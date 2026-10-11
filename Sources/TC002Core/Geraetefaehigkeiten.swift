import Foundation

/// Die Namenslisten einer AWTRIX NG aus `GET /api/v1/capabilities`
/// (`docs/awtrix-ng-protokoll.md` §5.5, §7.4).
///
/// Die Listen stehen nie im Code: Eine Firmware kann Effekte, Overlays oder
/// Paletten hinzufügen oder streichen, und ein fest eingetragener Name wäre dann
/// ein stiller `422`. Gelesen werden sie je Uhr zur Laufzeit; Oberflächen
/// zeigen daraus ihre Auswahl, `Darstellung.pruefen(gegen:)` prüft damit.
///
/// Die Namen behalten die Schreibweise der Uhr. Die Uhr vergleicht `effect` und
/// `overlay` ohne Rücksicht auf Groß-/Kleinschreibung (§5.5); `aufgeloest` tut
/// dasselbe und liefert die Schreibweise der Liste.
public struct Geraetefaehigkeiten: Equatable, Sendable {
    public var effekte: [String]
    /// Die Effekte, die eine Palette nutzen (`paletteEffects`).
    public var paletteneffekte: [String]
    public var overlays: [String]
    public var paletten: [String]
    public var uebergaenge: [String]
    /// `capabilities.layout`: ob die Uhr Layouts kann (§9). `nil`, solange nicht
    /// gefragt; ein Gerät, dessen Antwort das Feld nicht trägt (TC001/ESP32),
    /// kann es nicht.
    public var layoutUnterstuetzt: Bool?
    /// `capabilities.layouts.limits`; ohne Angabe die gemessenen Werte.
    public var layoutGrenzen = Layoutgrenzen()
    /// `capabilities.clockFaces` (`sheet`, `ring` …) — die Zifferblätter der Uhr-App.
    public var zifferblaetter: [String] = []
    /// `capabilities.mqttTls`: ob es `GET /api/v1/mqtt/tls` gibt (sonst `404`, §11.1).
    /// `nil`, solange nicht gefragt.
    public var mqttTlsUnterstuetzt: Bool?
    /// `capabilities.audio`: welche Klangquellen die Uhr kann (§7.4). `nil`,
    /// solange nicht gefragt und bei einer Antwort ohne `audio`: dann ist nichts
    /// gesperrt (`kann(_:)`).
    public var tonGemeldet: Tonfaehigkeiten?
    /// Ob ein Lautsprecher dran ist. Er lässt sich nicht erkennen
    /// (`audio.rtttl` ist auch ohne einen `true`); den Schalter gibt es bei der
    /// selbstgebauten Uhr (`Uhr.hatLautsprecher`). Ohne Lautsprecher kann die Uhr
    /// keine Klangart, und `ton` ist leer wie bei einer Uhr ohne Audio.
    public var lautsprecher = true
    /// `capabilities.audio` mit dem Lautsprecher verrechnet: Wer alle
    /// Klangfragen über `ton` und `kann(_:)` stellt, bekommt den Schalter
    /// ohne eigene Prüfung mit.
    public var ton: Tonfaehigkeiten? {
        get { lautsprecher ? tonGemeldet : Tonfaehigkeiten() }
        set { tonGemeldet = newValue }
    }
    /// `capabilities.sensors.light`: ob die Uhr einen Lichtsensor hat. Fehlt die
    /// Angabe, gilt „nein"; erst mit Sensor wirkt `autoBrightness`
    /// (`Geraeteeinstellung.wirkt(faehigkeiten:)`).
    public var lichtsensorGemeldet = false
    /// Bei der selbstgebauten Uhr meldet die Fähigkeit auch ohne Fotowiderstand
    /// `true`; dort zählt `ldrRaw == 0` als „kein Sensor" (`mitAusstattung`).
    public var ohneLichtmessung = false
    /// Ob ein Lichtsensor wirkt: gemeldet und nicht als fehlend erkannt.
    public var lichtsensor: Bool {
        get { lichtsensorGemeldet && !ohneLichtmessung }
        set { lichtsensorGemeldet = newValue }
    }
    /// `capabilities.platform.id` (`tc002`, `esp32` für die TC001). `nil`, solange
    /// nicht gefragt.
    public var plattform: String?

    /// Die TC001 (`esp32`) hat drei Tasten und keinen Drehknopf (ESP32-Zweig der
    /// Herstellerdoku); ohne Auskunft gilt „ja".
    public var hatDrehknopf: Bool { plattform != "esp32" }

    public init(effekte: [String] = [], paletteneffekte: [String] = [], overlays: [String] = [],
                paletten: [String] = [], uebergaenge: [String] = [],
                layoutUnterstuetzt: Bool? = nil, layoutGrenzen: Layoutgrenzen = Layoutgrenzen(),
                zifferblaetter: [String] = [], mqttTlsUnterstuetzt: Bool? = nil,
                ton: Tonfaehigkeiten? = nil, lichtsensor: Bool = false, plattform: String? = nil) {
        self.plattform = plattform
        self.tonGemeldet = ton
        self.lichtsensorGemeldet = lichtsensor
        self.zifferblaetter = zifferblaetter
        self.mqttTlsUnterstuetzt = mqttTlsUnterstuetzt
        self.layoutUnterstuetzt = layoutUnterstuetzt
        self.layoutGrenzen = layoutGrenzen
        self.effekte = effekte
        self.paletteneffekte = paletteneffekte
        self.overlays = overlays
        self.paletten = paletten
        self.uebergaenge = uebergaenge
    }

    /// Die Fähigkeiten, wie sie für diese Uhr gelten: bei der selbstgebauten
    /// Uhr ohne Lautsprecher kein Klang, und mit `ldrRaw` 0 kein Lichtsensor.
    /// Bei jedem anderen Modell bleibt die Antwort der Uhr unberührt. Ein
    /// echter Sensor in völliger Dunkelheit könnte 0 lesen; deshalb gilt die
    /// Regel nur für die Eigenbauuhr, nie für die TC001.
    public func mitAusstattung(fuer uhr: Uhr, zustand: Geraetezustand?) -> Geraetefaehigkeiten {
        var f = self
        f.lautsprecher = uhr.hatLautsprecher
        f.ohneLichtmessung = uhr.modell == .esp32DIY && zustand?.ldrRoh == 0
        return f
    }

    /// Aus der Antwort von `GET /api/v1/capabilities`. Eine fehlende oder
    /// anders getypte Liste ist leer; `nil` nur, wenn gar keine der fünf Listen
    /// darin steht (das war dann keine Fähigkeitsauskunft).
    public init?(antwort: [String: Any]) {
        func liste(_ schluessel: String) -> [String]? {
            (antwort[schluessel] as? [Any])?.compactMap { $0 as? String }
        }
        let alle = ["effects", "paletteEffects", "overlays", "palettes", "transitions"].map(liste)
        guard alle.contains(where: { $0 != nil }) else { return nil }
        self.init(effekte: alle[0] ?? [], paletteneffekte: alle[1] ?? [], overlays: alle[2] ?? [],
                  paletten: alle[3] ?? [], uebergaenge: alle[4] ?? [])
        layoutUnterstuetzt = antwort["layout"] as? Bool == true
        zifferblaetter = (antwort["clockFaces"] as? [Any])?.compactMap { $0 as? String } ?? []
        mqttTlsUnterstuetzt = antwort["mqttTls"] as? Bool == true
        plattform = (antwort["platform"] as? [String: Any])?["id"] as? String
        lichtsensor = (antwort["sensors"] as? [String: Any])?["light"] as? Bool == true
        ton = (antwort["audio"] as? [String: Any]).map { Tonfaehigkeiten(antwort: $0) }
        if let grenzen = (antwort["layouts"] as? [String: Any])?["limits"] as? [String: Any] {
            layoutGrenzen = Layoutgrenzen(antwort: grenzen)
        }
    }

    /// Die Schreibweise aus der Liste, ohne Rücksicht auf Groß-/Kleinschreibung.
    public static func aufgeloest(_ name: String, in liste: [String]) -> String? {
        liste.first { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Ob dieser Effekt die Palette der Anzeige nutzt (§5.5: alle außer
    /// `PingPong`, `Matrix`, `LookingEyes`).
    public func nutztPalette(effekt: String) -> Bool {
        Self.aufgeloest(effekt, in: paletteneffekte) != nil
    }
}
