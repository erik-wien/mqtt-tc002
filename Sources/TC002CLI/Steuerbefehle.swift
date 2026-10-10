import Foundation
import TC002Core

// Die Befehle der Fernsteuerung und des Zustands. Das Werkzeug schreibt nie die
// Einstellungen der App; geschrieben wird allein auf die Uhr.

private func meldungstext(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? "\(error)"
}

/// Die Befehle, die nur über HTTP gehen (`GET`/`PUT`/`DELETE /api/v1/mqtt/tls…`):
/// kein Broker nötig, auch nicht für eine MQTT-Uhr. `true`, wenn `befehl` einer
/// davon war.
func tlsBefehl(_ befehl: Optionen.Befehl, uhren: [Uhr], trocken: Bool) throws -> Bool {
    switch befehl {
    case .tls, .tlsCA, .tlsCAEntfernen: break
    default: return false
    }
    var pem = ""
    if case .tlsCA(let pfad) = befehl {
        let url = URL(fileURLWithPath: (pfad as NSString).expandingTildeInPath)
        guard let daten = try? Data(contentsOf: url), let text = String(data: daten, encoding: .utf8) else {
            throw Abbruch(lokf("Die Datei „%@“ ist nicht zu lesen.", pfad))
        }
        pem = text
        try TLSZertifikat.pruefen(pem: pem)
    }
    var fehler: [String] = []
    var gelungen = 0
    for uhr in uhren {
        guard !uhr.host.isEmpty else {
            fehler.append(lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name))
            continue
        }
        let geraet = Geraet(host: uhr.host)
        do {
            if uhren.count > 1 { print("# \(uhr.name)") }
            switch befehl {
            case .tls:
                let s = try geraet.tlsStatus()
                print(lokf("CA: %@", Terminaltext.sicher(s.ca)))
                print(lokf("Ausstehend: %@", Terminaltext.sicher(s.pending ?? "—")))
            case .tlsCA:
                if trocken {
                    print("PUT http://\(uhr.host)/api/v1/mqtt/tls/ca")
                    print(lokf("%d Byte Zertifikat, nichts gesendet (--trocken).", pem.utf8.count))
                } else {
                    let s = try geraet.tlsCAHochladen(pem: pem)
                    print(lokf("%@: Zertifikat hochgeladen", uhr.name))
                    if let s { print(lokf("CA: %@", Terminaltext.sicher(s.ca))) }
                }
            default:
                if trocken {
                    print("DELETE http://\(uhr.host)/api/v1/mqtt/tls/ca")
                    print(lok("nichts gesendet (--trocken)."))
                } else {
                    let s = try geraet.tlsCAEntfernen()
                    print(lokf("%@: Zertifikat entfernt", uhr.name))
                    if let s { print(lokf("CA: %@", Terminaltext.sicher(s.ca))) }
                }
            }
            gelungen += 1
        } catch {
            fehler.append("\(uhr.name): \(meldungstext(error))")
        }
    }
    guard fehler.isEmpty, gelungen > 0 else {
        throw Abbruch(fehler.isEmpty ? lok("Keine Uhr hat geantwortet.") : fehler.joined(separator: "\n"))
    }
    return true
}

private func gruppentitel(_ g: Einstellungsgruppe) -> String {
    switch g {
    case .helligkeitFarbe: return lok("Helligkeit & Farbe")
    case .text: return lok("Text & Laufschrift")
    case .schleife: return lok("Schleife")
    case .uhr: return lok("Uhr")
    case .zeitDatum: return lok("Zeit & Datum")
    case .wochentagsleiste: return lok("Wochentagsleiste")
    case .klang: return lok("Klang")
    case .tasten: return lok("Tasten")
    }
}

private func aus(_ b: Bool?) -> String { b == nil ? "—" : (b! ? lok("an") : lok("aus")) }

private func verbindung(_ v: Verbindungsstand?) -> String {
    guard let v else { return "—" }
    return v.fehler.map { "\(v.zustand) (\($0))" } ?? v.zustand
}

/// Gibt den Zustand einer Uhr aus: Zeilen `Name<Tab>Wert`.
private func zustandAusgeben(_ z: Geraetezustand) {
    func zeile(_ name: String, _ wert: String?) { print("\(name)\t\(Terminaltext.sicher(wert ?? "—"))") }
    zeile(lok("Fassung"), z.fassung)
    zeile(lok("Platine"), z.platine)
    zeile(lok("Display"), aus(z.panelAn))
    zeile(lok("Helligkeit"), z.helligkeit.map(String.init))
    zeile(lok("Aktive Anzeige"), z.aktiveAnzeige)
    zeile("WLAN", verbindung(z.wlan) + (z.wlanSignal.map { " \($0) dBm" } ?? ""))
    zeile("MQTT", verbindung(z.mqtt))
    zeile(lok("Laufzeit"), z.laufzeitSekunden.map { "\($0) s" })
    if let b = z.batterieProzent { zeile(lok("Batterie"), "\(b) %" + (z.batterieSchwach == true ? " (!)" : "")) }
    if let u = z.usbStrom { zeile("USB", aus(u)) }
    for (i, a) in z.indikatoren.enumerated() {
        zeile(lokf("Anzeiger %d", i + 1), a.an ? "\(a.farbe) blink \(a.blinkMs) fade \(a.fadeMs)" : lok("aus"))
    }
}

private func einstellungenAusgeben(_ e: Geraeteeinstellungen) {
    for g in Einstellungsgruppe.allCases {
        let zeilen = e.zeilen(in: g)
        guard !zeilen.isEmpty else { continue }
        print("[\(gruppentitel(g))]")
        for z in zeilen {
            let gesperrt = Geraeteeinstellung(rawValue: z.schluessel)?.schreibbar == false
            print("\(Terminaltext.sicher(z.schluessel))\t\(Terminaltext.sicher(z.wert))" + (gesperrt ? "\t" + lok("(nur lesen)") : ""))
        }
    }
    print(lokf("%d Schlüssel insgesamt; die übrigen stellt diese App nicht ein.", e.schluesselinsgesamt))
}

/// Führt die übrigen Steuerbefehle aus, nachdem Ziele und Broker feststehen.
/// `true`, wenn `optionen.befehl` einer davon war.
func steuerbefehl(_ optionen: Optionen, gewaehlte: [Uhr], einstellungen: Einstellungen,
                  anAlle: (String, (Anzeigen, Uhr) throws -> Void) throws -> Void) throws -> Bool {
    func kanal(_ uhr: Uhr) -> Anzeigen? {
        Anzeigen.fuer(uhr, brokerzugang: einstellungen.zugang(
            clientID: "tc002-cli-" + uhr.id.uuidString.prefix(8).lowercased()))
    }
    /// Der Trockenlauf: wohin was ginge.
    func trocken(http: String, thema: (String) -> String, json: String) {
        if Einstellungen.brokerNoetig(fuer: gewaehlte) {
            print(lokf("Broker %@:%d, Konto %@, Kennwort %@", einstellungen.brokerHost, Int(einstellungen.brokerPort),
                         einstellungen.benutzer ?? "—",
                         einstellungen.kennwort == nil ? lok("fehlt") : lok("vorhanden")))
        }
        for uhr in gewaehlte {
            switch uhr.wirksameBetriebsart {
            case .http:
                let teile = http.split(separator: " ", maxSplits: 1).map(String.init)
                print("\(teile[0]) http://\(uhr.host)\(teile[1])")
            case .mqtt: print(thema(uhr.praefix))
            }
        }
        print(json.isEmpty ? "(leer)" : json)
        print(lok("nichts gesendet (--trocken)."))
    }
    func lesen(_ was: (Anzeigen) throws -> Void) throws {
        var fehler: [String] = []
        var gelesen = 0
        for uhr in gewaehlte {
            guard let anzeigen = kanal(uhr) else { continue }
            do {
                if gewaehlte.count > 1 { print("# \(uhr.name)") }
                try was(anzeigen)
                gelesen += 1
            } catch { fehler.append("\(uhr.name): \(meldungstext(error))") }
        }
        guard fehler.isEmpty, gelesen > 0 else {
            throw Abbruch(fehler.isEmpty ? lok("Keine Uhr hat geantwortet.") : fehler.joined(separator: "\n"))
        }
    }
    func faehigkeiten(_ uhr: Uhr) -> Geraetefaehigkeiten? {
        uhr.host.isEmpty ? nil : ((try? Geraet(host: uhr.host).faehigkeiten()) ?? nil)
    }

    switch optionen.befehl {
    case .display(let an):
        let json = an ? #"{"power":true}"# : #"{"power":false}"#
        if optionen.trocken { trocken(http: "PATCH /api/v1/display", thema: { NGThema.anzeigeSteuern(praefix: $0) }, json: json); return true }
        try anAlle(an ? lok("Display eingeschaltet") : lok("Display ausgeschaltet")) { a, _ in try a.anzeigeStrom(an) }
    case .helligkeit(let n):
        if optionen.trocken { trocken(http: "PATCH /api/v1/settings", thema: { NGThema.einstellungen(praefix: $0) }, json: "{\"brightness\":\(n)}"); return true }
        try anAlle(lokf("Helligkeit %d", n)) { a, _ in try a.helligkeit(n) }
    case .moodlight(let licht):
        if optionen.trocken { trocken(http: "PUT /api/v1/display/moodlight", thema: { NGThema.moodlight(praefix: $0) }, json: try licht.json()); return true }
        try anAlle(lok("Moodlight gesetzt")) { a, _ in try a.moodlight(licht) }
    case .moodlightAus:
        if optionen.trocken { trocken(http: "DELETE /api/v1/display/moodlight", thema: { NGThema.moodlight(praefix: $0) }, json: ""); return true }
        try anAlle(lok("Moodlight aus")) { a, _ in try a.moodlightAus() }
    case .indikator(let stand):
        if optionen.trocken {
            trocken(http: "PUT /api/v1/indicators/\(stand.nummer)",
                    thema: { NGThema.indikator(praefix: $0, nummer: stand.nummer) }, json: try stand.json()); return true
        }
        try anAlle(lokf("Anzeiger %d gesetzt", stand.nummer)) { a, _ in try a.indikator(stand) }
    case .indikatorAus(let n):
        if optionen.trocken {
            trocken(http: "DELETE /api/v1/indicators/\(n)", thema: { NGThema.indikator(praefix: $0, nummer: n) }, json: ""); return true
        }
        try anAlle(lokf("Anzeiger %d aus", n)) { a, _ in try a.indikatorAus(n) }
    case .weiter, .zurueck:
        let vor = optionen.befehl == .weiter
        if optionen.trocken {
            trocken(http: "POST /api/v1/apps/" + (vor ? "next" : "previous"),
                    thema: { NGThema.blaettern(praefix: $0, vor: vor) }, json: ""); return true
        }
        try anAlle(vor ? lok("weitergeschaltet") : lok("zurückgeschaltet")) { a, _ in try a.blaettern(vor: vor) }
    case .neustart:
        if optionen.trocken {
            trocken(http: "POST /api/v1/device/reboot", thema: { NGThema.neustart(praefix: $0) }, json: ""); return true
        }
        try anAlle(lok("Neustart ausgelöst")) { a, _ in try a.neustarten() }
    case .tonSpielen(let klang):
        if optionen.trocken {
            trocken(http: "POST /api/v1/audio/play", thema: { NGThema.tonSpielen(praefix: $0) },
                    json: try Klangbau.spielen([klang])); return true
        }
        try anAlle(lok("Klang gesendet")) { anzeigen, uhr in
            let caps = faehigkeiten(uhr)
            try klaengePruefen([klang], anzeigen: anzeigen, faehigkeiten: caps)
            try anzeigen.tonSpielen([klang], faehigkeiten: caps)
        }
    case .tonStopp(let gruppe):
        if optionen.trocken {
            trocken(http: "POST /api/v1/audio/stop", thema: { NGThema.tonStoppen(praefix: $0) },
                    json: Klangbau.stoppen(gruppe)); return true
        }
        try anAlle(lok("Klang angehalten")) { anzeigen, _ in try anzeigen.tonStoppen(gruppe) }
    case .tonMelodie(let name, let rtttl):
        if optionen.trocken {
            trocken(http: "PUT /api/v1/audio/melodies/\(name)", thema: { _ in lok("(nur über HTTP)") },
                    json: try Klangbau.melodie(name: name, rtttl: rtttl)); return true
        }
        try anAlle(lokf("Melodie „%@“ gesetzt", name)) { anzeigen, uhr in
            try anzeigen.melodieSetzen(name: name, rtttl: rtttl, faehigkeiten: faehigkeiten(uhr))
        }
    case .tonMelodieLoeschen(let name):
        if optionen.trocken {
            try Klangbau.melodienameInOrdnung(name)
            trocken(http: "DELETE /api/v1/audio/melodies/\(name)", thema: { _ in lok("(nur über HTTP)") },
                    json: ""); return true
        }
        try anAlle(lokf("Melodie „%@“ gelöscht", name)) { anzeigen, _ in try anzeigen.melodieLoeschen(name: name) }
    case .tonZustand:
        try lesen { tonzustandAusgeben(try $0.tonzustandLesen()) }
    case .tonMelodien:
        try lesen { melodienAusgeben(try $0.melodienLesen()) }
    case .tonMP3Liste:
        try lesen { mp3AusgebenListe(try $0.mp3Lesen()) }
    case .tonMP3Loeschen(let name):
        if optionen.trocken {
            trocken(http: "DELETE /api/v1/audio/mp3/\(name)", thema: { _ in lok("(nur über HTTP)") }, json: ""); return true
        }
        try anAlle(lokf("MP3 „%@“ gelöscht", name)) { anzeigen, _ in try anzeigen.mp3Loeschen(name: name) }
    case .tonMP3Hochladen(let datei, let angegeben, let ersetzen):
        let url = URL(fileURLWithPath: (datei as NSString).expandingTildeInPath)
        guard let daten = try? Data(contentsOf: url) else {
            throw Abbruch(lokf("Die Datei „%@“ ist nicht zu lesen.", datei))
        }
        let name = angegeben ?? Klangname.vorschlag(ausDateiname: url.lastPathComponent)
        if angegeben == nil { print(lokf("Name auf der Uhr: %@", name)) }
        guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
        if optionen.trocken {
            trocken(http: "POST /api/v1/audio/mp3 (multipart, file=\(name).mp3, \(daten.count) Byte)",
                    thema: { _ in lok("(nur über HTTP)") }, json: ""); return true
        }
        try anAlle(lokf("MP3 „%@“ hochgeladen", name)) { anzeigen, uhr in
            let caps = faehigkeiten(uhr)
            guard Klangeignung.mp3Hochladbar(caps) else { throw KlangFehler.mp3NichtSpielbar }
            let belegt = try anzeigen.mp3Lesen().namen
            let melodien = try anzeigen.melodienLesen().namen
            if melodien.contains(name) {
                let frei = Klangname.freierName(name, vorhanden: belegt + melodien)
                throw Abbruch(lokf("„%@“ ist der Name einer Melodie auf der Uhr. Frei wäre „%@“ (--name).", name, frei))
            }
            if belegt.contains(name), !ersetzen {
                let frei = Klangname.freierName(name, vorhanden: belegt + melodien)
                throw Abbruch(lokf("„%@“ gibt es auf der Uhr schon. Mit --ersetzen überschreiben, oder einen freien Namen nehmen: --name %@", name, frei))
            }
            try anzeigen.mp3Hochladen(name: name, daten: daten, faehigkeiten: caps)
        }
    case .tonSender:
        try lesen { senderAusgeben(try $0.senderLesen()) }
    case .tonAbgleichen:
        let bestand = Klangsammlung(ordner: Klangordner.eigene).alle()
        guard !bestand.isEmpty else {
            throw Abbruch(lok("Die Klangsammlung ist leer. In der App unter „Einstellungen › Klänge“ füllen."))
        }
        var fehler: [String] = []
        for uhr in gewaehlte {
            guard !uhr.host.isEmpty else { fehler.append(lokf("%@: keine Adresse", uhr.name)); continue }
            let e = Klangabgleich.abgleichen(sammlung: bestand, geraet: Geraet(host: uhr.host), uhrname: uhr.name,
                                             faehigkeiten: faehigkeiten(uhr), trocken: optionen.trocken)
            abgleichAusgeben(e)
            if let f = e.fehler { fehler.append("\(uhr.name): \(f)") }
        }
        if optionen.trocken { print(lok("nichts gesendet (--trocken).")) }
        guard fehler.isEmpty else { throw Abbruch(fehler.joined(separator: "\n")) }
    case .zustand:
        try lesen { anzeigen in
            zustandAusgeben(try anzeigen.geraetezustandLesen())
        }
    case .einstellungen:
        try lesen { anzeigen in
            einstellungenAusgeben(try anzeigen.einstellungenLesen())
        }
    case .einstellungenSetzen(let schluessel, let wert):
        let punktiert = schluessel.contains(".")
        if optionen.trocken {
            // Der Trockenlauf liest bei einem Unterfeld den Stand (nur lesen), sonst nichts.
            for uhr in gewaehlte {
                let aktuell = punktiert ? try kanal(uhr)?.einstellungenLesen() : Geraeteeinstellungen()
                let a = try (aktuell ?? Geraeteeinstellungen()).aenderung(schluessel: schluessel, wert: wert,
                                                                          faehigkeiten: faehigkeiten(uhr))
                trocken(http: "PATCH /api/v1/settings", thema: { NGThema.einstellungen(praefix: $0) }, json: try a.json())
                break
            }
            return true
        }
        try anAlle(lokf("%@ gesetzt", schluessel)) { anzeigen, uhr in
            let aktuell = punktiert ? try anzeigen.einstellungenLesen() : Geraeteeinstellungen()
            let a = try aktuell.aenderung(schluessel: schluessel, wert: wert, faehigkeiten: faehigkeiten(uhr))
            try anzeigen.einstellungenAendern(a)
        }
    default:
        return false
    }
    return true
}
