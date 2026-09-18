import SwiftUI
import TC002Core
import TC002Modell

/// Was von hier aus geschickt wurde — Zeit, Platz, Icon, Text.
///
/// Drei Dinge heißen in dieser App ähnlich und sind verschieden:
///
/// - Das Protokoll (`AnzeigenView`) ist die technische Ebene: was die App
///   getan hat und was die Uhren gemeldet haben. Ab Werk aus.
/// - Auf der Uhr ist der Zustand: was jetzt gerade darauf liegt.
/// - Der Verlauf, dies hier, ist die Geschichte: was man geschickt hat,
///   mit allen Reglern. Ein Druck darauf stellt die Meldung wieder her — nicht
///   nur ihren Text, sondern Schrift, Farbe, Ausrichtung, Tempo und Icon.
///
/// Sie steht unter den Blöcken, auf beiden Oberflächen: Am Telefon füllt
/// sie die Fläche, die zwischen Blöcken und Eingabefeld leer stand; am
/// Schreibtisch wächst sie in den Platz, den das Fenster hergibt. Dieselbe
/// Anordnung, weil es dieselbe Frage ist — und der häufigste Fall ist
/// „dasselbe noch einmal".
public struct Verlaufsliste: View {
    @Bindable var zustand: AppZustand
    /// Was beim Antippen geschehen soll — die Ansicht setzt ihre eigenen
    /// Regler, und die kennt nur sie.
    let uebernehmen: (Verlaufseintrag) -> Void

    public init(zustand: AppZustand, uebernehmen: @escaping (Verlaufseintrag) -> Void) {
        self.zustand = zustand
        self.uebernehmen = uebernehmen
    }

    /// `verlaufstand` wird gelesen, damit SwiftUI neu zeichnet: Die Einträge
    /// liegen in Dateien, und ohne einen beobachteten Wert wüsste niemand,
    /// dass sich dort etwas getan hat.
    private var eintraege: [Verlaufseintrag] {
        _ = zustand.verlaufstand
        return zustand.verlauf()
    }

    private static let zeitform: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    public var body: some View {
        if zustand.verlaufAn, !eintraege.isEmpty {
            // Eine Ueberschrift, so klein wie moeglich: Ohne sie stuende
            // dort eine Liste, die man fuer vieles halten kann — die Anzeigen
            // auf der Uhr etwa, die es an anderer Stelle wirklich gibt. Mit
            // ihr ist in einem Wort gesagt, dass dies die eigenen, schon
            // geschickten Meldungen sind.
            HStack {
                Text("Verlauf")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 6)
            List {
                ForEach(eintraege) { eintrag in
                    Button { uebernehmen(eintrag) } label: {
                        zeile(eintrag)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            zustand.verlaufVergessen(eintrag.id)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    /// Eine Zeile: Zeit und Platz links, dann das Icon, dann der Text. Die
    /// Ziele stehen darunter klein — bei einer Uhr ist das keine Auskunft, bei
    /// dreien sehr wohl.
    private func zeile(_ eintrag: Verlaufseintrag) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.zeitform.string(from: eintrag.zeit))
                    .font(.caption).foregroundStyle(.secondary)
                if let platz = eintrag.platz {
                    Text(lokf("Platz %d", platz))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 96, alignment: .leading)

            if let nummer = eintrag.iconNummer, !nummer.isEmpty {
                Text(nummer)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 1) {
                // Der Text in der Farbe, in der er gesendet wurde — die
                // schnellste Auskunft darueber, welche Meldung das war.
                Text(eintrag.optionen.text)
                    .lineLimit(1)
                    .foregroundStyle(Color(hex: eintrag.optionen.farbe) ?? .primary)
                Text(eintrag.uhr)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Übernimmt diese Meldung samt Einstellungen"))
    }
}
