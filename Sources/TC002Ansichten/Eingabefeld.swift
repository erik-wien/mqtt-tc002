import SwiftUI
import TC002Core

/// Die Fassung, die ein Eingabefeld sichtbar macht — derselbe Punkt wie bei
/// den Schaltflaechen, nur eine Stufe allgemeiner
/// (`docs/superpowers/vorlagen/apple-inspektor.md`, „Zeilen").
///
/// **Der Mangel war Auffindbarkeit, nicht Schoenheit.** Ohne Fassung zeigt
/// eine Zeile nur ihre Beschriftung; wo zu tippen ist, sieht man erst, wenn
/// man hineingeklickt hat. Bei „LaMetric-Nummer" stand die Beschriftung sogar
/// allein in der Zeile und las sich wie eine Ueberschrift. Im Vorbild
/// (Numbers, „Zeilen 18" / „Spalten 13") traegt jeder Wert sein graues,
/// abgerundetes Kaestchen rechts in der Zeile.
///
/// **Die Trennung verlaeuft nicht zwischen Mac und iPad**, sondern zwischen
/// **Inspektor** und **Blatt**: Beide Desktop-Oberflaechen zeigen denselben
/// Mangel, also gilt hier derselbe Aufruf fuer beide — kein `#if os(macOS)`
/// an jeder Stelle. Was auf dem iPhone in einer `Form` oder einem Blatt
/// steht, folgt dagegen dem dortigen Kanon (Beschriftung links, rechts
/// angeschlagener Wert ohne Kasten, wie in den Systemeinstellungen) und
/// bleibt unberuehrt.
public extension View {
    /// Grauer, abgerundeter Kasten um ein `TextField` oder `SecureField`.
    ///
    /// `.roundedBorder` und nicht eine selbstgezeichnete Fassung: Sie bringt
    /// Fokusring, Hoehe und Innenabstand des Systems mit, und die verschieben
    /// sich mit der eingestellten Textgroesse — eine nachgebaute Fassung
    /// taete das nicht.
    func eingabefeld() -> some View {
        textFieldStyle(.roundedBorder)
    }

    /// Dieselbe Fassung, dazu ein (x) am rechten Rand — **nur, solange etwas
    /// drinsteht.**
    ///
    /// Nicht für jedes Feld: Wo man den Inhalt überschreibt statt ihn
    /// wegzuwerfen (Brokeradresse, Port, Präfix), wäre es ein Knopf, den
    /// niemand drückt. Gemeint sind die flüchtigen Felder — die Nachricht, die
    /// Suche, Name und Nummer eines Bildes, das gerade gesichert wird.
    ///
    /// **Im Kasten und nicht daneben.** So halten es die Suchfelder des
    /// Systems, und daneben nähme es den engen Inspektorzeilen die Breite, die
    /// sie für Schriftnamen und Nummern brauchen. Der Preis: Text, der länger
    /// ist als der Kasten, läuft unter dem Zeichen durch — beim System
    /// ebenso.
    ///
    /// `.plain`, weil es hier wirklich nur ein Zeichen sein soll: Ohne
    /// ausdrücklichen Stil zeichnete iPadOS blaue Schrift in der Akzentfarbe,
    /// und ein blaues Zeichen im Feld läse sich als Verweis.
    func eingabefeld(loeschbar text: Binding<String>) -> some View {
        eingabefeld(loeschbar: text, senden: nil, laeuft: false)
    }

    /// Dasselbe, dazu ein ⏎ am rechten Rand — **für das Feld, das die
    /// Haupthandlung auslöst.**
    ///
    /// Es sagt an, was die Eingabetaste tut, und **ist zugleich der Knopf**:
    /// Ohne ihn hätte, wer mit der Maus arbeitet, gar keine Stelle mehr zum
    /// Klicken, seit der eigene Sendeknopf weggefallen ist. Ein Zeichen, das
    /// nur aussieht wie ein Knopf, wäre die schlechtere Hälfte von beidem.
    ///
    /// **Die Reihenfolge ist (x) links, ⏎ rechts.** Das Löschen gehört zum
    /// Feld, das Senden ist die Handlung danach — von links nach rechts
    /// gelesen also erst zurücknehmen, dann abschicken.
    ///
    /// Während des Sendens tritt ein Fortschrittsdreher an die Stelle des ⏎,
    /// und das (x) fällt weg: Ein Feld, dessen Inhalt gerade hinausgeht,
    /// leert man nicht. Ohne den Dreher fehlte jede Rückmeldung — die gab
    /// vorher der Knopf, der „Sende…" hieß.
    func eingabefeld(loeschbar text: Binding<String>,
                     senden: (() -> Void)?,
                     laeuft: Bool) -> some View {
        eingabefeld()
            .overlay(alignment: .trailing) {
                HStack(spacing: 6) {
                    if !text.wrappedValue.isEmpty, !laeuft {
                        Button { text.wrappedValue = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(lok("Leeren"))
                        .accessibilityLabel(Text("Leeren"))
                    }
                    if laeuft {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(Text("Sende…"))
                    } else if let senden, !text.wrappedValue.isEmpty {
                        Button(action: senden) {
                            Image(systemName: "return")
                        }
                        .buttonStyle(.plain)
                        // **In der Akzentfarbe, das (x) daneben gedaempft.**
                        // Blau ist in diesem Haus die *eine* Haupthandlung
                        // einer Ansicht (`Knopfstil.swift`), und die ist hier
                        // das Senden. Grau war es die schwaechere Haelfte von
                        // beidem: der wichtigste Griff, so unauffaellig wie das
                        // Leeren daneben. Ein gefuellter Knopf waere zu viel —
                        // im Feld ist das Zeichen selbst die Schaltflaeche,
                        // wie der Pfeil in Nachrichten.
                        .foregroundStyle(.tint)
                        .help(lok("Senden"))
                        .accessibilityLabel(Text("Senden"))
                    }
                }
                .padding(.trailing, 4)
            }
    }
}
