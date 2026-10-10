import Foundation

/// Die Fernsteuerung der Uhr auf dem Kanal, den die Uhr eingestellt hat: Panel,
/// Helligkeit, Overlay, Moodlight, Anzeiger und die gespeicherten Einstellungen
/// (`docs/awtrix-ng-protokoll.md` §3.2, §4.2, §10).
///
/// Dieselbe Nutzlast auf beiden Kanälen (§3): Was über MQTT auf
/// `<P>/cmd/display` geht, ist der Rumpf von `PATCH /api/v1/display`. Nur das
/// Ausschalten fällt auseinander — über MQTT löscht ein leerer Rumpf
/// (Moodlight, Anzeiger), über HTTP gibt es `DELETE`; ein `{}` wäre dort `422`.
extension Anzeigen {
    private func steuern(_ thema: (String) -> String, nutzlast: Data,
                         http: (Geraet) throws -> Void) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(nutzlast, an: thema(praefix), sender: sender, zugang: zugang)
        case .http(let geraet):
            try http(geraet)
        }
    }

    /// Schaltet das Panel ein oder aus (`power`). Aus ist das Panel dunkel; die
    /// Uhr läuft weiter.
    public func anzeigeStrom(_ an: Bool) throws {
        let json = Steuerfarbe.json([("power", .bool(an))])
        try steuern(NGThema.anzeigeSteuern, nutzlast: Data(json.utf8)) { try $0.anzeigeAendern(json) }
    }

    /// Wetter-Overlay über allem; `nil` oder leer nimmt es weg. Mit den Namen der
    /// Uhr (`capabilities.overlays`) wird vorher geprüft und die Schreibweise der
    /// Liste genommen; ohne sie weist die Uhr einen falschen selbst ab (`422`).
    public func overlay(_ name: String?, faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        var wert = JSONWert.null
        if let name, !name.isEmpty {
            if let liste = faehigkeiten?.overlays, !liste.isEmpty {
                guard let treffer = Geraetefaehigkeiten.aufgeloest(name, in: liste) else {
                    throw SteuerungsFehler.unbekannterName(feld: "overlay", wert: name)
                }
                wert = .text(treffer)
            } else {
                wert = .text(name)
            }
        }
        let json = Steuerfarbe.json([("overlay", wert)])
        try steuern(NGThema.anzeigeSteuern, nutzlast: Data(json.utf8)) { try $0.anzeigeAendern(json) }
    }

    /// Die Helligkeit des Panels, 0–255 roh (kein Prozentsatz). Sie ist eine
    /// gespeicherte Einstellung (`brightness`), kein Teil von `PATCH /display`.
    public func helligkeit(_ wert: Int, faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        var a = Einstellungsaenderung()
        try a.setzen(.brightness, .zahl(Double(wert)), faehigkeiten: faehigkeiten)
        try einstellungenAendern(a)
    }

    /// Flutet das Panel einfarbig.
    public func moodlight(_ licht: Moodlight) throws {
        let json = try licht.json()
        try steuern(NGThema.moodlight, nutzlast: Data(json.utf8)) { try $0.moodlightSetzen(json) }
    }

    /// Schaltet das Moodlight aus (`DELETE`, immer `200`; über MQTT ein leerer Rumpf).
    public func moodlightAus() throws {
        try steuern(NGThema.moodlight, nutzlast: Data()) { try $0.moodlightAus() }
    }

    public func indikator(_ stand: Indikator) throws {
        let json = try stand.json()
        try steuern({ NGThema.indikator(praefix: $0, nummer: stand.nummer) }, nutzlast: Data(json.utf8)) {
            try $0.indikatorSetzen(nummer: stand.nummer, json: json)
        }
    }

    /// Setzt den Anzeiger zurück und schaltet ihn aus (`DELETE`, immer `200`).
    public func indikatorAus(_ nummer: Int) throws {
        guard Indikator.nummern.contains(nummer) else { throw SteuerungsFehler.ungueltigeKennziffer(nummer) }
        try steuern({ NGThema.indikator(praefix: $0, nummer: nummer) }, nutzlast: Data()) {
            try $0.indikatorAus(nummer: nummer)
        }
    }

    /// `PATCH /api/v1/settings` bzw. `cmd/settings`: eine Teilmenge, alles
    /// geprüft, bevor etwas hinausgeht.
    public func einstellungenAendern(_ aenderung: Einstellungsaenderung) throws {
        let json = try aenderung.json()
        try steuern(NGThema.einstellungen, nutzlast: Data(json.utf8)) { try $0.einstellungenAendern(json) }
    }

    // MARK: - Lesen

    /// Der Zustand der Uhr. Mit Adresse über HTTP (`GET /api/v1/device`), das
    /// immer den jetzigen Stand nennt; ohne Adresse am MQTT-Kanal aus der
    /// aufbewahrten Nachricht auf `state/device` — die auch von gestern sein
    /// kann, wenn die Uhr inzwischen weg ist.
    public func geraetezustandLesen(frist: TimeInterval = 5,
                                    lauscher: ThemaLauschend = MQTTThemenlauscher()) throws -> Geraetezustand {
        switch kanal {
        case .http(let geraet): return try geraet.geraetezustand()
        case .mqtt(_, let zugang, let praefix, let ausweich):
            if let ausweich { return try ausweich.geraetezustand() }
            return try Geraetezustand(daten: try aufbewahrt(NGThema.zustandGeraet(praefix: praefix),
                                                            zugang: zugang, frist: frist, lauscher: lauscher))
        }
    }

    /// Die Einstellungen der Uhr, wie `geraetezustandLesen` (`state/settings`).
    public func einstellungenLesen(frist: TimeInterval = 5,
                                   lauscher: ThemaLauschend = MQTTThemenlauscher()) throws -> Geraeteeinstellungen {
        switch kanal {
        case .http(let geraet): return try geraet.einstellungen()
        case .mqtt(_, let zugang, let praefix, let ausweich):
            if let ausweich { return try ausweich.einstellungen() }
            return try Geraeteeinstellungen(daten: try aufbewahrt(NGThema.zustandEinstellungen(praefix: praefix),
                                                                  zugang: zugang, frist: frist, lauscher: lauscher))
        }
    }

    /// Die laufende Anzeige: `currentApp` des Gerätezustands bzw. die blanke
    /// Zeichenkette auf `state/apps/active`.
    public func aktiveAnzeigeLesen(frist: TimeInterval = 5,
                                   lauscher: ThemaLauschend = MQTTThemenlauscher()) throws -> String {
        switch kanal {
        case .http(let geraet):
            guard let name = try geraet.geraetezustand().aktiveAnzeige else { throw NGFehler.keineZustandsantwort }
            return name
        case .mqtt(_, let zugang, let praefix, _):
            let daten = try aufbewahrt(NGThema.zustandAktiveAnzeige(praefix: praefix),
                                       zugang: zugang, frist: frist, lauscher: lauscher)
            let name = String(decoding: daten, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw NGFehler.keineZustandsantwort }
            return name
        }
    }

    private func aufbewahrt(_ thema: String, zugang: MQTTZugang, frist: TimeInterval,
                            lauscher: ThemaLauschend) throws -> Data {
        // Aufbewahrt: Die Uhr (der Broker) liefert die Nachricht gleich beim Abonnieren, es
        // gibt nichts zu senden.
        guard let daten = try lauscher.erwarten(thema: thema, zugang: zugang, frist: frist, waehrend: {}) else {
            throw NGFehler.keineZustandsantwort
        }
        return daten
    }
}
