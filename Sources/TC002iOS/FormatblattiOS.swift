import SwiftUI
import TC002Ansichten
import TC002Core

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau. Schriftart, beide Ausrichtungen,
/// Größe, Fett, Großbuchstaben, Rand und Abstand sitzen inzwischen in der
/// Formatpille über dem Eingabefeld (SendeniOS.swift) — hier bleiben Weg,
/// Dauer und Laufschrift.
///
/// **Die Dauer kam am 14.09.2026 dazu.** Sie stand als eigene Zeile neben den
/// fünf Blöcken und nahm dort die Breite weg, die die Blöcke brauchen. Hier
/// steht sie bei der Laufschrift — beide reisen mit *dieser einen* Meldung
/// mit, und genau so hält es der Zeit-Reiter am Schreibtisch.
struct FormatblattiOS: View {
    @Binding var weg: SendeWeg
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Binding var dauerText: String
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
                } header: {
                    // Derselbe Wortlaut wie im Inspektor am Schreibtisch —
                    // eine Konstante waere hier eine ueber zwei Ziele hinweg;
                    // der Sammler fuehrt beide auf denselben Schluessel.
                    Abschnittskopf("Senden als", hilfe: lok("Als Pixel rechnet die App das Bild selbst; passt der Text nicht, baut sie den Lauf als GIF. Als Text setzt ihn die Uhr mit ihrer eingebauten Schrift und lässt ihn bei Bedarf selbst durchlaufen — das Tempo steht dann in den Einstellungen der Uhr."))
                }
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
