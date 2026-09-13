import XCTest
@testable import TC002Ansichten

/// Die Kantenlaenge der Malflaeche. Am iPad gemeldet: zu klein, um mit dem
/// Finger ein bestimmtes Pixel zu treffen — diese Rechnung ist die Antwort
/// darauf, und diese Tests halten fest, dass sie es bleibt.
final class MalrasterTests: XCTestCase {

    /// Der Icon-Editor hatte feste 28 Punkte, die Malflaeche hoechstens 14.
    /// Beide Zahlen sind jetzt ueberschritten, wo Platz ist.
    func testEinIconRasterWirdDeutlichGroesserAlsFrueher() {
        let kante = Malraster.kante(breite: 8, hoehe: 8, verfuegbareBreite: 600)
        XCTAssertGreaterThan(kante, 28, "kleiner als vorher wäre keine Verbesserung")
        XCTAssertEqual(kante, Malraster.kanteMax, "bei so viel Platz zählt nur die Obergrenze")
    }

    /// Die Flaeche fuellt die Spalte, die sie hat — und laeuft nicht rechts
    /// hinaus, wenn die Spalte schmal ist.
    func testDieFlaechePasstInDieVerfuegbareBreite() {
        for breite in [8, 16, 52] {
            for platz in [200.0, 400.0, 900.0] {
                let kante = Malraster.kante(breite: breite, hoehe: 16, verfuegbareBreite: platz)
                XCTAssertLessThanOrEqual(Double(breite) * kante, max(platz, Double(breite) * Malraster.kanteMin),
                                         "\(breite) Spalten bei \(platz) Punkten")
            }
        }
    }

    /// Und sie wird nicht so hoch, dass Bildleiste, Namensfeld und Sendezeile
    /// aus dem Fenster rutschen.
    func testDieFlaecheBleibtUnterDerHoehengrenze() {
        for (breite, hoehe) in [(8, 8), (16, 16), (52, 16)] {
            let kante = Malraster.kante(breite: breite, hoehe: hoehe, verfuegbareBreite: 4000)
            XCTAssertLessThanOrEqual(Double(hoehe) * kante, Malraster.hoeheMax,
                                     "\(breite)×\(hoehe)")
        }
    }

    /// Ein 16×16 bei voller Kante waere 704 Punkte hoch — die Hoehengrenze
    /// greift dort, nicht erst bei der Breite.
    func testBeiSechzehnZeilenEntscheidetDieHoehe() {
        let kante = Malraster.kante(breite: 16, hoehe: 16, verfuegbareBreite: 4000)
        XCTAssertLessThan(kante, Malraster.kanteMax)
        XCTAssertEqual(kante, (Malraster.hoeheMax / 16).rounded(.down))
    }

    /// Unter sechs Punkten ist ein Kaestchen nicht mehr zu treffen — dann
    /// laeuft die Flaeche lieber hinaus, als unbedienbar zu werden.
    func testUnterSechsPunktenWirdNichtGegangen() {
        XCTAssertEqual(Malraster.kante(breite: 52, hoehe: 16, verfuegbareBreite: 40),
                       Malraster.kanteMin)
    }

    /// Beim allerersten Aufbau ist noch nichts gemessen. Dann soll die Flaeche
    /// gross beginnen und beim ersten Messen schrumpfen — nicht umgekehrt mit
    /// sechs Punkten anfangen und sichtbar aufspringen.
    func testOhneMessungWirdNichtKlein() {
        XCTAssertEqual(Malraster.kante(breite: 8, hoehe: 8, verfuegbareBreite: 0),
                       Malraster.kanteMax)
    }

    /// Ganze Punkte: ein halber Punkt Kante ergibt bei 52 Spalten sichtbar
    /// ungleich breite Kaestchen.
    func testDieKanteIstEineGanzeZahl() {
        let kante = Malraster.kante(breite: 52, hoehe: 16, verfuegbareBreite: 700)
        XCTAssertEqual(kante, kante.rounded(.down))
    }
}
