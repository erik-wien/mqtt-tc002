import CoreText
import Foundation

/// Die mitgelieferten Pixelschriften fuer die Tests anmelden.
///
/// CoreText kennt sie sonst nicht: Schriftdateien muessen je Prozess
/// registriert werden, anders als installierte Systemschriften. Im Programm tut
/// das `Schriften.registrieren()` aus dem Buendel — beim Test gibt es kein
/// Buendel, also aus dem Quellbaum ueber `#filePath`, wie die Schnappschuesse
/// des Rahmenbaus auch.
enum Schriftbuendel {
    /// Die drei mitgelieferten Pixelschriften unter ihrem **registrierten
    /// Familiennamen**. Micro5 traegt ein Leerzeichen im Namen — im
    /// Font-Editor geprueft, kein Tippfehler (siehe `SendenView`).
    static let schriften = ["Micro 5", "Silkscreen", "Tiny5"]

    private static var angemeldet = false

    static func anmelden() {
        guard !angemeldet else { return }
        angemeldet = true
        let ordner = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // TC002CoreTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // Wurzel
            .appendingPathComponent("Resources/Schriften")
        guard let dateien = try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: nil) else { return }
        for datei in dateien where datei.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(datei as CFURL, .process, nil)
        }
    }

    /// Ist die Schrift wirklich da? CoreText liefert sonst klaglos eine
    /// Ersatzschrift, und die Messung maesse dann etwas ganz anderes.
    static func vorhanden(_ name: String) -> Bool {
        anmelden()
        return (CTFontCopyFamilyName(CTFontCreateWithName(name as CFString, 12, nil)) as String) == name
    }
}
