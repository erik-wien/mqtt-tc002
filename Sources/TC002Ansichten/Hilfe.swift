import SwiftUI
import TC002Core

/// Ein Baustein eines Hilfeabschnitts: Fließtext, Überschrift, Unterpunkt
/// einer Überschrift oder Aufzählung.
///
/// Der deutsche Wortlaut ist der Übersetzungsschlüssel; nachgeschlagen wird
/// erst beim Darstellen (`HilfeabschnittView`), nicht beim Bauen der Liste.
/// So bleiben die Bausteine reine Daten und lassen sich zwischen den
/// Oberflächen teilen (siehe `HilfeInhalt`).
///
/// **Eine zweispaltige Tabelle gibt es hier nicht.** Sie war der Baustein für
/// Zuordnungen („HTTP → was das bedeutet“), und ihre erste Spalte nahm im
/// `Grid` ihre ideale Breite und brach nicht um: Am Telefon stand der ganze
/// Abschnitt dadurch links und rechts über dem Bildschirmrand, ohne dass sich
/// waagrecht rollen ließ. Ersetzt ist sie durch zwei Ebenen von Überschriften
/// — der Begriff steht als `untertitel` über seiner Erklärung statt in einer
/// Spalte daneben. Das bricht um, liest sich auf einer schmalen Seite wie auf
/// einer breiten und braucht keine Sonderbehandlung je Plattform. Wer eine
/// Tabelle wiedereinführt, baut denselben Fehler wieder ein.
public enum Hilfebaustein {
    case ueberschrift(String)
    /// Die zweite Ebene: ein Begriff oder Fall unter einer `ueberschrift`.
    case untertitel(String)
    case absatz(String)
    case punkte([String])
    /// Eine gezeichnete Abbildung (`Hilfebilder.swift`).
    case abbildung(Hilfebild)
}

/// Ein Abschnitt der Hilfe: Titel und Bausteine. Welche Abschnitte es gibt und
/// woraus sie bestehen, entscheidet jede Oberfläche für sich — das Telefon hat
/// weder Seitenleiste noch Inspektor noch Finder, und eine wortgleiche Hilfe
/// wäre dort streckenweise schlicht falsch.
public struct Hilfeabschnitt: Identifiable {
    public let titel: String
    public let bausteine: [Hilfebaustein]
    public var id: String { titel }

    public init(_ titel: String, _ bausteine: [Hilfebaustein]) {
        self.titel = titel
        self.bausteine = bausteine
    }
}

/// Stellt einen Abschnitt dar — dieselbe Maschinerie für Mac und iPhone.
///
/// `zeigtTitel` steuert nur, ob der Titel noch einmal im Text steht: Am Mac
/// trägt die Detailspalte keinen eigenen Titel, am iPhone tut das die
/// Navigationsleiste schon.
public struct HilfeabschnittView: View {
    private let abschnitt: Hilfeabschnitt
    private let zeigtTitel: Bool

    /// `lineSpacing` ist ein Zuschlag, kein Faktor: Fuer den ueblichen
    /// Zeilenabstand von 1,2 kommen also 0,2 der Schriftgroesse obendrauf,
    /// nicht das 1,2-fache davon. 2,6 ist genau das, was die Mac-Fassung als
    /// `NSFont.systemFontSize * 0.2` gerechnet hat — `@ScaledMetric` laesst
    /// den Zuschlag am iPhone mit der eingestellten Textgroesse mitwachsen,
    /// ohne dass hier eine Plattform vorkommt.
    @ScaledMetric(relativeTo: .body) private var zeilenabstand: CGFloat = 2.6

    public init(_ abschnitt: Hilfeabschnitt, zeigtTitel: Bool = true) {
        self.abschnitt = abschnitt
        self.zeigtTitel = zeigtTitel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if zeigtTitel {
                Text(lok(abschnitt.titel)).font(.title2).fontWeight(.semibold)
            }
            ForEach(Array(abschnitt.bausteine.enumerated()), id: \.offset) { _, baustein in
                bausteinView(baustein)
            }
        }
    }

    /// Der uebersetzte Text mit ausgewerteter Markdown-Auszeichnung: `fett`
    /// und `` `Bezeichner` `` kommen in den Hilfetexten vor.
    ///
    /// `Text(String)` wertet sie nicht aus — Markdown liest SwiftUI nur aus
    /// einem `LocalizedStringKey`-Literal oder einem `AttributedString`, und ein
    /// zur Laufzeit uebersetzter Text ist beides nicht. Ohne diesen Umweg stehen
    /// die Sternchen und Akzente woertlich in der Hilfe.
    ///
    /// `inlineOnlyPreservingWhitespace`, weil jeder Baustein fuer sich ein
    /// Absatz ist: Die Blockebene von Markdown (Listen, Ueberschriften)
    /// besorgt `Hilfebaustein`, nicht der Text darin.
    static func ausgezeichnet(_ text: String) -> AttributedString {
        let uebersetzt = lok(text)
        return (try? AttributedString(
            markdown: uebersetzt,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(uebersetzt)
    }

    /// Baut einen einzelnen Hilfebaustein. Überschriften bekommen zusätzliche
    /// Luft davor, Aufzählungen einen Einzug.
    @ViewBuilder
    private func bausteinView(_ baustein: Hilfebaustein) -> some View {
        switch baustein {
        case .ueberschrift(let text):
            Text(lok(text))
                .font(.headline)
                .padding(.top, 10)
        case .untertitel(let text):
            // Kleiner und mit weniger Luft davor als die Überschrift: Die
            // beiden Ebenen müssen sich unterscheiden lassen, sonst ist die
            // Gliederung wieder flach.
            Text(lok(text))
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 4)
        case .absatz(let text):
            Text(Self.ausgezeichnet(text)).lineSpacing(zeilenabstand)
        case .punkte(let eintraege):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(eintraege.enumerated()), id: \.offset) { _, eintrag in
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: "•")
                        Text(Self.ausgezeichnet(eintrag)).lineSpacing(zeilenabstand)
                    }
                }
            }
            .padding(.leading, 8)
        case .abbildung(let bild):
            HilfebildView(bild: bild)
        }
    }
}
