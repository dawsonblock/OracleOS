import Foundation

// ─────────────────────────────────────────────────────────
// HTTPClient — shared synchronous HTTP client for sidecar calls
//
// All sidecar communication flows through here.
// Uses Foundation URLSession with semaphore-based sync.
// Timeouts, error handling, and response parsing are centralized.
//
// RULE: Sidecars return data only. They never mutate Oracle state.
// ─────────────────────────────────────────────────────────

public final class HTTPClient {

    public static let shared = HTTPClient()

    private let session: URLSession
    private let defaultTimeout: TimeInterval

    public init(timeout: TimeInterval = 15) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: config)
        self.defaultTimeout = timeout
    }

    // ── Typed response ──────────────────────────────────

    public struct Response {
        public let statusCode: Int
        public let body: String
        public let json: [String: Any]?
        public let success: Bool
        public let error: String?

        public static func failure(_ message: String) -> Response {
            return Response(statusCode: 0, body: "", json: nil, success: false, error: message)
        }
    }

    // ── POST JSON ───────────────────────────────────────

    public func post(url: String, json payload: [String: Any], timeout: TimeInterval? = nil) -> Response {
        guard let requestURL = URL(string: url) else {
            return .failure("invalid URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OracleRuntime/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout ?? defaultTimeout

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return .failure("JSON encode failed: \(error.localizedDescription)")
        }

        return execute(request)
    }

    // ── GET ─────────────────────────────────────────────

    public func get(url: String, timeout: TimeInterval? = nil) -> Response {
        guard let requestURL = URL(string: url) else {
            return .failure("invalid URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("OracleRuntime/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout ?? defaultTimeout

        return execute(request)
    }

    // ── Health check ────────────────────────────────────

    public func isReachable(baseURL: String) -> Bool {
        let resp = get(url: "\(baseURL)/health", timeout: 3)
        return resp.success
    }

    // ── Internal ────────────────────────────────────────

    private func execute(_ request: URLRequest) -> Response {
        let semaphore = DispatchSemaphore(value: 0)

        var resultData: Data?
        var resultResponse: HTTPURLResponse?
        var resultError: Error?

        let task = session.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response as? HTTPURLResponse
            resultError = error
            semaphore.signal()
        }
        task.resume()

        let waitResult = semaphore.wait(timeout: .now() + (request.timeoutInterval * 2))
        if waitResult == .timedOut {
            task.cancel()
            return .failure("request timed out: \(request.url?.absoluteString ?? "?")")
        }

        if let error = resultError {
            return .failure("request failed: \(error.localizedDescription)")
        }

        let statusCode = resultResponse?.statusCode ?? 0
        let bodyString = resultData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        var jsonDict: [String: Any]?
        if let data = resultData {
            jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }

        return Response(
            statusCode: statusCode,
            body: bodyString,
            json: jsonDict,
            success: (200..<300).contains(statusCode),
            error: (200..<300).contains(statusCode) ? nil : "HTTP \(statusCode)"
        )
    }
}
