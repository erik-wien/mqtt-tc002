import SwiftUI
import TC002Core

/// Die vier Dokumente neben der Hauptansicht: Über, Hilfe, Gerätereferenz,
/// Schriftprobe.
///
/// Am Mac ist jedes ein eigenes Fenster (`Window`-Szene in
/// `TC002App/App.swift`), auf dem iPad eine ganzflächige Einblendung aus dem
/// Menü der Seitenleiste (`SchreibtischView`). Der Grund für die zwei Wege:
/// `Window` gibt es unter iOS nicht, und `openWindow(id:)` übersetzt dort
/// klaglos und tut zur Laufzeit nichts — ein Knopf, der schweigt.
///
/// Damit die zwei Wege nicht auseinanderlaufen, liest keine Seite ihre eigene
/// Liste: Der Mac benennt seine Szenen über `id`, das iPad zählt
/// `allCases` auf. Ein fünftes Dokument kommt damit auf beiden Geräten an oder
/// auf keinem.
public enum Nebenfenster: String, CaseIterable, Identifiable, Sendable {
    /// Nur „Über", nicht „Über MQTT-TC002": Der Name steht gleich darunter im
    /// Inhalt noch einmal — am iPad in der Kopfzeile über der Einblendung, am
    /// Mac in der Titelleiste unmittelbar über derselben Überschrift. Der
    /// Menüeintrag im Programmmenü heißt weiterhin „Über MQTT-TC002", wie es
    /// am Mac üblich ist; er steht als eigener Wortlaut in `App.swift`.
    case ueber = "Über"
    case hilfe = "Hilfe"
    case geraetereferenz = "Gerätereferenz"
    case schriftprobe = "Schriftprobe"
    case virtuelleUhr = "Virtuelle Uhr"

    /// Zugleich die Kennung der `Window`-Szene am Mac.
    public var id: String {
        switch self {
        case .ueber: return "ueber"
        case .hilfe: return "hilfe"
        case .geraetereferenz: return "geraetereferenz"
        case .schriftprobe: return "schriftprobe"
        case .virtuelleUhr: return "virtuelleUhr"
        }
    }

    /// Schon übersetzt: `rawValue` ist der Schlüssel, nicht der fertige Text.
    /// Die vier Wortlaute stehen deshalb von Hand in `DYNAMISCH`
    /// (`scripts/texte-sammeln.py`) — der Sammler sieht `lok(x.rawValue)` nicht.
    public var titel: String { lok(rawValue) }

    public var symbol: String {
        switch self {
        case .ueber: return "info.circle"
        case .hilfe: return "questionmark.circle"
        case .geraetereferenz: return "doc.text"
        case .schriftprobe: return "textformat.size"
        case .virtuelleUhr: return "display"
        }
    }

    /// `@MainActor`, seit die virtuelle Uhr dazugehoert: Ihr Betrieb ist an
    /// den Hauptthread gebunden. Gebaut werden diese Ansichten ohnehin nur
    /// dort — in einer `Scene` am Mac und in einer Einblendung am iPad.
    @MainActor @ViewBuilder public var inhalt: some View {
        switch self {
        case .ueber: UeberView()
        case .hilfe: HilfeView()
        case .geraetereferenz: GeraeteReferenzView()
        // Die Schriftprobe bekommt die angebotenen Groessen gereicht, statt sie
        // zu kennen: Die Ansicht zeigt, was gemessen wurde — und daneben, was
        // die durchgesehene Liste (`Pixelgroessen.abgesegnet`) daraus anbietet.
        case .schriftprobe: SchriftprobeView(angeboteneGroessen: Pixelgroessen.abgesegnet)
        // Kein Dokument, sondern ein Blick auf etwas Laufendes — und darum
        // das einzige dieser Fenster, das sich von selbst aendert.
        case .virtuelleUhr: VirtuelleUhrView(betrieb: .gemeinsam)
        }
    }
}
