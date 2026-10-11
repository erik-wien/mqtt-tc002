import XCTest
@testable import TC002Core

/// Passt die Tinte nach `Pixelgroessen.wirksam` in das Feld, muss sie auch ganz
/// darin landen: Das Raster darf nichts abschneiden, was die Messung auf dem
/// hohen Feld mitgezählt hat.
final class TinteImFeldTests: XCTestCase {
    private func belegteZeilen(_ f: Pixelfeld) -> [Int] {
        (0..<f.hoehe).filter { y in (0..<f.breite).contains { f.farbe(x: $0, y: y) != nil } }
    }

    private func bild(_ f: Pixelfeld) -> String {
        (0..<f.hoehe).map { y in
            String((0..<min(f.breite, 12)).map { f.farbe(x: $0, y: y) != nil ? "#" : "." })
        }.joined(separator: "\n")
    }

    func testKeineTinteGehtAufDemFeldVerloren() {
        let masse = [Anzeigemass(breite: 32, hoehe: 8), Anzeigemass(breite: 52, hoehe: 16)]
        for schrift in Pixelgroessen.abgesegnet.keys.sorted() {
            for groesse in Pixelgroessen.angeboten(fuer: schrift) {
                for senkrecht in SendenVAusrichtung.allCases {
                    for text in ["ÄH", "HÜ", "ÖH"] {
                        for mass in masse {
                            let o = Meldungsoptionen(text: text, schrift: schrift, groesse: groesse,
                                                     senkrecht: senkrecht, rand: 1)
                            let wirksam = o.wirksameGroesse(fuer: mass)
                            let verfuegbar = senkrecht == .mittig ? mass.hoehe : mass.hoehe - o.rand
                            guard Pixelgroessen.zeilenbedarf(schrift: schrift, groesse: wirksam, fett: false)
                                    <= verfuegbar else { continue }
                            let hoch = Textraster.rasterPuffer(text, schrift: schrift, groesse: wirksam,
                                                               fett: false, farbe: "#FFFFFF", luecke: o.abstand,
                                                               mass: Anzeigemass(breite: mass.breite, hoehe: 64))
                            let echt = Meldungsbau.feld(o, mitIcon: false, mass: mass)
                            XCTAssertEqual(belegteZeilen(echt).count, belegteZeilen(hoch).count,
                                           "\(schrift) \(groesse) (wirksam \(wirksam)) \(senkrecht) \(text) auf \(mass.breite)×\(mass.hoehe)")
                        }
                    }
                }
            }
        }
    }

    /// Der gemeldete Fall: „HÜ“, Silkscreen 16, mittig, 32 × 8. Der Bezug „ÄH“
    /// maß 8 Zeilen und liess 9 px zu; die Punkte des Ü sitzen aber eine Zeile
    /// höher als die des Ä, „HÜ“ brauchte 9 Zeilen, und die unterste ging verloren.
    func testHUmlautSilkscreenMittigAufAchtZeilen() {
        let o = Meldungsoptionen(text: "HÜ", schrift: "Silkscreen", groesse: 16, senkrecht: .mittig)
        let mass = Anzeigemass(breite: 32, hoehe: 8)
        XCTAssertEqual(o.wirksameGroesse(fuer: mass), 8)
        let f = Meldungsbau.feld(o, mitIcon: false, mass: mass)
        print("HÜ Silkscreen 8, mittig, 32×8:\n" + bild(f))
        XCTAssertEqual(belegteZeilen(f).count,
                       belegteZeilen(Textraster.rasterPuffer("HÜ", schrift: "Silkscreen", groesse: 8,
                                                             fett: false, farbe: "#FFFFFF", luecke: 1,
                                                             mass: Anzeigemass(breite: 32, hoehe: 64))).count)
    }
}
