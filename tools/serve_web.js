// Minimal static server for testing the web build locally: node tools/serve_web.js
const http = require("http");
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..", "build", "web");
const types = { ".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream" };
http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split("?")[0]) === "/" ? "index.html" : decodeURIComponent(req.url.split("?")[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end("not found"); return; }
    res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
    res.end(data);
  });
}).listen(8060, () => console.log("serving build/web on http://localhost:8060"));
