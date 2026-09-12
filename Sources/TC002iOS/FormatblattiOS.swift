import SwiftUI
import TC002Core

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau.
struct FormatblattiOS: View {
    @Binding var weg: SendeWeg
    @Binding var schrift: String
    @Binding var groesse: Double
    @Binding var fett: Bool
    @Binding var grossbuchstaben: Bool
    @Binding var rand: Int
    @Binding var abstand: Int
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Environment(\.dismiss) private var schliessen

    /// Dieselbe Auswahl wie auf dem Mac. Nur diese wenigen, weil bei sechzehn
    /// Pixeln Höhe kaum eine Schrift sauber aufs Raster fällt.
    private static let schriften = ["Micro 5", "Silkscreen", "Tiny5", "Geneva",
                                    "Monaco", "Andale Mono", "Menlo", "PT Mono"]

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
                Section("Schrift") {
                    Picker("Schriftart", selection: $schrift) {
                        ForEach(Self.schriften, id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(weg == .text)
                    Stepper(lokf("Größe %d", Int(groesse)), value: $groesse, in: 6...16, step: 1)
                    Toggle("Fett", isOn: $fett).disabled(weg == .text)
                    Toggle("Großbuchstaben", isOn: $grossbuchstaben)
                }
                Section("Lage") {
                    Stepper(lokf("Rand %d", rand), value: $rand, in: 0...3)
                    Stepper(lokf("Abstand %d", abstand), value: $abstand, in: 0...3)
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
    }
}
