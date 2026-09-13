import XCTest
@testable import TC002Core

/// `Ablageort` entscheidet, wo die vier Bestaende liegen. Was hier schiefgeht,
/// faellt nicht als Fehlermeldung auf, sondern als verschwundener Bestand —
/// die App legte still einen zweiten an und der alte bliebe unberuehrt liegen.
///
/// **Kein Test hier fasst `Ablageort.gemeinsam` an**: Das waere der echte
/// Bestand dieser Installation. Alles laeuft gegen Wegwerfverzeichnisse und
/// gegen eine Wegwerf-Ablage.
final class AblageortTests: XCTestCase {

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    // MARK: Wo was liegt

    /// Ohne gewaehlten Abgleich liegt alles dort, wo es seit jeher liegt —
    /// auch wenn ein Behaelter bereitstuende.
    func testOhneWahlBleibtAllesOertlich() {
        let oertlich = temp(), fern = temp()
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: fern, gewuenscht: false)
        XCTAssertFalse(ort.wirkt)
        XCTAssertEqual(ort.ordner(.icons8), oertlich.appendingPathComponent("Icons"))
        XCTAssertEqual(ort.ordner(.icons16), oertlich.appendingPathComponent("Icons16"))
        XCTAssertEqual(ort.ordner(.bilder), oertlich.appendingPathComponent("Bilder"))
        XCTAssertEqual(ort.ordner(.slots), oertlich.appendingPathComponent("Slots"))
    }

    /// Gewaehlt und moeglich: alle vier im Behaelter, keiner davon vergessen.
    func testMitWahlUndBehaelterLiegtAllesDort() {
        let oertlich = temp(), fern = temp()
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: fern, gewuenscht: true)
        XCTAssertTrue(ort.wirkt)
        for bestand in Ablageort.Bestand.allCases {
            XCTAssertEqual(ort.ordner(bestand), fern.appendingPathComponent(bestand.rawValue))
        }
    }

    /// **Der Normalfall, solange die Berechtigung fehlt.** Gewaehlt, aber kein
    /// Behaelter: Die App arbeitet weiter genau wie vorher, oertlich. Kein
    /// halber Zustand, kein Fehler.
    func testOhneBehaelterArbeitetDieAppWeiterOertlich() {
        let oertlich = temp()
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: nil, gewuenscht: true)
        XCTAssertFalse(ort.wirkt, "ohne Behaelter wirkt der Abgleich nicht")
        XCTAssertTrue(ort.gewuenscht, "die Wahl bleibt trotzdem stehen")
        XCTAssertEqual(ort.wurzel, oertlich)
        XCTAssertNil(ort.fernerOrdner(.icons8))
    }

    /// Der oertliche Ordner bleibt auch dann benennbar, wenn der Abgleich
    /// wirkt — der Rueckweg braucht ihn.
    func testDerOertlicheOrdnerBleibtErreichbar() {
        let oertlich = temp(), fern = temp()
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: fern, gewuenscht: true)
        XCTAssertEqual(ort.oertlicherOrdner(.bilder), oertlich.appendingPathComponent("Bilder"))
        XCTAssertEqual(ort.fernerOrdner(.bilder), fern.appendingPathComponent("Bilder"))
    }

    // MARK: Was angelegt wird, und wann

    /// `ordner(_:)` liegt im Zeichenweg — `AppZustand.slotzustand` fragt es
    /// fuenfmal je Neuzeichnen, also bei jedem Tastendruck im Textfeld. Es
    /// darf deshalb nichts anlegen, sondern nur rechnen.
    func testOrdnerLegtNichtsAn() {
        let oertlich = temp()
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: nil, gewuenscht: false)
        _ = ort.ordner(.slots)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ort.ordner(.slots).path),
                       "ordner(_:) rechnet nur — angelegt wird in angelegt()")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oertlich.path))
    }

    /// Angelegt werden alle vier, unter genau diesen Namen. Ein vergessener
    /// Bestand faellt sonst erst dem Anwender auf.
    func testAngelegtLegtAlleVierAn() throws {
        let oertlich = temp()
        defer { try? FileManager.default.removeItem(at: oertlich) }
        let ort = Ablageort(oertlicheWurzel: oertlich, ferneWurzel: nil, gewuenscht: false).angelegt()
        XCTAssertEqual(ort.wurzel, oertlich)
        let inhalt = try FileManager.default.contentsOfDirectory(atPath: oertlich.path).sorted()
        XCTAssertEqual(inhalt, ["Bilder", "Icons", "Icons16", "Slots"])
    }

    // MARK: Die Wahl — und warum sie dort liegt, wo sie liegt

    /// Die Wahl liegt in **derselben** Ablage, aus der auch das Werkzeug seine
    /// Einstellungen liest. Nur deshalb folgt es dem Abgleich, ohne selbst
    /// etwas davon zu wissen. Ein eigener Bereich oder ein anderer Schluessel
    /// hiesse: Die App zieht um, das Werkzeug schreibt weiter am alten Ort.
    func testDieWahlLiegtWoDasWerkzeugSieFindet() {
        let bereich = "cloud.eriks.mqtt-tc002.test.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: bereich) }

        XCTAssertFalse(Ablageort.gewaehlt(bereich: bereich), "frisch heisst aus")
        Ablageort.waehlen(true, bereich: bereich)
        XCTAssertTrue(Ablageort.gewaehlt(bereich: bereich))

        // Derselbe Weg, den `Einstellungen.gelesen` nimmt — der des Werkzeugs.
        let wieDasWerkzeug = UserDefaults(suiteName: bereich)
        XCTAssertEqual(wieDasWerkzeug?.bool(forKey: "icloud.abgleich"), true)

        Ablageort.waehlen(false, bereich: bereich)
        XCTAssertFalse(Ablageort.gewaehlt(bereich: bereich))
    }

    /// Die Behaelterkennung steht in drei Dateien gleichlautend: hier, im
    /// Entwicklerkonto und in der Signatur
    /// (`com.apple.developer.icloud-container-identifiers`). Weicht eine ab,
    /// liefert `url(forUbiquityContainerIdentifier:)` `nil` — und zwar
    /// wortlos, so wie auch ohne jede Berechtigung.
    func testBehaelterkennungIstDieBuendelkennungMitPraefix() {
        XCTAssertEqual(Ablageort.behaelterKennung, "iCloud.cloud.eriks.mqtt-tc002")
        XCTAssertEqual(Ablageort.behaelterKennung, "iCloud." + Einstellungen.kennung)
    }
}
