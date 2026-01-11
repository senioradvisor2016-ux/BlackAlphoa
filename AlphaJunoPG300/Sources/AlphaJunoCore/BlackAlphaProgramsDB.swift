import Foundation

#if canImport(SQLite3)
import SQLite3

public enum BlackAlphaProgramsDB
{
    public struct Program: Equatable, Sendable
    {
        public var id: Int
        public var name: String
        public var category: String?
        public var author: String?
        public var rating: Int?
        public var favorite: Bool
        public var notes: String?
        public var programData: [UInt8]
        public var dateCreated: String?
    }

    public static func load(url: URL) throws -> [Program]
    {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw Error.openFailed }
        defer { sqlite3_close(db) }

        let sql = "SELECT Id, Name, Category, Author, Rating, Favorite, Notes, ProgramData, DateCreated FROM Programs ORDER BY Id;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw Error.queryFailed }
        defer { sqlite3_finalize(stmt) }

        var out: [Program] = []
        while sqlite3_step(stmt) == SQLITE_ROW
        {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = columnText(stmt, 1) ?? ""
            let category = columnText(stmt, 2)
            let author = columnText(stmt, 3)
            let rating = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
            let favorite = sqlite3_column_int(stmt, 5) != 0
            let notes = columnText(stmt, 6)
            let programData = columnBlob(stmt, 7)
            let dateCreated = columnText(stmt, 8)

            out.append(Program(id: id,
                               name: name,
                               category: category,
                               author: author,
                               rating: rating,
                               favorite: favorite,
                               notes: notes,
                               programData: programData,
                               dateCreated: dateCreated))
        }

        return out
    }

    public static func save(url: URL, programs: [Program]) throws
    {
        _ = try? FileManager.default.removeItem(at: url)

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw Error.openFailed }
        defer { sqlite3_close(db) }

        let schema = """
        CREATE TABLE Programs (
            Id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            Name VARCHAR(40) NOT NULL COLLATE NOCASE,
            Category VARCHAR(40) COLLATE NOCASE,
            Author VARCHAR(100),
            Rating INTEGER,
            Favorite INTEGER,
            Notes VARCHAR(200) NULL COLLATE NOCASE,
            ProgramData BLOB NOT NULL,
            DateCreated TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        );
        """
        guard sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK else { throw Error.schemaFailed }

        let ins = "INSERT INTO Programs (Id, Name, Category, Author, Rating, Favorite, Notes, ProgramData, DateCreated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, ins, -1, &stmt, nil) == SQLITE_OK else { throw Error.queryFailed }
        defer { sqlite3_finalize(stmt) }

        for p in programs
        {
            sqlite3_reset(stmt)
            sqlite3_bind_int(stmt, 1, Int32(p.id))
            sqlite3_bind_text(stmt, 2, p.name, -1, SQLITE_TRANSIENT)

            bindText(stmt, 3, p.category)
            bindText(stmt, 4, p.author)

            if let rating = p.rating { sqlite3_bind_int(stmt, 5, Int32(rating)) } else { sqlite3_bind_null(stmt, 5) }
            sqlite3_bind_int(stmt, 6, p.favorite ? 1 : 0)
            bindText(stmt, 7, p.notes)

            p.programData.withUnsafeBytes { buf in
                sqlite3_bind_blob(stmt, 8, buf.baseAddress, Int32(buf.count), SQLITE_TRANSIENT)
            }

            bindText(stmt, 9, p.dateCreated)

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw Error.insertFailed }
        }
    }

    // MARK: - helpers

    private static func columnText(_ stmt: OpaquePointer?, _ idx: Int32) -> String?
    {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let cstr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cstr)
    }

    private static func columnBlob(_ stmt: OpaquePointer?, _ idx: Int32) -> [UInt8]
    {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let ptr = sqlite3_column_blob(stmt, idx) else { return [] }
        let n = Int(sqlite3_column_bytes(stmt, idx))
        let buf = ptr.bindMemory(to: UInt8.self, capacity: n)
        return Array(UnsafeBufferPointer(start: buf, count: n))
    }

    private static func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?)
    {
        if let value
        {
            sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
        }
        else
        {
            sqlite3_bind_null(stmt, idx)
        }
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case openFailed
        case schemaFailed
        case queryFailed
        case insertFailed

        public var description: String
        {
            switch self
            {
            case .openFailed: return "Failed to open SQLite database."
            case .schemaFailed: return "Failed to create Programs schema."
            case .queryFailed: return "SQLite query failed."
            case .insertFailed: return "SQLite insert failed."
            }
        }
    }
}

#else

public enum BlackAlphaProgramsDB {}

#endif

