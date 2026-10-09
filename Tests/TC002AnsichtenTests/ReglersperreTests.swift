import XCTest
@testable import TC002Core

/// `AwtrixNG.wirkt` sagt je Regler, ob die Firmware ihn überhaupt hergibt,
/// und `begruendung` liefert den einen Satz dazu. Beides steht im Kern, damit
/// Mac- und iPhone-Fassung dieselbe Antwort bekommen. Ein Regler, der in der
/// Tabelle steht, aber in keiner der beiden Sendeansichten abgefragt wird,
/// bleibt bedienbar und schickt dann eine Einstellung an ein Gerät, das sie
/// nicht kennt — das fiele erst am Gerät auf, an einer Anzeige, die anders
/// aussieht als die Vorschau.
///
/// Geprüft wird deshalb am Quelltext der beiden Sendeansichten, wie in
/// `EinblendtextGegenstueckTests`, `PlattformwegeTests` und
/// `EditorbereichTests`. Kommentare fallen weg; ein Regler, der nur in einem
/// Kommentar vorkommt, zählt nicht als verdrahtet.
final class ReglersperreTests: XCTestCase {
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

    /// Die Regler, die AWTRIX NG nicht kennt. Wächst die Tabelle im Kern,
    /// wächst diese Menge von selbst mit — genau darum wird sie berechnet und
    /// nicht abgeschrieben.
    private var gesperrte: [Regler] {
        Regler.allCases.filter { !AwtrixNG.wirkt($0, weg: .text) }
    }

    func testJederGesperrteReglerIstAmMacVerdrahtet() throws {
        let quelle = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        for regler in gesperrte {
            XCTAssertTrue(quelle.contains("reglersperre(.\(regler.rawValue)"),
                          "„\(regler.rawValue)“ steht in der Tabelle, wird aber in SendenView nicht abgefragt — der Regler bliebe bedienbar")
        }
    }

    func testJederGesperrteReglerIstAmIPhoneVerdrahtet() throws {
        let quelle = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        for regler in gesperrte {
            XCTAssertTrue(quelle.contains("wirkt(.\(regler.rawValue)")
                          || quelle.contains("begruendung(.\(regler.rawValue)"),
                          "„\(regler.rawValue)“ steht in der Tabelle, wird aber in SendeniOS nicht abgefragt — der Regler bliebe bedienbar")
        }
    }

    /// Der halbe Fall, und der gefährlichste: Rechtsbündig wird von NG
    /// angenommen und als linksbündig gesendet. Ein Wähler, der es
    /// trotzdem anbietet, zeigte etwas anderes an, als auf der Uhr steht.
    /// Beide Ansichten müssen den Eintrag darum an `waagrechteAusrichtungen`
    /// hängen, statt ihn fest hinzuschreiben.
    func testRechtsbuendigHaengtInBeidenAnsichtenAnDerFirmware() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002iOS/SendeniOS.swift"] {
            let quelle = try quelltext(pfad)
            XCTAssertTrue(quelle.contains("waagrechteAusrichtungen(weg: optionen.weg).contains(.rechts)"),
                          "\(pfad) bietet „rechtsbündig“ ungefragt an")
        }
    }

    /// Und dass die Firmware überhaupt eine Meinung dazu hat — sonst prüfte der
    /// Test oben eine Bedingung, die immer wahr ist.
    func testNGKenntKeinRechtsbuendig() {
        XCTAssertFalse(AwtrixNG.waagrechteAusrichtungen(weg: .text).contains(.rechts))
    }

    /// Auf dem Pixelweg rastert die App selbst: Nichts ist gesperrt, auch
    /// rechtsbuendig nicht.
    func testAufDemPixelwegIstNichtsGesperrt() {
        for regler in Regler.allCases {
            XCTAssertTrue(AwtrixNG.wirkt(regler, weg: .pixel))
            XCTAssertNil(AwtrixNG.begruendung(regler, weg: .pixel))
        }
        XCTAssertTrue(AwtrixNG.waagrechteAusrichtungen(weg: .pixel).contains(.rechts))
    }
}
