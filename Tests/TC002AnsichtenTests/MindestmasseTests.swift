import XCTest

/// Die Fensterforderungen der Mac-Fassung sind **gemessen** — an einem Fenster,
/// das man ziehen kann. Auf dem iPad gibt es nichts zu ziehen: Kein Gerät
/// erreicht hochkant 1140 Punkte (das größte hat 1024), und in geteilter
/// Ansicht bleiben schnell 678 oder 320 übrig. Eine Mindestbreite, die dort
/// nicht aufgeht, verschwindet nicht — sie schneidet ab, lautlos.
///
/// Deshalb stehen die Maße hinter `#if os(macOS)`, und deshalb hält dieser Test
/// fest, dass sie dort bleiben. Der Übersetzer merkt davon nichts: Beide
/// Fassungen übersetzen.
final class MindestmasseTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private enum Zweig { case nurMac, nichtMac, unbekannt }

    /// Zeilen einer Datei samt der Angabe, ob sie in einem
    /// `#if os(macOS)`-Zweig liegen. Kommentare fallen weg — sonst zählte
    /// jeder Satz mit, der ein Maß bloß erwähnt.
    private func zeilenMitZweig(_ pfad: String) throws -> [(text: String, nurMac: Bool)] {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        var stapel: [Zweig] = []
        var ergebnis: [(String, Bool)] = []
        for zeile in roh.split(separator: "\n", omittingEmptySubsequences: false) {
            let nackt = zeile.trimmingCharacters(in: .whitespaces)
            if nackt.hasPrefix("#if ") {
                if nackt == "#if os(macOS)" { stapel.append(.nurMac) }
                else if nackt == "#if !os(macOS)" { stapel.append(.nichtMac) }
                else { stapel.append(.unbekannt) }
                continue
            }
            if nackt == "#else" {
                if let letzter = stapel.last {
                    stapel[stapel.count - 1] = letzter == .nurMac ? .nichtMac
                        : (letzter == .nichtMac ? .nurMac : .unbekannt)
                }
                continue
            }
            if nackt == "#endif" {
                if !stapel.isEmpty { stapel.removeLast() }
                continue
            }
            let ohneKommentar: String
            if let strich = zeile.range(of: "//") {
                ohneKommentar = String(zeile[zeile.startIndex..<strich.lowerBound])
            } else {
                ohneKommentar = String(zeile)
            }
            ergebnis.append((ohneKommentar, stapel.contains(.nurMac)))
        }
        return ergebnis
    }

    /// Jedes dieser Maße ist eine Forderung an das **Fenster**, nicht an einen
    /// Inhalt: Wird sie nicht erfüllt, schneidet SwiftUI ab, statt umzubrechen.
    /// Am Mac ist sie gemessen und abgenommen; überall sonst muss sie fehlen.
    func testFensterforderungenStehenNurUnterMacOS() throws {
        let faelle: [(datei: String, mass: String)] = [
            ("Sources/TC002Ansichten/SchreibtischView.swift", "minWidth: 1140"),
            ("Sources/TC002Ansichten/GeraeteReferenzView.swift", "minWidth: 880"),
            ("Sources/TC002Ansichten/GeraeteReferenzView.swift", "minWidth: 480"),
            ("Sources/TC002Ansichten/HilfeView.swift", "minWidth: 760"),
            ("Sources/TC002Ansichten/SchriftprobeView.swift", "minWidth: 560"),
            ("Sources/TC002Ansichten/SendenView.swift", "minWidth: 420"),
            ("Sources/TC002Ansichten/SendenView.swift", "inspectorColumnWidth(340)"),
        ]
        for fall in faelle {
            let zeilen = try zeilenMitZweig(fall.datei)
            let treffer = zeilen.filter { $0.text.contains(fall.mass) }
            // Ohne diese Zusicherung ginge der Test auch dann durch, wenn das
            // Mass umbenannt oder geloescht waere — und der Mac verloere sein
            // gemessenes Verhalten, ohne dass es jemandem auffiele.
            XCTAssertEqual(treffer.count, 1,
                           "\(fall.mass) kommt in \(fall.datei) nicht genau einmal vor")
            for zeile in treffer {
                XCTAssertTrue(zeile.nurMac,
                              "\(fall.mass) in \(fall.datei) steht nicht in einem #if os(macOS)-Zweig — "
                              + "auf dem iPad schneidet es ab")
            }
        }
    }

    /// Die Leinwand darf ihre Spalte nie breiter machen, als sie ist.
    ///
    /// Der gemeldete Fehler war genau das: ein starres `.frame(width:)` ueber
    /// einer Breite, die aus einem `GeometryReader` **innerhalb** derselben
    /// Flaeche kam — gemessen wurde damit, was die Flaeche sich schon genommen
    /// hatte, nicht was die Spalte hergab. Sichtbar wurde es erst am Geraet:
    /// Bedienzeile unter der Seitenleiste, Slot-Zeile ab Block 3.
    ///
    /// Der Uebersetzer sieht davon nichts, beide Fassungen uebersetzen.
    func testDieLeinwandMisstVonAussenUndRolltStattUeberzulaufen() throws {
        let zeilen = try zeilenMitZweig("Sources/TC002Ansichten/Malflaeche.swift")
        let text = zeilen.map(\.text).joined(separator: "\n")
        XCTAssertTrue(text.contains("GeometryReader { geo in"),
                      "ohne GeometryReader über der Fläche gibt es kein Maß, an das sie sich hält")
        XCTAssertTrue(text.contains("verfuegbareBreite: geo.size.width"),
                      "die Breite kommt nicht mehr von außen")
        XCTAssertTrue(text.contains("verfuegbareHoehe: geo.size.height"),
                      "die Höhe kommt nicht mehr von außen")
        XCTAssertTrue(text.contains("ScrollView(.horizontal)"),
                      "ohne waagrechtes Rollen läuft die Fläche bei Enge wieder über ihren Bereich hinaus")
    }
}
