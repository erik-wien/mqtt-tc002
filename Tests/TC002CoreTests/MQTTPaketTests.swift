import XCTest
@testable import TC002Core

final class MQTTPaketTests: XCTestCase {
    private func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    func testConnectEntsprichtDerAufzeichnung() {
        let paket = MQTTPaket.connect(clientID: "tc002-app", benutzer: "pixdeck",
                                      kennwort: "geheim", frist: 60)
        XCTAssertEqual(hex(paket),
            "102600044d51545404c2003c000974633030322d61707000077069786465636b000667656865696d")
    }

    func testPublishEntsprichtDerAufzeichnung() {
        let paket = MQTTPaket.publish(thema: "awtrix_a86b/custom/test", nutzlast: Data("HI".utf8))
        XCTAssertEqual(hex(paket),
            "301b00176177747269785f613836622f637573746f6d2f746573744849")
    }

    func testDisconnect() {
        XCTAssertEqual(hex(MQTTPaket.disconnect()), "e000")
    }

    /// Ueber 127 Bytes Restlaenge wird die Laenge mehrbytig kodiert.
    func testLangeNutzlastKodiertDieRestlaengeMehrbytig() {
        let lang = Data(repeating: 0x41, count: 200)
        let paket = MQTTPaket.publish(thema: "a", nutzlast: lang)
        XCTAssertEqual(paket[0], 0x30)
        XCTAssertEqual(paket[1], 0xcb)          // 203 & 0x7f | 0x80
        XCTAssertEqual(paket[2], 0x01)          // 203 >> 7
    }

    func testConnackCodeWirdGelesen() {
        XCTAssertEqual(MQTTPaket.connackCode(Data([0x20, 0x02, 0x00, 0x00])), 0)
        XCTAssertEqual(MQTTPaket.connackCode(Data([0x20, 0x02, 0x00, 0x04])), 4)
        XCTAssertNil(MQTTPaket.connackCode(Data([0x30, 0x02, 0x00, 0x00])))   // kein CONNACK
        XCTAssertNil(MQTTPaket.connackCode(Data([0x20])))                      // zu kurz
    }
}
