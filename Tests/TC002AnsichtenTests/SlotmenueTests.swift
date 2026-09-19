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

    /// Beide Sendeansichten haengen dasselbe Menue an ihren Block.
    func testBeideBloeckeTragenDasselbeMenue() throws {
        for datei in ["Sources/TC002iOS/SendeniOS.swift",
                      "Sources/TC002Ansichten/SendenView.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains(".slotmenue(belegt:"),
                          "\(datei): der Slotblock hat sein Kontextmenü verloren — am Finger gibt "
                          + "es dann keinen Weg mehr zum Löschen")
        }
    }

    /// Am Telefon gibt es das Zeichen ueberhaupt nicht mehr.
    func testDasTelefonHatKeinLoeschzeichenAmBlock() throws {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        XCTAssertFalse(text.contains("xmark.circle.fill"),
                       "am Telefon steht wieder ein rotes ⊗ an den Blöcken")
        XCTAssertFalse(text.contains("MeldungLoeschenKnopf"),
                       "der Löschknopf am Block ist am Telefon wieder da")
    }

    /// Am Schreibtisch bleibt es, aber nur unter dem Zeiger.
    func testAmSchreibtischErscheintDasZeichenNurUnterDemZeiger() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(text.contains("ueberfahrenerPlatz == i"),
                      "das ⊗ hängt nicht mehr am Überfahren — dann steht es wieder dauerhaft da, "
                      + "und am iPad, wo es kein Überfahren gibt, ebenfalls")
        XCTAssertTrue(text.contains(".onHover { drueber in ueberfahrenerPlatz = drueber ? i : nil }"),
                      "niemand setzt `ueberfahrenerPlatz` mehr — das ⊗ erschiene nie")
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
