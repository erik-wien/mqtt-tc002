import XCTest

/// **Kein `.help(...)` ohne sein Gegenstück.** `.help` zeigt einen Text beim
/// Verweilen mit der Maus — am iPad gibt es kein Verweilen, der Text war dort
/// bisher unsichtbar. Zwei Gegenstücke sind zulässig, beide sichtbar auf
/// beiden Geräten:
///
/// - `.namensichtbarAmIPad()` (`Symbolbeschriftung.swift`): Am Mac bleibt der
///   Knopf beim Symbol, am iPad steht der Name daneben. Für Knöpfe, die
///   **für sich allein** stehen — eine Werkzeugleiste, ein einzelnes Zeichen.
/// - `.contextMenu { … }`: Für Knöpfe, die sich wiederholen (je ein
///   Einzelbild, je ein Bestandseintrag) — ein Langdruck zeigt dort dieselben
///   Handlungen benannt, ohne dass jede Kachel ihre eigene Beschriftung
///   trüge.
///
/// Wo keins von beiden nötig war, weil dieselbe Erklärung schon in der Hilfe
/// steht (`HilfeInhalt.swift`/`HilfeView.swift`, auf beiden Geräten gleich
/// erreichbar) oder ein Regler seinen Wert ohnehin als Text zeigt, ist
/// `.help(...)` ganz verschwunden — dafür gibt es hier nichts mehr zu
/// prüfen. Geprüft wird darum nur, was von `.help(...)` **übrig geblieben**
/// ist: Jede verbliebene Stelle muss eins der beiden Gegenstücke tragen, und
/// zwar genau so oft, wie sie gebraucht wird.
///
/// Gleicher Weg wie `PlattformwegeTests`/`EditorbereichTests`: nachsehen im
/// Quelltext, Kommentare weg, der Übersetzer hat dazu nichts zu sagen.
final class EinblendtextGegenstueckTests: XCTestCase {
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

    /// Der Ausschnitt zwischen zwei Marken — fehlt eine, ist das ein
    /// Fehlschlag und kein übergangener Test.
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

    private func anzahl(_ text: String, _ wort: String) -> Int {
        text.components(separatedBy: wort).count - 1
    }

    // MARK: - Die schlichten Ansichten: jedes `.help` trägt sein eigenes
    // `.namensichtbarAmIPad()`, in derselben Kette.

    /// **Mutationsprobe** (13.09.2026): `.namensichtbarAmIPad()` beim
    /// damaligen „Icon entfernen“-Knopf in `IconAuswahlView.swift` entfernt →
    /// dieser Test fiel für genau diese Datei durch (1 `.help` gegen 0
    /// Gegenstücke); wieder eingesetzt → grün. Der Knopf selbst ist seit
    /// 15.09.2026 weg — redundant neben dem „ohne“-Feld im Blatt, das dieselbe
    /// Wahl trifft —, `IconAuswahlView.swift` hat seither kein `.help(...)`
    /// mehr und steht darum nicht mehr in der Liste unten (siehe Kopf der
    /// Datei: „dafür gibt es hier nichts mehr zu prüfen“).
    ///
    /// `SendenView.swift` steht seit 13.09.2026 **nicht** mehr in dieser
    /// Liste: Sein Inspektor hat fünf Regler mit zustandsabhängigem
    /// Einblendtext, die keinen Symbolknopf zeigen und darum kein
    /// `.namensichtbarAmIPad()` brauchen (siehe die drei Tests weiter unten,
    /// „MARK: - SendenView“). Eine blanke 1:1-Zählung über die ganze Datei
    /// verlangte für die von ihnen fälschlich ein Gegenstück.
    func testSchlichteAnsichtenZeigenJedenEinblendtextAuchAmIPad() throws {
        for datei in ["Sources/TC002Ansichten/Brokerzeichen.swift",
                      "Sources/TC002Ansichten/AnzeigenView.swift"] {
            let text = try quelltext(datei)
            let help = anzahl(text, ".help(")
            let gegenstueck = anzahl(text, ".namensichtbarAmIPad()")
            XCTAssertEqual(help, gegenstueck,
                           "\(datei): \(help) `.help(...)`, aber \(gegenstueck) "
                           + "`.namensichtbarAmIPad()` — mindestens einer steht ohne Gegenstück da "
                           + "und ist damit am iPad unsichtbar")
        }
    }

    // MARK: - SendenView: Regler in einer Form zeigen ihren Zustand als
    // Text — kein `.namensichtbarAmIPad()` nötig (siehe Symbolbeschriftung.
    // swift: „Gilt nur für Knöpfe, die für sich allein stehen … Ein Regler
    // in einer Form zeigt seinen Wert ohnehin als Text“). Die zwei
    // Symbolknöpfe für sich allein — „Formatierung ein-/ausblenden“ und der
    // Papierkorb bei `MeldungLoeschenKnopf` — tragen ihr Gegenstück weiter.

    /// Neun Regler im Inspektor erklären, warum sie gerade nichts bewirken —
    /// das kann weder die Beschriftung noch die Hilfe sagen, die den Zustand
    /// nicht kennt. Zwei Gründe kommen inzwischen zusammen, und beide zählen
    /// hier gleich:
    ///
    /// - **am Zustand**: Schrift, Größe, gewählter Weg oder eine laufende
    ///   Laufschrift geben den Regler gerade nicht her — `.help(...)` mit
    ///   einem Ternär.
    /// - **an der Geräteart**: die Gattung kennt den Regler überhaupt nicht —
    ///   `.gattungssperre(...)`, die `Geraetetyp.begruendung` holt und daraus
    ///   selbst ein `.help(...)` macht.
    ///
    /// Der zweite Weg ist der Grund, warum hier nicht nur `.help(` gezählt
    /// wird: Am 13.09.2026 wurden vier Ternäre durch `.gattungssperre`
    /// ersetzt, und dieser Test schlug an — zu Recht, denn er zählte eine
    /// Form und nicht die Sache.
    ///
    /// **Mutationsprobe** (13.09.2026): `.help(fettHilfe)` beim
    /// „Fett“-Schalter entfernt → 4 gegen erwartete 5, durchgefallen; wieder
    /// eingesetzt → grün. Nach dem Umbau erneut: `.gattungssperre(.abstand,
    /// gattung)` entfernt → 7 gegen erwartete 8, durchgefallen. Ein neunter
    /// kam am 15.09.2026 dazu: „Waagrecht“ wirkt nicht mehr, sobald der Text
    /// als Laufschrift läuft (`waagrechtWirktNicht`) — vorher verschwand dort
    /// nur, geräteartbedingt, das „rechts“-Segment, was leicht mit dieser
    /// Sperre verwechselt wurde.
    func testSendenViewInspektorReglerHabenZustandsabhaengigenEinblendtext() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        let inspektor = ausschnitt(text, von: "private var inspektor: some View", bis: "private var slotZeile")
        XCTAssertEqual(anzahl(inspektor, ".help(") + anzahl(inspektor, ".gattungssperre("), 9,
                       "der Inspektor hat nicht mehr neun Regler, die ihre Sperre begründen — "
                       + "dieser Test prüft die falsche Stelle")
        XCTAssertEqual(anzahl(inspektor, ".namensichtbarAmIPad()"), 0,
                       "ein Regler im Inspektor trägt `.namensichtbarAmIPad()` — das gilt nur für "
                       + "Symbolknöpfe für sich allein, ein Regler in einer Form zeigt seinen Wert "
                       + "ohnehin als Text")
    }

    /// Außerhalb des Inspektors bleiben zwei Symbolknöpfe, und sie tragen
    /// **verschiedene** Gegenstücke — genau nach der Regel oben:
    ///
    /// - „Formatierung ein-/ausblenden“ steht **für sich allein** in der
    ///   Werkzeugleiste → `.namensichtbarAmIPad()`.
    /// - Das ⊗ von `MeldungLoeschenKnopf` **wiederholt sich fünfmal**, einmal
    ///   je Slot → `.contextMenu`. Fünf ausgeschriebene Namen in der
    ///   Blockreihe wären mehr Text als Bild; dieselbe Überlegung wie beim
    ///   Papierkorb im Icon-Raster.
    ///
    /// Bis zum 14.09.2026 war das Löschen **eine** breite rote Schaltfläche
    /// neben der Reihe und trug deshalb `.namensichtbarAmIPad()`.
    ///
    /// **Mutationsprobe** (13.09.2026): `.namensichtbarAmIPad()` bei
    /// `MeldungLoeschenKnopf` entfernt → 2 `.help` gegen 1 Gegenstück,
    /// durchgefallen; wieder eingesetzt → grün. Nach dem Umbau erneut, jetzt
    /// gegen `.contextMenu`.
    func testSendenViewStandaloneKnoepfeZeigenNamenAuchAmIPad() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        let inspektor = ausschnitt(text, von: "private var inspektor: some View", bis: "private var slotZeile")
        let help = anzahl(text, ".help(") - anzahl(inspektor, ".help(")
        let namen = anzahl(text, ".namensichtbarAmIPad()") - anzahl(inspektor, ".namensichtbarAmIPad()")
        let menue = anzahl(text, ".contextMenu") - anzahl(inspektor, ".contextMenu")
        XCTAssertEqual(help, 2,
                       "außerhalb des Inspektors sind es nicht mehr zwei Symbolknöpfe")
        XCTAssertEqual(namen, 1, "der Knopf, der für sich allein steht, zeigt seinen Namen nicht mehr am iPad")
        XCTAssertEqual(menue, 1, "dem sich wiederholenden Knopf fehlt sein Kontextmenü")
        XCTAssertEqual(help, namen + menue,
                       "\(help) `.help(...)` außerhalb des Inspektors, aber nur \(namen + menue) "
                       + "Gegenstücke — einer der beiden Symbolknöpfe ist am iPad namenlos")
    }

    /// Hält die Gesamtzahl fest, damit eine neue, keinem der beiden Tests
    /// oben bekannte Stelle nicht still durchrutscht.
    ///
    /// **Mutationsprobe** (13.09.2026): ein zusätzliches
    /// `.help("Testweise")` am Ende der Datei eingefügt → 8 gegen erwartete
    /// 7, durchgefallen; wieder entfernt → grün.
    func testSendenViewHatKeineUnbeobachteteEinblendtextstelle() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertEqual(anzahl(text, ".help(") + anzahl(text, ".gattungssperre("), 11,
                       "SendenView.swift hat jetzt eine andere Anzahl Einblendtextstellen als die neun "
                       + "Regler im Inspektor plus die zwei Symbolknöpfe für sich allein — eine neue "
                       + "Stelle ist keinem der Tests oben bekannt")
    }

    // MARK: - Die Werkzeugleiste des Editors

    /// Rückgängig, Wiederherstellen, Inspektor ein-/ausblenden — drei
    /// Symbolknöpfe für sich allein, keiner wiederholt sich.
    ///
    /// **Mutationsprobe** (13.09.2026): `.namensichtbarAmIPad()` beim
    /// „Wiederherstellen“-Knopf entfernt → 3 `.help` gegen 2 Gegenstücke,
    /// durchgefallen; wieder eingesetzt → grün.
    func testWerkzeugleisteDesEditorsZeigtNamenAuchAmIPad() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let leiste = ausschnitt(text, von: "private var werkzeugleiste", bis: "private var inspektor: some View")
        let help = anzahl(leiste, ".help(")
        let gegenstueck = anzahl(leiste, ".namensichtbarAmIPad()")
        XCTAssertEqual(help, 3, "die Werkzeugleiste hat nicht mehr drei Symbolknöpfe")
        XCTAssertEqual(help, gegenstueck,
                       "die Werkzeugleiste hat \(help) `.help(...)`, aber nur \(gegenstueck) "
                       + "`.namensichtbarAmIPad()` — ein Knopf zeigt seinen Namen am iPad nicht mehr")
    }

    // MARK: - Die sich wiederholenden Zeilen: das Kontextmenü ist das
    // Gegenstück, nicht je eine eigene Beschriftung an jeder Kachel.

    /// „Verdoppeln“ und „Entfernen“ stehen unter jedem Einzelbild — bei
    /// mehreren Bildern also mehrfach. Das Kontextmenü daneben nennt beide
    /// Handlungen mit Text; das ist das Gegenstück, keine Beschriftung an
    /// jeder einzelnen Kachel.
    ///
    /// **Mutationsprobe** (13.09.2026): `.contextMenu { … }` aus
    /// `einzelbildstreifen` entfernt → durchgefallen; wieder eingesetzt →
    /// grün.
    func testEinzelbildKnoepfeHabenEinKontextmenue() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let streifen = ausschnitt(text, von: "private var einzelbildstreifen", bis: "private func bildVorschau")
        XCTAssertEqual(anzahl(streifen, ".help("), 2,
                       "„Verdoppeln“/„Entfernen“ sind nicht mehr zu zweit — dieser Test prüft die falsche Stelle")
        XCTAssertTrue(streifen.contains(".contextMenu {"),
                      "einzelbildstreifen hat sein Kontextmenü verloren — am iPad steht „Verdoppeln“/"
                      + "„Entfernen“ dann nirgends mehr benannt")
    }

    /// „Umbenennen“ und „Löschen“ stehen an jeder Zeile der Liste
    /// „Vorhandene“ — bei mehreren Einträgen mehrfach. Auch hier ist das
    /// Kontextmenü das Gegenstück.
    ///
    /// **Mutationsprobe** (13.09.2026): `.contextMenu { … }` aus
    /// `bestandszeile` entfernt → durchgefallen; wieder eingesetzt → grün.
    func testBestandszeileKnoepfeHabenEinKontextmenue() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let zeile = ausschnitt(text, von: "private func bestandszeile", bis: "private var sendezeile")
        XCTAssertEqual(anzahl(zeile, ".help("), 2,
                       "„Umbenennen“/„Löschen“ sind nicht mehr zu zweit — dieser Test prüft die falsche Stelle")
        XCTAssertTrue(zeile.contains(".contextMenu {"),
                      "bestandszeile hat sein Kontextmenü verloren — am iPad steht „Umbenennen“/"
                      + "„Löschen“ dann nirgends mehr benannt")
    }

    // MARK: - Zwei weitere Symbolknöpfe für sich allein: Abspielsymbol und
    // das geteilte Verschiebekreuz.

    /// **Die eine Ausnahme von der Gegenstück-Regel.** Sonst gilt: Ein
    /// Symbolknopf, der allein steht, zeigt seinen Namen am iPad sichtbar an
    /// (`namensichtbarAmIPad()`), weil es dort kein Verweilen gibt. Das
    /// runde Play/Pause unter der Leinwand trägt ihn ausdrücklich **nicht**:
    /// Es ist das eine Zeichen, das überall dasselbe bedeutet, und ein Wort
    /// daneben wäre am Bild nur Lärm — so hält es jede Abspielfläche des
    /// Systems. Die Sprachausgabe bekommt den Namen trotzdem, über
    /// `.accessibilityLabel` (siehe `EditorbereichTests`).
    ///
    /// Der Test hält die Ausnahme fest, statt sie zu verschweigen: Wer
    /// `namensichtbarAmIPad()` hier wieder einsetzt, soll die Entscheidung
    /// noch einmal treffen und nicht bloß einer Regel folgen.
    func testAbspielsymbolTraegtSeinenNamenNurFuerDieSprachausgabe() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let knopf = ausschnitt(text, von: "private var abspielknopf", bis: "private var sichernAbschnitte")
        XCTAssertEqual(anzahl(knopf, ".help("), 1,
                       "das Abspielsymbol hat nicht mehr genau einen Einblendtext")
        XCTAssertEqual(anzahl(knopf, ".accessibilityLabel("), 1,
                       "das Abspielsymbol ist für die Sprachausgabe stumm")
        XCTAssertEqual(anzahl(knopf, ".namensichtbarAmIPad()"), 0,
                       "das runde Transportzeichen trägt wieder einen sichtbaren Namen — gewollt?")
    }

    /// Die vier Pfeile des Verschiebekreuzes teilen sich eine Funktion
    /// (`pfeil`) — Einblendtext und Gegenstück stehen deshalb nur einmal im
    /// Quelltext, nicht viermal.
    ///
    /// **Mutationsprobe** (13.09.2026): `.namensichtbarAmIPad()` aus `pfeil`
    /// entfernt → 1 `.help` gegen 0 Gegenstücke, durchgefallen; wieder
    /// eingesetzt → grün.
    func testVerschiebekreuzZeigtNamenAuchAmIPad() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let funktion = ausschnitt(text, von: "private func pfeil(", bis: "\n    }")
        XCTAssertEqual(anzahl(funktion, ".help("), 1,
                       "die geteilte Pfeilfunktion hat nicht mehr genau einen Einblendtext")
        XCTAssertEqual(anzahl(funktion, ".namensichtbarAmIPad()"), 1,
                       "die geteilte Pfeilfunktion zeigt ihren Namen am iPad nicht mehr sichtbar an")
    }

    /// Das Nummernfeld erklärt, was die aktuelle Größe gerade aus ihm macht
    /// — LaMetric-Nummer oder Ulanzi-Werknummer —, ein zustandsabhängiger
    /// Text, den weder die Beschriftung (überall nur „Nummer") noch die
    /// Hilfe sagen kann. Kein Symbolknopf, darum kein
    /// `.namensichtbarAmIPad()` nötig — das Textfeld zeigt seinen Wert
    /// ohnehin als Text.
    ///
    /// **Mutationsprobe** (13.09.2026): `.namensichtbarAmIPad()`
    /// versuchsweise beim Nummernfeld ergänzt → 1 gegen erwartete 0,
    /// durchgefallen; wieder entfernt → grün.
    func testNummernfeldHatZustandsabhaengigenEinblendtextOhneGegenstueck() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let feld = ausschnitt(text, von: "TextField(\"Nummer\", text: $nummer)", bis: "\n                }")
        XCTAssertEqual(anzahl(feld, ".help("), 1,
                       "das Nummernfeld hat seinen zustandsabhängigen Einblendtext verloren")
        XCTAssertEqual(anzahl(feld, ".namensichtbarAmIPad()"), 0,
                       "das Nummernfeld trägt `.namensichtbarAmIPad()` — das gilt nur für Symbolknöpfe "
                       + "für sich allein, ein Textfeld zeigt seinen Wert ohnehin als Text")
    }

    // MARK: - Vollständigkeit: keine unbeobachtete Stelle

    /// Die sechs vorigen Tests decken zusammen jedes `.help(...)`, das in
    /// `EditorBereichView.swift` noch steht. Diese Summe hält das fest,
    /// damit ein neues `.help(...)` anderswo in der Datei nicht still
    /// durchrutscht, ohne dass einer der Tests oben es sieht.
    ///
    /// **Mutationsprobe** (13.09.2026): ein zusätzliches
    /// `.help("Testweise")` am Ende von `bestandszeile` eingefügt → 11 gegen
    /// erwartete 10, durchgefallen; wieder entfernt → grün. Kurz darauf hat
    /// dieser Test einen echten Zuwachs gefangen: den Einblendtext am
    /// Sendeknopf, der begründet, warum eine AWTRIX kein gemaltes Bild nimmt.
    /// Der Knopf trägt eine sichtbare Beschriftung („Senden“) und braucht
    /// darum kein `.namensichtbarAmIPad()`; unsichtbar bleibt am iPad allein
    /// der **Grund** seiner Sperre — dieselbe offene Stelle wie bei den
    /// übrigen zustandsabhängigen Erklärungen.
    func testEditorBereichViewHatKeineUnbeobachteteEinblendtextstelle() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertEqual(anzahl(text, ".help("), 12,
                       "EditorBereichView.swift hat jetzt eine andere Anzahl `.help(...)`-Stellen als "
                       + "die Werkzeugleiste (3), die beiden Kontextmenü-Zeilen (2 + 2), das "
                       + "Abspielsymbol (1), das Verschiebekreuz (1), das Nummernfeld (1), der "
                       + "Sendeknopf (1) und das Nachladen-Zeichen der LaMetric-Zeile (1) — eine neue "
                       + "Stelle ist keinem der Tests oben bekannt")
    }
}
