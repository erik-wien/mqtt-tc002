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
}
