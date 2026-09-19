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
///
/// Zwei Formen, dieselben Zeilen: `Verlaufsliste` bringt ihre eigene `List`
/// mit, `Verlaufsabschnitt` liefert einen `Section` in die Liste des
/// Aufrufers. Der Unterschied kommt aus der Umgebung, nicht aus der Sache —
/// am Telefon ist der ganze Bildschirm eine Liste, in der die Vorschau selbst
/// eine Zeile ist; am Schreibtisch hat die Vorschau die Werkzeugleiste über
/// sich und den Inspektor neben sich und ist kein Listeneintrag.
public struct Verlaufsliste: View {
    @Bindable var zustand: AppZustand
    /// Was beim Antippen geschehen soll — die Ansicht setzt ihre eigenen
    /// Regler, und die kennt nur sie.
    let uebernehmen: (Verlaufseintrag) -> Void

    public init(zustand: AppZustand, uebernehmen: @escaping (Verlaufseintrag) -> Void) {
        self.zustand = zustand
        self.uebernehmen = uebernehmen
    }

    public var body: some View {
        let zeilen = Verlaufsbau.zeilen(zustand)
        if !zeilen.isEmpty {
            HStack {
                Text(Verlaufsbau.ueberschrift)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 6)
            List(zeilen) { zeile in
                Verlaufszeilenbild(zustand: zustand, zeile: zeile, uebernehmen: uebernehmen)
            }
            .listStyle(.plain)
        }
    }
}

/// Dieselben Zeilen als Abschnitt in einer fremden `List`, mit der
/// Überschrift als `header`.
///
/// Eine eigene `List` wäre am Telefon die zweite in der ersten: Sie bekäme
/// darin keine eigene Höhe, bräuchte deshalb eine feste — und eine feste Höhe
/// mit wenigen Zeilen verteilt den Rest als Leere. Genau das stand zwischen
/// Slotleiste und Eingabefeld.
public struct Verlaufsabschnitt: View {
    @Bindable var zustand: AppZustand
    let uebernehmen: (Verlaufseintrag) -> Void

    public init(zustand: AppZustand, uebernehmen: @escaping (Verlaufseintrag) -> Void) {
        self.zustand = zustand
        self.uebernehmen = uebernehmen
    }

    public var body: some View {
        let zeilen = Verlaufsbau.zeilen(zustand)
        if !zeilen.isEmpty {
            Section {
                ForEach(zeilen) { zeile in
                    Verlaufszeilenbild(zustand: zustand, zeile: zeile, uebernehmen: uebernehmen)
                }
            } header: {
                // Dieselbe Auszeichnung wie am Schreibtisch, und ein eigener
                // Zeilenrand: Der Kopf einer `List(.plain)` bringt sonst den
                // Abstand eines eigenen Kapitels mit, und zwischen Slotleiste
                // und Verlauf stand damit wieder eine leere Flaeche.
                Text(Verlaufsbau.ueberschrift)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            }
        }
    }
}

/// Eine Zeile der Liste — entweder ein eigener Eintrag des Verlaufs oder
/// eine Anzeige, die auf der Uhr liegt und von der die App nichts weiß.
///
/// Ein Typ und nicht zwei Abschnitte: Für den Leser ist beides dasselbe —
/// eine Meldung auf der Uhr. Dass die App von der einen alles weiß und von
/// der anderen nur den Namen, ist ein Unterschied in der Auskunft, nicht
/// in der Sache; er zeigt sich darin, dass Felder leer bleiben.
struct Verlaufszeile: Identifiable {
    let id: String
    let eintrag: Verlaufseintrag?
    /// Der Name der Anzeige auf der Uhr — gesetzt, solange sie dort liegt.
    let aufDerUhr: String?
}

/// Was beide Formen teilen: die Überschrift und die Zeilen, die darunter
/// stehen.
enum Verlaufsbau {
    static let ueberschrift: LocalizedStringKey = "Auf der Uhr und zuletzt geschickt"

    /// Verlauf und Uhrenstand in einer Liste.
    ///
    /// Ein Verlaufseintrag gilt als „liegt auf der Uhr", wenn sein Platz
    /// gerade belegt ist und er der jüngste Eintrag zu diesem Platz ist —
    /// ältere auf demselben Platz sind überschrieben. Was auf der Uhr liegt,
    /// ohne dass ein Eintrag dazu passt, kommt von fremder Hand und steht mit
    /// seinem blanken Namen darüber.
    ///
    /// `verlaufstand` wird gelesen, damit SwiftUI neu zeichnet: Die Einträge
    /// liegen in Dateien, und ohne einen beobachteten Wert wüsste niemand,
    /// dass sich dort etwas getan hat.
    @MainActor
    static func zeilen(_ zustand: AppZustand) -> [Verlaufszeile] {
        _ = zustand.verlaufstand
        let eintraege = zustand.verlauf()
        let stand = zustand.anzeigenDerAktivenMitQuelle().namen
        var offen = Set(stand)
        var gesehen = Set<Int>()
        var aus: [Verlaufszeile] = []
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
            aus.append(Verlaufszeile(id: eintrag.id.uuidString, eintrag: eintrag, aufDerUhr: name))
        }
        // Fremdes zuerst: Es ist das, was man nicht erwartet hat.
        let fremd = stand.filter { offen.contains($0) }
            .map { Verlaufszeile(id: "uhr-\($0)", eintrag: nil, aufDerUhr: $0) }
        return fremd + aus
    }
}

/// Eine Zeile samt ihren Wischgesten — einmal geschrieben, von beiden Formen
/// benutzt. Die Gesten stehen hier und nicht am Aufrufer: Sie gehören zur
/// Zeile, und zweimal geschrieben liefen sie auseinander.
struct Verlaufszeilenbild: View {
    @Bindable var zustand: AppZustand
    let zeile: Verlaufszeile
    let uebernehmen: (Verlaufseintrag) -> Void

    private static let zeitform: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    var body: some View {
        zeilenbild
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

    /// Eine Zeile, für beide Herkünfte dieselbe Form: Ein Druck übernimmt die
    /// Regler, wo es welche gibt.
    @ViewBuilder
    private var zeilenbild: some View {
        if let eintrag = zeile.eintrag {
            Button { uebernehmen(eintrag) } label: {
                self.zeile(eintrag, aufDerUhr: zeile.aufDerUhr != nil)
            }
            .buttonStyle(.plain)
        } else if let name = zeile.aufDerUhr {
            fremdzeile(name)
        }
    }

    /// Was auf der Uhr liegt, ohne dass die App es kennt. Dieselbe Ordnung wie
    /// eine Verlaufszeile — was, an wen, wann —, nur bleiben die Felder leer,
    /// zu denen die Uhr nichts sagt: Sie nennt ihre Anzeigen beim Namen und
    /// sonst nichts (Gerätereferenz, §3.5). Eine Zeit gibt es dort nicht,
    /// also steht rechts nur der Platz.
    private func fremdzeile(_ name: String) -> some View {
        HStack(spacing: 10) {
            iconplatz
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text("auf der Uhr")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if let platz = Meldungsplatz.platz(fuerName: name) {
                Text(lokf("Platz %d", platz))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
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

    /// Die Kantenlänge des Bildchens vorn. So groß wie zwei Zeilen Text
    /// daneben hoch sind; größer würde die Zeile davon höher.
    private static let iconkante = 26.0

    /// Der leere Platz vorn — überall gleich breit, damit Text und Uhren
    /// untereinander stehen, ob eine Zeile ein Icon hat oder nicht.
    private var iconplatz: some View {
        Color.clear.frame(width: Self.iconkante, height: Self.iconkante)
    }

    /// Eine Zeile in der Reihenfolge der Auskunft: was — an wen — wann.
    ///
    /// Vorn das Icon als Bild und nicht als Nummer: Eine Sendung ohne Text
    /// bestand vorher aus „Gestern, 19:13 · 5610 · Uhrennamen", und niemand
    /// weiß, was 5610 ist. Der Verlauf soll „dasselbe noch einmal"
    /// ermöglichen, und dafür muss man das Dasselbe erkennen.
    ///
    /// Die Uhren stehen nur bei mehreren eingerichteten darunter: Bei einer
    /// einzigen ist ihr Name keine Auskunft, sondern in jeder Zeile dasselbe
    /// Wort.
    private func zeile(_ eintrag: Verlaufseintrag, aufDerUhr: Bool) -> some View {
        let icon = zustand.icon(fuer: eintrag)
        return HStack(spacing: 10) {
            if let icon {
                Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                           kante: Self.iconkante / Double(icon.kante))
            } else {
                iconplatz
            }

            VStack(alignment: .leading, spacing: 2) {
                // Der Text in der Schriftfarbe der Liste, die Sendefarbe
                // daneben als Punkt: In seiner eigenen Farbe gesetzt war ein
                // weiss geschickter Text auf weissem Grund unsichtbar — die
                // Zeile sah aus, als fehle die Meldung. Die Farbe ist eine
                // Auskunft ueber die Meldung, nicht die Farbe dieser Liste.
                HStack(spacing: 6) {
                    if let farbe = Color(hex: eintrag.optionen.farbe) {
                        Circle().fill(farbe)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.quaternary, lineWidth: 0.5))
                            .accessibilityHidden(true)
                    }
                    // Nie eine leere Zeile: Ohne Text sagt der Name des Icons,
                    // was geschickt wurde; gibt es das Icon nicht mehr, seine
                    // Nummer. Ist auch die weg, bleibt das Wort — eine Zeile
                    // ohne Inhalt laese sich als Fehler.
                    Text(inhaltswort(eintrag, icon: icon))
                        .lineLimit(1)
                        .foregroundStyle(eintrag.optionen.text.isEmpty ? .secondary : .primary)
                }
                if zustand.uhren.count > 1 {
                    Text(eintrag.uhr)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Self.zeitwort(eintrag.zeit))
                    .font(.caption).foregroundStyle(.secondary)
                if let platz = eintrag.platz {
                    Text(lokf("Platz %d", platz))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

            if aufDerUhr { uhrenzeichen }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Übernimmt diese Meldung samt Einstellungen"))
    }

    /// Heute nur die Uhrzeit, sonst der Tag davor („Gestern, 19:13").
    ///
    /// Zwei Former, weil `doesRelativeDateFormatting` für heute „Heute,
    /// 19:13" liefert: Das Wort kostet in der schmalen rechten Spalte mehr
    /// Breite, als es sagt — was heute war, ist der Normalfall.
    /// Was in der Zeile als Inhalt steht — der Text, sonst der Iconname,
    /// sonst die Iconnummer, sonst ein Wort dafuer, dass nichts davon bekannt
    /// ist.
    private func inhaltswort(_ eintrag: Verlaufseintrag, icon: Icon?) -> String {
        if !eintrag.optionen.text.isEmpty { return eintrag.optionen.text }
        if let name = icon?.name, !name.isEmpty { return name }
        if let nummer = eintrag.iconNummer, !nummer.isEmpty { return nummer }
        return lok("ohne Text")
    }

    private static func zeitwort(_ zeit: Date) -> String {
        Calendar.current.isDateInToday(zeit) ? heuteform.string(from: zeit)
                                             : zeitform.string(from: zeit)
    }

    private static let heuteform: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
