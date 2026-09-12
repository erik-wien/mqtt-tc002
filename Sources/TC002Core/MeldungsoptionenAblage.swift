import Foundation

public extension Meldungsoptionen {
    /// Liest die Formateinstellungen, die die Sendeansicht zuletzt abgelegt hat.
    ///
    /// Für alles, was nicht die Ansicht selbst ist — den App Intent vor allem.
    /// Ohne das sähe eine über Siri geschickte Meldung anders aus als dieselbe
    /// Meldung aus der App, und niemand käme darauf, warum.
    ///
    /// `text` bleibt leer; der kommt vom Aufrufer. Unsinnige Werte fallen auf
    /// die Vorgabe zurück statt zu scheitern — von Hand verbogene Einstellungen
    /// gibt es.
    static func ausAblage(_ d: UserDefaults) -> Meldungsoptionen {
        var o = Meldungsoptionen(text: "")
        if let s = d.string(forKey: "senden.schriftart"), !s.isEmpty { o.schrift = s }
        if let s = d.string(forKey: "senden.farbe"), !s.isEmpty { o.farbe = s }
        if d.object(forKey: "senden.groesse") != nil { o.groesse = d.double(forKey: "senden.groesse") }
        if d.object(forKey: "senden.fett") != nil { o.fett = d.bool(forKey: "senden.fett") }
        if d.object(forKey: "senden.luecke") != nil { o.abstand = d.integer(forKey: "senden.luecke") }
        if d.object(forKey: "senden.rand") != nil { o.rand = d.integer(forKey: "senden.rand") }
        if d.object(forKey: "senden.grossbuchstaben") != nil {
            o.grossbuchstaben = d.bool(forKey: "senden.grossbuchstaben")
        }
        if d.object(forKey: "senden.iconmitlaufend") != nil {
            o.iconLaeuftMit = d.bool(forKey: "senden.iconmitlaufend")
        }
        o.weg = d.string(forKey: "senden.weg").flatMap(SendeWeg.init(rawValue:)) ?? o.weg
        o.waagrecht = d.string(forKey: "senden.horizontal")
            .flatMap(SendenHAusrichtung.init(rawValue:)) ?? o.waagrecht
        o.senkrecht = d.string(forKey: "senden.vertikal")
            .flatMap(SendenVAusrichtung.init(rawValue:)) ?? o.senkrecht
        o.tempo = d.string(forKey: "senden.tempo").flatMap(Lauftempo.init(rawValue:)) ?? o.tempo
        return o
    }
}
