import SwiftUI

@main
struct TC002App: App {
    var body: some Scene {
        WindowGroup("MQTT-TC002") {
            Text("MQTT-TC002")
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}
