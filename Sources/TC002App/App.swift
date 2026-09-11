import AppKit
import SwiftUI

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
            .frame(minWidth: 900, minHeight: 620)
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
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("MQTT-TC002-Hilfe") { openWindow(id: "hilfe") }
                    .keyboardShortcut("?", modifiers: .command)
            }
        }

        Window("Hilfe", id: "hilfe") {
            HilfeView()
        }
        .windowResizability(.contentSize)
    }
}
