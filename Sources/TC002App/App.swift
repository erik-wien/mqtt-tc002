import AppKit
import SwiftUI
import TC002Core

@main
struct TC002App: App {
    @State private var zustand = AppZustand()
    @State private var bereich: Bereich? = .senden
    @Environment(\.openWindow) private var openWindow

    enum Bereich: String, CaseIterable, Identifiable {
        case senden = "Senden", malen = "Malen", anzeigen = "Anzeigen", verbindung = "Verbindung", icons = "Icons"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .senden: return "paperplane"
            case .malen: return "paintbrush"
            case .anzeigen: return "list.bullet"
            case .verbindung: return "antenna.radiowaves.left.and.right"
            case .icons: return "paintpalette"
            }
        }
    }

    var body: some Scene {
        WindowGroup("MQTT-TC002") {
            hauptfenster
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Über MQTT-TC002") { openWindow(id: "ueber") }
            }
            CommandGroup(replacing: .help) {
                Button("MQTT-TC002-Hilfe") { openWindow(id: "hilfe") }
                    .keyboardShortcut("?", modifiers: .command)
                Button("Gerätereferenz") { openWindow(id: "geraetereferenz") }
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
    }

    private var hauptfenster: some View {
        NavigationSplitView {
            List(Bereich.allCases, selection: $bereich) { b in
                Label(b.rawValue, systemImage: b.symbol).tag(b)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 220)
        } detail: {
            switch bereich ?? .senden {
            case .senden: SendenView(zustand: zustand)
            case .malen: MalenView(zustand: zustand)
            case .anzeigen: AnzeigenView(zustand: zustand)
            case .verbindung: VerbindungView(zustand: zustand)
            case .icons: IconEditorView(zustand: zustand)
            }
        }
        // Mindestgroesse: Seitenleiste (min. 150) plus die 52 Spalten der
        // Mal-/Vorschaufläche bei ihrer groessten Kantenlaenge (14) plus
        // Innenabstand — sonst faellt die Flaeche wie im gemeldeten Fall rechts
        // aus dem Fenster, bevor die reaktive Anpassung ueberhaupt eingreift.
        .frame(minWidth: 980, minHeight: 640)
        .alert("Fehler", isPresented: Binding(
            get: { zustand.fehler != nil },
            set: { if !$0 { zustand.fehler = nil } })) {
            Button("OK") { zustand.fehler = nil }
        } message: { Text(zustand.fehler ?? "") }
        // ⌘Q verlaesst das Fokusfeld nicht — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort verloren, das noch nicht im Schluesselbund steht.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            zustand.kennwortSichern()
        }
        .onAppear {
            Netzfreigabe.anfragen()
            Schriftregistrierung.schriftAnmelden()
            // Erst hier, nicht im Konstruktor: ein AppZustand allein soll keine
            // Verbindung aufbauen — sonst horchte auch jeder Test mit.
            zustand.horchenStarten()
        }
    }
}
