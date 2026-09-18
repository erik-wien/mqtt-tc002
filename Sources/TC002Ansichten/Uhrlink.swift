import SwiftUI
import TC002Core

/// Der Weg zur Uhr selbst. Beide Firmwares bringen eine Web-Oberfläche mit,
/// und alles, was diese App nicht einstellt — WLAN, Helligkeit, die
/// eingebauten Anzeigen, bei AWTRIX NG der MQTT-Broker samt Präfix —, wird
/// dort eingestellt.
///
/// Kein `URL(string:)!`: Ein Hostname aus einem Eingabefeld ist beliebiger
/// Text, und ein Ausrufezeichen darauf wäre ein Absturz, den ein Tippfehler
/// auslöst. Lässt sich keine Adresse bilden — oder ist das Feld noch leer —,
/// steht hier nichts.
public struct Uhrlink: View {
    let host: String

    public init(host: String) { self.host = host }

    private var ziel: URL? { Geraet.weboberflaeche(host: host) }

    public var body: some View {
        if let ziel {
            Link("Konfigurieren", destination: ziel)
                .knopfBefehl()
                .help(lokf("Die Web-Oberfläche von %@ im Browser öffnen", host))
        }
    }
}
