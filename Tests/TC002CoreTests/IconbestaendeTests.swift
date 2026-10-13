import XCTest
@testable import TC002Core

/// Dass ein 16×16 vom Werkzeug und von den Kurzbefehlen aus gefunden wird,
/// nicht nur ein 8×8 — sonst antwortet „Kein Icon" für ein vorhandenes Icon.
final class IconbestaendeTests: XCTestCase {
    /// Ein Wegwerfordner mit genau einer Icondatei. Das kleinste gueltige
    /// GIF-Kopfstueck genuegt: geprueft wird das Finden, nicht das Bild.
    private func ordner(mit dateiname: String) throws -> URL {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
            .write(to: ordner.appendingPathComponent(dateiname))
        return ordner
    }

    /// Der Fall, um den es geht: Der Schluessel liegt im zweiten Bestand.
    func testEinSechzehnerWirdGefunden() throws {
        let achter = Iconsammlung(ordner: try ordner(mit: "1673.gif"))
        let sechzehner = Iconsammlung(ordner: try ordner(mit: "Sonne.gif"), kante: 16)

        let gefunden = Iconbestaende.suchen("Sonne", in: [achter, sechzehner])
        XCTAssertEqual(gefunden?.nummer, "Sonne")
        XCTAssertEqual(gefunden?.kante, 16, "die Kante muss vom Bestand kommen, nicht die Vorgabe 8 sein")
    }

    /// Und der erste Bestand funktioniert weiter — sonst haette die Erweiterung
    /// das Vorhandene kaputtgemacht.
    func testEinAchterWirdWeiterhinGefunden() throws {
        let achter = Iconsammlung(ordner: try ordner(mit: "1673.gif"))
        let sechzehner = Iconsammlung(ordner: try ordner(mit: "Sonne.gif"), kante: 16)

        XCTAssertEqual(Iconbestaende.suchen("1673", in: [achter, sechzehner])?.kante, 8)
    }

    /// Der Zusammenstoss ist entschieden, nicht zufaellig: Traegt ein 16×16
    /// den Dateinamen einer LaMetric-Nummer, gewinnt das LaMetric-Icon — es ist
    /// der Bestand, auf den sich eine Nummer in einem Kurzbefehl bezieht.
    func testBeiGleichemSchluesselGewinntDerAchterBestand() throws {
        let achter = Iconsammlung(ordner: try ordner(mit: "1673.gif"))
        let sechzehner = Iconsammlung(ordner: try ordner(mit: "1673.gif"), kante: 16)

        XCTAssertEqual(Iconbestaende.suchen("1673", in: [achter, sechzehner])?.kante, 8)
    }

    /// Nichts gefunden heisst nil, nicht „irgendeines" — die Meldung darueber
    /// formulieren die Aufrufer.
    func testUnbekannterSchluesselFindetNichts() throws {
        let achter = Iconsammlung(ordner: try ordner(mit: "1673.gif"))
        XCTAssertNil(Iconbestaende.suchen("4711", in: [achter]))
    }

    // MARK: - Paare

    private func icon(_ nummer: String, _ kante: Int) -> Icon {
        Icon(nummer: nummer, name: nummer, kategorie: "",
             datei: URL(fileURLWithPath: "/tmp/\(kante)/\(nummer).gif"), kante: kante)
    }

    func testPaarWirdInBeidenRichtungenGefunden() {
        let k = Iconbestaende.paarkennungen([icon("haus", 8), icon("haus-16", 16)])
        XCTAssertEqual(k, ["8/haus", "16/haus-16"])
    }

    func testEinzelnerAchterOhnePartner() {
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("haus", 8), icon("baum", 8)]).isEmpty)
    }

    func testEinzelnerSechzehnerOhnePartner() {
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("sonne", 16)]).isEmpty)
    }

    func testSechzehnerMitEndungOhneAchter() {
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("sonne-16", 16), icon("haus", 8)]).isEmpty)
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("-16", 16), icon("", 8)]).isEmpty)
    }

    func testSechzehnerDessenGrundnameNichtPasst() {
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("haus", 16), icon("haus", 8)]).isEmpty,
                      "ohne Endung -16 gehoert ein 16×16 zu keinem 8×8")
        XCTAssertTrue(Iconbestaende.paarkennungen([icon("baum-16", 16), icon("haus", 8)]).isEmpty)
    }
}
