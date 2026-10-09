import XCTest
@testable import TC002Core

/// Benachrichtigungen, Lebensdauer und Schalten über den echten HTTP-Weg:
/// `Anzeigen` → `Geraet` → Port auf `127.0.0.1` → `VirtuelleNGUhr`. Kein Byte
/// verlässt den Rechner.
final class BenachrichtigungPruefstandTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, UInt16, Anzeigen) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                return (s, port, Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)")))
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func text(_ t: String = "hallo", dauer: Int? = nil, lebensdauer: Lebensdauer? = nil) -> Frame {
        Frame(dauer: dauer,
              herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: t, weg: .text, dauer: dauer)),
              lebensdauer: lebensdauer)
    }

    private func pixel(lebensdauer: Lebensdauer? = nil) -> Frame {
        Frame(pixel: Pixelinhalt(breite: 52, hoehe: 16,
                                 bilder: [Bildraster.Einzelbild(pixel: [String?](repeating: "#FF0000", count: 832),
                                                                dauer: 1)]),
              lebensdauer: lebensdauer)
    }

    // MARK: - Benachrichtigungen

    func testEineBenachrichtigungKommtMitIhrenFeldernAn() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(text("Tür"), .init(name: "tuer", halten: true, aufwecken: true, wiederholungen: 2))

        let liste = s.zustand.benachrichtigungen
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste[0].name, "tuer")
        XCTAssertTrue(liste[0].haelt)
        XCTAssertTrue(liste[0].weckt)
        XCTAssertEqual(liste[0].nutzlast["repeat"], .zahl(2))
        XCTAssertEqual(liste[0].nutzlast["text"], .text("Tür"))
        XCTAssertTrue(s.zustand.apps.allSatisfy(\.eingebaut), "keine Anzeige angelegt")
    }

    func testEinePixelbenachrichtigungGehtAlsIconHinaus() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(pixel(lebensdauer: Lebensdauer(sekunden: 5)))
        guard case .text(let icon)? = s.zustand.benachrichtigungen.first?.nutzlast["icon"] else {
            return XCTFail("kein icon")
        }
        XCTAssertTrue(icon.hasPrefix("data:image/gif;base64,"))
        XCTAssertNil(s.zustand.benachrichtigungen.first?.nutzlast["lifetimeMs"], "gehört in keine Benachrichtigung")
    }

    func testStackTrueReihtEinStackFalseErsetztDieSichtbare() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(text("eins"))
        try uhr.benachrichtigen(text("zwei"))
        XCTAssertEqual(s.zustand.benachrichtigungen.count, 2)
        try uhr.benachrichtigen(text("drei"), .init(einreihen: false))
        let texte = s.zustand.benachrichtigungen.map { $0.nutzlast["text"] }
        XCTAssertEqual(texte, [.text("drei"), .text("zwei")], "die sichtbare ist ersetzt, die wartende bleibt")
    }

    func testDieSichtbareZurueckziehenUndDieNaechsteRueckt() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(text("eins"))
        try uhr.benachrichtigen(text("zwei"))
        try uhr.benachrichtigungZurueckziehen()
        XCTAssertEqual(s.zustand.benachrichtigungen.map { $0.nutzlast["text"] }, [.text("zwei")])
        try uhr.benachrichtigungZurueckziehen()
        XCTAssertNoThrow(try uhr.benachrichtigungZurueckziehen(), "ohne sichtbare ebenfalls 200")
        XCTAssertTrue(s.zustand.benachrichtigungen.isEmpty)
    }

    func testNachNamenZurueckziehenAuchEineWartende() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(text("eins"), .init(name: "a"))
        try uhr.benachrichtigen(text("zwei"), .init(name: "b"))
        try uhr.benachrichtigungZurueckziehen(name: "b")
        XCTAssertEqual(s.zustand.benachrichtigungen.map(\.name), ["a"])
    }

    func testEinUnbekannterNameIstEineAbweisung() throws {
        let (_, _, uhr) = try gestartet()
        XCTAssertThrowsError(try uhr.benachrichtigungZurueckziehen(name: "nix")) { f in
            guard case GeraetFehler.ngAbgewiesen(let status, let code, _) = f else { return XCTFail("war \(f)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(code, "notFound")
        }
    }

    func testDieUhrWeistEinenReserviertenNamenAb() throws {
        // Am Prüfstand vorbei an der Vorprüfung des Kerns, wie ein fremder Absender.
        let (_, port, _) = try gestartet()
        let geraet = Geraet(host: "127.0.0.1:\(port)")
        XCTAssertThrowsError(try geraet.benachrichtigen(#"{"text":"x","name":"active"}"#)) { f in
            guard case GeraetFehler.ngAbgewiesen(_, let code, _) = f else { return XCTFail("war \(f)") }
            XCTAssertEqual(code, "invalidName")
        }
    }

    func testDieWarteschlangeIstBeiZweiunddreissigVoll() throws {
        let (_, _, uhr) = try gestartet()
        for i in 0..<32 { try uhr.benachrichtigen(text("n\(i)")) }
        XCTAssertThrowsError(try uhr.benachrichtigen(text("zu viel"))) { f in
            guard case GeraetFehler.ngAbgewiesen(let status, _, _) = f else { return XCTFail("war \(f)") }
            XCTAssertEqual(status, 507)
        }
        XCTAssertNoThrow(try uhr.benachrichtigen(text("ersetzt"), .init(einreihen: false)))
    }

    // MARK: - Lebensdauer

    func testDieLebensdauerStehtAlsFeldAnDerAnzeige() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.zeigen(text("kurz", lebensdauer: Lebensdauer(sekunden: 90, ablauf: .markieren)), auf: "meldung1")
        let app = try XCTUnwrap(s.zustand.apps.first { $0.name == "meldung1" })
        XCTAssertEqual(app.lebensdauerMs, 90_000)
        guard case .objekt(let o)? = app.nutzlast else { return XCTFail("keine Nutzlast") }
        XCTAssertEqual(o["lifetimeExpiry"], .text("mark"))
    }

    func testAbgelaufenMitRemoveVerschwindetDieAnzeige() throws {
        let (s, port, uhr) = try gestartet()
        try uhr.zeigen(pixel(lebensdauer: Lebensdauer(sekunden: 1)), auf: "meldung1")
        try uhr.zeigen(text("bleibt"), auf: "meldung2")
        XCTAssertEqual(try Geraet(host: "127.0.0.1:\(port)").anzeigennamen().sorted(), ["meldung1", "meldung2"])

        s.lebensdauerAblaufen("meldung1")

        XCTAssertEqual(try Geraet(host: "127.0.0.1:\(port)").anzeigennamen(), ["meldung2"],
                       "so liest die App die Belegung (GET /api/v1/apps)")
    }

    func testAbgelaufenMitMarkBleibtDieAnzeigeStehen() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.zeigen(text("markiert", lebensdauer: Lebensdauer(sekunden: 1, ablauf: .markieren)), auf: "meldung1")
        s.lebensdauerAblaufen("meldung1")
        let app = try XCTUnwrap(s.zustand.apps.first { $0.name == "meldung1" })
        XCTAssertTrue(app.markiert)
    }

    func testEineAnzeigeOhneLebensdauerVerfaelltNicht() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.zeigen(text("ewig"), auf: "meldung1")
        s.lebensdauerAblaufen("meldung1")
        XCTAssertNotNil(s.zustand.apps.first { $0.name == "meldung1" })
    }

    func testSchluesselFuerBenachrichtigungenSindInEinerAnzeigeAbgewiesen() throws {
        let (_, port, _) = try gestartet()
        let geraet = Geraet(host: "127.0.0.1:\(port)")
        for schluessel in ["hold", "wakeup", "stack", "name", "sound"] {
            let json = #"{"text":"x","\#(schluessel)":true}"#
            XCTAssertThrowsError(try geraet.anzeigeSetzen(json, name: "x"), schluessel) { f in
                guard case GeraetFehler.ngAbgewiesen(let status, _, let feld) = f else { return XCTFail("war \(f)") }
                XCTAssertEqual(status, 422)
                XCTAssertEqual(feld, schluessel)
            }
        }
    }

    func testEinUnbekanntesAblaufwortIstAbgewiesen() throws {
        let (_, port, _) = try gestartet()
        XCTAssertThrowsError(try Geraet(host: "127.0.0.1:\(port)")
            .anzeigeSetzen(#"{"text":"x","lifetimeMs":1000,"lifetimeExpiry":"morgen"}"#, name: "x")) { f in
            guard case GeraetFehler.ngAbgewiesen(_, _, let feld) = f else { return XCTFail("war \(f)") }
            XCTAssertEqual(feld, "lifetimeExpiry")
        }
    }

    // MARK: - Ein- und Ausschalten, Blättern

    func testEineAnzeigeAusUndWiederEinschalten() throws {
        let (s, port, uhr) = try gestartet()
        try uhr.zeigen(text(), auf: "meldung1")
        XCTAssertEqual(s.zustand.apps.first { $0.name == "meldung1" }?.aktiv, true)

        try uhr.schalten("meldung1", an: false)
        XCTAssertEqual(s.zustand.apps.first { $0.name == "meldung1" }?.aktiv, false)
        XCTAssertEqual(try Geraet(host: "127.0.0.1:\(port)").anzeigennamen(), ["meldung1"],
                       "abgeschaltet heißt nicht gelöscht: sie behält ihren Platz")

        try uhr.schalten("meldung1", an: true)
        XCTAssertEqual(s.zustand.apps.first { $0.name == "meldung1" }?.aktiv, true)
    }

    /// Gemessen 09.10.2026: Ein unbekannter Name ist ok und legt nichts an.
    func testEinUnbekannterNameBeimSchaltenIstOkUndLegtNichtsAn() throws {
        let (s, port, uhr) = try gestartet()
        try uhr.schalten("gibtsnicht", an: true)
        try uhr.schalten("gibtsnicht", an: false)
        XCTAssertNil(s.zustand.apps.first { $0.name == "gibtsnicht" })
        XCTAssertEqual(try Geraet(host: "127.0.0.1:\(port)").anzeigeninventar(), [])
    }

    /// Gemessen 09.10.2026 an einer echten Uhr: ausgeschaltet bleibt beim
    /// Ersetzen und beim Löschen, das Inventar sagt es.
    func testDasInventarNenntEnabledUndPresentBeimGeist() throws {
        let (_, port, uhr) = try gestartet()
        let g = Geraet(host: "127.0.0.1:\(port)")
        try uhr.zeigen(text(), auf: "meldung1")
        try uhr.schalten("meldung1", an: false)
        XCTAssertEqual(try g.anzeigeninventar(), [Inventareintrag(name: "meldung1", aktiv: false, vorhanden: true)])
        try uhr.zeigen(text("neu"), auf: "meldung1")
        XCTAssertEqual(try g.anzeigeninventar(), [Inventareintrag(name: "meldung1", aktiv: false, vorhanden: true)])
        try uhr.loeschen("meldung1")
        XCTAssertEqual(try g.anzeigeninventar(), [Inventareintrag(name: "meldung1", aktiv: false, vorhanden: false)])
        XCTAssertEqual(try g.anzeigennamen(), [], "ein Geist ist nicht belegt")
        try uhr.schalten("meldung1", an: true)
        XCTAssertEqual(try g.anzeigeninventar(), [])
    }

    func testUmschaltenUndBlaettern() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.zeigen(text(), auf: "meldung1")
        try uhr.zeigen(text(), auf: "meldung2")
        try uhr.umschalten(auf: "meldung1")
        XCTAssertEqual(s.zustand.aktiveApp, "meldung1")
        try uhr.blaettern(vor: true)
        XCTAssertEqual(s.zustand.aktiveApp, "meldung2")
        try uhr.blaettern(vor: false)
        XCTAssertEqual(s.zustand.aktiveApp, "meldung1")
        try uhr.schalten("meldung2", an: false)
        try uhr.blaettern(vor: true)
        XCTAssertNotEqual(s.zustand.aktiveApp, "meldung2", "eine abgeschaltete Anzeige wird übersprungen")
    }
}
