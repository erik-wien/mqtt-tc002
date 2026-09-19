import XCTest
import SwiftUI
@testable import TC002Ansichten

/// Die Hilfetexte tragen Markdown (`**fett**`, `` `Bezeichner` ``). `Text` mit
/// einem gewöhnlichen `String` wertet es nicht aus — dann stünden die Sternchen
/// und Akzente wörtlich in der Hilfe. `HilfeabschnittView.ausgezeichnet` geht
/// deshalb über `AttributedString`.
final class HilfeauszeichnungTests: XCTestCase {
    private func sichtbar(_ text: String) -> String {
        String(HilfeabschnittView.ausgezeichnet(text).characters)
    }

    func testFettUndBezeichnerVerschwindenAusDemSichtbarenText() {
        XCTAssertEqual(sichtbar("Was ein Broker **nicht** kann"),
                       "Was ein Broker nicht kann")
        XCTAssertEqual(sichtbar("siehe `AppZustand.abfragen`"),
                       "siehe AppZustand.abfragen")
    }

    /// Ein Text ohne Auszeichnung bleibt Zeichen für Zeichen derselbe — auch
    /// die typografischen Anführungszeichen und Gedankenstriche.
    func testTextOhneAuszeichnungBleibtUnveraendert() {
        let satz = "„Sichern und prüfen“ schreibt Adresse, Port — und fragt den Broker."
        XCTAssertEqual(sichtbar(satz), satz)
    }

    /// Kein Hilfebaustein darf am Ende noch ein `**` zeigen. Geprüft wird über
    /// die tatsächlich gebauten Abschnitte beider Oberflächen, nicht über den
    /// Quelltext: Was der Leser sieht, entsteht erst hier.
    func testKeinSichtbarerHilfetextZeigtNochSternchen() {
        for baustein in Self.alleBausteine {
            for text in Self.texte(aus: baustein) {
                XCTAssertFalse(sichtbar(text).contains("**"),
                               "Auszeichnung bleibt sichtbar: \(text)")
                XCTAssertFalse(sichtbar(text).contains("`"),
                               "Auszeichnung bleibt sichtbar: \(text)")
            }
        }
    }

    /// Die Gliederung läuft über Überschriften, nicht über eine Tabelle.
    ///
    /// `Hilfebaustein.tabelle` zeichnete ein `Grid`, dessen erste Spalte ihre
    /// ideale Breite nahm und nicht umbrach: Am Telefon stand der Abschnitt
    /// dadurch links und rechts über dem Rand, ohne dass sich waagrecht rollen
    /// ließ. Geprüft wird am Quelltext, denn hier gibt es nichts zu rechnen —
    /// und nur dort fällt auf, wenn jemand den Baustein wieder einführt.
    func testKeinHilfeabschnittBautEineTabelle() throws {
        for pfad in ["Sources/TC002Ansichten/Hilfe.swift",
                     "Sources/TC002Ansichten/HilfeInhalt.swift",
                     "Sources/TC002Ansichten/HilfeView.swift",
                     "Sources/TC002iOS/HilfeiOS.swift"] {
            let quelle = try Self.ohneKommentare(pfad)
            XCTAssertFalse(quelle.contains("tabelle"),
                           "\(pfad) baut wieder eine Tabelle statt einer Gliederung.")
            XCTAssertFalse(quelle.contains("Grid("),
                           "\(pfad) setzt die Hilfe wieder in ein Grid.")
        }
    }

    /// Die zweite Ebene wird auch benutzt: Wo vorher eine Tabelle zwei Spalten
    /// hatte, steht heute der Begriff als `untertitel` über seiner Erklärung.
    func testDieZweiteEbeneTraegtDieFruererenTabellenbegriffe() {
        let untertitel = Self.alleBausteine.compactMap { baustein -> String? in
            if case .untertitel(let t) = baustein { return t }
            return nil
        }
        for begriff in ["HTTP", "MQTT"] {
            XCTAssertTrue(untertitel.contains(begriff),
                          "„\(begriff)“ steht nicht mehr als eigene Ebene in der Gliederung.")
        }
    }

    private static func ohneKommentare(_ pfad: String) throws -> String {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let roh = try String(contentsOf: wurzel.appendingPathComponent(pfad), encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    private static func texte(aus baustein: Hilfebaustein) -> [String] {
        switch baustein {
        case .ueberschrift(let t), .untertitel(let t), .absatz(let t): return [t]
        case .punkte(let p): return p
        case .abbildung: return []
        }
    }

    /// Alle Bausteine, die `HilfeInhalt` bereitstellt — über Spiegelung
    /// gesammelt, damit eine neue Konstante nicht vergessen werden kann.
    private static let alleBausteine: [Hilfebaustein] = [
        HilfeInhalt.wasEsTut, HilfeInhalt.betriebsart, HilfeInhalt.geraeteart,
        HilfeInhalt.brokerNurFuerMqtt, HilfeInhalt.themen,
        HilfeInhalt.startOhneEinrichtung, HilfeInhalt.uhrHinzufuegen,
        HilfeInhalt.uhrEntfernen, HilfeInhalt.aufDerUhr, HilfeInhalt.brokerSichern,
        HilfeInhalt.uhrAbfragen, HilfeInhalt.brokerFelderLeer,
        HilfeInhalt.brokerKennwort, HilfeInhalt.brokerPruefen,
        HilfeInhalt.virtuelleUhr, HilfeInhalt.wolkenabgleich,
        HilfeInhalt.fuenfPlaetze, HilfeInhalt.blockwissenAnfang,
        HilfeInhalt.blockwissenSchluss, HilfeInhalt.wegeRegel,
        HilfeInhalt.blockierendeAnzeige, HilfeInhalt.blockLoeschen,
        HilfeInhalt.dauer, HilfeInhalt.zeichen, HilfeInhalt.schriftart,
        HilfeInhalt.groesse, HilfeInhalt.microFuenf, HilfeInhalt.fettUndGross,
        HilfeInhalt.randUndAbstand, HilfeInhalt.breiteUndAusrichtung,
        HilfeInhalt.iconImLauf, HilfeInhalt.verlaufHerkunft,
        HilfeInhalt.verlaufEntstehung, HilfeInhalt.verlaufLoeschen,
        HilfeInhalt.protokollListe, HilfeInhalt.protokollLeeren,
        HilfeInhalt.fehlerStille, HilfeInhalt.fehlerWelche,
        HilfeInhalt.fehlerReihe,
    ].flatMap { $0 }
}
