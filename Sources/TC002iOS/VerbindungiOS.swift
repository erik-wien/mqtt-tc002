import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Die Einstellungen am Telefon: eine Liste der fünf Themen, jedes Thema eine
/// eigene Seite.
///
/// **Der eine Unterschied zum Schreibtisch, und sein Grund.** Dort wählt eine
/// Segmentwahl über dem Inhalt das Thema. Auf dem Telefon ist dafür kein Platz
/// — fünf Wörter nebeneinander schrumpfen auf Kürzel —, und eine Reiterleiste
/// in einem Blatt ist dort nicht üblich: Reiter gehören der App, nicht einem
/// Blatt. Der Einstieg ist deshalb eine Liste mit `NavigationLink`, die Bauart
/// der Einstellungen-App. Die Inhalte der Seiten sind **dieselben Bausteine**
/// wie am Schreibtisch (`Einstellungsinhalt`).
struct VerbindungiOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen
    @State private var zeigeVirtuelleUhr = false
    @State private var zeigeHilfe = false
    @State private var zeigeUeber = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                List {
                    Section {
                        ForEach(Einstellungsthema.allCases) { thema in
                            NavigationLink(value: thema) {
                                Label { Text(thema.titel) } icon: {
                                    Image(systemName: thema.symbol)
                                }
                            }
                        }
                    }
                    ueberAbschnitt
                }
            }
            .navigationDestination(for: Einstellungsthema.self) { thema in
                Einstellungsinhalt(zustand: zustand, thema: thema, kanon: .telefon,
                                   virtuelleUhrAnsehen: { zeigeVirtuelleUhr = true })
                    .navigationTitle(thema.titel)
            }
            // Wie am Schreibtisch: beim Aufschlagen fragen, nicht erst auf
            // Druck (`AppZustand.alleAbfragen`).
            .task { zustand.alleAbfragen() }
            .navigationTitle("Einstellungen")
            // Format- und Icon-Blatt haben "Fertig" bzw. "Abbrechen" in der
            // Titelleiste, dieses hatte nur den Greifer — uneinheitlich, und
            // ohne ausdruecklichen Weg hinaus.
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $zeigeVirtuelleUhr) { VirtuelleUhrView(betrieb: .gemeinsam) }
        .sheet(isPresented: $zeigeHilfe) { HilfeiOS() }
        .sheet(isPresented: $zeigeUeber) { UeberiOS() }
    }

    /// Hilfe und Über am Fuß der Einstellungen. iOS stellt für „Über“ keine
    /// Stelle bereit — macOS hat das Apple-Menü, hier gibt es nichts
    /// dergleichen —, und die eingebürgerte Stelle ist das Ende der
    /// App-eigenen Einstellungen. Die obere Leiste der Sendeansicht bleibt
    /// bei ihren zwei Symbolen: ein drittes Fragezeichen ist auf dem iPhone
    /// kein verbreitetes Muster.
    private var ueberAbschnitt: some View {
        Section {
            // Zwei Listenzeilen, keine Befehlsknoepfe: Sie fuehren weiter,
            // statt etwas zu tun, und eine Formularzeile ist auf dem Telefon
            // selbst schon als antippbar zu erkennen. Ausdruecklich
            // `.automatic`, damit die Entscheidung im Quelltext steht.
            Button("Hilfe") { zeigeHilfe = true }
                .buttonStyle(.automatic)
            Button("Über Pixel Clock Messenger") { zeigeUeber = true }
                .buttonStyle(.automatic)
        }
    }
}
