import Foundation

public enum CDPBridge {
    private static let defaultPort = 9222
    private static let httpTimeout: TimeInterval = 1.5

    public static func isAvailable() -> Bool {
        getDebugTargets() != nil
    }

    public static func getDebugTargets() -> [[String: Any]]? {
        guard let url = URL(string: "http://127.0.0.1:\(defaultPort)/json") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: httpTimeout)
        request.httpMethod = "GET"

        final class Box: @unchecked Sendable {
            var data: Data?
            var error: Error?
        }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession(configuration: .default).dataTask(with: request) { data, _, error in
            box.data = data
            box.error = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        guard box.error == nil,
              let data = box.data,
              let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return targets
    }

    public static func findElements(query: String, tabIndex: Int = 0) -> [[String: Any]]? {
        guard let targets = getDebugTargets(), tabIndex < targets.count else { return nil }
        return []
    }

    public static func listInteractiveElements(tabIndex: Int = 0) -> [[String: Any]]? {
        guard let targets = getDebugTargets(), tabIndex < targets.count else { return nil }
        return []
    }

    public static func evaluateJS(_ expression: String, tabIndex: Int = 0) -> String? {
        guard let targets = getDebugTargets(), tabIndex < targets.count else { return nil }
        return nil
    }

    public static func viewportToScreen(viewportX: Double, viewportY: Double, windowX: Double, windowY: Double) -> (x: Double, y: Double) {
        (windowX + viewportX, windowY + viewportY)
    }
}
