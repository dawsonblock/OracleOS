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
            let state = try runtime.run(goal: Goal(text: goalText))

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        }
    }
}
