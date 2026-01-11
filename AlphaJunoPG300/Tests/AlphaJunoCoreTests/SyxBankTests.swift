import XCTest
@testable import AlphaJunoCore

final class SyxBankTests: XCTestCase
{
    func testAcceptance_NewBank1StructureAndFirst8Names() throws
    {
        let bytes = try loadFixtureBytes(named: "NEWBANK1.SYX")
        let messages = try SyxBank.splitSyxMessages(bytes)

        XCTAssertEqual(messages.count, 16)
        for (i, msg) in messages.enumerated()
        {
            XCTAssertEqual(msg.count, 266, "message \(i) length")
            XCTAssertEqual(msg.first, 0xF0)
            XCTAssertEqual(msg.last, 0xF7)
            XCTAssertEqual(msg[8], UInt8(i * 4), "startToneIndex \(i)")
        }

        let bank = try SyxBank.parseBankFileBytes(bytes)
        XCTAssertEqual(bank.tones.count, 64)

        let expected =
        [
            "LONG Bass",
            "BUZZ Bass",
            "BUZZ Bass2",
            "LONG Bass2",
            "LONG Bass3",
            "BUZZ Bass3",
            "BOING Bass",
            "SYN Bass"
        ]

        for i in 0..<8
        {
            XCTAssertEqual(bank.tones[i].name, expected[i], "tone \(i + 1) name")
        }
    }

    func testAcceptance_ToneNameEncodeDecodeRoundtrip() throws
    {
        let bytes = try loadFixtureBytes(named: "NEWBANK1.SYX")
        var bank = try SyxBank.parseBankFileBytes(bytes)

        XCTAssertEqual(bank.tones[0].name, "LONG Bass")

        try bank.tones[0].setName("STRINGS")
        let outBytes = try bank.encodeBankFileBytes()

        let bank2 = try SyxBank.parseBankFileBytes(outBytes)
        XCTAssertEqual(bank2.tones[0].name, "STRINGS")
    }
}

private func loadFixtureBytes(named name: String) throws -> [UInt8]
{
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil))
    let data = try Data(contentsOf: url)
    return Array(data)
}

