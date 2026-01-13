import XCTest
@testable import AlphaJunoCore

final class SysExProtocolTests: XCTestCase
{
    func testSimpleOpcodes() throws
    {
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 1, op: .wsf), [0xF0, 0x41, 0x40, 0x00, 0x23, 0xF7])
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 16, op: .rqf), [0xF0, 0x41, 0x41, 0x0F, 0x23, 0xF7])
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 5, op: .ack), [0xF0, 0x41, 0x43, 0x04, 0x23, 0xF7])
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 5, op: .eof), [0xF0, 0x41, 0x45, 0x04, 0x23, 0xF7])
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 5, op: .err), [0xF0, 0x41, 0x4E, 0x04, 0x23, 0xF7])
        XCTAssertEqual(try SysExAlphaJuno.simple(channel: 5, op: .rjc), [0xF0, 0x41, 0x4F, 0x04, 0x23, 0xF7])
    }

    func testIPRMatchesSpec() throws
    {
        let msg = try SysExAlphaJuno.ipr(channel: 1, group: .tone, param: 0x23, value: 0x0C)
        XCTAssertEqual(msg, [0xF0, 0x41, 0x36, 0x00, 0x23, 0x20, 0x01, 0x23, 0x0C, 0xF7])
    }

    func testIPRBuilderBackwardsCompatible() throws
    {
        let msg = try SysExIPR.iprMessage(channel: 2, param: 0x00, value: 0x7F)
        XCTAssertEqual(msg, [0xF0, 0x41, 0x36, 0x01, 0x23, 0x20, 0x01, 0x00, 0x7F, 0xF7])
    }
}

