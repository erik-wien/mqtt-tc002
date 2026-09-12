import Foundation

/// Uebersetzte Texte fuers Kommandozeilenwerkzeug.
///
/// Der deutsche Wortlaut ist zugleich der Schluessel — so bleibt der Quelltext
/// lesbar, und eine fehlende Uebersetzung faellt auf die deutsche Fassung
/// zurueck statt auf einen Schluesselnamen. Nachgesehen wird im Buendel, in dem
/// das Programm steckt: Liegt es in `MQTT-TC002.app/Contents/MacOS`, ist das
/// das Buendel der App samt ihrer `.lproj`-Ordner.
enum T {
    static func t(_ deutsch: String) -> String {
        Bundle.main.localizedString(forKey: deutsch, value: deutsch, table: nil)
    }
}

/// Schreibt auf die Fehlerausgabe — Meldungen gehoeren nicht in die Ausgabe,
/// die jemand weiterverarbeitet.
func fehlerAusgeben(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}
