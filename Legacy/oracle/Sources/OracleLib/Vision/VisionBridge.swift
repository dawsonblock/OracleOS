import Foundation

public enum VisionBridge {
    private static let baseURL: String = {
        if let url = ProcessInfo.processInfo.environment["ORACLE_VISION_URL"] { return url }
        let port = ProcessInfo.processInfo.environment["ORACLE_VISION_PORT"] ?? "9876"
        return "http://127.0.0.1:\(port)"
    }()

    private static let healthTimeout: TimeInterval = 2.0
    private static let groundTimeout: TimeInterval = 30.0

    public enum SidecarState: Sendable {
        case stopped
        case starting
        case ready
        case failed
    }

    public struct GroundResult: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let confidence: Double
        public let raw: String
        public let method: String
        public let inferenceMs: Int

        public init(x: Double, y: Double, confidence: Double, raw: String = "", method: String = "unknown", inferenceMs: Int = 0) {
            self.x = x
            self.y = y
            self.confidence = confidence
            self.raw = raw
            self.method = method
            self.inferenceMs = inferenceMs
        }
    }

    public static func isAvailable() -> Bool {
        healthCheck() != nil
    }

    public static func healthCheck() -> [String: Any]? {
        httpGet(path: "/health", timeout: healthTimeout)
    }

    public static func ground(imageBase64: String, description: String, screenWidth: Double = 1728, screenHeight: Double = 1117, cropBox: [Double]? = nil) -> GroundResult? {
        var payload: [String: Any] = [
            "image": imageBase64,
            "description": description,
            "screen_w": screenWidth,
            "screen_h": screenHeight,
        ]
        if let cropBox, cropBox.count == 4 { payload["crop_box"] = cropBox }
        guard let result = httpPost(path: "/ground", body: payload, timeout: groundTimeout),
              let x = result["x"] as? Double,
              let y = result["y"] as? Double,
              let confidence = result["confidence"] as? Double else {
            return nil
        }
        return GroundResult(
            x: x,
            y: y,
            confidence: confidence,
            raw: result["raw"] as? String ?? "",
            method: result["method"] as? String ?? "unknown",
            inferenceMs: result["inference_ms"] as? Int ?? 0
        )
    }

    public static func detect(imageBase64: String, screenWidth: Double = 1728, screenHeight: Double = 1117) -> [String: Any]? {
        httpPost(path: "/detect", body: ["image": imageBase64, "screen_w": screenWidth, "screen_h": screenHeight], timeout: groundTimeout)
    }

    public static func parse(imageBase64: String, screenWidth: Double = 1728, screenHeight: Double = 1117) -> [String: Any]? {
        httpPost(path: "/parse", body: ["image": imageBase64, "screen_w": screenWidth, "screen_h": screenHeight], timeout: groundTimeout)
    }

    @discardableResult
    public static func startSidecar() -> Bool {
        false
    }

    private static func httpGet(path: String, timeout: TimeInterval) -> [String: Any]? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        return perform(request: request)
    }

    private static func httpPost(path: String, body: [String: Any], timeout: TimeInterval) -> [String: Any]? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return perform(request: request)
    }

    private static func perform(request: URLRequest) -> [String: Any]? {
        final class Box: @unchecked Sendable {
            var data: Data?
            var error: Error?
        }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)
        URLSession(configuration: .default).dataTask(with: request) { data, _, error in
            box.data = data
            box.error = error
            semaphore.signal()
        }.resume()
        semaphore.wait()
        guard box.error == nil,
              let data = box.data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}
