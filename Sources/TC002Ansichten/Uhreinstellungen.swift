import SwiftUI
import TC002Core
import TC002Modell

/// Was auf der Uhr eingestellt ist, nicht was diese Meldung mitbringt.
///
/// Zwei Werte, die die App über `/getConfig` liest und beim Verstellen sofort
/// auf das Gerät schreibt. Sie gelten für alles, was auf der Uhr steht —
/// Uhrzeit und Temperatur eingeschlossen —, und überdauern jede Meldung.
///
/// Warum sie hier stehen und nicht im Inspektor: Zwei Sorten Zustand gehören
/// nicht nebeneinander — die einen reisen mit einer Nutzlast mit (Dauer,
/// Lauftempo), die anderen sind Fernbedienung (Seitenwechsel, Scrolltempo).
/// Den Unterschied erklärt ein (?) an der Dauer, die Fernbedienung steht dort,
/// wo Einstellungen stehen.
///
/// Die Uhr kommt herein und wird nicht aus `AppZustand` geholt: Gelesen und
/// geschrieben wird die Uhr, deren Seite offen steht (`Uhrseite`), nicht die
/// angesehene. Vorher stand dieser Abschnitt einmal unter allen Uhren und galt
/// stets der angesehenen — wer eine andere meinte, musste die Einstellungen
/// verlassen und umschalten.
///
/// Nur bei der Ulanzi-Werksfirmware: `/getConfig` gibt es bei AWTRIX NG
/// nicht; dort führt die Uhr beides selbst. Der Aufrufer zeigt diese Ansicht
/// deshalb gar nicht erst an — sie prüft es zusätzlich, damit sie ohne
/// Rücksicht auf den Aufrufer wahr bleibt.
public struct Uhreinstellungen: View {
    @Bindable var zustand: AppZustand
    private let uhr: Uhr
    private let kanon: Formkanon

    public init(zustand: AppZustand, uhr: Uhr, kanon: Formkanon) {
        self.zustand = zustand
        self.uhr = uhr
        self.kanon = kanon
    }

    /// Vorgabe zehn Sekunden, nicht „kein Wechsel" (0): 0 fixiert die Anzeige
    /// auf die erste Meldung (Geraetereferenz §5.4 nennt das als haeufige
    /// Ursache), und genau das waere der Zustand, solange die Uhr noch nicht
    /// geantwortet hat. Geschrieben wird dadurch nichts: Kommt die Antwort,
    /// gilt sie, und `ladeLauf` verhindert, dass der gelesene Wert als Griff
    /// des Anwenders zurueckgeschrieben wird.
    @State private var seitenwechsel = 10
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

    /// Warum ein Lesefehler hier als Zeile steht, nicht als Hinweisfenster:
    /// Ein Fenster gehört zu einer Handlung, die der Anwender ausgelöst hat.
    /// Diese Abfrage läuft von selbst beim Öffnen des Zeit-Reiters, und ein
    /// modaler Dialog mitten im Senden wäre eine Auskunft, um die niemand
    /// gebeten hat. Sie meldet sich deshalb in ihrer eigenen Zeile — und im
    /// Protokoll, wo man nachsehen kann.
    @State private var lesefehler: String?


    /// Ob diese Uhr die Werksfirmware fährt. Nur dann sind die beiden Regler
    /// eine Einstellung dieser Uhr: Sie stehen in `/getConfig`, und diesen Pfad
    /// gibt es bei AWTRIX NG nicht.
    private var nurUlanzi: Bool { uhr.gattung == .tc002 }

    public var body: some View {
        if nurUlanzi {
            Section {
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
                .help(lok("Gilt nur den Anzeigen, die die Uhr selbst verwaltet — Uhrzeit, Temperatur. Auf Meldungen dieser App wirkt es nicht."))
                .onChange(of: scrollTempo) { _, neu in
                    guard !scrollLadeLauf else { scrollLadeLauf = false; return }
                    nutzerHatScrollGewaehlt = true
                    setzen("scrollSpeed", neu)
                }
                // Ein Satz je Einstellung, das Laengere hinter dem (?) am
                // Kopf: Was einen Absatz braucht, um verstanden zu werden,
                // steht am falschen Ort oder heisst falsch.
                Text("Der Takt, in dem die Uhr durch alles blättert, was auf ihr steht.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
                if let lesefehler {
                    // Angezeigt wird der Grund, nicht ein aufgeräumter
                    // Ersatzsatz: Steht dort „keine Verbindung zum lokalen
                    // Netzwerk“, sagt die Meldung des Kerns schon, was zu tun
                    // ist.
                    Label(lesefehler, systemImage: "exclamationmark.triangle")
                        .font(kanon.fussnote).foregroundStyle(.secondary)
                    Button("Erneut abfragen") {
                        geladen = false
                        self.lesefehler = nil
                        Task { await lesen() }
                    }
                    .buttonStyle(.borderless)
                    .font(kanon.fussnote)
                }
            } header: {
                Abschnittskopf("Auf der Uhr", hilfe: lok("Zwei Einstellungen des Geräts: Sie überdauern jede Meldung, gelten für alles, was auf der Uhr steht — Uhrzeit, Temperatur, die fünf Meldungen —, und werden beim Verstellen sofort geschrieben. Der Seitenwechsel ist der Takt, in dem sie durch alles blättert; „kein Wechsel“ hält sie beim ersten. Das Scrolltempo gilt dagegen nur den Anzeigen, die die Uhr selbst verwaltet: Auf Meldungen dieser App wirkt es nicht, die Werksfirmware lässt selbst geschickten Text gar nicht laufen. Was nur eine einzelne Meldung betrifft — ihre Dauer und ihr Lauftempo —, steht unter „Senden“ im Zeit-Reiter."))
            }
            .task(id: uhr.id) { await lesen() }
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
        guard nurUlanzi else { return }
        let host = uhr.host
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
        let host = uhr.host
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
