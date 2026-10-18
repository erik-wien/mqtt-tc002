import Foundation

/// Was `POST /api/v1/restore` antwortet, wenn die Uhr die Sicherung angenommen hat
/// (`ok: true`, Status 200): wie viele Einträge je Art eingespielt wurden und
/// welche sie übersprungen hat. Die Uhr spielt Eintrag für Eintrag ein; ein
/// beschädigter, fremder oder nicht passender Eintrag wird mit einer Warnung
/// übergangen, der Rest läuft weiter.
public struct Sicherungsergebnis: Equatable, Sendable {
    /// `applied` der Antwort: `wifi`, `system`, `settings`, `appLoop`, `radioStations`,
    /// `icons`, `iconOrigins`, `melodies`, `palettes`, `mp3`, `scripts`, `skipped`.
    public let angewendet: [String: Int]
    /// Eine englische Zeile je übersprungenem Eintrag, wie die Uhr sie schreibt.
    public let warnungen: [String]

    public init(angewendet: [String: Int], warnungen: [String]) {
        self.angewendet = angewendet
        self.warnungen = warnungen
    }

    /// Neue WLAN-Zugangsdaten und die Systemkonfiguration gelten erst nach einem
    /// Neustart der Uhr.
    public var neustartNoetig: Bool {
        (angewendet["wifi"] ?? 0) > 0 || (angewendet["system"] ?? 0) > 0
    }

    public var uebersprungen: Int { angewendet["skipped"] ?? 0 }

    /// Die eingespielten Arten mit Zahl, eine Zeile je Art; Arten ohne Eintrag fehlen.
    public var zeilen: [String] {
        let namen: [(String, String)] = [
            ("wifi", lok("WLAN-Zugang")), ("system", lok("Systemkonfiguration")),
            ("settings", lok("Einstellungen")), ("appLoop", lok("Reihenfolge der Anzeigen")),
            ("radioStations", lok("Radiosender")), ("icons", lok("Icons")),
            ("iconOrigins", lok("Herkunft der Icons")), ("melodies", lok("Melodien")),
            ("palettes", lok("Paletten")), ("mp3", lok("MP3-Dateien")), ("scripts", lok("Skripte")),
        ]
        return namen.compactMap { schluessel, name in
            let n = angewendet[schluessel] ?? 0
            return n > 0 ? "\(name): \(n)" : nil
        }
    }

    /// Liest den Rumpf einer Antwort mit Status 200. `nil`, wenn es keine Antwort
    /// dieser Route ist. Mit `ok: false` (Status 400) wirft die Uhr die Sicherung
    /// ganz ab; das ist hier kein Ergebnis, sondern `GeraetFehler.sicherungAbgewiesen`.
    init?(antwort: Data) {
        guard let o = (try? JSONSerialization.jsonObject(with: antwort)) as? [String: Any],
              o["ok"] as? Bool == true else { return nil }
        var zahlen: [String: Int] = [:]
        for (k, v) in (o["applied"] as? [String: Any]) ?? [:] {
            if let n = v as? Int { zahlen[k] = n }
        }
        self.init(angewendet: zahlen, warnungen: (o["warnings"] as? [String]) ?? [])
    }
}

/// Sicherung und Rückspielen der Uhr, im Format der Weboberfläche von AWTRIX NG
/// (`backup.js`): ein unkomprimiertes Zip mit `manifest.json` zuerst. Die Uhr hat
/// keinen Export; wie die Weboberfläche baut diese App das Zip aus den
/// Einzelabfragen.
///
/// Inhalt, in dieser Reihenfolge:
/// - `manifest.json`: `app`, `backupFormat`, `createdAt`, `device.hostname`, `categories`;
/// - `apploop.json` (`GET /apploop.json`, fehlt ohne Abbruch, wenn die Uhr keine hat);
/// - `config/wifi.json`: `wifiSsid`, `wifiPass` aus `GET /api/v1/system?secrets=1`;
/// - `config/system.json`: dasselbe Objekt ohne diese beiden;
/// - `config/settings.json`: `GET /api/v1/settings` unverändert;
/// - `ICONS/…` (`GET /api/v1/files?dir=/ICONS`, dann `GET /ICONS/<name>`) und
///   `config/icon-origins.json` (`GET /api/v1/icons/origins`, bei `404` ausgelassen);
/// - `MELODIES/<name>.txt` mit dem `rtttl` aus `GET /api/v1/audio/melodies`;
/// - `PALETTES/…`, `MP3/…`, `SCRIPTS/…` wie die Icons; dazu
///   `SCRIPTS/<name>/<datei>` für die Klänge der Skripte aus `GET /api/v1/audio/mp3`.
///
/// Das Zip enthält WLAN-, MQTT- und Webkennwort im Klartext.
extension Geraet {
    /// Eine fertige Sicherung und die Namen, die die Uhr genannt hat und die nicht
    /// ins Zip kamen, weil sie kein harmloser Dateiname waren (`..`, `\\`, NUL …).
    public struct Sicherung: Sendable {
        public let zip: Data
        public let ausgelassen: [String]
    }

    public func sicherungErstellen(zeit: Date = Date()) throws -> Sicherung {
        var ausgelassen: [String] = []
        /// Nur der Dateiname, wie `baseName` der Weboberfläche; `nil`, wenn er unbrauchbar ist.
        func sauber(_ roh: String) -> String? {
            let name = roh.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? roh
            if Sicherungszip.namensicher(name) { return name }
            ausgelassen.append(roh.unicodeScalars.map { $0.value < 0x20 ? "?" : String($0) }.joined())
            return nil
        }
        var eintraege: [Sicherungszip.Eintrag] = []
        var kategorien: [String] = []
        func text(_ s: String) -> Data { Data(s.utf8) }
        func json(_ o: Any) throws -> Data {
            try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys, .withoutEscapingSlashes])
        }

        let systemRoh = try lesen("/api/v1/system?secrets=1")
        guard var system = (try? JSONSerialization.jsonObject(with: systemRoh)) as? [String: Any] else {
            throw GeraetFehler.unerwarteteAntwort("/api/v1/system")
        }
        let ssid = system.removeValue(forKey: "wifiSsid") as? String ?? ""
        let kennwort = system.removeValue(forKey: "wifiPass") as? String ?? ""
        eintraege.append(.init(pfad: "config/wifi.json", daten: try json(["wifiSsid": ssid, "wifiPass": kennwort])))
        kategorien.append("wifi")

        eintraege.append(.init(pfad: "config/system.json", daten: try json(system)))
        eintraege.append(.init(pfad: "config/settings.json", daten: try lesen("/api/v1/settings")))
        kategorien.append("settings")

        try dateienSichern("/ICONS", in: &eintraege, sauber: sauber)
        do {
            let herkunft = try ngAnfrage("GET", "/api/v1/icons/origins", koerper: nil)
            guard let o = (try? JSONSerialization.jsonObject(with: herkunft)) as? [String: Any],
                  o["icons"] is [Any] else { throw GeraetFehler.unerwarteteAntwort("/api/v1/icons/origins") }
            eintraege.append(.init(pfad: "config/icon-origins.json", daten: herkunft))
        } catch GeraetFehler.ngAbgewiesen(404, _, _) {
        }
        kategorien.append("icons")

        for m in (try hole("/api/v1/audio/melodies")["melodies"] as? [[String: Any]]) ?? [] {
            guard let name = m["name"] as? String, let rtttl = m["rtttl"] as? String else { continue }
            guard Klangname.gueltig(name) else { ausgelassen.append(name); continue }
            eintraege.append(.init(pfad: "MELODIES/\(name).txt", daten: text(rtttl)))
        }
        kategorien.append("melodies")

        try dateienSichern("/PALETTES", in: &eintraege, sauber: sauber)
        kategorien.append("palettes")
        try dateienSichern("/MP3", in: &eintraege, sauber: sauber)
        kategorien.append("mp3")

        try dateienSichern("/SCRIPTS", in: &eintraege, sauber: sauber)
        for s in (try hole("/api/v1/audio/mp3")["scripts"] as? [[String: Any]]) ?? [] {
            guard let name = s["name"] as? String else { continue }
            guard !name.contains("/"), let skript = sauber(name) else { continue }
            for f in (s["files"] as? [[String: Any]]) ?? [] {
                guard let roh = f["name"] as? String, let datei = sauber(roh) else { continue }
                let pfad = "SCRIPTS/" + skript + "/" + datei
                eintraege.append(.init(pfad: pfad, daten: try dateiLesen("/SCRIPTS/" + Self.ngName(skript) + "/" + Self.ngName(datei))))
            }
        }
        kategorien.append("scripts")

        if let apploop = try? lesen("/apploop.json") {
            eintraege.insert(.init(pfad: "apploop.json", daten: apploop), at: 0)
            kategorien.append("apporder")
        }

        let kopf = Sicherungszip.manifest(erstellt: zeit, hostname: system["hostname"] as? String ?? "",
                                          kategorien: kategorien)
        return Sicherung(zip: Sicherungszip.schreiben([kopf] + eintraege), ausgelassen: ausgelassen)
    }

    /// Alle Dateien eines Ordners der Uhr, als `ICONS/<name>` usw.
    private func dateienSichern(_ ordner: String, in eintraege: inout [Sicherungszip.Eintrag],
                                sauber: (String) -> String?) throws {
        let liste = try hole("/api/v1/files?dir=" + ordner)
        for f in (liste["files"] as? [[String: Any]]) ?? [] {
            guard let roh = f["name"] as? String, let name = sauber(roh) else { continue }
            eintraege.append(.init(pfad: String(ordner.dropFirst()) + "/" + name,
                                   daten: try dateiLesen(ordner + "/" + Self.ngName(name))))
        }
    }

    private func dateiLesen(_ pfad: String) throws -> Data {
        try lesen(pfad, grenze: Antwortgrenze.datei)
    }

    /// `POST /api/v1/restore`, `multipart`, Feld `file` (wie die Weboberfläche).
    /// Die Uhr schreibt sofort; was sie davon nicht einspielt, steht in
    /// `warnungen`. Ein Zip, das die Uhr als Ganzes abweist (kein Manifest, fremde
    /// App, unbekannte Fassung), ist `sicherungAbgewiesen`.
    public func sicherungZurueckspielen(_ zip: Data, dateiname: String = "sicherung.zip") throws -> Sicherungsergebnis {
        let name = dateiname.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" && $0 != "\\" }
        let grenze = "TC002-" + UUID().uuidString
        var rumpf = Data("--\(grenze)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name.isEmpty ? "sicherung.zip" : name)\"\r\nContent-Type: application/zip\r\n\r\n".utf8)
        rumpf.append(zip)
        rumpf.append(Data("\r\n--\(grenze)--\r\n".utf8))
        let (daten, status) = try ngRoh("POST", "/api/v1/restore", koerper: rumpf,
                                        inhaltsart: "multipart/form-data; boundary=\(grenze)", frist: 300)
        let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
        switch status {
        case 200:
            guard let ergebnis = Sicherungsergebnis(antwort: daten) else {
                throw GeraetFehler.unerwarteteAntwort("/api/v1/restore")
            }
            return ergebnis
        case 507:
            throw GeraetFehler.sicherungNichtGespeichert
        case 400 where o?["ok"] as? Bool == false:
            throw GeraetFehler.sicherungAbgewiesen(o?["error"] as? String ?? lok("ohne Begründung"))
        default:
            let fehler = o?["error"] as? [String: Any]
            let feld = fehler?["field"] as? String
            throw GeraetFehler.ngAbgewiesen(status: status, code: fehler?["code"] as? String ?? lok("ohne Begründung"),
                                            feld: (feld?.isEmpty ?? true) ? nil : feld)
        }
    }
}
