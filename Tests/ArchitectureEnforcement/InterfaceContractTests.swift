import Interface
import XCTest

final class InterfaceContractTests: XCTestCase {
    func test_cli_argument_parser_understands_server_flags() {
        let command = CLIArgumentParser.parse(["oracle-runtime", "--server", "--port", "9090"])
        XCTAssertEqual(command, .server(port: 9090))
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
}
