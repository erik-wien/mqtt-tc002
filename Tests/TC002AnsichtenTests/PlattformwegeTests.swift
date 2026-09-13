import XCTest
@testable import TC002Ansichten

/// Die Wege, die auf dem iPad stumm scheitern würden.
///
/// `openWindow(id:)` gibt es unter iOS (ab 16), `Window` als Szene nicht.
/// Ein Aufruf auf eine Szene, die es dort nicht gibt, **übersetzt** und tut zur
/// Laufzeit nichts — kein Fehler, keine Meldung, ein Knopf, der schweigt. Genau
/// deshalb prüft hier niemand den Übersetzer, sondern den Quelltext: Der
/// Übersetzer hat zu dieser Frage nichts zu sagen.
final class PlattformwegeTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TC002AnsichtenTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // Repo

    /// Quelltext ohne Kommentare — sonst zählt jeder Satz mit, der `openWindow`
    /// nur erwähnt (und dieses Repo erwähnt es an mehreren Stellen).
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

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    /// Fenster gibt es nur am Mac — also darf sie auch nur die Mac-App öffnen.
    /// Alles, was das iPad mitübersetzt (`TC002Ansichten`, `TC002iOS`), muss
    /// ohne auskommen.
    func testFensterAufrufeNurInDerMacApp() throws {
        for ordner in ["Sources/TC002Ansichten", "Sources/TC002iOS",
                       "Sources/TC002Modell", "Sources/TC002Core"] {
            for datei in swiftDateien(unter: ordner) {
                let text = try quelltext(datei)
                XCTAssertFalse(text.contains("openWindow"),
                               "\(datei) ruft openWindow — unter iOS übersetzt das und tut nichts")
                XCTAssertFalse(text.range(of: #"\bWindow\("#, options: .regularExpression) != nil,
                               "\(datei) baut eine Window-Szene — die gibt es unter iOS nicht")
            }
        }
    }

    /// Beide Geräte müssen dieselben vier Dokumente anbieten. Der Mac benennt
    /// seine Szenen über `Nebenfenster`, das iPad zählt `allCases` auf; hier
    /// wird nachgesehen, dass am Mac auch wirklich für jeden Fall eine Szene
    /// steht. Ohne diesen Test fiele eine gelöschte `Window`-Szene erst
    /// jemandem auf, der den Menüeintrag drückt.
    ///
    /// Möglich ist der Abgleich, weil `Nebenfenster.id` bewusst so heißt wie
    /// sein Fall.
    func testJederFallHatEineMacSzene() throws {
        let text = try quelltext("Sources/TC002App/App.swift")
        var gefunden: Set<String> = []
        var rest = Substring(text)
        while let start = rest.range(of: "Window(Nebenfenster.") {
            rest = rest[start.upperBound...]
            guard let punkt = rest.firstIndex(of: ".") else { break }
            gefunden.insert(String(rest[rest.startIndex..<punkt]))
        }
        XCTAssertEqual(gefunden, Set(Nebenfenster.allCases.map(\.id)),
                       "Mac-Szenen und Nebenfenster-Fälle laufen auseinander")
    }

    /// Das eigentliche Ziel dieses Schritts: Auf dem iPad steht der
    /// Schreibtisch, auf dem iPhone `SendeniOS` — entschieden am Idiom, nicht
    /// an der Größenklasse (die wechselt in der geteilten Ansicht).
    func testDasIPadBekommtDenSchreibtisch() throws {
        let text = try quelltext("Sources/TC002iOS/App.swift")
        XCTAssertTrue(text.contains("userInterfaceIdiom == .pad"),
                      "die Verzweigung hängt nicht mehr am Idiom")
        XCTAssertTrue(text.contains("SchreibtischView(zustand:"),
                      "das iPad bekommt die Schreibtischoberfläche nicht mehr")
        XCTAssertTrue(text.contains("SendeniOS(zustand:"),
                      "dem iPhone ist seine eigene Oberfläche abhanden gekommen")
    }
}
