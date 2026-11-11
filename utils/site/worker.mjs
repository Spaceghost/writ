// This Worker serves public project documents only. It does not execute Writ.
const BASE = "/writ/";
const HEADERS = {
  "content-security-policy":
    "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
};

export function createWorker(assets) {
  return {
    fetch(request) {
      const url = new URL(request.url);
      const isHead = request.method === "HEAD";
      const respond = (body, status, headers = {}) =>
        new Response(isHead ? null : body, {
          status,
          headers: {
            ...HEADERS,
            "content-type": "text/plain; charset=utf-8",
            ...headers,
          },
        });
      if (request.method !== "GET" && !isHead) {
        return respond("Method not allowed\n", 405, { allow: "GET, HEAD" });
      }
      if (url.pathname === "/writ" || url.pathname === "/writ/index.html") {
        return respond(null, 308, { location: BASE + url.search });
      }
      if (!url.pathname.startsWith(BASE)) return respond("Not found\n", 404);
      const name = url.pathname.slice(BASE.length) || "index.html";
      if (!Object.hasOwn(assets, name)) return respond("Not found\n", 404);
      const asset = assets[name];
      const headers = {
        "content-type": asset.type,
        "cache-control": "public, max-age=0, must-revalidate",
        etag: asset.etag,
      };
      if (request.headers.get("if-none-match") === asset.etag)
        return respond(null, 304, headers);
      return respond(asset.body, 200, headers);
    },
  };
}
