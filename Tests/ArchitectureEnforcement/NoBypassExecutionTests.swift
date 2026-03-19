import Core
import XCTest

final class NoBypassExecutionTests: XCTestCase {
    func test_only_loop_calls_executor() throws {
        let offenders = try ScanSupport.scan(
            patterns: ["\\.execute\\("],
            excluding: ["Sources/Core/Loop/AgentLoop.swift"]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }
}
