import XCTest
@testable import TC002Core

/// **Rastern auf acht Zeilen.** `Meldungsbau` und `Textraster` rechneten bis
/// zum 15.09.2026 fest mit 52 × 16; das Maß ist jetzt ein Parameter mit genau
/// dieser Vorgabe.
///
/// Was hier geprüft wird, ist beides: dass ein anderes Maß wirklich
/// durchschlägt — **und** dass die Vorgabe hält. Der zweite Teil steht
/// größtenteils gar nicht in dieser Datei, sondern in der unveränderten
/// übrigen Testreihe: Jeder Aufruf dort kommt ohne `mass:` aus, und wäre die
/// Vorgabe falsch, bräche er.
final class MeldungsbauMassTests: XCTestCase {
    private let ng = Anzeigemass(breite: 32, hoehe: 8)

    // MARK: - Das Feld

    func testDasFeldHatDieGroesseDesMasses() {
        let o = Meldungsoptionen(text: "Hi")
        let feld = Meldungsbau.feld(o, mitIcon: false, mass: ng)
        XCTAssertEqual(feld.breite, 32)
        XCTAssertEqual(feld.hoehe, 8)
    }

    func testOhneMassBleibtEs52x16() {
        let feld = Meldungsbau.feld(Meldungsoptionen(text: "Hi"), mitIcon: false)
        XCTAssertEqual(feld.breite, 52)
        XCTAssertEqual(feld.hoehe, 16)
    }

    // MARK: - Ob der Text passt

    /// Derselbe Text, zwei Maße, zwei Antworten: Was auf 52 Spalten steht,
    /// läuft auf 32 durch. Ein gerechneter Vergleich statt zweier fester
    /// Erwartungen — die Breite hängt an der Schrift, und die soll sich hier
    /// ändern dürfen, ohne dass dieser Test zur Lüge wird.
    func testWasAufDieWerksfirmwarePasstMussNichtAufNGPassen() {
        let o = Meldungsoptionen(text: "Hallo Welt")
        let breite = Meldungsbau.breite(o)
        XCTAssertGreaterThan(breite, 32, "Der Beispieltext ist für diese Probe zu kurz.")
        XCTAssertLessThanOrEqual(breite, 52, "Der Beispieltext ist für diese Probe zu lang.")

        XCTAssertTrue(Meldungsbau.passt(o, mitIcon: false))
        XCTAssertFalse(Meldungsbau.passt(o, mitIcon: false, mass: ng))
    }

    // MARK: - Die Laufschrift

    /// Jedes Einzelbild ist so groß wie die Anzeige — sonst spielte auf NG
    /// überhaupt nichts ab (§8 der NG-Referenz: Ein GIF, dessen erstes Bild
    /// höher ist als die Leinwand, bleibt stumm).
    func testDieEinzelbilderDerLaufschriftHabenDieGroesseDesMasses() {
        let o = Meldungsoptionen(text: "Ein längerer Text, der laufen muss")
        let bilder = Meldungsbau.laufschriftBilder(o, iconBilder: [], mass: ng)
        XCTAssertFalse(bilder.isEmpty)
        for bild in bilder {
            XCTAssertEqual(bild.pixel.count, 32 * 8)
        }
    }

    /// Die senkrechte Mitte ist die Mitte des Maßes, nicht die von sechzehn
    /// Zeilen. Auf acht Zeilen mit einer 8-px-Schrift bleibt dafür kein Platz
    /// übrig — der Versatz darf das Bild nicht nach unten aus der Anzeige
    /// schieben.
    func testDerSenkrechteVersatzBleibtImFeld() {
        var o = Meldungsoptionen(text: "Hi")
        o.senkrecht = .mittig
        let feld = Meldungsbau.feld(o, mitIcon: false, mass: ng)
        let tinte = (0..<feld.hoehe).filter { zeile in
            (0..<feld.breite).contains { feld.farbe(x: $0, y: zeile) != nil }
        }
        XCTAssertFalse(tinte.isEmpty, "Auf acht Zeilen ist vom Text nichts übriggeblieben.")
    }
}
