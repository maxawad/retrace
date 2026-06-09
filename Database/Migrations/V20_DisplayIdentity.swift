import Foundation
import SQLCipher
import Shared

/// V20 Migration: persist display identity for multi-monitor capture.
/// `displayId` is the runtime CoreGraphics ID; `displayStableId` is the
/// hardware-derived key used to correlate the same monitor across hotplug.
struct V20_DisplayIdentity: Migration {
    let version = 20

    func migrate(db: OpaquePointer) async throws {
        Log.info("🖥️ Ensuring display identity columns...", category: .database)

        if !(try hasColumn(db: db, table: "frame", column: "displayId")) {
            try execute(db: db, sql: "ALTER TABLE frame ADD COLUMN displayId INTEGER;")
            Log.debug("✓ Added frame.displayId column")
        }

        if !(try hasColumn(db: db, table: "frame", column: "displayStableId")) {
            try execute(db: db, sql: "ALTER TABLE frame ADD COLUMN displayStableId TEXT;")
            Log.debug("✓ Added frame.displayStableId column")
        }

        if !(try hasColumn(db: db, table: "frame", column: "displayName")) {
            try execute(db: db, sql: "ALTER TABLE frame ADD COLUMN displayName TEXT;")
            Log.debug("✓ Added frame.displayName column")
        }

        if !(try hasColumn(db: db, table: "video", column: "displayStableId")) {
            try execute(db: db, sql: "ALTER TABLE video ADD COLUMN displayStableId TEXT;")
            Log.debug("✓ Added video.displayStableId column")
        }

        try execute(
            db: db,
            sql: """
                CREATE INDEX IF NOT EXISTS idx_frame_display_stable_created_at
                ON frame(displayStableId, createdAt)
                WHERE displayStableId IS NOT NULL;
                """
        )

        try execute(db: db, sql: "DROP INDEX IF EXISTS index_video_on_unfinalized_resolution;")
        try execute(
            db: db,
            sql: """
                CREATE INDEX IF NOT EXISTS index_video_on_unfinalized_display_resolution
                ON video(displayStableId, width, height, processingState)
                WHERE processingState = 1;
                """
        )

        Log.info("✅ V20 migration completed: display identity persisted", category: .database)
    }

    private func hasColumn(db: OpaquePointer, table: String, column: String) throws -> Bool {
        let sql = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.migrationFailed(
                version: version,
                underlying: "Failed to inspect table info: \(String(cString: sqlite3_errmsg(db)))"
            )
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }) else {
                continue
            }
            if name == column {
                return true
            }
        }

        return false
    }

    private func execute(db: OpaquePointer, sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)

        if result != SQLITE_OK {
            let errorMessage = errorPointer.flatMap { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorPointer)
            throw DatabaseError.migrationFailed(version: version, underlying: "SQL execution failed: \(errorMessage)")
        }
    }
}
