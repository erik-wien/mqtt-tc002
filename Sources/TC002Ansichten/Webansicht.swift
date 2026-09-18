import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// Eine eingebettete Webseite.
///
/// **Die eine Stelle in diesem Ziel, die eine Plattform kennt.** Sonst gilt
/// hier: kein `import AppKit`, kein `import UIKit` (CLAUDE.md). Der Grund für
/// die Ausnahme ist, dass SwiftUI bis macOS 26 keine eigene Webansicht hat und
/// `WKWebView` nur über `NSViewRepresentable` bzw. `UIViewRepresentable`
/// einzusetzen ist. Der Unterschied betrifft vier Zeilen und bleibt in dieser
/// Datei; die Alternative wäre gewesen, aus jeder Oberfläche eine eigene
/// Ansicht hereinzureichen — mehr Bauteile für dieselbe Sache.
struct Webansicht: View {
    let adresse: URL

    var body: some View {
        #if canImport(WebKit)
        Traeger(adresse: adresse)
        #else
        // Ohne WebKit bleibt der Weg nach draußen.
        Link(lok("Im Browser öffnen"), destination: adresse)
        #endif
    }
}

#if canImport(WebKit)
#if os(macOS)
private struct Traeger: NSViewRepresentable {
    let adresse: URL

    func makeNSView(context: Context) -> WKWebView {
        let ansicht = WKWebView()
        ansicht.load(URLRequest(url: adresse))
        return ansicht
    }

    /// Nur bei wirklich neuer Adresse neu laden: `updateNSView` läuft bei
    /// jedem Neuzeichnen, und ein Ladebefehl darin setzte die Seite bei jedem
    /// Tastendruck im Nummernfeld daneben zurück.
    func updateNSView(_ ansicht: WKWebView, context: Context) {
        guard ansicht.url != adresse, !ansicht.isLoading else { return }
        ansicht.load(URLRequest(url: adresse))
    }
}
#else
private struct Traeger: UIViewRepresentable {
    let adresse: URL

    func makeUIView(context: Context) -> WKWebView {
        let ansicht = WKWebView()
        ansicht.load(URLRequest(url: adresse))
        return ansicht
    }

    func updateUIView(_ ansicht: WKWebView, context: Context) {
        guard ansicht.url != adresse, !ansicht.isLoading else { return }
        ansicht.load(URLRequest(url: adresse))
    }
}
#endif
#endif
