import SwiftUI
import TC002Core
import TC002Modell

/// **Wie lange etwas zu sehen ist** — die drei Regler, die diese eine Frage
/// beantworten, an einer Stelle statt an dreien.
///
/// Sie standen bis zum 14.09.2026 auseinander: „Seitenwechsel" und
/// „Scrolltempo" unter „Einstellungen", die „Dauer" in der Sendezeile ganz
/// unten. Zusammengehört haben sie trotzdem immer, und dass niemand mehr sagen
/// konnte, worin sich Seitenwechsel und Dauer unterscheiden, war die Folge
/// dieser Streuung.
///
/// Der Unterschied, damit er nicht wieder verlorengeht:
///
/// - **Seitenwechsel** ist eine Einstellung **des Geräts** (`carouselSpeed` in
///   `/getConfig`): wie lange *irgendeine* Anzeige steht, bevor die Uhr zur
///   nächsten blättert. Gilt für alle fünf Plätze zugleich.
/// - **Scrolltempo** ebenso (`scrollSpeed`), und nur für Text, den die **Uhr
///   selbst** setzt — den Weg „als Text".
/// - **Dauer** reist mit *einer* Meldung mit (`duration` in der Nutzlast): die
///   eigene Standzeit dieser einen Anzeige.
///
/// **Wie Dauer und Seitenwechsel zusammenwirken, ist nicht dokumentiert.** Ob
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

    /// **Was die Ansicht sonst noch zur einzelnen Meldung zu sagen hat** — bei
    /// „Senden“ das Lauftempo, im Editor nichts.
    ///
    /// Als Platz statt als Parameter, weil das Tempo an `weg` und `passt`
    /// hängt: Zustand der Sendeansicht. Ihn hierher zu reichen hieße, drei
    /// Werte durchzugeben, damit dieser Baustein entscheiden kann, was der
    /// Aufrufer längst weiß.
    ///
    /// Und **innerhalb** von „Nur diese Meldung“, nicht darüber: Das Tempo
    /// reist mit der Meldung mit wie die Dauer. Ein eigener Abschnitt daneben
    /// ließe offen, für wie viele Anzeigen er gilt — und genau diese Frage war
    /// hier schon einmal die falsch beantwortete.
    @ViewBuilder let zusatz: Zusatz

    @State private var seitenwechsel = 0
    @State private var scrollTempo = 0
    @State private var geladen = false
    /// Ein gelesener Wert darf nicht als Griff des Anwenders gelten und
    /// zurückgeschrieben werden — sonst schriebe jedes Öffnen der Ansicht auf
    /// die Uhr.
    @State private var ladeLauf = false
    @State private var scrollLadeLauf = false
    /// Hat der Anwender während der Abfrage schon selbst gewählt, gilt seine
    /// Wahl: Der spät eintreffende gelesene Wert überschreibt sie nicht.
    @State private var nutzerHatGewaehlt = false
    @State private var nutzerHatScrollGewaehlt = false

    /// **Warum die beiden Werte gerade nicht dastehen — als Zeile, nicht als
    /// Hinweisfenster.**
    ///
    /// Bis zum 14.09.2026 setzte das Lesen `zustand.fehler`, also einen
    /// modalen Dialog. Das ging durch, solange es nur beim Öffnen der
    /// Einstellungen geschah — ein Griff, den man selbst getan hat. Seit die
    /// beiden Regler hier stehen, liest die App beim Öffnen des Zeit-Reiters,
    /// und eine nicht erreichbare Uhr warf einem dann mitten im Senden einen
    /// Dialog vor die Nase, für eine Auskunft, um die man nicht gebeten hat.
    ///
    /// Ein Fenster gehört zu einer Handlung, die der Anwender ausgelöst hat.
    /// Eine Abfrage, die von selbst läuft, meldet sich in ihrer eigenen Zeile
    /// — und im Protokoll, wo man nachsehen kann.
    @State private var lesefehler: String?

    /// Ob die aktive Uhr die Werksfirmware fährt. Nur dann sind die beiden
    /// oberen Regler eine Einstellung **dieser** Uhr: Sie stehen in
    /// `/getConfig`, und diesen Pfad gibt es bei AWTRIX NG nicht.
    private var nurUlanzi: Bool { (zustand.aktiveUhr?.gattung ?? .tc002) == .tc002 }

    var body: some View {
        // **Die Ueberschriften nennen die Reichweite, nicht den Gegenstand.**
        // „Diese Anzeige" und „Diese Uhr" standen hier zuerst, und der
        // Anwender hat den Unterschied zweimal nicht verstanden — zu Recht:
        // Beide Abschnitte handeln von Sekunden, und woran die Sekunden
        // haengen, sagten die Woerter nicht. „Nur diese Meldung" gegen „Alles,
        // was diese Uhr zeigt" sagt es in der Ueberschrift selbst.
        Section {
            LabeledContent("Dauer (Sek.)") {
                TextField("", text: $dauerText)
                    .eingabefeld()
                    .frame(width: 70)
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            Text(nurUlanzi
                 ? lok("Wie lange die Uhr diese eine Meldung zeigt, bevor sie weiterblättert. Leer oder 0: keine eigene Angabe — dann gilt der Seitenwechsel unten.")
                 : lok("Wie lange die Uhr diese eine Meldung zeigt, bevor sie weiterblättert. Leer oder 0: keine eigene Angabe."))
                .font(.footnote).foregroundStyle(.secondary)
        } header: {
            Text("Nur diese Meldung")
        } footer: {
            // **Ein Satz unter der Karte, keine zweite Karte.** Bei einer
            // AWTRIX NG blieb von „Alles, was diese Uhr zeigt" nichts uebrig
            // als diese Begruendung — eine Ueberschrift, die die Reichweite
            // von nichts nannte. Als Fusstext steht der Satz da, wo Fusstexte
            // stehen, und verspricht keine Regler.
            if !nurUlanzi {
                Text("Seitenwechsel und Scrolltempo stellt diese App nur bei der Ulanzi-Werksfirmware. Diese Uhr ist eine AWTRIX NG; sie führt beides selbst.")
            }
        }
        .task(id: zustand.aktiveID) { await lesen() }

        // **Ein eigener Abschnitt, keine Zeile im vorigen.** Am 14.09.2026
        // stand das Lauftempo als Zeile unter der Dauer — und im schmalen
        // Inspektor faellt die Beschriftung eines Segmentschalters weg. Uebrig
        // blieb ein namenloses „langsam mittel schnell" unter „Dauer (Sek.)",
        // mit einem Fusstext darunter, der von der Dauer handelt. Es las sich
        // als Teil der Dauer.
        //
        // Der Abschnitt bringt seine Ueberschrift selbst mit, und die faellt
        // nicht weg. Was er dabei einbuesst — die Naehe zur Dauer, mit der er
        // die Reichweite teilt —, holt sein Fusstext zurueck: Er sagt
        // ausdruecklich, dass er nur fuer diese eine Meldung gilt.
        zusatz

        if nurUlanzi {
            Section("Alles, was diese Uhr zeigt") {
                Picker("Seitenwechsel", selection: $seitenwechsel) {
                    Text("kein Wechsel").tag(0)
                    ForEach([10, 20, 30, 60], id: \.self) { Text(lokf("alle %d Sekunden", $0)).tag($0) }
                }
                .onChange(of: seitenwechsel) { _, neu in
                    guard !ladeLauf else { ladeLauf = false; return }
                    nutzerHatGewaehlt = true
                    setzen("carouselSpeed", neu)
                }
                LabeledContent("Scrolltempo") {
                    Schrittwahl("Scrolltempo", wert: $scrollTempo, bereich: 0...20)
                }
                .help(lok("Lauftempo für Text, den die Uhr selbst setzt (unter „Senden“ der Weg „als Text“). Der gültige Wertebereich ist nicht dokumentiert."))
                .onChange(of: scrollTempo) { _, neu in
                    guard !scrollLadeLauf else { scrollLadeLauf = false; return }
                    nutzerHatScrollGewaehlt = true
                    setzen("scrollSpeed", neu)
                }
                Text("Die Uhr blättert durch alles, was auf ihr steht — Uhrzeit, Temperatur, deine fünf Meldungen. Der Seitenwechsel ist der Takt dafür und gilt für alle. „kein Wechsel“: sie bleibt beim ersten stehen.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let lesefehler {
                    // Angezeigt wird der Grund, **nicht** ein aufgeräumter
                    // Ersatzsatz: Steht dort „keine Verbindung zum lokalen
                    // Netzwerk“, sagt die Meldung des Kerns schon, was zu tun
                    // ist.
                    Label(lesefehler, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Erneut abfragen") {
                        geladen = false
                        self.lesefehler = nil
                        Task { await lesen() }
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                }
            }
        }
    }

    /// Ein Abruf für beide Felder statt zweier — sie stehen ohnehin in
    /// derselben Antwort. Blockiert bis zur Antwort der Uhr, läuft deshalb über
    /// `Hintergrund` und nicht im kooperativen Pool.
    private func lesen() async {
        guard !geladen else { return }
        geladen = true
        // `/getConfig` gibt es nur bei der Werksfirmware. Bei einer AWTRIX NG
        // holte diese Abfrage eine 404 und meldete sie als Fehler — für eine
        // Einstellung, die dort gar nicht gefragt ist.
        guard nurUlanzi, let host = zustand.aktiveUhr?.host else { return }
        let ergebnis: (carousel: Int?, scroll: Int?, fehler: String?) = await Hintergrund.lauf {
            do {
                let k = try Geraet(host: host).konfiguration()
                return (k["carouselSpeed"] as? Int, k["scrollSpeed"] as? Int, nil)
            } catch { return (nil, nil, (error as? LocalizedError)?.errorDescription ?? "\(error)") }
        }
        // Ohne Meldung zeigte der Wähler nach einem Fehlschlag fälschlich
        // „kein Wechsel" — und sah aus wie eine Einstellung der Uhr.
        if let meldung = ergebnis.fehler {
            lesefehler = meldung
            zustand.log(lokf("Die Einstellungen „Seitenwechsel“ und „Scrolltempo“ ließen sich nicht lesen: %@", meldung))
            return
        }
        if let wert = ergebnis.carousel {
            if wert != seitenwechsel, !nutzerHatGewaehlt { ladeLauf = true; seitenwechsel = wert }
        } else {
            lesefehler = lok("Die Uhr hat keinen Wert für „Seitenwechsel“ gemeldet.")
        }
        if let wert = ergebnis.scroll {
            if wert != scrollTempo, !nutzerHatScrollGewaehlt { scrollLadeLauf = true; scrollTempo = wert }
        } else {
            lesefehler = lok("Die Uhr hat keinen Wert für „Scrolltempo“ gemeldet.")
        }
    }

    private func setzen(_ feld: String, _ wert: Int) {
        guard let host = zustand.aktiveUhr?.host else { return }
        Task {
            do {
                try await Hintergrund.lauf { try Geraet(host: host).konfigurationSetzen(feld, wert) }
                zustand.log(lokf("%@ auf %@ gesetzt", feld, "\(wert)"))
            } catch {
                zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            }
        }
    }
}

extension Zeitabschnitte where Zusatz == EmptyView {
    /// Für Aufrufer ohne eigene Zeile — der Editor kennt keine Laufschrift.
    init(zustand: AppZustand, dauerText: Binding<String>) {
        self.init(zustand: zustand, dauerText: dauerText) { EmptyView() }
    }
}
