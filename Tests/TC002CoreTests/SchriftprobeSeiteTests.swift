import XCTest
@testable import TC002Core

/// Schreibt die Musterseite `erzeugt/schriftprobe.html` — das **Werkzeug**.
///
/// Die Schriftprobe in der App zeigt dieselbe Messung fuer Anwender; diese
/// Seite ist die Fassung zum Abhaken: Sie traegt je Block ein Kreuz „brauchbar"
/// und baut daraus unten die Swift-Zeile, die in `sauberePixelgroessen`
/// gehoerte. Das ist der Unterschied, und nur er — gemessen wird dasselbe.
///
/// Gezeigt werden die **Kollisionsgruppen als Raster**, nicht ein festes Wort:
/// Die Frage lautet je Zeile „sind genau diese zusammengefallenen Zeichen noch
/// auseinanderzuhalten?", und die beantwortet nur, wer die Mitglieder
/// unmittelbar nebeneinander sieht. Ein festes Wort zeigt in jeder Zeile
/// dasselbe und beantwortet sie nie.
///
/// Die Seite kommt ohne Netz aus (kein CDN, keine Webschrift), liest sich auf
/// einem Telefon und folgt dem hellen wie dem dunklen Erscheinungsbild. Ihre
/// Texte sind **nicht** uebersetzt: Sie ist ein Werkzeug fuer die Entwicklung,
/// keine Programmoberflaeche. Die Ausschlussgruende kommen aus
/// `Grund.beschreibung` und sind es doch — sie stehen auch in der App.
final class SchriftprobeSeiteTests: XCTestCase {
    func testMusterseiteSchreiben() throws {
        Schriftbuendel.anmelden()
        // Die mitgelieferten Schriften liegen im Quellbaum — fehlen sie, ist
        // etwas am Baum faul und die Seite waere wertlos. Die Systemschriften
        // koennen dagegen von Rechner zu Rechner fehlen; dann steht das auf der
        // Seite, statt dass ein Ergebnis der Ersatzschrift dort erschiene.
        for schrift in Schriften.mitgeliefert {
            try XCTSkipUnless(Schriftbuendel.vorhanden(schrift), "Schrift „\(schrift)“ fehlt")
        }

        let messungen = Schriftprobe.alleMessungen()
        var koerper = ""
        var erwarteteRaster = 0
        for schrift in Schriftprobe.schriften {
            koerper += "<h2>\(entschaerft(schrift))</h2>\n"
            let eigene = messungen.filter { $0.schrift == schrift }
            guard !eigene.isEmpty else {
                koerper += "<p class=\"fehlt\">Auf diesem Rechner nicht installiert — nicht gemessen.</p>\n"
                continue
            }
            for messung in eigene {
                koerper += Self.block(messung)
                erwarteteRaster += messung.gruppen.count + (messung.umlautbild == nil ? 0 : 1) + 1
            }
        }

        let ziel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("erzeugt")
        try FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: true)
        let datei = ziel.appendingPathComponent("schriftprobe.html")
        try seite(koerper).write(to: datei, atomically: true, encoding: .utf8)

        // Die Seite muss wirklich entstanden sein und genau so viele Raster
        // enthalten, wie die Messung hergibt — sonst schriebe dieser Test
        // klaglos eine leere Huelle oder liesse Gruppen unter den Tisch fallen.
        let geschrieben = try String(contentsOf: datei, encoding: .utf8)
        XCTAssertTrue(geschrieben.contains("Micro 5"))
        XCTAssertEqual(geschrieben.components(separatedBy: "class=\"raster\"").count - 1,
                       erwarteteRaster, "Zahl der Raster")
        print("Musterseite: \(datei.path)")
    }

    /// Das Gitter zeigt die Pixel des Rasters, nicht irgendein Gitter: So viele
    /// `<b>` wie gesetzte Punkte, so viele Elemente wie Punkte ueberhaupt.
    /// Ohne das koennte die Seite hübsch und falsch sein.
    func testGitterZeigtDieGerastertenPixel() {
        Schriftbuendel.anmelden()
        let feld = Textraster.rasterPuffer("HKX", schrift: "Micro 5", groesse: 12,
                                           fett: false, farbe: "#FFFFFF", luecke: 1)
        var gesetzt = 0
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite where feld.farbe(x: x, y: y) != nil { gesetzt += 1 }
        }
        XCTAssertGreaterThan(gesetzt, 0)

        let html = Self.raster(feld)
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

    /// Der Block zeigt die zusammengefallenen Zeichen — und zwar diese, nicht
    /// irgendein Wort. Bei Micro 5 in 12 px sind das vier Gruppen, alle zu
    /// sehen; bei 8 px zu viele, dann wird gekappt und der Rest steht als Text.
    func testBlockZeigtDieKollisionsgruppenUndKapptBeiVielen() {
        Schriftbuendel.anmelden()
        let wenige = Schriftprobe.messen(schrift: "Micro 5", groesse: 12)
        let blockWenige = Self.block(wenige)
        for gruppe in wenige.gruppen {
            XCTAssertTrue(blockWenige.contains(gruppe.text), "Gruppe \(gruppe.text) fehlt im Block")
        }
        XCTAssertFalse(blockWenige.contains("weitere Gruppen"))
        XCTAssertFalse(blockWenige.contains(Schriftprobe.umlautprobe),
                       "ohne Umlautschaden keine Umlautzeile")

        let viele = Schriftprobe.messen(schrift: "Micro 5", groesse: 8)
        let blockViele = Self.block(viele)
        XCTAssertTrue(blockViele.contains("weitere Gruppen"))
        XCTAssertTrue(blockViele.contains(Schriftprobe.umlautprobe),
                      "„Ö=Ü“ ist ein Umlautschaden — dann gehört die Zeile hin")
    }

    // MARK: - Bausteine

    /// Ein Block aus der gemeinsamen Messung. Dieselben Gruppen, dieselbe
    /// Kappung, dieselbe Umlautentscheidung wie in der App — hier nur mit
    /// Kreuz und Swift-Ausgabe drumherum.
    static func block(_ m: Schriftprobe.Messung) -> String {
        let marke: (String, String)
        switch m.lage {
        case .nichtsFaelltZusammen: marke = ("frei", "nichts fällt zusammen")
        case .wenigeGruppen: marke = ("entscheidung", "hier ist zu entscheiden")
        case .vieleGruppen: marke = ("entschieden", "schon entschieden")
        }

        var inhalt = ""
        if m.gruppen.isEmpty {
            inhalt += "<p class=\"frei\">Kein Zeichen fällt mit einem anderen zusammen — nichts zu vergleichen.</p>\n"
        } else {
            inhalt += "<div class=\"gruppen\">"
            for gruppe in m.gruppen {
                inhalt += "<div class=\"gruppe\"><p class=\"beschriftung\">\(entschaerft(gruppe.text))</p>"
                inhalt += raster(gruppe.bild)
                inhalt += "</div>"
            }
            inhalt += "</div>\n"
            if !m.weitereGruppen.isEmpty {
                let liste = m.weitereGruppen.map(entschaerft).joined(separator: ", ")
                inhalt += "<p class=\"rest\">und \(m.weitereGruppen.count) weitere Gruppen: \(liste)</p>\n"
            }
        }

        if let umlautbild = m.umlautbild {
            inhalt += "<p class=\"beschriftung\">Umlaute: \(Schriftprobe.umlautprobe)</p>"
            inhalt += raster(umlautbild) + "\n"
        } else {
            inhalt += "<p class=\"frei\">Umlaute sauber.</p>\n"
        }

        if !m.gruende.isEmpty {
            inhalt += "<ul class=\"gruende\">"
                + m.gruende.map { "<li>\(entschaerft($0.beschreibung))</li>" }.joined()
                + "</ul>\n"
        }

        // Das Musterwort ganz unten und klein: Es entscheidet nichts, aber ohne
        // einen zusammenhaengenden Text fehlt der Gesamteindruck.
        inhalt += "<p class=\"beschriftung leise\">\(Schriftprobe.musterwort)</p>"
        inhalt += raster(m.musterbild)

        return """
        <section class="\(marke.0)">
          <h3>\(Int(m.groesse)) px <span class="marke">\(marke.1)</span>
              <label class="haken"><input type="checkbox" data-schrift="\(entschaerft(m.schrift))" data-groesse="\(Int(m.groesse))"> brauchbar</label></h3>
          \(inhalt)
        </section>

        """
    }

    /// Ein Pixelfeld als Gitter aus Kaestchen: ein Element je Punkt, `<b>` an,
    /// `<i>` aus — der Rest ist CSS. Die zwei kuerzestmoeglichen Elementnamen,
    /// weil es einige zehntausend davon werden und die Seite auch auf einem
    /// Telefon aufgehen soll.
    ///
    /// Beide **muessen** geschlossen werden: `<i>` und `<b>` sind keine leeren
    /// Elemente, ein offenes verschachtelt das naechste in sich hinein. Aus
    /// zehntausend Geschwistern wuerden zehntausend Ebenen, und das Gitter legt
    /// nur seine unmittelbaren Kinder aus — die Seite zeigte dann eine einzige
    /// Spalte.
    static func raster(_ feld: Pixelfeld) -> String {
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

    private static func entschaerft(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func entschaerft(_ text: String) -> String { Self.entschaerft(text) }

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
          --warnung: #b91c1c; --gut: #15803d; --merk: #2563eb;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --grund: #131316; --schrift: #ececee; --matt: #9b9ba3;
            --karte: #1d1d21; --kante: #313138; --aus: #2a2a30; --an: #22c55e;
            --warnung: #f87171; --gut: #4ade80; --merk: #60a5fa;
          }
        }
        * { box-sizing: border-box; }
        body {
          margin: 0; padding: 16px 16px 140px; background: var(--grund); color: var(--schrift);
          font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
        }
        h1 { font-size: 1.3rem; margin: 0 0 .4rem; }
        h2 { font-size: 1.1rem; margin: 2rem 0 .6rem; }
        h3 {
          font-size: .95rem; margin: 0 0 .6rem; color: var(--matt);
          display: flex; flex-wrap: wrap; align-items: center; gap: .5rem;
        }
        p.hinweis { color: var(--matt); margin: 0 0 1rem; max-width: 46rem; }
        section {
          background: var(--karte); border: 1px solid var(--kante); border-radius: 10px;
          border-left-width: 4px; padding: 12px; margin-bottom: 12px;
        }
        /* Wo wirklich zu entscheiden ist, steht am Rand — damit die Zeit
           dorthin geht und nicht in die längst gelaufenen Blöcke. */
        section.entscheidung { border-left-color: var(--merk); }
        section.entschieden { border-left-color: var(--kante); opacity: .72; }
        section.frei { border-left-color: var(--gut); }
        .marke { font-size: .75rem; text-transform: uppercase; letter-spacing: .04em; }
        section.entscheidung .marke { color: var(--merk); }
        section.frei .marke { color: var(--gut); }
        .haken { margin-left: auto; font-size: .8rem; color: var(--schrift); }
        .gruppen { display: flex; flex-wrap: wrap; gap: 14px; }
        .gruppe { min-width: 0; }
        .rasterrahmen { overflow-x: auto; }
        /* Die Spaltenzahl steht am Element selbst: sie ist bei jedem Raster
           eine andere, und sie muss stimmen, sonst bricht das Bild um. */
        .raster { display: grid; gap: 1px; width: max-content; }
        .raster i, .raster b { width: 5px; height: 5px; display: block; }
        .raster i { background: var(--aus); }
        .raster b { background: var(--an); }
        .beschriftung {
          color: var(--matt); font-size: .8rem; margin: .5rem 0 .25rem;
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        }
        .beschriftung.leise { opacity: .7; }
        .rest { color: var(--matt); font-size: .8rem; margin: .5rem 0 0; overflow-wrap: anywhere; }
        ul.gruende { margin: .6rem 0 0; padding-left: 1.2rem; color: var(--warnung); font-size: .85rem; }
        ul.gruende li { margin-bottom: .2rem; overflow-wrap: anywhere; }
        p.frei { margin: .5rem 0 0; color: var(--gut); font-size: .85rem; }
        /* Eine Schrift, die dieser Rechner nicht hat, ist nicht gemessen —
           und das steht dort, wo sonst ihre Bloecke staenden. */
        p.fehlt { margin: .2rem 0 1rem; color: var(--warnung); font-size: .9rem; }
        #ausgabe {
          position: fixed; left: 0; right: 0; bottom: 0; z-index: 2;
          background: var(--karte); border-top: 1px solid var(--kante);
          padding: 10px 16px; max-height: 40vh; overflow: auto;
        }
        #ausgabe pre {
          margin: .3rem 0 0; font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace;
          white-space: pre-wrap; overflow-wrap: anywhere;
        }
        #ausgabe p { margin: 0; font-size: .75rem; color: var(--matt); }
        </style>
        </head>
        <body>
        <h1>Schriftprobe</h1>
        <p class="hinweis">Je Schrift und Größe die Zeichen, die zu <em>demselben</em> Pixelbild
        rastern — gruppenweise, als tatsächliches Raster, ein Kästchen je Pixel, mit einer Spalte
        Abstand wie in der App. Die Frage je Block: <strong>Sind genau diese Zeichen noch
        auseinanderzuhalten?</strong> Höchstens vier Gruppen werden gezeigt; sind es mehr, ist die
        Größe ohnehin gelaufen und der Rest steht als Text.
        <strong>„Nichts fällt zusammen“ heißt nicht „gut“</strong>: Zwei Zeichen können sich um
        ein Pixel unterscheiden und trotzdem unlesbar sein. Das entscheidet nur das Auge — dafür
        die Kreuze.</p>
        \(koerper)<div id="ausgabe"><p>Angekreuzt, als Swift:</p><pre id="swift">—</pre></div>
        <script>
        // Sammelt die Kreuze zu der Zeile, die in `sauberePixelgroessen` gehörte.
        // Der Stepper dort kann nur eine arithmetische Folge: erste, letzte und
        // die Schrittweite aus den ersten beiden Einträgen.
        function auffrischen() {
          const je = {};
          document.querySelectorAll('section input[type=checkbox]:checked').forEach(k => {
            (je[k.dataset.schrift] = je[k.dataset.schrift] || []).push(Number(k.dataset.groesse));
          });
          const namen = Object.keys(je).sort();
          if (!namen.length) { document.getElementById('swift').textContent = '—'; return; }
          const zeilen = namen.map(n => {
            const g = je[n].sort((a, b) => a - b);
            const lueckenlos = g.every((w, i) => i === 0 || w - g[i - 1] === g[1] - g[0]);
            const warnung = lueckenlos ? '' : '   // ungleiche Abstände — der Stepper kann das nicht';
            return '    "' + n + '": [' + g.join(', ') + '],' + warnung;
          });
          document.getElementById('swift').textContent =
            'static let sauberePixelgroessen: [String: [Double]] = [\\n' + zeilen.join('\\n') + '\\n]';
        }
        document.addEventListener('change', e => {
          if (e.target.matches('section input[type=checkbox]')) auffrischen();
        });
        </script>
        </body>
        </html>

        """
    }
}
