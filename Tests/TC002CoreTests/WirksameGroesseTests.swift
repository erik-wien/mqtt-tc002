import XCTest
@testable import TC002Core

final class WirksameGroesseTests: XCTestCase {
    private let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    private let tc001 = Anzeigemass(breite: 32, hoehe: 8)

    private func optionen(_ groesse: Double, schrift: String = "Silkscreen", rand: Int = 1,
                          senkrecht: SendenVAusrichtung = .oben) -> Meldungsoptionen {
        Meldungsoptionen(text: "Grüß", schrift: schrift, groesse: groesse,
                         senkrecht: senkrecht, rand: rand)
    }

    func testSechzehnPixelAufDerTC001WerdenAcht() {
        XCTAssertEqual(optionen(16).wirksameGroesse(fuer: tc001), 8)
        XCTAssertEqual(optionen(16).verkleinert(fuer: tc001), 8)
    }

    func testSechzehnPixelBleibenAufDerTC002() {
        XCTAssertEqual(optionen(16).wirksameGroesse(fuer: tc002), 16)
        XCTAssertNil(optionen(16).verkleinert(fuer: tc002))
    }

    func testAchtPixelBleibenAufDerTC001() {
        XCTAssertEqual(optionen(8).wirksameGroesse(fuer: tc001), 8)
    }

    func testRandWirdBeiObenUndUntenBeruecksichtigt() {
        // Mit Rand 0 hat die TC001 acht Zeilen, mit Rand 3 nur fuenf.
        let ohne = optionen(8, rand: 0).wirksameGroesse(fuer: tc001)
        let mit = optionen(8, rand: 3).wirksameGroesse(fuer: tc001)
        XCTAssertGreaterThanOrEqual(ohne, mit)
        XCTAssertLessThan(mit, 8)
        // Mittig zaehlt der Rand nicht.
        XCTAssertEqual(optionen(8, rand: 3, senkrecht: .mittig).wirksameGroesse(fuer: tc001), ohne)
        XCTAssertEqual(optionen(8, rand: 3, senkrecht: .unten).wirksameGroesse(fuer: tc001), mit)
    }

    func testSchriftOhneAchtPixelStufe() {
        // Micro 5 bietet 10, 14, 16: passt keine, bleibt es bei der kleinsten Stufe.
        XCTAssertEqual(Pixelgroessen.angeboten(fuer: "Micro 5"), [10, 14, 16])
        XCTAssertEqual(optionen(16, schrift: "Micro 5").wirksameGroesse(fuer: tc001), 10)
        // Eine Groesse unterhalb aller Stufen bleibt, wie sie ist.
        XCTAssertEqual(optionen(6, schrift: "Micro 5").wirksameGroesse(fuer: tc001), 6)
    }

    func testSchriftDerUhrHatKeineGroesse() {
        var o = optionen(16)
        o.weg = .text
        XCTAssertEqual(o.wirksameGroesse(fuer: tc001), 16)
        XCTAssertNil(o.verkleinerungshinweis(uhr: "Flur", mass: tc001))
    }

    func testHinweis() throws {
        let h = try XCTUnwrap(optionen(16).verkleinerungshinweis(uhr: "Flur", mass: tc001))
        XCTAssertTrue(h.contains("Flur") && h.contains("8") && h.contains("16"))
        XCTAssertNil(optionen(16).verkleinerungshinweis(uhr: "Flur", mass: tc002))
    }

    /// Ganzer Weg: derselbe Satz an zwei Uhren verschiedener Hoehe. Die kleine
    /// bekommt dasselbe Bild wie bei gewaehlten 8 px, die grosse das ihre; das
    /// Slotgedaechtnis merkt 16 px, aber die Pruefsumme der verkleinerten
    /// Rasterung.
    func testZweiUhrenUnterschiedlicherGroesse() throws {
        let o = optionen(16)
        let sammlung = Iconsammlung(ordner: URL(fileURLWithPath: NSTemporaryDirectory()))
        let gross = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: tc002)
        let klein = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: tc001)
        let kleinMitAcht = try Meldungsbau.rahmen(optionen(8), icon: nil, sammlung: sammlung, mass: tc001)
        XCTAssertEqual(klein.pixel?.hoehe, 8)
        XCTAssertEqual(gross.pixel?.hoehe, 16)
        XCTAssertEqual(klein.pixel?.bilder.first?.pixel, kleinMitAcht.pixel?.bilder.first?.pixel)
        // Auf der TC001 steht Tinte in mehr als den zwei Mittelzeilen von frueher.
        let zeilen = (0..<8).filter { y in
            (0..<32).contains { x in klein.pixel?.bilder.first?.pixel[y * 32 + x] != nil }
        }
        XCTAssertGreaterThan(zeilen.count, 3)

        let ordner = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let g = Slotgedaechtnis(ordner: ordner)
        let uhrKlein = UUID(), uhrGross = UUID()
        g.merken(o, icon: nil, iconKante: 8, fuer: uhrKlein, platz: 1, mass: tc001)
        g.merken(o, icon: nil, iconKante: 8, fuer: uhrGross, platz: 1, mass: tc002)
        let sk = try XCTUnwrap(g.gemerkt(fuer: uhrKlein, platz: 1))
        let sg = try XCTUnwrap(g.gemerkt(fuer: uhrGross, platz: 1))
        XCTAssertEqual(sk.groesse, 16)
        XCTAssertEqual(sg.groesse, 16)
        let gesendet = Meldungsbau.feld(optionen(8), mitIcon: false, mass: tc001).punkteRoh
        XCTAssertEqual(sk.pruefsumme, Slotgedaechtnis.pruefsumme(pixel: gesendet))
        XCTAssertNotEqual(sk.pruefsumme, sg.pruefsumme)
    }
}
