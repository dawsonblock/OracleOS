import Foundation

// MARK: - VisionBridge

/// Synchronous bridge to the optional Python vision sidecar.
public enum VisionBridge {
    private static let logger = ExecutionLogger()
    private static let healthTimeout: TimeInterval = 2.0
    private static let groundTimeout: TimeInterval = 30.0
    private static let firstGroundTimeout: TimeInterval = 60.0

    private static var baseURL: String {
        if let overridden = ProcessInfo.processInfo.environment["ORACLE_VISION_URL"] {
            return overridden
        }
        let port = ProcessInfo.processInfo.environment["ORACLE_VISION_PORT"] ?? "9876"
        return "http://127.0.0.1:\(port)"
    }

    public enum SidecarState: Sendable, Equatable {
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

        public init(
            x: Double,
            y: Double,
            confidence: Double,
            raw: String = "",
            method: String = "unknown",
            inferenceMs: Int = 0
        ) {
            self.x = x
            self.y = y
            self.confidence = confidence
            self.raw = raw
            self.method = method
            self.inferenceMs = inferenceMs
        }
    }

    private final class SidecarLifecycle: @unchecked Sendable {
        private let lock = NSLock()
        private var _state: SidecarState = .stopped
        private var _process: Process?
        private var _hasCompletedFirstGround = false

        var state: SidecarState {
            get { lock.lock(); defer { lock.unlock() }; return _state }
            set { lock.lock(); defer { lock.unlock() }; _state = newValue }
        }

        var process: Process? {
            get { lock.lock(); defer { lock.unlock() }; return _process }
            set { lock.lock(); defer { lock.unlock() }; _process = newValue }
        }

        var hasCompletedFirstGround: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _hasCompletedFirstGround }
            set { lock.lock(); defer { lock.unlock() }; _hasCompletedFirstGround = newValue }
        }

        @discardableResult
        func transition(from expected: SidecarState, to desired: SidecarState) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard _state == expected else { return false }
            _state = desired
            return true
        }
    }

    private static let lifecycle = SidecarLifecycle()

    public static func isAvailable() -> Bool {
        guard let result = healthCheck() else { return false }
        return result["status"] != nil
    }

    public static func healthCheck() -> [String: Any]? {
        httpGet(path: "/health", timeout: healthTimeout)
    }

    public static func ground(
        imageBase64: String,
        description: String,
        screenWidth: Double = 1728,
        screenHeight: Double = 1117,
        cropBox: [Double]? = nil
    ) -> GroundResult? {
        if !isAvailable() && !startSidecar() {
            return nil
        }

        var payload: [String: Any] = [
            "image": imageBase64,
            "description": description,
            "screen_w": screenWidth,
            "screen_h": screenHeight,
        ]
        if let cropBox, cropBox.count == 4 {
            payload["crop_box"] = cropBox
        }

        let timeout = lifecycle.hasCompletedFirstGround ? groundTimeout : firstGroundTimeout
        guard let result = httpPost(path: "/ground", body: payload, timeout: timeout),
              let x = result["x"] as? Double,
              let y = result["y"] as? Double,
              let confidence = result["confidence"] as? Double else {
            return nil
        }

        lifecycle.hasCompletedFirstGround = true
        return GroundResult(
            x: x,
            y: y,
            confidence: confidence,
            raw: result["raw"] as? String ?? "",
            method: result["method"] as? String ?? "unknown",
            inferenceMs: result["inference_ms"] as? Int ?? 0
        )
    }

    public static func detect(
        imageBase64: String,
        screenWidth: Double = 1728,
        screenHeight: Double = 1117
    ) -> [String: Any]? {
        httpPost(path: "/detect", body: [
            "image": imageBase64,
            "screen_w": screenWidth,
            "screen_h": screenHeight,
        ], timeout: groundTimeout)
    }

    public static func parse(
        imageBase64: String,
        screenWidth: Double = 1728,
        screenHeight: Double = 1117
    ) -> [String: Any]? {
        httpPost(path: "/parse", body: [
            "image": imageBase64,
            "screen_w": screenWidth,
            "screen_h": screenHeight,
        ], timeout: groundTimeout)
    }

    @discardableResult
    public static func startSidecar() -> Bool {
        if isAvailable() {
            lifecycle.state = .ready
            return true
        }

        guard lifecycle.transition(from: .stopped, to: .starting)
                || lifecycle.transition(from: .failed, to: .starting) else {
            return lifecycle.state == .ready || waitForSidecar()
        }

        guard let binary = findVisionBinary() else {
            lifecycle.state = .failed
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--idle-timeout", "600"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            lifecycle.process = process
        } catch {
            logger.log("Failed to start vision sidecar: \(error)", level: .error)
            lifecycle.state = .failed
            return false
        }

        if waitForSidecar() {
            lifecycle.state = .ready
            return true
        }

        lifecycle.state = .failed
        return false
    }

    public static func stopSidecar() {
        lifecycle.process?.terminate()
        lifecycle.process = nil
        lifecycle.state = .stopped
    }

    private static func waitForSidecar(timeout: TimeInterval = 10, pollInterval: TimeInterval = 0.25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isAvailable() {
                lifecycle.state = .ready
                return true
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return false
    }

    private static func httpGet(path: String, timeout: TimeInterval) -> [String: Any]? {
        let response = HTTPClient.shared.get(url: baseURL + path, timeout: timeout)
        guard response.success else { return nil }
        return response.json
    }

    private static func httpPost(path: String, body: [String: Any], timeout: TimeInterval) -> [String: Any]? {
        let response = HTTPClient.shared.post(url: baseURL + path, json: body, timeout: timeout)
        guard response.success else { return nil }
        return response.json
    }

    private static func findVisionBinary() -> String? {
        if let overridden = ProcessInfo.processInfo.environment["ORACLE_VISION_BIN"],
           FileManager.default.isExecutableFile(atPath: overridden) {
            return overridden
        }

        let candidates = [
            "/opt/homebrew/bin/oracle-vision",
            "/usr/local/bin/oracle-vision",
            "/usr/bin/oracle-vision",
        ]
        if let match = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return match
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["oracle-vision"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}
