import Foundation

// ─────────────────────────────────────────────────────────
// MCPHTTPListener — HTTP server for Model Context Protocol
//
// Listens on a port and routes incoming JSON-RPC requests
// through MCPServer → OracleRuntime pipeline.
//
// Protocol: JSON-RPC 2.0 over HTTP (MCP standard)
//
// Endpoints:
//   POST /             — JSON-RPC request
//   GET  /health       — health check
//   GET  /tools        — list available tools
// ─────────────────────────────────────────────────────────

public final class MCPHTTPListener: NSObject, StreamDelegate {

    private let mcpServer: MCPServer
    private let runtime: OracleRuntime
    private var socketFD: Int32 = -1
    private var isRunning = false

    public init(mcpServer: MCPServer, runtime: OracleRuntime) {
        self.mcpServer = mcpServer
        self.runtime = runtime
    }

    public func start(port: UInt16 = 9100) {
        // Create socket
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            print("[mcp-http] Failed to create socket")
            return
        }

        // Set SO_REUSEADDR
        var optval: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(MemoryLayout<Int32>.size))

        // Bind
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            print("[mcp-http] Failed to bind on port \(port): \(String(cString: strerror(errno)))")
            close(socketFD)
            return
        }

        // Listen
        guard listen(socketFD, 10) == 0 else {
            print("[mcp-http] Failed to listen: \(String(cString: strerror(errno)))")
            close(socketFD)
            return
        }

        isRunning = true
        print("[mcp-http] Listening on 0.0.0.0:\(port)")

        // Accept loop
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(socketFD, sockPtr, &clientLen)
                }
            }

            guard clientFD >= 0 else { continue }
            handleClient(clientFD)
        }
    }

    public func stop() {
        isRunning = false
        if socketFD >= 0 { close(socketFD) }
        print("[mcp-http] Stopped")
    }

    // ── Client handling ─────────────────────────────────

    private func handleClient(_ fd: Int32) {
        // Read request (bounded to 64KB)
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else {
            close(fd)
            return
        }

        let rawRequest = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Parse HTTP request line
        let lines = rawRequest.split(separator: "\r\n", maxSplits: 1)
        let requestLine = String(lines.first ?? "")
        let parts = requestLine.split(separator: " ")
        let method = String(parts.first ?? "")
        let path = parts.count > 1 ? String(parts[1]) : "/"

        // Extract body (after blank line)
        let body: String
        if let range = rawRequest.range(of: "\r\n\r\n") {
            body = String(rawRequest[range.upperBound...])
        } else {
            body = ""
        }

        // Route
        let responseBody: String
        let statusCode: Int

        if method == "GET" && path == "/health" {
            statusCode = 200
            responseBody = "{\"status\":\"ok\",\"tools\":\(mcpServer.toolCount())}"

        } else if method == "GET" && path == "/tools" {
            statusCode = 200
            let tools = mcpServer.allToolDefinitions()
            let toolsJSON = tools.map { t in
                "{\"name\":\"\(t.name)\",\"description\":\"\(t.description)\"}"
            }.joined(separator: ",")
            responseBody = "{\"tools\":[\(toolsJSON)]}"

        } else if method == "POST" && (path == "/" || path == "/rpc") {
            (statusCode, responseBody) = handleJSONRPC(body: body)

        } else {
            statusCode = 404
            responseBody = "{\"error\":\"not found\"}"
        }

        // Send HTTP response
        let httpResponse = """
        HTTP/1.1 \(statusCode) \(statusText(statusCode))\r
        Content-Type: application/json\r
        Content-Length: \(responseBody.utf8.count)\r
        Connection: close\r
        \r
        \(responseBody)
        """

        _ = httpResponse.withCString { ptr in
            write(fd, ptr, strlen(ptr))
        }
        close(fd)
    }

    // ── JSON-RPC handler ────────────────────────────────

    private func handleJSONRPC(body: String) -> (Int, String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (400, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32700,\"message\":\"parse error\"},\"id\":null}")
        }

        let rpcMethod = json["method"] as? String ?? ""
        let rpcParams = json["params"] as? [String: Any] ?? [:]
        let rpcID = json["id"]

        let idJSON: String
        if let intID = rpcID as? Int { idJSON = "\(intID)" }
        else if let strID = rpcID as? String { idJSON = "\"\(strID)\"" }
        else { idJSON = "null" }

        switch rpcMethod {
        case "tools/list":
            let tools = mcpServer.allToolDefinitions()
            let toolsJSON = tools.map { t in
                "{\"name\":\"\(t.name)\",\"description\":\"\(t.description)\",\"inputSchema\":{\"type\":\"object\"}}"
            }.joined(separator: ",")
            return (200, "{\"jsonrpc\":\"2.0\",\"result\":{\"tools\":[\(toolsJSON)]},\"id\":\(idJSON)}")

        case "tools/call":
            let toolName = rpcParams["name"] as? String ?? ""
            let toolArgs = rpcParams["arguments"] as? [String: String] ?? [:]

            let mcpResponse = mcpServer.handleRequest(toolName: toolName, parameters: toolArgs)

            if var intent = mcpResponse.actionIntent {
                // Tag source surface as MCP
                intent = ActionIntent(
                    type: intent.type,
                    domain: intent.domain,
                    parameters: intent.parameters,
                    sourceSurface: .mcp
                )

                // Route through CommandDispatcher — never call executor directly.
                // Blueprint ref: Gate 1, §1.6 — "MCP enters through dispatcher"
                let dispatchResult = runtime.commandDispatcher.submitIntent(intent)

                let detail: String
                if dispatchResult.accepted {
                    detail = dispatchResult.reason ?? "accepted via dispatcher"
                } else {
                    detail = "rejected: \(dispatchResult.reason ?? "unknown")"
                }
                let escaped = detail
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                return (200, "{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"\(escaped)\"}]},\"id\":\(idJSON)}")
            } else {
                return (200, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"\(mcpResponse.data)\"},\"id\":\(idJSON)}")
            }

        case "initialize":
            return (200, """
            {"jsonrpc":"2.0","result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"oracle-mcp","version":"\(runtime.version)"}}}
            """.replacingOccurrences(of: "\n", with: ""))

        default:
            return (200, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"method not found: \(rpcMethod)\"},\"id\":\(idJSON)}")
        }
    }

    private func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
