import SwiftUI
import TC002Core
import TC002Modell

/// Uhren und Broker einrichten. Eine Liste im Hochformat; die Mac-Fassung
/// bringt dieselben Felder in einem Fenster unter, hier stehen sie in
/// Abschnitten untereinander.
struct VerbindungiOS: View {
    @Bindable var zustand: AppZustand
    @State private var neueAdresse = ""

    var body: some View {
        NavigationStack {
            Form {
                uhrenAbschnitt
                brokerAbschnitt
            }
            .navigationTitle("Einstellungen")
        }
    }

    private var uhrenAbschnitt: some View {
        Section("Uhren") {
            ForEach(zustand.uhren) { uhr in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(uhr.name)
                        Spacer()
                        if zustand.verbunden[uhr.id] == true {
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        } else if zustand.verbunden[uhr.id] == false {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                    Text(uhr.host).font(.caption).foregroundStyle(.secondary)
                    Text(uhr.praefix.isEmpty ? lok("noch nicht abgefragt") : uhr.praefix)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                        Spacer()
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                    }
                    .buttonStyle(.bordered)
                    .font(.callout)
                }
            }
            HStack {
                TextField("Adresse einer weiteren Uhr", text: $neueAdresse)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Hinzufügen") { hinzufuegen() }
                    .disabled(neueAdresse.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Das Präfix ermittelt die App selbst — es ist das eingestellte plus die letzten vier Stellen der MAC-Adresse.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var brokerAbschnitt: some View {
        Section("Broker") {
            LabeledContent("Adresse") {
                TextField("Adresse", text: $zustand.brokerHost)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Port") {
                TextField("Port", text: $zustand.brokerPort)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            LabeledContent("Benutzer") {
                TextField("Benutzer", text: $zustand.benutzer)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Kennwort") {
                SecureField("Kennwort", text: $zustand.kennwort)
                    .multilineTextAlignment(.trailing)
            }
            Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
            standText
            Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var standText: some View {
        switch zustand.brokerStand {
        case .unbekannt: Text("noch nicht geprüft").foregroundStyle(.secondary)
        case .laeuft: HStack { ProgressView(); Text("wird geprüft …") }
        case .angenommen: Text("angenommen").foregroundStyle(.green)
        case .abgelehnt(let grund): Text(grund).foregroundStyle(.red)
        }
    }

    private func hinzufuegen() {
        let adresse = neueAdresse.trimmingCharacters(in: .whitespaces)
        guard !adresse.isEmpty else { return }
        zustand.uhrHinzufuegen(host: adresse)
        neueAdresse = ""
    }
}
