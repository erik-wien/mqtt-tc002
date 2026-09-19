import XCTest

/// Unter der Vorschau steht kein Kleingedrucktes mehr.
///
/// Dort standen zwei Zeilen: die Erklaerung, dass eine AWTRIX NG den Text
/// selbst setzt, und die Groesse der naechsten Nutzlast. Beides ist richtig,
/// beides stand dauerhaft unter jedem Bild und las sich wie ein Beipackzettel
/// — Apples eigene Apps erklaeren sich nicht unter jedem Element.
///
/// Jetzt: Die Erklaerung haengt an einem Zeichen neben der Punktreihe
/// (`Hilfezeichen`, ein Text auf beiden Wegen — Einblendtext am Zeiger, Blase
/// am Finger). Die Nutzlast steht am Sendezeichen im Eingabefeld, wo man
/// drueckt. Sichtbar bleibt allein die Warnung ueber der Schwelle: Die ist
/// ein Befund, kein Kleingedrucktes.
///
/// Gleicher Weg wie `NutzlastzeileTests`: nachsehen im Quelltext, Kommentare
/// weg. Der Uebersetzer sagt zu einem Satz unter einem Bild nichts.
final class VorschauhinweisTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    /// Der Satz steht genau einmal im Quelltext, und zwar im Kern: Zwei
    /// Abschriften waeren zwei Uebersetzungsschluessel, die auseinanderlaufen.
    func testDerNaeherungssatzStehtGenauEinmalUndZwarImKern() throws {
        let anfang = "Nur eine Näherung — die Uhr setzt diesen Text selbst"
        var stellen: [String] = []
        for ordner in ["Sources/TC002Core", "Sources/TC002Modell", "Sources/TC002Ansichten",
                       "Sources/TC002App", "Sources/TC002iOS"] {
            for pfad in swiftDateien(unter: ordner) where try quelltext(pfad).contains(anfang) {
                stellen.append(pfad)
            }
        }
        XCTAssertEqual(stellen, ["Sources/TC002Core/Geraetetyp.swift"],
                       "Der Näherungssatz steht nicht mehr genau einmal im Kern "
                       + "(`Geraetetyp.vorschauhinweis`), sondern in: \(stellen)")
    }

    /// Beide Oberflaechen zeigen ihn, und beide ueber dasselbe Zeichen.
    func testBeideOberflaechenHaengenIhnAnEinZeichen() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift",
                      "Sources/TC002iOS/SendeniOS.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("gattung.vorschauhinweis"),
                          "\(datei) fragt nicht mehr, ob es etwas über die Vorschau zu sagen gibt")
            XCTAssertTrue(text.contains("Hilfezeichen(hinweis)"),
                          "\(datei) zeigt den Hinweis nicht mehr über `Hilfezeichen` — dann ist er "
                          + "am Finger entweder unsichtbar oder wieder ein Satz unter dem Bild")
        }
    }

    /// Sichtbar bleibt nur der Befund.
    func testUnterDerVorschauStehtNurNochDieWarnung() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(text.contains("nutzlastBytes > Nutzlastzeile.heikelAb"),
                      "die Nutzlastzeile steht wieder dauerhaft unter der Vorschau statt erst "
                      + "über der Schwelle")
        XCTAssertTrue(text.contains("Nutzlastzeile("),
                      "die Warnung über eine auffällig große Nutzlast ist ganz verschwunden — "
                      + "sie ist ein Befund und muss sichtbar bleiben")
    }

    /// Und der Stand steht am Sendezeichen, nicht nirgends.
    func testDieNutzlastStehtAmSendezeichen() throws {
        let sendenView = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(sendenView.contains("auskunft: nutzlastauskunft"),
                      "das Eingabefeld bekommt nicht mehr gesagt, was hinausgeht")
        let feld = try quelltext("Sources/TC002Ansichten/Eingabefeld.swift")
        XCTAssertTrue(feld.contains("auskunft ?? lok(\"Senden\")"),
                      "das ⏎ zeigt die Auskunft nicht mehr — dann steht die Nutzlastgröße nirgends")
        // Die Sprachausgabe bekommt weiter das Wort, nicht die Nutzlast: Sie
        // sagt, was der Knopf tut. Seit der Knopf eine Sekunde lang gelungen
        // aussieht, sind es zwei Wörter — beide sagen eine Handlung, keines
        // eine Größe.
        XCTAssertTrue(feld.contains("lok(\"Hinausgeschickt\") : lok(\"Senden\")"),
                      "die Sprachausgabe sagt nicht mehr, was der Knopf tut")
        XCTAssertFalse(feld.contains("accessibilityLabel(Text(auskunft"),
                       "die Sprachausgabe liest die Nutzlastgröße vor statt der Handlung")
    }
}
