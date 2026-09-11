import AppKit

/// Laedt ein Bild von der Platte, ohne den Zwischenspeicher von `NSImage`.
///
/// `NSImage(contentsOf:)` merkt sich Bilder anhand ihres Pfades. Wer ein Icon im
/// Editor aendert und es danach anderswo ansieht, bekaeme deshalb weiter das
/// alte zu sehen — die Datei ist neu, der Pfad derselbe. Ueber die Daten zu
/// gehen umgeht das: Es gibt nichts, woran sich der Zwischenspeicher haengen
/// koennte.
enum Bildladen {
    static func frisch(_ datei: URL) -> NSImage? {
        guard let daten = try? Data(contentsOf: datei) else { return nil }
        return NSImage(data: daten)
    }
}
