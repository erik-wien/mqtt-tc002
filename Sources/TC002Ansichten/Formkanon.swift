import SwiftUI

/// Woran sich ein Baustein der Einstellungen ausrichtet: am Schreibtisch (Mac
/// und iPad) oder am Telefon.
///
/// Die Themen sind auf beiden Oberflächen dieselben und stehen in denselben
/// Dateien. Was sich unterscheidet, sind zwei Kleinigkeiten — die Größe der
/// Fußnote und die Fassung der Eingabefelder (`Eingabefeld.swift` begründet
/// sie). Sie stehen hier an einer Stelle, statt in jedem Baustein noch einmal
/// entschieden zu werden.
public enum Formkanon: Sendable {
    case schreibtisch
    case telefon

    /// Dieselbe Wahl, die die beiden Einstellungsansichten für ihre Fußnoten
    /// schon immer getroffen haben.
    public var fussnote: Font {
        switch self {
        case .schreibtisch: return .footnote
        case .telefon: return .caption
        }
    }
}
