import SwiftUI
import TC002Core

/// **Sagt gleich, dass aus dieser Adresse nichts wird** — in der Uhrenzeile,
/// nicht erst beim Senden.
///
/// Bis zum 14.09.2026 fiel eine unbrauchbare Adresse erst auf, wenn jemand
/// etwas schickte: dann als Fenster, mitten in der Arbeit, für einen Fehler,
/// der beim Eintippen entstanden war. Ein Leerzeichen am Rand genügte dafür —
/// das wird inzwischen von selbst entfernt (`Uhr.host`), aber es gibt genug
/// andere Weisen, eine Adresse unbrauchbar zu machen.
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

/// **Warum eine Uhr nicht am Broker hängt** — wenn sie es selbst sagt.
///
/// Am 14.09.2026 stand in den Einstellungen ein Warndreieck, und der
/// Auftraggeber fragte, warum es nicht erklärt wird. Die Antwort stand in der
/// Geräteauskunft und wurde weggeworfen: `badCredentials`, neun Versuche,
/// keine Verbindung. Nur AWTRIX NG nennt einen Grund; die Werksfirmware
/// kennt dafür kein Feld.
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

