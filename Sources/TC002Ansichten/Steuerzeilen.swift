import SwiftUI
import TC002Core

/// Die Zeilen, die die Steuerungsseite und die Gruppen der Uhreinstellungen
/// gemeinsam brauchen. Beschriftungen kommen fertig übersetzt herein (`lok(…)`):
/// Ein gewöhnliches `String` schlägt SwiftUI nicht nach.

/// Ein Regler, der den Wert der Uhr zeigt und erst beim Loslassen sendet.
///
/// Während des Ziehens gilt der gezogene Wert; sobald die Uhr einen neuen Stand
/// meldet oder drei Sekunden vergangen sind, wieder der der Uhr. Sonst bliebe
/// ein Wert stehen, den die Uhr abgewiesen hat.
struct Wertregler: View {
    let titel: String
    /// Der Stand der Uhr, in den Einheiten des Reglers.
    let wert: Int
    let bereich: ClosedRange<Int>
    var schritt: Int = 1
    /// Wie der Wert neben dem Regler steht.
    let anzeige: (Int) -> String
    /// Grau und ohne Wirkung: der Wert wird von woanders bestimmt (Lichtsensor)
    /// oder ist noch nicht gelesen.
    var gesperrt = false
    let setzen: (Int) -> Void

    @State private var gezogen: Double?
    @State private var rueckfall: Task<Void, Never>?

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: Binding(get: { gezogen ?? Double(wert) }, set: { gezogen = $0 }),
                       in: Double(bereich.lowerBound)...Double(bereich.upperBound),
                       step: Double(schritt)) { bearbeitet in
                    guard !bearbeitet, let ziel = gezogen else { return }
                    setzen(Int(ziel.rounded()))
                    rueckfall?.cancel()
                    rueckfall = Task {
                        try? await Task.sleep(for: .seconds(3))
                        if !Task.isCancelled { gezogen = nil }
                    }
                }
                .disabled(gesperrt)
                .accessibilityLabel(Text(verbatim: titel))
                Text(verbatim: anzeige(Int((gezogen ?? Double(wert)).rounded())))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        } label: {
            Text(verbatim: titel)
        }
        .onChange(of: wert) { _, _ in gezogen = nil }
        .onDisappear { rueckfall?.cancel() }
    }
}

/// Eine Farbe der Uhr: Kreis in der Farbe, gesendet erst, wenn sie eine Weile
/// still steht — die Palette liefert beim Ziehen Dutzende Werte.
struct Farbzeile: View {
    let titel: String
    /// `#RRGGBB` der Uhr; `nil` bei einer Farbe, die ausgeschaltet sein kann.
    let hex: String?
    let setzen: (String) -> Void

    @State private var farbe: Color = .white
    /// Die Farbe, die zuletzt von der Uhr kam oder gesendet wurde; nur eine
    /// Abweichung davon ist eine Eingabe.
    @State private var bekannt = "#FFFFFF"

    var body: some View {
        LabeledContent {
            Farbkreis(farbe: $farbe)
        } label: {
            Text(verbatim: titel)
        }
        .onAppear { uebernehmen() }
        .onChange(of: hex) { _, _ in uebernehmen() }
        .task(id: farbe.hexWert) {
            let neu = farbe.hexWert
            guard neu != bekannt else { return }
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled { bekannt = neu; setzen(neu) }
        }
    }

    private func uebernehmen() {
        guard let hex, let c = Color(hex: hex) else { return }
        farbe = c
        bekannt = c.hexWert
    }
}

/// Eine Zahl mit Schrittwahl, die sofort sendet.
struct Zahlzeile: View {
    let titel: String
    let wert: Int
    let bereich: ClosedRange<Int>
    var schritt: Int = 1
    let anzeige: (Int) -> String
    let setzen: (Int) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Text(verbatim: anzeige(wert))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                Stepper(value: Binding(get: { wert }, set: { setzen($0) }), in: bereich, step: schritt) {
                    Text(verbatim: titel)
                }
                .labelsHidden()
            }
        } label: {
            Text(verbatim: titel)
        }
    }
}
