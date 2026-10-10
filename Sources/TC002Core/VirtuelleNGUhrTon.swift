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
    /// Namen gespeicherter MP3-Dateien. Hochladen gibt es hier nicht; Tests legen sie an.
    public var mp3: [String] = []
    public var sender: [Radiosender] = [Radiosender(name: "Fm4", url: "http://orf-live.ors-shoutcast.at/fm4-q2a")]
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

    public init() {}
}

/// Die Audio-Routen der virtuellen NG-Uhr (§3.2.1, §4.2, §7.5, §8).
///
/// Nicht nachgebildet: `POST /audio/clip`, MP3 hochladen, löschen und
/// umbenennen (`404 unknown route`).
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
///   alles zu `song` (die Syntax des Liedtexts prüft die virtuelle Uhr nicht, sie
///   weist nur die Länge ab);
/// - ein Name in `file` mit Schrägstrich (`Skript/name`) gilt als nicht gefunden,
///   solange es keine Skriptklänge gibt;
/// - `song` wird nur auf Länge geprüft, nicht gelesen;
/// - eine unlesbare Melodie ist, was nicht aus drei durch `:` getrennten Teilen
///   mit Noten besteht; die Uhr prüft vermutlich genauer;
/// - `audio/stop` mit einem anderen Schlüssel als `group` ist `422` mit dem
///   Schlüssel als `field`; leerer Rumpf und `{}` halten alles an;
/// - Antworten von `PUT`/`DELETE` auf Melodien und Sender sind `{"ok":true}`, der
///   Eintrag einer Melodie in der Liste ist `{"name","size"}` (Bytes des
///   Quelltexts), `totalBytes` eine runde Zahl;
/// - Melodiename: 1–24 Zeichen, nur Buchstaben, Ziffern, `_` und `-`
///   (`422`, `field` = `name`); ein Name, den schon eine MP3 trägt, ist `409
///   nameTaken` (§8);
/// - Zeilen einer Senderliste werden ab 0 gezählt (`stations[0].name`).
extension VirtuelleNGUhr {
    static let hoechsteMelodie = 512
    static let hoechsterSprechtext = 512
    static let hoechstesLied = 16384
    static let hoechsteSender = 32
    static let gesamtSpeicher = 1_048_576

    // MARK: - Fähigkeiten

    private static func kann(_ schluessel: String) -> Bool {
        guard case .objekt(let o) = capabilities, case .objekt(let a)? = o["audio"],
              case .bool(let b)? = a[schluessel] else { return false }
        return b
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
        default: return falsch("must be a string or an object")
        }
        let erlaubt = Set(meldung ? ["file", "rtttl", "speech", "loop"] : klangquellen + ["loop"])
        for k in o.keys.sorted() where !erlaubt.contains(k) { return falsch("unknown field", k) }
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
                guard rtttlLesbar(s) else { return falsch("unreadable melody", q) }
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

    static func rtttlLesbar(_ s: String) -> Bool {
        let teile = s.split(separator: ":", omittingEmptySubsequences: false)
        return teile.count == 3 && !teile[2].trimmingCharacters(in: .whitespaces).isEmpty
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
            if klein.hasPrefix("http://") || klein.hasPrefix("https://") { return kann("url") ? .spielbar : .unmoeglich }
            if z.ton.melodien[name] != nil { return kann("rtttl") ? .spielbar : .unmoeglich }
            return z.ton.mp3.contains(name) ? (kann("mp3") ? .spielbar : .unmoeglich) : .fehlt(name)
        }
        if k["rtttl"] != nil { return kann("rtttl") ? .spielbar : .unmoeglich }
        if k["song"] != nil { return kann("song") ? .spielbar : .unmoeglich }
        if k["speech"] != nil { return kann("speech") ? .spielbar : .unmoeglich }
        guard kann("radio") else { return .unmoeglich }
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
        if let fehlte { return fehler(404, "notFound", "nothing called \"\(fehlte)\"") }
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
            guard case .text(let name)? = o["name"], (1...24).contains(name.count) else {
                return ungueltig("invalid name", feld: "stations[\(i)].name")
            }
            guard case .text(let url)? = o["url"], url.count <= 255,
                  url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://"),
                  !url.contains(where: \.isWhitespace) else {
                return ungueltig("invalid url", feld: "stations[\(i)].url")
            }
            neu.append(Radiosender(name: name, url: url))
        }
        z.ton.sender = neu
        return ok
    }

    /// `GET /api/v1/audio/melodies`.
    static func melodienliste(_ z: NGUhrzustand) -> Antwort {
        let namen = z.ton.melodien.keys.sorted()
        let eintraege = namen.map { JSONWert.objekt(["name": .text($0), "size": .zahl(Double(z.ton.melodien[$0]!.utf8.count))]) }
        let belegt = z.ton.melodien.values.reduce(0) { $0 + $1.utf8.count }
        return json(.objekt(["melodies": .liste(eintraege), "usedBytes": .zahl(Double(belegt)),
                             "totalBytes": .zahl(Double(gesamtSpeicher))]))
    }

    /// `GET /api/v1/audio/mp3`.
    static func mp3liste(_ z: NGUhrzustand) -> Antwort {
        json(.objekt(["files": .liste(z.ton.mp3.sorted().map { .objekt(["name": .text($0)]) }),
                      "scripts": .liste([]), "usedBytes": .zahl(0), "totalBytes": .zahl(Double(gesamtSpeicher))]))
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
        guard rtttlLesbar(text) else { return ungueltig("unreadable melody", feld: "rtttl") }
        guard !z.ton.mp3.contains(name) else { return fehler(409, "nameTaken", "name already taken") }
        let neu = z.ton.melodien[name] == nil
        z.ton.melodien[name] = text
        return Antwort(status: neu ? 201 : 200, koerper: ok.koerper)
    }
}
