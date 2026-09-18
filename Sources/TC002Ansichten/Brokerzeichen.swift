import SwiftUI
import TC002Core

/// Ob eine Uhr gerade beim Broker angemeldet ist — als Zeichen mit
/// Einblendtext, an einer Stelle statt an zweien.
///
/// Dasselbe Paar stand wortgleich in `VerbindungView` und `ZielauswahlView`
/// und übersetzte dort nicht: Ein Ternär mit zwei `String`-Zweigen zwingt
/// SwiftUI in die `StringProtocol`-Überladung von `.help`, und die schlägt
/// nichts nach — der Textsammler sieht die Literale, die laufende App nicht.
/// Deshalb `lok(…)`.
///
/// Nur im MQTT-Betrieb: Ob eine Uhr am Broker hängt, ist im HTTP-Betrieb keine
/// Auskunft mehr über etwas, das diese App benutzt.
public struct Brokerzeichen: View {
    private let art: Betriebsart
    private let steht: Bool?

    public init(uhr: Uhr, steht: Bool?) {
        self.art = uhr.wirksameBetriebsart
        self.steht = steht
    }

    public var body: some View {
        if art == .mqtt, let steht {
            // `Label` statt eines blossen `Image`: Am Mac bleibt es beim
            // Symbol (`.iconOnly`), am iPad steht der Text gleich daneben —
            // dort gibt es kein Verweilen, das ihn im Einblendtext zeigen
            // koennte (`namensichtbarAmIPad()`).
            let text = steht ? lok("Am Broker angemeldet") : lok("Nicht am Broker angemeldet")
            Label {
                Text(text)
            } icon: {
                Image(systemName: steht ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(steht ? Color.green : Color.orange)
            }
            .namensichtbarAmIPad()
            .help(text)
        }
    }
}
