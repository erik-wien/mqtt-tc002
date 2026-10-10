import XCTest
import TC002Core
@testable import TC002CLI

/// Geprueft wird das Zerlegen der Kommandozeile und der Rahmenbau — beides ohne
/// Netz und ohne Geraet. Das Senden selbst hat `MQTTSenderTests` schon abgedeckt.
final class OptionenTests: XCTestCase {

    func testTextOhneBefehlswortGiltAlsSenden() throws {
        let o = try Optionen.zerlegt(["Kaffee", "fertig"])
        XCTAssertEqual(o.befehl, .senden(text: "Kaffee fertig"))
    }

    func testBefehlswortUndText() throws {
        XCTAssertEqual(try Optionen.zerlegt(["senden", "Hallo"]).befehl, .senden(text: "Hallo"))
        XCTAssertEqual(try Optionen.zerlegt(["loeschen", "cli"]).befehl, .loeschen(anzeige: "cli"))
        XCTAssertEqual(try Optionen.zerlegt(["umschalten", "cli"]).befehl, .umschalten(anzeige: "cli"))
        XCTAssertEqual(try Optionen.zerlegt(["uhren"]).befehl, .uhren)
        XCTAssertEqual(try Optionen.zerlegt([]).befehl, .hilfe)
    }

    /// Der Text darf wie eine Option aussehen, solange er hinter einem Befehl
    /// steht — sonst liesse sich „--- Achtung ---" nie senden. Das gilt hier
    /// nicht, deshalb: eine echte unbekannte Option muss auffallen.
    func testUnbekannteOptionWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Hallo", "--gibtsnicht"])) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("gibtsnicht") == true)
        }
    }

    func testFehlenderWertWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Hallo", "--farbe"])) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("--farbe") == true)
        }
    }

    func testUngueltigeFarbeWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Hallo", "--farbe", "gruen"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Hallo", "--farbe", "#GGGGGG"]))
        XCTAssertNoThrow(try Optionen.zerlegt(["senden", "Hallo", "--farbe", "#00FF66"]))
    }

    func testKeineZahlWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Hallo", "--dauer", "lang"])) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("--dauer") == true)
        }
    }

    func testTextOhneInhaltWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "--fett"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["loeschen"]))
    }

    func testGrossbuchstabenWirkenAufDenText() throws {
        let o = try Optionen.zerlegt(["senden", "grüße", "--gross"])
        XCTAssertEqual(o.befehl, .senden(text: "GRÜSSE"))
    }

    func testMehrereZieleSammelnSich() throws {
        let o = try Optionen.zerlegt(["senden", "x", "--an", "Küche", "--an", "Bad"])
        XCTAssertEqual(o.ziele, ["Küche", "Bad"])
    }

    func testEnglischeUndDeutscheSchreibweiseSindGleichwertig() throws {
        let deutsch = try Optionen.zerlegt(["senden", "x", "--farbe", "#FF0000", "--fett", "--zentriert", "--unten"])
        let englisch = try Optionen.zerlegt(["send", "x", "--color", "#FF0000", "--bold", "--center", "--bottom"])
        XCTAssertEqual(deutsch.farbe, englisch.farbe)
        XCTAssertEqual(deutsch.fett, englisch.fett)
        XCTAssertEqual(deutsch.waagrecht, englisch.waagrecht)
        XCTAssertEqual(deutsch.senkrecht, englisch.senkrecht)
    }

    /// Beide Achsen teilen sich den Fallnamen `.mittig` — eine Vertauschung von
    /// waagrecht und senkrecht faellt sonst keinem Test und keinem Uebersetzer auf.
    /// Deshalb hier je Achse ein Wert, der sich vom anderen unterscheidet.
    func testZentriertUndMitteTreffenVerschiedeneAchsen() throws {
        let a = try Optionen.zerlegt(["senden", "x", "--zentriert", "--oben"])
        XCTAssertEqual(a.waagrecht, .mittig)
        XCTAssertEqual(a.senkrecht, .oben)
        let b = try Optionen.zerlegt(["senden", "x", "--rechts", "--mitte"])
        XCTAssertEqual(b.waagrecht, .rechts)
        XCTAssertEqual(b.senkrecht, .mittig)
    }

    func testVorgabenEntsprechenDerApp() throws {
        let o = try Optionen.zerlegt(["senden", "x"])
        XCTAssertEqual(o.farbe, "#00FF66")
        XCTAssertEqual(o.schrift, "Silkscreen")
        XCTAssertEqual(o.groesse, 8)
        XCTAssertEqual(o.anzeigename, "cli")
        XCTAssertEqual(o.senkrecht, .mittig)
        XCTAssertEqual(o.waagrecht, .links)
    }

    /// `-AppleLanguages "(en)"` startet das Werkzeug einmalig auf Englisch.
    /// Foundation wertet das selbst aus; hier darf es weder als unbekannte
    /// Option scheitern noch im Text landen.
    func testEinstellungsargumenteLandenNichtImText() throws {
        let o = try Optionen.zerlegt(["senden", "-AppleLanguages", "(en)", "Hallo"])
        XCTAssertEqual(o.befehl, .senden(text: "Hallo"))
    }

    /// Und vor allem: auch vor dem Befehlswort. Genau das ging schief —
    /// `-AppleLanguages` stand an der Stelle des Befehls, also galt alles als
    /// Text, und `mqtttc002 -AppleLanguages "(en)" uhren` schickte das Wort
    /// „uhren" an die Uhr, statt die Liste zu zeigen.
    func testEinstellungsargumentVorDemBefehlswort() throws {
        XCTAssertEqual(try Optionen.zerlegt(["-AppleLanguages", "(en)", "uhren"]).befehl, .uhren)
        XCTAssertEqual(try Optionen.zerlegt(["-AppleLanguages", "(en)", "hilfe"]).befehl, .hilfe)
        XCTAssertEqual(try Optionen.zerlegt(["-AppleLanguages", "(en)", "senden", "Hallo"]).befehl,
                       .senden(text: "Hallo"))
    }

    /// Ein einzelner Strich mit Kleinbuchstaben ist dagegen keines — das soll
    /// weiterhin als unbekannt auffallen und nicht stillschweigend verschwinden.
    func testEinzelnerStrichKleingeschriebenBleibtText() throws {
        let o = try Optionen.zerlegt(["senden", "-5", "Grad"])
        XCTAssertEqual(o.befehl, .senden(text: "-5 Grad"))
    }

    // MARK: - Der Rahmenbau

    private func sammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    /// Der Werkzeug-Rahmen geht als Pixel hinaus (`Pixelweg`); mit
    /// „als Text" traegt er Text und Regler als Herkunft.
    func testDerRahmenGehtAlsPixelUndAlsTextMitHerkunft() throws {
        let o = try Optionen.zerlegt(["senden", "Hi", "--rechts", "--unten"])
        var m = o.meldung
        m.text = "Hi"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertNotNil(rahmen.pixel)
        XCTAssertNil(rahmen.herkunft)
        m.weg = .text
        let textrahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertNil(textrahmen.pixel)
        let herkunft = try XCTUnwrap(textrahmen.herkunft)
        XCTAssertEqual(herkunft.optionen.text, "Hi")
        XCTAssertEqual(herkunft.optionen.waagrecht, .rechts)
        XCTAssertEqual(herkunft.optionen.senkrecht, .unten)
    }

    func testDauerLandetImRahmen() throws {
        let o = try Optionen.zerlegt(["senden", "Hi", "--dauer", "12"])
        var m = o.meldung
        m.text = "Hi"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertEqual(rahmen.dauer, 12)
    }
}

/// Die beiden Befehle fuer den Bilderbestand. Ein Bild ist eine ganze
/// Anzeige und ersetzt Text und Icon — deshalb ein eigener Befehl und nicht
/// eine Option an `senden`.
final class BildbefehlTests: XCTestCase {
    func testBildMitNamen() throws {
        let o = try Optionen.zerlegt(["bild", "Herz"])
        XCTAssertEqual(o.befehl, .bild(name: "Herz"))
    }

    /// Ein Name aus mehreren Woertern kommt zusammengesetzt an — wie der Text
    /// bei `senden`, und aus demselben Grund: Die Schale hat ihn laengst
    /// zerlegt.
    func testEinNameAusMehrerenWoertern() throws {
        XCTAssertEqual(try Optionen.zerlegt(["bild", "Hallo", "Welt"]).befehl,
                       .bild(name: "Hallo Welt"))
    }

    func testOhneNamenEineVerstaendlicheMeldung() {
        XCTAssertThrowsError(try Optionen.zerlegt(["bild"])) { f in
            // Die Meldung nennt den Weg zur Liste — dieselbe Bauart wie bei
            // den uebrigen Fehlern dieses Zerlegers.
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("bilder") == true)
        }
    }

    func testBilderAuflisten() throws {
        XCTAssertEqual(try Optionen.zerlegt(["bilder"]).befehl, .bilder)
        XCTAssertEqual(try Optionen.zerlegt(["images"]).befehl, .bilder)
    }

    /// `--name` und `--dauer` gelten auch fuer ein Bild: Sie sagen, wohin
    /// und wie lange, nicht wie etwas gesetzt wird.
    func testPlatzUndDauerGeltenAuchFuerEinBild() throws {
        let o = try Optionen.zerlegt(["bild", "Herz", "--name", "meldung3", "--dauer", "7"])
        XCTAssertEqual(o.befehl, .bild(name: "Herz"))
        XCTAssertEqual(o.anzeigename, "meldung3")
        XCTAssertEqual(o.dauer, 7)
    }

}

/// Die Befehle `nachricht`/`zurueckziehen` und die Lebensdauer von `senden`.
final class BenachrichtigungsbefehlTests: XCTestCase {

    func testNachrichtAufDeutschUndEnglisch() throws {
        XCTAssertEqual(try Optionen.zerlegt(["nachricht", "Tür", "offen"]).befehl,
                       .nachricht(text: "Tür offen"))
        XCTAssertEqual(try Optionen.zerlegt(["message", "Door"]).befehl, .nachricht(text: "Door"))
    }

    /// Vorgabe: bleibt stehen, weckt, läuft zweimal durch, wird eingereiht.
    func testDieVorgabenEinerNachricht() throws {
        let o = try Optionen.zerlegt(["nachricht", "x"])
        XCTAssertEqual(o.benachrichtigung, Benachrichtigungsoptionen(
            name: nil, halten: true, einreihen: true, aufwecken: true, wiederholungen: 2))
    }

    func testDieOptionenZumAbschaltenUndAendern() throws {
        let o = try Optionen.zerlegt(["nachricht", "x", "--name", "tuer", "--nicht-halten", "--ersetzen",
                                      "--nicht-wecken", "--wiederholungen", "3", "--dauer", "8"])
        XCTAssertEqual(o.benachrichtigung, Benachrichtigungsoptionen(
            name: "tuer", halten: false, einreihen: false, aufwecken: false, wiederholungen: 3))
        XCTAssertEqual(o.meldung.dauer, 8)

        let e = try Optionen.zerlegt(["message", "x", "--no-hold", "--replace", "--no-wakeup", "--repeat", "3"])
        XCTAssertEqual(e.benachrichtigung, Benachrichtigungsoptionen(
            name: nil, halten: false, einreihen: false, aufwecken: false, wiederholungen: 3))
    }

    /// Ohne `--name` hat sie keinen — die Vorgabe „cli" gilt nur für Anzeigen.
    func testOhneNamenHatDieNachrichtKeinen() throws {
        XCTAssertNil(try Optionen.zerlegt(["nachricht", "x"]).benachrichtigung.name)
    }

    func testNachrichtNimmtDieFormatoptionenWieSenden() throws {
        let o = try Optionen.zerlegt(["nachricht", "grüße", "--gross", "--farbe", "#FF0000",
                                      "--icon", "12", "--zentriert", "--tempo", "schnell"])
        XCTAssertEqual(o.befehl, .nachricht(text: "GRÜSSE"))
        XCTAssertEqual(o.farbe, "#FF0000")
        XCTAssertEqual(o.iconNummer, "12")
        XCTAssertEqual(o.waagrecht, .mittig)
        XCTAssertEqual(o.tempo, .schnell)
    }

    func testNachrichtOhneTextWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "--ersetzen"]))
    }

    func testWiederholungenMuessenPositivSein() {
        for w in ["0", "-1", "viel"] {
            XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "x", "--wiederholungen", w]), w) { f in
                XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("--wiederholungen") == true)
            }
        }
    }

    func testZurueckziehenSichtbareUndNachName() throws {
        XCTAssertEqual(try Optionen.zerlegt(["zurueckziehen"]).befehl, .zurueckziehen(name: nil))
        XCTAssertEqual(try Optionen.zerlegt(["dismiss"]).befehl, .zurueckziehen(name: nil))
        XCTAssertEqual(try Optionen.zerlegt(["zurueckziehen", "tuer"]).befehl, .zurueckziehen(name: "tuer"))
        XCTAssertEqual(try Optionen.zerlegt(["dismiss", "--name", "tuer"]).befehl, .zurueckziehen(name: "tuer"),
                       "sonst nähme `--name` stillschweigend die sichtbare weg")
        XCTAssertEqual(try Optionen.zerlegt(["dismiss", "tuer", "--an", "Küche"]).ziele, ["Küche"])
    }

    // MARK: - Lebensdauer

    func testLebensdauerUndAblauf() throws {
        let o = try Optionen.zerlegt(["senden", "x", "--lebensdauer", "600", "--ablauf", "markieren"])
        XCTAssertEqual(o.meldung.lebensdauer, Lebensdauer(sekunden: 600, ablauf: .markieren))
        let e = try Optionen.zerlegt(["send", "x", "--lifetime", "5", "--expiry", "remove"])
        XCTAssertEqual(e.meldung.lebensdauer, Lebensdauer(sekunden: 5, ablauf: .entfernen))
        let m = try Optionen.zerlegt(["send", "x", "--lifetime", "5", "--expiry", "mark"])
        XCTAssertEqual(m.meldung.lebensdauer?.ablauf, .markieren)
    }

    func testOhneAblaufWirdEntfernt() throws {
        XCTAssertEqual(try Optionen.zerlegt(["senden", "x", "--lebensdauer", "9"]).meldung.lebensdauer,
                       Lebensdauer(sekunden: 9, ablauf: .entfernen))
    }

    /// Ohne jede Angabe gilt die Vorgabe: 30 Minuten, `remove`.
    func testOhneAngabeGiltDieVorgabe() throws {
        let m = try Optionen.zerlegt(["senden", "x"]).meldung
        XCTAssertNil(m.lebensdauer)
        XCTAssertEqual(m.wirksameLebensdauer, Lebensdauer(sekunden: 1800, ablauf: .entfernen))
    }

    func testNurDerAblaufAendertDieVorgabeDerZeit() throws {
        let m = try Optionen.zerlegt(["senden", "x", "--ablauf", "markieren"]).meldung
        XCTAssertEqual(m.wirksameLebensdauer, Lebensdauer(sekunden: 1800, ablauf: .markieren))
    }

    func testBehaltenSchaltetDieLebensdauerAb() throws {
        for schalter in ["--behalten", "--keep"] {
            let m = try Optionen.zerlegt(["senden", "x", schalter]).meldung
            XCTAssertEqual(m.lebensdauer, Lebensdauer.aus)
            XCTAssertNil(m.wirksameLebensdauer, "die Uhr bekommt kein lifetimeMs")
        }
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--behalten", "--lebensdauer", "5"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--keep", "--ablauf", "mark"]))
    }

    func testLebensdauerBrauchtEineZahlGroesserNull() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--lebensdauer", "lang"]))
        for w in ["0", "-3"] {
            XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--lebensdauer", w]), w)
        }
    }

    func testUnbekannterAblaufWirdGemeldet() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--lebensdauer", "5", "--ablauf", "morgen"])) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("morgen") == true)
        }
    }

    /// Eine Benachrichtigung ignoriert die Lebensdauer, und ein Feld nur für
    /// Benachrichtigungen ist an einer Anzeige `422`: Beides wird gesagt, statt
    /// still nichts zu bewirken.
    func testOptionenDieDerBefehlNichtKennt() {
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "x", "--lebensdauer", "5"])) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("--lebensdauer") == true)
        }
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "x", "--behalten"]))
        for option in ["--nicht-halten", "--ersetzen", "--nicht-wecken"] {
            XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", option]), option) { f in
                XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains(option) == true)
            }
        }
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--wiederholungen", "2"]))
    }

    /// Eine Benachrichtigung trägt keine Lebensdauer in ihren Optionen.
    func testDieMeldungEinerBenachrichtigungHatKeineLebensdauer() throws {
        XCTAssertNil(try Optionen.zerlegt(["nachricht", "x"]).meldung.lebensdauer)
    }

    // MARK: - Hilfetext und Zerleger

    // MARK: - Darstellung, Diagramm, Fortschritt

    func testDieDarstellungWirdZerlegt() throws {
        let o = try Optionen.zerlegt(["senden", "Regen", "--effekt", "Plasma", "--effekt-tempo", "2,5",
                                      "--overlay", "rain", "--palette", "#FF0000,#0000FF",
                                      "--palette-hart", "--palette-spanne", "6", "--palette-tempo", "0.5",
                                      "--text-palette"])
        XCTAssertEqual(o.darstellung, Darstellung(
            effekt: "Plasma", effektTempo: 2.5, overlay: "rain", palette: .farben(["#FF0000", "#0000FF"]),
            paletteUeberblenden: false, paletteSpanne: 6, paletteTempo: 0.5, textfarbeAusPalette: true))
        XCTAssertFalse(o.grafikGesetzt)
        XCTAssertEqual(try Optionen.palette("Lava"), .name("Lava"))
        XCTAssertEqual(try Optionen.palette("#FF0000@0,#0000FF@100"),
                       .stellen([.init(farbe: "#FF0000", pos: 0), .init(farbe: "#0000FF", pos: 100)]))
        XCTAssertThrowsError(try Optionen.palette("#FF0000,#0000FF@100"))
    }

    func testDieDarstellungWirdBeimZerlegenGeprueft() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--effekt-tempo", "99"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--hintergrund", "#000000", "--effekt", "Plasma"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--palette-tempo", "1"]), "ohne Palette")
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--hintergrund", "rot"]))
    }

    func testEineGrafikBrauchtKeinenTextUndKeinenText() throws {
        let o = try Optionen.zerlegt(["senden", "--linie", "3,5,-2", "--diagrammfarbe", "palette",
                                      "--palette", "Ocean", "--fortschritt", "40",
                                      "--fortschrittsfarbe", "#00FF00", "--fortschrittsgrund", "#222222",
                                      "--feste-skala"])
        XCTAssertTrue(o.grafikGesetzt)
        XCTAssertEqual(o.grafik, Grafikinhalt(diagramm: .linie([3, 5, -2]), diagrammSkalieren: false,
                                              diagrammfarbe: .palette, fortschritt: 40,
                                              fortschrittsfarbe: .farbe("#00FF00"), fortschrittsgrund: "#222222"))
        XCTAssertNotNil(try? Optionen.zerlegt(["nachricht", "--balken", "1,2"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Text", "--balken", "1,2"]), "Text und Grafik")
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "--balken", "1,x"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "--linie", "1"]), "eine Linie braucht zwei")
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "--fortschritt", "101"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "--fortschritt", "5", "--fortschrittsfarbe", "palette"]),
                             "ohne Palette")
        XCTAssertThrowsError(try Optionen.zerlegt(["senden"]), "weder Text noch Grafik")
    }

    func testDieDarstellungGiltNurFuerSendenUndNachricht() {
        XCTAssertThrowsError(try Optionen.zerlegt(["loeschen", "cli", "--overlay", "rain"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["bild", "Herz", "--fortschritt", "5"]))
        XCTAssertNoThrow(try Optionen.zerlegt(["effekte"]))
    }

    func testDerRahmenTraegtDieDarstellung() throws {
        let o = try Optionen.zerlegt(["senden", "Regen", "--overlay", "rain"])
        let text = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Regen", weg: .text)))
        XCTAssertEqual(o.mitDarstellung(text).darstellung, Darstellung(overlay: "rain"))
        let g = try Optionen.zerlegt(["senden", "--fortschritt", "5", "--dauer", "9", "--overlay", "snow"])
        let rahmen = g.grafikrahmen
        XCTAssertEqual(rahmen.grafik, Grafikinhalt(fortschritt: 5))
        XCTAssertEqual(rahmen.dauer, 9)
        XCTAssertNil(rahmen.herkunft)
        XCTAssertEqual(try Anzeigen.nutzlast(rahmen).hasPrefix(##"{"progress":5,"durationMs":9000"##), true)
    }

    /// Ob `option` irgendwo erkannt wird. Eine andere Beanstandung (fehlender
    /// Wert, falscher Befehl) heißt: Die Option ist bekannt.
    private func zerleggerKennt(_ option: String) -> Bool {
        for args in [["senden", "x", option], ["senden", "x", option, "1"],
                     ["message", "x", option], ["message", "x", option, "1"]] {
            do { _ = try Optionen.zerlegt(args); return true }
            catch Optionen.Fehler.unbekannteOption(let o) where o == option { continue }
            catch { return true }
        }
        return false
    }

    // MARK: - Layout und Bildschirm

    func testLayoutNimmtEineDateiUndDieOptionenEinerAnzeige() throws {
        let o = try Optionen.zerlegt(["layout", "drei.json", "--an", "Küche", "--name", "meldung2",
                                      "--dauer", "8", "--lebensdauer", "600", "--ablauf", "markieren", "--trocken"])
        XCTAssertEqual(o.befehl, .layout(datei: "drei.json"))
        XCTAssertEqual(o.ziele, ["Küche"])
        XCTAssertEqual(o.anzeigename, "meldung2")
        XCTAssertTrue(o.trocken)
        XCTAssertEqual(o.meldung.wirksameLebensdauer, Lebensdauer(sekunden: 600, ablauf: .markieren))
        XCTAssertEqual(o.dauer, 8)
    }

    /// Ein Layout verfällt wie jede Anzeige nach 30 Minuten, wenn nichts anderes gilt.
    func testEinLayoutHatDieVorgabeLebensdauer() throws {
        XCTAssertEqual(try Optionen.zerlegt(["layout", "x.json"]).meldung.wirksameLebensdauer, Lebensdauer.vorgabe)
        XCTAssertNil(try Optionen.zerlegt(["layout", "x.json", "--behalten"]).meldung.wirksameLebensdauer)
    }

    func testLayoutOhneDateiUndMitFremdenOptionen() {
        XCTAssertThrowsError(try Optionen.zerlegt(["layout"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["layout", "x.json", "--effekt", "Plasma"]), "Darstellung steht im Layout")
        XCTAssertThrowsError(try Optionen.zerlegt(["layout", "x.json", "--ersetzen"]), "nur für Nachrichten")
    }

    func testBildschirmUndSeineEnglischeFassung() throws {
        XCTAssertEqual(try Optionen.zerlegt(["bildschirm"]).befehl, .bildschirm)
        XCTAssertEqual(try Optionen.zerlegt(["screen", "--to", "Küche"]).befehl, .bildschirm)
    }

    /// Jede Option, die ein Hilfetext nennt, muss der Zerleger kennen — sonst
    /// steht dort eine Zusage, die „Unbekannte Option“ beantwortet. Gelesen wird
    /// der Quelltext des deutschen Textes und die englische Übersetzung.
    func testJedeOptionDerHilfeIstDemZerlegerBekannt() throws {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let quellen = ["Sources/TC002CLI/main.swift", "Resources/Sprachen/en.lproj/Localizable.strings"]
        for quelle in quellen {
            var text = try String(contentsOf: wurzel.appendingPathComponent(quelle), encoding: .utf8)
            if quelle.hasSuffix(".strings") {
                text = try XCTUnwrap(text.split(separator: "\n").first { $0.hasPrefix("\"cli.hilfe\"") }.map(String.init))
                    .replacingOccurrences(of: "\\n", with: "\n")
            } else {
                let anfang = try XCTUnwrap(text.range(of: "let hilfetext = \"\"\""))
                text = String(text[anfang.upperBound...].prefix(upTo: try XCTUnwrap(text.range(of: "\"\"\"\n", range: anfang.upperBound..<text.endIndex)).lowerBound))
            }
            let optionen = Set(text.split(whereSeparator: { " \n|,()\"".contains($0) })
                .map(String.init).filter { $0.hasPrefix("--") && $0.count > 3 }
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".:;")) })
            XCTAssertTrue(optionen.contains("--lebensdauer") || optionen.contains("--lifetime"), quelle)
            for option in optionen where option != "--help" {
                XCTAssertTrue(zerleggerKennt(option), "\(quelle): \(option) kennt der Zerleger nicht")
            }
        }
    }
}
