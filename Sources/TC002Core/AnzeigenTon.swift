import Foundation

extension NGThema {
    /// Ein Klangobjekt oder eine Liste (1–4), §3.2.1.
    public static func tonSpielen(praefix: String) -> String { "\(praefix)/cmd/audio/play" }
    /// `{"group":…}`; leer hält alles an.
    public static func tonStoppen(praefix: String) -> String { "\(praefix)/cmd/audio/stop" }
    /// `{"stations":[…]}`.
    public static func sender(praefix: String) -> String { "\(praefix)/cmd/audio/stations" }
}

/// Klang auf dem Kanal, den die Uhr eingestellt hat. Abspielen, Anhalten und die
/// Senderliste gehen über beide Wege mit derselben Nutzlast; Melodien und alle
/// Lesewege gibt es nur über HTTP (`audio/*` kennt über MQTT keine Listen, §3.2).
extension Anzeigen {
    private func ton(_ thema: (String) -> String, nutzlast: Data, http: (Geraet) throws -> Void) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, let ausweich):
            let t = thema(praefix)
            // Dieselbe Weiche wie bei Anzeigen: Eine MQTT-Nachricht über 8192 Byte
            // verwirft die Uhr ohne Antwort (lange Liedtexte).
            switch try Pixelweg.zustellweg(nutzlastBytes: nutzlast.count, themaBytes: t.utf8.count,
                                           betriebsart: .mqtt) {
            case .mqtt:
                try veroeffentlichen(nutzlast, an: t, sender: sender, zugang: zugang)
            case .http:
                guard let ausweich else { throw NGFehler.keineAdresseFuerGrosse(bytes: nutzlast.count) }
                try http(ausweich)
            }
        case .http(let geraet):
            _ = try Pixelweg.zustellweg(nutzlastBytes: nutzlast.count, themaBytes: 0, betriebsart: .http)
            try http(geraet)
        }
    }

    private func nurHTTP<T>(_ lesen: (Geraet) throws -> T) throws -> T {
        switch kanal {
        case .http(let geraet): return try lesen(geraet)
        case .mqtt(_, _, _, let ausweich):
            guard let ausweich else { throw KlangFehler.nurUeberHTTP }
            return try lesen(ausweich)
        }
    }

    /// Spielt 1–4 Klänge; die Uhr nimmt den ersten, den sie spielen kann. Mit den
    /// Fähigkeiten der Uhr wird vorher geprüft, was sie nicht kann.
    public func tonSpielen(_ klaenge: [Klang], faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        let json = try Klangbau.spielen(klaenge, faehigkeiten: faehigkeiten)
        try ton(NGThema.tonSpielen, nutzlast: Data(json.utf8)) { try $0.tonSpielen(json) }
    }

    /// Hält eine Gruppe an, ohne Angabe alles. Über MQTT ist das eine leere
    /// Nutzlast, über HTTP `{}`.
    public func tonStoppen(_ gruppe: Tongruppe? = nil) throws {
        let json = Klangbau.stoppen(gruppe)
        try ton(NGThema.tonStoppen, nutzlast: gruppe == nil ? Data() : Data(json.utf8)) {
            try $0.tonStoppen(json)
        }
    }

    /// Ersetzt die ganze Senderliste (höchstens 32; eine leere Liste leert sie).
    public func senderSetzen(_ liste: [Radiosender]) throws {
        let json = try Klangbau.sender(liste)
        try ton(NGThema.sender, nutzlast: Data(json.utf8)) { try $0.senderSetzen(json) }
    }

    /// Legt eine Melodie an oder ersetzt sie (nur HTTP). `true`: neu angelegt.
    @discardableResult
    public func melodieSetzen(name: String, rtttl: String,
                              faehigkeiten: Geraetefaehigkeiten? = nil) throws -> Bool {
        let json = try Klangbau.melodie(name: name, rtttl: rtttl, faehigkeiten: faehigkeiten)
        return try nurHTTP { try $0.melodieSetzen(name: name, json: json) }
    }

    /// Löscht eine Melodie (nur HTTP); eine, die es nicht gibt, ist `404`.
    public func melodieLoeschen(name: String) throws {
        try Klangbau.melodienameInOrdnung(name)
        try nurHTTP { try $0.melodieLoeschen(name: name) }
    }

    /// Lädt eine MP3-Datei unter `name` hoch (nur HTTP). Eine gleichnamige MP3
    /// ersetzt die Uhr still; wer das nicht will, fragt vorher `mp3Lesen`.
    public func mp3Hochladen(name: String, daten: Data, faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        try nurHTTP { try $0.mp3Hochladen(name: name, daten: daten, faehigkeiten: faehigkeiten) }
    }

    /// Löscht eine MP3-Datei (nur HTTP); `name` ohne `.mp3`.
    public func mp3Loeschen(name: String) throws {
        guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
        try nurHTTP { try $0.mp3Loeschen(name: name) }
    }

    // MARK: - Lesen (nur HTTP)

    public func tonzustandLesen() throws -> Tonzustand { try nurHTTP { try $0.tonzustand() } }
    public func melodienLesen() throws -> Tonablage { try nurHTTP { try $0.melodien() } }
    public func mp3Lesen() throws -> Tonablage { try nurHTTP { try $0.mp3Dateien() } }
    public func senderLesen() throws -> [Radiosender] { try nurHTTP { try $0.senderliste() } }
}
