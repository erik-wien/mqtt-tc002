import SwiftUI

struct VerbindungView: View {
    @Bindable var zustand: AppZustand
    @State private var neuerHost = ""
    /// Das Kennwort wandert beim Verlassen des Feldes in den Schluesselbund, nicht
    /// bei jedem Tastendruck.
    @FocusState private var kennwortFokus: Bool

    var body: some View {
        Form {
            Section("Uhren") {
                ForEach($zustand.uhren) { $uhr in
                    HStack {
                        Button {
                            zustand.aktiveID = uhr.id
                        } label: {
                            Image(systemName: zustand.aktiveID == uhr.id ? "largecircle.fill.circle" : "circle")
                        }
                        .buttonStyle(.plain)
                        .help("Diese Uhr ist das Ziel beim Senden")

                        TextField("Name", text: $uhr.name).frame(width: 140)
                        TextField("Adresse", text: $uhr.host).frame(width: 130)
                            .onChange(of: uhr.host) { _, _ in zustand.adresseGeaendert(uhr.id) }
                        Text(uhr.praefix.isEmpty ? "—" : uhr.praefix)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if let steht = zustand.verbunden[uhr.id] {
                            Image(systemName: steht ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(steht ? .green : .orange)
                                .help(steht ? "Am Broker angemeldet" : "Nicht am Broker angemeldet")
                        }
                        Spacer()
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                    }
                }
                HStack {
                    TextField("Adresse einer weiteren Uhr", text: $neuerHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 220)
                        .onSubmit { uhrHinzufuegen() }
                    Button("Hinzufügen") { uhrHinzufuegen() }
                }
                Text("Das Präfix ermittelt die App selbst — es ist das eingestellte plus die letzten vier Stellen der MAC-Adresse.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Broker") {
                TextField("Adresse", text: $zustand.brokerHost)
                TextField("Port", text: $zustand.brokerPort)
                TextField("Benutzer", text: $zustand.benutzer)
                SecureField("Kennwort", text: $zustand.kennwort)
                    .focused($kennwortFokus)
                    .onSubmit { zustand.kennwortSichern() }
                    .onChange(of: kennwortFokus) { _, hat in if !hat { zustand.kennwortSichern() } }
                Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
                        .disabled(zustand.brokerStand == .laeuft)
                    brokerStandAnzeige
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        // Fokuswechsel ist nicht zugesichert, wenn diese Ansicht durch einen
        // Bereichswechsel zerstoert wird — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort dabei verloren.
        .onDisappear { zustand.kennwortSichern() }
    }

    private func uhrHinzufuegen() {
        let host = neuerHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        zustand.uhrHinzufuegen(host: host)
        neuerHost = ""
    }

    @ViewBuilder
    private var brokerStandAnzeige: some View {
        switch zustand.brokerStand {
        case .unbekannt:
            Text("noch nicht geprüft")
                .font(.footnote).foregroundStyle(.secondary)
        case .laeuft:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("prüfe…").font(.footnote).foregroundStyle(.secondary)
            }
        case .angenommen:
            Text("Der Broker nimmt die Anmeldung an.")
                .font(.footnote).foregroundStyle(.green)
        case .abgelehnt(let text):
            Text(text)
                .font(.footnote).foregroundStyle(.red)
        }
    }
}
