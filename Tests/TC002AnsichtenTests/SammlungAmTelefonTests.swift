import XCTest

/// Am Telefon ist die ganze Sammlung erreichbar.
///
/// Sie war es nicht: Die 8 × 8 und 16 × 16 standen im Auswahlblatt, die
/// 52 × 16-Anzeigen hinter einem unbeschrifteten 🖼 am Ende der Formatpille —
/// ohne Überblick, ohne Suche, ohne Weg, etwas hinzuzufügen. Dass eine 52 × 16
/// nicht *in* der Iconauswahl steht, ist richtig (ein Icon steht neben dem
/// Text, eine Anzeige ersetzt ihn); am Schreibtisch trägt „Icons" diese
/// Entscheidung, weil es dort den zweiten Ort gibt. Am Telefon gab es den
/// nicht.
///
/// Geprüft wird am Quelltext, wie in `KnopfstilTests` und
/// `GrafiksperreAnsichtenTests`: Ob das Blatt gut aussieht, sieht man am Gerät;
/// dass die drei Größen überhaupt darin stehen und eine Anzeige von dort
/// hinausgeht, steht hier.
final class SammlungAmTelefonTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    private func blatt() throws -> String {
        try ohneKommentare("Sources/TC002iOS/IconsblattiOS.swift")
    }

    /// Alle drei Bestände werden gelesen, und zwar über `Editorbestand` — die
    /// eine Stelle, die weiß, wo welche Größe liegt.
    func testDasBlattLiestAlleDreiBestaende() throws {
        let quelle = try blatt()
        for merkmal in ["Editorbestand(", "icons8:", "icons16:", "bilder:"] as [String] {
            XCTAssertTrue(quelle.contains(merkmal),
                          "Das Icons-Blatt liest nicht mehr alle drei Bestände (\(merkmal) fehlt).")
        }
    }

    /// Und jede der drei Größen bekommt ihre Gruppe. `allCases`, nicht drei
    /// aufgezählte Fälle: Eine vierte Größe stünde damit von selbst da.
    func testJedeGroesseBekommtIhreGruppe() throws {
        let quelle = try blatt()
        XCTAssertTrue(quelle.contains("ForEach(Leinwandgroesse.allCases) { gruppe($0) }"),
                      "Das Icons-Blatt gruppiert nicht mehr über alle Größen.")
        XCTAssertTrue(quelle.contains("Text(lok(groesse.beschriftung))"),
                      "Die Gruppen tragen ihre Größe nicht mehr als Überschrift.")
    }

    /// Eine 52 × 16 lässt sich von hier aus schicken — derselbe Weg wie im
    /// Editor am Schreibtisch, über `Bildsendung.rahmen`.
    func testEineAnzeigeGehtVonHierAnDieUhr() throws {
        let quelle = try blatt()
        XCTAssertTrue(quelle.contains("Bildsendung.rahmen(aus: eintrag.datei)"),
                      "Die Anzeigeseite baut keinen Rahmen mehr — von hier geht nichts hinaus.")
        XCTAssertTrue(quelle.contains("zustand.senden(rahmen, als: name, slotPlatz: platz, slotPixel: slotPixel)"),
                      "Die Anzeigeseite schickt nicht mehr auf den gewählten Meldungsplatz — oder "
                      + "sie reicht die Pixel nicht mehr weiter, und der Block sagt danach "
                      + "„unbekannt“.")
    }

    /// Suchen, filtern, zurücksetzen — dieselben drei Fragen wie in der
    /// Übersicht am Schreibtisch, über denselben `Bestandsfilter`.
    func testDasBlattLaesstSichDurchsuchenUndEinschraenken() throws {
        let quelle = try blatt()
        XCTAssertTrue(quelle.contains(".searchable(text: $filter.suche"),
                      "Das Icons-Blatt hat keine Suche mehr.")
        XCTAssertTrue(quelle.contains("Filterleiste(wert: $filter.groesse"),
                      "Das Icons-Blatt hat keine Filterleiste mehr.")
        XCTAssertTrue(quelle.contains("if filter.schraenktEin"),
                      "Das Zurücksetzen steht wieder ohne Anlass da — oder gar nicht.")
        XCTAssertTrue(quelle.contains("filter.zuruecksetzen()"),
                      "Das Zurücksetzen nimmt nicht mehr alle drei Fragen zurück.")
    }

    /// Hinzufügen geht auf zwei Wegen: über die LaMetric-Nummer und aus den
    /// Dateien. Der zweite liest die Bytes sofort — eine URL aus dem
    /// Dateiwähler gilt nur zwischen `startAccessingSecurityScopedResource`
    /// und `stop…`, und wer sie sich merkt, greift am Gerät ins Leere.
    func testHinzufuegenGehtUeberNummerUndDatei() throws {
        let quelle = try blatt()
        XCTAssertTrue(quelle.contains("quelle.holen(nummer: nummer)"),
                      "Die LaMetric-Nummer holt nichts mehr.")
        XCTAssertTrue(quelle.contains("allowedContentTypes: [.gif, .png, .jpeg]"),
                      "Aus den Dateien kommt nichts mehr herein.")
        XCTAssertTrue(quelle.contains("bestand.einlesen(daten: daten"),
                      "Die Datei landet nicht mehr im Bestand ihrer eigenen Größe.")
        XCTAssertTrue(quelle.contains("url.startAccessingSecurityScopedResource()")
                      && quelle.contains("defer { if zugriff { url.stopAccessingSecurityScopedResource() } }"),
                      "Der Zugriff auf die gewählte Datei wird nicht mehr an- und abgemeldet.")
        XCTAssertTrue(quelle.contains("daten = try Data(contentsOf: url)")
                      && quelle.contains("importDaten = daten"),
                      "Der Import merkt sich wieder die URL statt der Bytes — außerhalb des "
                      + "Zugriffs ist sie nicht mehr lesbar.")
        XCTAssertFalse(quelle.contains("importURL"),
                       "Der Import hebt wieder eine URL auf.")
    }

    /// Die Sammlung steht oben, das Hinzufuegen darunter. Umgekehrt nahm das
    /// Feld fuer die LaMetric-Nummer die obere Haelfte des Blattes ein, und die
    /// Icons begannen unterhalb des Bildschirmrands — wer das Blatt oeffnet,
    /// will aber fast immer waehlen, nicht nachladen.
    func testDieSammlungStehtVorDemHinzufuegen() throws {
        let quelle = try blatt()
        guard let liste = quelle.range(of: "ForEach(Leinwandgroesse.allCases) { gruppe($0) }"),
              let zufuegen = quelle.range(of: "\n                hinzufuegen\n") else {
            return XCTFail("Das Blatt baut seine Liste nicht mehr aus Gruppen und „Hinzufügen“.")
        }
        XCTAssertTrue(liste.lowerBound < zufuegen.lowerBound,
                      "Das Hinzufügen steht wieder über der Sammlung; die Icons beginnen "
                      + "dann unterhalb des Bildschirmrands.")
    }

    /// Gemalt wird am Telefon weiterhin nicht: Ein 8 × 8-Raster mit dem Finger
    /// ist keine Arbeitsfläche. Ansehen, suchen, hinzufügen und verschicken ist
    /// kein Malen — die Leinwand bleibt draußen.
    func testAmTelefonWirdNichtGemalt() throws {
        let quelle = try blatt()
        for verboten in ["Malflaeche", "Malraster", "EditorBereichView"] as [String] {
            XCTAssertFalse(quelle.contains(verboten),
                           "Im Icons-Blatt steht wieder eine Leinwand (\(verboten)).")
        }
    }
}
