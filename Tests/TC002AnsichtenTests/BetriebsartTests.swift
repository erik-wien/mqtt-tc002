import XCTest

/// Die Wahl der Betriebsart muss es auf beiden Oberflächen geben: Sie
/// entscheidet, ob eine Uhr überhaupt beschickt werden kann — eine HTTP-Uhr
/// braucht kein Präfix und keinen Broker, eine MQTT-Uhr beides. Gäbe es die
/// Wahl nur am Mac, käme jemand am Telefon aus einer Einrichtung nicht mehr
/// heraus, die dort nicht trägt.
///
/// Gleicher Weg wie `PlattformwegeTests` und `KnopfstilTests`: nachsehen im
/// Quelltext, weil sich eine Oberfläche ohne Gerät nicht anders prüfen
/// lässt.
final class BetriebsartTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelle(_ pfad: String) throws -> String {
        try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
    }

    /// Die Wahl steht auf der Seite der Uhr (`Uhrseite`) und schreibt sich
    /// über `betriebsartGeaendert` zurück. Ohne diesen Aufruf bliebe ein
    /// Abonnement stehen, das es nach dem Wechsel nicht mehr geben darf.
    ///
    /// Vorher stand die Wahl zweimal da, einmal je Einstellungsansicht, und
    /// dieser Test sah in beiden nach. Seit die Einstellungen nach Themen
    /// gegliedert sind, gibt es die Uhrseite nur einmal — geprüft wird
    /// deshalb sie, und der Test darunter, dass beide Oberflächen sie
    /// erreichen.
    func testDieUhrseiteBietetDieWahlAn() throws {
        let pfad = "Sources/TC002Ansichten/Uhrseite.swift"
        let text = try quelle(pfad)
        XCTAssertTrue(text.contains("Picker(\"Betriebsart\""),
                      "\(pfad) bietet die Betriebsart nicht zur Wahl an")
        XCTAssertTrue(text.contains("Betriebsart.http") && text.contains("Betriebsart.mqtt"),
                      "\(pfad) bietet nicht beide Fälle an")
        XCTAssertTrue(text.contains("zustand.betriebsartGeaendert("),
                      "\(pfad) schreibt die Wahl, ohne sie wirksam zu machen")
    }

    /// Dieselbe Zusicherung wie vorher, nur eine Ebene höher: Gäbe es den Weg
    /// zur Uhrseite nur am Schreibtisch, käme jemand am Telefon aus einer
    /// Einrichtung nicht mehr heraus, die dort nicht trägt.
    func testBeideOberflaechenFuehrenAufDieUhrseite() throws {
        XCTAssertTrue(try quelle("Sources/TC002Ansichten/Uhrenliste.swift")
                        .contains("Uhrseite(zustand: zustand"),
                      "die Uhrenliste führt nicht mehr auf die Seite der Uhr")
        XCTAssertTrue(try quelle("Sources/TC002Ansichten/Einstellungsthema.swift")
                        .contains("Uhrenliste(zustand: zustand"),
                      "das Thema „Uhren“ zeigt nicht mehr die Uhrenliste")
        for pfad in ["Sources/TC002Ansichten/VerbindungView.swift",
                     "Sources/TC002iOS/VerbindungiOS.swift"] {
            XCTAssertTrue(try quelle(pfad).contains("Einstellungsinhalt(zustand: zustand"),
                          "\(pfad) baut seine Themen nicht mehr aus den gemeinsamen Bausteinen")
        }
    }

    /// Zwei Sätze in der Hilfe müssen zusammenpassen: „alle Nachrichten
    /// laufen über den MQTT-Broker" gilt seit dem HTTP-Betrieb nicht mehr und
    /// darf nicht mehr dastehen. Dass ein Broker HTTP-Sendungen nicht
    /// nebenbei mitliest, ist dagegen gemessen (45 Sekunden gehorcht, eine
    /// einzige Nachricht) und muss dastehen — sonst richtet sich jemand
    /// einen Broker ein, der ihm nichts bringt.
    func testDieHilfeBehauptetDenBrokerWederAlsUmwegNochAlsOhr() throws {
        let text = try quelle("Sources/TC002Ansichten/HilfeInhalt.swift")

        XCTAssertFalse(text.contains("Es tut das nicht direkt: alle Nachrichten laufen über den MQTT-Broker"),
                       "die Hilfe behauptet noch, jede Sendung gehe über den Broker")
        XCTAssertTrue(text.contains("Die Uhr reicht ihre HTTP-Vorgänge nicht über MQTT weiter."),
                      "die Hilfe sagt nicht, dass ein Broker HTTP-Sendungen nicht mithört")
        XCTAssertTrue(text.contains("Steht die Uhr auf HTTP, gibt es kein Mitlesen"),
                      "die Hilfe sagt nicht, dass die Blöcke im HTTP-Betrieb nichts mitlesen")
    }

    /// Der Unterschied ist ein Tausch, und beide Hälften davon stehen
    /// beieinander: was HTTP kann und was MQTT kann. Nur eine Hälfte zu
    /// nennen wäre eine Empfehlung, keine Auskunft.
    ///
    /// Wo der Satz steht, ist der Oberfläche überlassen; geprüft wird deshalb
    /// der Wortlaut, nicht seine Bauform. Er steht jetzt einmal, unter der
    /// Segmentwahl auf der Uhrseite — dort, wo die Wahl getroffen wird.
    func testDerHinweisNenntBeideHaelftenDesTauschs() throws {
        let pfad = "Sources/TC002Ansichten/Uhrseite.swift"
        XCTAssertTrue(try quelle(pfad).contains("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken."),
                      "\(pfad) nennt den Tausch nicht oder nur halb")
    }
}
