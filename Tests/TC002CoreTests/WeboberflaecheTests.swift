import XCTest
@testable import TC002Core

/// Der Knopf „Konfigurieren" in den Einstellungen führt zur Web-Oberfläche der
/// Uhr. Die Adresse dafür stammt aus einem Eingabefeld — auf solche Eingaben
/// gehört kein `URL(string:)!`: Eine ungültige Eingabe würde die App
/// abstürzen lassen statt eine Meldung zu ergeben.
final class WeboberflaecheTests: XCTestCase {
    func testAusEinerAdresseWirdEineHttpAdresse() {
        XCTAssertEqual(Geraet.weboberflaeche(host: "10.0.0.1")?.absoluteString, "http://10.0.0.1")
    }

    /// Der wichtigste Fall: `URL(string: "http://")` liefert eine gültige
    /// URL — nur zeigt sie nirgendwohin. Ohne die Prüfung auf den Rechnernamen
    /// stünde neben einer Uhr ohne Adresse ein Knopf, der ins Leere führt.
    func testEinLeererHostGibtKeineAdresse() {
        XCTAssertNil(Geraet.weboberflaeche(host: ""))
        XCTAssertNil(Geraet.weboberflaeche(host: "   "))
        // Und der Fall, den die Leerprüfung allein nicht fängt: ein
        // Schema ohne Rechnernamen. `URL(string: "http://")` ist gültig.
        XCTAssertNil(Geraet.weboberflaeche(host: "http://"))
    }

    /// Ein eingetragenes Schema bleibt stehen, statt ein zweites davorzusetzen.
    func testEinEigenesSchemaBleibt() {
        XCTAssertEqual(Geraet.weboberflaeche(host: "https://uhr.lan")?.absoluteString, "https://uhr.lan")
    }

    /// Leerraum um die Adresse herum ist beim Eintippen schnell passiert —
    /// und `URL(string:)` sagt dazu `nil`.
    func testLeerraumWirdAbgeschnitten() {
        XCTAssertEqual(Geraet.weboberflaeche(host: "  10.0.0.1 ")?.absoluteString, "http://10.0.0.1")
    }

    /// Ein Leerzeichen in der Adresse ergibt keine URL — dann steht kein
    /// Knopf da, statt dass einer abstürzt.
    func testEineUnmoeglicheAdresseGibtNichts() {
        XCTAssertNil(Geraet.weboberflaeche(host: "10.0.0.1 /pfad"))
    }
}
