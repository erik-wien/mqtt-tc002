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
        bildschirm[id] = nil
        tonzustand[id] = nil
        tonlisten[id] = nil
        mp3Ablage[id] = nil
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
        // Ohne Auskunft über die Fähigkeiten wird gefragt; eine Uhr ohne Audio antwortet mit 404 (`try?`).
        let ton = faehigkeiten[id].map { $0.ton != nil } ?? true
        do {
            let (geraetStand, anzeige, einstellungen, verschluesselung, tonStand) = try await Hintergrund.lauf {
                () throws -> (Geraetezustand, Anzeigestand?, Geraeteeinstellungen?, TLSStatus?, Tonzustand?) in
                let g = Geraet(host: host, sitzung: sitzung)
                return (try g.geraetezustand(), try? g.anzeigestand(), try? g.einstellungen(),
                        tls ? (try? g.tlsStatus()) : nil, ton ? (try? g.tonzustand()) : nil)
            }
            guard uhren.contains(where: { $0.id == id }) else { return false }
            erreichbar[id] = true
            geraetezustand[id] = geraetStand
            if let name = geraetStand.aktiveAnzeige { aktiveAnzeige[id] = name }
            if let anzeige { anzeigestand[id] = anzeige }
            if let einstellungen { uhreneinstellungen[id] = einstellungen }
            if let verschluesselung { tlsStatus[id] = verschluesselung }
            if let tonStand { tonzustand[id] = tonStand }
            return true
        } catch {
            guard uhren.contains(where: { $0.id == id }) else { return false }
            erreichbar[id] = false
            log(lokf("%@ hat auf die Zustandsabfrage nicht geantwortet", uhr.name))
            return false
        }
    }

    /// Fragt den Zustand im Takt, bis die Aufgabe abgebrochen wird — für die
    /// Steuerungsseite, solange sie offen ist. Eine MQTT-Uhr ohne Adresse führt
    /// ihren Stand das Mitlesen nach; `zustandAbfragen` tut dort nichts.
    public func zustandFolgen(_ id: UUID, takt: Duration = .seconds(10)) async {
        while !Task.isCancelled {
            await zustandAbfragen(id)
            try? await Task.sleep(for: takt)
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
            // Sättigend: ein Zähler darf nie zum Absturz führen.
            func plus(_ a: Int, _ b: Int) -> Int {
                let (r, ueberlauf) = a.addingReportingOverflow(b)
                return ueberlauf ? (b > 0 ? Int.max : Int.min) : r
            }
            drehknopf[id] = Drehknopfstand(letzteRasten: rasten, summe: plus(alt?.summe ?? 0, rasten),
                                           zaehler: plus(alt?.zaehler ?? 0, 1))
        case .fehler(let f):
            uhrenfehler[id] = f
            log(lokf("%@ meldet eine Abweisung: %@ (%@)", uhr.name, f.fehler, f.anfrage))
        }
    }

    // MARK: - Befehle an die gewählten Uhren

    /// Führt einen Steuerbefehl aus und holt danach den Stand von jeder erreichten
    /// Uhr mit Adresse — sie ist die Wahrheit, vor allem bei einem Moodlight,
    /// dessen fehlende Felder ihren alten Wert behalten.
    ///
    /// Ohne `id` bei den gewählten Uhren, mit `id` bei genau dieser, ob gewählt
    /// oder nicht: Die Steuerungsseite zeigt den Stand **einer** Uhr, und ihre
    /// Schalter gelten dieser.
    @discardableResult
    private func steuern(was: String, fuer id: UUID? = nil,
                         _ tat: @escaping @Sendable (Anzeigen, Uhr, Geraetefaehigkeiten?) throws -> Void) async -> Sendebilanz {
        var einzige: Uhr?
        if let id {
            guard let uhr = uhren.first(where: { $0.id == id }) else { return Sendebilanz(erreicht: [], ziele: 0) }
            einzige = uhr
        }
        let caps = faehigkeiten
        var erreicht: [Uhr] = []
        let ziele = await anZiele({ anzeigen, uhr in try tat(anzeigen, uhr, caps[uhr.id]) }, was: was,
                                  nur: einzige) { uhr, _ in
            erreicht.append(uhr)
        }
        for uhr in erreicht where !uhr.host.isEmpty { await zustandAbfragen(uhr.id) }
        return Sendebilanz(erreicht: erreicht.map(\.name), ziele: ziele)
    }

    /// Panel an oder aus (`power`).
    @discardableResult
    public func panelSchalten(an: Bool, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: an ? lok("Display einschalten") : lok("Display ausschalten"), fuer: id) { anzeigen, _, _ in
            try anzeigen.anzeigeStrom(an)
        }
    }

    /// Helligkeit 0–255, roh.
    @discardableResult
    public func helligkeitSetzen(_ wert: Int, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lok("Helligkeit"), fuer: id) { anzeigen, _, caps in
            try anzeigen.helligkeit(wert, faehigkeiten: caps)
        }
    }

    /// Wetter-Overlay; `nil` nimmt es weg.
    @discardableResult
    public func overlaySetzen(_ name: String?, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lok("Overlay"), fuer: id) { anzeigen, _, caps in
            try anzeigen.overlay(name, faehigkeiten: caps)
        }
    }

    @discardableResult
    public func moodlightSetzen(_ licht: Moodlight, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lok("Moodlight"), fuer: id) { anzeigen, _, _ in try anzeigen.moodlight(licht) }
    }

    @discardableResult
    public func moodlightAusschalten(fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lok("Moodlight ausschalten"), fuer: id) { anzeigen, _, _ in try anzeigen.moodlightAus() }
    }

    @discardableResult
    public func indikatorSetzen(_ stand: Indikator, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lokf("Anzeiger %d", stand.nummer), fuer: id) { anzeigen, _, _ in try anzeigen.indikator(stand) }
    }

    @discardableResult
    public func indikatorAusschalten(_ nummer: Int, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lokf("Anzeiger %d", nummer), fuer: id) { anzeigen, _, _ in try anzeigen.indikatorAus(nummer) }
    }

    /// Eine geprüfte Teilmenge der Einstellungen (`PATCH`). Die Prüfung gegen die
    /// Namenslisten der jeweiligen Uhr geschah beim Zusammenstellen; hier geht
    /// sie hinaus.
    @discardableResult
    public func einstellungenAendern(_ aenderung: Einstellungsaenderung, fuer id: UUID? = nil) async -> Sendebilanz {
        await steuern(was: lok("Einstellungen der Uhr"), fuer: id) { anzeigen, _, _ in
            try anzeigen.einstellungenAendern(aenderung)
        }
    }

    /// Eine Einstellung der Uhr aus Schlüssel und Wort (`scroll.speed`,
    /// `weekdayBar.show` …) — dieselbe Zerlegung wie im Werkzeug
    /// (`Geraeteeinstellungen.aenderung`): Ein Unterfeld geht mit dem gelesenen
    /// Stand des übrigen Objekts hinaus. Was die Prüfung abweist, steht in
    /// `fehler`.
    @discardableResult
    public func einstellungSetzen(_ schluessel: String, wert: String, fuer id: UUID) async -> Sendebilanz {
        let stand = uhreneinstellungen[id] ?? Geraeteeinstellungen()
        do {
            let aenderung = try stand.aenderung(schluessel: schluessel, wert: wert, faehigkeiten: faehigkeiten[id])
            return await einstellungenAendern(aenderung, fuer: id)
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return Sendebilanz(erreicht: [], ziele: 1)
        }
    }

    /// Hält Klang an: ohne Gruppe alles, mit Gruppe nur diese (`audio/stop`).
    @discardableResult
    public func tonStoppen(_ gruppe: Tongruppe? = nil, fuer id: UUID) async -> Sendebilanz {
        await steuern(was: lok("Ton anhalten"), fuer: id) { anzeigen, _, _ in try anzeigen.tonStoppen(gruppe) }
    }

    /// Spielt den Radiosender mit diesem Namen aus der Senderliste der Uhr.
    @discardableResult
    public func radioSpielen(sender: String, fuer id: UUID) async -> Sendebilanz {
        await steuern(was: lok("Radio"), fuer: id) { anzeigen, _, caps in
            try anzeigen.tonSpielen([Klang(.sender(sender))], faehigkeiten: caps)
        }
    }

    /// Holt Melodien und MP3-Dateien der Uhr (nur HTTP). Eine Uhr ohne Adresse
    /// oder ohne Antwort lässt die Listen, wie sie waren; die Ansicht zeigt dann
    /// weiter „Uhr abfragen …“.
    @discardableResult
    public func tonlistenAbfragen(_ id: UUID) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }), !uhr.host.isEmpty else { return false }
        let host = uhr.host, sitzung = netzsitzung
        let geholt = await Hintergrund.lauf { () -> (Tonlisten, Tonablage?)? in
            let g = Geraet(host: host, sitzung: sitzung)
            guard let melodien = try? g.melodien() else { return nil }
            let mp3 = try? g.mp3Dateien()
            return (Tonlisten(melodien: melodien.namen, mp3: mp3?.namen ?? []), mp3)
        }
        guard let geholt, uhren.contains(where: { $0.id == id }) else { return false }
        tonlisten[id] = geholt.0
        mp3Ablage[id] = geholt.1
        return true
    }

    /// Lädt eine MP3-Datei unter `name` auf die Uhr (nur HTTP) und holt danach
    /// die Listen neu, damit Klang › „Von der Uhr“ den Namen kennt. Gelesen wird
    /// die Datei im Hintergrund; der Zugriff auf eine vom Anwender gewählte Datei
    /// gilt nur, solange er ausdrücklich geöffnet ist. Eine gleichnamige MP3
    /// ersetzt die Uhr still — ob das gewollt ist, fragt die Ansicht vorher.
    @discardableResult
    public func mp3Hochladen(datei: URL, name: String, fuer id: UUID) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return false }
        guard !uhr.host.isEmpty else {
            fehler = lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name)
            return false
        }
        let host = uhr.host, sitzung = netzsitzung
        do {
            try await Hintergrund.lauf {
                let offen = datei.startAccessingSecurityScopedResource()
                defer { if offen { datei.stopAccessingSecurityScopedResource() } }
                // Die Größe vor dem Lesen: Eine riesige Datei soll nicht erst im Speicher landen.
                if let groesse = try? datei.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   groesse > Geraet.mp3Hoechstgroesse {
                    throw KlangFehler.mp3ZuGross(bytes: groesse, grenze: Geraet.mp3Hoechstgroesse)
                }
                guard let daten = try? Data(contentsOf: datei) else {
                    throw MP3Fehler.nichtLesbar(datei.lastPathComponent)
                }
                try Geraet(host: host, sitzung: sitzung).mp3Hochladen(name: name, daten: daten)
            }
            log(lokf("%@: MP3 „%@“ hochgeladen", uhr.name, name))
            await tonlistenAbfragen(id)
            return true
        } catch {
            melde(error, uhr: uhr)
            return false
        }
    }

    /// Löscht eine MP3-Datei der Uhr (nur HTTP) und holt die Listen neu.
    @discardableResult
    public func mp3Loeschen(name: String, fuer id: UUID) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return false }
        guard !uhr.host.isEmpty else {
            fehler = lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name)
            return false
        }
        let host = uhr.host, sitzung = netzsitzung
        do {
            try await Hintergrund.lauf { try Geraet(host: host, sitzung: sitzung).mp3Loeschen(name: name) }
            log(lokf("%@: MP3 „%@“ gelöscht", uhr.name, name))
            await tonlistenAbfragen(id)
            return true
        } catch {
            melde(error, uhr: uhr)
            return false
        }
    }

    /// Eine Anzeige vor oder zurück bei genau dieser Uhr.
    @discardableResult
    public func anzeigeBlaettern(vor: Bool, fuer id: UUID) async -> Sendebilanz {
        await steuern(was: vor ? lok("Weiterblättern") : lok("Zurückblättern"), fuer: id) { anzeigen, _, _ in
            try anzeigen.blaettern(vor: vor)
        }
    }

    /// Startet die Uhr neu. Anders als die übrigen Befehle liest sie danach nichts
    /// zurück: Die Uhr antwortet erst nach dem Hochfahren wieder, und eine
    /// Abfrage davor zeichnete sie als unerreichbar.
    @discardableResult
    public func neustarten(fuer id: UUID) async -> Sendebilanz {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return Sendebilanz(erreicht: [], ziele: 0) }
        var erreicht: [String] = []
        let ziele = await anZiele({ anzeigen, _ in try anzeigen.neustarten() }, was: lok("Neustart"), nur: uhr) { uhr, _ in
            erreicht.append(uhr.name)
        }
        if !erreicht.isEmpty { bildschirm[id] = nil }
        return Sendebilanz(erreicht: erreicht, ziele: ziele)
    }

    // MARK: - Bildspeicher

    /// Holt das Bild des Bildspeichers. Mit Adresse über HTTP — auch bei einer
    /// MQTT-Uhr, denn alle zwei Sekunden eine eigene Broker-Verbindung für
    /// `cmd/screen/get` wäre teurer als eine kurze Anfrage; ohne Adresse über
    /// MQTT. Ein Fehlschlag lässt das letzte Bild stehen und ist keine Meldung:
    /// Die Seite zeigt dessen Alter.
    @discardableResult
    public func bildschirmAbfragen(_ id: UUID) async -> Bool {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return false }
        let sitzung = netzsitzung
        let host = uhr.host
        let anzeigen = host.isEmpty ? self.anzeigen(fuer: uhr) : nil
        guard !host.isEmpty || anzeigen != nil else { return false }
        let bild = await Hintergrund.lauf { () -> Bildschirmauszug? in
            if !host.isEmpty { return try? Geraet(host: host, sitzung: sitzung).bildschirm() }
            return try? anzeigen?.bildschirmLesen(frist: 2)
        }
        guard !Task.isCancelled, let bild, uhren.contains(where: { $0.id == id }) else { return false }
        bildschirm[id] = (bild, Date())
        return true
    }

    /// Fragt das Bild im Takt ab, bis die Aufgabe abgebrochen wird. Die Ansicht
    /// hängt es an `.task`: Verlässt man die Seite, endet die Schleife mit ihr.
    public func bildschirmFolgen(_ id: UUID, takt: Duration = .seconds(2)) async {
        while !Task.isCancelled {
            await bildschirmAbfragen(id)
            try? await Task.sleep(for: takt)
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

    /// Wie `tlsCAHochladen`, aus einer Datei. Der Zugriff auf eine vom Anwender
    /// gewählte Datei gilt nur, solange er ausdrücklich geöffnet ist; gelesen
    /// wird im Hintergrund. Was nicht lesbar ist, steht in `fehler`.
    @discardableResult
    public func tlsCAHochladen(datei: URL, fuer id: UUID) async -> Bool {
        let pem = await Hintergrund.lauf { () -> String? in
            let offen = datei.startAccessingSecurityScopedResource()
            defer { if offen { datei.stopAccessingSecurityScopedResource() } }
            guard let daten = try? Data(contentsOf: datei, options: .mappedIfSafe),
                  daten.count <= TLSZertifikat.hoechstGroesse * 4 else { return nil }
            return String(data: daten, encoding: .utf8)
        }
        guard let pem else {
            fehler = lokf("Die Datei „%@“ ist nicht zu lesen.", datei.lastPathComponent)
            return false
        }
        return await tlsCAHochladen(pem, fuer: id)
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

/// Was beim Lesen der Datei schiefgehen kann, bevor etwas hinausgeht.
enum MP3Fehler: Error, LocalizedError {
    case nichtLesbar(String)

    var errorDescription: String? {
        switch self {
        case .nichtLesbar(let name): return lokf("Die Datei „%@“ ist nicht zu lesen.", name)
        }
    }
}
