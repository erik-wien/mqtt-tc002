import Network

/// Loest die macOS-Freigabe „Lokales Netzwerk" schon beim Start aus. Sonst faellt
/// sie dem Nutzer beim ersten „Abfragen" in den Ruecken: der Dialog erscheint, und
/// derselbe Versuch scheitert waehrenddessen mit „Uhr nicht erreichbar" — einer
/// Meldung, die auf die falsche Ursache zeigt.
@MainActor
enum Netzfreigabe {
    /// Haelt den Browser die drei Sekunden am Leben, die der Dialog braucht.
    /// Nur vom Hauptthread angefasst — deshalb der Hauptakteur am Typ.
    private static var browser: NWBrowser?

    static func anfragen() {
        let b = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .tcp)
        browser = b
        b.start(queue: .global())
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            b.cancel()
            browser = nil
        }
    }
}
