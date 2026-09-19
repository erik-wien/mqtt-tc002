import XCTest
@testable import TC002Modell
@testable import TC002Core

/// Was die App selbst geschickt hat, zeigt der Block — auch ohne Regler.
///
/// Ein Bild hat keine, aus denen sich sein Aussehen neu rechnen liesse; das
/// Slotgedaechtnis bleibt dafuer leer. Die Pixel sind aber bekannt, die App
/// hat sie gerade verschickt. Ohne sie stand nach jeder Bildsendung
/// „unbekannt" auf dem Platz — beanstandet am 19.09.2026: „Banana an
/// Sendeplaetze 3 geschickt, das gefaellt der Slotanzeige nicht."
///
/// Warum nicht ueber das Mitlesen: Die Uhr gibt ein GIF zurueck, und aus dem
/// laesst sich das Punktfeld nicht zurueckgewinnen (`Anzeigen.
/// pixelAusCustomNutzlast` sagt dazu `nil`). Genau dieser Fall loescht
/// `slotInhalt` — er darf ihn nicht loeschen, bevor er ihn nie gesetzt hat.
final class SlotbildNachBildsendungTests: XCTestCase {
    /// Gelesen im Quelltext, nicht am Netz: `senden` braucht eine erreichbare
    /// Uhr, und die ist in Tests tabu (CLAUDE.md). Geprueft wird die Naht —
    /// dass die Pixel von den beiden Bildwegen bis in `slotInhalt` gereicht
    /// werden.
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let roh = try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { z -> String in
                guard let strich = z.range(of: "//") else { return String(z) }
                return String(z[z.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Mutation: das `if let slotPixel` in `AppZustand.senden` entfernen —
    /// baut, uebersetzt, und jeder Platz mit einem Bild sagt wieder
    /// „unbekannt".
    func testDerKernMerktSichDieGeschicktenPixel() throws {
        let text = try quelltext("Sources/TC002Modell/AppZustand.swift")
        XCTAssertTrue(text.contains("slotPixel: [String?]? = nil"),
                      "`senden` nimmt keine Pixel mehr entgegen — dann kann der Block nach einer "
                      + "Bildsendung nur raten")
        XCTAssertTrue(text.contains("slotInhalt[uhr.id, default: [:]][slotPlatz] = Slotbild(pixel: slotPixel)"),
                      "die geschickten Pixel landen nicht mehr in `slotInhalt` — der Block zeigt "
                      + "dann „unbekannt“, obwohl die App sie selbst verschickt hat")
    }

    /// Beide Wege, die ein Bild schicken, reichen sie weiter — der Editor am
    /// Schreibtisch und die Bildseite am Telefon. Einer allein hiesse: auf
    /// einer Oberflaeche richtig, auf der anderen nicht.
    func testBeideBildwegeReichenDiePixelWeiter() throws {
        let editor = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(editor.contains("slotPixel: slotPixel"),
                      "der Editor schickt sein Bild ohne Pixel — der Platz sagt danach „unbekannt“")
        XCTAssertTrue(editor.contains("groesse.istIcon ? nil : leinwand.bild"),
                      "der Editor reicht die Pixel auch bei einem Icon weiter — dessen Punktfeld "
                      + "hat nicht das Mass der Anzeige und saehe im Block falsch aus")

        let telefon = try quelltext("Sources/TC002iOS/IconsblattiOS.swift")
        XCTAssertTrue(telefon.contains("slotPixel: slotPixel"),
                      "die Bildseite am Telefon schickt ohne Pixel — der Platz sagt danach "
                      + "„unbekannt“")
    }
}
