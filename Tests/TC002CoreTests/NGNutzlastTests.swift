import Foundation
import XCTest
@testable import TC002Core

/// Die Nutzlast einer AWTRIX-NG-Anzeige, byteweise gegen
/// `docs/awtrix-ng-protokoll.md` §5 geprueft.
///
/// Ohne Geraet und ohne Broker: Diese Datei rechnet nur; geschickt wird
/// nichts. Das ist genau der Grund, warum sie so streng sein darf: Auf dem
/// Geraet liesse sich ein falscher Schluessel nicht nachweisen — NG verwirft
/// eine Nachricht auf einem Thema ohne Route ohne jede Antwort, und ein
/// unbekannter oberster Schluessel wird `422` auf einem `/result`-Thema, das
/// niemand von selbst abonniert.
final class NGNutzlastTests: XCTestCase {

    private func optionen(_ anpassen: (inout Meldungsoptionen) -> Void = { _ in }) -> Meldungsoptionen {
        var o = Meldungsoptionen(text: "Grüße")
        anpassen(&o)
        return o
    }

    // MARK: - Die Anzeige selbst

    /// Der Schnappschuss: Schluessel, Reihenfolge und Schreibweise in einem.
    ///
    /// Jeder Schluessel darin steht ausdruecklich da, obwohl NG fuer alle
    /// eine Vorgabe hat — und zwar, weil die Vorgabe jedes Mal eine andere ist
    /// als unsere: `textCase` erbt sonst das global eingeschaltete `uppercase`,
    /// `textCenter` ist bei NG `true` und bei uns linksbuendig.
    func testDieAnzeigeTraegtGenauDieseSchluessel() throws {
        XCTAssertEqual(
            try NGNutzlast.anzeige(optionen()),
            ##"{"text":"Grüße","textCase":"asTyped","textColor":"#00FF66","textCenter":false,"scroll":{"speed":60}}"##)
    }

    /// `dauer * 1000` trappte bei grossen Werten; jetzt wird auf einen Tag
    /// begrenzt, Negatives wird 0.
    func testDauerLaeuftNichtUeber() throws {
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.dauer = Int.max }).contains(#""durationMs":86400000"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.dauer = -5 }).contains(#""durationMs":0"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.dauer = 9 }).contains(#""durationMs":9000"#))
    }

    /// Der Text bleibt, wie er eingetippt wurde: NG versalisiert selbst und
    /// erhaelt dabei die Zeichen; der Schalter gehoert deshalb nach `textCase`
    /// und nicht in den Text (`uppercased()` machte aus „ß“ ein „SS“).
    func testGrossbuchstabenGehenNachTextCaseUndNichtInDenText() throws {
        let json = try NGNutzlast.anzeige(optionen { $0.grossbuchstaben = true })
        XCTAssertTrue(json.contains(#""text":"Grüße""#), "der Text darf nicht versalisiert werden")
        XCTAssertTrue(json.contains(#""textCase":"upper""#))
        XCTAssertFalse(json.contains("GRÜSSE"), "aus „ß“ darf hier kein „SS“ werden")
    }

    /// Ausgeschaltet heisst `asTyped` und nicht „weglassen": Am gemessenen
    /// Geraet steht `uppercase` global auf `true`, ein fehlendes `textCase`
    /// ergaebe also trotzdem Versalschrift.
    func testOhneGrossbuchstabenStehtAsTypedDa() throws {
        XCTAssertTrue(try NGNutzlast.anzeige(optionen()).contains(#""textCase":"asTyped""#))
    }

    /// `textCenter` ist ein bool. „mittig" ist `true`, alles andere ist
    /// `false` — auch „rechts", das NG nicht kennt und das die Ansicht auf
    /// einer NG-Uhr deshalb gar nicht anbietet
    /// (`AwtrixNG.waagrechteAusrichtungen`). Eine stille Umdeutung nach
    /// mittig waere schlimmer als linksbuendig.
    func testNurMittigIstTextCenter() throws {
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .mittig })
            .contains(#""textCenter":true"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .links })
            .contains(#""textCenter":false"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .rechts })
            .contains(#""textCenter":false"#))
    }

    /// Millisekunden, nicht Sekunden: Ein mitgeschicktes `duration` waere ein unbekannter oberster Schluessel und
    /// damit `422` — laut, aber nur auf `/result`.
    func testDauerGehtInMillisekunden() throws {
        let json = try NGNutzlast.anzeige(optionen { $0.dauer = 10 })
        XCTAssertTrue(json.contains(#""durationMs":10000"#))
        XCTAssertFalse(json.contains(#","duration":"#), "`duration` wäre bei NG ein unbekannter Schlüssel")
    }

    /// Ohne eingestellte Dauer steht der Schluessel gar nicht da — dann gilt
    /// die globale `appDurationMs` des Geraets.
    func testOhneDauerStehtKeineDauerDa() throws {
        XCTAssertFalse(try NGNutzlast.anzeige(optionen()).contains("durationMs"))
    }

    /// Dasselbe Wort, dieselbe Geschwindigkeit — auf jeder Uhr.
    ///
    /// `scroll.speed` ist ein Prozentsatz der Grundgeschwindigkeit von rund
    /// 21 Pixeln je Sekunde; unsere Stufen sind Standzeiten je Einzelbild und
    /// ergeben 8, 12 und 18 Pixel je Sekunde. Umgerechnet wird deshalb auf die
    /// Geschwindigkeit, nicht auf das Verhaeltnis der Stufen zueinander — bei
    /// der Geraetevorgabe 100 liefe „mittel“ mit 21 statt 12 Pixeln je
    /// Sekunde, fast doppelt so schnell.
    func testTempoWirdAufDieGeschwindigkeitUmgerechnet() {
        XCTAssertEqual(NGNutzlast.tempo(.langsam), 40)
        XCTAssertEqual(NGNutzlast.tempo(.mittel), 60)
        XCTAssertEqual(NGNutzlast.tempo(.schnell), 87)
    }

    /// Die Probe aufs Exempel: Der Prozentsatz mal der Grundgeschwindigkeit
    /// muss wieder die Pixel je Sekunde des Pixelwegs ergeben — auf ein Pixel
    /// genau, mehr gibt eine ganze Zahl Prozent nicht her.
    func testDerProzentsatzTrifftDieGeschwindigkeitDesPixelwegs() {
        for t in [Lauftempo.langsam, .mittel, .schnell] {
            let unsere = 1.0 / t.bilddauer                       // Pixel je Sekunde
            let ihre = Double(NGNutzlast.tempo(t)) / 100 * AwtrixNG.grundgeschwindigkeit
            XCTAssertEqual(ihre, unsere, accuracy: 1.0,
                           "\(t): NG liefe mit \(ihre) statt \(unsere) Pixeln je Sekunde")
        }
    }

    /// Ein Text mit Anfuehrungszeichen darf die Nutzlast nicht zerlegen —
    /// die Maskierung ist `jsonEscape`.
    func testAnfuehrungszeichenImTextWerdenMaskiert() throws {
        let json = try NGNutzlast.anzeige(optionen { $0.text = #"sagt "hallo""# })
        XCTAssertTrue(json.contains(#"\"hallo\""#))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(json.utf8)))
    }

    // MARK: - Das Icon

    /// Eine Data-URL traegt das Bild selbst; reines Base64 ohne Vorsatz oder
    /// eine Kennung ueber 64 Zeichen ist `422` (§5.3).
    func testIconBleibtEineDataURL() throws {
        let json = try NGNutzlast.anzeige(optionen(),
                                          iconDatenURI: "data:image/gif;base64,R0lGODlhAQ==")
        XCTAssertTrue(json.contains(#""icon":"data:image/gif;base64,R0lGODlhAQ==""#),
                      "reines Base64 ohne Vorsatz ist 422 (§5.3)")
    }

    /// NG liest kein PNG (§5.3) und faellt bei einem unlesbaren Icon
    /// stillschweigend auf die Anordnung ohne Icon zurueck. Gesagt ist besser
    /// als geschickt.
    func testPngWirdAbgewiesenStattStillVerworfen() {
        XCTAssertThrowsError(try NGNutzlast.anzeige(optionen(),
                                                    iconDatenURI: "data:image/png;base64,iVBOR")) { fehler in
            guard case NGFehler.iconFormat(let typ) = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
            XCTAssertEqual(typ, "PNG")
        }
    }

    /// JPEG schneidet NG auf 8 × 8 zu (§5.3); die App schickt nur GIF.
    func testJpegWirdAbgewiesen() {
        XCTAssertThrowsError(try NGNutzlast.anzeige(optionen(), iconDatenURI: "data:image/jpeg;base64,/9j/4A"))
    }

    /// `iconMode` bildet genau die Frage ab, die „Icon mitlaufen lassen"
    /// stellt: `push` holt es in jedem Laufdurchgang zurueck, `fixed` laesst es
    /// stehen und den Text daran vorbeilaufen.
    func testIconMitlaufenWirdZuIconMode() throws {
        let uri = "data:image/gif;base64,R0lGODlh"
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.iconLaeuftMit = true }, iconDatenURI: uri)
            .contains(#""iconMode":"push""#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.iconLaeuftMit = false }, iconDatenURI: uri)
            .contains(#""iconMode":"fixed""#))
    }

    /// Ohne Icon steht weder `icon` noch `iconMode` da: NG stolpert zwar nicht
    /// darueber, aber ein leerer Schluessel ist eine Angabe, die nichts sagt.
    func testOhneIconStehenBeideSchluesselNichtDa() throws {
        let json = try NGNutzlast.anzeige(optionen())
        XCTAssertFalse(json.contains("icon"))
    }

    // MARK: - Umschalten und die Antwort

    /// Ein Rumpf fuer beide Wege: Ueber HTTP ist `Content-Type:
    /// application/json` bei `PUT` Pflicht, ein blanker Name waere keines —
    /// und §3 sichert zu, dass die MQTT-Nutzlast byteweise derselbe Rumpf ist.
    func testUmschaltenIstJsonUndKeinBlankerName() {
        XCTAssertEqual(NGNutzlast.umschalten(auf: "meldung3"), #"{"name":"meldung3"}"#)
    }

    /// Erfolg ist genau `{"ok":true}`; alles andere traegt seinen Code.
    func testErgebnisWirdGelesen() {
        XCTAssertEqual(NGNutzlast.ergebnis(Data(#"{"ok":true}"#.utf8)), .gelungen)
        XCTAssertEqual(
            NGNutzlast.ergebnis(Data(#"{"ok":false,"error":{"code":"validationFailed","message":"invalid value","field":"durationMs"}}"#.utf8)),
            .abgewiesen("Ungültiger Wert: validationFailed, Feld „durationMs“"))
        XCTAssertEqual(
            NGNutzlast.ergebnis(Data(#"{"ok":false,"error":{"code":"notFound","message":"not found"}}"#.utf8)),
            .abgewiesen("Nicht gefunden: notFound"))
    }

    /// Etwas ohne `ok` ist keine Antwort auf ein Kommando — und darf nicht als
    /// Fehlschlag durchgehen. Sonst machte jede mitgelesene Sendung eine
    /// Fehlerzeile.
    func testEtwasOhneOkIstKeineAntwort() {
        XCTAssertEqual(NGNutzlast.ergebnis(Data(#"{"text":"hallo"}"#.utf8)), .unlesbar)
        XCTAssertEqual(NGNutzlast.ergebnis(Data()), .unlesbar)
        XCTAssertEqual(NGNutzlast.ergebnis(Data("online".utf8)), .unlesbar)
    }

    // MARK: - Die Themen

    /// Kein `_<MAC4>`, kein `custom`: NG schweigt zu einem falschen Thema.
    func testDieThemenSindDieVonNG() {
        XCTAssertEqual(NGThema.anzeige(praefix: "wohnzimmer/uhr", name: "meldung1"),
                       "wohnzimmer/uhr/cmd/apps/pushed/meldung1")
        XCTAssertEqual(NGThema.umschalten(praefix: "awtrixng"), "awtrixng/cmd/apps/switch")
        XCTAssertEqual(NGThema.erreichbarkeit(praefix: "awtrixng"), "awtrixng/availability")
        XCTAssertEqual(NGThema.anzeigenMuster(praefix: "awtrixng"), "awtrixng/cmd/apps/pushed/#")
        XCTAssertEqual(NGThema.ergebnis(zu: "awtrixng/cmd/apps/pushed/meldung1"),
                       "awtrixng/cmd/apps/pushed/meldung1/result")
    }
}

/// Welche Regler auf AWTRIX NG ueberhaupt etwas bewirken.
final class AwtrixNGReglerTests: XCTestCase {

    /// Auf NG fallen genau die Regler weg, die unsere Rasterung steuern —
    /// und keiner mehr. Farbe, Dauer und das mitlaufende Icon wirken dort
    /// unveraendert, Tempo und Großbuchstaben in anderer Gestalt.
    func testAufNGFallenGenauDieRasterreglerWeg() {
        let gesperrt = Regler.allCases.filter { !AwtrixNG.wirkt($0, weg: .text) }
        XCTAssertEqual(Set(gesperrt),
                       [.schriftart, .groesse, .fett, .senkrecht, .rand, .abstand])
    }

    /// Ein gesperrter Regler ohne Begruendung waere ein Bedienelement, das
    /// nicht sagt, warum es nicht geht — genau das, was dieser Durchgang
    /// vermeiden soll.
    func testJederGesperrteReglerHatEinenSatzDazu() {
        for regler in Regler.allCases where !AwtrixNG.wirkt(regler, weg: .text) {
            let satz = AwtrixNG.begruendung(regler, weg: .text)
            XCTAssertNotNil(satz, "\(regler) ist gesperrt und sagt nicht, warum")
            XCTAssertFalse(satz?.isEmpty ?? true)
        }
    }

    /// `textCenter` ist ein bool: mittig oder linksbuendig. Rechtsbuendig
    /// ginge nur ueber eine Verschiebung in Pixeln, und dafuer muesste die App
    /// die Breite des Textes in einer Schrift kennen, die sie nicht hat.
    func testRechtsbuendigGibtEsNicht() {
        XCTAssertEqual(AwtrixNG.waagrechteAusrichtungen(weg: .text), [.links, .mittig])
    }
}
