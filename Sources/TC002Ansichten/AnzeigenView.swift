import SwiftUI
import TC002Core
import TC002Modell

/// Das Protokoll — die technische Mitschrift. Was auf der Uhr liegt, zeigen
/// die fünf Blöcke unter „Senden"; eine zweite Liste daneben war dieselbe
/// Auskunft an einer Stelle, an der sie niemand suchte.
public struct AnzeigenView: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) { self.zustand = zustand }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Ausgeschaltet ist der Bereich gar nicht da: Eine Ueberschrift
            // ueber einer leeren Liste ist Flaeche ohne Aussage; dass es ein
            // Protokoll gibt und wie man es einschaltet, sagt der Schalter in
            // den Einstellungen.
            if zustand.protokollAn {
                HStack {
                    Text("Protokoll").font(.headline)
                    Spacer()
                    Button("Leeren", role: .destructive) { zustand.protokoll.removeAll() }
                        .knopfZerstoerend()
                        .disabled(zustand.protokoll.isEmpty)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(zustand.protokoll.enumerated()), id: \.offset) { _, zeile in
                            Text(zeile)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(.footnote, design: .monospaced))
            }
        }
        .padding()
    }
}
