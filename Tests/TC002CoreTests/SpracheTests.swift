import XCTest
@testable import TC002Core

/// In Tests gibt es kein Buendel mit Uebersetzungen — `lok` liefert also den
/// deutschen Wortlaut zurueck. Genau das soll geprueft werden: Der Rueckfall
/// muss der Satz sein, nicht ein leerer String oder ein Schluesselname.
final class SpracheTests: XCTestCase {

    func testOhneUebersetzungBleibtDerDeutscheSatz() {
        XCTAssertEqual(lok("Der Broker hat nicht geantwortet."),
                       "Der Broker hat nicht geantwortet.")
    }

    func testEigenerSchluesselFaelltAufDieVorgabeZurueck() {
        XCTAssertEqual(lok("cli.hilfe", vorgabe: "Aufruf: mqtttc002 …"),
                       "Aufruf: mqtttc002 …")
    }

    /// `%d` in einem Schluessel bekommt einen `Int`. Auf 64 Bit ist das nicht
    /// selbstverstaendlich — `%d` ist von Haus aus 32-bittig —, und ein
    /// falsches Ergebnis faellt in der Oberflaeche nicht auf, weil dort ohnehin
    /// irgendeine Zahl steht. Deshalb hier festgehalten.
    func testGanzzahlenWerdenRichtigEingesetzt() {
        XCTAssertEqual(lokf("Rand %d", 3), "Rand 3")
        XCTAssertEqual(lokf("%d Byte", 62_000), "62000 Byte")
        XCTAssertEqual(lokf("von %d×%d auf %d×%d", 16, 16, 8, 8), "von 16×16 auf 8×8")
    }

    func testZeichenkettenWerdenRichtigEingesetzt() {
        XCTAssertEqual(lokf("an %@ gesendet: %@", "Küche", "cli"),
                       "an Küche gesendet: cli")
    }

    /// Die Reihenfolge bleibt, wie sie dasteht — eine Uebersetzung, die zwei
    /// Platzhalter vertauscht, vertauscht auch die Werte. Das ist der Grund,
    /// warum in der Uebersetzung Zahl und Reihenfolge der Platzhalter
    /// uebereinstimmen muessen.
    func testGemischtePlatzhalterInDerReihenfolge() {
        XCTAssertEqual(lokf("%@: Präfix %@, MQTT %@", "Küche", "awtrix_a86b", "verbunden"),
                       "Küche: Präfix awtrix_a86b, MQTT verbunden")
        XCTAssertEqual(lokf("Läuft durch: %d Einzelbilder, %@", 128, "rund 10 KB"),
                       "Läuft durch: 128 Einzelbilder, rund 10 KB")
    }
}
