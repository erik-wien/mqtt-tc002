import Foundation

/// Schreibt auf die Fehlerausgabe — Meldungen gehoeren nicht in die Ausgabe,
/// die jemand weiterverarbeitet.
func fehlerAusgeben(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}
