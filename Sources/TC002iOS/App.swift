import SwiftUI
import TC002Core
import TC002Modell

@main
struct TC002iOSApp: App {
    /// Die Schriften muessen vor der ersten Ansicht angemeldet sein: Die Liste
    /// der Schriftarten ist eine statische Eigenschaft und wird nur einmal
    /// ausgewertet. In `.onAppear` waere es zu spaet.
    init() {
        Schriften.registrieren()
    }

    var body: some Scene {
        WindowGroup {
            Text("Hallo")
        }
    }
}
