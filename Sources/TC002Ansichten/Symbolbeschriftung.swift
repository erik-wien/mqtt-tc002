import SwiftUI

/// Ein Symbolknopf, dessen Name am Mac im Einblendtext steht und am iPad
/// gleich daneben — dort gibt es kein Verweilen, das ihn zeigen könnte.
///
/// Gilt nur für Knöpfe, die **für sich allein** stehen und nichts als ihr
/// Symbol zeigen — eine Werkzeugleiste etwa, oder ein einzelnes Zeichen neben
/// einer Liste. Ein Regler in einer `Form` zeigt seinen Wert ohnehin als
/// Text; was er bedeutet, steht dort in der Hilfe, nicht hier.
///
/// `Label` bleibt dabei die eine Bauart für beide Geräte: Am Mac blendet
/// `.iconOnly` die Schrift aus (dasselbe Bild wie zuvor), am iPad zeigt
/// `.titleAndIcon` sie an. Der Aufrufer setzt `.help(...)` daneben
/// unverändert weiter — für den Mac ändert sich nichts.
public extension View {
    @ViewBuilder
    func namensichtbarAmIPad() -> some View {
        #if os(macOS)
        self.labelStyle(.iconOnly)
        #else
        self.labelStyle(.titleAndIcon)
        #endif
    }
}
