import XCTest
@testable import TC002Core

/// Steuerung und Zustand über den echten HTTP-Weg: `Anzeigen`/`Geraet` → Port auf
/// `127.0.0.1` → `VirtuelleNGUhr`. Kein Byte verlässt den Rechner.
final class SteuerungPruefstandTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, Anzeigen, Geraet) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, Anzeigen(geraet: g), g)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func abgewiesen(_ tat: () throws -> Void, status: Int, code: String, feld: String? = nil,
                            datei: StaticString = #filePath, zeile: UInt = #line) {
        XCTAssertThrowsError(try tat(), file: datei, line: zeile) {
            guard case GeraetFehler.ngAbgewiesen(let s, let c, let f)? = $0 as? GeraetFehler else {
                return XCTFail("keine Abweisung der Uhr: \($0)", file: datei, line: zeile)
            }
            XCTAssertEqual(s, status, file: datei, line: zeile)
            XCTAssertEqual(c, code, file: datei, line: zeile)
            XCTAssertEqual(f, feld, file: datei, line: zeile)
        }
    }

    // MARK: - Panel

    func testPanelAusUndEinWirktAufStandUndBildschirm() throws {
        let (s, uhr, g) = try gestartet()
        // Etwas auf dem Display, damit „schwarz“ etwas bedeutet.
        try g.anzeigeSetzen(##"{"draw":[["rectFill",0,0,26,8,"#FF0000"]]}"##, name: "rot")
        try uhr.umschalten(auf: "rot")
        XCTAssertTrue(try g.bildschirm().pixel.contains(0xFF0000))

        try uhr.anzeigeStrom(false)
        XCTAssertFalse(s.zustand.power)
        XCTAssertEqual(try g.anzeigestand().an, false)
        XCTAssertEqual(try g.geraetezustand().panelAn, false)
        XCTAssertTrue(try g.bildschirm().pixel.allSatisfy { $0 == 0 }, "aus ist das Bild schwarz")

        try uhr.anzeigeStrom(true)
        XCTAssertTrue(try g.bildschirm().pixel.contains(0xFF0000), "die Anzeige ist noch da")
    }

    func testHelligkeitIstEineEinstellungUndStehtImGeraetezustand() throws {
        let (s, uhr, g) = try gestartet()
        try uhr.helligkeit(33)
        XCTAssertEqual(s.zustand.einstellungen["brightness"], .zahl(33))
        XCTAssertEqual(try g.geraetezustand().helligkeit, 33)
        XCTAssertEqual(try g.anzeigestand().helligkeit, 33)
        XCTAssertEqual(try g.einstellungen().ganzzahl(.brightness), 33)
        XCTAssertThrowsError(try uhr.helligkeit(256), "geprüft, bevor etwas hinausgeht")
        XCTAssertEqual(try g.anzeigestand().helligkeit, 33)
    }

    func testOverlayMitNamenDerUhr() throws {
        let (s, uhr, g) = try gestartet()
        let f = try g.faehigkeiten()
        try uhr.overlay("RAIN", faehigkeiten: f)
        XCTAssertEqual(s.zustand.overlay, "rain", "Schreibweise der Liste der Uhr")
        XCTAssertEqual(try g.anzeigestand().overlay, "rain")
        XCTAssertThrowsError(try uhr.overlay("hagel", faehigkeiten: f)) {
            XCTAssertEqual($0 as? SteuerungsFehler, .unbekannterName(feld: "overlay", wert: "hagel"))
        }
        try uhr.overlay(nil)
        XCTAssertNil(s.zustand.overlay)
        XCTAssertNil(try g.anzeigestand().overlay)
        // Ohne Namenslisten weist die Uhr einen falschen selbst ab.
        abgewiesen({ try uhr.overlay("hagel") }, status: 422, code: "validationFailed", feld: "overlay")
    }

    // MARK: - Moodlight

    func testMoodlightErstesMalWeissBei120UndBehaeltFelder() throws {
        let (s, uhr, g) = try gestartet()
        try uhr.moodlight(Moodlight(helligkeit: 50))
        XCTAssertEqual(s.zustand.moodlight, NGMoodlight(farbe: "#FFFFFF", helligkeit: 50))
        try uhr.moodlight(Moodlight(farbe: "#FF8800"))
        XCTAssertEqual(try g.anzeigestand().moodlight, Moodlightstand(farbe: "#FF8800", helligkeit: 50),
                       "die Helligkeit bleibt")
    }

    func testMoodlightErstesMalNurFarbeGibtHelligkeit120() throws {
        let (_, uhr, g) = try gestartet()
        try uhr.moodlight(Moodlight(farbe: "#00FF00"))
        XCTAssertEqual(try g.anzeigestand().moodlight, Moodlightstand(farbe: "#00FF00", helligkeit: 120))
    }

    func testMoodlightKelvinGewinntUeberDieFarbeDerUhr() throws {
        let (s, _, g) = try gestartet()
        // Die App schickt nie beides (`Moodlight.pruefen`); die Uhr aber muss es
        // so handhaben, wie die Doku sagt.
        try g.moodlightSetzen(##"{"color":"#FF0000","kelvin":2700}"##)
        XCTAssertNotEqual(s.zustand.moodlight?.farbe, "#FF0000")
        XCTAssertEqual(s.zustand.moodlight?.farbe, VirtuelleNGUhr.kelvinfarbe(2700))
    }

    /// Gemessen: 300 wird zu 44, 256 zu 0 — die Uhr prüft nicht. Die App schon,
    /// die Bank der Uhr zeigt das Verhalten für Geräte, die ein anderer beschickt.
    func testDieUhrPruftDieMoodlightHelligkeitNichtAberDieAppSchon() throws {
        let (s, uhr, g) = try gestartet()
        try g.moodlightSetzen(#"{"brightness":300}"#)
        XCTAssertEqual(s.zustand.moodlight?.helligkeit, 44)
        try g.moodlightSetzen(#"{"brightness":256}"#)
        XCTAssertEqual(s.zustand.moodlight?.helligkeit, 0)
        XCTAssertThrowsError(try uhr.moodlight(Moodlight(helligkeit: 300)))
        XCTAssertEqual(s.zustand.moodlight?.helligkeit, 0, "nichts ging hinaus")
    }

    func testMoodlightLeerOderUngueltigIst422() throws {
        let (_, _, g) = try gestartet()
        abgewiesen({ try g.moodlightSetzen("{}") }, status: 422, code: "validationFailed")
        abgewiesen({ try g.moodlightSetzen(#"{"kelvin":999}"#) }, status: 422, code: "validationFailed", feld: "kelvin")
        abgewiesen({ try g.moodlightSetzen(#"{"color":"rot"}"#) }, status: 422, code: "validationFailed", feld: "color")
        abgewiesen({ try g.moodlightSetzen("{") }, status: 400, code: "invalidJson")
    }

    func testMoodlightAusIstImmer200() throws {
        let (s, uhr, g) = try gestartet()
        XCTAssertNoThrow(try uhr.moodlightAus(), "auch wenn keines läuft")
        try uhr.moodlight(Moodlight(farbe: "#0000FF"))
        XCTAssertNotNil(s.zustand.moodlight)
        try uhr.moodlightAus()
        XCTAssertNil(s.zustand.moodlight)
        XCTAssertNil(try g.anzeigestand().moodlight)
    }

    func testEinMoodlightFlutetDasBild() throws {
        let (_, uhr, g) = try gestartet()
        try uhr.moodlight(Moodlight(farbe: "#102030"))
        XCTAssertTrue(try g.bildschirm().pixel.allSatisfy { $0 == 0x102030 })
        try uhr.moodlightAus()
        XCTAssertTrue(try g.bildschirm().pixel.allSatisfy { $0 == 0 })
    }

    // MARK: - Anzeiger

    func testIndikatorSetzenUndZuruecksetzen() throws {
        let (s, uhr, g) = try gestartet()
        try uhr.indikator(Indikator(nummer: 2, farbe: "#FF0000", blinkMs: 300, fadeMs: 100))
        XCTAssertEqual(s.zustand.indikatoren[1], NGIndikator(an: true, farbe: "#FF0000", blinkMs: 300, fadeMs: 100))
        XCTAssertFalse(s.zustand.indikatoren[0].an)
        XCTAssertEqual(try g.geraetezustand().indikatoren[1], Indikatorstand(an: true, farbe: "#FF0000", blinkMs: 300, fadeMs: 100))
        // Jede Anfrage setzt Blinken und Blenden neu: fehlende gelten als 0.
        try uhr.indikator(Indikator(nummer: 2, farbe: "#00FF00"))
        XCTAssertEqual(s.zustand.indikatoren[1].blinkMs, 0)
        try uhr.indikatorAus(2)
        XCTAssertFalse(s.zustand.indikatoren[1].an)
        XCTAssertNoThrow(try uhr.indikatorAus(3), "immer 200")
        XCTAssertThrowsError(try uhr.indikatorAus(4)) {
            XCTAssertEqual($0 as? SteuerungsFehler, .ungueltigeKennziffer(4))
        }
    }

    func testIndikatorKennzifferAmGeraetIst404() throws {
        let (_, _, g) = try gestartet()
        abgewiesen({ try g.indikatorSetzen(nummer: 4, json: ##"{"color":"#FF0000"}"##) }, status: 404, code: "notFound")
    }

    // MARK: - Blättern

    func testWeiterUndZurueckWechseltDieAktiveAnzeige() throws {
        let (_, uhr, g) = try gestartet()
        try g.anzeigeSetzen(#"{"text":"a"}"#, name: "eins")
        XCTAssertEqual(try uhr.aktiveAnzeigeLesen(), "Time")
        try uhr.blaettern(vor: true)
        XCTAssertEqual(try uhr.aktiveAnzeigeLesen(), "Status")
        try uhr.blaettern(vor: true)
        XCTAssertEqual(try uhr.aktiveAnzeigeLesen(), "eins")
        try uhr.blaettern(vor: false)
        XCTAssertEqual(try g.geraetezustand().aktiveAnzeige, "Status")
        try uhr.umschalten(auf: "eins")
        XCTAssertEqual(try uhr.aktiveAnzeigeLesen(), "eins")
    }

    // MARK: - Einstellungen

    func testEinstellungenLesenAendernUndLesen() throws {
        let (s, uhr, g) = try gestartet()
        let vorher = try g.einstellungen()
        XCTAssertEqual(vorher.schluesselinsgesamt, 46)
        XCTAssertEqual(vorher.text(.clockFace), "sheet")
        XCTAssertEqual(vorher.lauftext?.speed, 100)

        var a = Einstellungsaenderung()
        try a.setzen(.clockFace, .text("ring"), faehigkeiten: try g.faehigkeiten())
        try a.setzen(.volume, .zahl(40))
        try a.setzen(.blockNavigation, .bool(true))
        try a.setzen(.transitionEffect, .text("slide"), faehigkeiten: try g.faehigkeiten())
        try uhr.einstellungenAendern(a)

        let nachher = try uhr.einstellungenLesen()
        XCTAssertEqual(nachher.text(.clockFace), "ring")
        XCTAssertEqual(nachher.ganzzahl(.volume), 40)
        XCTAssertEqual(nachher.wahrheit(.blockNavigation), true)
        XCTAssertEqual(nachher.text(.transitionEffect), "Slide")
        XCTAssertEqual(nachher.text(.dateOrder), vorher.text(.dateOrder), "Unberührtes bleibt")
        XCTAssertEqual(s.zustand.einstellungen["enlargeApps"], .bool(true), "nie angefasst")
        XCTAssertEqual(nachher.wahrheit(.enlargeApps), true)
    }

    func testEinUnterfeldAusDemGelesenenStand() throws {
        let (_, uhr, g) = try gestartet()
        let e = try g.einstellungen()
        try uhr.einstellungenAendern(try e.aenderung(schluessel: "scroll.speed", wert: "250"))
        try uhr.einstellungenAendern(try e.aenderung(schluessel: "weekdayBar.show", wert: "aus"))
        let neu = try g.einstellungen()
        XCTAssertEqual(neu.lauftext?.speed, 250)
        XCTAssertEqual(neu.lauftext?.mode, "wrap", "die übrigen Felder blieben")
        XCTAssertEqual(neu.wochentagsleiste?.show, false)
        XCTAssertEqual(neu.wochentagsleiste?.startOnMonday, true)
    }

    /// Die Gegenprobe: Was die App nie schickt, weist die Uhr trotzdem ab, wenn es
    /// jemand anders schickt — und was die App für gültig hält, nimmt sie an.
    func testDieUhrWeistAusserhalbVonBereichenAbWasDieAppSchonPruefte() throws {
        let (s, _, g) = try gestartet()
        let vorher = s.zustand
        let faelle: [(String, String)] = [
            (#"{"saturation":101}"#, "saturation"), (#"{"volume":101}"#, "volume"),
            (#"{"gamma":0}"#, "gamma"), (#"{"transitionDurationMs":2147483648}"#, "transitionDurationMs"),
            (#"{"clockFace":"digital"}"#, "clockFace"), (#"{"transitionEffect":"Nope"}"#, "transitionEffect"),
            (#"{"timeSeparatorMode":"flash"}"#, "timeSeparatorMode"), (#"{"textColor":null}"#, "textColor"),
            (#"{"scroll":{"speed":-1}}"#, "scroll.speed"), (#"{"scroll":{"mode":"zoom"}}"#, "scroll.mode"),
            (#"{"weekdayBar":{"weekendDays":["funday"]}}"#, "weekdayBar.weekendDays"),
            (#"{"timeMode":7}"#, "timeMode"),
        ]
        for (rumpf, feld) in faelle {
            abgewiesen({ try g.einstellungenAendern(rumpf) }, status: 422, code: "validationFailed", feld: feld)
        }
        XCTAssertEqual(s.zustand, vorher, "alles oder nichts")
        XCTAssertNoThrow(try g.einstellungenAendern(##"{"textColor":"#00ff00"}"##))
        XCTAssertEqual(s.zustand.einstellungen["textColor"], .text("#00FF00"), "die Uhr behält Großschreibung")
    }

    func testWerteZuruecksetzenUnbekannteSchluesselAbgewiesen() throws {
        let (_, _, g) = try gestartet()
        abgewiesen({ try g.einstellungenAendern(#"{"wifiSsid":"x"}"#) }, status: 422, code: "validationFailed",
                   feld: "wifiSsid")
    }

    // MARK: - TLS

    func testTLSStatusHochladenEntfernen() throws {
        let (s, _, g) = try gestartet()
        XCTAssertEqual(try g.tlsStatus(), try TLSStatus(daten: Data(#"{"ca":"public","pending":null}"#.utf8)))
        let pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n"
        let danach = try g.tlsCAHochladen(pem: pem)
        XCTAssertTrue(s.zustand.eigeneCA)
        XCTAssertEqual(danach?.oeffentlich, false)
        XCTAssertFalse(try g.tlsStatus().oeffentlich)
        let weg = try g.tlsCAEntfernen()
        XCTAssertFalse(s.zustand.eigeneCA)
        XCTAssertEqual(weg?.oeffentlich, true)
        XCTAssertTrue(try g.tlsStatus().oeffentlich)
        XCTAssertNoThrow(try g.tlsCAEntfernen(), "ohne CA ebenso")
    }

    func testTLSZuGrossOderKeinPEMGehtNieHinaus() throws {
        let (s, _, g) = try gestartet()
        XCTAssertThrowsError(try g.tlsCAHochladen(pem: "kein Zertifikat"))
        let zuGross = "-----BEGIN CERTIFICATE-----\n" + String(repeating: "A", count: 66_000) + "\n-----END CERTIFICATE-----"
        XCTAssertThrowsError(try g.tlsCAHochladen(pem: zuGross))
        XCTAssertFalse(s.zustand.eigeneCA)
    }

    /// Die Uhr selbst weist zu Großes mit 422 ab (Doku §11.1) — auch wenn jemand
    /// anders sendet.
    func testDieUhrWeistEinZuGrosseZertifikatAbMitFeld() throws {
        let (_, _, g) = try gestartet()
        let zuGross = "-----BEGIN CERTIFICATE-----\n" + String(repeating: "A", count: 66_000) + "\n-----END CERTIFICATE-----"
        let rumpf = Steuerfarbe.json([("certificate", .text(zuGross))])
        abgewiesen({ _ = try g.ngAnfrage("PUT", "/api/v1/mqtt/tls/ca", koerper: Data(rumpf.utf8)) },
                   status: 422, code: "validationFailed", feld: "certificate")
    }

    func testTLSRoutenSindNurFuerDieErlaubtenMethoden() throws {
        let (_, _, g) = try gestartet()
        abgewiesen({ _ = try g.ngAnfrage("POST", "/api/v1/mqtt/tls", koerper: nil) }, status: 405, code: "methodNotAllowed")
    }
}
