import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell
import UIKit

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
            wurzel
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
                // Dasselbe Netz wie am Mac: Ein eben eingetipptes Kennwort steht
                // noch nicht im Schluesselbund. Auf dem iPad sind die
                // Einstellungen ein Bereich der Seitenleiste und nicht ein
                // Blatt, das sich schliesst — `VerbindungView.onDisappear`
                // greift also nicht, wenn die App aus den Einstellungen heraus
                // in den Hintergrund geht. Folgenlos, wenn nichts zu sichern
                // ist.
                if neu != .active { zustand.kennwortSichern() }
                // Eine offene MQTT-Verbindung ueberlebt den Hintergrund nicht.
                switch neu {
                case .background: zustand.inDenHintergrund()
                case .active:     zustand.ausDemHintergrund()
                default:          break
                }
            }
        }
    }

    /// Zwei Oberflaechenfamilien, nicht eine.
    ///
    /// iPad: der Schreibtisch, derselbe wie am Mac — „ipad=desktop".
    /// iPhone: `SendeniOS` als Wurzel, ohne Reiterleiste; „Verlauf" und
    /// „Einstellungen" haengen als Menuepunkte in ihrer Titelleiste und gehen
    /// als Blatt auf. `SendeniOS` bringt ihren eigenen `NavigationStack` mit;
    /// hier darf deshalb keiner mehr herum.
    ///
    /// Am **Idiom**, nicht an der Groessenklasse: Die wechselt in der geteilten
    /// Ansicht und beim Schieben eines Fensters im Stage Manager. Eine
    /// Oberflaeche, die dabei die Familie wechselt, wirft jedes Mal ihren
    /// Zustand weg — und die beiden Familien teilen sich zwar dieselben
    /// `@AppStorage`-Schluessel, aber nicht ihre `@State`.
    @ViewBuilder private var wurzel: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            SchreibtischView(zustand: zustand)
        } else {
            SendeniOS(zustand: zustand)
        }
    }
}
