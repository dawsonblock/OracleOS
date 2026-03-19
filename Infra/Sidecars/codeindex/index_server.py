"""
Oracle Code Index Sidecar — cocoindex-code adapter

Provides fast AST-based code search for the Oracle runtime.

Endpoints:
    POST /symbol_lookup    — find symbol definitions
    POST /reference_lookup — find symbol references
    POST /text_search      — full text search
    GET  /health           — health check
"""

import json
import os
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime


# Simple in-memory index (Phase 11: replace with cocoindex backend)
class CodeIndex:

    def __init__(self):
        self.symbols = {}  # name -> [(file, line, kind)]
        self.indexed_files = 0

    def index_directory(self, path):
        """Walk directory and extract symbol definitions."""
        for root, _, files in os.walk(path):
            for fname in files:
                if fname.endswith((".swift", ".py", ".rs", ".ts", ".go")):
                    fpath = os.path.join(root, fname)
                    self._index_file(fpath)

    def _index_file(self, path):
        try:
            with open(path, "r", errors="ignore") as f:
                for i, line in enumerate(f, 1):
                    # Naive symbol extraction — Phase 11 uses AST
                    for match in re.finditer(
                        r"(?:func|class|struct|enum|protocol|def|fn|type)\s+(\w+)", line
                    ):
                        name = match.group(1)
                        if name not in self.symbols:
                            self.symbols[name] = []
                        self.symbols[name].append({
                            "file": path,
                            "line": i,
                            "kind": match.group(0).split()[0],
                        })
            self.indexed_files += 1
        except Exception:
            pass

    def lookup(self, symbol):
        return self.symbols.get(symbol, [])

    def search(self, pattern, limit=20):
        results = []
        regex = re.compile(pattern, re.IGNORECASE)
        for name, locations in self.symbols.items():
            if regex.search(name):
                results.extend(locations[:5])
            if len(results) >= limit:
                break
        return results[:limit]


index = CodeIndex()


class IndexHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b"{}"
        params = json.loads(body)

        if self.path == "/symbol_lookup":
            symbol = params.get("symbol", "")
            result = {"symbol": symbol, "locations": index.lookup(symbol)}
        elif self.path == "/reference_lookup":
            symbol = params.get("symbol", "")
            result = {"symbol": symbol, "references": index.lookup(symbol)}
        elif self.path == "/text_search":
            pattern = params.get("pattern", "")
            limit = params.get("limit", 20)
            result = {"pattern": pattern, "results": index.search(pattern, limit)}
        elif self.path == "/index":
            path = params.get("path", ".")
            index.index_directory(path)
            result = {"indexed_files": index.indexed_files, "symbols": len(index.symbols)}
        else:
            result = {"error": f"unknown endpoint: {self.path}"}

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

    def do_GET(self):
        if self.path == "/health":
            result = {
                "status": "ok",
                "indexed_files": index.indexed_files,
                "symbols": len(index.symbols),
                "timestamp": datetime.utcnow().isoformat(),
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        print(f"[codeindex] {args[0]}")


def main():
    port = 8081
    server = HTTPServer(("0.0.0.0", port), IndexHandler)
    print(f"[codeindex] Sidecar running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[codeindex] Shutting down")
        server.server_close()


if __name__ == "__main__":
    main()
