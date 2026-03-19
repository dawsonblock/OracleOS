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

    func test_http_router_returns_state_payload_for_goal_post() {
        let runtime = makeRuntime()
        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "POST",
            target: "/goal",
            path: "/goal",
            queryItems: [:],
            headers: [:],
            body: "write file a.txt hello"
        )

        let response = router.handle(request, runtime: runtime)
        let body = String(data: response.body, encoding: .utf8)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.contentType, "application/json")
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
            target: "/events?limit=1",
            path: "/events",
            queryItems: ["limit": "1"],
            headers: [:],
            body: ""
        )

        let response = router.handle(request, runtime: runtime)
        let decoder = JSONDecoder()
        let envelopes = try decoder.decode([EventEnvelope].self, from: response.body)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(envelopes.count, 1)
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
