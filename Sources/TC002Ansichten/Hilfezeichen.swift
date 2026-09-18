import SwiftUI
import TC002Core

/// Ein kleines (?) mit einer Erklärung dahinter — sichtbar und antippbar.
///
/// Warum es das gibt: Der Inspektor erklärt seine Regler seit jeher über
/// `.help(…)`: ein Einblendtext beim Verweilen mit der Maus. Am Mac genügt
/// das. Am iPad gibt es ohne Zeiger kein Verweilen, und damit war jede
/// Erklärung dort unerreichbar — `Gattungssperre.swift` hält denselben Mangel
/// für die Sperrgründe fest, und das Rückstandsdokument führte ihn als offene
/// Entscheidung über die Oberfläche. Dies ist die Antwort darauf: derselbe
/// Text, aber zusätzlich hinter einem Zeichen, das man sieht und trifft.
///
/// Der Text steht deshalb zweimal dran — als `.help` fürs Verweilen und im
/// Blatt für den Klick. Das ist kein zweiter Übersetzungsschlüssel: Er wird
/// einmal gereicht und einmal nachgeschlagen (die Aufrufer geben ihn schon
/// durch `lok(…)` gegangen herein, weil ein gewöhnliches `String` sonst
/// deutsch bliebe).
///
/// `presentationCompactAdaptation(.popover)`, damit es auch in einer schmalen
/// Umgebung ein kleines Blatt am Zeichen bleibt und nicht als volle Seite von
/// unten hereinfährt — es ist eine Fußnote, keine Ansicht.
public struct Hilfezeichen: View {
    private let text: String
    private let warnung: Bool
    @State private var zeigt = false

    /// `text` ist fertig übersetzt hereinzugeben (`lok(…)`): Er wird als
    /// gewöhnliches `String` weitergereicht, und das schlägt SwiftUI nicht nach.
    ///
    /// `warnung: true` macht daraus dasselbe Zeichen mit anderer Aussage: ein
    /// oranges Dreieck statt des Fragezeichens. Es steht dort, wo nicht bloß
    /// etwas zu erklären, sondern etwas im Weg ist — eine Wahl, die so nicht
    /// ankommen kann. Derselbe Bau, weil der Grund auf beiden Oberflächen
    /// antippbar sein muss und nicht nur beim Verweilen erscheinen darf.
    public init(_ text: String, warnung: Bool = false) {
        self.text = text
        self.warnung = warnung
    }

    public var body: some View {
        Button { zeigt = true } label: {
            Image(systemName: warnung ? "exclamationmark.triangle.fill" : "questionmark.circle")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(warnung ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        .help(text)
        // `lok` in beiden Zweigen: Ein Ternär mit zwei Zeichenketten zwingt
        // `Text` in die `StringProtocol`-Überladung, und die schlägt nichts
        // nach — beide Wörter stünden in `en.lproj` und blieben trotzdem
        // deutsch (CLAUDE.md, „Sprachen").
        .accessibilityLabel(Text(warnung ? lok("Warnung") : lok("Hilfe")))
        .popover(isPresented: $zeigt) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(width: 280)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Eine Gruppenüberschrift mit ihrer Erklärung rechts daneben.
///
/// Rechtsbündig und nicht neben dem einzelnen Feld: Eine Erklärung je Zeile
/// ergäbe eine Spalte von Fragezeichen und nähme den engen Zeilen des
/// Inspektors Breite, die sie für Schriftnamen und Nummern brauchen. Am Kopf
/// steht sie einmal für den ganzen Abschnitt — und dort, wo das Auge ohnehin
/// hinsieht, bevor es die Regler darunter liest.
///
/// Der Titel geht als `LocalizedStringKey` an `Text` und wird von SwiftUI
/// selbst nachgeschlagen; die Erklärung ist ein gewöhnliches `String` und
/// gehört vorher durch `lok(…)`.
public struct Abschnittskopf: View {
    private let titel: LocalizedStringKey
    private let hilfe: String

    public init(_ titel: LocalizedStringKey, hilfe: String) {
        self.titel = titel
        self.hilfe = hilfe
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(titel)
            Spacer(minLength: 8)
            Hilfezeichen(hilfe)
        }
    }
}
