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

    /// Was jetzt auf der angesehenen Uhr liegt — auch, was andere dorthin
    /// geschickt haben. Die Uhr nennt ihre Anzeigen beim Namen, mehr nicht;
    /// was darin steht, weiss sie nicht zu sagen (Gerätereferenz, §3.5).
    private var aufDerUhr: (namen: [String], quelle: AppZustand.Anzeigenquelle) {
        zustand.anzeigenDerAktivenMitQuelle()
    }

    /// Eine Zeile der Liste — entweder ein eigener Eintrag des Verlaufs oder
    /// eine Anzeige, die auf der Uhr liegt und von der die App nichts weiß.
    ///
    /// Ein Typ und nicht zwei Abschnitte: Für den Leser ist beides dasselbe —
    /// eine Meldung auf der Uhr. Dass die App von der einen alles weiß und von
    /// der anderen nur den Namen, ist ein Unterschied in der Auskunft, nicht
    /// in der Sache; er zeigt sich darin, dass Felder leer bleiben.
    private struct Zeile: Identifiable {
        let id: String
        let eintrag: Verlaufseintrag?
        /// Der Name der Anzeige auf der Uhr — gesetzt, solange sie dort liegt.
        let aufDerUhr: String?
    }

    /// Verlauf und Uhrenstand in einer Liste.
    ///
    /// Ein Verlaufseintrag gilt als „liegt auf der Uhr", wenn sein Platz
    /// gerade belegt ist und er der jüngste Eintrag zu diesem Platz ist —
    /// ältere auf demselben Platz sind überschrieben. Was auf der Uhr liegt,
    /// ohne dass ein Eintrag dazu passt, kommt von fremder Hand und steht mit
    /// seinem blanken Namen darüber.
    private var zeilen: [Zeile] {
        let stand = zustand.anzeigenDerAktivenMitQuelle().namen
        var offen = Set(stand)
        var gesehen = Set<Int>()
        var aus: [Zeile] = []
        for eintrag in eintraege {
            var name: String?
            if let platz = eintrag.platz, !gesehen.contains(platz) {
                let kandidat = Meldungsplatz.name(fuer: platz)
                if offen.contains(kandidat) {
                    name = kandidat
                    offen.remove(kandidat)
                    gesehen.insert(platz)
                }
            }
            aus.append(Zeile(id: eintrag.id.uuidString, eintrag: eintrag, aufDerUhr: name))
        }
        // Fremdes zuerst: Es ist das, was man nicht erwartet hat.
        let fremd = stand.filter { offen.contains($0) }
            .map { Zeile(id: "uhr-\($0)", eintrag: nil, aufDerUhr: $0) }
        return fremd + aus
    }

    public var body: some View {
        if !zeilen.isEmpty {
            HStack {
                Text("Auf der Uhr und zuletzt geschickt")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 6)
            List(zeilen) { zeile in
                zeilenbild(zeile)
                    .swipeActions(edge: .trailing) {
                        if let name = zeile.aufDerUhr {
                            Button(role: .destructive) {
                                Task { await zustand.loeschen(name) }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } else if let eintrag = zeile.eintrag {
                            Button(role: .destructive) {
                                zustand.verlaufVergessen(eintrag.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if let name = zeile.aufDerUhr {
                            Button { zustand.umschalten(auf: name) } label: {
                                Label("Zeigen", systemImage: "eye")
                            }
                            .tint(.blue)
                        }
                    }
            }
            .listStyle(.plain)
        }
    }

    /// Eine Zeile, für beide Herkünfte dieselbe Form: Ein Druck übernimmt die
    /// Regler, wo es welche gibt.
    @ViewBuilder
    private func zeilenbild(_ zeile: Zeile) -> some View {
        if let eintrag = zeile.eintrag {
            Button { uebernehmen(eintrag) } label: {
                self.zeile(eintrag, aufDerUhr: zeile.aufDerUhr != nil)
            }
            .buttonStyle(.plain)
        } else if let name = zeile.aufDerUhr {
            fremdzeile(name)
        }
    }

    /// Was auf der Uhr liegt, ohne dass die App es kennt. Dieselbe Anordnung
    /// wie eine Verlaufszeile, nur bleiben die Felder leer, zu denen die Uhr
    /// nichts sagt — sie nennt ihre Anzeigen beim Namen und sonst nichts
    /// (Gerätereferenz, §3.5).
    private func fremdzeile(_ name: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("auf der Uhr")
                    .font(.caption).foregroundStyle(.secondary)
                if let platz = Meldungsplatz.platz(fuerName: name) {
                    Text(lokf("Platz %d", platz))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 96, alignment: .leading)
            Text(name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 0)
            uhrenzeichen
        }
        .contentShape(Rectangle())
    }

    /// Das Zeichen dafür, dass diese Meldung gerade auf der Uhr steht.
    private var uhrenzeichen: some View {
        Image(systemName: "display")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("liegt auf der Uhr"))
    }

    /// Eine Zeile: Zeit und Platz links, dann das Icon, dann der Text. Die
    /// Ziele stehen darunter klein — bei einer Uhr ist das keine Auskunft, bei
    /// dreien sehr wohl.
    private func zeile(_ eintrag: Verlaufseintrag, aufDerUhr: Bool) -> some View {
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
            if aufDerUhr { uhrenzeichen }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Übernimmt diese Meldung samt Einstellungen"))
    }
}
