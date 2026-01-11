import XCTest
@testable import AlphaJunoCore

final class BlackAlphaVC2Tests: XCTestCase
{
    func testVC2EncodeDecodeRoundtrip() throws
    {
        let xml = #"<Root foo="bar" ProgramName0="Test" ProgramData0="..." />"#
        let bytes = try VC2Container.encodeXML(xml)
        let xml2 = try VC2Container.decodeXML(from: bytes)
        XCTAssertEqual(xml2, xml)
    }

    func testBlackAlphaFXBParsePrograms() throws
    {
        var attrs: [String] = ["pluginVersion=\"2\""]
        for i in 0..<64
        {
            attrs.append("ProgramName\(i)=\"Name\(i)\"")
            attrs.append("ProgramData\(i)=\"Data\(i)\"")
        }
        let xml = "<VST.AU.Alpha.JUNO.EditorAllBanks \(attrs.joined(separator: " ")) />"
        let bytes = try VC2Container.encodeXML(xml)

        let programs = try BlackAlphaFXB.parsePrograms(fromVC2Bytes: bytes)
        XCTAssertEqual(programs.count, 64)
        XCTAssertEqual(programs[0].name, "Name0")
        XCTAssertEqual(programs[63].data, "Data63")
    }

    func testBlackAlphaRMSParsePrefs() throws
    {
        let xml = #"<Prefs Prefs_Midi_default_midi_channel="0" Prefs_Editor_knob_mode="4" Prefs_License_key="" />"#
        let bytes = try VC2Container.encodeXML(xml)
        let prefs = try BlackAlphaRMS.parsePrefs(fromVC2Bytes: bytes)
        XCTAssertEqual(prefs["Prefs_Midi_default_midi_channel"], "0")
        XCTAssertEqual(prefs["Prefs_Editor_knob_mode"], "4")
    }

    func testBlackAlphaProgramDataCodec_DBVariantTrailingDot() throws
    {
        // 54 bytes -> base64 72 chars; db variant appends trailing dot.
        let bytes = Array(0..<54).map { UInt8($0) }
        let s = BlackAlphaProgramDataCodec.encodeDBString(bytes: bytes)
        XCTAssertTrue(s.hasSuffix("."))
        let back = try BlackAlphaProgramDataCodec.decodeDBString(s)
        XCTAssertEqual(back, bytes)
    }

    func testBlackAlphaProgramDataCodec_FXBVariantNoTrailingDot() throws
    {
        let bytes = Array(0..<56).map { UInt8($0) }
        let s = BlackAlphaProgramDataCodec.encodeFXBString(bytes: bytes)
        XCTAssertFalse(s.hasSuffix("."))
        let back = try BlackAlphaProgramDataCodec.decodeFXBString(s)
        XCTAssertEqual(back, bytes)
    }
}

