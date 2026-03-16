import Foundation

public struct ProjectMemoryDraft: Sendable, Equatable {
    public let kind: ProjectMemoryKind
    public let knowledgeClass: KnowledgeClass
    public let title: String
    public let summary: String
    public let affectedModules: [String]
    public let evidenceRefs: [String]
    public let sourceTraceIDs: [String]
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        kind: ProjectMemoryKind,
        knowledgeClass: KnowledgeClass,
        title: String,
        summary: String,
        affectedModules: [String] = [],
        evidenceRefs: [String] = [],
        sourceTraceIDs: [String] = [],
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.knowledgeClass = knowledgeClass
        self.title = title
        self.summary = summary
        self.affectedModules = affectedModules
        self.evidenceRefs = evidenceRefs
        self.sourceTraceIDs = sourceTraceIDs
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public final class ProjectMemoryStore: @unchecked Sendable {
    public let projectRootURL: URL
    public let rootURL: URL
    public let databaseURL: URL
    public let draftsURL: URL
    public let residueURL: URL
    private let indexer: ProjectMemoryIndexer

    public init(projectRootURL: URL) throws {
        self.projectRootURL = projectRootURL
        self.rootURL = Self.rootURL(for: projectRootURL)
        self.databaseURL = Self.databaseURL(for: projectRootURL)
        self.draftsURL = Self.draftsURL(for: projectRootURL)
        self.residueURL = Self.residueURL(for: projectRootURL)
        self.indexer = try ProjectMemoryIndexer(databaseURL: databaseURL)
        try ensureRuntimeStructure()
    }

    public static func rootURL(for projectRootURL: URL) -> URL {
        projectRootURL.appendingPathComponent("ProjectMemory", isDirectory: true)
    }

    public static func databaseURL(for projectRootURL: URL) -> URL {
        projectRootURL.appendingPathComponent(".oracle", isDirectory: true).appendingPathComponent("project-memory.sqlite3", isDirectory: false)
    }

    public static func residueURL(for projectRootURL: URL) -> URL {
        projectRootURL.appendingPathComponent(".oracle", isDirectory: true).appendingPathComponent("project-memory-episode", isDirectory: true)
    }

    public static func draftsURL(for projectRootURL: URL) -> URL {
        projectRootURL.appendingPathComponent(".oracle", isDirectory: true).appendingPathComponent("project-memory-drafts", isDirectory: true)
    }

    public func ensureStructure() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        for kind in ProjectMemoryKind.allCases where kind != .risk {
            try FileManager.default.createDirectory(at: rootURL.appendingPathComponent(kind.directoryName, isDirectory: true), withIntermediateDirectories: true)
        }
    }

    public func ensureRuntimeStructure() throws {
        try FileManager.default.createDirectory(at: draftsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: residueURL, withIntermediateDirectories: true)
    }

    public func syncIndex() {
        indexer.rebuild(from: [rootURL, draftsURL])
    }

    public func writeDraft(_ draft: ProjectMemoryDraft) throws -> ProjectMemoryRef {
        try ensureRuntimeStructure()
        let fileURL = draft.knowledgeClass == .episode ? residueFileURL(for: draft) : draftFileURL(for: draft)
        let record = ProjectMemoryRecord(
            id: fileURL.deletingPathExtension().lastPathComponent,
            kind: draft.kind,
            knowledgeClass: draft.knowledgeClass,
            status: .draft,
            title: draft.title,
            summary: draft.summary,
            path: fileURL.path,
            affectedModules: draft.affectedModules,
            evidenceRefs: draft.evidenceRefs,
            sourceTraceIDs: draft.sourceTraceIDs,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt
        )
        let markdown = renderMarkdown(for: draft, id: fileURL.deletingPathExtension().lastPathComponent)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        if draft.knowledgeClass != .episode {
            indexer.upsert(record)
        }
        return record.ref
    }

    public func writeOpenProblemDraft(title: String, summary: String, knowledgeClass: KnowledgeClass, affectedModules: [String] = [], evidenceRefs: [String] = [], sourceTraceIDs: [String] = [], body: String) throws -> ProjectMemoryRef {
        try writeDraft(ProjectMemoryDraft(kind: .openProblem, knowledgeClass: knowledgeClass, title: title, summary: summary, affectedModules: affectedModules, evidenceRefs: evidenceRefs, sourceTraceIDs: sourceTraceIDs, body: body))
    }

    public func writeRejectedApproachDraft(title: String, summary: String, knowledgeClass: KnowledgeClass, affectedModules: [String] = [], evidenceRefs: [String] = [], sourceTraceIDs: [String] = [], body: String) throws -> ProjectMemoryRef {
        try writeDraft(ProjectMemoryDraft(kind: .rejectedApproach, knowledgeClass: knowledgeClass, title: title, summary: summary, affectedModules: affectedModules, evidenceRefs: evidenceRefs, sourceTraceIDs: sourceTraceIDs, body: body))
    }

    public func writeKnownGoodPatternDraft(title: String, summary: String, knowledgeClass: KnowledgeClass, affectedModules: [String] = [], evidenceRefs: [String] = [], sourceTraceIDs: [String] = [], body: String) throws -> ProjectMemoryRef {
        try writeDraft(ProjectMemoryDraft(kind: .knownGoodPattern, knowledgeClass: knowledgeClass, title: title, summary: summary, affectedModules: affectedModules, evidenceRefs: evidenceRefs, sourceTraceIDs: sourceTraceIDs, body: body))
    }

    public func writeArchitectureDecisionDraft(title: String, summary: String, knowledgeClass: KnowledgeClass, affectedModules: [String] = [], evidenceRefs: [String] = [], sourceTraceIDs: [String] = [], body: String) throws -> ProjectMemoryRef {
        try writeDraft(ProjectMemoryDraft(kind: .architectureDecision, knowledgeClass: knowledgeClass, title: title, summary: summary, affectedModules: affectedModules, evidenceRefs: evidenceRefs, sourceTraceIDs: sourceTraceIDs, body: body))
    }

    public func writeRiskDraft(title: String, summary: String, knowledgeClass: KnowledgeClass, affectedModules: [String] = [], evidenceRefs: [String] = [], sourceTraceIDs: [String] = [], body: String) throws -> ProjectMemoryRef {
        try writeDraft(ProjectMemoryDraft(kind: .risk, knowledgeClass: knowledgeClass, title: title, summary: summary, affectedModules: affectedModules, evidenceRefs: evidenceRefs, sourceTraceIDs: sourceTraceIDs, body: body))
    }

    public func query(text: String, modules: [String] = [], kinds: [ProjectMemoryKind] = [], limit: Int = 10) -> [ProjectMemoryRef] {
        indexer.query(text: text, modules: modules, kinds: kinds, limit: limit)
    }

    public func allRecords(includeEpisodeResidue: Bool = false) -> [ProjectMemoryRecord] {
        let roots = includeEpisodeResidue ? [rootURL, draftsURL, residueURL] : [rootURL, draftsURL]
        let fileManager = FileManager.default
        var records: [ProjectMemoryRecord] = []

        for root in roots {
            guard fileManager.fileExists(atPath: root.path),
                  let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
                continue
            }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "md" {
                guard let record = ProjectMemoryIndexer.parseRecord(fileURL: fileURL) else { continue }
                if !includeEpisodeResidue, record.knowledgeClass == .episode { continue }
                records.append(record)
            }
        }

        return records.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.id < rhs.id }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func residueFileURL(for draft: ProjectMemoryDraft) -> URL {
        let datePrefix = ISO8601DateFormatter().string(from: draft.createdAt).replacingOccurrences(of: ":", with: "-")
        let slug = slugify(draft.title)
        return residueURL.appendingPathComponent("\(datePrefix)-\(slug).md", isDirectory: false)
    }

    private func draftFileURL(for draft: ProjectMemoryDraft) -> URL {
        let datePrefix = ISO8601DateFormatter().string(from: draft.createdAt).replacingOccurrences(of: ":", with: "-")
        let slug = slugify(draft.title)
        let directory = draftsURL.appendingPathComponent(draft.kind.directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(datePrefix)-\(slug).md", isDirectory: false)
    }

    private func renderMarkdown(for draft: ProjectMemoryDraft, id: String) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            "# \(draft.kind.titlePrefix): \(draft.title)",
            "id: \(id)",
            "kind: \(draft.kind.rawValue)",
            "knowledge_class: \(draft.knowledgeClass.rawValue)",
            "status: \(ProjectMemoryStatus.draft.rawValue)",
            "summary: \(draft.summary)",
            "created_at: \(formatter.string(from: draft.createdAt))",
            "updated_at: \(formatter.string(from: draft.updatedAt))",
            "affected_modules: \(draft.affectedModules.joined(separator: ", "))",
            "evidence_refs: \(draft.evidenceRefs.joined(separator: ", "))",
            "source_trace_ids: \(draft.sourceTraceIDs.joined(separator: ", "))",
            "",
            "## Details",
            draft.body,
            "",
        ].joined(separator: "\n")
    }

    private func slugify(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
