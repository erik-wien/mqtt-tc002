import SwiftUI
import TC002Core

/// Die Zeilen, die die Steuerungsseite und die Gruppen der Uhreinstellungen
/// gemeinsam brauchen. Beschriftungen kommen fertig übersetzt herein (`lok(…)`):
/// Ein gewöhnliches `String` schlägt SwiftUI nicht nach.

/// Ein Regler, der den Wert der Uhr zeigt und genau einmal sendet: beim
/// Loslassen, bei Pfeiltasten und VoiceOver (die kein Loslassen melden) nach
/// kurzer Ruhe. Nimmt die Uhr die Sendung an, steht neben dem Regler 1,5 s ein
/// Häkchen; sonst zeigt die Fehlerleiste, woran es lag (`setzen` liefert, ob
/// die Uhr es genommen hat).
///
/// Während des Ziehens gilt der gezogene Wert; sobald die Uhr einen neuen Stand
/// meldet oder drei Sekunden vergangen sind, wieder der der Uhr. Sonst bliebe
/// ein Wert stehen, den die Uhr abgewiesen hat. Der Ablauf selbst ist
/// `Reglerablauf` im Kern; wer den Regler für eine andere Uhr zeigt, gibt ihm
/// eine andere `.id`, damit nichts von der vorigen stehen bleibt.
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
    /// Sendet und meldet, ob die Uhr es genommen hat.
    let setzen: (Int) async -> Bool

    @State private var ablauf = Reglerablauf()
    @State private var rueckfall: Task<Void, Never>?
    @State private var ruhe: Task<Void, Never>?
    @State private var haekchen: Task<Void, Never>?

    private var gezeigt: Double { ablauf.wert ?? Double(wert) }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: Binding(get: { gezeigt }, set: { geaendert($0) }),
                       in: Double(bereich.lowerBound)...Double(bereich.upperBound),
                       step: Double(schritt)) { aktiv in
                    ablauf.bearbeitet(aktiv)
                    ruhe?.cancel()
                    if !aktiv, let ziel = ablauf.loslassen() { senden(ziel) }
                }
                .disabled(gesperrt)
                .accessibilityLabel(Text(verbatim: titel))
                Text(verbatim: anzeige(Int(gezeigt.rounded())))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
                // Der Platz bleibt reserviert, sonst sprängen Regler und Wert
                // beim Ein- und Ausblenden.
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .opacity(ablauf.phase == .bestaetigt ? 1 : 0)
                    .accessibilityHidden(ablauf.phase != .bestaetigt)
                    .accessibilityLabel(Text("Gesendet"))
            }
        } label: {
            Text(verbatim: titel)
        }
        .onChange(of: wert) { _, _ in ablauf.uhrMeldet() }
        .onDisappear { rueckfall?.cancel(); ruhe?.cancel(); haekchen?.cancel() }
    }

    /// Ein neuer Wert vom Regler. Ohne Berührung (Tastatur, VoiceOver) kommt
    /// kein Loslassen; dann sendet die Ruhe nach der letzten Verstellung.
    private func geaendert(_ neu: Double) {
        ablauf.aendert(neu)
        ruhe?.cancel()
        ruhe = Task {
            try? await Task.sleep(for: .seconds(Reglerablauf.ruhefrist))
            if !Task.isCancelled, let ziel = ablauf.ruhe() { senden(ziel) }
        }
    }

    private func senden(_ ziel: Int) {
        haekchen?.cancel()
        Task {
            let genommen = await setzen(ziel)
            ablauf.antwort(erfolg: genommen)
            guard genommen else { return }
            AccessibilityNotification.Announcement(lok("Gesendet")).post()
            haekchen = Task {
                try? await Task.sleep(for: .seconds(Reglerablauf.haekchendauer))
                if !Task.isCancelled { withAnimation(.easeOut(duration: 0.4)) { ablauf.haekchenFertig() } }
            }
        }
        rueckfall?.cancel()
        rueckfall = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { ablauf.uhrMeldet() }
        }
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
