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

    /// Die HTTP-Seite laeuft ueber denselben `URLProtocol`-Doppelgaenger wie
    /// `GeraetTests` — kein Netz, keine Uhr.
    private func httpAnzeigen() -> Anzeigen {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        return Anzeigen(geraet: Geraet(host: "10.0.0.1", sitzung: URLSession(configuration: k)))
    }

    override func setUp() {
        Doppelgaenger.antworten = ["/api/custom": #"{"code":200,"message":"ok"}"#,
                                   "/api/switchDiyApp": #"{"code":200,"message":"ok"}"#]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
        Doppelgaenger.abfragen = [:]
        Doppelgaenger.methoden = [:]
        Doppelgaenger.pfade = []
    }

    // MARK: - Dieselbe Nutzlast, anderer Kanal

    /// Der Satz, um den es geht. Was ueber MQTT auf
    /// `<praefix>/custom/<name>` geht, geht ueber HTTP als Rumpf von
    /// `POST /api/custom?name=<name>` — und zwar Zeichen fuer Zeichen
    /// dasselbe. Der Rahmenbau kennt die Betriebsart nicht und darf sie nicht
    /// kennen; wuerde er fuer einen der beiden Wege etwas anderes bauen,
    /// zeigte dieselbe Meldung je nach Einstellung etwas anderes.
    func testBeideKanaeleSchickenDieselbeNutzlast() throws {
        let frame = Frame(draw: [DrawBefehl(x: 3, y: 4, breite: 5, hoehe: 6, farbe: "#00FF66")])
        let sender = MitschreibenderSender()

        try Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b").zeigen(frame, auf: "meldung2")
        try httpAnzeigen().zeigen(frame, auf: "meldung2")

        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/custom"], sender.gesendet.first?.nutzlast)
        XCTAssertEqual(Doppelgaenger.abfragen["/api/custom"], "name=meldung2")
    }

    /// Gegenlaeufig, und beides gemessen. Ueber MQTT loescht die leere
    /// Nutzlast, ueber HTTP der Rumpf `{}` — vertauscht bliebe die Anzeige auf
    /// der Uhr stehen, und die Uhr antwortete trotzdem `ok`.
    func testLoeschenIstAufBeidenWegenDasGegenteilVoneinander() throws {
        let sender = MitschreibenderSender()
        try Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b").loeschen("meldung2")
        try httpAnzeigen().loeschen("meldung2")

        XCTAssertEqual(sender.gesendet.first?.nutzlast, "", "über MQTT löscht die leere Nutzlast")
        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/custom"], "{}", "über HTTP löscht `{}`")
    }

    func testUmschaltenGehtImHttpBetriebAnDenApiPfad() throws {
        try httpAnzeigen().umschalten(auf: "meldung2")
        XCTAssertEqual(Doppelgaenger.pfade, ["/api/switchDiyApp"])
        XCTAssertEqual(Doppelgaenger.abfragen["/api/switchDiyApp"], "name=meldung2")
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
        let mqtt = Uhr(name: "b", host: "10.0.0.2", praefix: "awtrix_a86b", betriebsart: .mqtt)
        XCTAssertNil(Anzeigen.fuer(mqtt, brokerzugang: nil))
        let kanalMqtt = try XCTUnwrap(Anzeigen.fuer(mqtt, brokerzugang: zugang))
        XCTAssertFalse(kanalMqtt.quittiert)

        // Und ohne Praefix auch mit Broker nicht.
        XCTAssertNil(Anzeigen.fuer(Uhr(name: "b", host: "10.0.0.2", betriebsart: .mqtt),
                                   brokerzugang: zugang))
    }

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

extension AnzeigenTests {
    /// Genau die Nutzlast, die am 11.09.2026 im Broker beobachtet wurde.
    func testCustomListWirdGelesen() {
        let daten = Data(#"{"apps":[{"appName":"scrolltest"}],"count":1}"#.utf8)
        XCTAssertEqual(Anzeigen.namenAusCustomList(daten), ["scrolltest"])
    }

    /// Eine leere Liste ist eine Aussage — auf der Uhr steht nichts —, kein Fehler.
    func testLeereCustomListIstKeineStoerung() {
        XCTAssertEqual(Anzeigen.namenAusCustomList(Data(#"{"apps":[],"count":0}"#.utf8)), [])
    }

    /// Unlesbares ergibt nil und nicht die leere Liste: sonst behauptete die App,
    /// die Uhr habe nichts, obwohl sie nur nichts Verstaendliches gesagt hat.
    func testUnlesbareCustomListErgibtNichts() {
        XCTAssertNil(Anzeigen.namenAusCustomList(Data("online".utf8)))
        XCTAssertNil(Anzeigen.namenAusCustomList(Data()))
        XCTAssertNil(Anzeigen.namenAusCustomList(Data(#"{"count":0}"#.utf8)))
    }

    /// Dieselbe Liste, zwei Schreibweisen: Ueber MQTT kommen Objekte mit
    /// `appName`, ueber `GET /api/customList` blosse Zeichenketten. Am
    /// 13.09.2026 am Geraet belegt. Ein Leser fuer beide — ein zweiter daneben
    /// waere eine zweite Stelle, an der sich die Form aendern koennte.
    func testBeideSchreibweisenDesAppsFeldes() {
        XCTAssertEqual(Anzeigen.namenAusAppsFeld(["meldung2", "meldung5", "meldung3"]),
                       ["meldung2", "meldung5", "meldung3"], "die Form ueber HTTP")
        XCTAssertEqual(Anzeigen.namenAusAppsFeld([["appName": "scrolltest"]]),
                       ["scrolltest"], "die Form ueber MQTT")
        XCTAssertEqual(Anzeigen.namenAusAppsFeld([]), [], "leer heisst: auf der Uhr steht nichts")
        XCTAssertNil(Anzeigen.namenAusAppsFeld(nil))
        XCTAssertNil(Anzeigen.namenAusAppsFeld(42))
    }
}
