import Core
import Foundation
import Interface

@main
enum App {
    static func main() throws {
        let runtime = Bootstrap.makeRuntime()

        switch CLIArgumentParser.parse(CommandLine.arguments) {
        case let .server(port):
            let server = HTTPServer(runtime: runtime)
            try server.start(port: port)
            RunLoop.main.run()
        case let .goal(text):
            let goalText = text.isEmpty ? "write file runtime-goal.log runtime bootstrapped" : text
            let result = try runtime.runResult(goal: Goal(text: goalText))
            let output = CLIOutput(
                status: result.success ? "ok" : "degraded",
                success: result.success,
                goal: goalText,
                issues: result.issues,
                emittedEventCount: result.emittedEventCount,
                summary: RuntimeViewBuilder.stateSummary(from: result.state),
                state: result.state
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        }
    }
}

private struct CLIOutput: Encodable {
    let status: String
    let success: Bool
    let goal: String
    let issues: [String]
    let emittedEventCount: Int
    let summary: RuntimeStateSummary
    let state: WorldState
}
