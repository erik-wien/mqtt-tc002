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
    @MainActor
    public init(zustand: AppZustand) {
        self.zustand = zustand
        _bereich = State(initialValue: Bereich.start(eingerichtet: zustand.eingerichtet))
    }

    enum Bereich: String, CaseIterable, Identifiable {
        case senden = "Senden", malen = "Malen", icons = "Icons",
             verlauf = "Verlauf", einstellungen = "Einstellungen"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .senden: return "paperplane"
            case .malen: return "paintbrush"
            case .icons: return "paintpalette"
            case .verlauf: return "clock.arrow.circlepath"
            case .einstellungen: return "gearshape"
            }
        }
        /// Die beiden unteren stehen abgesetzt am Fuss der Seitenleiste.
        static let oben: [Bereich] = [.senden, .malen, .icons]
        static let unten: [Bereich] = [.verlauf, .einstellungen]

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
        // Mindestgroesse: Seitenleiste (min. 150) plus die 52 Spalten der
        // Mal-/Vorschaufläche bei ihrer groessten Kantenlaenge (14) plus
        // Innenabstand — sonst faellt die Flaeche wie im gemeldeten Fall rechts
        // aus dem Fenster, bevor die reaktive Anpassung ueberhaupt eingreift.
        // 980 kommt von „Malen": 52 Spalten bei groesster Kantenlaenge plus
        // Seitenleiste. Der Inspektor von „Senden" braucht rund 340 Punkte
        // obendrauf — erzwungen wird das hier aber nicht, sonst waere das
        // Fenster fuer alle Bereiche so breit wie fuer den einen, der ihn hat,
        // und wuechse ueber den Bildschirmrand. Die Vorgabegroesse ist breit
        // genug; ist das Fenster schmaler, hilft der Knopf in der
        // Werkzeugleiste, der den Inspektor einklappt.
        // GEMESSEN, nicht gerechnet (12.09.2026, Bildschirmfoto bei 980):
        // Die Detailspalte des Split-View geht nicht unter rund 600 Punkte,
        // gleich was ihr Inhalt an Mindestbreite angibt. Mit fester
        // Seitenleiste (170) und festem Inspektor (340) fehlten bei 980 genau
        // 128 Punkte — beide Leisten wurden angeschnitten, nicht die Mitte.
        // 170 + 600 + 340 = 1110, mit Luft 1120. Malen braucht weniger.
        //
        // Nur am Mac: Kein iPad erreicht 1120 im Hochformat (das groesste hat
        // 1024), und in geteilter Ansicht bricht es immer. Die Forderung ist am
        // Mac gemessen und gilt fuer ein Fenster, das man ziehen kann — auf dem
        // iPad gibt es nichts zu ziehen, dort schnitte sie nur ab.
        #if os(macOS)
        .frame(minWidth: 1120, minHeight: 640)
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
        // Auf dem iPad zugleich ein Gewinn: 170 statt der dortigen Vorgabe von
        // rund 320 laesst quer genug fuer Mitte und Inspektor uebrig.
        .navigationSplitViewColumnWidth(170)
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
            case .malen: MalenView(zustand: zustand)
            case .icons: IconEditorView(zustand: zustand)
            case .verlauf: AnzeigenView(zustand: zustand)
            case .einstellungen: VerbindungView(zustand: zustand)
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
                Button("Fertig") { schliessen() }.fontWeight(.semibold)
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
