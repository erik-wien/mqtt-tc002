import SwiftUI
import TC002Core
import TC002Modell

/// Der Abschnitt „Virtuelle Uhr" in den Einstellungen — für alle drei
/// Oberflächen derselbe. Wo die Anzeige aufgeht, entscheidet die jeweilige
/// Oberfläche: am Mac ein eigenes Fenster, am iPad eine Einblendung, am
/// Telefon ein Blatt. Deshalb kommt das Aufmachen als Handlung herein.
public struct VirtuelleUhrAbschnitt: View {
    @Bindable var zustand: AppZustand
    private let betrieb: Virtuelleuhrbetrieb
    private let ansehen: () -> Void

    public init(zustand: AppZustand, betrieb: Virtuelleuhrbetrieb,
                ansehen: @escaping () -> Void) {
        self.zustand = zustand
        self.betrieb = betrieb
        self.ansehen = ansehen
    }

    private var eingetragen: Bool {
        zustand.uhren.contains { $0.host == betrieb.adresse }
    }

    public var body: some View {
        Section {
            Toggle("Virtuelle Uhr", isOn: Binding(
                get: { betrieb.laeuft },
                set: { an in an ? betrieb.starten() : betrieb.beenden() }))

            if let fehler = betrieb.fehler {
                Label(fehler, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if betrieb.laeuft {
                LabeledContent("Adresse") {
                    Text(betrieb.adresse)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !eingetragen {
                    // Der Knopf legt die Uhr an und fragt sie ab: Ohne
                    // Abfrage fehlte ihr das Praefix, und sie waere eine Uhr,
                    // die beim Senden stillschweigend uebersprungen wird.
                    Button("Als Uhr eintragen") {
                        zustand.uhrHinzufuegen(host: betrieb.adresse)
                    }
                    .knopfBefehl()
                }
                Button("Ansehen", action: ansehen)
                    .knopfBefehl()
            }

            Text("Eine Uhr, die es nicht gibt: Sie nimmt Anzeigen entgegen wie eine Ulanzi mit Werksfirmware und zeigt sie in einem eigenen Fenster. Damit lässt sich alles ausprobieren — Senden, Löschen, die fünf Plätze, das Blättern —, ohne dass ein Gerät im Netz steht.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Sie hört nur auf dem eigenen Rechner zu und spricht HTTP, keinen MQTT: Ein Broker ist ein fremdes Programm und kann hier nicht mitkommen.")
                .font(.footnote).foregroundStyle(.secondary)
        } header: {
            Text("Virtuelle Uhr")
        }
    }
}
