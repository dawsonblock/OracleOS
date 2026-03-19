import Core
import Interface
import XCTest

final class InterfaceContractTests: XCTestCase {
    func test_cli_argument_parser_understands_server_flags() {
        let command = CLIArgumentParser.parse(["oracle-runtime", "--server", "--port", "9090"])
        XCTAssertEqual(command, .server(port: 9090))
    }

    func test_cli_argument_parser_understands_explicit_goal_flag() {
        let command = CLIArgumentParser.parse(["oracle-runtime", "--goal", "write file a.txt hello"])
        XCTAssertEqual(command, .goal("write file a.txt hello"))
    }

    func test_http_request_parser_extracts_path_query_headers_and_body() {
        let request = HTTPRequestParser.parse("POST /events?limit=25 HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\nX-Test: runtime\r\n\r\nhello world")

        XCTAssertEqual(request?.method, "POST")
        XCTAssertEqual(request?.path, "/events")
        XCTAssertEqual(request?.queryItems["limit"], "25")
        XCTAssertEqual(request?.headers["host"], "localhost")
        XCTAssertEqual(request?.headers["x-test"], "runtime")
        XCTAssertEqual(request?.body, "hello world")
    }

    func test_http_request_parser_rejects_truncated_body() {
        let request = HTTPRequestParser.parse("POST /goal HTTP/1.1\r\nContent-Length: 5\r\n\r\nhi")
        XCTAssertNil(request)
    }

    func test_http_request_parser_detects_incomplete_request() {
        XCTAssertFalse(HTTPRequestParser.isCompleteRequest("POST /goal HTTP/1.1\r\nContent-Length: 5\r\n\r\nhi"))
        XCTAssertTrue(HTTPRequestParser.isCompleteRequest("POST /goal HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello"))
    }

    func test_http_router_returns_state_payload_for_goal_post() {
        let runtime = makeRuntime()
        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "POST",
            path: "/goal",
            queryItems: [:],
            headers: [:],
            body: "write file a.txt hello"
        )

        let response = router.handle(request, runtime: runtime)
        let body = String(data: response.body, encoding: .utf8)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.contentType, "application/json")
        XCTAssertTrue(body?.contains("\"success\" : true") ?? false)
        XCTAssertTrue(body?.contains("\"goal\" : \"write file a.txt hello\"") ?? false)
        XCTAssertTrue(body?.contains("\"a.txt\"") ?? false)
    }

    func test_http_router_clamps_event_limit() throws {
        let runtime = makeRuntime()
        _ = try runtime.run(goal: Goal(text: "write file a.txt one"))
        _ = try runtime.run(goal: Goal(text: "write file b.txt two"))

        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "GET",
            path: "/events",
            queryItems: ["limit": "1"],
            headers: [:],
            body: ""
        )

        let response = router.handle(request, runtime: runtime)
        let decoder = JSONDecoder()
        let body = try decoder.decode(EventListBody.self, from: response.body)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body.events.count, 1)
        XCTAssertTrue(body.events[0].summary.contains("wrote"))
        XCTAssertTrue(body.events[0].success)
    }

    func test_http_router_surfaces_failure_details_for_blocked_goal() {
        let runtime = makeRuntime()
        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "POST",
            path: "/goal",
            queryItems: [:],
            headers: [:],
            body: "write file ../escape.txt blocked"
        )

        let response = router.handle(request, runtime: runtime)
        let body = String(data: response.body, encoding: .utf8)

        XCTAssertEqual(response.status, 200)
        XCTAssertTrue(body?.contains("\"status\" : \"degraded\"") ?? false)
        XCTAssertTrue(body?.contains("\"success\" : false") ?? false)
        XCTAssertTrue(body?.contains("File commands must stay within the workspace root") ?? false)
        XCTAssertTrue(body?.contains("\"failureCount\" : 1") ?? false)
    }

    func test_http_router_state_view_includes_summary() throws {
        let runtime = makeRuntime()
        _ = try runtime.run(goal: Goal(text: "write file a.txt hello"))

        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "GET",
            path: "/state",
            queryItems: [:],
            headers: [:],
            body: ""
        )

        let response = router.handle(request, runtime: runtime)
        let decoder = JSONDecoder()
        let body = try decoder.decode(StateViewBody.self, from: response.body)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(body.summary.fileCount, 1)
        XCTAssertEqual(body.summary.failureCount, 0)
        XCTAssertEqual(body.summary.lastHTTPResponseStatus, 0)
        XCTAssertEqual(body.state.files["a.txt"], "hello")
    }

    func test_http_router_event_view_surfaces_failure_summary() throws {
        let runtime = makeRuntime()
        _ = try runtime.runResult(goal: Goal(text: "write file ../escape.txt blocked"))

        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "GET",
            path: "/events",
            queryItems: [:],
            headers: [:],
            body: ""
        )

        let response = router.handle(request, runtime: runtime)
        let decoder = JSONDecoder()
        let body = try decoder.decode(EventListBody.self, from: response.body)

        XCTAssertEqual(response.status, 200)
        XCTAssertTrue(body.events.contains(where: { !$0.success && $0.summary.contains("workspace root") }))
    }

    private func makeRuntime() -> AgentRuntime {
        AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine()),
                store: InMemoryEventStore(),
                reducer: DefaultReducer(),
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )
    }
}

private struct EventListBody: Decodable {
    let count: Int
    let events: [RuntimeEventSummary]
}

private struct StateViewBody: Decodable {
    let summary: RuntimeStateSummary
    let state: WorldState
}
