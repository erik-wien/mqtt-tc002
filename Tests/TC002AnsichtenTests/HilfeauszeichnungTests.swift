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

    private static func texte(aus baustein: Hilfebaustein) -> [String] {
        switch baustein {
        case .ueberschrift(let t), .absatz(let t): return [t]
        case .punkte(let p): return p
        case .tabelle(let z): return z.flatMap { [$0.0, $0.1] }
        case .abbildung: return []
        }
    }

    /// Alle Bausteine, die `HilfeInhalt` bereitstellt — über Spiegelung
    /// gesammelt, damit eine neue Konstante nicht vergessen werden kann.
    private static let alleBausteine: [Hilfebaustein] = [
        HilfeInhalt.wasEsTut, HilfeInhalt.betriebsart, HilfeInhalt.geraeteart,
        HilfeInhalt.brokerNurFuerMqtt, HilfeInhalt.startOhneEinrichtung,
        HilfeInhalt.uhrAbfragen, HilfeInhalt.brokerFelderLeer,
        HilfeInhalt.brokerKennwort, HilfeInhalt.brokerPruefen,
        HilfeInhalt.virtuelleUhr, HilfeInhalt.wolkenabgleich,
        HilfeInhalt.fuenfPlaetze, HilfeInhalt.blockwissenAnfang,
        HilfeInhalt.blockwissenSchluss, HilfeInhalt.wegeRegel,
        HilfeInhalt.blockierendeAnzeige, HilfeInhalt.papierkorb,
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
