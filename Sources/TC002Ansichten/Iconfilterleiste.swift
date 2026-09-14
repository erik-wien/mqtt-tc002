import SwiftUI
import TC002Core

/// **Die Filterleiste über dem Icon-Raster** — Größe und Bewegung, für alle
/// Oberflächen dieselbe.
///
/// Sie steht hier und nicht zweimal in den beiden Auswahlblättern: Was ein
/// Filter anbietet, ist eine Entscheidung über das Programm, nicht über das
/// Gerät. Wie er dort eingebettet wird — Listenzeile am Telefon, Zeile unter
/// dem Suchfeld am Schreibtisch —, bleibt den Blättern überlassen.
///
/// „alle" gibt es zweimal, einmal je Frage; die Segmentwahl trägt ihre
/// Beschriftung nicht sichtbar, weil die Antworten sich selbst erklären.
public struct Iconfilterleiste: View {
    /// Kantenlänge in Pixeln, `nil` heißt beide Größen.
    @Binding var kante: Int?
    @Binding var nurBewegte: Bool

    public init(kante: Binding<Int?>, nurBewegte: Binding<Bool>) {
        self._kante = kante
        self._nurBewegte = nurBewegte
    }

    public var body: some View {
        HStack(spacing: 10) {
            Picker("Größe", selection: $kante) {
                Text("alle").tag(nil as Int?)
                Text("8 × 8").tag(8 as Int?)
                Text("16 × 16").tag(16 as Int?)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // Kein Schalter mit Beschriftung daneben, sondern ein Knopf, der
            // eingerastet bleibt: Er sagt an derselben Stelle, was er tut und
            // ob er gerade tut. Das Zeichen ist dasselbe wie an den bewegten
            // Icons in der Liste.
            Toggle(isOn: $nurBewegte) {
                Label("bewegte", systemImage: "play.fill")
            }
            .toggleStyle(.button)
            .help("Nur Icons zeigen, die sich bewegen")
        }
    }
}
