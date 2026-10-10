import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau. Schriftart, beide Ausrichtungen,
/// Größe, Fett, Großbuchstaben, Rand und Abstand sitzen inzwischen in der
/// Formatpille über dem Eingabefeld (SendeniOS.swift) — hier bleiben Dauer
/// und Laufschrift.
///
/// „Senden als" gibt es hier nicht: Die App wählt den Weg selbst, siehe
/// `SendeWeg` im Kern.
///
/// Die Dauer steht bei der Laufschrift, nicht als eigene Zeile neben den
/// fünf Blöcken — dort nähme sie die Breite weg, die die Blöcke brauchen.
/// Beide reisen mit dieser einen Meldung mit, genau so wie der Zeit-Reiter
/// am Schreibtisch.
struct FormatblattiOS: View {
    @Bindable var zustand: AppZustand
    @Binding var darstellung: Darstellungswahl
    let weg: SendeWeg
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Binding var dauerText: String
    /// Anzeige oder Nachricht: Der Abschnitt der nicht gewählten Art ist
    /// gesperrt, nicht versteckt — wie im Reiter „Zeit“ am Schreibtisch.
    let art: Sendeart
    @Binding var nachrichtHalten: Bool
    @Binding var nachrichtAufwecken: Bool
    @Binding var nachrichtErsetzen: Bool
    @Binding var nachrichtDurchlaeufe: Int
    @Binding var lebensdauerBehalten: Bool
    @Binding var lebensdauerZahl: Int
    @Binding var lebensdauerEinheit: Lebensdauereinheit
    @Binding var lebensdauerAblauf: Lebensablauf
    @Environment(\.dismiss) private var schliessen
    /// `.numberPad` hat keine Eingabetaste — ohne „Fertig" bleibt die Tastatur
    /// stehen. Dieselbe Leiste wie am Nummernfeld der Iconauswahl und am Port
    /// in den Einstellungen.
    @FocusState private var amDauerfeld: Bool

    /// Welcher Reiter oben steht. Ein Blatt, zwei Reiter (Variante 1A der
    /// Freigabe): Die Darstellung bekommt keine eigene Tür.
    @State private var reiter = Formatreiter.zeit

    private enum Formatreiter: Hashable { case zeit, darstellung }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Reiter", selection: $reiter) {
                    Text("Zeit").tag(Formatreiter.zeit)
                    Text("Darstellung").tag(Formatreiter.darstellung)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.vertical, 8)
                switch reiter {
                case .zeit: zeitform
                case .darstellung:
                    Form { Darstellungsabschnitte(zustand: zustand, wahl: $darstellung, weg: weg) }
                }
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }

    private var zeitform: some View {
            Form {
                Section {
                    LabeledContent("Dauer (Sek.)") {
                        TextField("Uhr entscheidet", text: $dauerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($amDauerfeld)
                    }
                    Text("Wie lange die Uhr diese eine Meldung zeigt, bevor sie weiterblättert. Leer oder 0: keine eigene Angabe.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Abschnittskopf("Nur diese Meldung", hilfe: lok("Dauer und Lauftempo reisen mit dieser einen Meldung mit. Wie schnell die Uhr durch alle Anzeigen blättert, ist dagegen eine Einstellung des Geräts und steht unter „Einstellungen“ — bei der Uhr, für die sie gilt."))
                }
                Section("Laufschrift") {
                    Picker("Tempo", selection: $tempo) {
                        Text("langsam").tag(Lauftempo.langsam)
                        Text("mittel").tag(Lauftempo.mittel)
                        Text("schnell").tag(Lauftempo.schnell)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                    Text("Gilt nur, wenn der Text nicht ins Display passt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Lebensdauerabschnitt(behalten: $lebensdauerBehalten, zahl: $lebensdauerZahl,
                                     einheit: $lebensdauerEinheit, ablauf: $lebensdauerAblauf,
                                     aktiv: art == .anzeige)
                Nachrichtabschnitt(halten: $nachrichtHalten, aufwecken: $nachrichtAufwecken,
                                   ersetzen: $nachrichtErsetzen, durchlaeufe: $nachrichtDurchlaeufe,
                                   aktiv: art == .nachricht)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { amDauerfeld = false }
                }
            }
    }
}
