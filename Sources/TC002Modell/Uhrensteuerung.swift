import Foundation
import TC002Core

/// Der Drehknopf (`<P>/event/knob`, §3.5): Rasten, positiv im Uhrzeigersinn.
/// `zaehler` wächst mit jeder Meldung, damit eine Ansicht auch zwei gleiche
/// aufeinanderfolgende bemerkt.
public struct Drehknopfstand: Equatable, Sendable {
    public var letzteRasten: Int
    /// Alle Rasten seit dem Start der App.
    public var summe: Int
    public var zaehler: Int
}

/// Fernsteuerung und Zustand der Uhren, so wie die spätere Steuerungsseite sie
/// braucht: Befehle an die gewählten Uhren, danach der Stand von der Uhr selbst.
///
/// Wie bei jeder Sendung gilt der Kanal der Uhr (`Anzeigen.fuer`); gelesen wird
/// über HTTP, wo die Uhr eine Adresse hat. Bei MQTT-Uhren hält das Mitlesen den
/// Stand frisch (`AppZustand.themen(fuer:)`).
extension AppZustand {
    func steuerungszustandVergessen(_ id: UUID) {
        geraetezustand[id] = nil
        anzeigestand[id] = nil
        uhreneinstellungen[id] = nil
        aktiveAnzeige[id] = nil
        tlsStatus[id] = nil
        tasten[id] = nil
        drehknopf[id] = nil
        uhrenfehler[id] = nil
    }

    // MARK: - Zustand

    /// Fragt die Uhr nach Gerät, Anzeige, Einstellungen und — wenn sie es kann —
    /// dem TLS-Stand und legt die Antworten ab. Über HTTP, also nur mit Adresse.
    ///
    /// Eine Uhr, die nicht antwortet, ist kein Fehler zum Wegklicken (wie bei
    /// `abfragen`): `erreichbar` wird `false`, im Protokoll steht eine Zeile.
    /// Gelingt nur das Gerät, bleibt der Rest, wie er war.
    @discardableResult
    public func zustandAbfragen(_ id: UUID) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }), !uhr.host.isEmpty else { return false }
        let host = uhr.host, sitzung = netzsitzung
        let tls = faehigkeiten[id]?.mqttTlsUnterstuetzt == true
        do {
            let (geraetStand, anzeige, einstellungen, verschluesselung) = try await Hintergrund.lauf {
                () throws -> (Geraetezustand, Anzeigestand?, Geraeteeinstellungen?, TLSStatus?) in
                let g = Geraet(host: host, sitzung: sitzung)
                return (try g.geraetezustand(), try? g.anzeigestand(), try? g.einstellungen(),
                        tls ? (try? g.tlsStatus()) : nil)
            }
            guard uhren.contains(where: { $0.id == id }) else { return false }
            erreichbar[id] = true
            geraetezustand[id] = geraetStand
            if let name = geraetStand.aktiveAnzeige { aktiveAnzeige[id] = name }
            if let anzeige { anzeigestand[id] = anzeige }
            if let einstellungen { uhreneinstellungen[id] = einstellungen }
            if let verschluesselung { tlsStatus[id] = verschluesselung }
            return true
        } catch {
            guard uhren.contains(where: { $0.id == id }) else { return false }
            erreichbar[id] = false
            log(lokf("%@ hat auf die Zustandsabfrage nicht geantwortet", uhr.name))
            return false
        }
    }

    /// Fragt alle Uhren mit Adresse, nebeneinander.
    public func alleZustandAbfragen() async {
        let ids = uhren.filter { !$0.host.isEmpty }.map(\.id)
        await withTaskGroup(of: Void.self) { gruppe in
            for id in ids { gruppe.addTask { [weak self] in await self?.zustandAbfragen(id) } }
        }
    }

    /// Was die Uhr von sich aus meldet (`state/*`, `event/*`), in den Zustand.
    func ereignisUebernehmen(_ ereignis: Uhrenereignis, fuer uhr: Uhr) {
        let id = uhr.id
        switch ereignis {
        case .geraet(let z):
            geraetezustand[id] = z
            if let name = z.aktiveAnzeige { aktiveAnzeige[id] = name }
            if var a = anzeigestand[id] {
                if let an = z.panelAn { a.an = an }
                if let h = z.helligkeit { a.helligkeit = h }
                anzeigestand[id] = a
            }
        case .einstellungen(let e):
            uhreneinstellungen[id] = e
            if var a = anzeigestand[id], let h = e.ganzzahl(.brightness) {
                a.helligkeit = h
                anzeigestand[id] = a
            }
        case .aktiveAnzeige(let name):
            aktiveAnzeige[id] = name
        case .taste(let taste, let gedrueckt):
            tasten[id, default: [:]][taste] = gedrueckt
        case .drehknopf(let rasten):
            let alt = drehknopf[id]
            drehknopf[id] = Drehknopfstand(letzteRasten: rasten, summe: (alt?.summe ?? 0) + rasten,
                                           zaehler: (alt?.zaehler ?? 0) + 1)
        case .fehler(let f):
            uhrenfehler[id] = f
            log(lokf("%@ meldet eine Abweisung: %@ (%@)", uhr.name, f.fehler, f.anfrage))
        }
    }

    // MARK: - Befehle an die gewählten Uhren

    /// Führt einen Steuerbefehl bei den gewählten Uhren aus und holt danach den
    /// Stand von jeder erreichten Uhr mit Adresse — sie ist die Wahrheit, vor
    /// allem bei einem Moodlight, dessen fehlende Felder ihren alten Wert behalten.
    @discardableResult
    private func steuern(was: String, _ tat: @escaping @Sendable (Anzeigen, Uhr, Geraetefaehigkeiten?) throws -> Void) async -> Sendebilanz {
        let caps = faehigkeiten
        var erreicht: [Uhr] = []
        let ziele = await anZiele({ anzeigen, uhr in try tat(anzeigen, uhr, caps[uhr.id]) }, was: was) { uhr, _ in
            erreicht.append(uhr)
        }
        for uhr in erreicht where !uhr.host.isEmpty { await zustandAbfragen(uhr.id) }
        return Sendebilanz(erreicht: erreicht.map(\.name), ziele: ziele)
    }

    /// Panel an oder aus (`power`).
    @discardableResult
    public func panelSchalten(an: Bool) async -> Sendebilanz {
        await steuern(was: an ? lok("Display einschalten") : lok("Display ausschalten")) { anzeigen, _, _ in
            try anzeigen.anzeigeStrom(an)
        }
    }

    /// Helligkeit 0–255, roh.
    @discardableResult
    public func helligkeitSetzen(_ wert: Int) async -> Sendebilanz {
        await steuern(was: lok("Helligkeit")) { anzeigen, _, caps in
            try anzeigen.helligkeit(wert, faehigkeiten: caps)
        }
    }

    /// Wetter-Overlay; `nil` nimmt es weg.
    @discardableResult
    public func overlaySetzen(_ name: String?) async -> Sendebilanz {
        await steuern(was: lok("Overlay")) { anzeigen, _, caps in
            try anzeigen.overlay(name, faehigkeiten: caps)
        }
    }

    @discardableResult
    public func moodlightSetzen(_ licht: Moodlight) async -> Sendebilanz {
        await steuern(was: lok("Moodlight")) { anzeigen, _, _ in try anzeigen.moodlight(licht) }
    }

    @discardableResult
    public func moodlightAusschalten() async -> Sendebilanz {
        await steuern(was: lok("Moodlight ausschalten")) { anzeigen, _, _ in try anzeigen.moodlightAus() }
    }

    @discardableResult
    public func indikatorSetzen(_ stand: Indikator) async -> Sendebilanz {
        await steuern(was: lokf("Anzeiger %d", stand.nummer)) { anzeigen, _, _ in try anzeigen.indikator(stand) }
    }

    @discardableResult
    public func indikatorAusschalten(_ nummer: Int) async -> Sendebilanz {
        await steuern(was: lokf("Anzeiger %d", nummer)) { anzeigen, _, _ in try anzeigen.indikatorAus(nummer) }
    }

    /// Eine geprüfte Teilmenge der Einstellungen (`PATCH`). Die Prüfung gegen die
    /// Namenslisten der jeweiligen Uhr geschah beim Zusammenstellen; hier geht
    /// sie hinaus.
    @discardableResult
    public func einstellungenAendern(_ aenderung: Einstellungsaenderung) async -> Sendebilanz {
        await steuern(was: lok("Einstellungen der Uhr")) { anzeigen, _, _ in
            try anzeigen.einstellungenAendern(aenderung)
        }
    }

    // MARK: - MQTT über TLS

    /// Lädt die CA des Brokers auf die Uhr (`PUT /api/v1/mqtt/tls/ca`). Nur über
    /// HTTP, also nur mit Adresse; `true`, wenn die Uhr sie genommen hat. Schaltet
    /// TLS nicht ein.
    @discardableResult
    public func tlsCAHochladen(_ pem: String, fuer id: UUID) async -> Bool {
        await tlsAendern(id, was: lok("Zertifikat hochladen")) { try $0.tlsCAHochladen(pem: pem) }
    }

    /// Entfernt die hochgeladene CA (`DELETE /api/v1/mqtt/tls/ca`).
    @discardableResult
    public func tlsCAEntfernen(fuer id: UUID) async -> Bool {
        await tlsAendern(id, was: lok("Zertifikat entfernen")) { try $0.tlsCAEntfernen() }
    }

    private func tlsAendern(_ id: UUID, was: String,
                            _ tat: @escaping @Sendable (Geraet) throws -> TLSStatus?) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return false }
        guard !uhr.host.isEmpty else {
            fehler = lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name)
            return false
        }
        let host = uhr.host, sitzung = netzsitzung
        do {
            let stand = try await Hintergrund.lauf { try tat(Geraet(host: host, sitzung: sitzung)) }
            log(lokf("%@: %@", uhr.name, was))
            // Die Antwort des Hochladens ist nicht dokumentiert; der Stand kommt
            // sicherheitshalber von der Uhr.
            if let stand { tlsStatus[id] = stand }
            await zustandAbfragen(id)
            return true
        } catch {
            melde(error, uhr: uhr)
            return false
        }
    }
}
