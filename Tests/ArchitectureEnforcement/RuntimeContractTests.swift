import Core
import XCTest

final class RuntimeContractTests: XCTestCase {
    func test_command_resolver_normalizes_payloads() {
        let resolver = CommandResolver()
        let commands = resolver.normalize([
            Command(type: " File.Write ", payload: [:]),
            Command(type: "http.request", payload: ["url": "https://example.com", "method": "post"]),
        ])

        XCTAssertEqual(commands[0].type, "file.write")
        XCTAssertEqual(commands[0].payload["path"], "runtime-output.txt")
        XCTAssertEqual(commands[0].payload["content"], "")
        XCTAssertEqual(commands[1].payload["method"], "POST")
    }

    func test_in_memory_event_store_preserves_append_order() throws {
        let store = InMemoryEventStore()
        let command = Command(type: "file.write", payload: ["path": "a.txt", "content": "hello"])
        let events: [any DomainEvent] = [
            FileWriteRequestedEvent(commandID: command.id, path: "a.txt", content: "hello"),
            ShellExecutedEvent(commandID: command.id, command: "echo hi", output: "hi", status: 0),
        ]

        try store.append(events)
        let envelopes = try store.load()

        XCTAssertEqual(envelopes.count, 2)
        XCTAssertEqual(envelopes[0].commandID, command.id)
        XCTAssertEqual(envelopes[1].commandID, command.id)
    }
}
