import XCTest
@testable import TC002Core

/// Schreibt die Musterseite `erzeugt/schriftprobe.html`.
///
/// Kein Test im eigentlichen Sinn, sondern ein Werkzeug in Testgestalt: Die
/// Pruefung sagt nur Nein, nie Ja — wer wissen will, ob eine der
/// **uebriggebliebenen** Groessen wirklich lesbar ist, muss sie ansehen. Das
/// kann keine Zusicherung leisten.
///
/// Gezeigt wird deshalb das **tatsaechliche Raster**, Pixel fuer Pixel als
/// Kaestchen — nicht der Text in einer Webschrift. Was hier steht, ist das,
/// was zur Uhr ginge.
///
/// Die Seite kommt ohne Netz aus (kein CDN, keine Webschrift), liest sich auf
/// einem Telefon und folgt dem hellen wie dem dunklen Erscheinungsbild. Ihre
/// Texte sind **nicht** uebersetzt: Sie ist ein Werkzeug fuer die Entwicklung,
/// keine Programmoberflaeche.
final class SchriftprobeSeiteTests: XCTestCase {
    /// Die Umlautzeile: der entscheidende Fall auf einen Blick.
    private static let umlautzeile = "a ä o ö u ü s ß"

    func testMusterseiteSchreiben() throws {
        Schriftbuendel.anmelden()
        for schrift in Schriftbuendel.schriften {
            try XCTSkipUnless(Schriftbuendel.vorhanden(schrift), "Schrift „\(schrift)“ fehlt")
        }

        var koerper = ""
        for schrift in Schriftbuendel.schriften {
            koerper += "<h2>\(entschaerft(schrift))</h2>\n"
            for groesse in SchriftprobeTests.groessen {
                koerper += block(schrift: schrift, groesse: groesse)
            }
        }

        let ziel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("erzeugt")
        try FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: true)
        let datei = ziel.appendingPathComponent("schriftprobe.html")
        try seite(koerper).write(to: datei, atomically: true, encoding: .utf8)

        // Die Seite muss wirklich entstanden sein und Raster enthalten — sonst
        // schriebe dieser Test klaglos eine leere Huelle.
        let geschrieben = try String(contentsOf: datei, encoding: .utf8)
        XCTAssertTrue(geschrieben.contains("Micro 5"))
        XCTAssertGreaterThanOrEqual(geschrieben.components(separatedBy: "class=\"raster\"").count - 1,
                                    2 * Schriftbuendel.schriften.count * SchriftprobeTests.groessen.count,
                                    "je Block ein Musterwort und eine Umlautzeile")
        print("Musterseite: \(datei.path)")
    }

    /// Das Gitter zeigt die Pixel des Rasters, nicht irgendein Gitter: So viele
    /// `<b>` wie gesetzte Punkte, so viele Elemente wie Punkte ueberhaupt.
    /// Ohne das koennte die Seite hübsch und falsch sein.
    func testGitterZeigtDieGerastertenPixel() {
        Schriftbuendel.anmelden()
        let feld = Textraster.rasterPuffer(Schriftprobe.musterwort, schrift: "Tiny5",
                                           groesse: 8, fett: false, farbe: "#FFFFFF", luecke: 1)
        var gesetzt = 0
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite where feld.farbe(x: x, y: y) != nil { gesetzt += 1 }
        }
        XCTAssertGreaterThan(gesetzt, 0)

        let html = Self.raster(Schriftprobe.musterwort, schrift: "Tiny5", groesse: 8)
        XCTAssertEqual(html.components(separatedBy: "<b>").count - 1, gesetzt)
        XCTAssertEqual(html.components(separatedBy: "<i>").count - 1,
                       feld.breite * feld.hoehe - gesetzt)
        XCTAssertTrue(html.contains("repeat(\(feld.breite),5px)"), "die Spaltenzahl muss zum Feld passen")
        // Jedes Kaestchen wieder zu: sonst steckt eines im anderen statt
        // nebeneinander, und das Gitter zeigt eine einzige Spalte.
        XCTAssertEqual(html.components(separatedBy: "</b>").count,
                       html.components(separatedBy: "<b>").count)
        XCTAssertEqual(html.components(separatedBy: "</i>").count,
                       html.components(separatedBy: "<i>").count)
    }

    // MARK: - Bausteine

    private func block(schrift: String, groesse: Double) -> String {
        let gruende = Schriftprobe.ausschlussgruende(schrift: schrift, groesse: groesse)
        let urteil = gruende.isEmpty
            ? "<p class=\"frei\">nicht ausgeschlossen</p>"
            : "<ul class=\"gruende\">" + gruende.map {
                "<li>\(entschaerft($0.beschreibung))</li>"
            }.joined() + "</ul>"

        return """
        <section>
          <h3>\(Int(groesse)) px</h3>
          \(Self.raster(Schriftprobe.musterwort, schrift: schrift, groesse: groesse))
          <p class="beschriftung">a ä o ö u ü s ß</p>
          \(Self.raster(Self.umlautzeile, schrift: schrift, groesse: groesse))
          \(urteil)
        </section>

        """
    }

    /// Ein Pixelfeld als Gitter aus Kaestchen: ein Element je Punkt, `<b>` an,
    /// `<i>` aus — der Rest ist CSS. Die zwei kuerzestmoeglichen Elementnamen,
    /// weil es rund fuenfzigtausend davon werden und die Seite auch auf einem
    /// Telefon aufgehen soll.
    ///
    /// Beide **muessen** geschlossen werden: `<i>` und `<b>` sind keine leeren
    /// Elemente, ein offenes verschachtelt das naechste in sich hinein. Aus
    /// fuenfzigtausend Geschwistern wuerden fuenfzigtausend Ebenen, und das
    /// Gitter legt nur seine unmittelbaren Kinder aus — die Seite zeigte dann
    /// eine einzige Spalte.
    static func raster(_ text: String, schrift: String, groesse: Double) -> String {
        // Abstand 1 wie die Vorgabe der App (`Meldungsoptionen.abstand`).
        let feld = Textraster.rasterPuffer(text, schrift: schrift, groesse: groesse,
                                           fett: false, farbe: "#FFFFFF", luecke: 1)
        var punkte = ""
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite {
                punkte += feld.farbe(x: x, y: y) == nil ? "<i></i>" : "<b></b>"
            }
        }
        return """
        <div class="rasterrahmen"><div class="raster" style="grid-template-columns:repeat(\(feld.breite),5px)">\(punkte)</div></div>
        """
    }

    private func entschaerft(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func seite(_ koerper: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Schriftprobe — MQTT-TC002</title>
        <style>
        :root {
          --grund: #ffffff; --schrift: #1b1b1b; --matt: #666666;
          --karte: #f4f4f5; --kante: #d8d8dc; --aus: #dfdfe3; --an: #16a34a;
          --warnung: #b91c1c; --gut: #15803d;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --grund: #131316; --schrift: #ececee; --matt: #9b9ba3;
            --karte: #1d1d21; --kante: #313138; --aus: #2a2a30; --an: #22c55e;
            --warnung: #f87171; --gut: #4ade80;
          }
        }
        * { box-sizing: border-box; }
        body {
          margin: 0; padding: 16px; background: var(--grund); color: var(--schrift);
          font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
        }
        h1 { font-size: 1.3rem; margin: 0 0 .4rem; }
        h2 { font-size: 1.1rem; margin: 2rem 0 .6rem; }
        h3 { font-size: .95rem; margin: 0 0 .5rem; color: var(--matt); }
        p.hinweis { color: var(--matt); margin: 0 0 1rem; max-width: 46rem; }
        section {
          background: var(--karte); border: 1px solid var(--kante); border-radius: 10px;
          padding: 12px; margin-bottom: 12px;
        }
        .rasterrahmen { overflow-x: auto; margin-bottom: .5rem; }
        /* Die Spaltenzahl steht am Element selbst: sie ist bei jedem Raster
           eine andere, und sie muss stimmen, sonst bricht das Bild um. */
        .raster { display: grid; gap: 1px; width: max-content; }
        .raster i, .raster b { width: 5px; height: 5px; display: block; }
        .raster i { background: var(--aus); }
        .raster b { background: var(--an); }
        .beschriftung { color: var(--matt); font-size: .8rem; margin: .6rem 0 .25rem; }
        ul.gruende { margin: .5rem 0 0; padding-left: 1.2rem; color: var(--warnung); }
        ul.gruende li { margin-bottom: .2rem; overflow-wrap: anywhere; }
        p.frei { margin: .5rem 0 0; color: var(--gut); }
        </style>
        </head>
        <body>
        <h1>Schriftprobe</h1>
        <p class="hinweis">Je Schrift und Größe das Musterwort „Grüße“ und die Umlautzeile
        „a ä o ö u ü s ß“ — als tatsächliches Raster, ein Kästchen je Pixel, mit einer Spalte
        Abstand zwischen den Zeichen wie in der App. Darunter, was gegen diese Größe spricht.
        <strong>„Nicht ausgeschlossen“ heißt nicht „gut“</strong>: Zwei Zeichen können sich um
        ein Pixel unterscheiden und trotzdem unlesbar sein. Das entscheidet nur das Auge.</p>
        \(koerper)</body>
        </html>

        """
    }
}
