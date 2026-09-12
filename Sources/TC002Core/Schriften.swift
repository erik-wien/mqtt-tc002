import CoreText
import Foundation

/// Meldet alle mitgelieferten Schriften aus `Schriften/` bei CoreText an. Ohne
/// das kennt CoreText sie nicht, obwohl die Dateien im App-Paket liegen —
/// Schriftdateien muessen fuer den Prozess einzeln registriert werden, anders
/// als installierte Systemschriften.
///
/// Aufgerufen beim Start der App und beim Start des Kommandozeilenwerkzeugs —
/// beide rastern Text, und beide sollen dieselben Schriften kennen.
public enum Schriften {
    public static func registrieren() {
        guard let ordner = Bundle.main.resourceURL?.appendingPathComponent("Schriften"),
              let dateien = try? FileManager.default.contentsOfDirectory(
                  at: ordner, includingPropertiesForKeys: nil) else { return }
        for datei in dateien where datei.pathExtension.lowercased() == "ttf" {
            // Fehler (drittes Argument nil) bleiben absichtlich unbehandelt: fehlt
            // eine Datei oder schlaegt die Registrierung fehl (etwa Start aus
            // `swift run` ohne fertiges Buendel), fehlt die betroffene Schrift
            // einfach: der Filter in `SendenView.schriftarten` laesst sie aus
            // der Auswahl, und die Liste faellt auf die naechste Schrift
            // zurueck. Kein Absturz.
            CTFontManagerRegisterFontsForURL(datei as CFURL, .process, nil)
        }
    }
}
