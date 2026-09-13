import Foundation
import XCTest
@testable import TC002Core

/// Nagelt den Rahmenbau fest. Diese Tests sind nicht dazu da, eine Absicht zu
/// beschreiben — sie halten fest, was die App **heute** erzeugt, damit das
/// Verschieben in den Kern nichts verändert. Weicht ein Schnappschuss ab, ist
/// das ein Fehler der Verschiebung und keine Verbesserung.
final class MeldungsbauTests: XCTestCase {

    /// Ein leerer Iconordner: Die Schnappschüsse sollen die Rechnung festhalten,
    /// nicht den Inhalt eines Icons.
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    private var ordner: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Schnappschuesse")
    }

    /// Vergleicht gegen die abgelegte Fassung. Fehlt sie, wird sie geschrieben
    /// und der Test schlägt einmal fehl — damit niemand versehentlich einen
    /// Schnappschuss einführt, ohne ihn angesehen zu haben.
    private func vergleiche(_ json: String, mit name: String,
                            datei: StaticString = #filePath, zeile: UInt = #line) throws {
        let pfad = ordner.appendingPathComponent("\(name).json")
        guard let erwartet = try? String(contentsOf: pfad, encoding: .utf8) else {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try json.write(to: pfad, atomically: true, encoding: .utf8)
            XCTFail("Schnappschuss \(name) neu angelegt — bitte ansehen und einchecken.",
                    file: datei, line: zeile)
            return
        }
        XCTAssertEqual(json, erwartet, "Schnappschuss \(name) weicht ab", file: datei, line: zeile)
    }

    private func json(_ o: Meldungsoptionen) throws -> String {
        try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung()).alsJSON()
    }

    func testWaagrechteAusrichtung() throws {
        for (name, wert) in [("links", SendenHAusrichtung.links),
                             ("mittig", .mittig), ("rechts", .rechts)] {
            var o = Meldungsoptionen(text: "Hallo")
            o.waagrecht = wert
            try vergleiche(json(o), mit: "waagrecht-\(name)")
        }
    }

    func testSenkrechteAusrichtungUndRand() throws {
        for (name, wert) in [("oben", SendenVAusrichtung.oben),
                             ("mittig", .mittig), ("unten", .unten)] {
            for rand in [0, 1, 3] {
                var o = Meldungsoptionen(text: "Hallo")
                o.senkrecht = wert
                o.rand = rand
                try vergleiche(json(o), mit: "senkrecht-\(name)-rand\(rand)")
            }
        }
    }

    func testAbstand() throws {
        for abstand in [0, 1, 3] {
            var o = Meldungsoptionen(text: "Hallo")
            o.abstand = abstand
            try vergleiche(json(o), mit: "abstand-\(abstand)")
        }
    }

    func testDauerUndGrossbuchstaben() throws {
        var o = Meldungsoptionen(text: "Grüße")
        o.dauer = 12
        o.grossbuchstaben = true
        try vergleiche(json(o), mit: "dauer-gross")
    }

    func testGeraeteschrift() throws {
        for (name, wert) in [("links", SendenHAusrichtung.links),
                             ("mittig", .mittig), ("rechts", .rechts)] {
            var o = Meldungsoptionen(text: "Hallo")
            o.weg = .text
            o.waagrecht = wert
            o.senkrecht = .unten
            try vergleiche(json(o), mit: "geraeteschrift-\(name)")
        }
    }

    func testLaufschrift() throws {
        var o = Meldungsoptionen(text: "Dieser Text ist viel zu lang für zweiundfünfzig Pixel")
        o.tempo = .mittel
        try vergleiche(json(o), mit: "laufschrift-mittel")
    }

    /// Die Entscheidung „passt oder läuft" hängt an der Breite des stehenden
    /// Falls, nicht an „Icon mitscrollen".
    func testPasstHaengtNichtAmMitlaufendenIcon() {
        var o = Meldungsoptionen(text: "Ziemlich langer Text")
        o.iconLaeuftMit = false
        let ohne = Meldungsbau.passt(o, mitIcon: true)
        o.iconLaeuftMit = true
        XCTAssertEqual(Meldungsbau.passt(o, mitIcon: true), ohne)
    }

    /// Mit Icon beginnt die Textflaeche bei Spalte 10 und ist 42 breit. Diese
    /// Zahlen stehen in keinem Schnappschuss, weil die dort alle ohne Icon
    /// gebaut werden — und das Icon sitzt senkrecht mittig auf `y: 4`, was
    /// ebenso von Hand gesetzt wurde.
    func testIconVersatz() {
        var o = Meldungsoptionen(text: "Hallo")
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: true), 10)
        XCTAssertEqual(Meldungsbau.flaecheBreite(mitIcon: true), 42)
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: false), 0)
        XCTAssertEqual(Meldungsbau.flaecheBreite(mitIcon: false), 52)
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true), 10)
        o.waagrecht = .mittig
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true), 22)
        XCTAssertEqual(Meldungsbau.textblock(o, mitIcon: true).flaeche, [10, 0, 42, 16])
        XCTAssertEqual(Meldungsbau.textblock(o, mitIcon: false).flaeche, [0, 0, 52, 16])
    }

    /// Mehr Rand verlangen, als Platz ist, darf nicht abschneiden: Der Wert
    /// wird auf die Haelfte des freien Raums geklammert. Die Schnappschuesse
    /// loesen das nie aus, weil dort jeder Rand unter der Grenze liegt.
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

    /// Ein 16×16 belegt achtzehn Spalten statt zehn und sitzt auf Zeile 0 —
    /// es fuellt die volle Hoehe, statt wie ein 8×8 mittig zu schwimmen.
    func testSechzehnerIconBelegtAchtzehnSpaltenUndSitztOben() {
        XCTAssertEqual(Meldungsbau.iconY(kante: 8), 4)
        XCTAssertEqual(Meldungsbau.iconY(kante: 16), 0)
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: true, iconKante: 16), 18)
        XCTAssertEqual(Meldungsbau.flaecheBreite(mitIcon: true, iconKante: 16), 34)

        var o = Meldungsoptionen(text: "Hallo")
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true, iconKante: 16), 18)
        XCTAssertEqual(Meldungsbau.textblock(o, mitIcon: true, iconKante: 16).flaeche, [18, 0, 34, 16])
    }

    /// Ohne ausdrueckliche Kante rechnet alles wie vorher — jede Stelle, die
    /// nur „Icon ja/nein" weiss, meint ein 8×8.
    func testOhneAngabeBleibtEsBeimAchterIcon() {
        var o = Meldungsoptionen(text: "Hallo")
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: true), Meldungsbau.flaecheX(mitIcon: true, iconKante: 8))
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true), 10)
    }

    /// Der fertige Rahmen nimmt die Groesse vom Icon selbst: ein 16×16 landet
    /// auf `position` [0,0], ein 8×8 weiterhin auf [0,4].
    func testRahmenSetztDasIconNachSeinerGroesse() throws {
        let (achter, iconA) = try sammlungMitIcon(kante: 8)
        let (sechzehner, iconS) = try sammlungMitIcon(kante: 16)
        XCTAssertEqual(iconA.kante, 8)
        XCTAssertEqual(iconS.kante, 16)

        let o = Meldungsoptionen(text: "Hi")
        let mitAchter = try Meldungsbau.rahmen(o, icon: iconA, sammlung: achter).alsJSON()
        let mitSechzehner = try Meldungsbau.rahmen(o, icon: iconS, sammlung: sechzehner).alsJSON()
        XCTAssertTrue(mitAchter.contains(#""position":[0,4]"#), mitAchter)
        XCTAssertTrue(mitSechzehner.contains(#""position":[0,0]"#), mitSechzehner)
    }

    /// Der Text beginnt hinter dem Icon — bei einem 16×16 also ab Spalte 18.
    func testTextBeginntHinterDemSechzehnerIcon() throws {
        let (sechzehner, icon) = try sammlungMitIcon(kante: 16)
        var o = Meldungsoptionen(text: "Hi")
        o.waagrecht = .links
        let rahmen = try Meldungsbau.rahmen(o, icon: icon, sammlung: sechzehner)
        let ersteSpalte = rahmen.draw.map(\.x).min()
        XCTAssertEqual(ersteSpalte, 18, "der Text darf nicht unter dem Icon anfangen")
    }

    /// Das Lauf-GIF backt ein 16×16 ueber die volle Hoehe ein — die oberste
    /// Zeile der ersten Spalte ist bei einem 8×8 leer und bei einem 16×16 nicht.
    func testLaufschriftBaecktDasSechzehnerIconUeberDieVolleHoeheEin() {
        let kante = 16
        let bild = [String?](repeating: "#FF0000", count: kante * kante)
        let o = Meldungsoptionen(text: "Ein ziemlich langer Text, der nicht passt")
        let bilder = Meldungsbau.laufschriftBilder(o, iconBilder: [bild], iconKante: kante)
        guard let erstes = bilder.first else { return XCTFail("keine Einzelbilder") }
        XCTAssertEqual(erstes.pixel[0], "#FF0000", "Zeile 0, Spalte 0 gehört dem 16×16-Icon")
        XCTAssertEqual(erstes.pixel[15 * Pixelfeld.breiteStandard], "#FF0000", "und Zeile 15 auch")

        let achter = [String?](repeating: "#FF0000", count: 64)
        let mitAchter = Meldungsbau.laufschriftBilder(o, iconBilder: [achter])
        XCTAssertNil(mitAchter.first?.pixel[0] ?? nil, "ein 8×8 lässt Zeile 0 frei")
    }

}
