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
    private let gewicht: Gewicht

    /// Wie dringend das ist, was dahintersteht.
    ///
    /// Drei Faelle, weil es drei gibt: eine Erklaerung, ein Hinweis auf etwas,
    /// das nur zum Teil gelungen ist, und eine Sperre. Der Auftraggeber:
    /// *„gemischte empfänger: gelbes Dreieck, keine TC oder nur TC001: rotes
    /// dreieck."* Beides mit derselben Farbe zu zeigen hiesse, „es ist etwas
    /// angekommen" und „es kann nichts ankommen" gleich auszusehen.
    public enum Gewicht: Equatable, Sendable {
        /// Ein (?) — hier steht eine Erklaerung.
        case erklaerung
        /// Ein gelbes Dreieck — etwas ist gelungen, etwas nicht.
        case teilweise
        /// Ein rotes Dreieck — so geht es gar nicht.
        case sperre

        var zeichen: String {
            self == .erklaerung ? "questionmark.circle" : "exclamationmark.triangle.fill"
        }

        var farbe: AnyShapeStyle {
            switch self {
            case .erklaerung: return AnyShapeStyle(.secondary)
            case .teilweise: return AnyShapeStyle(.yellow)
            case .sperre: return AnyShapeStyle(.red)
            }
        }

        var wort: String {
            self == .erklaerung ? lok("Hilfe") : lok("Warnung")
        }
    }
    @State private var zeigt = false

    /// `text` ist fertig übersetzt hereinzugeben (`lok(…)`): Er wird als
    /// gewöhnliches `String` weitergereicht, und das schlägt SwiftUI nicht nach.
    ///
    /// `gewicht` macht daraus dasselbe Zeichen mit anderer Aussage: ein
    /// Dreieck statt des Fragezeichens, gelb oder rot. Es steht dort, wo nicht
    /// bloß etwas zu erklären, sondern etwas im Weg ist. Derselbe Bau, weil
    /// der Grund auf beiden Oberflächen antippbar sein muss und nicht nur beim
    /// Verweilen erscheinen darf.
    public init(_ text: String, gewicht: Gewicht = .erklaerung) {
        self.text = text
        self.gewicht = gewicht
    }

    public var body: some View {
        Button { zeigt = true } label: {
            Image(systemName: gewicht.zeichen)
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(gewicht.farbe)
        .help(text)
        // `lok` in beiden Zweigen: Ein Ternär mit zwei Zeichenketten zwingt
        // `Text` in die `StringProtocol`-Überladung, und die schlägt nichts
        // nach — beide Wörter stünden in `en.lproj` und blieben trotzdem
        // deutsch (CLAUDE.md, „Sprachen").
        .accessibilityLabel(Text(gewicht.wort))
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
