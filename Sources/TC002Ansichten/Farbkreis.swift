import SwiftUI
import TC002Core

/// **Ein Farbfeld, das man auch dann als solches erkennt, wenn es weiß ist.**
///
/// Das Systemfeld (`ColorPicker`) zeigt am Mac eine Pille, unter iPadOS eine
/// nackte Pille ohne den Regenbogenkreis, den der Mac danebenstellt. Ist die
/// gewählte Farbe weiß, steht dort ein weißer Fleck auf hellem Grund — man
/// sieht nicht mehr, dass das überhaupt ein Bedienelement ist, geschweige
/// denn welches.
///
/// **Ein offizielles Element dafür gibt es nicht.** Nachgesehen im SDK
/// (18.09.2026): `ColorPicker` kennt `selection`, `supportsOpacity` und ein
/// `label` — das Etikett steht *neben* dem Farbfeld und ersetzt es nicht —,
/// und einen `colorPickerStyle` gibt es in SwiftUI nicht, obwohl es für
/// Knöpfe, Menüs, Listen und selbst Datumswähler einen gibt. Wie das Feld
/// aussieht, entscheidet allein das System.
///
/// Deshalb das Vorbild aus Pages nachgebaut: ein Kreis in der gewählten Farbe,
/// umlegt von einem Regenbogenring. Der Ring gehört nicht zur Farbe, er gehört
/// zum **Element** — er bleibt sichtbar, gleich was gewählt ist.
///
/// **Die Systempalette bleibt.** Gezeichnet wird nur das Gesicht; der Auslöser
/// ist ein unsichtbar darübergelegter `ColorPicker`. Kein AppKit, kein
/// Nachbau einer Farbpalette — beides wäre hier auch gar nicht erlaubt
/// (`TC002Ansichten` kennt keine Plattform).
public struct Farbkreis: View {
    @Binding private var farbe: Color
    private let kante: Double

    public init(farbe: Binding<Color>, kante: Double = 22) {
        self._farbe = farbe
        self.kante = kante
    }

    /// Der Ring. Rot steht am Anfang **und** am Ende, sonst klafft dort, wo
    /// sich der Kreis schließt, eine harte Kante.
    private static let regenbogen: [Color] = [
        .red, .yellow, .green, .cyan, .blue, .purple, .red,
    ]

    public var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: Self.regenbogen, center: .center))
            Circle()
                .fill(farbe)
                .padding(3)
            // Die Kante zwischen Füllung und Ring — ohne sie fließt eine helle
            // Farbe in den gelben Teil des Rings über.
            Circle()
                .strokeBorder(.separator, lineWidth: 0.5)
                .padding(3)
            // **Unsichtbar, aber treffbar.** `opacity` nimmt einer Ansicht
            // nicht ihre Trefferfläche; der Klick landet also im Systemfeld
            // und öffnet dessen Palette, während man den Kreis darunter sieht.
            // Nicht ganz null, damit kein Optimierer auf den Gedanken kommt,
            // die Ansicht wegzulassen.
            ColorPicker("Farbe", selection: $farbe, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02)
                .frame(width: kante, height: kante)
                .clipped()
        }
        .frame(width: kante, height: kante)
        .help(lok("Farbe"))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Farbe"))
    }
}
