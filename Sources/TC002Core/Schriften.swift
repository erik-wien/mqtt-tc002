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
    /// Die mitgelieferten Pixelschriften unter ihrem **registrierten**
    /// Familiennamen. Micro 5 traegt ein Leerzeichen im Namen — im Font-Editor
    /// gepruefte Tatsache, kein Tippfehler.
    public static let mitgeliefert = ["Micro 5", "Silkscreen", "Tiny5"]

    /// Die Systemschriften der Auswahl — geprueft bei sechzehn Pixeln Hoehe:
    /// Sie rastern mit gleichmaessigen Strichstaerken. Umlaute koennen sie
    /// auch, aber niemand hat je eine Schriftprobe von ihnen durchgesehen;
    /// deshalb stehen sie nicht in `Pixelgroessen.abgesegnet`.
    public static let systemschriften = ["Geneva", "Monaco", "Andale Mono", "Menlo", "PT Mono"]

    /// Was die Sendeansicht zur Wahl stellt — **eine** Liste fuer alle
    /// Oberflaechen und fuer die Schriftprobe. Sie stand frueher dreimal da
    /// (Mac, iPhone, Messung), und die Messung kannte nur drei der acht Namen.
    public static let auswahl = mitgeliefert + systemschriften

    /// Ist die Schrift auf diesem Geraet wirklich da?
    ///
    /// CoreText liefert sonst klaglos eine Ersatzschrift: Ein Ergebnis kaeme
    /// dann trotzdem, nur waere es ueber etwas anderes gemessen als behauptet.
    /// Kommt derselbe Familienname zurueck, ist die Schrift da.
    ///
    /// Der Schriftverwalter von AppKit taugt dafuer nicht — er listet
    /// Schriften, die nur fuer diesen Prozess angemeldet sind, NICHT auf; die
    /// mitgelieferten fielen dadurch immer heraus, obwohl CoreText sie kennt.
    public static func vorhanden(_ name: String) -> Bool {
        (CTFontCopyFamilyName(CTFontCreateWithName(name as CFString, 12, nil)) as String) == name
    }

    public static func registrieren() {
        guard let ordner = Programmbuendel.eigenes.resourceURL?.appendingPathComponent("Schriften"),
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
