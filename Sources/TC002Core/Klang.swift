import Foundation

/// Was beim Zusammenstellen eines Klangs schiefgehen kann, bevor etwas
/// hinausgeht (`docs/awtrix-ng-protokoll.md` §3.2.1, §5.6, §8). Die Uhr
/// antwortet auf einen falsch gebauten Klang mit `422`; über MQTT bliebe die
/// Antwort womöglich ungelesen, darum prüft der Kern vorher.
public enum KlangFehler: Error, LocalizedError, Equatable {
    case keineQuelle
    /// Zwei Quellen in einem Klang: Die Uhr nimmt genau eine.
    case mehrereQuellen
    case leer(feld: String)
    case zuLang(feld: String, grenze: Int, einheit: String)
    /// `loop` mit `station`: Ein Radiostrom wiederholt sich nicht.
    case wiederholenMitSender
    case ungueltigeAnzahl(Int)
    /// Quelle, die ein Benachrichtigungston nicht kennt (`station`).
    case nichtInBenachrichtigung(feld: String)
    /// Die Uhr meldet in `capabilities.audio`, dass sie das nicht kann.
    case nichtGekonnt(faehigkeit: String)
    /// `audio.mp3` ist aus: Die Uhr nähme die Datei an, könnte sie aber nicht spielen.
    case mp3NichtSpielbar
    case endungImNamen(String)
    case unlesbareMelodie
    case ungueltigerMelodiename(String)
    case zuvieleSender(Int)
    case ungueltigerSender(zeile: Int, feld: String)
    case ungueltigeGruppe(String)
    case negativePosition(Int)
    /// Melodien und Listen gibt es nur über HTTP.
    case nurUeberHTTP
    /// Kein Name, den die Uhr für eine MP3-Datei nimmt (`Klangname`).
    case ungueltigerKlangname(String)
    case mp3Leer
    case mp3ZuGross(bytes: Int, grenze: Int)
    /// `409 nameTaken`: Eine Melodie heißt schon so.
    case mp3NameBelegt(String)
    /// `415 unsupportedMediaType`: Die Uhr erkennt die Datei nicht als MP3.
    case keinMP3
    /// `507` oder `413`: Die Uhr hat keinen Platz für die Datei.
    case mp3KeinPlatz
    /// `404` beim Löschen.
    case mp3Unbekannt(String)

    public var errorDescription: String? {
        switch self {
        case .keineQuelle:
            return lok("Ein Klang braucht eine Quelle: Datei, RTTTL, Lied, Sprechtext oder Sender.")
        case .mehrereQuellen:
            return lok("Ein Klang hat genau eine Quelle, nicht mehrere.")
        case .leer(let feld):
            return lokf("„%@“ darf nicht leer sein.", feld)
        case .zuLang(let feld, let grenze, let einheit):
            return lokf("„%@“ ist zu lang: höchstens %d %@.", feld, grenze, einheit)
        case .wiederholenMitSender:
            return lok("Ein Sender lässt sich nicht wiederholen: „loop“ gilt nicht für Radio.")
        case .ungueltigeAnzahl(let n):
            return lokf("Eine Klangliste hat 1 bis 4 Klänge, nicht %d.", n)
        case .nichtInBenachrichtigung(let feld):
            return lokf("„%@“ ist als Benachrichtigungston nicht erlaubt; möglich sind Datei, RTTTL, Lied und Sprechtext.", feld)
        case .nichtGekonnt(let f):
            return lokf("Diese Uhr kann das nicht: Sie meldet „%@“ nicht als Fähigkeit.", f)
        case .mp3NichtSpielbar:
            return lok("Diese Uhr kann keine MP3 spielen. Die Datei wird nicht hochgeladen.")
        case .endungImNamen(let name):
            return lokf("„%@“ ist ein Name ohne Endung: „.mp3“ und „.txt“ setzt die Uhr selbst.", name)
        case .ungueltigerKlangname(let name):
            return lokf("„%@“ ist kein Name für eine MP3-Datei: erlaubt sind 1 bis 32 Zeichen aus Buchstaben, Ziffern, „_“ und „-“.", name)
        case .mp3Leer:
            return lok("Die Datei ist leer.")
        case .mp3ZuGross(let bytes, let grenze):
            return lokf("Die Datei ist zu groß: %d Byte, höchstens %d.", bytes, grenze)
        case .mp3NameBelegt(let name):
            return lokf("„%@“ ist auf der Uhr schon vergeben, und zwar von einer Melodie.", name)
        case .keinMP3:
            return lok("Die Uhr erkennt die Datei nicht als MP3.")
        case .mp3KeinPlatz:
            return lok("Auf der Uhr ist für die Datei kein Platz mehr.")
        case .mp3Unbekannt(let name):
            return lokf("Auf der Uhr gibt es keine MP3-Datei „%@“.", name)
        case .unlesbareMelodie:
            return lok("Die Melodie ist kein RTTTL: Name, Einstellungen und Noten, durch „:“ getrennt.")
        case .ungueltigerMelodiename(let name):
            return lokf("„%@“ ist kein Melodiename: erlaubt sind 1 bis 24 Zeichen aus Buchstaben, Ziffern, „_“ und „-“.", name)
        case .zuvieleSender(let n):
            return lokf("Die Uhr nimmt höchstens 32 Sender, nicht %d.", n)
        case .ungueltigerSender(let zeile, let feld):
            return lokf("Sender %d: „%@“ ist ungültig.", zeile, feld)
        case .ungueltigeGruppe(let g):
            return lokf("„%@“ ist keine Klanggruppe. Möglich: alarm, app, radio.", g)
        case .negativePosition(let n):
            return lokf("Die Listenposition eines Senders beginnt bei 0, nicht bei %d.", n)
        case .nurUeberHTTP:
            return lok("Das gibt es nur über HTTP, und für diese Uhr ist keine Adresse eingetragen. Unter „Einstellungen“ die Adresse eintragen.")
        }
    }
}

/// Die Klangquellen, die eine Uhr als Fähigkeit nennt (`capabilities.audio`,
/// §7.4). Fehlt `audio` in der Antwort ganz, ist die Auskunft unbekannt
/// (`Geraetefaehigkeiten.ton == nil`) und nichts gesperrt; ein einzelner
/// fehlender Schalter in einem vorhandenen `audio` gilt ebenso als erlaubt.
public struct Tonfaehigkeiten: Equatable, Sendable {
    public var mp3 = false
    public var rtttl = false
    public var song = false
    public var speech = false
    public var radio = false
    public var url = false
    public var effect = false
    public var clip = false
    public var track = false

    public init(mp3: Bool = false, rtttl: Bool = false, song: Bool = false, speech: Bool = false,
                radio: Bool = false, url: Bool = false, effect: Bool = false, clip: Bool = false,
                track: Bool = false) {
        self.mp3 = mp3; self.rtttl = rtttl; self.song = song; self.speech = speech
        self.radio = radio; self.url = url; self.effect = effect; self.clip = clip; self.track = track
    }

    /// Aus dem Objekt `audio` der Fähigkeitenauskunft; ein fehlender Schalter
    /// ist unbekannt und gilt als erlaubt, ein anders getypter als `false`.
    public init(antwort: [String: Any]) {
        func schalter(_ k: String) -> Bool { antwort[k].map { $0 as? Bool == true } ?? true }
        self.init(mp3: schalter("mp3"), rtttl: schalter("rtttl"), song: schalter("song"),
                  speech: schalter("speech"), radio: schalter("radio"), url: schalter("url"),
                  effect: schalter("effect"), clip: schalter("clip"), track: schalter("track"))
    }
}

/// Die Gruppe, die `audio/stop` anhält (§3.2.1).
public enum Tongruppe: String, Equatable, Sendable, CaseIterable {
    /// Benachrichtigungston, Wiedergabe über `audio/play`, Startklang, Voice-Antwort.
    case alarm = "alert"
    /// Klänge von Skripten.
    case app
    case radio

    /// Das Wort der Kommandozeile (`alarm`, `app`, `radio`; `alert` geht auch).
    public init?(wort: String) {
        switch wort.lowercased() {
        case "alarm", "alert": self = .alarm
        case "app": self = .app
        case "radio": self = .radio
        default: return nil
        }
    }
}

/// Ein Klang für `audio/play` oder, ohne `station`, als Benachrichtigungston
/// (`sound`; gemessen: `song` ist dort erlaubt).
public struct Klang: Equatable, Sendable {
    public enum Quelle: Equatable, Sendable {
        /// Gespeicherter Name, `Skript/name` oder `http(s)://`-Adresse.
        case datei(String)
        case rtttl(String)
        case lied(String)
        case sprache(String)
        /// Name oder Stream-Adresse.
        case sender(String)
        /// Listenposition ab 0.
        case senderPosition(Int)

        var schluessel: String {
            switch self {
            case .datei: return "file"
            case .rtttl: return "rtttl"
            case .lied: return "song"
            case .sprache: return "speech"
            case .sender, .senderPosition: return "station"
            }
        }
    }

    public var quelle: Quelle
    public var wiederholen: Bool

    /// RTTTL-Text: höchstens 512 Zeichen. Gleiche Grenze für Dateinamen und
    /// Sendernamen (Annahme: die Doku nennt dort keine eigene).
    public static let textGrenze = 512
    /// Sprechtext: 1–512 Byte (§8).
    public static let sprechGrenze = 512
    /// Song-Text: 16384 Byte (§8).
    public static let liedGrenze = 16384
    /// Eine Liste hält 1–4 Klänge.
    public static let listenbereich = 1...4

    public init(_ quelle: Quelle, wiederholen: Bool = false) {
        self.quelle = quelle
        self.wiederholen = wiederholen
    }

    static func istAdresse(_ wert: String) -> Bool {
        let klein = wert.lowercased()
        return klein.hasPrefix("http://") || klein.hasPrefix("https://")
    }

    /// Genau die Regeln aus §3.2.1 und §8. `faehigkeiten` sind die der Ziel-Uhr;
    /// ohne sie (oder ohne ihre `audio`-Auskunft) bleibt die Fähigkeit ungeprüft.
    public func pruefen(inBenachrichtigung: Bool = false,
                        faehigkeiten: Geraetefaehigkeiten? = nil, listen: Tonlisten? = nil) throws {
        let ton = faehigkeiten?.ton
        func gekonnt(_ ok: (Tonfaehigkeiten) -> Bool, _ name: String) throws {
            if let ton, !ok(ton) { throw KlangFehler.nichtGekonnt(faehigkeit: "audio." + name) }
        }
        func text(_ wert: String, feld: String, grenze: Int, einheit: String, bytes: Bool = false) throws {
            guard !wert.isEmpty else { throw KlangFehler.leer(feld: feld) }
            let laenge = bytes ? wert.utf8.count : wert.count
            guard laenge <= grenze else {
                throw KlangFehler.zuLang(feld: feld, grenze: grenze, einheit: einheit)
            }
        }
        if inBenachrichtigung {
            switch quelle {
            case .sender, .senderPosition:
                throw KlangFehler.nichtInBenachrichtigung(feld: quelle.schluessel)
            default: break
            }
        }
        switch quelle {
        case .datei(let name):
            try text(name, feld: "file", grenze: Self.textGrenze, einheit: lok("Zeichen"))
            if Self.istAdresse(name) {
                try gekonnt(\.url, "url")
            } else {
                let klein = name.lowercased()
                if klein.contains(".mp3") || klein.contains(".txt") { throw KlangFehler.endungImNamen(name) }
                // Ein Name ohne Schrägstrich ist zuerst eine MP3, dann eine Melodie;
                // welche, sagen die `listen` der Uhr (`arten`).
                if let faehigkeiten, ton != nil {
                    let arten = self.arten(listen: listen)
                    if !arten.contains(where: { faehigkeiten.kann($0) }) {
                        throw KlangFehler.nichtGekonnt(faehigkeit: arten == [.melodie] ? "audio.rtttl" : "audio.mp3")
                    }
                }
            }
        case .rtttl(let melodie):
            try text(melodie, feld: "rtttl", grenze: Self.textGrenze, einheit: lok("Zeichen"))
            try Klangbau.melodiePruefen(melodie)
            try gekonnt(\.rtttl, "rtttl")
        case .lied(let lied):
            try text(lied, feld: "song", grenze: Self.liedGrenze, einheit: "Byte", bytes: true)
            try gekonnt(\.song, "song")
        case .sprache(let satz):
            try text(satz, feld: "speech", grenze: Self.sprechGrenze, einheit: "Byte", bytes: true)
            try gekonnt(\.speech, "speech")
        case .sender(let name):
            try text(name, feld: "station", grenze: Self.textGrenze, einheit: lok("Zeichen"))
            try gekonnt(\.radio, "radio")
        case .senderPosition(let n):
            guard n >= 0 else { throw KlangFehler.negativePosition(n) }
            try gekonnt(\.radio, "radio")
        }
        if wiederholen, case .sender = quelle { throw KlangFehler.wiederholenMitSender }
        if wiederholen, case .senderPosition = quelle { throw KlangFehler.wiederholenMitSender }
    }

    /// Die Paare des Objekts: die Quelle, dann `loop` — nur, wenn gewiederholt wird.
    func paare() -> [(String, JSONWert)] {
        var p: [(String, JSONWert)]
        switch quelle {
        case .datei(let s), .rtttl(let s), .lied(let s), .sprache(let s), .sender(let s):
            p = [(quelle.schluessel, .text(s))]
        case .senderPosition(let n):
            p = [(quelle.schluessel, .zahl(Double(n)))]
        }
        if wiederholen { p.append(("loop", .bool(true))) }
        return p
    }

    func objektJSON() -> String { Steuerfarbe.json(paare()) }
}

/// Die Nutzlasten für Klang: `audio/play`, `audio/stop`, `audio/stations`,
/// Melodien und der Ton einer Benachrichtigung.
public enum Klangbau {
    /// Höchstens so viele Sender nimmt die Uhr (§8).
    public static let senderGrenze = 32
    public static let sendernamenGrenze = 24
    public static let senderadresseGrenze = 255
    public static let melodienamenGrenze = 24

    /// RTTTL ist `Name:Einstellungen:Noten`. Mehr prüft die App nicht — die Uhr
    /// weist eine unlesbare Melodie mit `422` ab (§3.2.1).
    static func melodiePruefen(_ text: String) throws {
        let teile = text.split(separator: ":", omittingEmptySubsequences: false)
        guard teile.count == 3, !teile[2].trimmingCharacters(in: .whitespaces).isEmpty else {
            throw KlangFehler.unlesbareMelodie
        }
    }

    /// `audio/play`: ein Klang als Objekt, mehrere (1–4) als Liste.
    public static func spielen(_ klaenge: [Klang], faehigkeiten: Geraetefaehigkeiten? = nil) throws -> String {
        guard Klang.listenbereich.contains(klaenge.count) else {
            throw KlangFehler.ungueltigeAnzahl(klaenge.count)
        }
        for k in klaenge { try k.pruefen(faehigkeiten: faehigkeiten) }
        if klaenge.count == 1 { return klaenge[0].objektJSON() }
        return "[" + klaenge.map { $0.objektJSON() }.joined(separator: ",") + "]"
    }

    /// `audio/stop`: `{"group":…}`; ohne Gruppe `nil`, und das heißt alles
    /// (über MQTT eine leere Nutzlast, über HTTP `{}`).
    public static func stoppen(_ gruppe: Tongruppe?) -> String {
        guard let gruppe else { return "{}" }
        return Steuerfarbe.json([("group", .text(gruppe.rawValue))])
    }

    /// `sound` einer Benachrichtigung (§5.6): ein Name als blanke Zeichenkette,
    /// sonst ein Objekt, mehrere als Liste. Der Wert, nicht das Feld.
    public static func benachrichtigungston(_ klaenge: [Klang],
                                            faehigkeiten: Geraetefaehigkeiten? = nil) throws -> String {
        guard Klang.listenbereich.contains(klaenge.count) else {
            throw KlangFehler.ungueltigeAnzahl(klaenge.count)
        }
        for k in klaenge { try k.pruefen(inBenachrichtigung: true, faehigkeiten: faehigkeiten) }
        if klaenge.count == 1 {
            if case .datei(let name) = klaenge[0].quelle, !klaenge[0].wiederholen {
                return String(decoding: JSONWert.text(name).daten, as: UTF8.self)
            }
            return klaenge[0].objektJSON()
        }
        return "[" + klaenge.map { $0.objektJSON() }.joined(separator: ",") + "]"
    }

    /// `PUT /api/v1/audio/melodies/{name}`: `{"rtttl":…}`.
    public static func melodie(name: String, rtttl: String,
                               faehigkeiten: Geraetefaehigkeiten? = nil) throws -> String {
        try melodienameInOrdnung(name)
        guard !rtttl.isEmpty else { throw KlangFehler.leer(feld: "rtttl") }
        guard rtttl.count <= Klang.textGrenze else {
            throw KlangFehler.zuLang(feld: "rtttl", grenze: Klang.textGrenze, einheit: lok("Zeichen"))
        }
        try melodiePruefen(rtttl)
        if let ton = faehigkeiten?.ton, !ton.rtttl { throw KlangFehler.nichtGekonnt(faehigkeit: "audio.rtttl") }
        return Steuerfarbe.json([("rtttl", .text(rtttl))])
    }

    /// 1–24 Zeichen; die Zeichenmenge ist vorsichtig gewählt (Annahme), weil der
    /// Name im Pfad und als Dateiname steht.
    public static func melodienameInOrdnung(_ name: String) throws {
        let ok = (1...melodienamenGrenze).contains(name.count)
            && name.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
                || ($0 >= 97 && $0 <= 122) || $0 == 95 || $0 == 45 }
        guard ok else { throw KlangFehler.ungueltigerMelodiename(name) }
    }

    /// `PUT /api/v1/audio/stations` bzw. `cmd/audio/stations`: die ganze Liste.
    public static func sender(_ liste: [Radiosender]) throws -> String {
        guard liste.count <= senderGrenze else { throw KlangFehler.zuvieleSender(liste.count) }
        for (i, s) in liste.enumerated() { try s.pruefen(zeile: i + 1) }
        let eintraege = liste.map {
            Steuerfarbe.json([("name", .text($0.name)), ("url", .text($0.url))])
        }
        return #"{"stations":["# + eintraege.joined(separator: ",") + "]}"
    }
}

/// Ein Eintrag der Senderliste: Name und Stream-Adresse (§8).
public struct Radiosender: Equatable, Sendable {
    public var name: String
    public var url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    /// Name 1–24 Zeichen, Adresse höchstens 255 Zeichen mit `http(s)`.
    public func pruefen(zeile: Int) throws {
        guard (1...Klangbau.sendernamenGrenze).contains(name.count) else {
            throw KlangFehler.ungueltigerSender(zeile: zeile, feld: "name")
        }
        guard url.count <= Klangbau.senderadresseGrenze, Klang.istAdresse(url),
              !url.contains(where: \.isWhitespace) else {
            throw KlangFehler.ungueltigerSender(zeile: zeile, feld: "url")
        }
    }
}

/// Was `GET /api/v1/audio` meldet (§7.5).
public struct Tonzustand: Equatable, Sendable {
    public struct Radio: Equatable, Sendable {
        public var spielt = false
        public var sender = ""
        public var titel = ""
        public var fehler = ""
        /// Nur beim laufenden Radio genannt; fehlt eines, bleibt es `nil`.
        public var underruns: Int?
        public var decodeUs: Int?
        public var starvedMs: Int?
        public var bufferBytes: Int?
    }
    /// Die Gruppen `app` und `alert`.
    public struct Wiedergabe: Equatable, Sendable {
        public var spielt = false
        public var name = ""
        public var fehler = ""
    }
    public var radio = Radio()
    public var app = Wiedergabe()
    public var alarm = Wiedergabe()
    public var sender: [Radiosender] = []

    public init() {}

    /// `nil`, wenn keiner der vier Teile darin steht (das war keine Tonauskunft).
    public init?(antwort: [String: Any]) {
        guard ["radio", "app", "alert", "stations"].contains(where: { antwort[$0] != nil }) else { return nil }
        if let r = antwort["radio"] as? [String: Any] {
            radio = Radio(spielt: r["playing"] as? Bool ?? false, sender: r["station"] as? String ?? "",
                          titel: r["title"] as? String ?? "", fehler: r["error"] as? String ?? "",
                          underruns: r["underruns"] as? Int, decodeUs: r["decodeUs"] as? Int,
                          starvedMs: r["starvedMs"] as? Int, bufferBytes: r["bufferBytes"] as? Int)
        }
        func wiedergabe(_ k: String) -> Wiedergabe {
            guard let w = antwort[k] as? [String: Any] else { return Wiedergabe() }
            return Wiedergabe(spielt: w["playing"] as? Bool ?? false, name: w["name"] as? String ?? "",
                              fehler: w["error"] as? String ?? "")
        }
        app = wiedergabe("app")
        alarm = wiedergabe("alert")
        sender = Tonzustand.sender(aus: antwort["stations"])
    }

    static func sender(aus wert: Any?) -> [Radiosender] {
        (wert as? [[String: Any]])?.compactMap { e in
            guard let n = e["name"] as? String, let u = e["url"] as? String else { return nil }
            return Radiosender(name: n, url: u)
        } ?? []
    }
}

/// Die Ablage von Melodien oder MP3-Dateien: Namen und Speicherstand
/// (`GET /api/v1/audio/melodies`, `…/mp3`).
public struct Tonablage: Equatable, Sendable {
    public var namen: [String]
    public var belegteBytes: Int?
    public var gesamteBytes: Int?
    /// Größe je Name in Byte, soweit die Uhr sie nennt (`size` bei MP3-Dateien).
    public var groessen: [String: Int]
    /// Der RTTTL-Text je Melodie, soweit die Uhr ihn nennt (`rtttl` in der
    /// Melodienliste, mit dem von der Uhr umgeschriebenen Namensteil).
    public var texte: [String: String]

    public init(namen: [String], belegteBytes: Int? = nil, gesamteBytes: Int? = nil,
                groessen: [String: Int] = [:], texte: [String: String] = [:]) {
        self.namen = namen; self.belegteBytes = belegteBytes; self.gesamteBytes = gesamteBytes
        self.groessen = groessen; self.texte = texte
    }

    /// Die Doku nennt für die Einträge keine Form (§4); gelesen wird ein Name
    /// als Zeichenkette oder als Objekt mit `name`.
    ///
    /// `endung` wird von den Namen abgezogen: Die MP3-Liste führt `x.mp3`,
    /// während Abspielen und Löschen den Namen ohne Endung brauchen.
    init(antwort: [String: Any], liste: String, endung: String = "") {
        let roh = antwort[liste] as? [Any] ?? []
        func ohneEndung(_ n: String) -> String {
            !endung.isEmpty && n.lowercased().hasSuffix(endung) ? String(n.dropLast(endung.count)) : n
        }
        namen = roh.compactMap { ($0 as? String) ?? (($0 as? [String: Any])?["name"] as? String) }.map(ohneEndung)
        var groessen: [String: Int] = [:]
        var texte: [String: String] = [:]
        for eintrag in roh {
            guard let o = eintrag as? [String: Any], let n = o["name"] as? String else { continue }
            if let g = o["size"] as? Int { groessen[ohneEndung(n)] = g }
            if let t = o["rtttl"] as? String { texte[ohneEndung(n)] = t }
        }
        self.groessen = groessen
        self.texte = texte
        belegteBytes = antwort["usedBytes"] as? Int
        gesamteBytes = antwort["totalBytes"] as? Int
    }
}
