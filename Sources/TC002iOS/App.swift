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
    ///
    /// Ebenfalls hier, und aus demselben Grund wie am Mac: die mitgelieferten
    /// Icons wandern beim allerersten Start in den Schreibordner — bevor eine
    /// Ansicht die Iconliste zum ersten Mal liest.
    init() {
        Schriften.registrieren()
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
            .grundschatzEinmalUebernehmen()
    }

    var body: some Scene {
        WindowGroup {
            // Keine Reiterleiste: „Senden" ist die ganze App, „Verlauf" und
            // „Einstellungen" haengen als Menuepunkte in ihrer Titelleiste und
            // gehen als Blatt auf. `SendeniOS` bringt ihren eigenen
            // `NavigationStack` mit; hier darf deshalb keiner mehr herum.
            SendeniOS(zustand: zustand)
            .onAppear {
                // Ohne diesen Aufruf bleibt `horchenErlaubt` false, und
                // `horchenAbgleichen()` kehrt an seinem guard sofort zurueck:
                // Die App baut dann **kein einziges** Abonnement auf, hoert die
                // Uhr nie und sieht aus, als kaeme sie nicht ins Netz. Am Mac
                // steht derselbe Aufruf in `.onAppear` (App.swift).
                // Erst hier, nicht im Konstruktor: ein AppZustand allein soll
                // keine Verbindung aufbauen, sonst horchte auch jeder Test mit.
                zustand.horchenStarten()
            }
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
