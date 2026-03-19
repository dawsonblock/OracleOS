import Foundation

enum ScanSupport {
    static func repositoryRoot(filePath: String = #filePath) -> URL {
        var url = URL(fileURLWithPath: filePath).deletingLastPathComponent()

        while true {
            let manifest = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: manifest.path) {
                return url
            }

            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                return url
            }
            url = parent
        }
    }

    static func swiftFiles(in relativeDirectories: [String]) throws -> [URL] {
        try relativeDirectories.flatMap { relativeDirectory in
            let directory = repositoryRoot().appendingPathComponent(relativeDirectory, isDirectory: true)
            guard FileManager.default.fileExists(atPath: directory.path) else {
                return []
            }

            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            var result: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "swift" {
                    result.append(fileURL)
                }
            }
            return result
        }
    }

    static func scan(
        patterns: [String],
        including: [String] = ["Sources"],
        excluding: [String] = []
    ) throws -> [String] {
        let files = try swiftFiles(in: including)
        var hits: [String] = []

        for fileURL in files {
            let relativePath = fileURL.path.replacingOccurrences(of: repositoryRoot().path + "/", with: "")
            if excluding.contains(where: { relativePath.contains($0) }) {
                continue
            }

            let text = try String(contentsOf: fileURL, encoding: .utf8)
            for pattern in patterns where text.range(of: pattern, options: .regularExpression) != nil {
                hits.append("\(relativePath) -> \(pattern)")
            }
        }

        return hits.sorted()
    }

    static func importedModules(in relativeDirectories: [String]) throws -> [String: [String]] {
        let files = try swiftFiles(in: relativeDirectories)
        var result: [String: [String]] = [:]

        for fileURL in files {
            let relativePath = fileURL.path.replacingOccurrences(of: repositoryRoot().path + "/", with: "")
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let modules = text
                .split(separator: "\n")
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("import ") else {
                        return nil
                    }
                    return String(trimmed.dropFirst("import ".count))
                }
            result[relativePath] = modules
        }

        return result
    }
}
