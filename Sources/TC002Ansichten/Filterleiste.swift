import SwiftUI
import TC002Core

/// Die Filterleiste über einem Bestand — Größe und Bewegung, für alle
/// Oberflächen und beide Bestände dieselbe.
///
/// Sie steht hier und nicht dreimal in den Blättern: Was ein Filter anbietet,
/// ist eine Entscheidung über das Programm, nicht über das Gerät. Wie er
/// eingebettet wird — Listenzeile am Telefon, Zeile unter dem Suchfeld am
/// Schreibtisch —, bleibt dem Aufrufer überlassen.
///
/// Über den Wert allgemein, weil die beiden Bestände verschieden zählen:
/// Das Auswahlblatt kennt Kantenlängen (8, 16), der Bestand im Editor
/// Leinwandgrößen (8 × 8, 16 × 16, 16 × 52). `nil` heißt in beiden Fällen
/// „alle“.
public struct Filterleiste<Wert: Hashable>: View {
    @Binding var wert: Wert?
    /// Beschriftung, Kurzform und Wert je Segment, in der angebotenen
    /// Reihenfolge. Die Beschriftungen sind Übersetzungsschlüssel („8 × 8“),
    /// keine fertigen Texte — deshalb `lok` und nicht `Text(_:)`.
    let angebot: [(titel: String, kurz: String, wert: Wert)]
    @Binding var nurBewegte: Bool

    public init(wert: Binding<Wert?>, angebot: [(titel: String, kurz: String, wert: Wert)],
                nurBewegte: Binding<Bool>) {
        self._wert = wert
        self.angebot = angebot
        self._nurBewegte = nurBewegte
    }

    /// Nachgebend, nicht abschneidend: Im Inspektor des Editors sind es vier
    /// Segmente und ein Schalter auf rund 280 Punkten — am iPad, wo die
    /// Zeilenschrift 17 statt 13 Punkte misst, wurde daraus
    /// „alle · 8… · 16… · 16…". Zwei abgeschnittene Beschriftungen, die
    /// dasselbe zeigen, sind schlimmer als eine kurze, die unterscheidet.
    ///
    /// `ViewThatFits` probiert deshalb zuerst die ausgeschriebenen Größen und
    /// fällt erst dann auf die kurzen zurück — auf breiten Blättern ändert
    /// sich nichts.
    public var body: some View {
        ViewThatFits(in: .horizontal) {
            leiste(kurz: false)
            leiste(kurz: true)
        }
    }

    private func leiste(kurz: Bool) -> some View {
        HStack(spacing: 10) {
            Picker("Größe", selection: $wert) {
                Text("alle").tag(nil as Wert?)
                ForEach(angebot, id: \.wert) { eintrag in
                    Text(lok(kurz ? eintrag.kurz : eintrag.titel)).tag(Optional(eintrag.wert))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            // Nur das Zeichen, kein Wort: „bewegte" wurde am Mac zu „b…" und
            // am iPad zu „beweg-te" über zwei Zeilen. Es ist dasselbe Zeichen,
            // das in jeder Zeile der Liste die bewegten Einträge markiert;
            // daneben steht kein zweites, mit dem es zu verwechseln wäre. Für
            // die Sprachausgabe steht der Name weiterhin da.
            Toggle(isOn: $nurBewegte) {
                Label("bewegte", systemImage: "play.fill")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .help("Nur Einträge zeigen, die sich bewegen")
            .accessibilityLabel(Text("bewegte"))
            Spacer(minLength: 0)
        }
    }
}
