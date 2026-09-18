import SwiftUI
import TC002Core
import TC002Modell

/// Die Schreibtisch-Oberfläche: Seitenleiste links, Bereich rechts. Mac und
/// iPad teilen sie sich — das iPad bekommt nicht das vergrößerte Telefon,
/// sondern den Schreibtisch.
///
/// Nur der Mac: Menübefehle, `Window`-Szenen, „im Finder zeigen", Netzfreigabe
/// und das Mithören — die stehen in `TC002App/App.swift`. Nur das iPad: der Weg
/// zu den Nebenfenstern (dort keine Fenster) und ein Titel über dem Bereich,
/// weil die Seitenleiste hochkant hinter einem Knopf verschwindet; beides hier
/// hinter `#if !os(macOS)`.
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
             // „Protokoll", nicht „Verlauf": Der Bereich zeigt, was jetzt auf
             // der Uhr liegt, und darunter die technische Mitschrift. „Verlauf"
             // heisst die Liste der gesendeten Meldungen unter den Bloecken.
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

        /// Womit die Oberflaeche beginnt. Ohne eingerichtete Uhr und Broker
        /// (`AppZustand.eingerichtet`) waere „Senden" eine Sackgasse: keine
        /// Vorschau, kein Ziel. Gesperrt ist nichts, die Seitenleiste steht
        /// offen.
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
        // Mindestbreite: 190 (Seitenleiste) + 600 + 340 (Inspektor) = 1130,
        // mit Luft 1140. Die 600 sind gemessen, nicht gerechnet — die
        // Detailspalte eines NavigationSplitView geht nicht darunter, gleich
        // was ihr Inhalt fordert; bei einem 980 breiten Fenster wurden beide
        // Leisten angeschnitten, nicht die Mitte.
        //
        // Nur am Mac: Kein iPad erreicht 1140 im Hochformat (das groesste hat
        // 1024), und geteilt bricht es immer. Dort gibt es kein Fenster zu
        // ziehen, die Forderung schnitte nur ab.
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
        // Protokoll, Einstellungen und Hilfe bleiben unten abgesetzt, statt
        // in derselben Liste mitzulaufen — eine zweite List traegt dieselbe
        // Auswahl ($bereich) und dieselbe Reihen-Optik wie die obere.
        .safeAreaInset(edge: .bottom) {
            List(selection: $bereich) {
                ForEach(Bereich.unten) { b in
                    Label(lok(b.rawValue), systemImage: b.symbol).tag(b)
                }
                hilfezeile
            }
            // Drei Zeilen, kein Rollen: Bei 76 war der Inhalt fuer zwei ein
            // paar Punkte hoeher als die Liste, und sie bot einen Rollbalken
            // an; 44 je Zeile haelt denselben Abstand.
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .frame(height: 132)
        }
        // Feste Breite, kein Spielraum: Schrumpft das Fenster, gibt nur die
        // Mitte nach — nicht die Seitenleiste. Wie bei Finder und Mail.
        // Auf dem iPad zugleich ein Gewinn: 220 statt der dortigen Vorgabe von
        // rund 320 laesst quer genug fuer Mitte und Inspektor uebrig.
        //
        // Woher die Zahlen kommen, steht in `Seitenleiste` — gemessen an
        // „Einstellungen", das bei 170 und bei 190 auf dem iPad umbrach.
        // Am Mac bleibt es bei 190: Dort ist die Zeilenschrift 13 statt 17
        // Punkte gross, und die Mindestbreite des Fensters unten haengt daran.
        .navigationSplitViewColumnWidth(Seitenleiste.breite)
        #if !os(macOS)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { nebenfensterMenue } }
        #endif
    }

    /// Oeffnet die Hilfe — am Mac das Fenster der `Window`-Szene, auf dem iPad
    /// die ganzflaechige Einblendung.
    ///
    /// Ein Knopf und keine Zeile mit `tag`: Als `Bereich` stuende in der
    /// Detailspalte eine `NavigationSplitView` in einer `NavigationSplitView`,
    /// und die Auswahl bliebe auf „Hilfe" stehen.
    ///
    /// Am Mac steht die Hilfe zusaetzlich im Hilfe-Menue. Die Doppelung ist
    /// beabsichtigt: Das iPad hat keine Menueleiste (erst iPadOS 26, die App
    /// laeuft ab iOS 17).
    @ViewBuilder
    private var hilfezeile: some View {
        Button {
            #if os(macOS)
            fensterOeffnen?(Nebenfenster.hilfe.id)
            #else
            nebenfenster = .hilfe
            #endif
        } label: {
            Label(Nebenfenster.hilfe.titel, systemImage: Nebenfenster.hilfe.symbol)
                // Sonst faerbt der Knopfkanon die Zeile blau, waehrend die
                // beiden darueber in der Schriftfarbe stehen.
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Kein ⌘?: Das Hilfe-Menue am Mac traegt es schon, und zwei Halter
        // desselben Kuerzels schliessen einander aus.
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
/// Die Kopfzeile ist gezeichnet, nicht als `.toolbar` angemeldet, und gilt ohne
/// Fallunterscheidung für alle Nebenfenster: Eine Werkzeugleiste, die von außen
/// auf eine Ansicht mit eigener `NavigationSplitView` gelegt wird (Hilfe,
/// Gerätereferenz), findet keinen Navigationsbehälter, übersetzt klaglos und
/// wird nie gezeichnet — der Schließknopf fehlt dann, ohne dass es auffällt.
/// `safeAreaInset` ist reine Anordnung und kann nicht still ausfallen.
/// `PlattformwegeTests` hält beides fest.
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
