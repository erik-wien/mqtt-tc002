import Foundation
import TC002Core

/// Schreibt auf die Fehlerausgabe — Meldungen gehoeren nicht in die Ausgabe,
/// die jemand weiterverarbeitet.
func fehlerAusgeben(_ text: String) {
    // Zeilenweise: Die Zeilenumbrüche der Meldung bleiben, Steuerzeichen darin nicht.
    let sauber = text.components(separatedBy: "\n").map(Terminaltext.sicher).joined(separator: "\n")
    FileHandle.standardError.write(Data((sauber + "\n").utf8))
}
