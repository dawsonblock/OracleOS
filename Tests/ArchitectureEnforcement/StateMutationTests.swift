import Core
import XCTest

final class StateMutationTests: XCTestCase {
    func test_no_direct_worldstate_mutation_outside_reducers() throws {
        let offenders = try ScanSupport.scan(
            patterns: [
                "\\.files\\[[^\\]]+\\]\\s*=(?!=)",
                "\\.files\\.removeValue\\(",
                "\\.lastOutput\\s*=(?!=)",
                "\\.lastHTTPResponseSize\\s*=(?!=)",
            ],
            excluding: [
                "Sources/Core/State/Reducer.swift",
                "Sources/Core/State/WorldState.swift",
            ]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func test_no_direct_state_mutation() throws {
        try test_no_direct_worldstate_mutation_outside_reducers()
    }
}
