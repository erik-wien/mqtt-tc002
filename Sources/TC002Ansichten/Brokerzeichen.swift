import SwiftUI
import TC002Core

/// Ob eine Uhr gerade beim Broker angemeldet ist — als Zeichen mit
/// Einblendtext, an einer Stelle statt an zweien.
///
/// Dasselbe Paar stand wortgleich in `VerbindungView` und `ZielauswahlView`,
/// und **beide Male übersetzte es nicht**: Ein Ternär mit zwei
/// `String`-Zweigen zwingt SwiftUI in die `StringProtocol`-Überladung von
/// `.help`, und die schlägt nichts nach. Der Eintrag stand in `en.lproj` und
/// wurde nie gefunden — der Textsammler sieht die Literale, die laufende App
/// nicht. Deshalb `lok(…)`: Dann ist die Übersetzung schon geschehen, bevor
/// SwiftUI den Wert sieht.
///
/// **Nur im MQTT-Betrieb.** Ob eine Uhr am Broker hängt, ist im HTTP-Betrieb
/// keine Auskunft mehr über etwas, das diese App benutzt — das Zeichen stünde
/// dort als Rest einer Einrichtung da, die für diese Uhr nicht mehr gilt.
public struct Brokerzeichen: View {
    private let art: Betriebsart
    private let steht: Bool?

    public init(uhr: Uhr, steht: Bool?) {
        self.art = uhr.wirksameBetriebsart
        self.steht = steht
    }

    public var body: some View {
        if art == .mqtt, let steht {
            Image(systemName: steht ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(steht ? Color.green : Color.orange)
                .help(steht ? lok("Am Broker angemeldet") : lok("Nicht am Broker angemeldet"))
        }
    }
}
