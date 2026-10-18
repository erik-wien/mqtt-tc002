import Foundation
import XCTest
@testable import TC002Core

/// Die Rechnung hinter dem Rahmenbau: Breite, Versatz und Platz des Icons.
final class MeldungsbauTests: XCTestCase {

    /// Ein leerer Iconordner: Es zaehlt die Rechnung, nicht der Inhalt eines
    /// Icons.
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    /// Die Entscheidung „passt oder läuft" hängt an der Breite des stehenden
    /// Falls, nicht an „Icon mitscrollen".
    func testPasstHaengtNichtAmMitlaufendenIcon() {
        var o = Meldungsoptionen(text: "Ziemlich langer Text")
        o.iconLaeuftMit = false
        let ohne = Meldungsbau.passt(o, icon: .voll())
        o.iconLaeuftMit = true
        XCTAssertEqual(Meldungsbau.passt(o, icon: .voll()), ohne)
    }

    /// Mit einem vollen 8×8-Icon und einem Pixel Abstand beginnt die Textflaeche
    /// bei Spalte 9 und ist 43 breit; das Icon sitzt senkrecht mittig auf `y: 4`.
    /// Mittig steht der ganze Block aus Icon, Abstand und Text in der Mitte.
    func testIconVersatz() {
        var o = Meldungsoptionen(text: "Hallo")
        XCTAssertEqual(Meldungsbau.flaecheX(icon: .voll()), 9)
        XCTAssertEqual(Meldungsbau.flaecheBreite(icon: .voll()), 43)
        XCTAssertEqual(Meldungsbau.flaecheX(icon: nil), 0)
        XCTAssertEqual(Meldungsbau.flaecheBreite(icon: nil), 52)
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: .voll()), 9)
        o.waagrecht = .mittig
        let block = (52 - 9 - Meldungsbau.breite(o)) / 2
        XCTAssertEqual(Meldungsbau.iconX(o, icon: .voll()), block)
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: .voll()), block + 9)
    }

    /// Mehr Rand verlangen, als Platz ist, darf nicht abschneiden: `r` wird auf
    /// die Haelfte des freien Raums geklammert. Fuer „Hallo" liegt die Tinte
    /// bei Zeile 2 bis 7 (sechs Pixel hoch), also `max(0, (16-6)/2) = 5`; bei
    /// Rand 8 klemmt `r` also auf 5 statt 8, und `versatzY` — das noch den
    /// Tintenbeginn `-2` einrechnet — landet bei `-2 + 5 = 3`. Ohne die
    /// Klammerung waere es `-2 + 8 = 6` geworden. Die Schnappschuesse loesen
    /// das nie aus, weil dort jeder Rand unter der Grenze liegt.
    func testRandWirdGeklammert() {
        var o = Meldungsoptionen(text: "Hallo")
        o.senkrecht = .oben
        o.rand = 3
        let mitDrei = Meldungsbau.versatzY(o)
        o.rand = 8
        XCTAssertEqual(Meldungsbau.versatzY(o), 3,
                       "acht Rand wird bei sechs Pixeln Tinte auf fuenf geklammert, versatzY = -2 + 5 = 3")
        XCTAssertLessThan(mitDrei, Meldungsbau.versatzY(o))
    }

    /// Die `rawValue`-Zeichenketten sind ein Dateiformat: `@AppStorage` legt sie
    /// so ab. Wer sie ändert, macht die Einstellungen einer laufenden
    /// Installation unlesbar — die Ansicht fiele wortlos auf ihre Vorgabe
    /// zurück, und niemand wüsste warum.
    func testAufzaehlungenBehaltenIhreZeichenketten() {
        XCTAssertEqual(SendeWeg.allCases.map(\.rawValue), ["pixel", "text"])
        XCTAssertEqual(SendenHAusrichtung.allCases.map(\.rawValue), ["links", "mittig", "rechts"])
        XCTAssertEqual(SendenVAusrichtung.allCases.map(\.rawValue), ["oben", "mittig", "unten"])
        XCTAssertEqual(Lauftempo.allCases.map(\.rawValue), ["langsam", "mittel", "schnell"])
    }

    /// Der Name des Meldungsplatzes ist der Bezeichner der Anzeige auf dem
    /// Gerät. Ändert er sich, findet die App ihre alten Anzeigen nicht mehr und
    /// kann sie auch nicht mehr löschen.
    func testMeldungsplatzNamenBleiben() {
        XCTAssertEqual(Meldungsplatz.anzahl, 5)
        XCTAssertEqual((1...5).map(Meldungsplatz.name(fuer:)),
                       ["meldung1", "meldung2", "meldung3", "meldung4", "meldung5"])
    }

    /// Die Kehrseite von `name(fuer:)` — gebraucht vom Kommandozeilenwerkzeug,
    /// um zu erkennen, ob ein frei gewaehlter Anzeigename (`--name`) zufaellig
    /// einen der fuenf festen Plaetze trifft.
    func testMeldungsplatzPlatzFuerNameSpiegeltName() {
        XCTAssertEqual((1...5).map { Meldungsplatz.platz(fuerName: Meldungsplatz.name(fuer: $0)) },
                       [1, 2, 3, 4, 5])
        XCTAssertNil(Meldungsplatz.platz(fuerName: "cli"))
        XCTAssertNil(Meldungsplatz.platz(fuerName: "meldung6"))
    }

    // MARK: - 16×16-Icons

    /// Legt ein Icon der Groesse `kante` in einem frischen Ordner an.
    private func sammlungMitIcon(kante: Int) throws -> (Iconsammlung, Icon) {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let sammlung = Iconsammlung(ordner: ordner, kante: kante)
        var pixel = [String?](repeating: nil, count: kante * kante)
        pixel[0] = "#FF0000"
        pixel[kante * kante - 1] = "#00FF66"
        let icon = try sammlung.sichern(nummer: "pruef", name: "Prüf", pixel: pixel)
        return (sammlung, icon)
    }

    /// Ein 16×16 belegt siebzehn Spalten statt neun und sitzt auf Zeile 0 —
    /// es fuellt die volle Hoehe, statt wie ein 8×8 mittig zu schwimmen.
    func testSechzehnerIconBelegtSiebzehnSpaltenUndSitztOben() {
        XCTAssertEqual(Meldungsbau.iconY(kante: 8), 4)
        XCTAssertEqual(Meldungsbau.iconY(kante: 16), 0)
        XCTAssertEqual(Meldungsbau.flaecheX(icon: .voll(kante: 16)), 17)
        XCTAssertEqual(Meldungsbau.flaecheBreite(icon: .voll(kante: 16)), 35)

        var o = Meldungsoptionen(text: "Hallo")
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: .voll(kante: 16)), 17)
    }

    /// Ein volles Icon ohne Kante ist ein 8×8.
    func testVollesIconOhneKanteIstEinAchter() {
        var o = Meldungsoptionen(text: "Hallo")
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.flaecheX(icon: .voll()), Meldungsbau.flaecheX(icon: .voll(kante: 8)))
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: .voll()), 9)
    }

    /// Das Lauf-GIF backt ein 16×16 ueber die volle Hoehe ein — die oberste
    /// Zeile der ersten Spalte ist bei einem 8×8 leer und bei einem 16×16 nicht.
    func testLaufschriftBaecktDasSechzehnerIconUeberDieVolleHoeheEin() {
        let kante = 16
        let bild = [String?](repeating: "#FF0000", count: kante * kante)
        let o = Meldungsoptionen(text: "Ein ziemlich langer Text, der nicht passt")
        let bilder = Meldungsbau.laufschriftBilder(o, iconBilder: [bild], icon: .voll(kante: kante))
        guard let erstes = bilder.first else { return XCTFail("keine Einzelbilder") }
        XCTAssertEqual(erstes.pixel[0], "#FF0000", "Zeile 0, Spalte 0 gehört dem 16×16-Icon")
        XCTAssertEqual(erstes.pixel[15 * Pixelfeld.breiteStandard], "#FF0000", "und Zeile 15 auch")

        let achter = [String?](repeating: "#FF0000", count: 64)
        let mitAchter = Meldungsbau.laufschriftBilder(o, iconBilder: [achter], icon: .voll())
        XCTAssertNil(mitAchter.first?.pixel[0] ?? nil, "ein 8×8 lässt Zeile 0 frei")
    }

}
