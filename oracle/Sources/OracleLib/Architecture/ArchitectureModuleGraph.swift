import Foundation

// MARK: - ArchitectureModuleGraph

public struct ArchitectureModuleGraph: Codable, Sendable, Equatable {
    /// Map from module name → set of dependency module names.
    public let modules: [String: Set<String>]

    public init(modules: [String: Set<String>] = [:]) {
        self.modules = modules
    }

    // MARK: - Module Name Inference

    /// Derives a logical module name from a workspace-relative file path.
    ///
    /// Examples:
    /// - `Sources/OracleOS/Agent/Planning/Foo.swift`  → `Agent/Planning`
    /// - `Sources/OracleOS/Core/Execution/Bar.swift`  → `Core/Execution`
    /// - `Sources/OracleOS/Runtime/OracleRuntime.swift` → `Runtime`
    /// - `Tests/OracleTests/FooTests.swift`           → `Tests/OracleTests`
    public static func moduleName(for path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count >= 3 else {
            return components.first ?? path
        }

        // Sources/<TargetName>/<Module>[/<SubModule>]/File.swift
        if components[0] == "Sources" {
            let rest = Array(components.dropFirst(2))        // drop Sources + target name
            if rest.count >= 2, ["Agent", "Core", "Learning"].contains(rest[0]) {
                return "\(rest[0])/\(rest[1])"
            }
            return rest.first ?? components[1]
        }

        // Tests/<SuiteName>/...
        if components[0] == "Tests", components.count >= 2 {
            return "\(components[0])/\(components[1])"
        }

        return components.prefix(2).joined(separator: "/")
    }

    // MARK: - Graph Builder

    /// Builds a module graph from a `RepositorySnapshot`.
    public static func build(from snapshot: RepositorySnapshot) -> ArchitectureModuleGraph {
        var modules: [String: Set<String>] = [:]

        // Seed modules from files
        for file in snapshot.files where !file.isDirectory {
            let module = moduleName(for: file.path)
            if modules[module] == nil { modules[module] = [] }
        }

        // Add edges from dependency graph
        for edge in snapshot.dependencyGraph.edges {
            let sourceModule = moduleName(for: edge.sourcePath)
            if let dep = inferredModule(for: edge.dependency, snapshot: snapshot),
               dep != sourceModule {
                modules[sourceModule, default: []].insert(dep)
            }
        }

        return ArchitectureModuleGraph(modules: modules)
    }

    private static func inferredModule(for dependency: String, snapshot: RepositorySnapshot) -> String? {
        if snapshot.files.contains(where: { $0.path.contains(dependency) }) {
            return moduleName(for: dependency)
        }
        let candidates = Set(snapshot.files.compactMap { file -> String? in
            let m = moduleName(for: file.path)
            return m.localizedCaseInsensitiveContains(dependency) ? m : nil
        })
        return candidates.sorted().first
    }
}
