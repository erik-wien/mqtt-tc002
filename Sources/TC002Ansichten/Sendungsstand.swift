import Foundation
import TC002Core

/// Was mit dem naechsten Druck hinausgeht — als ein Satz, an zwei Stellen
/// gebraucht: im Einblendtext am Sendezeichen unter „Senden" und unter der
/// Leinwand im Editor.
///
/// **Ohne Groessenangabe.** Hier standen einmal Kilobyte und eine Warnung ab
/// einer gesetzten Schwelle. Die Engstelle ist allein die Uhr, und was sie
/// fasst, sagt sie nicht: Die Werksfirmware gibt ueber sich selbst weder
/// freien Speicher noch eine Grenze heraus (`docs/tc002-protokoll.md`, §5.1
/// bis §5.4), und eine AWTRIX NG meldet zwar `freeHeapBytes`
/// (`docs/awtrix-ng-protokoll.md`, §7.1), nimmt aber gar kein gemaltes
/// 52×16-Bild an — die Zahl gaebe es also genau dort nicht, wo sie zaehlte.
/// Eine Kilobytezahl ohne Bezugsgroesse beunruhigt, ohne zu helfen; fuer App
/// und iCloud ist sie ohnehin belanglos.
///
/// Was bleibt, ist die Zahl der Einzelbilder: Sie sagt, wie lange die Meldung
/// laeuft, und das ist eine Aussage ueber die Meldung, nicht ueber die
/// Leitung.
enum Sendungsstand {
    /// „Laufschrift · 119 Bilder".
    ///
    /// `art` ist schon uebersetzt (`lok`), nicht erst hier: Ein Ternaer am
    /// Aufrufort schluege sonst nichts nach.
    static func satz(art: String, bilder: Int) -> String {
        lokf("%@ · %d Bilder", art, bilder)
    }
}
