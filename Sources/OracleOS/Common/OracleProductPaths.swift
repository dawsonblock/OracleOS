import Foundation

public enum OracleProductPaths {
    public static let productDirectoryName = "Oracle OS"

    private static let dataRootOverrideKey = "ORACLE_OS_DATA_ROOT"
    private static let logsOverrideKey = "ORACLE_OS_LOG_DIR"
    private static let recipesOverrideKey = "ORACLE_OS_RECIPES_DIR"
    private static let approvalsOverrideKey = "ORACLE_OS_APPROVALS_DIR"
    private static let graphOverrideKey = "ORACLE_OS_GRAPH_DB"
    private static let traceOverrideKey = "ORACLE_OS_TRACE_DIR"

    public static var dataRootDirectory: URL {
        if let override = environmentURL(for: dataRootOverrideKey, isDirectory: true) {
            return override
        }

        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupport.appendingPathComponent(productDirectoryName, isDirectory: true)
    }

    public static var logsDirectory: URL {
        if let override = environmentURL(for: logsOverrideKey, isDirectory: true) {
            return override
        }

        let logsRoot = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        return logsRoot
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(productDirectoryName, isDirectory: true)
    }

    public static var tracesRootDirectory: URL {
        if let override = environmentURL(for: traceOverrideKey, isDirectory: true) {
            return override
        }
        return dataRootDirectory.appendingPathComponent("Traces", isDirectory: true)
    }

    public static var traceSessionsDirectory: URL {
        tracesRootDirectory.appendingPathComponent("sessions", isDirectory: true)
    }

    public static var traceArtifactsDirectory: URL {
        tracesRootDirectory.appendingPathComponent("artifacts", isDirectory: true)
    }

    public static var recipesDirectory: URL {
        if let override = environmentURL(for: recipesOverrideKey, isDirectory: true) {
            return override
        }
        return dataRootDirectory.appendingPathComponent("Recipes", isDirectory: true)
    }

    public static var approvalsDirectory: URL {
        if let override = environmentURL(for: approvalsOverrideKey, isDirectory: true) {
            return override
        }
        return dataRootDirectory.appendingPathComponent("Approvals", isDirectory: true)
    }

    public static var projectMemoryDirectory: URL {
        dataRootDirectory.appendingPathComponent("ProjectMemory", isDirectory: true)
    }

    public static var experimentsDirectory: URL {
        dataRootDirectory.appendingPathComponent("Experiments", isDirectory: true)
    }

    public static var graphDirectory: URL {
        dataRootDirectory.appendingPathComponent("Graph", isDirectory: true)
    }

    public static var graphDatabaseURL: URL {
        if let override = environmentURL(for: graphOverrideKey, isDirectory: false) {
            return override
        }
        return graphDirectory.appendingPathComponent("oracleos.sqlite3", isDirectory: false)
    }

    public static var diagnosticsDirectory: URL {
        dataRootDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    public static var exportsDirectory: URL {
        dataRootDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    public static var visionInstallDirectory: URL {
        dataRootDirectory.appendingPathComponent("Vision", isDirectory: true)
    }

    public static var visionModelsDirectory: URL {
        visionInstallDirectory.appendingPathComponent("models", isDirectory: true)
    }

    public static var visionModelDirectory: URL {
        visionModelsDirectory.appendingPathComponent("ShowUI-2B", isDirectory: true)
    }

    public static var legacyVenvRootDirectory: URL {
        legacyOracleRootDirectory.appendingPathComponent("venv", isDirectory: true)
    }

    public static func legacyVenvExecutablePath(_ executable: String) -> String {
        legacyVenvRootDirectory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(executable, isDirectory: false)
            .path
    }

    public static var claudeBinaryCandidates: [String] {
        [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
    }

    public static var systemPythonCandidates: [String] {
        [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
    }

    public static var systemOracleBinaryCandidates: [String] {
        [
            "/opt/homebrew/bin/oracle",
            "/usr/local/bin/oracle",
        ]
    }

    public static var systemOracleVisionBinaryCandidates: [String] {
        [
            "/opt/homebrew/bin/oracle-vision",
            "/usr/local/bin/oracle-vision",
        ]
    }

    public static var homebrewRecipesDirectories: [String] {
        [
            "/opt/homebrew/share/oracle-os/recipes",
            "/usr/local/share/oracle-os/recipes",
        ]
    }

    public static var visionModelCandidateDirectories: [String] {
        [
            visionModelDirectory.path,
            "/opt/homebrew/share/oracle-os/models/ShowUI-2B",
            NSHomeDirectory() + "/.oracle-os/models/ShowUI-2B",
            NSHomeDirectory() + "/.oracle-os/models/llm/ShowUI-2B-bf16-8bit",
        ]
    }

    public static func oracleVisionBinaryCandidates(executableDirectory: String) -> [String] {
        [
            visionInstallDirectory.appendingPathComponent("oracle-vision", isDirectory: false).path,
            bundledVisionBootstrapDirectory?.appendingPathComponent("oracle-vision", isDirectory: false).path,
        ]
        .compactMap { $0 }
        + systemOracleVisionBinaryCandidates
        + [
            executableDirectory + "/oracle-vision",
            executableDirectory + "/../Infra/Sidecars/vision-sidecar/oracle-vision",
        ]
    }

    public static func visionServerScriptCandidates(executableDirectory: String) -> [String] {
        [
            visionInstallDirectory.appendingPathComponent("server.py", isDirectory: false).path,
            bundledVisionBootstrapDirectory?.appendingPathComponent("server.py", isDirectory: false).path,
            "/opt/homebrew/share/oracle-os/vision-sidecar/server.py",
            "/usr/local/share/oracle-os/vision-sidecar/server.py",
            executableDirectory + "/Infra/Sidecars/vision-sidecar/server.py",
            (executableDirectory as NSString).deletingLastPathComponent + "/Infra/Sidecars/vision-sidecar/server.py",
            ((executableDirectory as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent + "/Infra/Sidecars/vision-sidecar/server.py",
        ]
        .compactMap { $0 }
    }

    public static var visionPythonCandidates: [String] {
        [
            visionInstallDirectory
                .appendingPathComponent(".venv", isDirectory: true)
                .appendingPathComponent("bin", isDirectory: true)
                .appendingPathComponent("python3", isDirectory: false)
                .path,
            legacyVenvExecutablePath("python3"),
            systemPythonCandidates[0],
            systemPythonCandidates[1],
        ]
    }

    public static var legacyOracleRootDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".oracle-os", isDirectory: true)
    }

    public static var legacyRecipesDirectory: URL {
        legacyOracleRootDirectory.appendingPathComponent("recipes", isDirectory: true)
    }

    public static var legacyApprovalsDirectory: URL {
        legacyOracleRootDirectory.appendingPathComponent("approvals", isDirectory: true)
    }

    public static var legacyLogsDirectory: URL {
        legacyOracleRootDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    public static var legacyGraphDirectory: URL {
        legacyOracleRootDirectory.appendingPathComponent("graph", isDirectory: true)
    }

    public static var legacyVisionDirectory: URL {
        legacyOracleRootDirectory
    }

    public static var runningFromAppBundle: Bool {
        appBundleURL != nil
    }

    public static var bundledHelperURL: URL? {
        guard let appBundleURL else {
            return nil
        }

        let helper = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("OracleControllerHost", isDirectory: false)
        return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
    }

    public static var bundledSampleRecipesDirectory: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("SampleRecipes", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        if let developerRoot = developerProjectRoot {
            let bundled = developerRoot.appendingPathComponent("recipes", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        return nil
    }

    public static var bundledVisionBootstrapDirectory: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL
                .appendingPathComponent("VisionBootstrap", isDirectory: true)
                .appendingPathComponent("vision-sidecar", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        if let developerRoot = developerProjectRoot {
            let bundled = developerRoot.appendingPathComponent("Infra/Sidecars/vision-sidecar", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        return nil
    }

    public static var helpDocumentURL: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("Help.md", isDirectory: false)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        if let developerRoot = developerProjectRoot {
            let helpDoc = developerRoot.appendingPathComponent("docs/oracle-controller.md", isDirectory: false)
            if FileManager.default.fileExists(atPath: helpDoc.path) {
                return helpDoc
            }
            let readme = developerRoot.appendingPathComponent("README.md", isDirectory: false)
            if FileManager.default.fileExists(atPath: readme.path) {
                return readme
            }
        }

        return nil
    }

    public static var releaseNotesURL: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("ReleaseNotes.md", isDirectory: false)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        if let developerRoot = developerProjectRoot {
            let notes = developerRoot.appendingPathComponent("docs/release-notes.md", isDirectory: false)
            if FileManager.default.fileExists(atPath: notes.path) {
                return notes
            }
        }

        return nil
    }

    public static var buildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? OracleOS.version
    }

    public static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? OracleOS.version
    }

    public static var developerProjectRoot: URL? {
        let fileManager = FileManager.default
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true),
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.deletingLastPathComponent(),
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle.main.executableURL?.deletingLastPathComponent().deletingLastPathComponent(),
            Bundle.main.resourceURL,
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if let root = firstAncestor(containing: "Package.swift", from: candidate) {
                return root
            }
        }

        return nil
    }

    public static var appBundleURL: URL? {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.bundleURL,
            Bundle.main.executableURL,
            URL(fileURLWithPath: CommandLine.arguments[0]),
        ].compactMap { $0?.resolvingSymlinksInPath() }

        for candidate in candidates {
            if candidate.pathExtension == "app" {
                return candidate
            }

            var current = candidate
            if !current.hasDirectoryPath {
                current = current.deletingLastPathComponent()
            }
            while current.path != "/" {
                if current.pathExtension == "app", fileManager.fileExists(atPath: current.path) {
                    return current
                }
                current.deleteLastPathComponent()
            }
        }

        return nil
    }

    public static func ensureUserDirectories() throws {
        let directories = [
            dataRootDirectory,
            logsDirectory,
            tracesRootDirectory,
            traceSessionsDirectory,
            traceArtifactsDirectory,
            recipesDirectory,
            approvalsDirectory,
            projectMemoryDirectory,
            experimentsDirectory,
            graphDirectory,
            diagnosticsDirectory,
            exportsDirectory,
            visionInstallDirectory,
            visionModelsDirectory,
        ]

        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func environmentURL(for key: String, isDirectory: Bool) -> URL? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            return nil
        }
        return URL(
            fileURLWithPath: NSString(string: value).expandingTildeInPath,
            isDirectory: isDirectory
        )
    }

    private static func firstAncestor(containing fileName: String, from url: URL) -> URL? {
        let fileManager = FileManager.default
        var current = url.standardizedFileURL

        if !current.hasDirectoryPath {
            current = current.deletingLastPathComponent()
        }

        while current.path != "/" {
            if fileManager.fileExists(atPath: current.appendingPathComponent(fileName, isDirectory: false).path) {
                return current
            }
            current.deleteLastPathComponent()
        }

        return nil
    }
}
