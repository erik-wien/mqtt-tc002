import XCTest
@testable import TC002Core

/// **Die eine Stelle, die den echten Schlüsselbund befragen muss.**
///
/// Überall sonst tritt `Schluesselbundzugriff` als Doppelgänger an, aus dem
/// Grund, der dort steht. Hier geht das nicht: Geprüft wird gerade, ob unsere
/// Aufrufe von `SecItemAdd`, `SecItemCopyMatching` und `SecItemDelete` richtig
/// sind. Ein Doppelgänger davor würde nur sich selbst bestätigen — der
/// klassische Test, der grün bleibt, während die Sache kaputt ist.
///
/// Eingegrenzt wird das deshalb nicht durch Vermeiden, sondern durch einen
/// **eigenen Dienst**: `dienst` weicht hier von `Einstellungen.kennung` ab, und
/// damit liegt kein Testeintrag je im Namensraum der App. Vorher trugen diese
/// Tests ein Wegwerfkonto, aber den echten Dienst der App — im Schlüsselbund
/// des Menschen, der sie laufen lässt. `testDerDienstDerAppBleibtUnberuehrt`
/// hält das fest, damit ein weggelassenes `dienst:` auffällt und nicht still
/// wieder in die App hineinschreibt.
final class SchluesselbundTests: XCTestCase {
    private let konto = "test-\(UUID().uuidString)"
    /// Ein Dienst, den es nur für diesen Lauf gibt.
    private let dienst = "\(Einstellungen.kennung).test.\(UUID().uuidString)"

    override func tearDown() { Schluesselbund.loeschen(konto, dienst: dienst) }

    func testSchreibenLesenLoeschen() {
        XCTAssertNil(Schluesselbund.lesen(konto, dienst: dienst))
        Schluesselbund.setzen("geheim", fuer: konto, dienst: dienst)
        XCTAssertEqual(Schluesselbund.lesen(konto, dienst: dienst), "geheim")
        Schluesselbund.setzen("neu", fuer: konto, dienst: dienst)
        XCTAssertEqual(Schluesselbund.lesen(konto, dienst: dienst), "neu", "Überschreiben muss gehen")
        Schluesselbund.loeschen(konto, dienst: dienst)
        XCTAssertNil(Schluesselbund.lesen(konto, dienst: dienst))
    }

    /// Der Rueckgabewert ist der einzige Weg, ein gescheitertes Schreiben zu
    /// bemerken — sonst ist das Kennwort erst nach dem Neustart weg.
    func testSetzenMeldetErfolg() {
        XCTAssertTrue(Schluesselbund.setzen("geheim", fuer: konto, dienst: dienst))
        XCTAssertTrue(Schluesselbund.setzen("geheim", fuer: konto, dienst: dienst), "Überschreiben ebenso")
    }

    /// Ein leeres Kennwort ist kein Eintrag, aber auch kein Fehlschlag.
    func testLeererWertLoeschtOhneFehlschlag() {
        Schluesselbund.setzen("geheim", fuer: konto, dienst: dienst)
        XCTAssertTrue(Schluesselbund.setzen("", fuer: konto, dienst: dienst))
        XCTAssertNil(Schluesselbund.lesen(konto, dienst: dienst))
    }

    /// Die Abgrenzung selbst. Wer irgendwo oben das `dienst:` vergisst, schreibt
    /// wieder in den Schlüsselbund-Namensraum der App — dieser Test fällt dann.
    func testDerDienstDerAppBleibtUnberuehrt() {
        Schluesselbund.setzen("geheim", fuer: konto, dienst: dienst)
        XCTAssertNil(Schluesselbund.lesen(konto),
                     "unter dem Dienst der App darf nichts liegen, was hier geschrieben wurde")
        XCTAssertEqual(Schluesselbund.lesen(konto, dienst: dienst), "geheim",
                       "und unter dem eigenen Dienst sehr wohl — sonst prüfte der Test nichts")
    }
}
