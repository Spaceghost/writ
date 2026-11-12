"""Disposable native acceptance fixture; independent SigV4 and CAS oracle.

Never a production remote or alternate Writ policy engine. The test owns its
temporary TLS certificate, bucket bytes, credentials and failure barriers.
"""
import argparse
import hashlib
import hmac
import http.server
import json
import re
import ssl
import threading
import time
from pathlib import Path

ACCESS = "writ-native-fixture"
SECRET = "public-disposable-fixture-secret"
PREFIX = "/writ-test/writ/"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory
    objects = directory / "objects"
    objects.mkdir()
    lock = threading.Lock()
    verified = 0

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *args):
            pass  # No Authorization/header material is written to diagnostics.

        def reply(self, status, body=b"", etag=None):
            self.send_response(status)
            self.send_header("Content-Length", str(len(body)))
            if etag:
                self.send_header("ETag", etag)
            self.end_headers()
            self.wfile.write(body)

        def barrier(self, name):
            source = directory / name
            try:
                source.rename(directory / (name + ".claimed"))
            except FileNotFoundError:
                return
            (directory / (name + ".blocked")).write_text("blocked")
            deadline = time.monotonic() + 25
            while not (directory / (name + ".release")).exists():
                if time.monotonic() >= deadline:
                    raise TimeoutError("fixture barrier timed out")
                time.sleep(.02)

        def request(self):
            nonlocal verified
            if not self.path.startswith(PREFIX) or "?" in self.path:
                return self.reply(400)
            size = int(self.headers.get("Content-Length", "0"))
            if size < 0 or size > 4 * 1024 * 1024:
                return self.reply(413)
            body = self.rfile.read(size)
            payload = hashlib.sha256(body).hexdigest()
            auth = re.fullmatch(r"AWS4-HMAC-SHA256 Credential=([^/]+)/([^,]+), SignedHeaders=([^,]+), Signature=([0-9a-f]{64})", self.headers.get("Authorization", ""))
            if not auth or auth[1] != ACCESS or self.headers.get("x-amz-content-sha256") != payload:
                return self.reply(403)
            names = auth[3].split(";")
            if names != sorted(set(names)) or not {"host", "x-amz-date", "x-amz-content-sha256"}.issubset(names):
                return self.reply(403)
            headers = "".join(name + ":" + self.headers[name].strip() + "\n" for name in names)
            date = self.headers["x-amz-date"]
            scope = date[:8] + "/auto/s3/aws4_request"
            canonical = self.command + "\n" + self.path + "\n\n" + headers + "\n" + auth[3] + "\n" + payload
            to_sign = "AWS4-HMAC-SHA256\n" + date + "\n" + scope + "\n" + hashlib.sha256(canonical.encode()).hexdigest()
            key = ("AWS4" + SECRET).encode()
            for part in (date[:8], "auto", "s3", "aws4_request"):
                key = hmac.digest(key, part.encode(), "sha256")
            if auth[2] != scope or not hmac.compare_digest(auth[4], hmac.new(key, to_sign.encode(), "sha256").hexdigest()):
                return self.reply(403)
            target = objects / hashlib.sha256(self.path.encode()).hexdigest()
            is_manifest = self.path == PREFIX + "manifest.writ"
            if self.command == "GET" and not is_manifest:
                self.barrier("hold-get")
            if self.command == "PUT" and is_manifest:
                self.barrier("hold-put")
            with lock:
                verified += 1
                (directory / "verified.txt").write_text(str(verified))
                before = target.read_bytes() if target.exists() else None
                etag = '"' + hashlib.sha256(before).hexdigest() + '"' if before is not None else None
                if self.command == "GET":
                    if before is None:
                        return self.reply(404)
                    if self.headers.get("If-None-Match") == etag:
                        return self.reply(304, etag=etag)
                    if not is_manifest and (directory / "corrupt").exists():
                        before = bytes([before[0] ^ 1]) + before[1:] if before else b"x"
                    return self.reply(200, before, etag)
                if self.command != "PUT":
                    return self.reply(405)
                if is_manifest and (directory / "fail-write").exists():
                    return self.reply(503)
                if "if-none-match" not in names and "if-match" not in names:
                    return self.reply(428)
                if self.headers.get("If-None-Match") == "*" and before is not None:
                    return self.reply(412)
                if self.headers.get("If-Match") and self.headers["If-Match"] != etag:
                    (directory / "cas-rejected").write_text("412")
                    return self.reply(412)
                if not is_manifest and self.path != PREFIX + "objects/" + payload:
                    return self.reply(400)
                target.write_bytes(body)
                return self.reply(200, etag='"' + hashlib.sha256(body).hexdigest() + '"')

        do_GET = request
        do_PUT = request

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(directory / "certificate.pem", directory / "private.pem")
    server.socket = context.wrap_socket(server.socket, server_side=True)
    (directory / "ready.json").write_text(json.dumps({"endpoint": f"https://localhost:{server.server_port}"}))
    server.serve_forever()


if __name__ == "__main__":
    main()
