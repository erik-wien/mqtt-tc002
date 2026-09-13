import XCTest
@testable import TC002Ansichten

/// Die Kantenlaenge der Malflaeche. Zwei Beschwerden stecken darin, und sie
/// ziehen in verschiedene Richtungen: am iPad zu kleine Kaestchen, um mit dem
/// Finger ein Pixel zu treffen — und eine Flaeche, die sich nahm, was sie
/// wollte, und dabei ueber ihre Spalte hinauszeichnete.
final class MalrasterTests: XCTestCase {

    /// Der Icon-Editor hatte feste 28 Punkte, die Malflaeche hoechstens 14.
    /// Beide Zahlen sind jetzt ueberschritten, wo Platz ist.
    func testEinIconRasterWirdDeutlichGroesserAlsFrueher() {
        let kante = Malraster.kante(breite: 8, hoehe: 8,
                                    verfuegbareBreite: 600, verfuegbareHoehe: 600)
        XCTAssertGreaterThan(kante, 28, "kleiner als vorher wäre keine Verbesserung")
        XCTAssertEqual(kante, Malraster.kanteMax, "bei so viel Platz zählt nur die Obergrenze")
    }

    /// Der gemeldete Fehler: Die Flaeche war breiter als ihre Spalte und
    /// schob alles hinaus. Sie darf die gemessene Breite nie ueberschreiten,
    /// solange die kleinste Kantenlaenge das zulaesst.
    func testDieFlaechePasstInDieVerfuegbareBreite() {
        for breite in [8, 16, 52] {
            for platz in [200.0, 400.0, 900.0] {
                let kante = Malraster.kante(breite: breite, hoehe: 16,
                                            verfuegbareBreite: platz, verfuegbareHoehe: 900)
                XCTAssertLessThanOrEqual(Double(breite) * kante,
                                         max(platz, Double(breite) * Malraster.kanteMin),
                                         "\(breite) Spalten bei \(platz) Punkten")
            }
        }
    }

    /// Dasselbe fuer die Hoehe — und das ist neu: Bis zum 13.09.2026 ging sie
    /// gar nicht ein, sondern eine feste Obergrenze von 420 Punkten.
    func testDieFlaechePasstInDieVerfuegbareHoehe() {
        for (breite, hoehe) in [(8, 8), (16, 16), (52, 16)] {
            for platz in [120.0, 300.0, 700.0] {
                let kante = Malraster.kante(breite: breite, hoehe: hoehe,
                                            verfuegbareBreite: 4000, verfuegbareHoehe: platz)
                XCTAssertLessThanOrEqual(Double(hoehe) * kante,
                                         max(platz, Double(hoehe) * Malraster.kanteMin),
                                         "\(breite)×\(hoehe) bei \(platz) Punkten Höhe")
            }
        }
    }

    /// Bei den quadratischen Groessen entscheidet die Hoehe, bei 52 Spalten
    /// die Breite — genau darum bekommen 8×8 und 16×16 den Platz, um den es
    /// ging, und 52×16 bleibt klein, ohne hinauszulaufen.
    func testWelchesMassDenEngpassStellt() {
        // iPad quer, Leinwandspalte 804 × 866.
        XCTAssertEqual(Malraster.kante(breite: 8, hoehe: 8,
                                       verfuegbareBreite: 804, verfuegbareHoehe: 866),
                       Malraster.kanteMax, "8×8 ist dort nur noch von der Obergrenze begrenzt")
        XCTAssertEqual(Malraster.kante(breite: 52, hoehe: 16,
                                       verfuegbareBreite: 804, verfuegbareHoehe: 866),
                       (804.0 / 52).rounded(.down), "bei 52 Spalten entscheidet die Breite")
        XCTAssertEqual(Malraster.kante(breite: 16, hoehe: 16,
                                       verfuegbareBreite: 804, verfuegbareHoehe: 400),
                       (400.0 / 16).rounded(.down), "bei knapper Höhe entscheidet sie")
    }

    /// Unter sechs Punkten ist ein Kaestchen nicht mehr zu treffen — dann
    /// rollt die Leinwand lieber waagrecht, als unbedienbar zu werden.
    func testUnterSechsPunktenWirdNichtGegangen() {
        XCTAssertEqual(Malraster.kante(breite: 52, hoehe: 16,
                                       verfuegbareBreite: 40, verfuegbareHoehe: 200),
                       Malraster.kanteMin)
    }

    /// Beim allerersten Aufbau ist noch nichts gemessen. Dann soll die Flaeche
    /// gross beginnen und beim ersten Messen schrumpfen — nicht umgekehrt mit
    /// sechs Punkten anfangen und sichtbar aufspringen.
    func testOhneMessungWirdNichtKlein() {
        XCTAssertEqual(Malraster.kante(breite: 8, hoehe: 8,
                                       verfuegbareBreite: 0, verfuegbareHoehe: 0),
                       Malraster.kanteMax)
    }

    /// Und ein einzeln fehlendes Mass darf das andere nicht mitreissen.
    func testEinFehlendesMassLaesstDasAndereGelten() {
        XCTAssertEqual(Malraster.kante(breite: 52, hoehe: 16,
                                       verfuegbareBreite: 520, verfuegbareHoehe: 0),
                       10)
        XCTAssertEqual(Malraster.kante(breite: 52, hoehe: 16,
                                       verfuegbareBreite: 0, verfuegbareHoehe: 160),
                       10)
    }

    /// Ganze Punkte: ein halber Punkt Kante ergibt bei 52 Spalten sichtbar
    /// ungleich breite Kaestchen.
    func testDieKanteIstEineGanzeZahl() {
        let kante = Malraster.kante(breite: 52, hoehe: 16,
                                    verfuegbareBreite: 700, verfuegbareHoehe: 333)
        XCTAssertEqual(kante, kante.rounded(.down))
    }
}
