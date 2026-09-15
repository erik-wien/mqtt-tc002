import XCTest
@testable import TC002Core

/// **Das Maß, auf dem gerastert wird** — bis hierher überall die beiden
/// Konstanten aus `Pixelfeld`, also immer die Werksfirmware.
///
/// `Uhr.anzeigemass` kennt die Zahlen längst; was fehlte, war ein Wert, der
/// sie durch `Meldungsbau` und `Textraster` trägt. Zwei lose Zahlen wären
/// dafür das Falsche: Wer eine davon an einer Stelle vergisst, rastert 52
/// breit in ein Feld, das 32 ist — ein Fehler, der genau wie der aussieht, den
/// dieser Durchgang behebt.
final class AnzeigemassTests: XCTestCase {
    func testDieVorgabeIstDieWerksfirmware() {
        XCTAssertEqual(Anzeigemass.tc002.breite, 52)
        XCTAssertEqual(Anzeigemass.tc002.hoehe, 16)
    }

    func testEineWerksfirmwareUhrGibtDasStandardmass() {
        let uhr = Uhr(name: "Küche", host: "uhr.example", typ: .tc002)
        XCTAssertEqual(Anzeigemass.fuer(uhr), .tc002)
    }

    /// `typ` ist `Optional`, und `nil` heißt Werksfirmware — dieselbe Lesart
    /// wie überall sonst.
    func testOhneGattungGiltDieWerksfirmware() {
        let uhr = Uhr(name: "Alt", host: "uhr.example", typ: nil)
        XCTAssertEqual(Anzeigemass.fuer(uhr), .tc002)
    }

    /// Solange „Abfragen" nicht gelaufen ist, gilt die dokumentierte Vorgabe
    /// `32 × 1` — als Vorgabe, nicht als Tatsache über dieses Gerät.
    func testEineNGUhrOhneGemeldeteBreiteIst32x8() {
        let uhr = Uhr(name: "Flur", host: "ng.example", typ: .awtrixNG)
        XCTAssertEqual(Anzeigemass.fuer(uhr), Anzeigemass(breite: 32, hoehe: 8))
    }

    /// Wer zwei Panels hängen hat, soll auch zwei sehen.
    func testEineNGUhrNimmtDieGemeldeteBreite() {
        let uhr = Uhr(name: "Flur", host: "ng.example", typ: .awtrixNG, panelbreite: 64)
        XCTAssertEqual(Anzeigemass.fuer(uhr), Anzeigemass(breite: 64, hoehe: 8))
    }

    /// Die Höhe ist bei NG fest acht — auch wenn jemand eine krumme Breite
    /// gemeldet bekommt.
    func testDieHoeheVonNGBleibtAchtZeilen() {
        let uhr = Uhr(name: "Flur", host: "ng.example", typ: .awtrixNG, panelbreite: 128)
        XCTAssertEqual(Anzeigemass.fuer(uhr).hoehe, 8)
    }

    /// Ein Icon sitzt senkrecht mittig — auf acht Zeilen liegt ein 8×8 damit
    /// auf Zeile 0 und füllt sie ganz, statt wie auf sechzehn Zeilen auf
    /// Zeile 4 zu sitzen.
    func testDasIconSitztSenkrechtMittig() {
        XCTAssertEqual(Anzeigemass.tc002.iconY(kante: 8), 4)
        XCTAssertEqual(Anzeigemass.tc002.iconY(kante: 16), 0)
        XCTAssertEqual(Anzeigemass(breite: 32, hoehe: 8).iconY(kante: 8), 0)
    }
}
