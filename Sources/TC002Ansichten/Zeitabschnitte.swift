import SwiftUI
import TC002Core
import TC002Modell

/// Wie lange etwas zu sehen ist — Dauer, und bei „Senden“ das Lauftempo, an
/// einer Stelle: Beide reisen mit einer Meldung mit (`durationMs` und
/// `scroll.speed` in der Nutzlast).
///
/// Von „Senden" und „Editor" gemeinsam benutzt — zwei Fassungen derselben
/// Regler liefen früher oder später auseinander.
struct Zeitabschnitte<Zusatz: View>: View {
    @Bindable var zustand: AppZustand
    /// Die Dauer gehört der jeweiligen Ansicht: Sie ist Teil des Auftrags, der
    /// dort zusammengestellt wird, und nicht Zustand dieses Bausteins.
    @Binding var dauerText: String
    /// Was gerade geschickt wird; bestimmt die Worte der Überschrift.
    var art: Sendeart = .anzeige
    /// Bei einer Nachricht ersetzt „Steht …“ das Feld „Dauer (s)“ — dieselben
    /// Bindungen wie im Optionenblatt, damit es nur eine Einstellung gibt.
    var steht: Stehtbindungen?

    /// Was die Ansicht sonst noch zur einzelnen Meldung zu sagen hat — bei
    /// „Senden“ das Lauftempo, im Editor nichts.
    ///
    /// Als Platz statt als Parameter, weil das Tempo an `weg` und `passt`
    /// hängt: Zustand der Sendeansicht. Ihn hierher zu reichen hieße, drei
    /// Werte durchzugeben, damit dieser Baustein entscheiden kann, was der
    /// Aufrufer längst weiß.
    ///
    /// Und innerhalb von „Nur diese Meldung“, nicht darüber: Das Tempo
    /// reist mit der Meldung mit wie die Dauer. Ein eigener Abschnitt daneben
    /// ließe offen, für wie viele Anzeigen er gilt — und genau diese Frage war
    /// hier schon einmal die falsch beantwortete.
    @ViewBuilder let zusatz: Zusatz

    /// Text im Feld, der keine ganze Zahl ist: Gesendet wird er nie, das Feld
    /// würde sonst stumm als leer gelten.
    private var dauerUngueltig: Bool {
        let t = dauerText.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && Int(t) == nil
    }

    var body: some View {
        // Die Ueberschriften nennen die Reichweite, nicht den Gegenstand:
        // Beide Abschnitte handeln von Sekunden, und woran die Sekunden
        // haengen, sagt der Gegenstand allein nicht. „Nur diese Meldung"
        // gegen „Alles, was diese Uhr zeigt" sagt es in der Ueberschrift
        // selbst.
        Section {
            if art == .nachricht, let steht {
                StehtWahl(steht: steht)
            } else {
                LabeledContent("Dauer (s)") {
                    TextField("", text: $dauerText)
                        .eingabefeld()
                        .frame(minWidth: 70)
                        #if !os(macOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }
            if art == .nachricht, steht != nil {
                Text(art.dauerErklaerung)
                    .font(.footnote).foregroundStyle(.secondary)
            } else if dauerUngueltig {
                Text("Das ist keine ganze Zahl — es gilt keine eigene Dauer.")
                    .font(.footnote).foregroundStyle(.red)
            } else {
                Text(art.dauerErklaerung)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Abschnittskopf(art.nurDiese, hilfe: art.zeithilfe)
        }

        // Ein eigener Abschnitt, keine Zeile im vorigen: Im schmalen
        // Inspektor faellt die Beschriftung eines Segmentschalters weg — als
        // Zeile unter „Dauer (s)" waere er ein namenloses „langsam mittel
        // schnell" und laese sich als Teil der Dauer.
        //
        // Der Abschnitt bringt seine Ueberschrift selbst mit, und die faellt
        // nicht weg. Was er dabei einbuesst — die Naehe zur Dauer, mit der er
        // die Reichweite teilt —, holt sein Fusstext zurueck: Er sagt
        // ausdruecklich, dass er nur fuer diese eine Meldung gilt.
        zusatz
    }
}

extension Zeitabschnitte where Zusatz == EmptyView {
    /// Für Aufrufer ohne eigene Zeile — der Editor kennt keine Laufschrift.
    init(zustand: AppZustand, dauerText: Binding<String>) {
        self.init(zustand: zustand, dauerText: dauerText, steht: nil) { EmptyView() }
    }
}
