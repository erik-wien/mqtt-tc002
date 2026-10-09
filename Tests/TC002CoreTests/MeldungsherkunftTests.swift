import Foundation
import XCTest
@testable import TC002Core

/// Dass jeder gebaute Rahmen seine Herkunft mitfuehrt — und was daran haengt.
///
/// Ohne sie kann eine AWTRIX NG mit einer Sendung nichts anfangen: Sie setzt
/// den Text selbst und braucht die Regler, nicht die Pixel. Genau daran
/// erkennt `Anzeigen` auch den Gegenfall — ein gemaltes Bild kommt nicht
/// durch `Meldungsbau.rahmen` und hat deshalb keine.
final class MeldungsherkunftTests: XCTestCase {

    /// Ein leerer Iconordner: Hier zaehlt die Buchfuehrung, nicht der Inhalt
    /// eines Icons.
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    /// Der Rahmen traegt die Regler, aus denen er entstand.
    func testEinStehenderRahmenTraegtSeineRegler() throws {
        var o = Meldungsoptionen(text: "hi")
        o.farbe = "#FF0000"
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        XCTAssertEqual(rahmen.herkunft?.optionen, o)
    }

    /// Auch ein langer Text ist ein Rahmen mit Herkunft und ohne Pixel: Die
    /// Uhr laesst ihn selbst durchlaufen.
    func testAuchEinLangerTextTraegtSeineRegler() throws {
        let o = Meldungsoptionen(text: "ein ziemlich langer Text, der bestimmt nicht mehr hineinpasst")
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        XCTAssertTrue(rahmen.draw.isEmpty)
        XCTAssertTrue(rahmen.bilder.isEmpty)
        XCTAssertEqual(rahmen.herkunft?.optionen.text, o.text)
    }

    /// Ein von Hand gebauter Rahmen — gemalt, aus der Bildersammlung — hat
    /// keine. Das ist kein Versaeumnis, sondern die Auskunft.
    func testEinSelbstGebauterRahmenHatKeineHerkunft() {
        XCTAssertNil(Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")]).herkunft)
    }
}

/// Die Masse einer Uhr.
final class UhrMasseTests: XCTestCase {

    /// Ohne Auskunft der Uhr gilt 52 × 16; sobald „Abfragen" gelaufen ist,
    /// zaehlt, was sie meldet.
    func testDieAnzeigemasseKommenVonDerUhr() {
        let neu = Uhr(name: "a", host: "h")
        XCTAssertEqual(neu.anzeigemass.breite, 52)
        XCTAssertEqual(neu.anzeigemass.hoehe, 16)

        let gemeldet = Uhr(name: "c", host: "h", panelbreite: 64, panelhoehe: 8)
        XCTAssertEqual(gemeldet.anzeigemass.breite, 64)
        XCTAssertEqual(gemeldet.anzeigemass.hoehe, 8)
    }
}
