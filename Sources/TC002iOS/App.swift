import SwiftUI
import TC002Core
import TC002Modell

@main
struct TC002iOSApp: App {
    @State private var zustand = AppZustand()
    @Environment(\.scenePhase) private var phase

    /// Die Schriften muessen vor der ersten Ansicht angemeldet sein: Die Liste
    /// der Schriftarten ist eine statische Eigenschaft und wird nur einmal
    /// ausgewertet. In `.onAppear` waere es zu spaet.
    init() {
        Schriften.registrieren()
    }

    var body: some Scene {
        WindowGroup {
            // Keine Reiterleiste: „Senden" ist spaeter die ganze App,
            // „Verlauf" und „Einstellungen" haengen als Menuepunkte in ihrer
            // Titelleiste und gehen als Blatt auf. Solange es nur diese eine
            // Ansicht gibt, ist sie die Wurzel — Aufgabe 7 setzt „Senden"
            // davor. Jede dieser Ansichten bringt ihren eigenen
            // `NavigationStack` mit; hier darf deshalb keiner mehr herum.
            VerbindungiOS(zustand: zustand)
            .onChange(of: phase) { _, neu in
                // Eine offene MQTT-Verbindung ueberlebt den Hintergrund nicht.
                switch neu {
                case .background: zustand.inDenHintergrund()
                case .active:     zustand.ausDemHintergrund()
                default:          break
                }
            }
        }
    }
}
