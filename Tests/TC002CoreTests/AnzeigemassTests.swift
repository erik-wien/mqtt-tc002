import XCTest
@testable import TC002Core

/// Das Maß, auf dem gerastert wird.
///
/// `Uhr.anzeigemass` kennt die Zahlen; was fehlte, war ein Wert, der sie durch
/// `Meldungsbau` und `Textraster` trägt. Zwei lose Zahlen wären dafür das
/// Falsche: Wer eine davon an einer Stelle vergisst, rastert 52 breit in ein
/// Feld, das anders ist.
final class AnzeigemassTests: XCTestCase {
    func testDieVorgabeIst52x16() {
        XCTAssertEqual(Anzeigemass.vorgabe.breite, 52)
        XCTAssertEqual(Anzeigemass.vorgabe.hoehe, 16)
    }

    /// Solange „Abfragen" nicht gelaufen ist, gilt die Vorgabe — als Vorgabe,
    /// nicht als Tatsache über dieses Gerät.
    func testEineUhrOhneGemeldetesMassHatDieVorgabe() {
        let uhr = Uhr(name: "Küche", host: "uhr.example")
        XCTAssertEqual(Anzeigemass.fuer(uhr), .vorgabe)
    }

    /// Was die Uhr meldet, zählt: Breite und Höhe kommen aus `capabilities`.
    func testEineUhrNimmtDasGemeldeteMass() {
        let uhr = Uhr(name: "Flur", host: "ng.example", panelbreite: 64, panelhoehe: 8)
        XCTAssertEqual(Anzeigemass.fuer(uhr), Anzeigemass(breite: 64, hoehe: 8))
    }

    /// Ein Icon sitzt senkrecht mittig — auf sechzehn Zeilen liegt ein 8×8
    /// auf Zeile 4, ein 16×16 auf Zeile 0; auf acht Zeilen füllt das 8×8 sie.
    func testDasIconSitztSenkrechtMittig() {
        XCTAssertEqual(Anzeigemass.vorgabe.iconY(kante: 8), 4)
        XCTAssertEqual(Anzeigemass.vorgabe.iconY(kante: 16), 0)
        XCTAssertEqual(Anzeigemass(breite: 32, hoehe: 8).iconY(kante: 8), 0)
    }
}
