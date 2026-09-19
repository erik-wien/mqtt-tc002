import SwiftUI
import TC002Core

/// Die Filterleiste über einem Bestand — Größe und Bewegung, für alle
/// Oberflächen und beide Bestände dieselbe.
///
/// Sie steht hier und nicht dreimal in den Blättern: Was ein Filter anbietet,
/// ist eine Entscheidung über das Programm, nicht über das Gerät. Wie er
/// eingebettet wird — Listenzeile am Telefon, Zeile unter dem Suchfeld am
/// Schreibtisch —, bleibt dem Aufrufer überlassen.
///
/// Über den Wert allgemein, weil die beiden Bestände verschieden zählen:
/// Das Auswahlblatt kennt Kantenlängen (8, 16), der Bestand im Editor
/// Leinwandgrößen (8 × 8, 16 × 16, 52 × 16). `nil` heißt in beiden Fällen
/// „alle“.
public struct Filterleiste<Wert: Hashable>: View {
    @Binding var wert: Wert?
    /// Beschriftung, Kurzform und Wert je Segment, in der angebotenen
    /// Reihenfolge. Die Beschriftungen sind Übersetzungsschlüssel („8 × 8“),
    /// keine fertigen Texte — deshalb `lok` und nicht `Text(_:)`.
    let angebot: [(titel: String, kurz: String, wert: Wert)]
    @Binding var nurBewegte: Bool

    public init(wert: Binding<Wert?>, angebot: [(titel: String, kurz: String, wert: Wert)],
                nurBewegte: Binding<Bool>) {
        self._wert = wert
        self.angebot = angebot
        self._nurBewegte = nurBewegte
    }

    /// Nachgebend, nicht abschneidend: Im Inspektor des Editors sind es vier
    /// Segmente und ein Schalter auf rund 280 Punkten — am iPad, wo die
    /// Zeilenschrift 17 statt 13 Punkte misst, wurde daraus
    /// „alle · 8… · 16… · 16…". Zwei abgeschnittene Beschriftungen, die
    /// dasselbe zeigen, sind schlimmer als eine kurze, die unterscheidet.
    ///
    /// `ViewThatFits` probiert deshalb zuerst die ausgeschriebenen Größen und
    /// fällt erst dann auf die kurzen zurück — auf breiten Blättern ändert
    /// sich nichts.
    /// Kein eigener `Spacer`: Die Leiste ist so breit wie ihr Inhalt, den
    /// Zwischenraum setzt der Aufrufer. Mit einem eigenen waren es zwei
    /// gierige Geschwister in derselben Zeile; die Breitenprobe bekam nur die
    /// Haelfte vorgeschlagen und nahm die Kurzform auch dort, wo „8 × 8"
    /// bequem Platz hatte.
    public var body: some View {
        HStack(spacing: 8) {
            Text("Filter")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Die Breitenprobe umfasst **nur** die Kapsel. Lag der `Spacer`
            // mit darin, war jede Fassung unendlich breit, keine passte, und
            // `ViewThatFits` nahm immer die letzte — die Kurzform, auch auf
            // einem Blatt, auf dem „8 × 8" bequem Platz hat.
            ViewThatFits(in: .horizontal) {
                kapsel(kurz: false)
                kapsel(kurz: true)
            }
        }
    }

    /// Eine Kapsel für beides, mit einem Strich dazwischen.
    ///
    /// **Ein Nachbau der Segmentwahl, und der braucht seine Begründung**
    /// (CLAUDE.md, „Bedienelemente so, wie Apple sie festlegt"): Größe und
    /// Bewegung sind zwei Filter über demselben Bestand und gehören sichtbar
    /// zusammen — aber nicht in **einen** `Picker`. Ein fünftes Segment
    /// „bewegte" würde die Größenwahl aufheben, sobald man es wählt; man
    /// könnte dann nicht mehr „8 × 8 **und** bewegt" filtern. Zwei
    /// Bedienelemente nebeneinander wiederum lasen sich als zwei Sachen: Der
    /// Schalter stand allein daneben und sah nicht nach Filter aus.
    ///
    /// Die Form ist die, die Fotos für gruppierte Werkzeuge über dem Bild
    /// benutzt: eine Kapsel, innen durch einen Strich geteilt. Was der
    /// `Picker` dabei von selbst mitbrachte, steht hier von Hand — die Wahl
    /// als `.isSelected` für die Sprachausgabe, und je Segment ein eigener
    /// Einblendtext.
    private func kapsel(kurz: Bool) -> some View {
        HStack(spacing: 2) {
            segment(titel: lok("alle"), gewaehlt: wert == nil) { wert = nil }
            ForEach(angebot, id: \.wert) { eintrag in
                segment(titel: lok(kurz ? eintrag.kurz : eintrag.titel),
                        gewaehlt: wert == eintrag.wert) { wert = eintrag.wert }
            }

            // Der Strich trennt die beiden Fragen: links **welche Größe**,
            // rechts **ob bewegt**. Ohne ihn läse sich das Zeichen als fünfte
            // Größe.
            Divider().frame(height: strichhoehe).padding(.horizontal, 4)

            // Nur das Zeichen, kein Wort: „bewegte" wurde am Mac zu „b…" und
            // am iPad über zwei Zeilen umbrochen. Es ist dasselbe Zeichen,
            // das in jeder Zeile der Liste die bewegten Einträge markiert.
            segment(symbol: "play.fill", name: lok("Nur bewegte"),
                    gewaehlt: nurBewegte) { nurBewegte.toggle() }
        }
        .padding(3)
        .background(Capsule().fill(.quaternary.opacity(0.4)))
    }

    /// Die Höhe des Trennstrichs wächst mit der eingestellten Textgröße mit —
    /// eine feste Zahl stünde sonst neben doppelt so hohen Segmenten.
    @ScaledMetric(relativeTo: .body) private var strichhoehe: Double = 16

    private func segment(titel: String, gewaehlt: Bool,
                         tun: @escaping () -> Void) -> some View {
        segmentrumpf(gewaehlt: gewaehlt, name: titel, tun: tun) {
            Text(titel).lineLimit(1)
        }
    }

    private func segment(symbol: String, name: String, gewaehlt: Bool,
                         tun: @escaping () -> Void) -> some View {
        segmentrumpf(gewaehlt: gewaehlt, name: name, tun: tun) {
            Image(systemName: symbol)
        }
    }

    @ViewBuilder
    private func segmentrumpf<Inhalt: View>(gewaehlt: Bool, name: String,
                                            tun: @escaping () -> Void,
                                            @ViewBuilder inhalt: () -> Inhalt) -> some View {
        Button(action: tun) {
            inhalt()
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    if gewaehlt {
                        Capsule().fill(.background).shadow(radius: 0.5, y: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }
}
