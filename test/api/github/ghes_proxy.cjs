// Used in mimicking Github Enterprise Servers that starts with /api/v3 since the base
// api's used in the openapi spec doesnt prefix them with /api/v3

const http = require('http');
const httpProxy = require('http-proxy'); // npm i http-proxy

const proxy = httpProxy.createProxyServer({ target: 'http://localhost:55000' });

const PREFIX = '/api/v3';

const server = http.createServer((req, res) => {
    if (req.url.startsWith(PREFIX)) {
        req.url = req.url.slice(PREFIX.length) || '/';
    }
    proxy.web(req, res, {}, (err) => {
        res.writeHead(502);
        res.end('Proxy error: ' + err.message);
    });
});

server.listen(8080, () => {
    console.log('Prefix proxy running on http://localhost:8080' + PREFIX);
});
