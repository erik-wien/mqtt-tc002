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

        XCTAssertTrue(text.contains("Button(\"Neu anfangen\", role: .destructive) { neu() }"),
                      "die Rückfrage führt nicht mehr auf „Neu“ — oder sie ist nicht mehr als zerstörend gekennzeichnet")
        XCTAssertTrue(text.contains("if ungesichert { rueckfrage = .neu } else { neu() }"),
                      "ohne diesen Zweig fragt „Neu“ entweder immer oder nie")

        let anzahl = aufrufe("neu", in: text)
        XCTAssertEqual(anzahl, 2,
                       "`neu()` wird an \(anzahl) Stellen gerufen — es darf nur die Rückfrage und der Fall „da ist nichts zu verlieren“ sein")
    }

    /// **C1.** Der Import richtet sich nach der **Datei**, nicht nach dem
    /// Editor. Die Größe entscheidet, in welchen Bestand sie geht und ob nach
    /// einer Nummer gefragt wird — und sie wird geprüft, **bevor** das Blatt
    /// aufgeht: Wer eine 32×32 gewählt hat, soll das nicht erst erfahren,
    /// nachdem er einen Namen eingetippt hat.
    ///
    /// Der Rückfall in die alte Fassung ist der stumme: `groesse.mitNummer`
    /// statt `importMitNummer` übersetzt anstandslos und sieht am Mac gleich
    /// aus — solange der Editor zufällig auf 8×8 steht.
    func testDerImportRichtetSichNachDerDateiUndNichtNachDemEditor() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(text.contains("Editorbestand.zielgroesse(fuer: daten)"),
                      "die Größe der Datei wird nicht mehr geprüft — dann rechnet wieder jemand herunter")
        XCTAssertFalse(text.contains("importGroesse"),
                       "die rohen Maße werden wieder aufbewahrt, statt der Größe, in der aufgenommen wird")

        let blatt = ausschnitt(text, von: "private var importBlatt", bis: "private var importMitNummer")
        XCTAssertTrue(blatt.contains("if importMitNummer {"),
                      "das Blatt fragt wieder nach der Größe des Editors statt nach der der Datei")

        let abgeleitet = ausschnitt(text, von: "private var importMitNummer", bis: "private var importSchluessel")
        XCTAssertTrue(abgeleitet.contains("importZiel"),
                      "„hat eine Nummer“ hängt nicht mehr an der Datei, sondern wieder an der Leinwand")

        let einlesen = ausschnitt(text, von: "private func einlesen()", bis: "private func grundschatz")
        XCTAssertFalse(einlesen.contains("groesse: groesse"),
                       "die eingestellte Leinwandgröße wird wieder an den Bestand durchgereicht")
    }

    /// **C2.** „Icon einfügen" ist der **eine** Weg, auf dem zwischen den
    /// Größen gerechnet wird — und die Rechnung steht im Kern
    /// (`Leinwand.iconEinsetzen`), nicht als Schleife in der Ansicht. Die
    /// Ansicht hatte bis zum 13.09.2026 eine eigene, die fest von 8×8 auf
    /// Zeile 4 schrieb; ein zweiter Weg daneben wäre nach C1 genau der Fehler,
    /// den C2 abstellt.
    func testIconEinfuegenRechnetImKernUndBietetAlleKleinerenAn() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        let einfuegen = ausschnitt(text, von: "private func iconEinfuegen", bis: "private func abspielen")
        XCTAssertTrue(einfuegen.contains("iconEinsetzen(quelle.bild, groesse: eintrag.groesse)"),
                      "die Ansicht rechnet wieder selbst, statt den Kern zu fragen")
        XCTAssertFalse(einfuegen.contains("for y in 0..<8"),
                       "die feste 8×8-Schleife ist zurück — dann gibt es das Verdoppeln nicht")
        XCTAssertFalse(einfuegen.contains("y: 4 + y"),
                       "die Zeile 4 steht wieder fest in der Ansicht statt in `Leinwandgroesse.einsatz`")

        let abschnitt = ausschnitt(text, von: "if groesse.iconEinfuegbar {", bis: "@ViewBuilder")
        XCTAssertTrue(abschnitt.contains("ForEach(groesse.aufnehmbar)"),
                      "das Menü bietet nicht mehr alle einsetzbaren Größen an, sondern wieder nur 8×8")
        XCTAssertFalse(abschnitt.contains("iconsammlung"),
                       "das Menü liest wieder am Bestand vorbei unmittelbar in der 8×8-Sammlung")
    }

    /// **A4.** Das Blatt hinter „Öffnen…" sagt, was dort einzutragen ist —
    /// beschriftete Zeilen statt zweier nackter Felder —, es belegt Nummer und
    /// Titel aus dem Dateinamen vor, und es warnt **vor** dem Sichern, wenn
    /// der Platz schon belegt ist.
    ///
    /// Der Rückfall ist auch hier still: Der ganze Dateiname in beiden Feldern
    /// übersetzt, baut und sieht am Mac ordentlich aus — nur steht die Nummer
    /// dann zweimal falsch da.
    func testDasImportblattBelegtVorUndWarntVorDemErsetzen() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        XCTAssertTrue(text.contains("Editorbestand.vorschlag("),
                      "der Dateiname wird nicht mehr in Nummer und Titel getrennt")
        XCTAssertFalse(text.contains("importNummer = basis"),
                       "der ganze Dateiname steht wieder in beiden Feldern")

        let blatt = ausschnitt(text, von: "private var importBlatt", bis: "private var importMitNummer")
        for zeile in ["LabeledContent(\"LaMetric-Nummer\")", "LabeledContent(\"Name\")"] {
            XCTAssertTrue(blatt.contains(zeile),
                          "\(zeile) fehlt — dann steht wieder nicht da, was einzutragen ist")
        }
        XCTAssertTrue(blatt.contains("if let vorhanden = importBelegt {"),
                      "das Blatt warnt nicht mehr vor einem belegten Platz — "
                      + "dann merkt man das Ersetzen erst, wenn es geschehen ist")
        XCTAssertTrue(blatt.contains("lok(\"Ersetzen\")"),
                      "der Knopf heißt nicht mehr „Ersetzen“, wo er ersetzt")

        // Eine Ansicht, nicht zwei: Was bei 16×16 und 16×52 fehlt, wird
        // abgeleitet — ein zweites Blatt fiele beim Übersetzen nicht auf.
        XCTAssertTrue(blatt.contains("if importMitNummer {"),
                      "die Nummer hängt nicht mehr an einer abgeleiteten Eigenschaft")

        let belegt = ausschnitt(text, von: "private var importBelegt", bis: "private var importSchluessel")
        XCTAssertTrue(belegt.contains("Editorbestand.belegt(in: vorhandene"),
                      "die Belegung wird wieder eigens gerechnet oder bei jedem "
                      + "Tastendruck im Dateisystem gesucht")
    }

    /// **B3.** „Abspielen" ist kein eigener Knopf mehr, sondern ein Symbol
    /// **unmittelbar rechts neben dem Sekundenwert** — so verlangt. Es
    /// schaltet um und muss deshalb beide Zustände zeigen; und weil ein
    /// Symbol für sich stumm ist, braucht es in **beiden** eine Beschriftung
    /// für die Sprachausgabe.
    ///
    /// Nichts davon sieht ein Übersetzer, ein Bau oder ein Blick auf den Mac:
    /// Ein Symbol ohne Beschriftung baut und zeichnet anstandslos.
    func testDasAbspielsymbolStehtAnDerLeinwandUndNenntBeideZustaende() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        // **Am Bild, nicht im Reiter** (14.09.2026). Bis dahin sass das
        // Symbol neben dem Sekundenwert im Reiter „Animation"; wer ein
        // bewegtes Icon aus dem Bestand oeffnete, kam nur ueber einen Umweg
        // daran. Es steht jetzt unter der Leinwand — und nur dann, wenn es
        // ueberhaupt etwas abzuspielen gibt.
        let fuss = ausschnitt(text, von: "private var fusszeile", bis: "private var fusstexte")
        XCTAssertTrue(fuss.contains("abspielknopf"),
                      "das Wiedergabesymbol steht nicht mehr unter der Leinwand")
        XCTAssertTrue(fuss.contains("leinwand.bilder.count > 1"),
                      "das Symbol steht auch bei einem einzigen Einzelbild da — dann ist es ein Knopf "
                      + "ohne Wirkung statt einer Auskunft darueber, dass sich hier etwas bewegt")

        let sekunden = ausschnitt(text, von: "LabeledContent(\"Verzögerung\")", bis: "\n            }")
        XCTAssertTrue(sekunden.contains("Text(\"s\")"),
                      "die Sekundenzeile sieht anders aus — dann prüft dieser Test die falsche Stelle")
        XCTAssertFalse(sekunden.contains("abspielknopf"),
                       "das Symbol steht wieder **zusätzlich** neben dem Sekundenwert — zwei Orte für "
                       + "dieselbe Handlung")

        let knopf = ausschnitt(text, von: "private var abspielknopf", bis: "private var sichernAbschnitte")
        // Play und **Pause**, nicht Play und Stopp: `stoppeAbspielen` bricht
        // nur die Schleife ab, das gezeigte Einzelbild bleibt stehen. Ein
        // `stop.fill` verspraeche einen Ruecksprung an den Anfang.
        for zustand in ["\"play.circle\"", "\"pause.circle\""] {
            XCTAssertTrue(knopf.contains(zustand),
                          "\(zustand) fehlt — ein Knopf, der umschaltet, muss beides zeigen")
        }
        XCTAssertFalse(knopf.contains("stop.fill"),
                       "das Symbol verspricht wieder einen Stopp, hält aber nur an")
        XCTAssertTrue(knopf.contains(".accessibilityLabel("),
                      "das Symbol trägt keine Beschriftung mehr — für die Sprachausgabe ist es dann stumm")
        // Zweimal, nicht dreimal: Der Knopf traegt sein Symbol ohne sichtbaren
        // Namen (siehe `EinblendtextGegenstueckTests`), es bleiben
        // Einblendtext und Sprachausgabe.
        for wort in ["lok(\"Pause\")", "lok(\"Abspielen\")"] {
            XCTAssertEqual(knopf.components(separatedBy: wort).count - 1, 2,
                           "\(wort) steht nicht in Einblendtext **und** Sprachausgabe — "
                           + "oder ein Zweig ist ohne `lok` geschrieben und übersetzt damit nicht")
        }
        XCTAssertTrue(knopf.contains(".help("),
                      "das Symbol hat wieder keinen Einblendtext — am Mac ist es damit unbenannt")
    }

    /// **Ein geladenes Bild will man auch sehen.** Aus einer Datei wie von
    /// LaMetric: Beide Wege enden bei `geladenUebernehmen`, und der entscheidet
    /// an **einer** Stelle, ob gefragt wird. Bis zum 14.09.2026 wanderte eine
    /// eingelesene Datei nur in den Bestand — auf der Leinwand geschah nichts,
    /// aus Sorge um Ungesichertes. Der Auftraggeber hat das abgelehnt.
    ///
    /// Der Rückfall ist still: Ein Weg, der den Eintrag nur ablegt, übersetzt
    /// und baut anstandslos; dass die Leinwand nicht mitgeht, sieht man nur am
    /// Gerät.
    ///
    /// Mutation: in `nachladen` `geladenUebernehmen(eintrag)` durch eine
    /// Meldung ersetzen — dann liegt das geholte Icon wieder nur im Bestand.
    func testEinGeladenesBildKommtAufDieLeinwand() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        let nachladen = ausschnitt(text, von: "private func nachladen()", bis: "private func dateiUebernehmen")
        XCTAssertTrue(nachladen.contains("geladenUebernehmen(eintrag)"),
                      "ein von LaMetric geholtes Icon kommt wieder nur in den Bestand")
        XCTAssertTrue(nachladen.contains("Editorbestand.eintrag(fuer: icon)"),
                      "die Größe des geholten Icons wird wieder angenommen statt aus ihm gelesen")

        XCTAssertTrue(text.contains("geladenUebernehmen(eintrag)\n    }"),
                      "der Weg aus dem Blatt führt nicht mehr auf die Leinwand")

        let uebernehmen = ausschnitt(text, von: "private func geladenUebernehmen", bis: "private func aufDieLeinwand")
        XCTAssertTrue(uebernehmen.contains("if ungesichert { rueckfrage = .geladen(eintrag) } else { aufDieLeinwand(eintrag) }"),
                      "geladen wird wieder ohne Rückfrage ersetzt — oder gar nicht mehr gezeigt")

        let leinwand = ausschnitt(text, von: "private func aufDieLeinwand", bis: "private func imBestandLassen")
        XCTAssertTrue(leinwand.contains("oeffnen(eintrag"),
                      "das Geladene kommt auf einem zweiten Weg auf die Leinwand statt über „Öffnen“")
    }

    /// **Die Rückfrage nach dem Laden hat drei Wege** — so verlangt: ersetzen,
    /// nur in den Bestand, abbrechen. Sie ist die einzige der vier mit dem
    /// mittleren Weg: Nur dort liegt das Stück schon im Bestand.
    ///
    /// Mutation: `Button("Nur in den Bestand")` aus dem Zweig `.geladen`
    /// entfernen — dann bleibt nur „ersetzen oder gar nicht“, und wer beides
    /// will, muss zweimal laden.
    func testDieRueckfrageNachDemLadenHatDreiWege() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let dialog = ausschnitt(text, von: "presenting: rueckfrage", bis: "} message: { frage in")

        XCTAssertTrue(dialog.contains("Button(\"Ersetzen\", role: .destructive) { aufDieLeinwand(eintrag) }"),
                      "„Ersetzen“ fehlt — oder es ist nicht mehr als zerstörend gekennzeichnet")
        XCTAssertTrue(dialog.contains("Button(\"Nur in den Bestand\") { imBestandLassen(eintrag) }"),
                      "der zweite Weg fehlt: Das Geladene liegt im Bestand, und die Leinwand soll bleiben dürfen")
        XCTAssertTrue(dialog.contains("Button(\"Abbrechen\", role: .cancel) {}"),
                      "eine Rückfrage ohne Ausweg ist keine")
        XCTAssertEqual(dialog.components(separatedBy: "Button(\"Abbrechen\"").count - 1, 1,
                       "„Abbrechen“ steht mehrfach da — es gilt für alle vier Anlässe gemeinsam")
    }

    /// **Eine Rückfrage, nicht fünf.** Alle vier Anlässe — „Neu“,
    /// Größenwechsel, Öffnen, Laden — stellen dieselbe Frage und hängen an
    /// **einem** Zustand. Zwei Bedienelemente, die gleichzeitig aufgehen
    /// wollen, schließen einander aus: SwiftUI zeigt eines und verschluckt das
    /// andere stillschweigend. Genau deshalb steht auch die Frage nach dem
    /// Blatt in `onDismiss` und nicht im Knopf, der das Blatt schließt.
    ///
    /// Mutation: `onDismiss: blattGeschlossen` aus dem `.sheet` entfernen und
    /// `blattGeschlossen()` am Ende von `einlesen()` rufen — baut, übersetzt,
    /// und die Rückfrage kommt nie.
    func testEineRueckfrageFuerAllesWasUngesichertesVerwirft() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        XCTAssertFalse(text.contains(".alert("),
                       "neben der einen Rückfrage liegt wieder ein Hinweisfenster — zwei davon schließen einander aus")
        XCTAssertEqual(text.components(separatedBy: "isPresented: Binding(get: { rueckfrage != nil }").count - 1, 1,
                       "die Rückfrage hängt nicht mehr an genau einem Zustand")
        XCTAssertTrue(text.contains(".sheet(isPresented: $zeigeImportBlatt, onDismiss: blattGeschlossen)"),
                      "die Rückfrage nach dem Blatt wird wieder im selben Durchlauf gestellt, in dem das Blatt zugeht — SwiftUI verschluckt sie")

        for zweig in ["if ungesichert { rueckfrage = .groesse(neue) } else { groesseSetzen(neue) }",
                      "if ungesichert { rueckfrage = .neu } else { neu() }",
                      "if ungesichert { rueckfrage = .oeffnen(eintrag) } else { oeffnen(eintrag) }",
                      "if ungesichert { rueckfrage = .geladen(eintrag) } else { aufDieLeinwand(eintrag) }"] {
            XCTAssertTrue(text.contains(zweig), "„\(zweig)“ fehlt — dieser Anlass fragt wieder nach eigener Regel")
        }
    }

    /// **Woran „ungesichert“ hängt.** Nicht an „ist die Leinwand leer“ — das
    /// war zweimal falsch: Eine gemalte, nie gesicherte Zeichnung ist nicht
    /// leer, und ein eben geöffnetes Bild ist nicht ungesichert. Gerechnet
    /// wird es im Kern, gegen den Stand, der im Bestand liegt; die Ansicht
    /// sagt nur, **wann** dieser Stand ein anderer wird.
    ///
    /// Mutation: `verlauf.gesichertMerken(leinwand)` aus `sichern()` entfernen
    /// — dann gilt frisch Gesichertes weiter als ungesichert, und jedes
    /// „Neu“ danach fragt umsonst.
    func testUngesichertHaengtAmGesichertenStandUndNichtAnIstLeer() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")

        XCTAssertTrue(text.contains("private var ungesichert: Bool { verlauf.weichtAb(leinwand) }"),
                      "die Ansicht rechnet wieder selbst, statt den Kern zu fragen")
        XCTAssertFalse(text.contains("istLeer"),
                       "„leer“ steht wieder für „nichts zu verlieren“ — eine gemalte, nie gesicherte Zeichnung ist nicht leer")

        for (stelle, bis) in [("private func groesseSetzen", "private func neuAnfragen"),
                              ("private func oeffnen(", "private func geladenUebernehmen"),
                              ("private func sichern()", "private func loeschen(")] {
            XCTAssertTrue(ausschnitt(text, von: stelle, bis: bis).contains("verlauf.gesichertMerken("),
                          "„\(stelle)“ sagt nicht mehr, was jetzt im Bestand liegt — der gesicherte Stand läuft weg")
        }
    }

    /// **Der Stift neben dem Papierkorb.** Gleiche Bauart, gleiche
    /// Trefferfläche, eigene Beschriftung für die Sprachausgabe — aber
    /// **nicht** gefärbt und nicht als zerstörend gekennzeichnet: Der
    /// Papierkorb wirft weg, Umbenennen nicht.
    ///
    /// Nichts davon sieht ein Übersetzer: Ein rot eingefärbter Stift mit
    /// zerstörender Rolle baut und zeichnet anstandslos.
    ///
    /// Mutation: den Stift als `Button(role: .destructive)` schreiben — der
    /// Test fällt, und am Gerät stünden zwei Warnfarben nebeneinander, von
    /// denen eine nichts zerstört.
    func testDieBestandszeileHatEinenStiftNebenDemPapierkorb() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let zeile = ausschnitt(text, von: "private func bestandszeile", bis: "private var sendezeile")

        XCTAssertTrue(zeile.contains("Image(systemName: \"pencil\")"),
                      "der Stift fehlt — dann gibt es in der Liste keinen Weg zum Umbenennen")
        XCTAssertTrue(zeile.contains("umbenennenBeginnen(eintrag)"),
                      "der Stift führt nicht mehr auf das Umbenennen")
        XCTAssertEqual(zeile.components(separatedBy: ".buttonStyle(.borderless)").count - 1, 2,
                       "Stift und Papierkorb tragen nicht mehr denselben Stil — dann haben sie "
                       + "verschiedene Größen und Trefferflächen")
        XCTAssertTrue(zeile.contains("lokf(\"„%@“ umbenennen\", eintrag.name)"),
                      "der Stift trägt keine Beschriftung mit dem Namen — zwei gleiche Symbole "
                      + "untereinander sind sonst nicht auseinanderzuhalten")
        for faerbung in ["role: .destructive) { umbenennenBeginnen", ".knopfZerstoerend()",
                         ".foregroundStyle(.red)"] {
            XCTAssertFalse(zeile.contains(faerbung),
                           "„\(faerbung)“ steht in der Bestandszeile — Umbenennen zerstört nichts")
        }
        XCTAssertTrue(zeile.contains("Button(\"Umbenennen…\") { umbenennenBeginnen(eintrag) }"),
                      "das Kontextmenü der Zeile bietet kein Umbenennen an")
    }

    /// **Umbenennen benennt eine Datei um** — also dieselben Fragen wie beim
    /// Sichern, und dieselbe Antwort wie beim Import: sichtbar ersetzen statt
    /// abweisen, mit umbenanntem Knopf. Ohne Namen bleibt er gesperrt und
    /// sichtbar abgeblendet stehen.
    ///
    /// Der stille Rückfall ist der gesperrte Knopf: Beim 8×8 trägt die Nummer
    /// den Schlüssel — ein leerer Name allein ließe ihn dort offen, und das
    /// Icon hieße hinterher nach seiner Nummer.
    ///
    /// Mutation: die zweite Bedingung (`benennName…isEmpty`) streichen — baut,
    /// übersetzt, und beim 8×8 lässt sich der Name leeren.
    func testDasUmbenennenblattWarntVorherUndSperrtDenLeerenNamen() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let blatt = ausschnitt(text, von: "private func umbenennenBlatt", bis: "private func benennSchluessel")

        XCTAssertTrue(blatt.contains("if eintrag.groesse.mitNummer {"),
                      "die Nummer hängt nicht mehr an der abgeleiteten Eigenschaft — "
                      + "dann fehlt sie beim 16×52 oder steht beim 16×16 da, wo es keine gibt")
        XCTAssertTrue(blatt.contains("if let vorhanden = benennBelegt(eintrag) {"),
                      "das Blatt warnt nicht mehr vor einem belegten Schlüssel — "
                      + "dann merkt man das Ersetzen erst, wenn es geschehen ist")
        XCTAssertTrue(blatt.contains("lok(\"Ersetzen\")"),
                      "der Knopf heißt nicht mehr „Ersetzen“, wo er ersetzt")
        XCTAssertTrue(blatt.contains(".disabled(benennSchluessel(eintrag).isEmpty\n"
                                     + "                          || benennName.trimmingCharacters(in: .whitespaces).isEmpty)"),
                      "ohne beide Bedingungen lässt sich der Name leeren oder ein Eintrag ohne Schlüssel anlegen")

        let belegt = ausschnitt(text, von: "private func benennBelegt", bis: "private func schritt()")
        XCTAssertTrue(belegt.contains("treffer?.id == eintrag.id ? nil : treffer"),
                      "der Eintrag zählt wieder als sein eigener Ersatz — dann warnt das Blatt, "
                      + "sobald man nur die Nummer ändert")
    }

    /// **Liegt das Umbenannte gerade auf der Leinwand, zieht sein Name mit.**
    /// Sonst legte das nächste „Sichern“ es unter dem alten Namen ein zweites
    /// Mal an. Beim Löschen zieht derselbe Vergleich den umgekehrten Schluss —
    /// dort wird der Bezug geleert; **eine** Rechnung, zwei Folgerungen.
    ///
    /// Mutation: `if offen { … }` aus `umbenennen` streichen — baut und
    /// übersetzt, und wer nach dem Umbenennen sichert, hat sein Bild zweimal.
    func testDerNameZiehtMitWennDasUmbenannteAufDerLeinwandLiegt() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let handlung = ausschnitt(text, von: "private func umbenennen(_ eintrag", bis: "private func nachladen")

        XCTAssertTrue(handlung.contains("let offen = istGeoeffnet(eintrag)"),
                      "ob das Umbenannte offen ist, wird nicht mehr **vor** der Umbenennung "
                      + "festgestellt — danach stimmt der Vergleich nicht mehr")
        XCTAssertTrue(handlung.contains("if offen {"),
                      "der Name zieht nicht mehr mit — das nächste „Sichern“ legt das Bild "
                      + "unter dem alten Namen noch einmal an")

        let loeschen = ausschnitt(text, von: "private func loeschen(_ eintrag", bis: "private func umbenennenBeginnen")
        XCTAssertTrue(loeschen.contains("if istGeoeffnet(eintrag) {"),
                      "das Löschen rechnet wieder selbst, ob der Eintrag offen ist")

        let vergleich = ausschnitt(text, von: "private func istGeoeffnet", bis: "private var feld: Pixelfeld")
        XCTAssertTrue(vergleich.contains("eintrag.schluessel.caseInsensitiveCompare(schluessel)"),
                      "verglichen werden wieder Namen statt Schlüssel — bei 16×52 geht das daneben, "
                      + "weil der Dateiname der bereinigte Name ist")
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
                      "der Inspektor trägt die Moduswahl nicht mehr an seinem Kopf — dann gibt es keinen Weg mehr zu den vier Modi")

        let wahl = ausschnitt(text, von: "private var modusWahl", bis: "private var malenAbschnitte")
        XCTAssertTrue(wahl.contains(".pickerStyle(.segmented)"),
                      "die Moduswahl ist keine Segmentwahl mehr")
        // **Symbole statt Woerter** seit dem 14.09.2026: Vier ausgeschriebene
        // Namen passen in 330 Punkte nicht mehr, ohne abgeschnitten zu werden.
        // Die Namen duerfen deshalb nicht verschwinden, sondern wandern an die
        // Bedienungshilfen — geprueft wird beides, Symbol **und** Name.
        for (modus, symbol) in [("Malen", "paintpalette"), ("Animation", "film"),
                                ("Bestand", "folder"), ("Zeit", "clock")] {
            XCTAssertTrue(wahl.contains("Image(systemName: \"\(symbol)\").tag("),
                          "„\(modus)“ fehlt als Symbol „\(symbol)“ — oder das Kennzeichen sitzt nicht mehr ganz außen")
            XCTAssertTrue(wahl.contains("accessibilityLabel(Text(\"\(modus)\"))"),
                          "„\(modus)“ hat keinen Namen mehr — ein Symbol ohne Namen ist für VoiceOver stumm")
        }
    }

    /// **F5.** Im Fenster gibt es genau **einen** Anwaerter auf die Eingabetaste.
    ///
    /// „Sichern" und „Senden" trugen bis zum 14.09.2026 beide
    /// `.keyboardShortcut(.defaultAction)`. Welchen von zweien SwiftUI dann
    /// nimmt, ist nicht festgelegt — und genau so ein Gleichstand hat kurz
    /// zuvor „Sichern" das zerstoerende „Neu" ausloesen lassen. Der Uebersetzer
    /// hat dazu nichts zu sagen: Zwei Vorgabetasten uebersetzen anstandslos.
    ///
    /// Gezaehlt wird nur, was im **Fenster** steht. Die beiden Blaetter
    /// dahinter („Oeffnen", „Umbenennen") sind eigene, modale Zusammenhaenge
    /// und haben ihre Vorgabetaste zu Recht.
    func testImFensterGibtEsGenauEinenAnwaerterAufDieEingabetaste() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        let fenster = ausschnitt(text, von: "public var body", bis: "private var importBlatt")
        let anwaerter = fenster.components(separatedBy: ".keyboardShortcut(.defaultAction)").count - 1
        XCTAssertEqual(anwaerter, 1,
                       "im Editorfenster stehen \(anwaerter) Knöpfe auf der Eingabetaste — "
                       + "welcher gewinnt, ist Zufall")

        XCTAssertTrue(ausschnitt(text, von: "private var sichernAbschnitte", bis: "private var pfeilkreuz")
                        .contains(".keyboardShortcut(.defaultAction)"),
                      "„Sichern“ hat die Eingabetaste nicht mehr — sie gehört der einen Haupthandlung, "
                      + "und die gibt es bei jeder Leinwandgröße")

        XCTAssertFalse(ausschnitt(text, von: "private var sendeKnopf", bis: "private var importBlatt")
                        .contains(".keyboardShortcut(.defaultAction)"),
                       "„Senden“ hat die Eingabetaste wieder — diese Zeile gibt es nur bei 16×52, "
                       + "die Taste täte dann je nach Leinwand etwas anderes")
    }
}
