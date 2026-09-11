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

    /// Von Hand ausgerechnet: 0x82, Restlaenge, Paketkennung 0x0001, dann
    /// Laenge 0x0016 + "awtrix_a86b/customList" + Guetegrad 0x00.
    func testSubscribeIstVonHandNachgerechnet() {
        XCTAssertEqual(hex(MQTTPaket.subscribe(thema: "awtrix_a86b/customList", paketID: 1)),
            "821b000100166177747269785f613836622f637573746f6d4c69737400")
        XCTAssertEqual(hex(MQTTPaket.subscribe(thema: "awtrix_a86b/status", paketID: 2)),
            "8217000200126177747269785f613836622f73746174757300")
    }

    /// Auch das SUBSCRIBE kodiert seine Restlaenge mehrbytig, sobald sie ueber 127 geht.
    func testLangesThemaKodiertDieRestlaengeMehrbytig() {
        let paket = MQTTPaket.subscribe(thema: String(repeating: "a", count: 300), paketID: 7)
        XCTAssertEqual(hex(paket.prefix(5)), "82b1020007")
        XCTAssertEqual(paket.count, 308)
    }

    func testPingreq() {
        XCTAssertEqual(hex(MQTTPaket.pingreq()), "c000")
    }

    func testSubackWirdGelesen() {
        let angenommen = MQTTPaket.subackGelesen(Data([0x90, 0x03, 0x00, 0x07, 0x00]))
        XCTAssertEqual(angenommen?.paketID, 7)
        XCTAssertEqual(angenommen?.angenommen, true)

        let abgelehnt = MQTTPaket.subackGelesen(Data([0x90, 0x03, 0x00, 0x07, 0x80]))
        XCTAssertEqual(abgelehnt?.paketID, 7)
        XCTAssertEqual(abgelehnt?.angenommen, false)

        XCTAssertNil(MQTTPaket.subackGelesen(Data([0x20, 0x03, 0x00, 0x07, 0x00])))  // kein SUBACK
        XCTAssertNil(MQTTPaket.subackGelesen(Data([0x90, 0x03, 0x00])))              // zu kurz
    }

    /// Dieselbe Byte-Folge wie das gesendete PUBLISH aus der Aufzeichnung, nur
    /// andersherum gelesen.
    func testPublishWirdGelesen() {
        let roh = Data([0x30, 0x1b]) + Data("\u{0000}\u{0017}awtrix_a86b/custom/testHI".utf8)
        let gelesen = MQTTPaket.publishGelesen(roh)
        XCTAssertEqual(gelesen?.thema, "awtrix_a86b/custom/test")
        XCTAssertEqual(gelesen?.nutzlast, Data("HI".utf8))
    }

    /// Eine Nutzlast von 40 KB ist bei der Laufschrift nichts Ungewoehnliches —
    /// ihre Restlaenge braucht drei Bytes, und der Leser muss sie ueberspringen.
    func testRundlaufMitLangerNutzlast() {
        let nutzlast = Data(repeating: 0x7B, count: 40_000)
        let roh = MQTTPaket.publish(thema: "awtrix_a86b/customList", nutzlast: nutzlast)
        XCTAssertEqual(hex(roh.prefix(4)), "30d8b802")   // drei Laengenbytes
        let gelesen = MQTTPaket.publishGelesen(roh)
        XCTAssertEqual(gelesen?.thema, "awtrix_a86b/customList")
        XCTAssertEqual(gelesen?.nutzlast, nutzlast)
    }

    /// Eine leere Nutzlast ist kein Fehler, sondern der Loeschbefehl (§3.2) —
    /// und sie kommt genauso zurueck, wenn die Uhr sie weitermeldet.
    func testPublishOhneNutzlast() {
        let gelesen = MQTTPaket.publishGelesen(MQTTPaket.publish(thema: "a/b", nutzlast: Data()))
        XCTAssertEqual(gelesen?.thema, "a/b")
        XCTAssertEqual(gelesen?.nutzlast, Data())
    }

    func testUnvollstaendigesPublishGibtNichtsZurueck() {
        let roh = MQTTPaket.publish(thema: "awtrix_a86b/status", nutzlast: Data("online".utf8))
        XCTAssertNil(MQTTPaket.publishGelesen(roh.prefix(roh.count - 1)))
        XCTAssertNil(MQTTPaket.publishGelesen(Data([0x30])))
        XCTAssertNil(MQTTPaket.publishGelesen(Data([0x20, 0x02, 0x00, 0x00])))   // kein PUBLISH
    }

    func testConnackCodeWirdGelesen() {
        XCTAssertEqual(MQTTPaket.connackCode(Data([0x20, 0x02, 0x00, 0x00])), 0)
        XCTAssertEqual(MQTTPaket.connackCode(Data([0x20, 0x02, 0x00, 0x04])), 4)
        XCTAssertNil(MQTTPaket.connackCode(Data([0x30, 0x02, 0x00, 0x00])))   // kein CONNACK
        XCTAssertNil(MQTTPaket.connackCode(Data([0x20])))                      // zu kurz
    }
}
