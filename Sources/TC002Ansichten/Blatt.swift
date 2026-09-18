import SwiftUI
import TC002Core

/// Der Rahmen eines Blattes: Titel, Inhalt, Abbrechen und die Haupthandlung.
///
/// **Die beiden Plattformen setzen die Knöpfe verschieden, und beide haben
/// recht.** Am Mac stehen sie unten rechts im Blatt, die Haupthandlung ganz
/// außen; unter iOS gehören sie in die Navigationsleiste, Abbrechen links,
/// Bestätigen rechts. Wer eines von beidem überall nimmt, ist auf der anderen
/// Seite falsch — deshalb hier einmal die Fallunterscheidung statt in jedem
/// Blatt eine handgebaute Zeile.
///
/// `#if os(macOS)` und kein `import AppKit`: Die Regel in CLAUDE.md verbietet
/// die Plattform-Bausteine, nicht die Frage, auf welcher Plattform man steht —
/// `SchreibtischView` und `EditorBereichView` stellen sie längst.
struct Blatt<Inhalt: View>: View {
    let titel: String
    /// Beschriftung der Haupthandlung. `nil` heißt: Es gibt nur einen Weg
    /// hinaus, und der heißt „Fertig".
    var bestaetigung: String?
    var bestaetigenMoeglich: Bool = true
    let schliessen: () -> Void
    var bestaetigen: (() -> Void)?
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 14) {
            Text(titel).font(.headline)
            inhalt()
            HStack {
                Spacer()
                Button(bestaetigung == nil ? lok("Fertig") : lok("Abbrechen")) { schliessen() }
                    .knopfBefehl()
                    .keyboardShortcut(.cancelAction)
                if let bestaetigung, let bestaetigen {
                    Button(bestaetigung) { bestaetigen() }
                        .knopfHaupthandlung()
                        .keyboardShortcut(.defaultAction)
                        .disabled(!bestaetigenMoeglich)
                }
            }
        }
        .padding(20)
        #else
        NavigationStack {
            inhalt()
                .navigationTitle(titel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(bestaetigung == nil ? lok("Fertig") : lok("Abbrechen")) {
                            schliessen()
                        }
                    }
                    if let bestaetigung, let bestaetigen {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(bestaetigung) { bestaetigen() }
                                .disabled(!bestaetigenMoeglich)
                        }
                    }
                }
        }
        #endif
    }
}
