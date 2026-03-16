import Foundation

// MARK: - CDPBridge

/// Lightweight Chrome DevTools Protocol discovery bridge.
///
/// This layer intentionally implements the cheap, synchronous pieces first:
/// debug-port discovery, tab enumeration, and coarse interactive-element hints.
/// Full websocket DOM evaluation can be layered in later without changing this API.
public enum CDPBridge {
    private static let httpTimeout: TimeInterval = 1.5

    private static var debugPort: Int {
        Int(ProcessInfo.processInfo.environment["ORACLE_CDP_PORT"] ?? "") ?? 9222
    }

    public static func isAvailable() -> Bool {
        getDebugTargets() != nil
    }

    public static func getDebugTargets() -> [[String: Any]]? {
        guard let url = URL(string: "http://127.0.0.1:\(debugPort)/json") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: httpTimeout)
        request.httpMethod = "GET"

        final class Box: @unchecked Sendable {
            var data: Data?
            var error: Error?
        }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession(configuration: .ephemeral).dataTask(with: request) { data, _, error in
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

    public static func findElements(
        query: String,
        tabIndex: Int = 0
    ) -> [[String: Any]]? {
        guard let elements = listInteractiveElements(tabIndex: tabIndex) else { return nil }
        let loweredQuery = query.lowercased()
        return elements.filter { element in
            let haystacks = [
                element["text"] as? String,
                element["ariaLabel"] as? String,
                element["placeholder"] as? String,
                element["title"] as? String,
                element["url"] as? String,
                element["role"] as? String,
                element["tag"] as? String,
            ].compactMap { $0?.lowercased() }
            return haystacks.contains { $0.contains(loweredQuery) }
        }
    }

    public static func listInteractiveElements(tabIndex: Int = 0) -> [[String: Any]]? {
        guard let targets = getDebugTargets() else { return nil }
        let pages = targets.filter { ($0["type"] as? String) == "page" }
        guard tabIndex < pages.count else { return nil }

        let page = pages[tabIndex]
        return [[
            "text": page["title"] as? String ?? "",
            "role": "document",
            "tag": "page",
            "url": page["url"] as? String ?? "",
            "actionable": false,
        ]]
    }
}
