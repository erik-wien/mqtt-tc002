import XCTest

/// **B1.** Ein Stil lässt sich schlecht prüfen — der Übersetzer hat dazu
/// nichts zu sagen, und ohne Gerät sieht es niemand. Der Quelltext lässt sich
/// dagegen prüfen, und genau darum geht es hier: **Kein Befehlsknopf steht
/// ohne Stil da, und kein Eingabefeld ohne Fassung.**
///
/// Der Mangel, den das abfängt, ist der stumme: Ohne ausdrücklichen Stil
/// nimmt SwiftUI `.automatic`, und die sieht auf den beiden Geräten
/// verschieden aus — am Mac ein gerahmter Knopf, unter iPadOS bloße Schrift
/// in der Akzentfarbe. Ein Befehl sah dort damit aus wie ein Verweis. Ein
/// neuer Knopf, den jemand ohne Stil hinschreibt, fällt beim Übersetzen nicht
/// auf und auf dem Mac auch beim Ansehen nicht.
///
/// Geprüft wird nicht, **welcher** Stil dasteht, sondern **dass** einer
/// dasteht. `.plain`, `.borderless` und das ausdrückliche `.automatic` zählen
/// mit: Sie sind Entscheidungen — für eine Kachel, ein Löschzeichen, eine
/// Listenzeile — und stehen als solche im Quelltext. Vergessen zählt nicht.
///
/// Gleicher Weg wie `PlattformwegeTests` und `EditorbereichTests`: nachsehen
/// im Quelltext, Kommentare weg.
final class KnopfstilTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Wo ein Knopf **keinen** eigenen Stil braucht, weil ihn das System
    /// setzt und ein eigener dort falsch wäre: Rückfragen, Menüs,
    /// Werkzeug- und Tastaturleisten, Wischgesten, das Mac-Menü.
    private static let ausnahmen = [
        "alert(", "confirmationDialog(", "contextMenu", "swipeActions",
        "toolbar", "ToolbarItem", "ToolbarItemGroup",
        "Menu {", "Menu(", "commands", "CommandGroup(", "CommandMenu(",
    ]

    /// Was als ausdrücklicher Stil gilt.
    private static let stile = [
        ".knopfBefehl()", ".knopfHaupthandlung()", ".knopfZerstoerend()",
        ".buttonStyle(",
    ]

    private static let ordner = [
        "Sources/TC002Ansichten", "Sources/TC002App", "Sources/TC002iOS",
    ]

    // MARK: - Quelltext lesen

    private struct Zeile {
        let text: String
        let einzug: Int
        let nackt: String
    }

    /// Zeilen ohne Kommentare, samt Einzug. Der Einzug trägt hier die ganze
    /// Struktur: In SwiftUI hängt die Modifikatorenkette eines Knopfes
    /// entweder tiefer als er oder gleich tief und beginnt mit einem Punkt.
    private func zeilen(_ pfad: String) throws -> [Zeile] {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            let ohneKommentar: String
            if let strich = z.range(of: "//") {
                ohneKommentar = String(z[z.startIndex..<strich.lowerBound])
            } else {
                ohneKommentar = String(z)
            }
            let nackt = ohneKommentar.trimmingCharacters(in: .whitespaces)
            let einzug = ohneKommentar.prefix { $0 == " " }.count
            return Zeile(text: ohneKommentar, einzug: nackt.isEmpty ? Int.max : einzug, nackt: nackt)
        }
    }

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    // MARK: - Der Scanner

    /// Steht dieser Knopf in einer der Ausnahmen? Dafür wird von der
    /// Knopfzeile aus nach **außen** gegangen: die jeweils nächste Zeile mit
    /// geringerem Einzug ist der umschließende Aufruf. Abgebrochen wird an
    /// der Deklaration, in der der Knopf steht — weiter außen steht nur noch
    /// der Typ.
    private func istAusgenommen(_ alle: [Zeile], ab stelle: Int) -> Bool {
        var einzug = alle[stelle].einzug
        var i = stelle - 1
        while i >= 0 {
            let z = alle[i]
            // Tiefer eingerückt heißt: gehört zu einem Geschwister, nicht zum
            // umschließenden Aufruf.
            if z.einzug > einzug { i -= 1; continue }
            // Gleich tief zählt mit: Ein Aufruf über mehrere Zeilen
            // (`confirmationDialog(` … `) { eintrag in`) trägt seinen Namen in
            // der **ersten** davon, und die steht nicht flacher als der Rest.
            if Self.ausnahmen.contains(where: { z.nackt.contains($0) }) { return true }
            if z.nackt.hasPrefix("var ") || z.nackt.hasPrefix("private var ")
                || z.nackt.hasPrefix("func ") || z.nackt.hasPrefix("private func ")
                || z.nackt.hasPrefix("struct ") || z.nackt.hasPrefix("public struct ")
                || z.nackt.hasPrefix("extension ") {
                return false
            }
            einzug = z.einzug
            i -= 1
        }
        return false
    }

    /// Die Modifikatorenkette eines Knopfes: alles, was tiefer eingerückt
    /// folgt, dazu die Zeilen auf seiner eigenen Höhe, die mit `.` oder `}`
    /// beginnen. Der erste Geschwisterausdruck beendet sie — so schlägt der
    /// Stil des **nächsten** Knopfes nicht auf diesen durch.
    private func kette(_ alle: [Zeile], ab stelle: Int) -> String {
        var stuecke = [alle[stelle].nackt]
        var i = stelle + 1
        while i < alle.count {
            let z = alle[i]
            if z.einzug == Int.max { i += 1; continue }
            if z.einzug > alle[stelle].einzug
                || (z.einzug == alle[stelle].einzug
                    && (z.nackt.hasPrefix(".") || z.nackt.hasPrefix("}"))) {
                stuecke.append(z.nackt)
                i += 1
                continue
            }
            break
        }
        return stuecke.joined(separator: "\n")
    }

    // MARK: - Die Prüfungen

    /// Jeder Knopf, der nicht in einer Ausnahme steht, trägt einen
    /// ausdrücklichen Stil.
    ///
    /// **Mutationsprobe** (13.09.2026): `.knopfBefehl()` bei „Bild anhängen"
    /// entfernt → dieser Test fällt mit genau dieser Zeile durch; wieder
    /// eingesetzt → grün.
    func testKeinBefehlsknopfOhneStil() throws {
        var ohneStil: [String] = []
        for ordner in Self.ordner {
            for datei in swiftDateien(unter: ordner) {
                let alle = try zeilen(datei)
                for (i, z) in alle.enumerated() {
                    guard z.nackt.range(of: #"\bButton\s*[\(\{]"#, options: .regularExpression) != nil
                    else { continue }
                    if istAusgenommen(alle, ab: i) { continue }
                    let kette = kette(alle, ab: i)
                    if Self.stile.contains(where: { kette.contains($0) }) { continue }
                    ohneStil.append("\(datei):\(i + 1)  \(z.nackt)")
                }
            }
        }
        XCTAssertTrue(ohneStil.isEmpty,
                      "Diese Knöpfe stehen ohne ausdrücklichen Stil da. Unter iPadOS sehen sie "
                      + "damit aus wie Verweise. Einen der drei Aufrufe aus `Knopfstil.swift` "
                      + "setzen — oder, wenn es wirklich keiner ist, `.buttonStyle(.automatic)` "
                      + "samt Begründung:\n" + ohneStil.joined(separator: "\n"))
    }

    /// Und auf den beiden Schreibtischen (`TC002Ansichten` — Mac und iPad)
    /// trägt jedes Eingabefeld seine Fassung.
    ///
    /// **Warum nicht auch `TC002iOS`:** Das Telefon zeigt seine Felder in
    /// einer `Form` oder einem Blatt, und dort ist der Kanon Beschriftung
    /// links, rechts angeschlagener Wert **ohne** Kasten — wie in den
    /// Systemeinstellungen. Ein Rahmen wäre dort der falsche Kanon, nicht die
    /// fehlende Fassung.
    ///
    /// **Mutationsprobe** (13.09.2026): `.eingabefeld()` bei „Suchen" im
    /// Editor entfernt → durchgefallen; wieder eingesetzt → grün.
    func testKeinEingabefeldOhneFassung() throws {
        var ohneFassung: [String] = []
        for datei in swiftDateien(unter: "Sources/TC002Ansichten") {
            let alle = try zeilen(datei)
            for (i, z) in alle.enumerated() {
                guard z.nackt.contains("TextField(") || z.nackt.contains("SecureField(") else { continue }
                if kette(alle, ab: i).contains(".eingabefeld()") { continue }
                ohneFassung.append("\(datei):\(i + 1)  \(z.nackt)")
            }
        }
        XCTAssertTrue(ohneFassung.isEmpty,
                      "Diesen Feldern fehlt die Fassung (`Eingabefeld.swift`). Ohne sie zeigt die "
                      + "Zeile nur ihre Beschriftung, und wo zu tippen ist, sieht man erst nach "
                      + "dem Hineinklicken:\n" + ohneFassung.joined(separator: "\n"))
    }

    /// Die Schrittwahl ist **ein** Element mit Trennstrich, nicht zwei
    /// Knöpfe, und ihr Wert steht in einem eigenen Kästchen. Beides steckt in
    /// `Schrittwahl`; hier steht, dass die drei Stellen sie auch benutzen und
    /// nicht wieder je einen nackten `Stepper` hinschreiben.
    func testDieDreiSchrittwahlenGehenUeberDasGemeinsameElement() throws {
        for (datei, anzahl) in [("Sources/TC002Ansichten/SendenView.swift", 2),
                                ("Sources/TC002Ansichten/VerbindungView.swift", 1)] {
            let text = try zeilen(datei).map(\.text).joined(separator: "\n")
            let treffer = text.components(separatedBy: "Schrittwahl(").count - 1
            XCTAssertEqual(treffer, anzahl,
                           "\(datei) hat nicht mehr \(anzahl) Schrittwahl(en) — "
                           + "steht dort wieder ein nackter Stepper ohne Wertkästchen?")
            XCTAssertFalse(text.contains("Stepper("),
                           "\(datei) baut wieder einen Stepper von Hand; "
                           + "der trägt weder Kästchen noch die gemeinsame Fassung")
        }
    }
}
