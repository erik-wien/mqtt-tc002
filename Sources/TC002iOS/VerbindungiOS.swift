import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Uhren und Broker einrichten. Eine Liste im Hochformat; die Mac-Fassung
/// bringt dieselben Felder in einem Fenster unter, hier stehen sie in
/// Abschnitten untereinander.
struct VerbindungiOS: View {
    @Bindable var zustand: AppZustand
    @State private var neueAdresse = ""
    @Environment(\.dismiss) private var schliessen
    /// `.numberPad` hat keine Eingabetaste — ohne Tastaturleiste kaeme man aus
    /// dem Port-Feld nur durch Tippen daneben heraus.
    @FocusState private var portFokus: Bool
    @State private var zeigeHilfe = false
    @State private var zeigeUeber = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                Form {
                    uhrenAbschnitt
                    brokerAbschnitt
                    ueberAbschnitt
                }
            }
            .navigationTitle("Einstellungen")
            // Format- und Icon-Blatt haben "Fertig" bzw. "Abbrechen" in der
            // Titelleiste, dieses hatte nur den Greifer — uneinheitlich, und
            // ohne ausdruecklichen Weg hinaus.
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $zeigeHilfe) { HilfeiOS() }
        .sheet(isPresented: $zeigeUeber) { UeberiOS() }
        // Wischt man das Blatt weg, ohne „Sichern und prüfen“ zu drücken, ginge
        // ein eben erst eingetipptes Kennwort sonst verloren — es stünde nur im
        // Speicher, nicht im Schlüsselbund. Dasselbe Netz wie am Mac.
        .onDisappear { zustand.kennwortSichern() }
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
                // Beispiel statt Beschreibung — dieselbe Ueberlegung wie am
                // Mac: Man sieht sofort, dass eine IP-Adresse gemeint ist.
                TextField("z. B. 192.168.0.10", text: $neueAdresse)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { hinzufuegen() }
                Button("Hinzufügen") { hinzufuegen() }
                    .disabled(neueAdresse.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Das Präfix ermittelt die App selbst — es ist das eingestellte plus die letzten vier Stellen der MAC-Adresse.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Hilfe und Über am Fuß der Einstellungen. iOS stellt für „Über“ keine
    /// Stelle bereit — macOS hat das Apple-Menü, hier gibt es nichts
    /// dergleichen —, und die eingebürgerte Stelle ist das Ende der
    /// App-eigenen Einstellungen. Die obere Leiste der Sendeansicht bleibt
    /// bei ihren zwei Symbolen: ein drittes Fragezeichen ist auf dem iPhone
    /// kein verbreitetes Muster.
    private var ueberAbschnitt: some View {
        Section {
            Button("Hilfe") { zeigeHilfe = true }
            Button("Über MQTT-TC002") { zeigeUeber = true }
        }
    }

    private var brokerAbschnitt: some View {
        Section("Broker") {
            // Beschriftet waren die vier Felder hier schon; was fehlte, war
            // der Platzhalter, der nach dem Leeren der Vorgaben sichtbar wird.
            // Die Beschriftung links sagt, was das Feld ist, das Beispiel
            // rechts, wie ein Wert darin aussieht.
            LabeledContent("Adresse") {
                TextField("z. B. 192.168.0.20", text: $zustand.brokerHost)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Port") {
                TextField("Port", text: $zustand.brokerPort)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($portFokus)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            // Nur beim Port: `.keyboard` gilt sonst fuer jede
                            // Tastatur dieses Blattes, auch fuer Adresse,
                            // Benutzer und Kennwort, die ihre Eingabetaste
                            // schon haben.
                            if portFokus {
                                Spacer()
                                Button("Fertig") { portFokus = false }
                            }
                        }
                    }
            }
            LabeledContent("Benutzer") {
                TextField("z. B. pixdeck", text: $zustand.benutzer)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Kennwort") {
                SecureField("Kennwort", text: $zustand.kennwort)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { zustand.kennwortSichern() }
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
