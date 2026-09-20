import XCTest

/// Ein belegter Slotblock traegt kein Dauerzeichen mehr.
///
/// Das rote ⊗ an jedem belegten Block stand immer da, ueberlappte das Motiv
/// und sah aus wie der Wackelmodus des Home-Bildschirms — ein Zustand, den man
/// absichtlich betritt, nicht die Ruhelage. Am Finger lag seine Trefferflaeche
/// zudem auf dem Block, der selbst ein Knopf ist.
///
/// Stattdessen: das Kontextmenue des Blocks (`slotmenue`, `Slotblock.swift`),
/// auf beiden Oberflaechen dasselbe. Am Schreibtisch erscheint das ⊗
/// zusaetzlich beim Ueberfahren mit dem Zeiger — der eine begruendete
/// Unterschied, Zeiger gegen Finger; am iPad meldet `onHover` nichts, dort
/// bleibt es damit von selbst weg.
///
/// Gleicher Weg wie `KnopfstilTests`: nachsehen im Quelltext. Der Uebersetzer
/// hat dazu nichts zu sagen, und ein Zeichen, das immer da ist, sieht nur, wer
/// die App startet.
final class SlotmenueTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Es gibt nur **eine** Blockreihe: `Slotleiste`. Alle drei Sendeflächen
    /// benutzen sie, statt jede ihre eigene zu bauen.
    ///
    /// Vorher stand sie dreimal da und lief auseinander — einmal mit sechs
    /// Punkten Abstand, einmal mit acht, einmal ohne das ⊗, und der Editor
    /// blieb bei einem Umbau ganz zurück. Der Auftraggeber: *„verwende bitte
    /// möglichst das selbe objekt."*
    ///
    /// Mutation: in einer der drei Ansichten wieder eine eigene Reihe aus
    /// `Slotblock` bauen — baut, übersetzt, und zwei Blockreihen derselben App
    /// verhalten sich wieder verschieden.
    func testAlleDreiBenutzenDieselbeLeiste() throws {
        for datei in ["Sources/TC002iOS/SendeniOS.swift",
                      "Sources/TC002Ansichten/SendenView.swift",
                      "Sources/TC002Ansichten/EditorBereichView.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("Slotleiste(zustand: zustand, gewaehlt:"),
                          "\(datei) benutzt nicht mehr die gemeinsame Slotleiste")
            XCTAssertFalse(text.contains("Slotblock("),
                           "\(datei) baut seine Blockreihe wieder selbst")
        }
    }

    /// Menü und ⊗ hängen an der Leiste, und dort nur einmal.
    func testDieLeisteTraegtMenueUndZeichen() throws {
        let text = try quelltext("Sources/TC002Ansichten/Slotleiste.swift")
        XCTAssertTrue(text.contains(".slotmenue(belegt:"),
                      "der Slotblock hat sein Kontextmenü verloren — am Finger gibt es dann "
                      + "keinen Weg mehr zum Löschen")
        XCTAssertTrue(text.contains("if ueberfahren == i {"),
                      "das ⊗ hängt nicht mehr am Überfahren — dann steht es dauerhaft über dem "
                      + "Block und verdeckt sein Motiv")
        XCTAssertTrue(text.contains(".onHover { drueber in ueberfahren = drueber ? i : nil }"),
                      "niemand setzt `ueberfahren` mehr — das ⊗ erschiene nie")
    }

    /// Am Telefon gibt es das Zeichen nicht: Dort meldet `onHover` nichts,
    /// die gemeinsame Leiste zeigt es deshalb von selbst nie. Was hier geprüft
    /// wird, ist, dass es die Ansicht nicht doch wieder selbst anhängt.
    func testDasTelefonHatKeinLoeschzeichenAmBlock() throws {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        XCTAssertFalse(text.contains("xmark.circle.fill"),
                       "am Telefon steht wieder ein rotes ⊗ an den Blöcken")
        XCTAssertFalse(text.contains("MeldungLoeschenKnopf"),
                       "der Löschknopf am Block ist am Telefon wieder da")
    }

    /// Ein Block, auf dem etwas Fremdes liegt, traegt ein Zeichen und kein
    /// Wort.
    ///
    /// „belegt“ in einem Kaestchen von 44 Punkten Hoehe stand als Etikett
    /// dort, wo sonst Bilder stehen. Fuer die Sprachausgabe bleibt es dabei —
    /// das Wort geht aus dem Bild, nicht aus der Auskunft.
    func testDerUnbekannteBlockZeigtEinZeichenUndKeinWort() throws {
        let text = try quelltext("Sources/TC002Ansichten/Slotblock.swift")
        XCTAssertFalse(text.contains("Text(lok(\"belegt\"))"),
                       "auf dem unbekannten Block steht wieder das Wort „belegt“")
        XCTAssertTrue(text.contains("Image(systemName: \"questionmark\")"),
                      "der unbekannte Block trägt kein Fragezeichen mehr — dann ist er von einem "
                      + "leeren Block nicht mehr zu unterscheiden")
        XCTAssertTrue(text.contains("lokf(\"Slot %d, unbekannt\", platz)"),
                      "die Sprachausgabe unterscheidet „belegt“ und „unbekannt“ nicht mehr")
        XCTAssertTrue(text.contains("help(lok(\"belegt — von einer anderen Quelle\"))"),
                      "am Zeiger sagt nichts mehr, was das Fragezeichen bedeutet")
    }

    /// Ein leerer Platz bekommt kein Menue: Er hat nichts zu loeschen und
    /// nichts zu zeigen, und ein leeres Menue ist eine Geste, die nichts tut.
    func testEinLeererBlockBekommtKeinMenue() throws {
        let text = try quelltext("Sources/TC002Ansichten/Slotblock.swift")
        XCTAssertTrue(text.contains("if belegt {"),
                      "`slotmenue` hängt sich wieder an jeden Block, auch an leere")
        XCTAssertTrue(text.contains("Label(\"Löschen\", systemImage: \"trash\")"),
                      "„Löschen“ steht nicht mehr im Menü des Blocks")
        XCTAssertTrue(text.contains("Label(\"Zeigen\", systemImage: \"eye\")"),
                      "„Zeigen“ steht nicht mehr im Menü des Blocks")
    }
}
