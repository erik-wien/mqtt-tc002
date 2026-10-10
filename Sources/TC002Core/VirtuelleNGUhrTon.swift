import Foundation

/// Was die virtuelle Uhr von Klang hält. Gespielt wird nichts; sie merkt sich,
/// was gespielt und angehalten wurde, damit Tests es prüfen können.
public struct NGTon: Equatable, Sendable {
    public struct Wiedergabe: Equatable, Sendable {
        public var spielt = false
        public var name = ""
    }

    /// Melodienname → RTTTL-Text (`/MELODIES/<name>.txt`).
    public var melodien: [String: String] = [:]
    /// Namen gespeicherter MP3-Dateien (ohne `.mp3`). Tests legen sie an oder
    /// laden sie hoch (`POST /audio/mp3`).
    public var mp3: [String] = []
    /// Größe je MP3-Datei in Byte; eine fehlende zählt 0.
    public var mp3Groessen: [String: Int] = [:]
    public var sender: [Radiosender] = [Radiosender(name: "Fm4", url: "http://radio.example.com/stream")]
    /// Die Klangobjekte, die `audio/play` gewählt hat — je Anfrage eines, in
    /// der Reihenfolge der Anfragen. Das Objekt ist so, wie es angenommen wurde.
    public var gespielt: [JSONWert] = []
    /// Was `audio/stop` angehalten hat: `alert`, `app`, `radio` oder `all`.
    public var gestoppt: [String] = []
    public var alarm = Wiedergabe()
    public var app = Wiedergabe()
    public var radio = Wiedergabe()
    /// Das Gerät hat keinen Ausgang: Jedes Abspielen ist `503 unavailable`
    /// („no audio output“, §3.4).
    public var ohneAusgabe = false
    /// Die Schalter von `capabilities.audio`; `nil` heißt: die der TC002.
    /// `tc001` ist der Satz der TC001 (gemessen 10. Oktober 2026): Melodien auf
    /// dem Summer, keine MP3, kein Sprechen. Das Hochladen einer MP3 nimmt auch
    /// sie an.
    public var faehigkeiten: [String: Bool]?

    public static let tc001: [String: Bool] = [
        "mp3": false, "rtttl": true, "song": false, "speech": false, "track": false,
        "radio": false, "url": false, "effect": false, "clip": false]

    func kann(_ schluessel: String) -> Bool {
        if let faehigkeiten { return faehigkeiten[schluessel] ?? false }
        return VirtuelleNGUhr.kannTC002(schluessel)
    }

    public init() {}
}

/// Die Audio-Routen der virtuellen NG-Uhr (§3.2.1, §4.2, §7.5, §8).
///
/// Nicht nachgebildet: `POST /audio/clip` und MP3 umbenennen (`404 unknown route`).
///
/// Annahmen, wo die Doku schweigt (❓):
/// - `audio/play` spielt in die Gruppe `alert`, `station` ins Radio; der Name in
///   `alert.name` ist der Wert von `file`, sonst der Schlüssel (`rtttl`, `song`,
///   `speech`);
/// - ein Klang in einer Liste, den das Gerät nicht spielen kann (Fähigkeit fehlt,
///   Datei oder Sender unbekannt), wird übersprungen; spielt keiner, ist es `404
///   notFound`, wenn einer nur fehlte, sonst `503 unavailable`;
/// - die Meldungen sind die gemessenen (§3.2.1); ungemessen sind `404` bei einer
///   Station (gleicher Wortlaut wie bei `file`), `503` ohne spielbaren Klang und
///   die Syntaxfehler von `song` (die virtuelle Uhr weist nur die Länge ab);
/// - in der Melodienliste ist `durationMs` immer 0 (die Uhr rechnet die Dauer);
/// - ein Name in `file` mit Schrägstrich (`Skript/name`) gilt als nicht gefunden,
///   solange es keine Skriptklänge gibt;
/// - `song` wird nur auf Länge geprüft, nicht gelesen;
/// - eine unlesbare Melodie ist, was nicht aus drei durch `:` getrennten Teilen
///   mit Noten besteht; die Uhr prüft vermutlich genauer;
/// - `audio/stop` mit einem anderen Schlüssel als `group` ist `422` mit dem
///   Schlüssel als `field`; leerer Rumpf und `{}` halten alles an;
/// - `totalBytes` ist eine runde Zahl; `409 nameTaken` bei einer Melodie: Wortlaut ungemessen, bei einer MP3 `name taken`;
/// - Melodiename: 1–24 Zeichen, nur Buchstaben, Ziffern, `_` und `-`
///   (`422`, `field` = `name`); ein Name, den schon eine MP3 trägt, ist `409
///   nameTaken` (§8);
/// - ein Sendername über 24 Zeichen ist `too long` (ungemessen);
/// - MP3 hochladen, auflisten, löschen nach der Messung vom 10. Oktober 2026
///   (§4.2): Name `[A-Za-z0-9_-]{1,32}` mit `.mp3` im Dateinamen des
///   `multipart`-Teils `file`, sonst `400 invalidName`; gleicher Name ersetzt still;
///   eine Melodie gleichen Namens ist `409 nameTaken`; kein MP3-Inhalt ist `415`.
///   ❓ Als MP3 gilt, was mit `ID3` oder einem MPEG-Frame-Sync (`0xFF`, dann die
///   oberen drei Bits des zweiten Bytes gesetzt) beginnt. ❓ Reihenfolge der
///   Prüfungen: Name, Inhalt, Melodie, Platz; ein Rumpf ohne `multipart` oder ohne
///   Teil `file` ist `400 badRequest`; zu wenig Platz ist `507 insufficientStorage`;
///   `DELETE` einer unbekannten Datei ist `404 notFound`.
extension VirtuelleNGUhr {
    static let hoechsteMelodie = 512
    static let hoechsterSprechtext = 512
    static let hoechstesLied = 16384
    static let hoechsteSender = 32
    static let gesamtSpeicher = 1_048_576

    // MARK: - Fähigkeiten

    static func kannTC002(_ schluessel: String) -> Bool {
        guard case .objekt(let o) = capabilities, case .objekt(let a)? = o["audio"],
              case .bool(let b)? = a[schluessel] else { return false }
        return b
    }

    /// `GET /api/v1/capabilities`; mit eigenem Audiosatz (`NGTon.faehigkeiten`)
    /// tragen `audio` und `platform.id` (`esp32`, wenn der Satz der der TC001 ist).
    static func faehigkeitenantwort(_ z: NGUhrzustand) -> JSONWert {
        guard case .objekt(var o) = capabilities else { return capabilities }
        o["sensors"] = .objekt(["light": .bool(z.lichtsensor)])
        if let satz = z.ton.faehigkeiten {
            o["audio"] = .objekt(satz.mapValues { .bool($0) })
            if satz == NGTon.tc001 { o["platform"] = .objekt(["id": .text("esp32")]) }
        }
        return .objekt(o)
    }

    // MARK: - Klänge prüfen

    private static let klangquellen = ["file", "rtttl", "song", "speech", "station"]

    /// Prüft einen Klang und liefert das Objekt, wie die Uhr es versteht. `ort`
    /// ist der Vorsatz für `field`: leer bei `audio/play`, `[1]` in dessen Liste,
    /// `sound` bzw. `sound[1]` bei einer Benachrichtigung.
    private static func klangpruefen(_ wert: JSONWert, ort: String,
                                     meldung: Bool) -> (objekt: [String: JSONWert]?, fehler: Antwort?) {
        func stelle(_ schluessel: String) -> String { ort.isEmpty ? schluessel : ort + "." + schluessel }
        func falsch(_ text: String, _ schluessel: String? = nil) -> (objekt: [String: JSONWert]?, fehler: Antwort?) {
            let feld = schluessel.map(stelle) ?? (ort.isEmpty ? nil : ort)
            return (nil, ungueltig(text, feld: feld))
        }
        let o: [String: JSONWert]
        switch wert {
        case .text(let name): o = ["file": .text(name)]
        case .objekt(let x): o = x
        default: return falsch(meldung ? "must be a string, object or list" : "must be a string or an object")
        }
        // Gemessen: In einer Benachrichtigung ist `station` „not here“, `song` erlaubt.
        let erlaubt = Set(meldung ? ["file", "rtttl", "song", "speech", "loop"] : klangquellen + ["loop"])
        for k in o.keys.sorted() where !erlaubt.contains(k) {
            return falsch(meldung && k == "station" ? "not here" : "unknown field", k)
        }
        let quellen = klangquellen.filter { o[$0] != nil }
        guard !quellen.isEmpty else { return falsch("one source required") }
        guard quellen.count == 1 else { return falsch("one sound key only", quellen[0]) }
        let q = quellen[0]
        switch (q, o[q]!) {
        case ("station", .zahl):
            guard let n = o[q]?.ganzzahl, n >= 0 else { return falsch("must be a position from 0", q) }
        case (_, .text(let s)):
            guard !s.isEmpty else { return falsch(q == "speech" ? "must be 1..512 bytes" : "must not be empty", q) }
            switch q {
            case "file":
                if !s.lowercased().hasPrefix("http://"), !s.lowercased().hasPrefix("https://"),
                   s.lowercased().contains(".mp3") || s.lowercased().contains(".txt") {
                    return falsch("invalid name", q)
                }
            case "rtttl":
                guard s.count <= hoechsteMelodie else { return falsch("too long", q) }
                if let grund = rtttlFehler(s) { return falsch(grund, q) }
            case "song":
                guard s.utf8.count <= hoechstesLied else { return falsch("too long", q) }
            case "speech":
                guard s.utf8.count <= hoechsterSprechtext else { return falsch("must be 1..512 bytes", q) }
            default: break
            }
        default:
            return falsch("wrong type", q)
        }
        if let l = o["loop"] {
            guard case .bool(let b) = l else { return falsch("must be a boolean", "loop") }
            if b, q == "station" { return falsch("not with station", "loop") }
        }
        return (o, nil)
    }

    /// Gemessen für `audio/play`: `kaputt` → `missing ':' (at offset 6)`,
    /// `a:d=4:` → `empty note (at offset 6)`; der Offset ist die Länge des Textes.
    /// Ein Namensteil darf fehlen. ❓ Andere Fehlerfälle (ungültige Einstellungen,
    /// Noten) prüft die Emulation nicht.
    static func rtttlFehler(_ s: String) -> String? {
        let teile = s.split(separator: ":", omittingEmptySubsequences: false)
        guard teile.count == 3 else { return "missing ':' (at offset \(s.count))" }
        guard !teile[2].trimmingCharacters(in: .whitespaces).isEmpty else { return "empty note (at offset \(s.count))" }
        return nil
    }

    /// `sound` einer Benachrichtigung (§5.6): Name, Objekt oder Liste von 1–4;
    /// `""` und `null` sind kein Klang. Spielbar oder nicht ist **kein** Fehler,
    /// die Benachrichtigung erscheint dann stumm.
    static func meldungstonPruefen(_ wert: JSONWert) -> Antwort? {
        switch wert {
        case .null: return nil
        case .text(""): return nil
        case .liste(let l):
            guard (1...4).contains(l.count) else { return ungueltig("must have 1 to 4 entries", feld: "sound") }
            for (i, e) in l.enumerated() {
                if let f = klangpruefen(e, ort: "sound[\(i + 1)]", meldung: true).fehler { return f }
            }
            return nil
        default:
            return klangpruefen(wert, ort: "sound", meldung: true).fehler
        }
    }

    // MARK: - Abspielen und Anhalten

    private enum Spielbarkeit { case spielbar, fehlt(String), unmoeglich }

    private static func spielbarkeit(_ k: [String: JSONWert], _ z: NGUhrzustand) -> Spielbarkeit {
        if case .text(let name)? = k["file"] {
            let klein = name.lowercased()
            if klein.hasPrefix("http://") || klein.hasPrefix("https://") { return z.ton.kann("url") ? .spielbar : .unmoeglich }
            if z.ton.melodien[name] != nil { return z.ton.kann("rtttl") ? .spielbar : .unmoeglich }
            return z.ton.mp3.contains(name) ? (z.ton.kann("mp3") ? .spielbar : .unmoeglich) : .fehlt(name)
        }
        if k["rtttl"] != nil { return z.ton.kann("rtttl") ? .spielbar : .unmoeglich }
        if k["song"] != nil { return z.ton.kann("song") ? .spielbar : .unmoeglich }
        if k["speech"] != nil { return z.ton.kann("speech") ? .spielbar : .unmoeglich }
        guard z.ton.kann("radio") else { return .unmoeglich }
        switch k["station"] {
        case .zahl?:
            guard let n = k["station"]?.ganzzahl else { return .fehlt("?") }
            return n < z.ton.sender.count ? .spielbar : .fehlt(String(n))
        case .text(let s)?:
            let klein = s.lowercased()
            if klein.hasPrefix("http://") || klein.hasPrefix("https://") { return .spielbar }
            return z.ton.sender.contains { $0.name.caseInsensitiveCompare(s) == .orderedSame } ? .spielbar : .fehlt(s)
        default: return .fehlt("?")
        }
    }

    /// `POST /api/v1/audio/play` (§3.2.1).
    static func tonSpielen(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        var klaenge: [[String: JSONWert]] = []
        if case .liste(let l) = wert {
            guard (1...4).contains(l.count) else { return ungueltig("must have 1 to 4 entries") }
            for (i, e) in l.enumerated() {
                let (objekt, fehler) = klangpruefen(e, ort: "[\(i + 1)]", meldung: false)
                if let fehler { return fehler }
                klaenge.append(objekt!)
            }
        } else {
            let (objekt, fehler) = klangpruefen(wert, ort: "", meldung: false)
            if let fehler { return fehler }
            klaenge = [objekt!]
        }
        if z.ton.ohneAusgabe { return fehler(503, "unavailable", "no audio output") }
        var fehlte: String?
        for k in klaenge {
            switch spielbarkeit(k, z) {
            case .spielbar:
                z.ton.gespielt.append(.objekt(k))
                if case .text(let name)? = k["file"] {
                    z.ton.alarm = NGTon.Wiedergabe(spielt: true, name: name)
                } else if let q = klangquellen.first(where: { k[$0] != nil }), q != "station" {
                    z.ton.alarm = NGTon.Wiedergabe(spielt: true, name: q)
                } else {
                    var name = ""
                    if case .text(let s)? = k["station"] {
                        name = z.ton.sender.first { $0.name.caseInsensitiveCompare(s) == .orderedSame }?.name ?? s
                    }
                    if case .zahl? = k["station"], let n = k["station"]?.ganzzahl { name = z.ton.sender[n].name }
                    z.ton.radio = NGTon.Wiedergabe(spielt: true, name: name)
                }
                return ok
            case .fehlt(let name): fehlte = fehlte ?? name
            case .unmoeglich: break
            }
        }
        if let fehlte {
            // Gemessen: ohne Schrägstrich `nothing called "x"`, mit `no file "x/y"`.
            let text = fehlte.contains("/") ? "no file \"\(fehlte)\"" : "nothing called \"\(fehlte)\""
            return fehler(404, "notFound", text)
        }
        return fehler(503, "unavailable", "no playable sound")
    }

    /// `POST /api/v1/audio/stop`: `{"group":"alert"|"app"|"radio"}`, sonst alles.
    static func tonStoppen(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        var gruppe: String?
        let leer = a.koerper.allSatisfy { $0 == 32 || $0 == 10 || $0 == 13 || $0 == 9 }
        if !leer {
            guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
            guard case .objekt(let o) = wert else { return ungueltig("must be an object") }
            if let k = o.keys.sorted().first(where: { $0 != "group" }) { return ungueltig("unknown field", feld: k) }
            if let g = o["group"] {
                guard case .text(let s) = g, ["alert", "app", "radio"].contains(s) else {
                    return ungueltig("must be alert, app or radio", feld: "group")
                }
                gruppe = s
            }
        }
        z.ton.gestoppt.append(gruppe ?? "all")
        if gruppe == nil || gruppe == "alert" { z.ton.alarm = NGTon.Wiedergabe() }
        if gruppe == nil || gruppe == "app" { z.ton.app = NGTon.Wiedergabe() }
        if gruppe == nil || gruppe == "radio" { z.ton.radio = NGTon.Wiedergabe() }
        return ok
    }

    // MARK: - Zustand und Listen

    private static func senderwert(_ s: [Radiosender]) -> JSONWert {
        .liste(s.map { .objekt(["name": .text($0.name), "url": .text($0.url)]) })
    }

    /// `GET /api/v1/audio` (§7.5).
    static func tonzustand(_ z: NGUhrzustand) -> JSONWert {
        .objekt([
            "radio": .objekt(["playing": .bool(z.ton.radio.spielt), "station": .text(z.ton.radio.name),
                              "title": .text(""), "error": .text(""), "underruns": .zahl(0),
                              "decodeUs": .zahl(0), "starvedMs": .zahl(0), "bufferBytes": .zahl(0)]),
            "app": .objekt(["playing": .bool(z.ton.app.spielt), "name": .text(z.ton.app.name), "error": .text("")]),
            "alert": .objekt(["playing": .bool(z.ton.alarm.spielt), "name": .text(z.ton.alarm.name),
                              "error": .text("")]),
            "stations": senderwert(z.ton.sender),
        ])
    }

    /// `GET`/`PUT /api/v1/audio/stations`: ganze Liste lesen bzw. ersetzen.
    static func tonSender(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        if a.methode == "GET" { return json(.objekt(["stations": senderwert(z.ton.sender)])) }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        let roh: [JSONWert]
        switch wert {
        case .liste(let l): roh = l
        case .objekt(let o):
            guard case .liste(let l)? = o["stations"] else { return ungueltig("stations required", feld: "stations") }
            roh = l
        default: return ungueltig("must be an object or an array")
        }
        guard roh.count <= hoechsteSender else { return ungueltig("too many stations", feld: "stations") }
        var neu: [Radiosender] = []
        for (i, e) in roh.enumerated() {
            guard case .objekt(let o) = e else { return ungueltig("must be an object", feld: "stations[\(i)]") }
            // Gemessen: leerer Name `must not be empty`, `ftp://` `must be an http(s) URL`.
            guard case .text(let name)? = o["name"], !name.isEmpty else {
                return ungueltig("must not be empty", feld: "stations[\(i)].name")
            }
            guard name.count <= 24 else { return ungueltig("too long", feld: "stations[\(i)].name") }
            guard case .text(let url)? = o["url"], url.count <= 255,
                  url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://"),
                  !url.contains(where: \.isWhitespace) else {
                return ungueltig("must be an http(s) URL", feld: "stations[\(i)].url")
            }
            neu.append(Radiosender(name: name, url: url))
        }
        z.ton.sender = neu
        return ok
    }

    /// `GET /api/v1/audio/melodies`.
    static func melodienliste(_ z: NGUhrzustand) -> Antwort {
        let namen = z.ton.melodien.keys.sorted()
        let eintraege = namen.map { n -> JSONWert in
            let text = z.ton.melodien[n]!
            let teile = text.split(separator: ":", omittingEmptySubsequences: false)
            let noten = teile.count == 3 ? teile[2].split(separator: ",").count : 0
            return .objekt(["name": .text(n), "rtttl": .text(text), "bytes": .zahl(Double(text.utf8.count)),
                            "notes": .zahl(Double(noten)), "durationMs": .zahl(0), "valid": .bool(true)])
        }
        let belegt = z.ton.melodien.values.reduce(0) { $0 + $1.utf8.count }
        return json(.objekt(["melodies": .liste(eintraege), "usedBytes": .zahl(Double(belegt)),
                             "totalBytes": .zahl(Double(gesamtSpeicher))]))
    }

    private static func mp3Belegt(_ z: NGUhrzustand) -> Int {
        z.ton.mp3.reduce(0) { $0 + (z.ton.mp3Groessen[$1] ?? 0) }
    }

    /// `GET /api/v1/audio/mp3`: die Namen mit Endung, wie die Uhr sie führt.
    static func mp3liste(_ z: NGUhrzustand) -> Antwort {
        let dateien = z.ton.mp3.sorted().map { n -> JSONWert in
            .objekt(["name": .text(n + ".mp3"), "size": .zahl(Double(z.ton.mp3Groessen[n] ?? 0))])
        }
        return json(.objekt(["files": .liste(dateien), "scripts": .liste([]),
                             "usedBytes": .zahl(Double(mp3Belegt(z))), "totalBytes": .zahl(Double(gesamtSpeicher))]))
    }

    private static func istMP3(_ daten: Data) -> Bool {
        let b = [UInt8](daten.prefix(3))
        if b == [0x49, 0x44, 0x33] { return true }
        return b.count >= 2 && b[0] == 0xFF && b[1] & 0xE0 == 0xE0
    }

    /// Der Dateiname und der Inhalt des Teils `file` eines `multipart/form-data`-Rumpfes.
    private static func dateiteil(_ a: Anfrage) -> (name: String, inhalt: Data)? {
        let art = a.kopf["content-type"] ?? ""
        guard art.lowercased().hasPrefix("multipart/form-data"),
              let r = art.range(of: "boundary=") else { return nil }
        let grenze = String(art[r.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\" ;"))
        let trenner = Data(("--" + grenze).utf8)
        let kopfende = Data("\r\n\r\n".utf8)
        var start = a.koerper.startIndex
        while let hit = a.koerper.range(of: trenner, in: start..<a.koerper.endIndex) {
            let teilStart = hit.upperBound
            guard let naechster = a.koerper.range(of: trenner, in: teilStart..<a.koerper.endIndex) else { break }
            var teil = a.koerper[teilStart..<naechster.lowerBound]
            if teil.starts(with: Data("\r\n".utf8)) { teil = teil.dropFirst(2) }
            if let ende = teil.range(of: kopfende) {
                let kopf = String(decoding: teil[teil.startIndex..<ende.lowerBound], as: UTF8.self)
                var inhalt = teil[ende.upperBound...]
                if inhalt.suffix(2) == Data("\r\n".utf8) { inhalt = inhalt.dropLast(2) }
                if kopf.contains("name=\"file\""),
                   let f = kopf.range(of: "filename=\""),
                   let zu = kopf[f.upperBound...].firstIndex(of: "\"") {
                    return (String(kopf[f.upperBound..<zu]), Data(inhalt))
                }
            }
            start = naechster.lowerBound
        }
        return nil
    }

    /// `POST /api/v1/audio/mp3`.
    static func mp3Hochladen(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let teil = dateiteil(a) else { return fehler(400, "badRequest", "expected multipart file") }
        let name = teil.name.hasSuffix(".mp3") ? String(teil.name.dropLast(4)) : ""
        guard Klangname.gueltig(name) else { return fehler(400, "invalidName", "invalid file name") }
        guard istMP3(teil.inhalt) else { return fehler(415, "unsupportedMediaType", "expected MP3") }
        guard z.ton.melodien[name] == nil else { return fehler(409, "nameTaken", "name taken") }
        let frei = gesamtSpeicher - mp3Belegt(z) + (z.ton.mp3Groessen[name] ?? 0)
        guard teil.inhalt.count <= frei else { return fehler(507, "insufficientStorage", "not enough space") }
        if !z.ton.mp3.contains(name) { z.ton.mp3.append(name) }
        z.ton.mp3Groessen[name] = teil.inhalt.count
        return ok
    }

    /// `DELETE /api/v1/audio/mp3/{name}`.
    static func mp3Loeschen(_ name: String, _ z: inout NGUhrzustand) -> Antwort {
        guard z.ton.mp3.contains(name) else { return fehler(404, "notFound", "file not found") }
        z.ton.mp3.removeAll { $0 == name }
        z.ton.mp3Groessen[name] = nil
        return ok
    }

    /// `PUT`/`DELETE /api/v1/audio/melodies/{name}`.
    static func melodie(_ name: String, _ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        let gueltig = (1...24).contains(name.count)
            && name.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
                || ($0 >= 97 && $0 <= 122) || $0 == 95 || $0 == 45 }
        if a.methode == "DELETE" {
            guard z.ton.melodien.removeValue(forKey: name) != nil else {
                return fehler(404, "notFound", "melody not found")
            }
            return ok
        }
        guard gueltig else { return ungueltig("invalid name", feld: "name") }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let o) = wert, case .text(let text)? = o["rtttl"] else {
            return ungueltig("rtttl required", feld: "rtttl")
        }
        guard !text.isEmpty, text.count <= hoechsteMelodie else { return ungueltig("invalid length", feld: "rtttl") }
        guard rtttlFehler(text) == nil else { return ungueltig("expected name:defaults:notes", feld: "rtttl") }
        guard !z.ton.mp3.contains(name) else { return fehler(409, "nameTaken", "name taken") }
        let neu = z.ton.melodien[name] == nil
        // Gemessen: Die Uhr schreibt den Namensteil des RTTTL auf den Melodienamen um.
        let teile = text.split(separator: ":", omittingEmptySubsequences: false)
        z.ton.melodien[name] = name + ":" + teile[1] + ":" + teile[2]
        return Antwort(status: neu ? 201 : 200, koerper: ok.koerper)
    }
}
