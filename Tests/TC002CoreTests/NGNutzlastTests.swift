import Foundation
import XCTest
@testable import TC002Core

/// Die Nutzlast einer AWTRIX-NG-Anzeige, byteweise gegen
/// `docs/awtrix-ng-protokoll.md` §5 geprueft.
///
/// **Ohne Geraet und ohne Broker.** Diese Datei rechnet nur; geschickt wird
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
    /// Jeder Schluessel darin steht **ausdruecklich** da, obwohl NG fuer alle
    /// eine Vorgabe hat — und zwar, weil die Vorgabe jedes Mal eine andere ist
    /// als unsere: `textCase` erbt sonst das global eingeschaltete `uppercase`,
    /// `textCenter` ist bei NG `true` und bei uns linksbuendig.
    func testDieAnzeigeTraegtGenauDieseSchluessel() throws {
        XCTAssertEqual(
            try NGNutzlast.anzeige(optionen()),
            ##"{"text":"Grüße","textCase":"asTyped","textColor":"#00FF66","textCenter":false,"scroll":{"speed":100}}"##)
    }

    /// **Der Text bleibt, wie er eingetippt wurde.** Auf der Werksfirmware
    /// macht `Meldungsoptionen.gesendeterText` aus „Großbuchstaben“ ein
    /// `uppercased()` — und damit aus „ß“ ein „SS“. NG versalisiert selbst und
    /// erhaelt dabei die Zeichen; der Schalter gehoert deshalb nach `textCase`
    /// und nicht in den Text.
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

    /// `textCenter` ist ein bool. „mittig" ist `true`, **alles andere ist
    /// `false`** — auch „rechts", das NG nicht kennt und das die Ansicht auf
    /// einer NG-Uhr deshalb gar nicht anbietet
    /// (`Geraetetyp.waagrechteAusrichtungen`). Eine stille Umdeutung nach
    /// mittig waere schlimmer als linksbuendig.
    func testNurMittigIstTextCenter() throws {
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .mittig })
            .contains(#""textCenter":true"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .links })
            .contains(#""textCenter":false"#))
        XCTAssertTrue(try NGNutzlast.anzeige(optionen { $0.waagrecht = .rechts })
            .contains(#""textCenter":false"#))
    }

    /// **Sekunden bei der Werksfirmware, Millisekunden bei NG.** Ein
    /// mitgeschicktes `duration` waere ein unbekannter oberster Schluessel und
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

    /// `scroll.speed` ist ein **Prozentsatz**, unsere Stufen sind Standzeiten.
    /// Umgerechnet, nicht erfunden: „mittel" ist die 100.
    func testTempoWirdInProzentUmgerechnet() {
        XCTAssertEqual(NGNutzlast.tempo(.mittel), 100)
        XCTAssertEqual(NGNutzlast.tempo(.langsam), 67)
        XCTAssertEqual(NGNutzlast.tempo(.schnell), 145)
    }

    /// Ein Text mit Anfuehrungszeichen darf die Nutzlast nicht zerlegen —
    /// dieselbe Maskierung wie beim Rahmen der Werksfirmware.
    func testAnfuehrungszeichenImTextWerdenMaskiert() throws {
        let json = try NGNutzlast.anzeige(optionen { $0.text = #"sagt "hallo""# })
        XCTAssertTrue(json.contains(#"\"hallo\""#))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(json.utf8)))
    }

    // MARK: - Das Icon

    /// **NG entscheidet allein nach der Laenge** (§5.3): bis 64 Zeichen eine
    /// Kennung im Dateisystem des Geraets, darueber Base64 unmittelbar im
    /// Text. Bliebe der `data:`-Vorsatz stehen, waere die Nutzlast zwar lang
    /// genug — aber die Bytes waeren kein Bild.
    func testIconVerliertDenDatenVorsatz() throws {
        let json = try NGNutzlast.anzeige(optionen(),
                                          iconDatenURI: "data:image/gif;base64,R0lGODlhAQ==")
        XCTAssertTrue(json.contains(#""icon":"R0lGODlhAQ==""#))
        XCTAssertFalse(json.contains("data:image"))
    }

    /// **NG liest kein PNG** (§5.3) und faellt bei einem unlesbaren Icon
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

    /// JPEG geht — die Gegenprobe, damit die Pruefung oben nicht alles abweist.
    func testJpegGehtDurch() throws {
        XCTAssertTrue(try NGNutzlast.anzeige(optionen(), iconDatenURI: "data:image/jpeg;base64,/9j/4A")
            .contains(#""icon":"/9j/4A""#))
    }

    /// **Acht Zeilen sind acht Zeilen.** Ein 16×16-Icon ist auf NG nicht bloss
    /// gross: Ein GIF, dessen erstes Bild hoeher ist als die Leinwand, spielt
    /// dort **gar nicht** — ohne Meldung, ohne Fehler. Also gesagt statt
    /// geschickt.
    func testEinSechzehnerIconWirdAbgewiesen() {
        XCTAssertThrowsError(try NGNutzlast.anzeige(optionen(),
                                                    iconDatenURI: "data:image/gif;base64,R0lGODlh",
                                                    iconKante: 16)) { fehler in
            guard case NGFehler.iconZuHoch(let kante) = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
            XCTAssertEqual(kante, 16)
        }
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

    /// **Der Gewinn, den die Werksfirmware nie hatte.** Erfolg ist genau
    /// `{"ok":true}`; alles andere traegt seinen Code.
    func testErgebnisWirdGelesen() {
        XCTAssertEqual(NGNutzlast.ergebnis(Data(#"{"ok":true}"#.utf8)), .gelungen)
        XCTAssertEqual(
            NGNutzlast.ergebnis(Data(#"{"ok":false,"error":{"code":"validationFailed","message":"invalid value","field":"durationMs"}}"#.utf8)),
            .abgewiesen("validationFailed (durationMs)"))
        XCTAssertEqual(
            NGNutzlast.ergebnis(Data(#"{"ok":false,"error":{"code":"notFound","message":"not found"}}"#.utf8)),
            .abgewiesen("notFound"))
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

    /// **Kein `_<MAC4>`, kein `custom`.** Die beiden Firmwares haben an
    /// derselben Stelle voellig verschiedene Themen, und beide schweigen zu
    /// einem falschen.
    func testDieThemenSindDieVonNGUndNichtDieDerWerksfirmware() {
        XCTAssertEqual(NGThema.anzeige(praefix: "wohnzimmer/uhr", name: "meldung1"),
                       "wohnzimmer/uhr/cmd/apps/pushed/meldung1")
        XCTAssertEqual(NGThema.umschalten(praefix: "awtrixng"), "awtrixng/cmd/apps/switch")
        XCTAssertEqual(NGThema.erreichbarkeit(praefix: "awtrixng"), "awtrixng/availability")
        XCTAssertEqual(NGThema.anzeigenMuster(praefix: "awtrixng"), "awtrixng/cmd/apps/pushed/#")
        XCTAssertEqual(NGThema.ergebnis(zu: "awtrixng/cmd/apps/pushed/meldung1"),
                       "awtrixng/cmd/apps/pushed/meldung1/result")
    }
}

/// Welche Regler auf welcher Gattung ueberhaupt etwas bewirken.
final class GeraetetypTests: XCTestCase {

    /// Auf der Werksfirmware rastert die App selbst — jeder Regler formt das
    /// Bild, keiner ist gegenstandslos.
    func testAufDerWerksfirmwareWirktJederRegler() {
        for regler in Regler.allCases {
            XCTAssertTrue(Geraetetyp.tc002.wirkt(regler), "\(regler) müsste auf der TC002 wirken")
            XCTAssertNil(Geraetetyp.tc002.begruendung(regler),
                         "\(regler) ist nicht gesperrt und braucht keine Begründung")
        }
    }

    /// **Auf NG fallen genau die Regler weg, die unsere Rasterung steuern** —
    /// und keiner mehr. Farbe, Dauer und das mitlaufende Icon wirken dort
    /// unveraendert, Tempo und Großbuchstaben in anderer Gestalt.
    func testAufNGFallenGenauDieRasterreglerWeg() {
        let gesperrt = Regler.allCases.filter { !Geraetetyp.awtrixNG.wirkt($0) }
        XCTAssertEqual(Set(gesperrt),
                       [.schriftart, .groesse, .fett, .senkrecht, .rand, .abstand])
    }

    /// Ein gesperrter Regler ohne Begruendung waere ein Bedienelement, das
    /// nicht sagt, warum es nicht geht — genau das, was dieser Durchgang
    /// vermeiden soll.
    func testJederGesperrteReglerHatEinenSatzDazu() {
        for regler in Regler.allCases where !Geraetetyp.awtrixNG.wirkt(regler) {
            let satz = Geraetetyp.awtrixNG.begruendung(regler)
            XCTAssertNotNil(satz, "\(regler) ist gesperrt und sagt nicht, warum")
            XCTAssertFalse(satz?.isEmpty ?? true)
        }
    }

    /// **Der einzige halbe Fall.** `textCenter` ist ein bool: mittig oder
    /// linksbuendig. Rechtsbuendig ginge nur ueber eine Verschiebung in Pixeln,
    /// und dafuer muesste die App die Breite des Textes in einer Schrift
    /// kennen, die sie nicht hat.
    func testRechtsbuendigGibtEsNurAufDerWerksfirmware() {
        XCTAssertEqual(Geraetetyp.tc002.waagrechteAusrichtungen, [.links, .mittig, .rechts])
        XCTAssertEqual(Geraetetyp.awtrixNG.waagrechteAusrichtungen, [.links, .mittig])
    }

    /// Gemalt wird auf 52×16, NGs Anzeige ist 32×8. Ein gestauchtes Bild waere
    /// nicht dasselbe Bild.
    func testGemaltesNimmtNurDieWerksfirmware() {
        XCTAssertTrue(Geraetetyp.tc002.nimmtGemaltes)
        XCTAssertFalse(Geraetetyp.awtrixNG.nimmtGemaltes)
    }
}
