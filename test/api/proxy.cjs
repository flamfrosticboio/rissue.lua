const http = require('http');
const httpProxy = require('http-proxy');

const PREFIX = process.env.PREFIX || "";

const PORT = Number(process.env.PORT) || 55000
const TARGET_PORT = Number(process.env.TARGET_PORT) || 55001

const proxy = httpProxy.createProxyServer({ target: `http://localhost:${TARGET_PORT}` });

const server = http.createServer((req, res) => {
    if (req.url.startsWith(PREFIX)) {
        req.url = req.url.slice(PREFIX.length) || '/';
    }
    proxy.web(req, res, {}, (err) => {
        res.writeHead(502);
        res.end('Proxy error: ' + err.message);
    });
});

server.listen(PORT, () => {
    console.log(`Prefix proxy running on http://localhost:${PORT}` + PREFIX);
});
