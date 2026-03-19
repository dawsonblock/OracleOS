import Core
import XCTest

final class PlannerPurityTests: XCTestCase {
    func test_planner_has_no_side_effect_calls() throws {
        let offenders = try ScanSupport.scan(
            patterns: ["Process\\(", "FileManager\\.default\\.", "URLSession"],
            including: ["Sources/Core/Planning"]
        )
        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func test_planner_returns_commands_only() {
        let planner = BasicPlanner()
        let commands = planner.plan(goal: Goal(text: "write file a.txt hello"), state: .empty)

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.type, "file.write")
        XCTAssertEqual(commands.first?.stringValue(for: "path"), "a.txt")
    }
}
