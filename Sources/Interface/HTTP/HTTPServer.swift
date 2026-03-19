import Core
import Foundation

#if canImport(Glibc)
import Glibc
private let runtimeClose = Glibc.close
private let streamSocketType = Int32(SOCK_STREAM.rawValue)
#else
import Darwin
private let runtimeClose = Darwin.close
private let streamSocketType = SOCK_STREAM
#endif

public final class HTTPServer {
    private let runtime: AgentRuntime
    private let queue = DispatchQueue(label: "oracle.runtime.http")
    private var serverSocket: Int32 = -1

    public init(runtime: AgentRuntime) {
        self.runtime = runtime
    }

    public func start(port: UInt16 = 8080) throws {
        let socketDescriptor = socket(AF_INET, streamSocketType, 0)
        guard socketDescriptor >= 0 else {
            throw RuntimeError.serverFailure("Unable to create HTTP listener socket")
        }

        var reuseAddress: Int32 = 1
        _ = withUnsafePointer(to: &reuseAddress) { pointer in
            setsockopt(
                socketDescriptor,
                SOL_SOCKET,
                SO_REUSEADDR,
                pointer,
                socklen_t(MemoryLayout<Int32>.size)
            )
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: in_addr_t(0))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { reboundPointer in
                bind(
                    socketDescriptor,
                    reboundPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }

        guard bindResult == 0 else {
            runtimeClose(socketDescriptor)
            throw RuntimeError.serverFailure("Unable to bind HTTP listener to port \(port)")
        }

        guard listen(socketDescriptor, 16) == 0 else {
            runtimeClose(socketDescriptor)
            throw RuntimeError.serverFailure("Unable to start HTTP listener backlog")
        }

        serverSocket = socketDescriptor
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        guard serverSocket >= 0 else {
            return
        }
        runtimeClose(serverSocket)
        serverSocket = -1
    }

    private func acceptLoop() {
        while serverSocket >= 0 {
            var address = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientSocket = withUnsafeMutablePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { reboundPointer in
                    accept(serverSocket, reboundPointer, &length)
                }
            }

            guard clientSocket >= 0 else {
                continue
            }

            handle(clientSocket)
        }
    }

    private func handle(_ clientSocket: Int32) {
        defer { runtimeClose(clientSocket) }

        guard let requestText = readRequest(from: clientSocket) else {
            writeResponse(makeResponse(status: 400, body: Data("bad request\n".utf8), contentType: "text/plain"), to: clientSocket)
            return
        }

        let response = route(requestText)
        writeResponse(response, to: clientSocket)
    }

    private func route(_ requestText: String) -> Data {
        let requestLine = requestText.components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return makeResponse(status: 400, body: Data("bad request\n".utf8), contentType: "text/plain")
        }

        let method = String(parts[0])
        let path = String(parts[1])
        let body = requestText.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n")

        switch (method, path) {
        case ("POST", "/goal"):
            do {
                let state = try runtime.run(goal: Goal(text: body.trimmingCharacters(in: .whitespacesAndNewlines)))
                let data = try JSONEncoder().encode(state)
                return makeResponse(status: 200, body: data, contentType: "application/json")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                return makeResponse(status: 500, body: Data(message.utf8), contentType: "text/plain")
            }
        case ("GET", "/events"):
            do {
                let data = try JSONEncoder().encode(runtime.recentEvents(limit: 100))
                return makeResponse(status: 200, body: data, contentType: "application/json")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                return makeResponse(status: 500, body: Data(message.utf8), contentType: "text/plain")
            }
        case ("GET", "/state"):
            do {
                let data = try JSONEncoder().encode(runtime.currentState())
                return makeResponse(status: 200, body: data, contentType: "application/json")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                return makeResponse(status: 500, body: Data(message.utf8), contentType: "text/plain")
            }
        default:
            return makeResponse(status: 404, body: Data("not found\n".utf8), contentType: "text/plain")
        }
    }

    private func readRequest(from clientSocket: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
            recv(clientSocket, rawBuffer.baseAddress, rawBuffer.count, 0)
        }

        guard bytesRead > 0 else {
            return nil
        }

        return String(decoding: buffer.prefix(Int(bytesRead)), as: UTF8.self)
    }

    private func writeResponse(_ response: Data, to clientSocket: Int32) {
        _ = response.withUnsafeBytes { rawBuffer in
            send(clientSocket, rawBuffer.baseAddress, rawBuffer.count, 0)
        }
    }

    private func makeResponse(status: Int, body: Data, contentType: String) -> Data {
        let statusText: String
        switch status {
        case 200:
            statusText = "OK"
        case 400:
            statusText = "Bad Request"
        case 404:
            statusText = "Not Found"
        default:
            statusText = "Internal Server Error"
        }

        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"

        var response = Data(header.utf8)
        response.append(body)
        return response
    }
}
