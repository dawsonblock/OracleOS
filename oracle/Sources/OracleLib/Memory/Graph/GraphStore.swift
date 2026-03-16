import Foundation
import SQLite3

// ─────────────────────────────────────────────────────────
// GraphStore — canonical truth memory
//
// R2: Runtime memory is exactly three categories:
//   1. Trace — what happened (execution evidence)
//   2. Workflow — reusable successful patterns
//   3. Knowledge Graph — structured facts and relations
//
// GraphStore owns all three via SQLite.
// No additional long-lived memory stores allowed.
// ─────────────────────────────────────────────────────────

public final class GraphStore {

    private var db: OpaquePointer?
    private let path: String
    let compatibilityStorage = GraphCompatibilityStorage()

    public init(path: String = "data/graph.db") {
        self.path = path
    }

    // ── Lifecycle ───────────────────────────────────────

    public func initialize() {

        // Ensure data directory exists
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            print("[graph] Failed to open database at \(path)")
            return
        }

        createTables()
        print("[graph] Initialized at \(path)")
    }

    private func createTables() {

        let schemas = [
            // ── Trace: execution evidence ──
            """
            CREATE TABLE IF NOT EXISTS traces (
                id TEXT PRIMARY KEY,
                action_id TEXT NOT NULL,
                action_type TEXT NOT NULL,
                success INTEGER NOT NULL,
                detail TEXT,
                timestamp TEXT NOT NULL
            )
            """,

            // ── Nodes: graph entities ──
            """
            CREATE TABLE IF NOT EXISTS nodes (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                label TEXT NOT NULL,
                data TEXT,
                created_at TEXT NOT NULL
            )
            """,

            // ── Edges: graph relations ──
            """
            CREATE TABLE IF NOT EXISTS edges (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                target_id TEXT NOT NULL,
                relation TEXT NOT NULL,
                weight REAL DEFAULT 1.0,
                created_at TEXT NOT NULL,
                FOREIGN KEY(source_id) REFERENCES nodes(id),
                FOREIGN KEY(target_id) REFERENCES nodes(id)
            )
            """,

            // ── Workflows: reusable patterns ──
            """
            CREATE TABLE IF NOT EXISTS workflows (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                steps TEXT NOT NULL,
                success_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """,

            // ── Artifacts: stored objects ──
            """
            CREATE TABLE IF NOT EXISTS artifacts (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                content TEXT,
                metadata TEXT,
                task_id TEXT,
                created_at TEXT NOT NULL
            )
            """,

            // ── Goals: goal tracking ──
            """
            CREATE TABLE IF NOT EXISTS goals (
                id TEXT PRIMARY KEY,
                description TEXT NOT NULL,
                status TEXT DEFAULT 'active',
                created_at TEXT NOT NULL,
                completed_at TEXT
            )
            """,
        ]

        for sql in schemas {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                let err = errMsg.map { String(cString: $0) } ?? "unknown"
                print("[graph] Table creation error: \(err)")
                sqlite3_free(errMsg)
            }
        }
    }

    // ── Record execution result ─────────────────────────

    public func record(result: ExecutionResult, forAction action: ActionIntent) {
        let id = UUID().uuidString
        let ts = ISO8601DateFormatter().string(from: Date())
        let success: Int32 = result.success ? 1 : 0

        let sql = """
            INSERT INTO traces (id, action_id, action_type, success, detail, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (action.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (action.type as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 4, success)
        sqlite3_bind_text(stmt, 5, (result.detail as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (ts as NSString).utf8String, -1, nil)

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // ── Record goal ─────────────────────────────────────

    public func recordGoal(_ goal: Goal) {

        let ts = ISO8601DateFormatter().string(from: goal.createdAt)

        let sql = """
            INSERT OR IGNORE INTO goals (id, description, status, created_at)
            VALUES (?, ?, 'active', ?)
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (goal.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (goal.description as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (ts as NSString).utf8String, -1, nil)

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // ── Query recent traces ─────────────────────────────

    public func recentTraces(limit: Int = 20) -> [ExecutionTrace] {

        var results: [ExecutionTrace] = []

        let sql = "SELECT id, action_id, action_type, success, detail, timestamp FROM traces ORDER BY timestamp DESC LIMIT ?"
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return results }
        
        sqlite3_bind_int(stmt, 1, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? UUID().uuidString
            let actionId = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let actionType = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "unknown"
            let success = sqlite3_column_int(stmt, 3) == 1
            let detail = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
            
            // Note: Detail / timestamp are unused in the constructor currently
            // We shim a hash using the detail for now to fit the schema
            
            results.append(
                ExecutionTrace(
                    actionID: actionId,
                    actionType: actionType,
                    preStateHash: "pre_" + String((id + detail).hash),
                    postStateHash: "post_" + String((id + detail).hash),
                    verified: success,
                    success: success,
                    id: id
                )
            )
        }

        sqlite3_finalize(stmt)
        return results
    }

    // ── Node operations ─────────────────────────────────

    public func addNode(type: String, label: String, data: String = "") -> String {
        let id = UUID().uuidString
        let ts = ISO8601DateFormatter().string(from: Date())

        let sql = "INSERT INTO nodes (id, type, label, data, created_at) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return id }
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (type as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (label as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (data as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (ts as NSString).utf8String, -1, nil)

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return id
    }

    public func addEdge(source: String, target: String, relation: String, weight: Double = 1.0) {
        let id = UUID().uuidString
        let ts = ISO8601DateFormatter().string(from: Date())

        let sql = """
            INSERT INTO edges (id, source_id, target_id, relation, weight, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (source as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (target as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (relation as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, weight)
        sqlite3_bind_text(stmt, 6, (ts as NSString).utf8String, -1, nil)

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // ── Cleanup ─────────────────────────────────────────

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}
