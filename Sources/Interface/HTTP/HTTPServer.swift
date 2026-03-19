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
    private let router: HTTPRouter
    private let queue = DispatchQueue(label: "oracle.runtime.http")
    private var serverSocket: Int32 = -1
    private let maximumRequestBytes = 1_048_576

    public init(runtime: AgentRuntime, router: HTTPRouter = HTTPRouter()) {
        self.runtime = runtime
        self.router = router
    }

    public func start(port: UInt16 = 8080) throws {
        guard serverSocket < 0 else {
            throw RuntimeError.serverFailure("HTTP listener is already running")
        }

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
            writeResponse(
                makeResponse(HTTPResponse(status: 400, contentType: "text/plain", body: Data("bad request\n".utf8))),
                to: clientSocket
            )
            return
        }

        let response = route(requestText)
        writeResponse(response, to: clientSocket)
    }

    private func route(_ requestText: String) -> Data {
        guard let request = HTTPRequestParser.parse(requestText) else {
            return makeResponse(HTTPResponse(status: 400, contentType: "text/plain", body: Data("bad request\n".utf8)))
        }
        return makeResponse(router.handle(request, runtime: runtime))
    }

    private func readRequest(from clientSocket: Int32) -> String? {
        var requestData = Data()

        while requestData.count < maximumRequestBytes {
            var chunk = [UInt8](repeating: 0, count: 4096)
            let bytesRead = chunk.withUnsafeMutableBytes { rawBuffer in
                recv(clientSocket, rawBuffer.baseAddress, rawBuffer.count, 0)
            }

            if bytesRead <= 0 {
                break
            }

            requestData.append(contentsOf: chunk.prefix(Int(bytesRead)))

            if let requestText = String(data: requestData, encoding: .utf8),
               HTTPRequestParser.isCompleteRequest(requestText) {
                return requestText
            }
        }

        guard !requestData.isEmpty else {
            return nil
        }

        return String(data: requestData, encoding: .utf8)
    }

    private func writeResponse(_ response: Data, to clientSocket: Int32) {
        _ = response.withUnsafeBytes { rawBuffer in
            send(clientSocket, rawBuffer.baseAddress, rawBuffer.count, 0)
        }
    }

    private func makeResponse(_ response: HTTPResponse) -> Data {
        var header = "HTTP/1.1 \(response.status) \(response.statusText)\r\n"
        header += "Content-Type: \(response.contentType)\r\n"
        header += "Content-Length: \(response.body.count)\r\n"
        header += "Connection: close\r\n\r\n"

        var data = Data(header.utf8)
        data.append(response.body)
        return data
    }
}
