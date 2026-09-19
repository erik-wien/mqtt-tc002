import SwiftUI
import TC002Core

/// Die Fassung, die ein Eingabefeld sichtbar macht — derselbe Punkt wie bei
/// den Schaltflaechen, nur eine Stufe allgemeiner
/// (`docs/superpowers/vorlagen/apple-inspektor.md`, „Zeilen").
///
/// Der Mangel war Auffindbarkeit, nicht Schoenheit: Ohne Fassung zeigt eine
/// Zeile nur ihre Beschriftung; wo zu tippen ist, sieht man erst, wenn man
/// hineingeklickt hat. Bei „LaMetric-Nummer" stand die Beschriftung sogar
/// allein in der Zeile und las sich wie eine Ueberschrift. Im Vorbild
/// (Numbers, „Zeilen 18" / „Spalten 13") traegt jeder Wert sein graues,
/// abgerundetes Kaestchen rechts in der Zeile.
///
/// Die Trennung verlaeuft nicht zwischen Mac und iPad, sondern zwischen
/// Inspektor und Blatt: Beide Desktop-Oberflaechen zeigen denselben Mangel,
/// also gilt hier derselbe Aufruf fuer beide — kein `#if os(macOS)` an jeder
/// Stelle. Was auf dem iPhone in einer `Form` oder einem Blatt steht, folgt
/// dagegen dem dortigen Kanon (Beschriftung links, rechts angeschlagener Wert
/// ohne Kasten, wie in den Systemeinstellungen) und bleibt unberuehrt.
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

    /// Ein Feld in einer beschrifteten Zeile (`LabeledContent`), so wie es die
    /// jeweilige Oberfläche haben will.
    ///
    /// Am Schreibtisch trägt es die Fassung und gibt seine eigene Beschriftung
    /// ab — die steht schon links in der Zeile. Auf dem Telefon steht der Wert
    /// rechts angeschlagen ohne Kasten, wie in den Systemeinstellungen, und die
    /// Beschriftung des Feldes ist dort der Platzhalter.
    ///
    /// Seit sich beide Oberflächen dieselben Bausteine teilen, braucht dieser
    /// eine Unterschied einen Schalter statt zweier Dateien.
    @ViewBuilder
    func eingabefeld(inZeile kanon: Formkanon) -> some View {
        switch kanon {
        case .schreibtisch: labelsHidden().eingabefeld()
        case .telefon: multilineTextAlignment(.trailing)
        }
    }

    /// Adresse, Benutzername und Präfix sind keine Prosa: keine Autokorrektur,
    /// kein großer Anfangsbuchstabe. `textInputAutocapitalization` gibt es nur
    /// außerhalb von macOS; eine Mac-Tastatur fängt von sich aus ohnehin nicht
    /// groß an.
    @ViewBuilder
    func ohneAutokorrektur() -> some View {
        #if os(macOS)
        autocorrectionDisabled()
        #else
        autocorrectionDisabled().textInputAutocapitalization(.never)
        #endif
    }

    /// Der Ziffernblock für ein Portfeld samt „Fertig“ darüber: `.numberPad`
    /// hat keine Eingabetaste, ohne Leiste käme man aus dem Feld nur durch
    /// Tippen daneben heraus. Beides gibt es nur außerhalb von macOS — dort
    /// tippt man die Zahl auf derselben Tastatur wie alles andere.
    ///
    /// Die Leiste hängt am Fokus dieses einen Feldes: `.keyboard` gölte sonst
    /// für jede Tastatur derselben Ansicht, auch für Adresse, Benutzer und
    /// Kennwort, die ihre Eingabetaste schon haben.
    @ViewBuilder
    func ziffernfeld(fokus: FocusState<Bool>.Binding) -> some View {
        #if os(macOS)
        self
        #else
        focused(fokus)
            .keyboardType(.numberPad)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if fokus.wrappedValue {
                        Spacer()
                        Button("Fertig") { fokus.wrappedValue = false }
                    }
                }
            }
        #endif
    }

    /// Dieselbe Fassung, dazu ein (x) am rechten Rand — nur, solange etwas
    /// drinsteht.
    ///
    /// Nicht für jedes Feld: Wo man den Inhalt überschreibt statt ihn
    /// wegzuwerfen (Brokeradresse, Port, Präfix), wäre es ein Knopf, den
    /// niemand drückt. Gemeint sind die flüchtigen Felder — die Nachricht, die
    /// Suche, Name und Nummer eines Bildes, das gerade gesichert wird.
    ///
    /// Im Kasten und nicht daneben: So halten es die Suchfelder des Systems,
    /// und daneben nähme es den engen Inspektorzeilen die Breite, die sie für
    /// Schriftnamen und Nummern brauchen. Der Preis: Text, der länger ist als
    /// der Kasten, läuft unter dem Zeichen durch — beim System ebenso.
    ///
    /// `.plain`, weil es hier wirklich nur ein Zeichen sein soll: Ohne
    /// ausdrücklichen Stil zeichnete iPadOS blaue Schrift in der Akzentfarbe,
    /// und ein blaues Zeichen im Feld läse sich als Verweis.
    func eingabefeld(loeschbar text: Binding<String>) -> some View {
        eingabefeld(loeschbar: text, senden: nil, laeuft: false)
    }

    /// Dasselbe, dazu ein Sendeknopf am rechten Rand — für das Feld, das die
    /// Haupthandlung auslöst.
    ///
    /// Es sagt an, was die Eingabetaste tut, und ist zugleich der Knopf: Ohne
    /// ihn hätte, wer mit der Maus arbeitet, gar keine Stelle mehr zum
    /// Klicken, seit der eigene Sendeknopf weggefallen ist.
    ///
    /// Die Reihenfolge ist (x) links, ⏎ rechts: Das Löschen gehört zum Feld,
    /// das Senden ist die Handlung danach — von links nach rechts gelesen
    /// also erst zurücknehmen, dann abschicken.
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
                        Sendezeichen(senden: senden)
                    }
                }
                .padding(.trailing, 4)
            }
    }
}

/// Der Sendeknopf im Eingabefeld: ein gefüllter Kreis in der Akzentfarbe, wie
/// der Sendepfeil in Nachrichten.
///
/// Ein eigener Baustein und kein Stück der Erweiterung darüber, weil
/// `@ScaledMetric` eine Ansicht braucht: Der Kreis sitzt in einem Feld, das mit
/// der eingestellten Textgröße wächst — bliebe er fest, säße er darin
/// irgendwann wie ein Fremdkörper.
///
/// Blau ist in diesem Haus die eine Haupthandlung einer Ansicht
/// (`Knopfstil.swift`), und die ist hier das Senden. Beim ersten Anwendertest
/// wurde das bloße Zeichen ohne Kreis nicht als Schaltfläche erkannt.
struct Sendezeichen: View {
    let senden: () -> Void

    @ScaledMetric(relativeTo: .body) private var kante: Double = 26
    @ScaledMetric(relativeTo: .body) private var pfeil: Double = 13

    var body: some View {
        Button(action: senden) {
            Image(systemName: "arrow.up")
                .font(.system(size: pfeil, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: kante, height: kante)
                .background(Circle().fill(.tint))
        }
        .buttonStyle(.plain)
        .help(lok("Senden"))
        .accessibilityLabel(Text("Senden"))
    }
}
