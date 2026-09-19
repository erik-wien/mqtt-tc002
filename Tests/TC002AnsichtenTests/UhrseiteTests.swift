import XCTest

/// Je Uhr eine Seite, und jeder Wert darauf gilt **dieser** Uhr.
///
/// Der Mangel, den das abfängt, ist der stumme: „Auf der Uhr" — Seitenwechsel
/// und Scrolltempo — stand früher einmal unter allen Uhren und las und schrieb
/// stets die *angesehene* (`zustand.aktiveUhr`). Eine Fußnote sagte das, die
/// Stelle nicht; wer eine andere Uhr meinte, musste die Einstellungen
/// verlassen, umschalten und zurückkommen. Nimmt jemand später wieder
/// `aktiveUhr` zur Hand, sieht man das weder am Übersetzer noch am Bildschirm
/// — die Werte sehen richtig aus, sie gelten nur der falschen Uhr.
///
/// Geprüft wird am Quelltext wie in `KnopfstilTests`: Wie es aussieht, sieht
/// man am Gerät; welche Uhr gemeint ist, steht hier.
final class UhrseiteTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    /// Die Geräteeinstellungen bekommen ihre Uhr gereicht und holen sie nicht
    /// aus dem Zustand.
    func testDieGeraeteeinstellungenGeltenDerUhrDerSeite() throws {
        let pfad = "Sources/TC002Ansichten/Uhreinstellungen.swift"
        let quelle = try ohneKommentare(pfad)
        XCTAssertTrue(quelle.contains("public init(zustand: AppZustand, uhr: Uhr"),
                      "\(pfad) nimmt die Uhr nicht mehr entgegen")
        XCTAssertFalse(quelle.contains("aktiveUhr"),
                       "\(pfad) liest wieder die angesehene Uhr — dann gelten Seitenwechsel "
                       + "und Scrolltempo nicht der Uhr, deren Seite offen steht")
        XCTAssertFalse(quelle.contains("aktiveID"),
                       "\(pfad) hängt seine Abfrage wieder an die angesehene Uhr statt an die "
                       + "Uhr der Seite")
    }

    /// Gelesen und geschrieben wird an der Adresse der Uhr, deren Seite offen
    /// steht — beides über dieselbe Quelle.
    func testGelesenUndGeschriebenWirdAnDerselbenAdresse() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Uhreinstellungen.swift")
        XCTAssertEqual(quelle.components(separatedBy: "let host = uhr.host").count - 1, 2,
                       "Lesen und Setzen holen die Adresse nicht mehr beide aus der Uhr der Seite")
    }

    /// Eine AWTRIX NG hat kein `/getConfig`; der Abschnitt fehlt dort. Geprüft
    /// wird die Bedingung an der Gattung **dieser** Uhr — vorher hing sie an
    /// der angesehenen und blendete den Abschnitt auf der Seite einer TC002
    /// aus, sobald man eine NG ansah.
    func testAufDerUhrNurBeiDerWerksfirmware() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Uhreinstellungen.swift")
        XCTAssertTrue(quelle.contains("private var nurUlanzi: Bool { uhr.gattung == .tc002 }"),
                      "die Bedingung hängt nicht mehr an der Gattung der Uhr dieser Seite")
        XCTAssertTrue(quelle.contains("if nurUlanzi {"),
                      "der Abschnitt „Auf der Uhr“ wird nicht mehr an der Gattung entschieden")
    }

    /// Entfernen fragt nach, und beide Wege fragen dasselbe: die rote Zeile am
    /// Fuß der Seite und das Wischen in der Liste. Ein zweiter Wortlaut wäre
    /// ein zweiter Übersetzungsschlüssel, der auseinanderlaufen kann.
    func testEntfernenFragtNachUndZwarAufBeidenWegen() throws {
        for pfad in ["Sources/TC002Ansichten/Uhrseite.swift",
                     "Sources/TC002Ansichten/Uhrenliste.swift"] {
            XCTAssertTrue(try ohneKommentare(pfad).contains(".uhrentfernenRueckfrage("),
                          "\(pfad) entfernt eine Uhr ohne Rückfrage")
        }
        let liste = try ohneKommentare("Sources/TC002Ansichten/Uhrenliste.swift")
        XCTAssertTrue(liste.contains(".swipeActions("),
                      "in der Liste lässt sich eine Uhr nicht mehr wegwischen")
        let seite = try ohneKommentare("Sources/TC002Ansichten/Uhrseite.swift")
        XCTAssertTrue(seite.contains("Button(Uhrentfernen.knopf, role: .destructive)"),
                      "die Uhrseite hat ihre rote Zeile am Fuß verloren")
        XCTAssertEqual(try ohneKommentare("Sources/TC002Ansichten/Uhrseite.swift")
                        .components(separatedBy: "public static var titel").count - 1, 1,
                       "der Wortlaut der Rückfrage steht nicht mehr genau einmal da")
    }

    /// Die Liste zeigt je Uhr **eine** Zeile und keine Karte mit drei Knöpfen:
    /// Alles, was man mit einer Uhr tut, steht auf ihrer Seite.
    func testDieListeZeigtEineZeileJeUhr() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Uhrenliste.swift")
        XCTAssertTrue(quelle.contains("NavigationLink(value: uhr.id)"),
                      "die Zeile führt nicht mehr auf die Seite der Uhr")
        for verirrt in ["Button(\"Abfragen\"", "pickerStyle(.segmented)", "Uhrlink("] {
            XCTAssertFalse(quelle.contains(verirrt),
                           "„\(verirrt)“ steht wieder in der Liste statt auf der Uhrseite — "
                           + "damit wächst die Liste wieder zur Wand")
        }
    }
}
