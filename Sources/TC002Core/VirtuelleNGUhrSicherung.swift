import Foundation

/// Die Dateiablage der virtuellen NG-Uhr, soweit eine Sicherung sie berührt.
/// MP3 und Melodien liegen weiter in `NGTon`; `dateien` hält zusätzlich die Bytes
/// der MP3-Dateien.
public struct NGAblage: Equatable, Sendable {
    /// Pfad (`/ICONS/a.gif`, `/PALETTES/p.bin`, `/SCRIPTS/x.be`,
    /// `/SCRIPTS/<skript>/<klang>.mp3`, `/MP3/x.mp3`) → Inhalt.
    public var dateien: [String: Data] = [:]
    /// Rumpf von `GET /api/v1/icons/origins`; `nil`: die Uhr antwortet `404`.
    public var iconHerkunft: Data?
    /// Inhalt von `/apploop.json`; `nil`: es gibt keine Datei (`404`).
    public var anzeigenfolge: Data?
    /// Systemkonfiguration über die vier festen Schlüssel hinaus, einschließlich
    /// `wifiSsid`, `wifiPass`, `mqttPass`, `authPass`.
    public var system: [String: JSONWert] = [:]

    public init() {}
}

/// Dateiablage, Systemkonfiguration mit Geheimnissen und `POST /api/v1/restore` der
/// virtuellen NG-Uhr — genug, um eine Sicherung ganz durchzuspielen (sammeln, zippen,
/// zurückspielen).
///
/// Folgt `reference/http` (Backup restore, Files) und `reference/errors` (Restore
/// result) der Herstellerdoku und `backup.js` der Weboberfläche. Annahmen, wo beide
/// schweigen (❓):
/// - Die Uhr liest das Zip Eintrag für Eintrag und überspringt einen Eintrag mit
///   falscher Prüfsumme; die virtuelle Uhr liest es als Ganzes und weist ein Zip
///   mit einer falschen Prüfsumme als `not a zip` ab.
/// - Ein Icon gilt als passend, wenn es mit `GIF8` oder `FF D8 FF` beginnt; eine
///   Palette, wenn sie nicht leer ist. Die Uhr prüft vermutlich genauer.
/// - Die Warnungen sind englische Sätze, nach dem Muster der Doku formuliert
///   (`skipped unknown entry 'x'`); ihr Wortlaut ist nicht gemessen.
/// - `config/system.json` wird schlüsselweise in `ablage.system` gemischt, ohne
///   Wertebereiche zu prüfen; `config/settings.json` geht durch dieselbe Prüfung wie
///   `PATCH /api/v1/settings`.
/// - `GET /api/v1/files?dir=/MELODIES` führt `<name>.txt`, `dir=/MP3` führt
///   `<name>.mp3`; ein Ordner ohne Dateien ist `200` mit leerer Liste.
/// - Nicht nachgebildet: Anmeldung, Einrichtungsbetrieb, `radio.json`, die
///   Größengrenzen der Einträge, `507 insufficientStorage` nach dem Einspielen.
extension VirtuelleNGUhr {
    private static let geheimnisse = ["wifiPass", "mqttPass", "authPass"]

    // MARK: - System

    /// `GET /api/v1/system`; mit `?secrets=1` auch die Geheimnisse.
    static func systemantwort(_ a: Anfrage, _ z: NGUhrzustand) -> Antwort {
        var o: [String: JSONWert] = ["mqttEnabled": .bool(false), "mqttHost": .text(""),
                                     "mqttPort": .zahl(1883), "mqttPrefix": .text(z.mqttPrefix),
                                     "hostname": .text("virtuelle-uhr"), "webPort": .zahl(80),
                                     "wifiSsid": .text("")]
        for (k, v) in z.ablage.system { o[k] = v }
        o["mqttPrefix"] = .text(z.mqttPrefix)
        if a.abfrage["secrets"] == "1" {
            for k in geheimnisse where o[k] == nil { o[k] = .text("") }
        } else {
            for k in geheimnisse { o[k] = nil }
        }
        return json(.objekt(o))
    }

    // MARK: - Dateien

    private static func pfadOK(_ pfad: String) -> Bool {
        !pfad.contains("..") && !pfad.contains("\\")
    }

    /// Name und Größe der Dateien eines Ordners.
    private static func ordnerinhalt(_ ordner: String, _ z: NGUhrzustand) -> [(name: String, size: Int)] {
        switch ordner {
        case "/MP3":
            return z.ton.mp3.sorted().map { ($0 + ".mp3", z.ton.mp3Groessen[$0] ?? 0) }
        case "/MELODIES":
            return z.ton.melodien.keys.sorted().map { ($0 + ".txt", z.ton.melodien[$0]!.utf8.count) }
        default:
            let vorsatz = ordner + "/"
            return z.ablage.dateien.keys.sorted().compactMap { pfad in
                guard pfad.hasPrefix(vorsatz) else { return nil }
                let rest = String(pfad.dropFirst(vorsatz.count))
                return rest.contains("/") ? nil : (rest, z.ablage.dateien[pfad]!.count)
            }
        }
    }

    /// `GET /api/v1/files?dir=`.
    static func dateienliste(_ a: Anfrage, _ z: NGUhrzustand) -> Antwort {
        var ordner = a.abfrage["dir"] ?? "/ICONS"
        if !ordner.hasPrefix("/") { ordner = "/" + ordner }
        guard pfadOK(ordner) else { return fehler(400, "invalidPath", "invalid path", feld: "dir") }
        while ordner.count > 1, ordner.hasSuffix("/") { ordner.removeLast() }
        let dateien = ordnerinhalt(ordner, z).map { d -> JSONWert in
            .objekt(["name": .text(d.name), "size": .zahl(Double(d.size))])
        }
        let belegt = z.ablage.dateien.values.reduce(0) { $0 + $1.count }
        return json(.objekt(["files": .liste(dateien), "usedBytes": .zahl(Double(belegt)),
                             "totalBytes": .zahl(Double(gesamtSpeicher))]))
    }

    /// Die Skripte mit Klängen für `GET /api/v1/audio/mp3` (`scripts`).
    static func skriptklaenge(_ z: NGUhrzustand) -> JSONWert {
        var je: [String: [(String, Int)]] = [:]
        for (pfad, daten) in z.ablage.dateien where pfad.hasPrefix("/SCRIPTS/") {
            let teile = pfad.split(separator: "/", omittingEmptySubsequences: true)
            guard teile.count == 3 else { continue }
            je[String(teile[1]), default: []].append((String(teile[2]), daten.count))
        }
        return .liste(je.keys.sorted().map { name in
            .objekt(["name": .text(name),
                     "files": .liste(je[name]!.sorted { $0.0 < $1.0 }.map {
                         .objekt(["name": .text($0.0), "size": .zahl(Double($0.1))])
                     })])
        })
    }

    /// `GET /ICONS/*`, `/MELODIES/*`, `/PALETTES/*`, `/MP3/*`, `/SCRIPTS/*`, `/apploop.json`.
    static func statischeDatei(_ pfad: String, _ z: NGUhrzustand) -> Antwort {
        let fehlt = fehler(404, "notFound", "not found")
        guard pfadOK(pfad) else { return fehlt }
        func datei(_ d: Data) -> Antwort { Antwort(koerper: d, inhaltstyp: "application/octet-stream") }
        if pfad == "/apploop.json" {
            return z.ablage.anzeigenfolge.map { Antwort(koerper: $0) } ?? fehlt
        }
        if pfad.hasPrefix("/MELODIES/"), pfad.hasSuffix(".txt") {
            let name = String(pfad.dropFirst("/MELODIES/".count).dropLast(4))
            return z.ton.melodien[name].map { datei(Data($0.utf8)) } ?? fehlt
        }
        return z.ablage.dateien[pfad].map(datei) ?? fehlt
    }

    // MARK: - Restore

    private static func abgewiesen(_ grund: String) -> Antwort {
        json(.objekt(["ok": .bool(false), "error": .text(grund), "warnings": .liste([])]), status: 400)
    }

    private static func endung(_ name: String) -> String {
        name.lowercased().split(separator: ".").last.map(String.init) ?? ""
    }

    /// `POST /api/v1/restore`.
    static func wiederherstellen(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let teil = dateiteil(a) else { return fehler(400, "badRequest", "no file received") }
        let eintraege: [Sicherungszip.Eintrag]
        do { eintraege = try Sicherungszip.lesen(teil.inhalt) } catch { return abgewiesen("not a zip") }
        do { try Sicherungszip.pruefen(eintraege) } catch {
            switch error as? Sicherungszip.Fehler {
            case .fremdeSicherung?: return abgewiesen("not an awtrix-ng backup")
            case .fassungUnbekannt(let n)?: return abgewiesen("unsupported backup format \(n)")
            default: return abgewiesen(eintraege.isEmpty ? "no manifest.json" : "not an awtrix backup")
            }
        }

        var gezaehlt: [String: Int] = [:]
        var warnungen: [String] = []
        var herkunft: Data?
        func zaehlen(_ k: String) { gezaehlt[k, default: 0] += 1 }
        func ueberspringen(_ s: String) { gezaehlt["skipped", default: 0] += 1; warnungen.append(s) }

        for e in eintraege.dropFirst() {
            let name = e.pfad
            switch name {
            case "config/wifi.json":
                guard case .objekt(let o)? = JSONWert.lesen(e.daten) else {
                    ueberspringen("skipped wifi: invalid JSON"); continue
                }
                for k in ["wifiSsid", "wifiPass"] {
                    if case .text(let t)? = o[k] { z.ablage.system[k] = .text(t) }
                }
                zaehlen("wifi")
            case "config/system.json":
                guard case .objekt(let o)? = JSONWert.lesen(e.daten) else {
                    ueberspringen("system config not applied: invalid JSON"); continue
                }
                for (k, v) in o { z.ablage.system[k] = v }
                if case .text(let t)? = o["mqttPrefix"] { z.mqttPrefix = t }
                zaehlen("system")
            case "config/settings.json":
                let r = einstellungenAendern(Anfrage("PATCH", "/api/v1/settings", koerper: e.daten), &z)
                if r.status == 200 { zaehlen("settings") } else {
                    ueberspringen("settings not applied: " + meldungstext(r))
                }
            case "config/icon-origins.json":
                if case .objekt(let o)? = JSONWert.lesen(e.daten), case .liste? = o["icons"] {
                    herkunft = e.daten
                } else {
                    ueberspringen("skipped icon origins: invalid")
                }
            case "apploop.json":
                if JSONWert.lesen(e.daten) != nil {
                    z.ablage.anzeigenfolge = e.daten
                    zaehlen("appLoop")
                } else {
                    ueberspringen("app order not applied: invalid JSON")
                }
            default:
                dateiEinspielen(e, &z, zaehlen: zaehlen, ueberspringen: ueberspringen)
            }
        }
        if let herkunft {
            z.ablage.iconHerkunft = herkunft
            zaehlen("iconOrigins")
        }

        let schluessel = ["wifi", "system", "settings", "appLoop", "radioStations", "icons", "iconOrigins",
                          "melodies", "palettes", "mp3", "scripts", "skipped"]
        let angewendet = JSONWert.objekt(Dictionary(uniqueKeysWithValues: schluessel.map {
            ($0, JSONWert.zahl(Double(gezaehlt[$0] ?? 0)))
        }))
        return json(.objekt(["ok": .bool(true), "applied": angewendet,
                             "warnings": .liste(warnungen.map { .text($0) })]))
    }

    private static func meldungstext(_ a: Antwort) -> String {
        if case .objekt(let o)? = JSONWert.lesen(a.koerper), case .objekt(let f)? = o["error"],
           case .text(let m)? = f["message"] { return m }
        return "rejected"
    }

    /// Ein Eintrag unter `ICONS/`, `MELODIES/`, `PALETTES/`, `MP3/` oder `SCRIPTS/`.
    private static func dateiEinspielen(_ e: Sicherungszip.Eintrag, _ z: inout NGUhrzustand,
                                        zaehlen: (String) -> Void, ueberspringen: (String) -> Void) {
        let teile = e.pfad.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let ordner = teile.first,
              ["ICONS", "MELODIES", "PALETTES", "MP3", "SCRIPTS"].contains(ordner) else {
            ueberspringen("skipped unknown entry '\(e.pfad)'"); return
        }
        let flach = teile.count == 2 && !teile[1].isEmpty && pfadOK(e.pfad)
        let skriptklang = ordner == "SCRIPTS" && teile.count == 3 && pfadOK(e.pfad)
            && !teile[1].isEmpty && endung(teile[2]) == "mp3"
        guard flach || skriptklang else {
            ueberspringen("skipped unsafe path '\(e.pfad)'"); return
        }
        let datei = teile.last!
        let pfad = "/" + e.pfad
        switch ordner {
        case "ICONS":
            let b = [UInt8](e.daten.prefix(4))
            let gif = b == Array("GIF8".utf8), jpg = b.starts(with: [0xFF, 0xD8, 0xFF])
            guard ["gif", "jpg", "jpeg"].contains(endung(datei)), gif || jpg else {
                ueberspringen("skipped \(pfad): expected GIF or JPEG"); return
            }
            z.ablage.dateien[pfad] = e.daten
            zaehlen("icons")
        case "MELODIES":
            let name = String(datei.dropLast(4))
            guard endung(datei) == "txt", let text = String(data: e.daten, encoding: .utf8),
                  (1...24).contains(name.count), Klangname.gueltig(name),
                  !text.isEmpty, text.count <= hoechsteMelodie, rtttlFehler(text) == nil else {
                ueberspringen("skipped \(pfad): expected RTTTL"); return
            }
            guard !z.ton.mp3.contains(name) else { ueberspringen("skipped \(pfad): name taken"); return }
            z.ton.melodien[name] = text
            zaehlen("melodies")
        case "PALETTES":
            guard !e.daten.isEmpty else { ueberspringen("skipped \(pfad): empty"); return }
            z.ablage.dateien[pfad] = e.daten
            zaehlen("palettes")
        case "MP3":
            let name = String(datei.dropLast(4))
            guard endung(datei) == "mp3", Klangname.gueltig(name), istMP3(e.daten) else {
                ueberspringen("skipped \(pfad): expected MP3"); return
            }
            guard z.ton.melodien[name] == nil else { ueberspringen("skipped \(pfad): name taken"); return }
            if !z.ton.mp3.contains(name) { z.ton.mp3.append(name) }
            z.ton.mp3Groessen[name] = e.daten.count
            z.ablage.dateien[pfad] = e.daten
            zaehlen("mp3")
        default:
            if skriptklang {
                guard istMP3(e.daten) else { ueberspringen("skipped \(pfad): expected MP3"); return }
                z.ablage.dateien[pfad] = e.daten
                zaehlen("mp3")
            } else {
                z.ablage.dateien[pfad] = e.daten
                zaehlen("scripts")
            }
        }
    }
}
