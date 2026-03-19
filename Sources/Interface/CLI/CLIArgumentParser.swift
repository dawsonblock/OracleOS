import Foundation

public enum CLICommand: Equatable {
    case server(port: UInt16)
    case goal(String)
}

public enum CLIArgumentParser {
    public static func parse(_ arguments: [String]) -> CLICommand {
        var port: UInt16 = 8080
        var goalParts: [String] = []
        var isServer = false

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--server":
                isServer = true
            case "--goal":
                if index + 1 < arguments.count {
                    goalParts.append(arguments[index + 1])
                    index += 1
                }
            case "--port":
                if index + 1 < arguments.count, let parsed = UInt16(arguments[index + 1]) {
                    port = parsed
                    index += 1
                }
            default:
                goalParts.append(argument)
            }
            index += 1
        }

        if isServer {
            return .server(port: port)
        }

        return .goal(goalParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
