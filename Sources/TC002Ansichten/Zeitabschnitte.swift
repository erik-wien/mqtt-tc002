import SwiftUI
import TC002Core
import TC002Modell

/// Wie lange etwas zu sehen ist — die drei Regler, die diese eine Frage
/// beantworten, an einer Stelle statt an dreien: Getrennt liesse sich nicht
/// mehr sagen, worin sich Seitenwechsel und Dauer unterscheiden.
///
/// Der Unterschied, damit er nicht wieder verlorengeht:
///
/// - Seitenwechsel ist eine Einstellung des Geräts (`carouselSpeed` in
///   `/getConfig`): wie lange irgendeine Anzeige steht, bevor die Uhr zur
///   nächsten blättert. Gilt für alle fünf Plätze zugleich.
/// - Scrolltempo ebenso (`scrollSpeed`), und nur für Text, den die Uhr
///   selbst setzt — den Weg „als Text".
/// - Dauer reist mit einer Meldung mit (`duration` in der Nutzlast): die
///   eigene Standzeit dieser einen Anzeige.
///
/// Wie Dauer und Seitenwechsel zusammenwirken, ist nicht dokumentiert: Ob
/// die Dauer den Seitenwechsel für ihre Anzeige überschreibt oder der kleinere
/// Wert gewinnt, sagt die Herstellerdokumentation nicht (Gerätereferenz, §4.4).
/// Das steht so auch in der Hilfe; hier wird es nicht besser geraten.
///
/// Von „Senden" und „Editor" gemeinsam benutzt — zwei Fassungen derselben drei
/// Regler liefen früher oder später auseinander.
struct Zeitabschnitte<Zusatz: View>: View {
    @Bindable var zustand: AppZustand
    /// Die Dauer gehört der jeweiligen Ansicht: Sie ist Teil des Auftrags, der
    /// dort zusammengestellt wird, und nicht Zustand dieses Bausteins.
    @Binding var dauerText: String

    /// Was die Ansicht sonst noch zur einzelnen Meldung zu sagen hat — bei
    /// „Senden“ das Lauftempo, im Editor nichts.
    ///
    /// Als Platz statt als Parameter, weil das Tempo an `weg` und `passt`
    /// hängt: Zustand der Sendeansicht. Ihn hierher zu reichen hieße, drei
    /// Werte durchzugeben, damit dieser Baustein entscheiden kann, was der
    /// Aufrufer längst weiß.
    ///
    /// Und innerhalb von „Nur diese Meldung“, nicht darüber: Das Tempo
    /// reist mit der Meldung mit wie die Dauer. Ein eigener Abschnitt daneben
    /// ließe offen, für wie viele Anzeigen er gilt — und genau diese Frage war
    /// hier schon einmal die falsch beantwortete.
    @ViewBuilder let zusatz: Zusatz

    /// Ob die aktive Uhr die Werksfirmware fährt. Nur dann sind die beiden
    /// oberen Regler eine Einstellung dieser Uhr: Sie stehen in
    /// `/getConfig`, und diesen Pfad gibt es bei AWTRIX NG nicht.
    private var nurUlanzi: Bool { (zustand.aktiveUhr?.gattung ?? .tc002) == .tc002 }

    var body: some View {
        // Die Ueberschriften nennen die Reichweite, nicht den Gegenstand:
        // Beide Abschnitte handeln von Sekunden, und woran die Sekunden
        // haengen, sagt der Gegenstand allein nicht. „Nur diese Meldung"
        // gegen „Alles, was diese Uhr zeigt" sagt es in der Ueberschrift
        // selbst.
        Section {
            LabeledContent("Dauer (Sek.)") {
                TextField("", text: $dauerText)
                    .eingabefeld()
                    .frame(width: 70)
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            Text("Wie lange die Uhr diese eine Meldung zeigt, bevor sie weiterblättert. Leer oder 0: keine eigene Angabe.")
                .font(.footnote).foregroundStyle(.secondary)
        } header: {
            Abschnittskopf("Nur diese Meldung", hilfe: lok("Dauer und Lauftempo reisen mit dieser einen Meldung mit. Wie schnell die Uhr durch alle Anzeigen blättert, ist dagegen eine Einstellung des Geräts und steht unter „Einstellungen“ — bei der Uhr, für die sie gilt."))
        } footer: {
            // Ein Satz unter der Karte, keine zweite Karte: Bei einer
            // AWTRIX NG bliebe von „Alles, was diese Uhr zeigt" nichts als
            // diese Begruendung — eine Ueberschrift, die die Reichweite von
            // nichts nennt. Als Fusstext steht der Satz da, wo Fusstexte
            // stehen, und verspricht keine Regler.
            if !nurUlanzi {
                Text("Eine AWTRIX NG führt den Seitenwechsel selbst; unter „Einstellungen“ steht er deshalb nur bei einer Ulanzi-Werksfirmware.")
            }
        }

        // Ein eigener Abschnitt, keine Zeile im vorigen: Im schmalen
        // Inspektor faellt die Beschriftung eines Segmentschalters weg — als
        // Zeile unter „Dauer (Sek.)" waere er ein namenloses „langsam mittel
        // schnell" und laese sich als Teil der Dauer.
        //
        // Der Abschnitt bringt seine Ueberschrift selbst mit, und die faellt
        // nicht weg. Was er dabei einbuesst — die Naehe zur Dauer, mit der er
        // die Reichweite teilt —, holt sein Fusstext zurueck: Er sagt
        // ausdruecklich, dass er nur fuer diese eine Meldung gilt.
        zusatz
    }
}

extension Zeitabschnitte where Zusatz == EmptyView {
    /// Für Aufrufer ohne eigene Zeile — der Editor kennt keine Laufschrift.
    init(zustand: AppZustand, dauerText: Binding<String>) {
        self.init(zustand: zustand, dauerText: dauerText) { EmptyView() }
    }
}
