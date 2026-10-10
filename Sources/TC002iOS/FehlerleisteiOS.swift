import SwiftUI
import TC002Ansichten
import TC002Modell

/// Zeigt `AppZustand.fehler` als schmale Leiste unter der Titelleiste.
///
/// Ausdrücklich kein Blatt: Ein Blatt verdeckte die Vorschau, und die
/// Meldungen sind Hinweise, keine Entscheidungen. Wegtippen räumt sie weg;
/// im Protokoll unter „Verlauf" stehen sie ohnehin weiter.
struct FehlerleisteiOS: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        if let fehler = zustand.fehler {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Warnfarbe.symbol)
                    .accessibilityLabel(Text("Fehler"))
                Text(fehler).font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    zustand.fehler = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                // Trefferfläche 44 × 44 pt, das Zeichen bleibt klein.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Schließen")
            }
            .padding(10)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            // Die Leiste erscheint ohne Zutun des Anwenders; ohne Ansage
            // erfährt die Sprachausgabe nicht, dass etwas schiefging.
            .onAppear { AccessibilityNotification.Announcement(fehler).post() }
            .onChange(of: fehler) { _, neu in AccessibilityNotification.Announcement(neu).post() }
        }
    }
}
