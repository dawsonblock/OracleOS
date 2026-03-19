import Foundation

public struct PatchCandidate: Equatable {

    public let id: String
    public let targetFile: String
    public let diff: String
    public let score: Double

    public init(
        targetFile: String,
        diff: String,
        score: Double,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.targetFile = targetFile
        self.diff = diff
        self.score = score
    }
}
