"""
Oracle Crawler Sidecar — web extraction pipeline

Converts URLs into normalized markdown artifacts.

Pipeline:
    URL → fetch page → extract content → convert to markdown → return artifact

Endpoints:
    POST /extract   — extract and convert a URL
    POST /batch     — extract multiple URLs
    GET  /health    — health check
"""

import json
import re
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
from html.parser import HTMLParser


class TextExtractor(HTMLParser):
    """Simple HTML to text converter."""

    def __init__(self):
        super().__init__()
        self.text_parts = []
        self.skip_tags = {"script", "style", "noscript"}
        self._skip = False

    def handle_starttag(self, tag, attrs):
        if tag in self.skip_tags:
            self._skip = True
        if tag in ("p", "br", "div", "h1", "h2", "h3", "h4", "li"):
            self.text_parts.append("\n")
        if tag in ("h1", "h2", "h3"):
            self.text_parts.append("#" * int(tag[1]) + " ")

    def handle_endtag(self, tag):
        if tag in self.skip_tags:
            self._skip = False

    def handle_data(self, data):
        if not self._skip:
            self.text_parts.append(data.strip())

    def get_text(self):
        raw = " ".join(self.text_parts)
        # Collapse whitespace
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        raw = re.sub(r" {2,}", " ", raw)
        return raw.strip()


def fetch_and_extract(url, timeout=15):
    """Fetch URL and extract markdown-like text."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "OracleCrawler/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
            extractor = TextExtractor()
            extractor.feed(html)
            text = extractor.get_text()
            # Truncate to reasonable size
            if len(text) > 50000:
                text = text[:50000] + "\n\n[truncated]"
            return {"url": url, "content": text, "length": len(text), "success": True}
    except Exception as e:
        return {"url": url, "content": "", "error": str(e), "success": False}


class CrawlerHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b"{}"
        params = json.loads(body)

        if self.path == "/extract":
            url = params.get("url", "")
            result = fetch_and_extract(url)
        elif self.path == "/batch":
            urls = params.get("urls", [])
            result = {"results": [fetch_and_extract(u) for u in urls[:10]]}
        else:
            result = {"error": f"unknown endpoint: {self.path}"}

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

    def do_GET(self):
        if self.path == "/health":
            result = {"status": "ok", "timestamp": datetime.utcnow().isoformat()}
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        print(f"[crawler] {args[0]}")


def main():
    port = 8083
    server = HTTPServer(("0.0.0.0", port), CrawlerHandler)
    print(f"[crawler] Sidecar running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[crawler] Shutting down")
        server.server_close()


if __name__ == "__main__":
    main()
