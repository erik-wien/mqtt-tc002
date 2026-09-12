import SwiftUI
import TC002Core

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau. Schriftart, beide Ausrichtungen,
/// Größe, Fett, Großbuchstaben, Rand und Abstand sitzen inzwischen in der
/// Formatpille über dem Eingabefeld (SendeniOS.swift) — hier bleiben nur noch
/// Weg und Laufschrift.
struct FormatblattiOS: View {
    @Binding var weg: SendeWeg
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weg", selection: $weg) {
                        Text("als Pixel").tag(SendeWeg.pixel)
                        Text("als Text").tag(SendeWeg.text)
                    }
                    .pickerStyle(.segmented)
                    if weg == .pixel {
                        Text("Die App rastert selbst. Umlaute gehen, die Schrift ist frei wählbar.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Die Uhr setzt selbst, mit ihrer eingebauten Schrift. Die kennt keine Umlaute.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
