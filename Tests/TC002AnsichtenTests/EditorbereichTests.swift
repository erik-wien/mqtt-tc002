import XCTest
@testable import TC002Ansichten

/// Aus „Bilder" und „Icons" ist ein Bereich geworden: „Editor".
///
/// Zwei Hälften, und beide werden gebraucht: die Seitenleiste selbst und die
/// Zusicherung, dass es wirklich **eine** Ansicht mit Unterschieden ist und
/// nicht wieder zwei mit Ähnlichkeiten. Die zweite prüft der Übersetzer nicht —
/// eine zweite, fast gleiche Datei übersetzt anstandslos. Deshalb derselbe Weg
/// wie in `PlattformwegeTests`: nachsehen im Quelltext.
final class EditorbereichTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Quelltext ohne Kommentare — sonst zählte jeder Satz mit, der etwas
    /// bloß erwähnt, und diese Datei erwähnt ihre Vorgänger.
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

    func testDieSeitenleisteHatVierEintraegeUndDarunterDenEditor() {
        XCTAssertEqual(SchreibtischView.Bereich.oben, [.senden, .editor])
        XCTAssertEqual(SchreibtischView.Bereich.unten, [.verlauf, .einstellungen])
        XCTAssertEqual(SchreibtischView.Bereich.allCases.count, 4,
                       "„Bilder“ und „Icons“ sind zu einem Eintrag geworden")
    }

    /// Der Eintrag heißt „Editor" und trägt die Palette — beides ausdrücklich
    /// so verlangt, und beides ließe sich unbemerkt ändern.
    func testDerEintragHeisstEditorUndTraegtDiePalette() {
        XCTAssertEqual(SchreibtischView.Bereich.editor.rawValue, "Editor")
        XCTAssertEqual(SchreibtischView.Bereich.editor.symbol, "paintpalette")
    }

    /// Es gibt genau **einen** Editor. In diesem Projekt ist schon einmal ein
    /// Fehler daraus entstanden, dass es dieselbe Rechnung dreimal gab.
    func testEsGibtNurEineEditoransicht() {
        let fm = FileManager.default
        for weg in ["Sources/TC002Ansichten/IconEditorView.swift",
                    "Sources/TC002Ansichten/BilderBereichView.swift",
                    "Sources/TC002Ansichten/PixelEditor.swift"] {
            XCTAssertFalse(fm.fileExists(atPath: Self.wurzel.appendingPathComponent(weg).path),
                           "\(weg) ist wieder da — es soll eine Ansicht mit Unterschieden sein, nicht zwei mit Ähnlichkeiten")
        }
        XCTAssertTrue(fm.fileExists(atPath: Self.wurzel
            .appendingPathComponent("Sources/TC002Ansichten/EditorBereichView.swift").path))
    }

    /// Die Unterschiede zwischen den drei Größen werden **abgeleitet**
    /// (`Leinwandgroesse`), nicht als Fallunterscheidung in die Ansicht
    /// geschrieben. Genau darum geht es bei diesem Umbau.
    func testDieUnterschiedeWerdenAbgeleitetUndNichtAufgezaehlt() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(text.contains("groesse.sendbar"),
                      "die Sendezeile hängt nicht mehr an der abgeleiteten Eigenschaft")
        XCTAssertTrue(text.contains("groesse.mitNummer"),
                      "das Nummernfeld hängt nicht mehr an der abgeleiteten Eigenschaft")
        XCTAssertTrue(text.contains("groesse.iconEinfuegbar"),
                      "„Icon einfügen“ hängt nicht mehr an der abgeleiteten Eigenschaft")
        for sonderfall in ["groesse == .icon8", "groesse == .icon16", "groesse == .anzeige",
                           "case .icon8:", "case .anzeige:"] {
            XCTAssertFalse(text.contains(sonderfall),
                           "„\(sonderfall)“ ist ein Sonderfall in der Ansicht — er gehört nach Leinwandgroesse")
        }
    }

    /// Die Hilfe zieht mit: Zu jedem Bereich der Seitenleiste muss es einen
    /// gleichnamigen Abschnitt geben. Beim Zusammenlegen von „Bilder" und
    /// „Icons" wären sonst zwei Abschnitte über etwas stehen geblieben, das es
    /// nicht mehr gibt — und die Übersetzungsprüfung merkt davon nichts, sie
    /// sieht nur, ob ein Eintrag da ist.
    func testZuJedemBereichGibtEsEinenHilfeabschnitt() throws {
        let text = try quelltext("Sources/TC002Ansichten/HilfeView.swift")
        for bereich in SchreibtischView.Bereich.allCases {
            XCTAssertTrue(text.contains("= \"\(bereich.rawValue)\""),
                          "die Hilfe hat keinen Abschnitt „\(bereich.rawValue)“")
        }
        XCTAssertFalse(text.contains("case bilder"), "der Abschnitt „Bilder“ steht noch da")
        XCTAssertFalse(text.contains("case icons"), "der Abschnitt „Icons“ steht noch da")
    }

    /// Der Dateiwaehler. Am iPad laeuft die App in der Sandbox, und eine URL
    /// von dort gilt nur zwischen `startAccessingSecurityScopedResource` und
    /// `stop…`; am Mac gilt die Einschränkung nicht — deshalb **kann** kein
    /// Test hier die Wirkung zeigen, und deshalb hält dieser fest, dass der
    /// Weg der richtige bleibt. Genau so ist der Fehler entstanden: Die App
    /// merkte sich die URL und las erst beim Bestätigen des Blattes.
    func testDerDateiwaehlerLiestSofortUndMeldetJedenFehlschlag() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(text.contains("url.startAccessingSecurityScopedResource()"),
                      "ohne Zugriffsanforderung schlägt am iPad jedes Lesen fehl")
        XCTAssertTrue(text.contains("url.stopAccessingSecurityScopedResource()"),
                      "ein Zugriff, der nicht abgemeldet wird, bleibt offen")
        XCTAssertTrue(text.contains("try Data(contentsOf: url)"),
                      "die Datei wird nicht gelesen, solange der Zugriff offen ist")
        XCTAssertTrue(text.contains("importDaten"),
                      "gemerkt gehören die Bytes, nicht die URL")
        XCTAssertFalse(text.contains("importDatei"),
                       "die URL wird wieder aufbewahrt und später gelesen — dann ist der Zugriff zu")
        XCTAssertTrue(text.contains("case .failure(let fehler):"),
                      "ein fehlgeschlagener Dateiwähler tut wieder stillschweigend nichts")
    }

    /// Der Ausschnitt zwischen zwei Marken — ohne Kommentare, wie oben. Fehlt
    /// eine der Marken, ist das ein Fehlschlag und kein übergangener Test:
    /// Sonst ginge dieser Test still durch, sobald jemand die Stelle umbaut.
    private func ausschnitt(_ text: String, von: String, bis: String) -> String {
        guard let anfang = text.range(of: von) else {
            XCTFail("„\(von)“ gibt es im Quelltext nicht mehr")
            return ""
        }
        let rest = text[anfang.lowerBound...]
        guard let ende = rest.range(of: bis) else {
            XCTFail("„\(bis)“ steht nicht mehr hinter „\(von)“")
            return ""
        }
        return String(rest[rest.startIndex..<ende.lowerBound])
    }

    /// Zählt Aufrufe von `name()` — die Deklaration (`func name()`) zählt nicht
    /// mit, und `nameAnfragen()` ist ein anderer Name und wird nicht getroffen.
    private func aufrufe(_ name: String, in text: String) -> Int {
        var anzahl = 0
        var rest = Substring(text)
        while let treffer = rest.range(of: "\(name)()") {
            let vorher = rest[rest.startIndex..<treffer.lowerBound]
            let vorzeichen = vorher.last
            if !vorher.hasSuffix("func "), !(vorzeichen?.isLetter ?? false) {
                anzahl += 1
            }
            rest = rest[treffer.upperBound...]
        }
        return anzahl
    }

    /// **A1.** „Sichern" und „Neu" stehen in **einer** Zeile der `Form`, und
    /// eine Formularzeile ist selbst das Bedienelement: Ein Knopf mit dem
    /// vorgegebenen Stil bekommt darin die Trefferfläche der ganzen Zeile.
    /// Zwei davon teilen sich dieselbe Fläche — der Druck auf „Sichern"
    /// landete bei „Neu", und weil die Zeile auch bei gesperrtem „Sichern"
    /// antippbar bleibt, traf es dann zwangsläufig den zerstörenden Knopf.
    ///
    /// Geprüft wird der Quelltext, nicht die Wirkung: Ein Übersetzer hat zur
    /// Trefferfläche nichts zu sagen, und ohne Gerät sieht das niemand.
    func testSichernUndNeuTeilenSichKeineTrefferflaeche() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let zeile = ausschnitt(text, von: "Button(\"Sichern\")", bis: "} header:")
        XCTAssertTrue(zeile.contains("Button(\"Neu\")"),
                      "„Neu“ steht nicht mehr neben „Sichern“ — dann prüft dieser Test die falsche Zeile")
        // `knopfHaupthandlung` und `knopfBefehl` setzen beide ausdrücklich
        // einen Knopfstil (`Knopfstil.swift`) — und genau das, nicht das
        // Aussehen, nimmt den beiden die gemeinsame Trefferfläche.
        for stil in [".knopfHaupthandlung()", ".knopfBefehl()"] {
            XCTAssertTrue(zeile.contains(stil),
                          "„Sichern“ und „Neu“ tragen nicht mehr je einen eigenen Knopfstil (\(stil) fehlt) — "
                          + "ohne ihn bekommen beide die Trefferfläche der ganzen Formularzeile: „Sichern“ löst „Neu“ aus")
        }
    }

    /// **A1, die zweite Hälfte.** „Neu" ist zerstörend — es leert Leinwand,
    /// Einzelbilder, Name und Nummer und wirft den Verlauf weg. Es darf
    /// deshalb **nur** über die Rückfrage erreichbar sein: der Knopf ruft
    /// `neuAnfragen()`, und `neu()` selbst steht genau an zwei Stellen — im
    /// Zweig „da ist nichts zu verlieren" und hinter der Bestätigung.
    func testNeuIstNurUeberDieRueckfrageErreichbar() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let zeile = ausschnitt(text, von: "Button(\"Sichern\")", bis: "} header:")
        XCTAssertTrue(zeile.contains("Button(\"Neu\") { neuAnfragen() }"),
                      "der Knopf „Neu“ räumt wieder unmittelbar auf, statt vorher zu fragen")

        XCTAssertTrue(text.contains("alert(\"Neu anfangen?\", isPresented: $zeigeNeuBestaetigung)"),
                      "die Rückfrage vor dem Aufräumen gibt es nicht mehr")
        XCTAssertTrue(text.contains("Button(\"Neu anfangen\", role: .destructive) { neu() }"),
                      "die Rückfrage führt nicht mehr auf „Neu“ — oder sie ist nicht mehr als zerstörend gekennzeichnet")
        XCTAssertTrue(text.contains("if istLeer { neu() } else { zeigeNeuBestaetigung = true }"),
                      "ohne diesen Zweig fragt „Neu“ entweder immer oder nie")

        let anzahl = aufrufe("neu", in: text)
        XCTAssertEqual(anzahl, 2,
                       "`neu()` wird an \(anzahl) Stellen gerufen — es darf nur die Rückfrage und der Fall „da ist nichts zu verlieren“ sein")
    }

    /// **A3.** Ein Satz Bedienelemente in der Leiste, nicht zwei übereinander.
    ///
    /// Am Mac gehört die Werkzeugleiste dem **Fenster** (mindestens 1140 Punkte,
    /// Titel woanders, Überlaufmenü) — dort passte alles. Am iPad gehört sie der
    /// Navigationsleiste der **Detailspalte**: Fenster minus Seitenleiste minus
    /// Inspektor, mit Seitenleistenknopf links und Titel in der Mitte. Sie läuft
    /// nicht über, sie schiebt übereinander; die Segmentleiste war das breiteste
    /// Stück darin und hat den Seitenleistenknopf verdeckt, „Rückgängig“ fiel
    /// ganz heraus. Die drei Modi sitzen deshalb am Kopf des Inspektors.
    ///
    /// Der Übersetzer hat dazu nichts zu sagen — beide Fassungen übersetzen.
    func testDieModuswahlStehtImInspektorUndNichtInDerWerkzeugleiste() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let leiste = ausschnitt(text, von: "private var werkzeugleiste", bis: "private var inspektor")

        XCTAssertFalse(leiste.contains("Picker("),
                       "die Modusleiste liegt wieder in der Werkzeugleiste — am iPad verdeckt sie dort den Seitenleistenknopf")
        for knopf in ["rueckgaengig()", "wiederherstellen()", "zeigeInspektor.toggle()"] {
            XCTAssertTrue(leiste.contains(knopf),
                          "„\(knopf)“ steht nicht mehr in der Werkzeugleiste — es muss auf beiden Geräten erreichbar bleiben")
        }

        XCTAssertTrue(ausschnitt(text, von: "private var inspektor", bis: "private var modusWahl")
                        .contains("modusWahl"),
                      "der Inspektor trägt die Moduswahl nicht mehr an seinem Kopf — dann gibt es keinen Weg mehr zu den drei Modi")

        let wahl = ausschnitt(text, von: "private var modusWahl", bis: "private var malenAbschnitte")
        XCTAssertTrue(wahl.contains(".pickerStyle(.segmented)"),
                      "die Moduswahl ist keine Segmentwahl mehr")
        for modus in ["Malen", "Animation", "Bestand"] {
            XCTAssertTrue(wahl.contains("Text(\"\(modus)\").tag("),
                          "„\(modus)“ fehlt in der Segmentwahl — oder das Kennzeichen sitzt nicht mehr ganz außen")
        }
    }
}
