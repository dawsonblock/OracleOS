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
            let state = try waitForRuntime {
                try await runtime.run(goal: Goal(text: goalText))
            }
            let payload = GoalRunResponse(
                status: "ok",
                success: true,
                goal: goalText,
                commandCount: state.executedCommandIDs.count,
                traceCount: state.executionTrace.count,
                emittedEventCount: state.executionTrace.count,
                issues: [],
                summary: RuntimeViewBuilder.stateSummary(from: state),
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
            let events = try runtime.recentEventSummaries(limit: safeLimit)
            return json(status: 200, EventListResponse(count: events.count, events: events))
        } catch {
            return plainText(status: 500, text: errorMessage(error))
        }
    }

    private func state(runtime: AgentRuntime) -> HTTPResponse {
        do {
            let state = try runtime.currentState()
            return json(status: 200, StateViewResponse(summary: RuntimeViewBuilder.stateSummary(from: state), state: state))
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

    private func waitForRuntime<T>(
        _ operation: @escaping @Sendable () async throws -> T
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = AsyncResultBox<T>()

        Task {
            do {
                box.result = .success(try await operation())
            } catch {
                box.result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()
        return try box.result!.get()
    }
}

private struct GoalRunResponse: Encodable {
    let status: String
    let success: Bool
    let goal: String
    let commandCount: Int
    let traceCount: Int
    let emittedEventCount: Int
    let issues: [String]
    let summary: RuntimeStateSummary
    let state: WorldState
}

private struct EventListResponse: Encodable {
    let count: Int
    let events: [RuntimeEventSummary]
}

private struct StateViewResponse: Encodable {
    let summary: RuntimeStateSummary
    let state: WorldState
}

private final class AsyncResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
