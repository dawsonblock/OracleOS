import Foundation

// ─────────────────────────────────────────────────────────
// CandidateResult — verified outcome of executing a candidate
//
// After the executor runs a candidate, the critic evaluates
// the result. This struct captures the full outcome so the
// ResultSelector can compare candidates deterministically.
// ─────────────────────────────────────────────────────────

/// The verified outcome of executing one Candidate.
public struct CandidateResult: Identifiable {

    public let id: String
    /// The candidate that was executed.
    public let candidate: Candidate
    /// Whether the candidate's postconditions were satisfied.
    public let success: Bool
    /// Composite score used for ranking (higher is better).
    public let score: Double
    /// The critic verdict from evaluation.
    public let criticVerdict: CriticVerdict
    /// Execution latency in milliseconds.
    public let elapsedMs: Double
    /// Optional notes from the critic or executor.
    public let notes: [String]

    public init(
        id: String = UUID().uuidString,
        candidate: Candidate,
        success: Bool,
        score: Double,
        criticVerdict: CriticVerdict,
        elapsedMs: Double = 0,
        notes: [String] = []
    ) {
        self.id = id
        self.candidate = candidate
        self.success = success
        self.score = score
        self.criticVerdict = criticVerdict
        self.elapsedMs = elapsedMs
        self.notes = notes
    }
}
