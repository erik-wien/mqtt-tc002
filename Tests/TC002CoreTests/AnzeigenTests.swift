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

    /// Ein Rahmen, wie `Meldungsbau.rahmen` ihn baut: Text und Regler.
    private func rahmen(_ text: String = "hallo") -> Frame {
        Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: text)))
    }

    /// Die HTTP-Seite laeuft ueber denselben `URLProtocol`-Doppelgaenger wie
    /// `GeraetTests` — kein Netz, keine Uhr.
    private func httpAnzeigen() -> Anzeigen {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        return Anzeigen(geraet: Geraet(host: "10.0.0.1", sitzung: URLSession(configuration: k)))
    }

    override func setUp() {
        Doppelgaenger.antworten = [:]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
        Doppelgaenger.abfragen = [:]
        Doppelgaenger.methoden = [:]
        Doppelgaenger.pfade = []
    }

    // MARK: - Dieselbe Nutzlast, anderer Kanal

    /// Was ueber MQTT auf `<praefix>/cmd/apps/pushed/<name>` geht, geht ueber
    /// HTTP als Rumpf von `PUT /api/v1/apps/pushed/<name>` — Zeichen fuer
    /// Zeichen dasselbe. Der Rahmenbau kennt die Betriebsart nicht und darf
    /// sie nicht kennen; baute er fuer einen der beiden Wege etwas anderes,
    /// zeigte dieselbe Meldung je nach Einstellung etwas anderes.
    func testBeideKanaeleSchickenDieselbeNutzlast() throws {
        let sender = MitschreibenderSender()

        try Anzeigen(sender: sender, zugang: zugang, praefix: "wohnzimmer/uhr")
            .zeigen(rahmen(), auf: "meldung2")
        try httpAnzeigen().zeigen(rahmen(), auf: "meldung2")

        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/pushed/meldung2"],
                       sender.gesendet.first?.nutzlast)
        XCTAssertEqual(Doppelgaenger.methoden["/api/v1/apps/pushed/meldung2"], "PUT")
    }

    /// Ueber MQTT loescht die leere Nutzlast, ueber HTTP `DELETE` ohne Rumpf
    /// (`{}` auf `PUT` ist `422`).
    func testLoeschenGehtAufBeidenWegenAnders() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "wohnzimmer/uhr").loeschen("meldung2")
        try httpAnzeigen().loeschen("meldung2")

        XCTAssertEqual(sender.gesendet.first?.nutzlast, "", "über MQTT löscht die leere Nutzlast")
        XCTAssertEqual(Doppelgaenger.methoden["/api/v1/apps/meldung2"], "DELETE")
        XCTAssertNil(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/meldung2"])
    }

    func testUmschaltenGehtImHttpBetriebAnDenApiPfad() throws {
        try httpAnzeigen().umschalten(auf: "meldung2")
        XCTAssertEqual(Doppelgaenger.pfade, ["/api/v1/apps/active"])
        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/active"], #"{"name":"meldung2"}"#)
    }

    /// Der HTTP-Kanal quittiert, der MQTT-Kanal nicht — daran haengt, ob die
    /// Oberflaeche „angekommen" oder nur „abgeschickt" sagen darf.
    func testNurDerHttpKanalQuittiert() {
        XCTAssertTrue(httpAnzeigen().quittiert)
        XCTAssertFalse(Anzeigen(sender: MitschreibenderSender(), zugang: zugang, praefix: "p").quittiert)
    }

    // MARK: - Welcher Kanal fuer welche Uhr

    /// Die eine Stelle, an der aus einer Uhr ein Kanal wird — App, Werkzeug und
    /// Kurzbefehle rufen alle hierher.
    func testDerKanalRichtetSichNachDerBetriebsartDerUhr() throws {
        // HTTP: kein Broker, kein Praefix noetig.
        let http = Uhr(name: "a", host: "10.0.0.1", betriebsart: .http)
        let kanalHttp = try XCTUnwrap(Anzeigen.fuer(http, brokerzugang: nil))
        XCTAssertTrue(kanalHttp.quittiert)

        // Aber ohne Adresse gibt es auch ueber HTTP kein Ziel.
        XCTAssertNil(Anzeigen.fuer(Uhr(name: "a", host: "", praefix: "p", betriebsart: .http),
                                   brokerzugang: nil))

        // MQTT: ohne Brokerzugang geht nichts, auch mit Praefix nicht.
        let mqtt = Uhr(name: "b", host: "10.0.0.2", praefix: "wohnzimmer/uhr", betriebsart: .mqtt)
        XCTAssertNil(Anzeigen.fuer(mqtt, brokerzugang: nil))
        let kanalMqtt = try XCTUnwrap(Anzeigen.fuer(mqtt, brokerzugang: zugang))
        XCTAssertFalse(kanalMqtt.quittiert)

        // Und ohne Praefix auch mit Broker nicht.
        XCTAssertNil(Anzeigen.fuer(Uhr(name: "b", host: "10.0.0.2", betriebsart: .mqtt),
                                   brokerzugang: zugang))
    }

    func testZeigenSchicktDenRahmenAufDasRichtigeThema() throws {
        let sender = MitschreibenderSender()
        let anzeigen = Anzeigen(sender: sender, zugang: zugang, praefix: "wohnzimmer/uhr")
        try anzeigen.zeigen(rahmen(), auf: "notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/pushed/notiz")
        XCTAssertTrue(sender.gesendet.first?.nutzlast.contains("\"text\":\"hallo\"") == true)
    }

    /// Loeschen heisst: leere Nutzlast auf dasselbe Thema.
    func testLoeschenSchicktLeereNutzlast() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "wohnzimmer/uhr").loeschen("notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/pushed/notiz")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, "")
    }

    func testUmschaltenSchicktDenNamenAnSwitch() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "wohnzimmer/uhr").umschalten(auf: "notiz")
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/switch")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, #"{"name":"notiz"}"#)
    }

    /// Schraegstriche am Ende des Praefixes gehoeren nicht zum Thema.
    func testEinPraefixMitSchraegstrichenAmEndeBildetDasselbeThema() throws {
        for praefix in ["awtrix_a86b/", "awtrix_a86b///"] {
            let a1 = MitschreibenderSender(), a2 = MitschreibenderSender()
            let ohne = Anzeigen(sender: a1, zugang: zugang, praefix: "awtrix_a86b")
            let mit = Anzeigen(sender: a2, zugang: zugang, praefix: praefix)

            try ohne.zeigen(rahmen(), auf: "notiz")
            try mit.zeigen(rahmen(), auf: "notiz")
            try ohne.loeschen("notiz")
            try mit.loeschen("notiz")
            try ohne.umschalten(auf: "notiz")
            try mit.umschalten(auf: "notiz")

            XCTAssertEqual(a1.gesendet.map(\.thema), a2.gesendet.map(\.thema), praefix)
            XCTAssertEqual(a1.gesendet.first?.thema, "awtrix_a86b/cmd/apps/pushed/notiz")
        }
    }
}
