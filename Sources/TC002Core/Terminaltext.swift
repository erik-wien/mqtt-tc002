import Foundation

/// Text von der Uhr für die Terminalausgabe. Titel eines Internetstreams, Namen
/// und Fehlertexte stammen von Fremden und können Steuerfolgen tragen (`ESC[2J`
/// löscht den Schirm, `ESC]0;…` setzt den Fenstertitel).
public enum Terminaltext {
    /// Ersetzt C0- (auch Tab und Zeilenumbruch), DEL, C1- und Bidi-Steuerzeichen
    /// (U+202A–U+202E, U+2066–U+2069) durch U+FFFD; alles andere bleibt.
    public static func sicher(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: gesperrt) else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.map { gesperrt($0) ? "\u{FFFD}" : $0 }))
    }

    private static func gesperrt(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x00...0x1F, 0x7F...0x9F, 0x202A...0x202E, 0x2066...0x2069: return true
        default: return false
        }
    }
}
