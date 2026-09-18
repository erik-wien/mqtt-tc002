import SwiftUI
import TC002Core

/// Zeigt in der Uhrenzeile, dass sich aus der Adresse keine Anfrage bilden
/// laesst — nicht erst als Fehlermeldung beim Senden. Ein Leerzeichen am Rand
/// entfernt bereits `Uhr.host` von selbst, aber es gibt weitere Wege, eine
/// Adresse unbrauchbar zu machen.
public struct Adresswarnung: View {
    let host: String

    public init(host: String) { self.host = host }

    public var body: some View {
        if !Geraet.adresseTaugt(host) {
            Label("Aus dieser Adresse lässt sich keine Anfrage bilden — sie wird beim Senden übersprungen.",
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Zeigt, warum eine Uhr nicht am Broker hängt — wenn die Geräteauskunft
/// selbst einen Grund nennt (z. B. `badCredentials`). Nur AWTRIX NG liefert
/// dieses Feld; die Werksfirmware kennt es nicht.
public struct Brokergrund: View {
    let grund: String?

    public init(grund: String?) { self.grund = grund }

    public var body: some View {
        if let grund, !grund.isEmpty {
            Label(lokf("Nicht am Broker angemeldet — die Uhr meldet „%@“. Benutzer und Kennwort stehen in der Uhr, nicht in dieser App.", grund),
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

