import Foundation
import XCTest

final class RepoContainmentTests: XCTestCase {
    func test_no_non_swift_runtime_files_in_sources() throws {
        let root = ScanSupport.repositoryRoot().appendingPathComponent("Sources", isDirectory: true)
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var offenders: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.hasDirectoryPath || url.pathExtension == "swift" {
                continue
            }
            offenders.append(url.path.replacingOccurrences(of: ScanSupport.repositoryRoot().path + "/", with: ""))
        }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }
}
