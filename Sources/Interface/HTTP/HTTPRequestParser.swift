import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let queryItems: [String: String]
    public let headers: [String: String]
    public let body: String

    public init(
        method: String,
        path: String,
        queryItems: [String: String],
        headers: [String: String],
        body: String
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

public enum HTTPRequestParser {
    public static func parse(_ requestText: String) -> HTTPRequest? {
        let segments = requestText.components(separatedBy: "\r\n\r\n")
        let head = segments.first ?? ""
        let body = segments.dropFirst().joined(separator: "\r\n\r\n")
        let lines = head.components(separatedBy: "\r\n")

        guard let requestLine = lines.first, !requestLine.isEmpty else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2 else {
            return nil
        }

        let method = String(requestParts[0]).uppercased()
        let target = String(requestParts[1])
        let parsedTarget = parseTarget(target)

        let headers = headerMap(lines.dropFirst().map(String.init))

        if let declaredLength = headers["content-length"].flatMap(Int.init),
           body.utf8.count < declaredLength {
            return nil
        }

        return HTTPRequest(
            method: method,
            path: parsedTarget.path,
            queryItems: parsedTarget.queryItems,
            headers: headers,
            body: body
        )
    }

    public static func isCompleteRequest(_ requestText: String) -> Bool {
        let segments = requestText.components(separatedBy: "\r\n\r\n")
        guard segments.count >= 2 else {
            return false
        }

        let head = segments[0]
        let body = segments.dropFirst().joined(separator: "\r\n\r\n")
        let lines = head.components(separatedBy: "\r\n")
        let headers = headerMap(lines.dropFirst().map(String.init))
        let declaredLength = headers["content-length"].flatMap(Int.init) ?? 0

        return body.utf8.count >= declaredLength
    }

    private static func parseTarget(_ target: String) -> (path: String, queryItems: [String: String]) {
        guard let components = URLComponents(string: "http://runtime.local\(target)") else {
            return (target, [:])
        }

        var queryItems: [String: String] = [:]
        for item in components.queryItems ?? [] {
            queryItems[item.name] = item.value ?? ""
        }

        return (components.path.isEmpty ? target : components.path, queryItems)
    }

    private static func headerMap(_ headerLines: [String]) -> [String: String] {
        var headers: [String: String] = [:]
        for line in headerLines where !line.isEmpty {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }

            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }
        return headers
    }
}
