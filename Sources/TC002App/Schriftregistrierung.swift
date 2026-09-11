import CoreText
import Foundation

/// Meldet die mitgelieferte Silkscreen-Schrift bei CoreText an. Ohne das kennt
/// CoreText sie nicht, obwohl die Datei im App-Paket liegt — Schriftdateien
/// muessen fuer den Prozess einzeln registriert werden, anders als installierte
/// Systemschriften. Aufgerufen an derselben Stelle wie `Netzfreigabe.anfragen()`.
enum Schriftregistrierung {
    static func schriftAnmelden() {
        guard let url = Bundle.main.resourceURL?
                .appendingPathComponent("Schriften/Silkscreen.ttf") else { return }
        // Fehler (drittes Argument nil) bleiben absichtlich unbehandelt: Start
        // aus Xcode ohne fertiges Buendel etwa liefert keine Schriftdatei — dann
        // fehlt „Silkscreen" einfach in `NSFontManager.availableFontFamilies`,
        // der Filter in `SendenView.schriftarten` laesst sie aus der Auswahl,
        // und die Liste faellt auf die naechste Schrift zurueck. Kein Absturz.
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
