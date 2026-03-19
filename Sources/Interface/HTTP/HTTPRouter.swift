import Core
import Foundation

public struct HTTPRouter {
    public init() {}

    public func handle(_ request: HTTPRequest, runtime: AgentRuntime) -> HTTPResponse {
        switch (request.method, request.path) {
        case ("POST", "/goal"):
            return runGoal(request, runtime: runtime)
        case ("GET", "/events"):
            return events(request, runtime: runtime)
        case ("GET", "/state"):
            return state(runtime: runtime)
        default:
            return plainText(status: 404, text: "not found\n")
        }
    }

    private func runGoal(_ request: HTTPRequest, runtime: AgentRuntime) -> HTTPResponse {
        do {
            let goalText = request.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let state = try runtime.run(goal: Goal(text: goalText))
            let payload = GoalRunResponse(
                status: "ok",
                goal: goalText,
                commandCount: state.executedCommandIDs.count,
                traceCount: state.executionTrace.count,
                state: state
            )
            return json(status: 200, payload)
        } catch {
            return plainText(status: 500, text: errorMessage(error))
        }
    }

    private func events(_ request: HTTPRequest, runtime: AgentRuntime) -> HTTPResponse {
        do {
            let limit = request.queryItems["limit"].flatMap(Int.init) ?? 100
            let safeLimit = max(1, min(limit, 1000))
            return json(status: 200, try runtime.recentEvents(limit: safeLimit))
        } catch {
            return plainText(status: 500, text: errorMessage(error))
        }
    }

    private func state(runtime: AgentRuntime) -> HTTPResponse {
        do {
            return json(status: 200, try runtime.currentState())
        } catch {
            return plainText(status: 500, text: errorMessage(error))
        }
    }

    private func json<T: Encodable>(status: Int, _ payload: T) -> HTTPResponse {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let body = try encoder.encode(payload)
            return HTTPResponse(status: status, contentType: "application/json", body: body)
        } catch {
            return plainText(status: 500, text: errorMessage(error))
        }
    }

    private func plainText(status: Int, text: String) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/plain", body: Data(text.utf8))
    }

    private func errorMessage(_ error: Error) -> String {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        return message + "\n"
    }
}

private struct GoalRunResponse: Encodable {
    let status: String
    let goal: String
    let commandCount: Int
    let traceCount: Int
    let state: WorldState
}
