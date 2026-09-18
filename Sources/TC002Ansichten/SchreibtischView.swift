import SwiftUI
import TC002Core
import TC002Modell

/// Die Schreibtisch-Oberfläche: Seitenleiste links, Bereich rechts. Mac und
/// iPad teilen sie sich — das iPad bekommt nicht das vergrößerte Telefon,
/// sondern den Schreibtisch.
///
/// Was **nur** der Mac hat, steht weiterhin in `TC002App/App.swift`:
/// Menübefehle, die vier `Window`-Szenen, „im Finder zeigen", die
/// Netzfreigabe und das Starten des Mithörens. Was **nur** das iPad braucht,
/// steht hier hinter `#if !os(macOS)`: ein Weg zu den vier Nebenfenstern (die
/// es dort als Fenster nicht gibt) und ein Titel über dem Bereich, weil die
/// Seitenleiste hochkant hinter einem Knopf verschwindet.
public struct SchreibtischView: View {
    @Bindable var zustand: AppZustand
    @State private var bereich: Bereich?
    #if !os(macOS)
    @State private var nebenfenster: Nebenfenster?
    #endif

    /// Der Startbereich steht hier fest und nicht an der Eigenschaft: `@State`
    /// nimmt seinen Anfangswert nur beim ersten Aufbau dieser Ansicht — genau
    /// einmal, beim Start. Ein spaeterer Aufbau (`.senden` gewaehlt, Uhr
    /// entfernt) wirft die Wahl des Benutzers damit nicht um.
    /// Wird nur von der Mac-App gesetzt (siehe `VerbindungView.ansehen`).
    private let fensterOeffnen: ((String) -> Void)?

    @MainActor
    public init(zustand: AppZustand, fensterOeffnen: ((String) -> Void)? = nil) {
        self.zustand = zustand
        self.fensterOeffnen = fensterOeffnen
        _bereich = State(initialValue: Bereich.start(eingerichtet: zustand.eingerichtet))
    }

    enum Bereich: String, CaseIterable, Identifiable {
        case senden = "Senden", editor = "Editor",
             // **„Protokoll", nicht „Verlauf"** (18.09.2026). Der Bereich
             // zeigt, was **jetzt** auf der Uhr liegt, und darunter die
             // technische Mitschrift — eine Geschichte war er nie. Den Namen
             // braucht seit heute etwas anderes: die Liste der gesendeten
             // Meldungen unter den Bloecken.
             protokoll = "Protokoll", einstellungen = "Einstellungen"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .senden: return "paperplane"
            case .editor: return "paintpalette"
            case .protokoll: return "clock.arrow.circlepath"
            case .einstellungen: return "gearshape"
            }
        }
        /// Die beiden unteren stehen abgesetzt am Fuss der Seitenleiste.
        static let oben: [Bereich] = [.senden, .editor]
        static let unten: [Bereich] = [.protokoll, .einstellungen]

        /// Womit die Oberflaeche beginnt. Ohne eingerichtete Uhr und ohne
        /// eingetragenen Broker (`AppZustand.eingerichtet`) waere „Senden" eine
        /// Sackgasse — keine Vorschau, kein Ziel, ein Sendeknopf, der
        /// nirgendwohin fuehrt. Wer eingerichtet ist, beginnt wie bisher.
        ///
        /// Gesperrt wird dabei nichts: Die Seitenleiste steht offen, und ein
        /// Klick fuehrt sofort woandershin.
        static func start(eingerichtet: Bool) -> Bereich {
            eingerichtet ? .senden : .einstellungen
        }
    }

    public var body: some View {
        NavigationSplitView {
            seitenleiste
        } detail: {
            bereichsansicht
        }
        // Mindestbreite des Fensters. GEMESSEN, nicht gerechnet (12.09.2026,
        // Bildschirmfoto bei 980): Die Detailspalte des Split-View geht nicht
        // unter rund 600 Punkte, gleich was ihr Inhalt an Mindestbreite
        // angibt. Mit fester Seitenleiste und festem Inspektor (340) fehlten
        // bei 980 genau 128 Punkte — beide Leisten wurden angeschnitten, nicht
        // die Mitte.
        //
        // 190 + 600 + 340 = 1130, mit Luft 1140. Die Seitenleiste ist am
        // 13.09.2026 von 170 auf 190 gewachsen (siehe `Seitenleiste`), die
        // Forderung deshalb von 1120 auf 1140 — sonst verschoebe sich der
        // Anschnitt dorthin zurueck, wo er schon einmal war.
        //
        // Die Leinwand des Editors fordert nichts mehr: Sie nimmt, was ihre
        // Spalte hergibt (`Malflaeche`), und rollt bei Enge waagrecht.
        //
        // Nur am Mac: Kein iPad erreicht 1140 im Hochformat (das groesste hat
        // 1024), und in geteilter Ansicht bricht es immer. Die Forderung ist am
        // Mac gemessen und gilt fuer ein Fenster, das man ziehen kann — auf dem
        // iPad gibt es nichts zu ziehen, dort schnitte sie nur ab.
        #if os(macOS)
        .frame(minWidth: 1140, minHeight: 640)
        #endif
        .alert("Fehler", isPresented: Binding(
            get: { zustand.fehler != nil },
            set: { if !$0 { zustand.fehler = nil } })) {
            Button("OK") { zustand.fehler = nil }
        } message: { Text(zustand.fehler ?? "") }
        #if !os(macOS)
        // Ganzflächig statt als Blatt: Hilfe und Gerätereferenz sind
        // zweispaltige Dokumente, und ein Formularblatt (rund 540 Punkte)
        // presste sie auf Spaltenbreite. Am Mac ist jedes davon ein Fenster;
        // ganzflächig ist dem am nächsten.
        .fullScreenCover(item: $nebenfenster) { NebenfensterSchirm(fenster: $0) }
        #endif
    }

    private var seitenleiste: some View {
        List(Bereich.oben, selection: $bereich) { b in
            Label(lok(b.rawValue), systemImage: b.symbol).tag(b)
        }
        // Verlauf und Einstellungen bleiben unten abgesetzt, statt in
        // derselben Liste mitzulaufen — eine zweite List traegt dieselbe
        // Auswahl ($bereich) und dieselbe Reihen-Optik wie die obere.
        .safeAreaInset(edge: .bottom) {
            List(Bereich.unten, selection: $bereich) { b in
                Label(lok(b.rawValue), systemImage: b.symbol).tag(b)
            }
            // Zwei Zeilen, kein Rollen: Bei 76 war der Inhalt ein paar
            // Punkte hoeher als die Liste, und sie bot einen Rollbalken an.
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .frame(height: 88)
        }
        // Feste Breite, kein Spielraum: Schrumpft das Fenster, gibt nur die
        // Mitte nach — nicht die Seitenleiste. Wie bei Finder und Mail.
        // Auf dem iPad zugleich ein Gewinn: 220 statt der dortigen Vorgabe von
        // rund 320 laesst quer genug fuer Mitte und Inspektor uebrig.
        //
        // Woher die Zahlen kommen, steht in `Seitenleiste` — gemessen an
        // „Einstellungen", das bei 170 **und bei 190** auf dem iPad umbrach.
        // Am Mac bleibt es bei 190: Dort ist die Zeilenschrift 13 statt 17
        // Punkte gross, und die Mindestbreite des Fensters unten haengt daran.
        .navigationSplitViewColumnWidth(Seitenleiste.breite)
        #if !os(macOS)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { nebenfensterMenue } }
        #endif
    }

    @ViewBuilder
    private var bereichsansicht: some View {
        let gewaehlt = bereich ?? .senden
        Group {
            switch gewaehlt {
            case .senden: SendenView(zustand: zustand)
            case .editor: EditorBereichView(zustand: zustand)
            case .protokoll: AnzeigenView(zustand: zustand)
            case .einstellungen: VerbindungView(zustand: zustand, fensterOeffnen: fensterOeffnen)
            }
        }
        // Nur auf dem iPad: Hochkant verschwindet die Seitenleiste hinter
        // einem Knopf, und ohne Titel stuende man dann vor einer Ansicht ohne
        // Angabe, wo man ist. Am Mac wuerde derselbe Aufruf den Fenstertitel
        // ueberschreiben — dort steht der Programmname, und das bleibt so.
        #if !os(macOS)
        .navigationTitle(lok(gewaehlt.rawValue))
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    #if !os(macOS)
    /// Der iPad-Ersatz fuer das Hilfe-Menue und „Über" im Programmmenue. Beide
    /// gibt es unter iOS nicht verlaesslich: Eine Menueleiste zeigt erst
    /// iPadOS 26, und die App laeuft ab iOS 17.
    private var nebenfensterMenue: some View {
        Menu {
            ForEach(Nebenfenster.allCases) { n in
                Button {
                    nebenfenster = n
                } label: {
                    Label(n.titel, systemImage: n.symbol)
                }
            }
        } label: {
            Label("Hilfe", systemImage: "questionmark.circle")
        }
    }
    #endif
}

#if !os(macOS)
/// Der Rahmen, den ein Nebenfenster auf dem iPad braucht. Am Mac gibt ihm die
/// Fensterverwaltung einen Schließknopf; hier muss er mitkommen, sonst ist die
/// ganzflächige Einblendung eine Sackgasse.
///
/// **Gezeichnet, nicht angemeldet.** Bis 13.09.2026 hing der Knopf an einer
/// `.toolbar`, und die fand bei Hilfe und Gerätereferenz keine Stelle: Beide
/// bringen eine eigene `NavigationSplitView` mit, und eine Werkzeugleiste, die
/// von *außen* darauf gelegt wird, hat keinen Navigationsbehälter, der sie
/// aufnimmt — sie übersetzt klaglos und wird nie gezeichnet. Am Gerät saß der
/// Benutzer dann in der Hilfe fest und musste die App beenden.
///
/// Deshalb eine eigene Kopfzeile, für alle vier gleich und **ohne
/// Fallunterscheidung**: `safeAreaInset` ist reine Anordnung — sie hängt an
/// keinem Behälter, den es geben muss, und kann darum nicht still ausfallen.
/// Die Fallunterscheidung war der Fehler, nicht bloß ihr falscher Zweig; mit
/// ihr fiele der Schließknopf beim nächsten Dokument mit eigenem Rahmen
/// wieder weg. `PlattformwegeTests` hält beides fest.
private struct NebenfensterSchirm: View {
    let fenster: Nebenfenster
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        fenster.inhalt
            .safeAreaInset(edge: .top, spacing: 0) { kopfzeile }
    }

    private var kopfzeile: some View {
        VStack(spacing: 0) {
            HStack {
                // `Nebenfenster.titel` ist schon übersetzt — deshalb
                // `verbatim`, sonst würde ein zweites Mal nachgeschlagen.
                Text(verbatim: fenster.titel).font(.headline)
                Spacer()
                // Das „Fertig" einer Navigationsleiste, nur von Hand
                // gezeichnet (warum, steht oben) — deshalb der Kanon der
                // Leiste und nicht der eines Befehlsknopfs: blosse Schrift,
                // halbfett. Ausdruecklich `.automatic`, damit die
                // Entscheidung im Quelltext steht.
                Button("Fertig") { schliessen() }
                    .buttonStyle(.automatic)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
        }
        // Bis unter die Statusleiste: Ohne das stünde dort der Inhalt durch.
        .background(.bar, ignoresSafeAreaEdges: .top)
    }
}
#endif
