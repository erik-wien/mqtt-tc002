import XCTest
@testable import TC002Core

/// Die Steuerung über MQTT: Themen und Nutzlasten (§3.2), die Antwort auf
/// `<Thema>/result`, und der Zustand aus den aufbewahrten Nachrichten (§3.5).
/// Die Uhr am „Broker“ ist `MQTTUhrDoppelgaenger` — dieselbe Logik wie über HTTP.
final class SteuerungMQTTTests: XCTestCase {
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: nil, kennwort: nil)
    private let p = "wz/uhr"

    private func kanal(_ uhr: MQTTUhrDoppelgaenger, quittierend: Bool = false) -> Anzeigen {
        let a = Anzeigen(sender: uhr, zugang: zugang, praefix: p)
        return quittierend ? a.quittierend(lauscher: ErgebnisAmDoppelgaenger(uhr: uhr), beiAusbleiben: { _ in }) : a
    }

    private func letzte(_ uhr: MQTTUhrDoppelgaenger) -> (thema: String, nutzlast: String)? {
        uhr.eingang.last.map { ($0.thema, String(decoding: $0.nutzlast, as: UTF8.self)) }
    }

    func testPanelUndOverlayAufDemDisplayThema() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = kanal(uhr)
        try k.anzeigeStrom(false)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/display")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"power":false}"#)
        XCTAssertFalse(uhr.zustand.power)
        try k.overlay("snow", faehigkeiten: nil)
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"overlay":"snow"}"#)
        XCTAssertEqual(uhr.zustand.overlay, "snow")
        try k.overlay(nil)
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"overlay":null}"#)
        XCTAssertNil(uhr.zustand.overlay)
    }

    func testHelligkeitUndEinstellungenAufDemSettingsThema() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        try kanal(uhr).helligkeit(77)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/settings")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"brightness":77}"#)
        XCTAssertEqual(uhr.zustand.einstellungen["brightness"], .zahl(77))
    }

    func testMoodlightUndAusMitLeererNutzlast() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = kanal(uhr)
        try k.moodlight(Moodlight(kelvin: 3000, helligkeit: 90))
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/display/moodlight")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"kelvin":3000,"brightness":90}"#)
        XCTAssertEqual(uhr.zustand.moodlight?.helligkeit, 90)
        try k.moodlightAus()
        XCTAssertEqual(letzte(uhr)?.nutzlast, "", "über MQTT schaltet ein leerer Rumpf aus")
        XCTAssertNil(uhr.zustand.moodlight)
    }

    func testIndikatorenAufEinzelnenKennziffern() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = kanal(uhr)
        try k.indikator(Indikator(nummer: 3, farbe: "#112233", blinkMs: 10, fadeMs: 20))
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/indicators/3")
        XCTAssertEqual(letzte(uhr)?.nutzlast, ##"{"color":"#112233","blinkMs":10,"fadeMs":20}"##)
        XCTAssertTrue(uhr.zustand.indikatoren[2].an)
        try k.indikatorAus(3)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/indicators/3")
        XCTAssertEqual(letzte(uhr)?.nutzlast, "")
        XCTAssertFalse(uhr.zustand.indikatoren[2].an)
    }

    /// Eine Kennziffer außerhalb trifft keine Route und bliebe ohne Antwort: Die App
    /// sendet sie gar nicht erst.
    func testEineFalscheKennzifferGehtNieHinaus() {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        XCTAssertThrowsError(try kanal(uhr).indikator(Indikator(nummer: 10, farbe: "#FFFFFF")))
        XCTAssertThrowsError(try kanal(uhr).indikatorAus(0))
        XCTAssertTrue(uhr.eingang.isEmpty)
        // Die virtuelle Uhr verwirft ein mehrstelliges Thema still, wie die Firmware.
        var z = NGUhrzustand()
        XCTAssertTrue(VirtuelleNGUhr.nachricht(thema: "wz/uhr/cmd/indicators/10", nutzlast: Data("{}".utf8),
                                               praefix: p, &z).isEmpty)
    }

    func testWeiterUndZurueckUeberMQTT() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = kanal(uhr)
        try k.blaettern(vor: true)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/apps/next")
        XCTAssertEqual(uhr.zustand.aktiveApp, "Status")
        try k.blaettern(vor: false)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/apps/previous")
        XCTAssertEqual(uhr.zustand.aktiveApp, "Time")
    }

    // MARK: - Abweisungen

    /// Der Wert, den die App prüft, geht nie hinaus; was sie nicht prüfen kann
    /// (ein Name ohne Liste), weist die Uhr auf `/result` ab.
    func testDieAbweisungDerUhrKommtAlsFehler() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        XCTAssertThrowsError(try kanal(uhr, quittierend: true).overlay("hagel")) {
            guard case NGFehler.abgewiesen(let grund)? = $0 as? NGFehler else { return XCTFail("\($0)") }
            XCTAssertTrue(grund.contains("validationFailed"), grund)
            XCTAssertTrue(grund.contains("overlay"), grund)
        }
        XCTAssertNil(uhr.zustand.overlay)
    }

    func testAbweisungenWerdenAuchAlsEreignisVeroeffentlicht() {
        var z = NGUhrzustand()
        let aus = VirtuelleNGUhr.nachricht(thema: "wz/uhr/cmd/settings", nutzlast: Data(#"{"volume":999}"#.utf8),
                                           praefix: p, &z)
        let ereignis = aus.first { $0.thema == "wz/uhr/event/error" }
        XCTAssertNotNil(ereignis)
        let gelesen = Uhrenereignis.lesen(thema: "wz/uhr/event/error", nutzlast: ereignis?.nutzlast ?? Data(), praefix: p)
        XCTAssertEqual(gelesen, .fehler(Uhrenfehler(quelle: "mqtt", anfrage: "wz/uhr/cmd/settings",
                                                    fehler: "validationFailed (volume)")))
    }

    // MARK: - Zustand aus aufbewahrten Nachrichten

    /// Liefert, was der Broker aufbewahrt hält, sobald abonniert wird.
    private struct Aufbewahrt: ThemaLauschend {
        let nachrichten: [(thema: String, nutzlast: Data)]
        func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                      waehrend tat: () throws -> Void) throws -> Data? {
            try tat()
            return nachrichten.first { $0.thema == thema }?.nutzlast
        }
    }

    func testZustandEinstellungenUndAktiveAnzeigeAusDemBroker() throws {
        var z = NGUhrzustand()
        z.aktiveApp = "Status"
        z.einstellungen["volume"] = .zahl(55)
        let lauscher = Aufbewahrt(nachrichten: VirtuelleNGUhr.aufbewahrt(praefix: p, z))
        let k = Anzeigen(sender: MQTTUhrDoppelgaenger(praefix: p), zugang: zugang, praefix: p)
        XCTAssertEqual(try k.geraetezustandLesen(lauscher: lauscher).aktiveAnzeige, "Status")
        XCTAssertEqual(try k.einstellungenLesen(lauscher: lauscher).ganzzahl(.volume), 55)
        XCTAssertEqual(try k.aktiveAnzeigeLesen(lauscher: lauscher), "Status")
    }

    func testOhneAufbewahrtesIstEsEinFehlerMitHinweis() {
        let k = Anzeigen(sender: MQTTUhrDoppelgaenger(praefix: p), zugang: zugang, praefix: p)
        XCTAssertThrowsError(try k.geraetezustandLesen(lauscher: Aufbewahrt(nachrichten: []))) {
            guard case NGFehler.keineZustandsantwort? = $0 as? NGFehler else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try k.aktiveAnzeigeLesen(lauscher: Aufbewahrt(nachrichten: [])))
    }

    /// Mit Adresse ist HTTP der Weg: Der Broker hält auch Altes aufbewahrt.
    func testMitAdresseWirdUeberHTTPGelesen() throws {
        var port: UInt16 = 0
        for _ in 0..<20 {
            port = UInt16.random(in: 20_000...60_000)
            let versuch = Uhrenserver(port: port)
            if (try? versuch.starten()) != nil { server = versuch; break }
        }
        defer { server?.beenden() }
        guard server != nil else { throw XCTSkip("kein freier Port") }
        let k = Anzeigen(sender: MQTTUhrDoppelgaenger(praefix: p), zugang: zugang, praefix: p,
                         ausweich: Geraet(host: "127.0.0.1:\(port)"))
        // Der Lauscher würde etwas Veraltetes liefern; er darf nicht gefragt werden.
        var alt = NGUhrzustand()
        alt.aktiveApp = "Veraltet"
        let lauscher = Aufbewahrt(nachrichten: VirtuelleNGUhr.aufbewahrt(praefix: p, alt))
        XCTAssertEqual(try k.geraetezustandLesen(lauscher: lauscher).aktiveAnzeige, "Time")
    }

    private var server: Uhrenserver?
}
