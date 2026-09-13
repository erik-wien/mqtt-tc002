import AppKit
import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

@main
struct TC002App: App {
    /// Die mitgelieferten Schriften muessen angemeldet sein, **bevor** irgendeine
    /// Ansicht ihre Schriftliste aufbaut — die wird einmal berechnet und bleibt
    /// dann stehen. In .onAppear waere es zu spaet gewesen.
    ///
    /// Ebenfalls hier: die mitgelieferten Icons wandern beim allerersten Start
    /// in den Schreibordner (`Iconsammlung.grundschatzEinmalUebernehmen`) —
    /// auch das, bevor eine Ansicht die Iconliste zum ersten Mal liest.
    init() {
        Schriften.registrieren()
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
            .grundschatzEinmalUebernehmen()
    }

    @State private var zustand = AppZustand()
    @State private var bereich: Bereich? = .senden
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var phase

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
    }

    var body: some Scene {
        WindowGroup("MQTT-TC002") {
            hauptfenster
        }
        .defaultSize(width: 1360, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Über MQTT-TC002") { openWindow(id: "ueber") }
            }
            CommandGroup(replacing: .help) {
                Button("MQTT-TC002-Hilfe") { openWindow(id: "hilfe") }
                    .keyboardShortcut("?", modifiers: .command)
                Button("Gerätereferenz") { openWindow(id: "geraetereferenz") }
                Button("Schriftprobe") { openWindow(id: "schriftprobe") }
            }
            // Beide Ordner liegen normalerweise unsichtbar in der Library und
            // werden von Iconordner.eigene bzw. Bilderordner.eigene bei Bedarf
            // selbst angelegt — der Finder greift hier also nie ins Leere.
            CommandGroup(after: .newItem) {
                Divider()
                Button("Eigene Icons im Finder zeigen") {
                    NSWorkspace.shared.open(Iconordner.eigene)
                }
                Button("Eigene Bilder im Finder zeigen") {
                    NSWorkspace.shared.open(Bilderordner.eigene)
                }
            }
        }

        Window("Über MQTT-TC002", id: "ueber") {
            UeberView()
        }
        .windowResizability(.contentSize)

        Window("Hilfe", id: "hilfe") {
            HilfeView()
        }
        .windowResizability(.contentSize)

        Window("Gerätereferenz", id: "geraetereferenz") {
            GeraeteReferenzView()
        }
        .windowResizability(.contentSize)

        // Die Schriftprobe bekommt die angebotenen Groessen gereicht, statt sie
        // zu kennen: Die Ansicht zeigt, was gemessen wurde — und daneben, was
        // die durchgesehene Liste (`Pixelgroessen.abgesegnet`) daraus anbietet.
        Window("Schriftprobe", id: "schriftprobe") {
            SchriftprobeView(angeboteneGroessen: Pixelgroessen.abgesegnet)
        }
        .windowResizability(.contentSize)
    }

    private var hauptfenster: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(170)
        } detail: {
            switch bereich ?? .senden {
            case .senden: SendenView(zustand: zustand)
            case .malen: MalenView(zustand: zustand)
            case .icons: IconEditorView(zustand: zustand)
            case .verlauf: AnzeigenView(zustand: zustand)
            case .einstellungen: VerbindungView(zustand: zustand)
            }
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
        .frame(minWidth: 1120, minHeight: 640)
        .alert("Fehler", isPresented: Binding(
            get: { zustand.fehler != nil },
            set: { if !$0 { zustand.fehler = nil } })) {
            Button("OK") { zustand.fehler = nil }
        } message: { Text(zustand.fehler ?? "") }
        // ⌘Q verlaesst das Fokusfeld nicht — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort verloren, das noch nicht im Schluesselbund steht.
        //
        // `scenePhase` statt `willTerminate`: Auf dem iPad gibt es dazu keine
        // gleichwertige Benachrichtigung. Sie feuert dafuer oefter — das ist
        // hier folgenlos, weil `kennwortSichern()` bei unveraendertem Wert
        // nichts tut.
        //
        // Und weil beim harten Abschuss gar nichts feuert, haengt das Kennwort
        // nicht allein an dieser Zeile: `VerbindungView` sichert es schon beim
        // Verlassen des Feldes, bei der Eingabetaste und beim Ansichtswechsel.
        // Enger geht es nicht — jeder Tastendruck wuerde den Schluesselbund-
        // Eintrag loeschen und neu anlegen (siehe `AppZustand.kennwort`).
        .onChange(of: phase) { _, neu in
            if neu != .active { zustand.kennwortSichern() }
        }
        .onAppear {
            Netzfreigabe.anfragen()
            // Erst hier, nicht im Konstruktor: ein AppZustand allein soll keine
            // Verbindung aufbauen — sonst horchte auch jeder Test mit.
            zustand.horchenStarten()
        }
    }
}
