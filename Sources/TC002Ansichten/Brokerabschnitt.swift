import SwiftUI
import TC002Core
import TC002Modell

/// Das Thema „Broker" der Einstellungen — für beide Oberflächen derselbe
/// Baustein: Adresse, Port, Benutzer, Kennwort und die Prüfung.
public struct Brokerabschnitt: View {
    @Bindable var zustand: AppZustand
    private let kanon: Formkanon
    /// Das Kennwort wandert beim Verlassen des Feldes in den Schlüsselbund,
    /// nicht bei jedem Tastendruck.
    @FocusState private var kennwortFokus: Bool
    @FocusState private var portFokus: Bool

    public init(zustand: AppZustand, kanon: Formkanon) {
        self.zustand = zustand
        self.kanon = kanon
    }

    public var body: some View {
        Section("Broker") {
            // Der Abschnitt wird nicht ausgeblendet und nicht abgeblendet,
            // sondern nur eingeordnet. Ausgeblendet spränge das Formular bei
            // jedem Griff an die Betriebsart; abgeblendet ließe sich ein Broker
            // nicht mehr eintragen, bevor man eine Uhr auf MQTT stellt — und
            // genau in der Reihenfolge geht man vor.
            if !Einstellungen.brokerNoetig(fuer: zustand.uhren) {
                Text("Zurzeit steht keine Uhr auf MQTT — dann wird hier nichts davon gebraucht. Eingetragen werden darf es trotzdem, und es gilt, sobald eine Uhr umgestellt wird.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            }
            // `LabeledContent` statt der Beschriftung, die `TextField` selbst
            // mitbringt: Am Mac zeigt SwiftUI die zwar an, auf dem iPad dagegen
            // ist sie der Platzhalter — und der verschwindet, sobald etwas im
            // Feld steht. Vier gefüllte Felder ohne jede Beschriftung waren das
            // Ergebnis. Die Beschriftung kommt deshalb von außen, das Feld
            // trägt nur noch das Beispiel.
            LabeledContent("Adresse") {
                TextField("z. B. 192.168.0.20", text: $zustand.brokerHost)
                    .eingabefeld(inZeile: kanon)
                    .ohneAutokorrektur()
            }
            LabeledContent("Port") {
                TextField("Port", text: $zustand.brokerPort)
                    .eingabefeld(inZeile: kanon)
                    .ziffernfeld(fokus: $portFokus)
            }
            LabeledContent("Benutzer") {
                TextField("z. B. pixdeck", text: $zustand.benutzer)
                    .eingabefeld(inZeile: kanon)
                    .ohneAutokorrektur()
            }
            LabeledContent("Kennwort") {
                SecureField("Kennwort", text: $zustand.kennwort)
                    .eingabefeld(inZeile: kanon)
                    .focused($kennwortFokus)
                    .onSubmit { zustand.kennwortSichern() }
                    .onChange(of: kennwortFokus) { _, hat in if !hat { zustand.kennwortSichern() } }
            }
            Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                .font(kanon.fussnote).foregroundStyle(.secondary)
            HStack {
                Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
                    .knopfBefehl()
                    .disabled(zustand.brokerStand == .laeuft)
                stand
            }
        }
        // Fokuswechsel ist nicht zugesichert, wenn diese Ansicht durch einen
        // Bereichs- oder Reiterwechsel zerstört wird — ohne dieses Netz ginge
        // ein eben erst eingetipptes Kennwort dabei verloren.
        .onDisappear { zustand.kennwortSichern() }
    }

    @ViewBuilder
    private var stand: some View {
        switch zustand.brokerStand {
        case .unbekannt:
            Text("noch nicht geprüft")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        case .laeuft:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("prüfe…").font(kanon.fussnote).foregroundStyle(.secondary)
            }
        case .angenommen:
            Text("Der Broker nimmt die Anmeldung an.")
                .font(kanon.fussnote).foregroundStyle(.green)
        case .abgelehnt(let text):
            Text(text)
                .font(kanon.fussnote).foregroundStyle(.red)
        }
    }
}
