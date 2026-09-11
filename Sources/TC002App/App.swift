import SwiftUI

@main
struct TC002App: App {
    @State private var zustand = AppZustand()
    @State private var bereich: Bereich? = .senden

    enum Bereich: String, CaseIterable, Identifiable {
        case senden = "Senden", malen = "Malen", anzeigen = "Anzeigen", verbindung = "Verbindung"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .senden: return "paperplane"
            case .malen: return "paintbrush"
            case .anzeigen: return "list.bullet"
            case .verbindung: return "antenna.radiowaves.left.and.right"
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
                case .verbindung: VerbindungView(zustand: zustand)
                default: Text("kommt in der nächsten Aufgabe").foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 900, minHeight: 620)
            .alert("Fehler", isPresented: Binding(
                get: { zustand.fehler != nil },
                set: { if !$0 { zustand.fehler = nil } })) {
                Button("OK") { zustand.fehler = nil }
            } message: { Text(zustand.fehler ?? "") }
        }
        .windowResizability(.contentMinSize)
    }
}
