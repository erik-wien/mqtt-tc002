import Foundation

/// Das Buendel, in dem das laufende Programm steckt.
///
/// `Bundle.main` taugt dafuer nicht durchgehend. Wird das Kommandozeilen-
/// werkzeug ueber einen Verweis gestartet — und genau so gehoert es benutzt,
/// `~/.local/bin/mqtttc002` zeigt auf `…/MQTT-TC002.app/Contents/MacOS/…` —,
/// dann zeigt `Bundle.main` auf den Ordner des Verweises. Dort liegt kein
/// Buendel: keine Fassungsnummer, keine Schriften, keine Uebersetzungen. Und
/// nichts davon meldet sich, es fehlt nur alles still.
///
/// Deshalb wird der Pfad der laufenden Datei aufgeloest und von dort nach oben
/// gesucht, ob ein `.app` darueber liegt.
public enum Programmbuendel {
    /// Einmal ermittelt; der Pfad aendert sich zur Laufzeit nicht.
    public static let eigenes: Bundle = ermitteln()

    private static func ermitteln() -> Bundle {
        // Hat `Bundle.main` selbst eine Info.plist, ist es das richtige — das
        // ist der Fall der App und der Fall „direkt im Buendel aufgerufen".
        if Bundle.main.bundleIdentifier != nil { return .main }

        guard let datei = laufendeDatei() else { return .main }
        // …/MQTT-TC002.app/Contents/MacOS/mqtttc002 → drei Ebenen hinauf.
        var ordner = datei.deletingLastPathComponent()
        for _ in 0..<3 {
            if ordner.pathExtension == "app", let b = Bundle(url: ordner) { return b }
            ordner = ordner.deletingLastPathComponent()
        }
        return .main
    }

    /// Der aufgeloeste Pfad der laufenden Datei. `executableURL` zeigt bei einem
    /// Verweis auf den Verweis selbst, deshalb `resolvingSymlinksInPath`.
    private static func laufendeDatei() -> URL? {
        if let pfad = Bundle.main.executableURL?.resolvingSymlinksInPath(),
           FileManager.default.fileExists(atPath: pfad.path) {
            return pfad
        }
        guard let erstes = CommandLine.arguments.first else { return nil }
        let url = URL(fileURLWithPath: erstes).resolvingSymlinksInPath()
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
