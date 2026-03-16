import Foundation

// ─────────────────────────────────────────────────────────
// ActionRegistry — canonical action catalogue
//
// Every callable action registers here.
// Unregistered actions are rejected by the executor.
// Tools, sidecars, and adapters register through this.
// ─────────────────────────────────────────────────────────

public final class ActionRegistry {

    public static let shared = ActionRegistry()

    public typealias ActionHandler = (ActionIntent) -> ExecutionResult

    private var handlers: [String: ActionHandler] = [:]

    private init() {}

    // ── Registration ────────────────────────────────────

    public func register(_ type: String, handler: @escaping ActionHandler) {
        handlers[type] = handler
        print("[registry] Registered action: \(type)")
    }

    public func isRegistered(_ type: String) -> Bool {
        return handlers[type] != nil
    }

    public func handler(for type: String) -> ActionHandler {
        return handlers[type] ?? { action in
            ExecutionResult(
                success: false,
                detail: "no handler for \(action.type)",
                executedThroughExecutor: true,
                actionID: action.id
            )
        }
    }

    public func registeredActions() -> [String] {
        return Array(handlers.keys).sorted()
    }

    // ── Built-in defaults ───────────────────────────────

    public func registerDefaults() {

        // log — write a message
        register("log") { action in
            let message = action.parameters["message"] ?? "(empty)"
            print("[action:log] \(message)")
            return ExecutionResult(success: true, detail: message, actionID: action.id)
        }

        // read_file — read file contents
        register("read_file") { action in
            guard let path = action.parameters["path"] else {
                return ExecutionResult(success: false, detail: "missing path", actionID: action.id)
            }
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return ExecutionResult(
                    success: true,
                    detail: "read \(content.count) chars from \(path)",
                    actionID: action.id
                )
            } catch {
                return ExecutionResult(
                    success: false,
                    detail: "read failed: \(error.localizedDescription)",
                    actionID: action.id
                )
            }
        }

        // write_file — write content to file
        register("write_file") { action in
            guard let path = action.parameters["path"],
                  let content = action.parameters["content"] else {
                return ExecutionResult(success: false, detail: "missing path or content", actionID: action.id)
            }
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return ExecutionResult(
                    success: true,
                    detail: "wrote \(content.count) chars to \(path)",
                    actionID: action.id
                )
            } catch {
                return ExecutionResult(
                    success: false,
                    detail: "write failed: \(error.localizedDescription)",
                    actionID: action.id
                )
            }
        }

        // list_directory — list directory contents
        register("list_directory") { action in
            guard let path = action.parameters["path"] else {
                return ExecutionResult(success: false, detail: "missing path", actionID: action.id)
            }
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: path)
                let listing = items.joined(separator: "\n")
                return ExecutionResult(
                    success: true,
                    detail: "found \(items.count) items:\n\(listing)",
                    actionID: action.id
                )
            } catch {
                return ExecutionResult(
                    success: false,
                    detail: "list failed: \(error.localizedDescription)",
                    actionID: action.id
                )
            }
        }

        // create_directory — create directory
        register("create_directory") { action in
            guard let path = action.parameters["path"] else {
                return ExecutionResult(success: false, detail: "missing path", actionID: action.id)
            }
            do {
                try FileManager.default.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                return ExecutionResult(success: true, detail: "created \(path)", actionID: action.id)
            } catch {
                return ExecutionResult(
                    success: false,
                    detail: "mkdir failed: \(error.localizedDescription)",
                    actionID: action.id
                )
            }
        }

        // noop — do nothing (for testing)
        register("noop") { action in
            return ExecutionResult(success: true, detail: "noop", actionID: action.id)
        }

        print("[registry] Default actions registered: \(registeredActions().joined(separator: ", "))")
    }
}
