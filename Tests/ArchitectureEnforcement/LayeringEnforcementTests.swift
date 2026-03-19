import XCTest

final class LayeringEnforcementTests: XCTestCase {
    func test_core_does_not_import_interface_or_multiagent() throws {
        let imports = try ScanSupport.importedModules(in: ["Sources/Core"])
        let offenders = imports.compactMap { path, modules -> String? in
            let illegal = modules.filter { $0 == "Interface" || $0 == "MultiAgent" || $0 == "App" }
            return illegal.isEmpty ? nil : "\(path) -> \(illegal.joined(separator: ", "))"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }

    func test_core_only_imports_foundation_modules() throws {
        let allowed = Set(["Foundation", "FoundationNetworking"])
        let imports = try ScanSupport.importedModules(in: ["Sources/Core"])
        let offenders = imports.compactMap { path, modules -> String? in
            let illegal = modules.filter { !allowed.contains($0) }
            return illegal.isEmpty ? nil : "\(path) -> \(illegal.joined(separator: ", "))"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }

    func test_interface_only_imports_core_and_system_modules() throws {
        let allowed = Set(["Foundation", "Core", "Glibc", "Darwin"])
        let imports = try ScanSupport.importedModules(in: ["Sources/Interface"])
        let offenders = imports.compactMap { path, modules -> String? in
            let illegal = modules.filter { !allowed.contains($0) }
            return illegal.isEmpty ? nil : "\(path) -> \(illegal.joined(separator: ", "))"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }

    func test_multiagent_only_imports_core_and_foundation() throws {
        let allowed = Set(["Foundation", "Core"])
        let imports = try ScanSupport.importedModules(in: ["Sources/MultiAgent"])
        let offenders = imports.compactMap { path, modules -> String? in
            let illegal = modules.filter { !allowed.contains($0) }
            return illegal.isEmpty ? nil : "\(path) -> \(illegal.joined(separator: ", "))"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }

    func test_only_app_layer_imports_interface_module() throws {
        let imports = try ScanSupport.importedModules(in: ["Sources"])
        let offenders = imports.compactMap { path, modules -> String? in
            guard modules.contains("Interface"), !path.hasPrefix("Sources/App/") else {
                return nil
            }
            return "\(path) -> Interface"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }

    func test_app_only_imports_composition_modules() throws {
        let allowed = Set(["Foundation", "Core", "Interface"])
        let imports = try ScanSupport.importedModules(in: ["Sources/App"])
        let offenders = imports.compactMap { path, modules -> String? in
            let illegal = modules.filter { !allowed.contains($0) }
            return illegal.isEmpty ? nil : "\(path) -> \(illegal.joined(separator: ", "))"
        }

        XCTAssertTrue(offenders.isEmpty, offenders.sorted().joined(separator: "\n"))
    }
}
