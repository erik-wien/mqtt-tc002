import XCTest
@testable import TC002Core

private final class MitschreibenderSender: NachrichtSendend {
    var gesendet: [(thema: String, nutzlast: String)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, String(data: nutzlast, encoding: .utf8) ?? ""))
    }
}

final class AnzeigenTests: XCTestCase {
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p")

    func testZeigenSchicktFrameAufDasRichtigeThema() throws {
        let sender = MitschreibenderSender()
        let anzeigen = Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b")
        try anzeigen.zeigen(Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")]),
                            auf: "notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "awtrix_a86b/custom/notiz")
        XCTAssertTrue(sender.gesendet.first?.nutzlast.contains("\"df\"") == true)
    }

    /// Loeschen heisst: leere Nutzlast auf dasselbe Thema.
    func testLoeschenSchicktLeereNutzlast() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b").loeschen("notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "awtrix_a86b/custom/notiz")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, "")
    }

    func testUmschaltenSchicktDenNamenAnSwitchDiyApp() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b").umschalten(auf: "notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "awtrix_a86b/switchDiyApp")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, "notiz")
    }

    func testNormalisierePraefixMitEinemSchrägstrich() throws {
        let sender1 = MitschreibenderSender()
        let sender2 = MitschreibenderSender()
        let frame = Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")])

        let a1 = Anzeigen(sender: sender1, zugang: zugang, praefix: "awtrix_a86b")
        let a2 = Anzeigen(sender: sender2, zugang: zugang, praefix: "awtrix_a86b/")

        try a1.zeigen(frame, auf: "notiz")
        try a2.zeigen(frame, auf: "notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)
        XCTAssertEqual(sender1.gesendet.first?.thema, "awtrix_a86b/custom/notiz")

        sender1.gesendet.removeAll()
        sender2.gesendet.removeAll()

        try a1.loeschen("notiz")
        try a2.loeschen("notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)

        sender1.gesendet.removeAll()
        sender2.gesendet.removeAll()

        try a1.umschalten(auf: "notiz")
        try a2.umschalten(auf: "notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)
    }

    func testNormalisierePraefixMitMehrerenSchrägstrichen() throws {
        let sender1 = MitschreibenderSender()
        let sender2 = MitschreibenderSender()
        let frame = Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")])

        let a1 = Anzeigen(sender: sender1, zugang: zugang, praefix: "awtrix_a86b")
        let a2 = Anzeigen(sender: sender2, zugang: zugang, praefix: "awtrix_a86b///")

        try a1.zeigen(frame, auf: "notiz")
        try a2.zeigen(frame, auf: "notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)
        XCTAssertEqual(sender1.gesendet.first?.thema, "awtrix_a86b/custom/notiz")

        sender1.gesendet.removeAll()
        sender2.gesendet.removeAll()

        try a1.loeschen("notiz")
        try a2.loeschen("notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)

        sender1.gesendet.removeAll()
        sender2.gesendet.removeAll()

        try a1.umschalten(auf: "notiz")
        try a2.umschalten(auf: "notiz")
        XCTAssertEqual(sender1.gesendet.first?.thema, sender2.gesendet.first?.thema)
    }
}
