import Foundation

public struct HTTPResponse: Equatable, Sendable {
    public let status: Int
    public let contentType: String
    public let body: Data

    public init(status: Int, contentType: String, body: Data) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public var statusText: String {
        switch status {
        case 200:
            return "OK"
        case 400:
            return "Bad Request"
        case 404:
            return "Not Found"
        default:
            return "Internal Server Error"
        }
    }
}
