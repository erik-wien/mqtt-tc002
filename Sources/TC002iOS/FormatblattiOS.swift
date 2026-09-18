import SwiftUI
import TC002Ansichten
import TC002Core

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
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Binding var dauerText: String
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Dauer (Sek.)") {
                        TextField("Uhr entscheidet", text: $dauerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
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
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }
}
