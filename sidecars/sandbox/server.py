"""
Oracle Sandbox Sidecar — OpenSandbox adapter

Wraps OpenSandbox execution daemon in a simple HTTP API.
Oracle calls this for risky operations instead of executing locally.

Endpoints:
    POST /execute      — run a shell command in container
    POST /run_tests    — run test suite in isolation
    POST /install_deps — install dependencies in ephemeral env
    POST /health       — health check

Requires Docker to be running.
"""

import json
import subprocess
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime


class SandboxHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b"{}"
        params = json.loads(body)

        if self.path == "/execute":
            result = self.handle_execute(params)
        elif self.path == "/run_tests":
            result = self.handle_run_tests(params)
        elif self.path == "/install_deps":
            result = self.handle_install_deps(params)
        elif self.path == "/health":
            result = {"status": "ok", "timestamp": datetime.utcnow().isoformat()}
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

    def handle_execute(self, params):
        command = params.get("command", "echo hello")
        workspace = params.get("workspace", "/tmp/sandbox")
        timeout = params.get("timeout", 60)
        execution_id = str(uuid.uuid4())

        try:
            result = subprocess.run(
                ["docker", "run", "--rm",
                 "-v", f"{workspace}:/workspace",
                 "-w", "/workspace",
                 "python:3.12-slim",
                 "sh", "-c", command],
                capture_output=True, text=True,
                timeout=timeout
            )
            return {
                "id": execution_id,
                "success": result.returncode == 0,
                "stdout": result.stdout[-4096:],  # bounded output
                "stderr": result.stderr[-2048:],
                "exit_code": result.returncode,
            }
        except subprocess.TimeoutExpired:
            return {"id": execution_id, "success": False, "error": "timeout"}
        except Exception as e:
            return {"id": execution_id, "success": False, "error": str(e)}

    def handle_run_tests(self, params):
        workspace = params.get("workspace", "/tmp/sandbox")
        command = params.get("command", "python -m pytest")
        return self.handle_execute({"command": command, "workspace": workspace, "timeout": 120})

    def handle_install_deps(self, params):
        workspace = params.get("workspace", "/tmp/sandbox")
        manifest = params.get("manifest", "requirements.txt")
        command = f"pip install -r {manifest}"
        return self.handle_execute({"command": command, "workspace": workspace})

    def log_message(self, format, *args):
        print(f"[sandbox] {args[0]}")


def main():
    port = 8080
    server = HTTPServer(("0.0.0.0", port), SandboxHandler)
    print(f"[sandbox] Sidecar running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[sandbox] Shutting down")
        server.server_close()


if __name__ == "__main__":
    main()
