"""
Oracle Context DB Sidecar — OpenViking-inspired context store

Long-horizon retrieval layer for task history, artifact metadata,
execution traces, and semantic summaries.

CRITICAL RULE: GraphStore remains the source of truth.
This sidecar is a retrieval/index layer only — it never
generates canonical state.

Endpoints:
    POST /store_context    — index a context record
    POST /query            — semantic query across contexts
    POST /task_history     — retrieve task execution history
    POST /artifacts        — retrieve artifacts for a task
    GET  /health           — health check
"""

import json
import sqlite3
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime


DB_PATH = os.environ.get("CONTEXT_DB_PATH", "../../data/context/context.db")


def get_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("""
        CREATE TABLE IF NOT EXISTS contexts (
            id TEXT PRIMARY KEY,
            task_id TEXT,
            content TEXT,
            summary TEXT,
            context_type TEXT,
            created_at TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS task_history (
            id TEXT PRIMARY KEY,
            goal TEXT,
            status TEXT,
            trace_summary TEXT,
            created_at TEXT,
            completed_at TEXT
        )
    """)
    conn.commit()
    return conn


class ContextHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b"{}"
        params = json.loads(body)

        db = get_db()

        if self.path == "/store_context":
            result = self.store_context(db, params)
        elif self.path == "/query":
            result = self.query_contexts(db, params)
        elif self.path == "/task_history":
            result = self.get_task_history(db, params)
        elif self.path == "/artifacts":
            result = self.get_artifacts(db, params)
        else:
            result = {"error": f"unknown endpoint: {self.path}"}

        db.close()
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

    def store_context(self, db, params):
        import uuid
        ctx_id = str(uuid.uuid4())
        db.execute(
            "INSERT INTO contexts (id, task_id, content, summary, context_type, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (ctx_id, params.get("task_id", ""),
             params.get("content", ""), params.get("summary", ""),
             params.get("type", "general"), datetime.utcnow().isoformat())
        )
        db.commit()
        return {"id": ctx_id, "stored": True}

    def query_contexts(self, db, params):
        query = params.get("query", "")
        limit = params.get("limit", 10)
        # Phase 18: replace with semantic search (embeddings)
        rows = db.execute(
            "SELECT id, task_id, summary, context_type, created_at FROM contexts "
            "WHERE content LIKE ? OR summary LIKE ? ORDER BY created_at DESC LIMIT ?",
            (f"%{query}%", f"%{query}%", limit)
        ).fetchall()
        return {"results": [dict(r) for r in rows]}

    def get_task_history(self, db, params):
        limit = params.get("limit", 20)
        rows = db.execute(
            "SELECT * FROM task_history ORDER BY created_at DESC LIMIT ?",
            (limit,)
        ).fetchall()
        return {"history": [dict(r) for r in rows]}

    def get_artifacts(self, db, params):
        task_id = params.get("task_id", "")
        rows = db.execute(
            "SELECT id, summary, context_type, created_at FROM contexts "
            "WHERE task_id = ? ORDER BY created_at DESC",
            (task_id,)
        ).fetchall()
        return {"artifacts": [dict(r) for r in rows]}

    def log_message(self, format, *args):
        print(f"[contextdb] {args[0]}")


def main():
    port = 8082
    server = HTTPServer(("0.0.0.0", port), ContextHandler)
    print(f"[contextdb] Sidecar running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[contextdb] Shutting down")
        server.server_close()


if __name__ == "__main__":
    main()
