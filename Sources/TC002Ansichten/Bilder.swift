import Foundation

/// Wo die Bilder dieses Ziels liegen.
///
/// `Bundle.module` taugt dafuer auf dem Mac **nicht**. Der von SwiftPM erzeugte
/// Zugriff sucht das Ressourcenbuendel unter `Bundle.main.bundleURL` — also
/// unmittelbar in `MQTT-TC002.app/` —, waehrend ein Mac-Programm seine
/// Ressourcen in `Contents/Resources` traegt. Er findet dort nichts und faellt
/// auf einen **fest eingebackenen Pfad in den `.build`-Ordner des
/// Entwicklungsrechners** zurueck. Das hat zwei Folgen:
///
/// - Auf dem Entwicklungsrechner laedt die App die unuebersetzte Fassung aus
///   `.build` und zeigt kein Bild, obwohl im Programm alles richtig liegt.
/// - Auf jedem anderen Rechner gibt es diesen Pfad nicht, und der erzeugte
///   Code bricht mit `fatalError` ab — die App stuerzt beim ersten Bild ab.
///
/// Am 12.09.2026 genau so beobachtet, nachzulesen im Systemprotokoll:
/// „No image named 'GeraeteRahmen' found in asset catalog for
/// …/.build/arm64-apple-macosx/release/TC002_TC002Ansichten.bundle".
///
/// Deshalb wird zuerst dort gesucht, wo das laufende Programm seine Ressourcen
/// wirklich hat. Das trifft beide Plattformen: Unter macOS ist
/// `resourceURL` der Ordner `Contents/Resources`, unter iOS die Buendelwurzel.
/// `Bundle.module` bleibt nur der Rueckfall fuer Tests.
public enum Bilder {
    static let name = "TC002_TC002Ansichten.bundle"

    public static let buendel: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name),
           let gefunden = Bundle(url: url) {
            return gefunden
        }
        return .module
    }()
}
