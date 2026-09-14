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

    /// Und vor allem: auch **vor** dem Befehlswort. Genau das ging schief —
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

    /// Kurzer Text steht still: `draw`-Befehle, kein Bild.
    func testKurzerTextWirdGerastert() throws {
        let o = try Optionen.zerlegt(["senden", "Hi"])
        var m = o.meldung
        m.text = "Hi"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertFalse(rahmen.draw.isEmpty, "gesetzte Pixel als draw-Befehle")
        XCTAssertTrue(rahmen.bilder.isEmpty)
        XCTAssertTrue(rahmen.texte.isEmpty)
    }

    /// Langer Text laeuft durch: ein animiertes GIF statt draw-Befehlen.
    func testLangerTextWirdZurLaufschrift() throws {
        let text = "Dieser Text ist viel zu lang für zweiundfünfzig Pixel"
        let o = try Optionen.zerlegt(["senden", text])
        var m = o.meldung
        m.text = text
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertTrue(rahmen.draw.isEmpty)
        XCTAssertEqual(rahmen.bilder.count, 1)
        XCTAssertTrue(rahmen.bilder[0].datenURI.hasPrefix("data:image/gif;base64,"))
    }

    /// Mit `--geraeteschrift` setzt die Uhr selbst — ein Textblock, kein Raster.
    func testGeraeteschriftErgibtTextblock() throws {
        let o = try Optionen.zerlegt(["senden", "Hallo", "--geraeteschrift", "--rechts", "--unten"])
        var m = o.meldung
        m.text = "Hallo"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertTrue(rahmen.draw.isEmpty)
        XCTAssertEqual(rahmen.texte.count, 1)
        XCTAssertEqual(rahmen.texte[0].inhalt, "Hallo")
        XCTAssertEqual(rahmen.texte[0].ausrichtung, "right")
        XCTAssertEqual(rahmen.texte[0].vertikal, "bottom")
    }

    func testDauerLandetImRahmen() throws {
        let o = try Optionen.zerlegt(["senden", "Hi", "--dauer", "12"])
        var m = o.meldung
        m.text = "Hi"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
        XCTAssertTrue(rahmen.alsJSON().contains("\"duration\":12"))
    }

    /// Die senkrechte Ausrichtung geht ueber die tatsaechliche Tinte, nicht ueber
    /// die Schriftgroesse — sonst saesse „oben" nicht oben.
    func testSenkrechteAusrichtungVerschiebtDenText() throws {
        func hoechsteZeile(_ argumente: [String]) throws -> Int {
            let o = try Optionen.zerlegt(argumente)
            var m = o.meldung
            m.text = "Hg"
            let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
            return rahmen.draw.map(\.y).min() ?? -1
        }
        let oben = try hoechsteZeile(["senden", "Hg", "--oben", "--rand", "0"])
        let mitte = try hoechsteZeile(["senden", "Hg", "--mitte"])
        let unten = try hoechsteZeile(["senden", "Hg", "--unten", "--rand", "0"])
        XCTAssertEqual(oben, 0, "ohne Rand sitzt die Tinte an der obersten Zeile")
        XCTAssertLessThan(oben, mitte)
        XCTAssertLessThan(mitte, unten)
    }
}

/// Die beiden Befehle fuer den Bilderbestand (14.09.2026). Ein Bild ist eine
/// ganze Anzeige und ersetzt Text und Icon — deshalb ein eigener Befehl und
/// nicht eine Option an `senden`.
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

    /// `--name` und `--dauer` gelten auch fuer ein Bild: Sie sagen, **wohin**
    /// und **wie lange**, nicht wie etwas gesetzt wird.
    func testPlatzUndDauerGeltenAuchFuerEinBild() throws {
        let o = try Optionen.zerlegt(["bild", "Herz", "--name", "meldung3", "--dauer", "7"])
        XCTAssertEqual(o.befehl, .bild(name: "Herz"))
        XCTAssertEqual(o.anzeigename, "meldung3")
        XCTAssertEqual(o.dauer, 7)
    }
}
