import XCTest
@testable import TC002Core

/// Was die Vorschau einer NG-Uhr zeigt, ist eine Näherung — und eine, die
/// immer dieselbe ist.
///
/// AWTRIX NG setzt den Text mit ihrer eigenen Schrift; unsere Schriftwahl ist
/// dort gesperrt (`Geraetetyp.wirkt(.schriftart)`). Der gespeicherte Wert
/// bleibt davon unberührt und kann „Tiny5, 16 px" sein — auf acht Zeilen
/// gerastert wäre das abgeschnitten, und die Vorschau zeigte einen Fehler, den
/// das Gerät gar nicht hat.
///
/// Im Kern und nicht in den Ansichten: Mac und iPhone rufen dasselbe und
/// können nicht auseinanderlaufen.
final class NaeherungTests: XCTestCase {
    func testAufDerWerksfirmwareAendertSichNichts() {
        var o = Meldungsoptionen(text: "Hallo")
        o.schrift = "Tiny5"
        o.groesse = 16
        XCTAssertEqual(o.naeherung(fuer: .tc002), o)
    }

    func testAufNGStehtImmerDieselbeSchriftDa() {
        var o = Meldungsoptionen(text: "Hallo")
        o.schrift = "Tiny5"
        o.groesse = 16
        let genaehert = o.naeherung(fuer: .awtrixNG)
        XCTAssertEqual(genaehert.schrift, "Silkscreen")
        XCTAssertEqual(genaehert.groesse, 8)
    }

    /// Die Näherung greift nur an Schrift und Größe: Farbe, Text,
    /// Ausrichtung und alles Übrige sind Regler, die auch NG kennt.
    func testDieUebrigenReglerBleibenStehen() {
        var o = Meldungsoptionen(text: "Hallo")
        o.farbe = "#FF0000"
        o.waagrecht = .mittig
        o.iconLaeuftMit = true
        o.abstand = 3
        let genaehert = o.naeherung(fuer: .awtrixNG)
        XCTAssertEqual(genaehert.text, "Hallo")
        XCTAssertEqual(genaehert.farbe, "#FF0000")
        XCTAssertEqual(genaehert.waagrecht, .mittig)
        XCTAssertTrue(genaehert.iconLaeuftMit)
        XCTAssertEqual(genaehert.abstand, 3)
    }

    /// Die genäherte Größe muss auf der abgesegneten Liste ihrer Schrift
    /// stehen — sonst rastert die Vorschau in einer Größe, die niemand
    /// durchgesehen hat.
    func testDieGenaeherteGroesseIstAbgesegnet() {
        let genaehert = Meldungsoptionen(text: "x").naeherung(fuer: .awtrixNG)
        let erlaubt = Pixelgroessen.abgesegnet[genaehert.schrift] ?? []
        XCTAssertTrue(erlaubt.contains(genaehert.groesse),
                      "\(genaehert.groesse) steht nicht auf der Liste von \(genaehert.schrift).")
    }
}
