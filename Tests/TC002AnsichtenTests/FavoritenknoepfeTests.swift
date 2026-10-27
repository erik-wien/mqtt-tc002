import XCTest
import TC002Core
@testable import TC002Modell
@testable import TC002Ansichten

/// Die Knöpfe über dem Eingabefeld: Was sie zeigen, entscheidet eine Funktion,
/// nicht die Darstellung.
final class FavoritenknoepfeTests: XCTestCase {
    private func bearbeitung() -> Favoritenbearbeitung {
        let suite = "favoritenknoepfe-" + UUID().uuidString
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        return Favoritenbearbeitung(favoritID: UUID(), titel: "Gruß", hinter: nil,
                                    vorher: Sendeauftrag.aus(d, zielIDs: []))
    }

    func testOhneBearbeitungWirdAngelegt() {
        XCTAssertEqual(Favoritenknoepfe.modus(bearbeitung: nil), .anlegen)
    }

    func testBearbeitungZeigtSpeichern() {
        XCTAssertEqual(Favoritenknoepfe.modus(bearbeitung: bearbeitung()), .bearbeiten)
    }

    func testLeererTitelSperrtSichern() {
        XCTAssertFalse(Favoritenknoepfe.sichernErlaubt(titel: ""))
        XCTAssertFalse(Favoritenknoepfe.sichernErlaubt(titel: "   "))
        XCTAssertTrue(Favoritenknoepfe.sichernErlaubt(titel: "Gruß"))
    }
}
