import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Welchen Teil des Formats ein Blatt zeigt. Zwei Knöpfe am Ende der
/// Formatpille (`SendeniOS`) öffnen je einen: die Uhr für Dauer und
/// Laufschrift, der Pinsel für die Darstellung.
enum Formatteil: String, Identifiable {
    case zeit, darstellung
    var id: String { rawValue }
}

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau. Schriftart (samt „Schrift der Uhr“),
/// beide Ausrichtungen, Größe, Fett, Großbuchstaben, Rand und Abstand sitzen
/// inzwischen in der Formatpille über dem Eingabefeld (SendeniOS.swift) — hier
/// bleiben Dauer und Laufschrift (Teil `zeit`) sowie die Darstellung (Teil
/// `darstellung`). „Icon mitscrollen“ steht beim Icon (`IconsblattiOS`).
/// Nachricht, Klang und Lebensdauer stehen nicht hier, sondern am Segment
/// „Anzeige | Nachricht“ (`Sendeartwahl`).
///
/// Die Dauer steht bei der Laufschrift, nicht als eigene Zeile neben den
/// fünf Blöcken — dort nähme sie die Breite weg, die die Blöcke brauchen.
/// Beide reisen mit dieser einen Anzeige mit, genau so wie der Zeit-Reiter
/// am Schreibtisch.
struct FormatblattiOS: View {
    @Bindable var zustand: AppZustand
    let teil: Formatteil
    @Binding var darstellung: Darstellungswahl
    @Binding var weg: SendeWeg
    @Binding var tempo: Lauftempo
    @Binding var dauerText: String
    var art: Sendeart = .anzeige
    var steht: Stehtbindungen?
    @Environment(\.dismiss) private var schliessen
    /// `.numberPad` hat keine Eingabetaste — ohne „Fertig" bleibt die Tastatur
    /// stehen. Dieselbe Leiste wie am Nummernfeld der Iconauswahl und am Port
    /// in den Einstellungen.
    @FocusState private var amDauerfeld: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch teil {
                case .zeit: zeitform
                case .darstellung:
                    Form {
                        Darstellungsabschnitte(zustand: zustand, wahl: $darstellung, weg: weg, art: art)
                    }
                }
            }
            .navigationTitle(teil == .zeit ? lok("Zeit") : lok("Darstellung"))
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
                    if art == .nachricht, let steht {
                        StehtWahl(steht: steht, zustand: zustand)
                    } else {
                        LabeledContent("Dauer (s)") {
                            TextField("Uhr entscheidet", text: $dauerText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($amDauerfeld)
                        }
                    }
                    Text(art.dauerErklaerung)
                        .font(.caption).foregroundStyle(.secondary)
                    if art == .anzeige { Standarddauerzeile(zustand: zustand) }
                } header: {
                    Abschnittskopf(art.nurDiese, hilfe: art.zeithilfe)
                }
                Section(art.laufschrifttitel) {
                    Picker("Tempo", selection: $tempo) {
                        Text("Langsam").tag(Lauftempo.langsam)
                        Text("Mittel").tag(Lauftempo.mittel)
                        Text("Schnell").tag(Lauftempo.schnell)
                    }
                    .pickerStyle(.segmented)
                    Text("Gilt nur, wenn der Text nicht ins Display passt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { amDauerfeld = false }
                }
            }
    }
}
