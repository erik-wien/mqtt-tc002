import SwiftUI
import TC002Core

/// **Die Filterleiste über einem Bestand** — Größe und Bewegung, für alle
/// Oberflächen und beide Bestände dieselbe.
///
/// Sie steht hier und nicht dreimal in den Blättern: Was ein Filter anbietet,
/// ist eine Entscheidung über das Programm, nicht über das Gerät. Wie er
/// eingebettet wird — Listenzeile am Telefon, Zeile unter dem Suchfeld am
/// Schreibtisch —, bleibt dem Aufrufer überlassen.
///
/// Über den Wert **allgemein**, weil die beiden Bestände verschieden zählen:
/// Das Auswahlblatt kennt Kantenlängen (8, 16), der Bestand im Editor
/// Leinwandgrößen (8 × 8, 16 × 16, 16 × 52). `nil` heißt in beiden Fällen
/// „alle“.
public struct Filterleiste<Wert: Hashable>: View {
    @Binding var wert: Wert?
    /// Beschriftung und Wert je Segment, in der angebotenen Reihenfolge. Die
    /// Beschriftung ist ein Übersetzungsschlüssel („8 × 8“), kein fertiger
    /// Text — deshalb `lok` und nicht `Text(_:)`.
    let angebot: [(titel: String, wert: Wert)]
    @Binding var nurBewegte: Bool

    public init(wert: Binding<Wert?>, angebot: [(titel: String, wert: Wert)],
                nurBewegte: Binding<Bool>) {
        self._wert = wert
        self.angebot = angebot
        self._nurBewegte = nurBewegte
    }

    public var body: some View {
        HStack(spacing: 10) {
            Picker("Größe", selection: $wert) {
                Text("alle").tag(nil as Wert?)
                ForEach(angebot, id: \.wert) { eintrag in
                    Text(lok(eintrag.titel)).tag(Optional(eintrag.wert))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // Kein Schalter mit Beschriftung daneben, sondern ein Knopf, der
            // eingerastet bleibt: Er sagt an derselben Stelle, was er tut und
            // ob er gerade tut. Das Zeichen ist dasselbe wie an den bewegten
            // Einträgen in der Liste.
            Toggle(isOn: $nurBewegte) {
                Label("bewegte", systemImage: "play.fill")
            }
            .toggleStyle(.button)
            .help("Nur Einträge zeigen, die sich bewegen")
        }
    }
}
