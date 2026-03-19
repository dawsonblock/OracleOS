import Core
import XCTest

final class ExecutionBoundaryTests: XCTestCase {
    func test_no_process_outside_executor() throws {
        let offenders = try ScanSupport.scan(
            patterns: ["Process\\(", "NSTask", "posix_spawn", "exec\\("],
            excluding: ["Sources/Core/Execution/VerifiedExecutor.swift"]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func test_no_filesystem_mutation_outside_reducers_or_executor() throws {
        let offenders = try ScanSupport.scan(
            patterns: ["FileManager\\.default\\.", "createFile", "removeItem", "write\\("],
            excluding: [
                "Sources/Core/Execution/VerifiedExecutor.swift",
                "Sources/Core/State/Reducer.swift",
            ]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func test_no_urlsession_outside_executor() throws {
        let offenders = try ScanSupport.scan(
            patterns: ["URLSession"],
            excluding: ["Sources/Core/Execution/VerifiedExecutor.swift"]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }
}
