import XCTest
@testable import TC002Core

/// Der Intent muss dieselben Formateinstellungen benutzen wie die Ansicht,
/// sonst sieht eine über Siri geschickte Meldung anders aus als dieselbe
/// Meldung aus der App. Gelesen werden die `senden.*`-Schlüssel, die
/// `@AppStorage` ablegt.
final class MeldungsoptionenAblageTests: XCTestCase {

    private func ablage() -> UserDefaults {
        UserDefaults(suiteName: "test.mqtt-tc002." + UUID().uuidString)!
    }

    func testLeereAblageErgibtDieVorgaben() {
        let o = Meldungsoptionen.ausAblage(ablage())
        XCTAssertEqual(o.schrift, "Silkscreen")
        XCTAssertEqual(o.groesse, 8)
        XCTAssertEqual(o.farbe, "#00FF66")
        XCTAssertEqual(o.abstand, 1)
        XCTAssertEqual(o.rand, 1)
        XCTAssertEqual(o.weg, .pixel)
        XCTAssertEqual(o.waagrecht, .links)
        XCTAssertEqual(o.senkrecht, .mittig)
        XCTAssertEqual(o.tempo, .mittel)
    }

    func testGesicherteWerteWerdenGelesen() {
        let d = ablage()
        d.set("Menlo", forKey: "senden.schriftart")
        d.set(12.0, forKey: "senden.groesse")
        d.set("#FF0000", forKey: "senden.farbe")
        d.set(true, forKey: "senden.fett")
        d.set(3, forKey: "senden.rand")
        d.set("rechts", forKey: "senden.horizontal")
        d.set("unten", forKey: "senden.vertikal")
        d.set("text", forKey: "senden.weg")
        d.set("schnell", forKey: "senden.tempo")

        let o = Meldungsoptionen.ausAblage(d)
        XCTAssertEqual(o.schrift, "Menlo")
        XCTAssertEqual(o.groesse, 12)
        XCTAssertEqual(o.farbe, "#FF0000")
        XCTAssertTrue(o.fett)
        XCTAssertEqual(o.rand, 3)
        XCTAssertEqual(o.waagrecht, .rechts)
        XCTAssertEqual(o.senkrecht, .unten)
        XCTAssertEqual(o.weg, .text)
        XCTAssertEqual(o.tempo, .schnell)
    }

    /// Ein unsinniger Wert darf nicht zum Absturz führen, sondern fällt auf die
    /// Vorgabe zurück — von Hand verbogene Einstellungen gibt es.
    func testUnsinnFaelltAufDieVorgabeZurueck() {
        let d = ablage()
        d.set("grün", forKey: "senden.horizontal")
        d.set("sehr schnell", forKey: "senden.tempo")
        let o = Meldungsoptionen.ausAblage(d)
        XCTAssertEqual(o.waagrecht, .links)
        XCTAssertEqual(o.tempo, .mittel)
    }

    // MARK: - Darstellung

    func testLeereAblageHatKeineDarstellung() {
        XCTAssertNil(Meldungsoptionen.ausAblage(ablage()).darstellung)
    }

    /// Die Ansicht legt die Wahl als JSON ab (`Darstellungswahl.rawValue`); der
    /// Kurzbefehl sendet danach mit Overlay und Palette wie die App zuletzt.
    func testGesicherteDarstellungWirdGelesen() throws {
        var wahl = Darstellungswahl()
        wahl.overlay = "rain"
        wahl.palette = .name("Ocean")
        wahl.hintergrundfarbe = "#112233"
        let d = ablage()
        d.set(wahl.rawValue, forKey: "senden.darstellung")

        XCTAssertEqual(Meldungsoptionen.ausAblage(d).darstellung, wahl)
    }

    /// Eine unveraenderte Wahl ist "nichts gewaehlt", wie in `SendenView.optionen`.
    func testUnveraenderteDarstellungBleibtNil() {
        let d = ablage()
        d.set(Darstellungswahl().rawValue, forKey: "senden.darstellung")
        XCTAssertNil(Meldungsoptionen.ausAblage(d).darstellung)
    }

    func testUnlesbareDarstellungWirdUebergangen() {
        let d = ablage()
        d.set("kein json", forKey: "senden.darstellung")
        XCTAssertNil(Meldungsoptionen.ausAblage(d).darstellung)
    }
}
