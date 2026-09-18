import SwiftUI
import TC002Core
import TC002Modell

/// Der iCloud-Abgleich in den Einstellungen — ein Abschnitt fuer beide
/// Oberflaechenfamilien. Er hat keine Seitenleiste, kein Blatt und keine
/// Tastatur; was am Mac richtig ist, ist es hier ausnahmsweise auch am
/// Telefon, weil es nur ein Schalter und eine Zeile ist.
///
/// Der Wortlaut bleibt knapp: was gilt, nicht warum. Die Begruendung
/// gehoert in die Hilfe.
public struct Wolkenabschnitt: View {
    @Bindable var zustand: AppZustand
    /// `.footnote` am Mac, `.caption` am Telefon — dieselbe Wahl, die die
    /// beiden Einstellungsansichten fuer ihre uebrigen Fussnoten schon
    /// treffen.
    let fussnote: Font

    public init(zustand: AppZustand, fussnote: Font) {
        self.zustand = zustand
        self.fussnote = fussnote
    }

    public var body: some View {
        Section("iCloud") {
            Toggle("Über iCloud abgleichen", isOn: schalter)
                .disabled(zustand.wolkenschalterGesperrt)
            stand
            Text("Das Kennwort bleibt im Schlüsselbund und wird nicht abgeglichen.")
                .font(fussnote).foregroundStyle(.secondary)
        }
        .task { zustand.wolkeBereitPruefen() }
    }

    /// Der Schalter schreibt nicht selbst, sondern laesst umschalten — daran
    /// haengt der Umzug, und der dauert.
    private var schalter: Binding<Bool> {
        Binding(get: { zustand.wolkeGewaehlt },
                set: { zustand.wolkeUmschalten($0) })
    }

    @ViewBuilder
    private var stand: some View {
        if zustand.wolkeLaeuft {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("wird umgestellt …").font(fussnote).foregroundStyle(.secondary)
            }
        } else if zustand.wolkeBereit == nil {
            Text("wird geprüft …").font(fussnote).foregroundStyle(.secondary)
        } else if zustand.wolkeBereit == false {
            Text("Auf diesem Gerät steht der Abgleich nicht bereit.")
                .font(fussnote).foregroundStyle(.secondary)
        } else if zustand.wolkeGewaehlt {
            Text("Icons, Bilder und die zuletzt gesendeten Meldungen liegen in iCloud.")
                .font(fussnote).foregroundStyle(.secondary)
        } else {
            Text("Icons, Bilder und die zuletzt gesendeten Meldungen bleiben auf diesem Gerät.")
                .font(fussnote).foregroundStyle(.secondary)
        }
    }
}
