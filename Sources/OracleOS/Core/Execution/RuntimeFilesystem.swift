import Foundation

public enum RuntimeFilesystem {
    public static func ensureDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public static func ensureDirectory(atPath path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    public static func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public static func isExecutableFile(atPath path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    public static func loadData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public static func loadData(atPath path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    public static func saveData(_ data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        try data.write(to: url, options: options)
    }

    public static func saveText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func append(_ data: Data, to fileURL: URL) throws {
        if !fileExists(atPath: fileURL.path) {
            try saveData(Data(), to: fileURL)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    public static func deleteItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public static func deleteItem(atPath path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    public static func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        try FileManager.default.copyItem(atPath: srcPath, toPath: dstPath)
    }

    public static func contentsOfDirectory(atPath path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }

    public static func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]? = nil) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)
    }
}
