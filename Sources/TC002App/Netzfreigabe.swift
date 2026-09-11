import Network

/// Loest die macOS-Freigabe „Lokales Netzwerk" schon beim Start aus. Sonst faellt
/// sie dem Nutzer beim ersten „Abfragen" in den Ruecken: der Dialog erscheint, und
/// derselbe Versuch scheitert waehrenddessen mit „Uhr nicht erreichbar" — einer
/// Meldung, die auf die falsche Ursache zeigt.
enum Netzfreigabe {
    private static var browser: NWBrowser?

    static func anfragen() {
        let b = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .tcp)
        browser = b
        b.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            b.cancel()
            browser = nil
        }
    }
}
