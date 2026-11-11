import assert from "node:assert/strict";
import test from "node:test";
import { createWorker } from "./worker.mjs";

const worker = createWorker({
  "index.html": {
    body: "<h1>Writ</h1>",
    type: "text/html; charset=utf-8",
    etag: '"page"',
  },
  "style.css": {
    body: "body{}",
    type: "text/css; charset=utf-8",
    etag: '"css"',
  },
});
const request = (path, options) =>
  worker.fetch(new Request(`https://spacegho.st${path}`, options));

test("canonical redirects stay within /writ and retain query parameters", () => {
  for (const path of ["/writ", "/writ/index.html"]) {
    const response = request(`${path}?from=example`);
    assert.equal(response.status, 308);
    assert.equal(response.headers.get("location"), "/writ/?from=example");
  }
});

test("only published paths are served, with correct media types", async () => {
  const response = request("/writ/");
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "<h1>Writ</h1>");
  assert.equal(
    response.headers.get("content-type"),
    "text/html; charset=utf-8",
  );
  assert.match(
    response.headers.get("content-security-policy"),
    /script-src 'self'/,
  );
  assert.equal(
    request("/writ/style.css").headers.get("content-type"),
    "text/css; charset=utf-8",
  );
  for (const path of [
    "/writ-other/",
    "/writ/missing",
    "/writ/constructor",
    "/writ/__proto__",
    "/writ/../",
    "/writ/%2e%2e/secret",
    "/writ/site.js.map",
  ]) {
    assert.equal(request(path).status, 404, path);
  }
});

test("HEAD has no body and conditional reads revalidate the exact asset", async () => {
  const head = request("/writ/", { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(await head.text(), "");
  assert.equal(head.headers.get("etag"), '"page"');
  const fresh = request("/writ/", { headers: { "if-none-match": '"page"' } });
  assert.equal(fresh.status, 304);
  assert.equal(await fresh.text(), "");
  assert.equal(
    request("/writ/", { headers: { "if-none-match": '"old"' } }).status,
    200,
  );
});

test("unsupported methods cannot turn the site into a write endpoint", () => {
  for (const method of ["POST", "PUT", "DELETE", "PATCH", "OPTIONS"]) {
    const response = request("/writ/", { method });
    assert.equal(response.status, 405);
    assert.equal(response.headers.get("allow"), "GET, HEAD");
  }
});
