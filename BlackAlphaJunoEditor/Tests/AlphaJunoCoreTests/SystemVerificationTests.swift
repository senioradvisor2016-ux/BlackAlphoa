import XCTest
@testable import AlphaJunoCore

final class SystemVerificationTests: XCTestCase
{
    func testPG300Parameters_AreCompleteAndUnique() throws
    {
        let params = PG300Parameters.all
        XCTAssertEqual(params.count, 36)

        let ids = params.map(\.id)
        XCTAssertEqual(Set(ids).count, 36, "Param IDs must be unique")

        XCTAssertEqual(ids.min(), 0x00)
        XCTAssertEqual(ids.max(), 0x23)

        // Ensure we have a full contiguous set 0x00..0x23
        for expected in UInt8(0x00)...UInt8(0x23)
        {
            XCTAssertTrue(ids.contains(expected), "Missing param id 0x\(String(expected, radix: 16))")
        }
    }

    func testFXBWriter_RoundtripNamesAndData() throws
    {
        let progs: [BlackAlphaFXB.Program] = (0..<64).map { i in
            .init(index: i, name: "P\(i)", data: "Data\(i)")
        }

        let bank = BlackAlphaFXBWriter.Bank(bankName: "Bank.0", programs: progs)
        let bytes = try BlackAlphaFXBWriter.buildFXBBytes(from: bank)

        let decoded = try BlackAlphaFXB.parsePrograms(fromVC2Bytes: bytes)
        XCTAssertEqual(decoded.count, 64)
        XCTAssertEqual(decoded[0].name, "P0")
        XCTAssertEqual(decoded[63].data, "Data63")
    }

    #if canImport(SQLite3)
    func testProgramsDB_SaveLoadRoundtrip() throws
    {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let programs: [BlackAlphaProgramsDB.Program] =
        [
            .init(id: 1,
                  name: "Prog 1",
                  category: "Bass",
                  author: "BlackAlpha",
                  rating: 5,
                  favorite: true,
                  notes: "Note",
                  programData: Array(0..<73).map { UInt8($0) },
                  dateCreated: "2026-01-11 00:00:00")
        ]

        try BlackAlphaProgramsDB.save(url: tmp, programs: programs)
        let loaded = try BlackAlphaProgramsDB.load(url: tmp)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, 1)
        XCTAssertEqual(loaded[0].name, "Prog 1")
        XCTAssertEqual(loaded[0].favorite, true)
        XCTAssertEqual(loaded[0].programData.count, 73)
    }
    #endif
}

