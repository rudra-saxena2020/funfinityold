const http = require("http");
const fs = require("fs");
const path = require("path");

const port = Number(process.env.PORT || 5000);
const host = "0.0.0.0";
const publicDir = path.join(__dirname, "public");
const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".ico": "image/x-icon",
};

function send(res, status, type, body) {
  res.writeHead(status, {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  if (url.pathname === "/api/health") {
    return send(res, 200, mimeTypes[".json"], JSON.stringify({
      ok: true,
      service: "funfinity-operations",
      mode: "demo",
    }));
  }

  if (url.pathname === "/favicon.ico") {
    return send(res, 204, "image/x-icon", "");
  }

  let requested = url.pathname === "/" ? "/index.html" : url.pathname;
  let filePath = path.normalize(path.join(publicDir, requested));
  if (!filePath.startsWith(publicDir)) {
    return send(res, 403, "text/plain; charset=utf-8", "Forbidden");
  }

  fs.stat(filePath, (error, stats) => {
    if (!error && stats.isDirectory()) filePath = path.join(filePath, "index.html");
    fs.readFile(filePath, (readError, data) => {
      if (readError) {
        return send(res, 404, "text/plain; charset=utf-8", "Not found");
      }
      const extension = path.extname(filePath).toLowerCase();
      send(res, 200, mimeTypes[extension] || "application/octet-stream", data);
    });
  });
});

server.listen(port, host, () => {
  console.log(`Funfinity is running on http://${host}:${port}`);
});