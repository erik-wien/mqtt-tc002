import Foundation

/// Die Themen, in die die Einstellungen der Uhr gegliedert sind
/// (`docs/awtrix-ng-protokoll.md` §10).
public enum Einstellungsgruppe: String, CaseIterable, Sendable {
    case helligkeitFarbe, text, schleife, uhr, zeitDatum, wochentagsleiste, klang, tasten
}

/// Wie ein Wert aussieht, den die Uhr annimmt.
public indirect enum Einstellungsart: Equatable, Sendable {
    case wahrheit
    case ganzzahl(ClosedRange<Int>)
    /// Eine Zahl größer als 0 (`gamma`).
    case zahlUeberNull
    /// `#RRGGBB`, nie `null`.
    case farbe
    case farbeOderNull
    /// Eine feste Liste von Wörtern, genau so geschrieben.
    case auswahl([String])
    /// Ein Name aus `capabilities.transitions`, Groß-/Kleinschreibung gleich.
    case uebergang
    /// Ein Name aus `capabilities.clockFaces`.
    case zifferblatt
    /// Eine Liste englischer Wochentagsnamen (`weekendDays`).
    case wochentage
    case objekt([String: Einstellungsart])

    static let wochentagsnamen = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    public static let zifferblaetter = ["sheet", "ring", "flap", "month", "big"]
    /// „int ≥ 0“ nennt die Doku ohne Obergrenze; was ein `int32` fasst, nimmt die App an.
    static let nichtNegativ = 0...Int(Int32.max)

    /// Prüft `wert` und gibt ihn in der Schreibweise zurück, die gesendet wird
    /// (Farben groß, Übergangsnamen wie in der Liste der Uhr).
    func pruefen(_ wert: JSONWert, feld: String, faehigkeiten: Geraetefaehigkeiten?) throws -> JSONWert {
        func falsch(_ erwartet: String) -> SteuerungsFehler {
            .falscheArt(feld: feld, wert: Self.kurz(wert), erwartet: erwartet)
        }
        switch self {
        case .wahrheit:
            guard case .bool = wert else { throw falsch(lok("Ja oder Nein")) }
            return wert
        case .ganzzahl(let bereich):
            guard let n = wert.ganzzahl else { throw falsch(lok("eine ganze Zahl")) }
            try Steuerfarbe.ganzzahl(n, bereich, feld: feld)
            return wert
        case .zahlUeberNull:
            guard case .zahl(let d) = wert, d.isFinite else { throw falsch(lok("eine Zahl")) }
            guard d > 0 else {
                throw SteuerungsFehler.ausserhalb(feld: feld, wert: Self.kurz(wert), bereich: lok("größer als 0"))
            }
            return wert
        case .farbe:
            guard case .text(let t) = wert else { throw falsch("#RRGGBB") }
            return .text(try Steuerfarbe.pruefen(t, feld: feld))
        case .farbeOderNull:
            if wert == .null { return wert }
            guard case .text(let t) = wert else { throw falsch("#RRGGBB") }
            return .text(try Steuerfarbe.pruefen(t, feld: feld))
        case .auswahl(let liste):
            guard case .text(let t) = wert else { throw falsch(liste.joined(separator: ", ")) }
            guard liste.contains(t) else { throw SteuerungsFehler.unbekannterName(feld: feld, wert: t) }
            return wert
        case .uebergang:
            guard case .text(let t) = wert else { throw falsch(lok("ein Name")) }
            guard let liste = faehigkeiten?.uebergaenge, !liste.isEmpty else { return wert }
            guard let name = Geraetefaehigkeiten.aufgeloest(t, in: liste) else {
                throw SteuerungsFehler.unbekannterName(feld: feld, wert: t)
            }
            return .text(name)
        case .zifferblatt:
            guard case .text(let t) = wert else { throw falsch(lok("ein Name")) }
            let bekannte = faehigkeiten?.zifferblaetter.isEmpty == false
                ? faehigkeiten!.zifferblaetter : Self.zifferblaetter
            guard bekannte.contains(t) else { throw SteuerungsFehler.unbekannterName(feld: feld, wert: t) }
            return wert
        case .wochentage:
            guard case .liste(let teile) = wert else { throw falsch(lok("eine Liste von Wochentagen")) }
            for teil in teile {
                guard case .text(let t) = teil else { throw falsch(lok("eine Liste von Wochentagen")) }
                guard Self.wochentagsnamen.contains(t) else {
                    throw SteuerungsFehler.unbekannterName(feld: feld, wert: t)
                }
            }
            return wert
        case .objekt(let felder):
            guard case .objekt(let o) = wert else { throw falsch(lok("ein Objekt")) }
            var ergebnis: [String: JSONWert] = [:]
            for (schluessel, teil) in o {
                guard let art = felder[schluessel] else {
                    throw SteuerungsFehler.unbekannteEinstellung(feld + "." + schluessel)
                }
                ergebnis[schluessel] = try art.pruefen(teil, feld: feld + "." + schluessel, faehigkeiten: faehigkeiten)
            }
            return .objekt(ergebnis)
        }
    }

    /// Macht aus einem Wort der Kommandozeile den Wert, noch ungeprüft gegen den
    /// Bereich. Ein Objekt gibt es hier nicht: Es wird über seine Felder gesetzt
    /// (`scroll.speed`).
    func wert(aus text: String, feld: String) throws -> JSONWert {
        let klein = text.lowercased()
        switch self {
        case .wahrheit:
            if ["ein", "an", "ja", "true", "on", "yes", "1"].contains(klein) { return .bool(true) }
            if ["aus", "nein", "false", "off", "no", "0"].contains(klein) { return .bool(false) }
            throw SteuerungsFehler.falscheArt(feld: feld, wert: text, erwartet: lok("ein/aus"))
        case .ganzzahl:
            guard let n = Int(text) else {
                throw SteuerungsFehler.falscheArt(feld: feld, wert: text, erwartet: lok("eine ganze Zahl"))
            }
            return .zahl(Double(n))
        case .zahlUeberNull:
            guard let d = Double(text.replacingOccurrences(of: ",", with: ".")) else {
                throw SteuerungsFehler.falscheArt(feld: feld, wert: text, erwartet: lok("eine Zahl"))
            }
            return .zahl(d)
        case .farbe:
            return .text(text)
        case .farbeOderNull:
            return ["aus", "off", "null", "-"].contains(klein) ? .null : .text(text)
        case .auswahl, .uebergang, .zifferblatt:
            return .text(text)
        case .wochentage:
            if ["keine", "none", "-", ""].contains(klein) { return .liste([]) }
            return .liste(klein.split(separator: ",").map { .text($0.trimmingCharacters(in: .whitespaces)) })
        case .objekt:
            throw SteuerungsFehler.falscheArt(feld: feld, wert: text, erwartet: lok("ein Unterfeld wie scroll.speed"))
        }
    }

    /// Kurz und lesbar, für Meldungen.
    static func kurz(_ wert: JSONWert) -> String {
        switch wert {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .zahl(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
        case .text(let t): return t
        case .liste, .objekt: return String(decoding: wert.daten, as: UTF8.self)
        }
    }
}

/// Die Anzeigeeinstellungen der Uhr, die diese App liest und schreibt
/// (`GET`/`PATCH /api/v1/settings`, MQTT `cmd/settings`, §10), gegliedert nach
/// den Gruppen der Steuerungsseite.
///
/// **Nie hier und nie geschrieben:** `enlargeApps` (alle Bilder werden für das
/// Anzeigemaß gerechnet; der Schlüssel ist lesbar, aber gesperrt), alles der
/// Systemkonfiguration (WLAN, MQTT-Zugang, Firmware, Zugang …) und die Schlüssel,
/// die laut Doku ohne Wirkung sind (`autoBrightness`, `timeMode`,
/// `dateWeekdayBar`, Fühler-Apps).
public enum Geraeteeinstellung: String, CaseIterable, Sendable, Hashable {
    case brightness, saturation, gamma, colorCorrection, colorTint
    case textColor, uppercase, scroll, enlargeApps
    case autoTransition, appDurationMs, transitionEffect, transitionDirection, transitionDurationMs
    case clockFace, timeColor, calendarHeaderColor, calendarTextColor, calendarBodyColor, calendarAnimation
    case time24h, timeLeadingZero, timeShowSeconds, timeShowAmPm, timeSeparatorMode
    case dateOrder, dateSeparator, dateYearMode, dateShowWeekday, dateMonthNames, dateColor
    case weekdayBar
    case volume, radioVolume, appVolume, alertVolume, bootSound, musicSource
    case blockNavigation

    /// `false` nur für `enlargeApps`.
    public var schreibbar: Bool { self != .enlargeApps }

    public var gruppe: Einstellungsgruppe {
        switch self {
        case .brightness, .saturation, .gamma, .colorCorrection, .colorTint: return .helligkeitFarbe
        case .textColor, .uppercase, .scroll, .enlargeApps: return .text
        case .autoTransition, .appDurationMs, .transitionEffect, .transitionDirection,
             .transitionDurationMs: return .schleife
        case .clockFace, .timeColor, .calendarHeaderColor, .calendarTextColor, .calendarBodyColor,
             .calendarAnimation: return .uhr
        case .time24h, .timeLeadingZero, .timeShowSeconds, .timeShowAmPm, .timeSeparatorMode,
             .dateOrder, .dateSeparator, .dateYearMode, .dateShowWeekday, .dateMonthNames,
             .dateColor: return .zeitDatum
        case .weekdayBar: return .wochentagsleiste
        case .volume, .radioVolume, .appVolume, .alertVolume, .bootSound, .musicSource: return .klang
        case .blockNavigation: return .tasten
        }
    }

    static let wochentagsleiste: Einstellungsart = .objekt([
        "show": .wahrheit, "startOnMonday": .wahrheit, "weekendDays": .wochentage,
        "activeColor": .farbe, "inactiveColor": .farbe,
        "weekendActiveColor": .farbe, "weekendInactiveColor": .farbe,
    ])

    static let lauftext: Einstellungsart = .objekt([
        "mode": .auswahl(["static", "wrap", "loop", "bounce"]),
        "direction": .auswahl(["left", "right"]),
        "entry": .auswahl(["inline", "offscreen"]),
        "whenFits": .auswahl(["static", "scroll"]),
        "speed": .ganzzahl(Einstellungsart.nichtNegativ),
        "gap": .ganzzahl(Einstellungsart.nichtNegativ),
        "holdMs": .ganzzahl(Einstellungsart.nichtNegativ),
    ])

    /// Der Bereich und die Art, wie in §10 angegeben.
    public var art: Einstellungsart {
        switch self {
        case .brightness: return .ganzzahl(0...255)
        case .saturation: return .ganzzahl(0...100)
        case .gamma: return .zahlUeberNull
        case .colorCorrection, .colorTint, .timeColor, .dateColor: return .farbeOderNull
        case .textColor, .calendarHeaderColor, .calendarTextColor, .calendarBodyColor: return .farbe
        case .uppercase, .enlargeApps, .autoTransition, .calendarAnimation, .time24h, .timeLeadingZero,
             .timeShowSeconds, .timeShowAmPm, .dateShowWeekday, .dateMonthNames, .bootSound,
             .blockNavigation: return .wahrheit
        case .scroll: return Self.lauftext
        case .appDurationMs: return .ganzzahl(Einstellungsart.nichtNegativ)
        case .transitionEffect: return .uebergang
        case .transitionDirection: return .auswahl(["normal", "reverse"])
        case .transitionDurationMs: return .ganzzahl(0...2147483647)
        case .clockFace: return .zifferblatt
        case .timeSeparatorMode: return .auswahl(["steady", "blink", "pulse"])
        case .dateOrder: return .auswahl(["dayMonthYear", "monthDayYear", "yearMonthDay"])
        case .dateSeparator: return .auswahl(["dot", "slash", "dash"])
        case .dateYearMode: return .auswahl(["none", "twoDigit", "fourDigit"])
        case .weekdayBar: return Self.wochentagsleiste
        case .volume, .radioVolume, .appVolume, .alertVolume: return .ganzzahl(0...100)
        case .musicSource: return .auswahl(["auto", "playback", "microphone"])
        }
    }
}

/// Der Laufschrift-Block der globalen Einstellungen (`scroll`, §5.2, §10).
public struct Lauftext: Equatable, Sendable {
    public var mode: String, direction: String, entry: String, whenFits: String
    public var speed: Int, gap: Int, holdMs: Int

    init?(_ wert: JSONWert?) {
        guard case .objekt(let o)? = wert,
              case .text(let m)? = o["mode"], case .text(let d)? = o["direction"],
              case .text(let e)? = o["entry"], case .text(let w)? = o["whenFits"],
              let s = o["speed"]?.ganzzahl, let g = o["gap"]?.ganzzahl, let h = o["holdMs"]?.ganzzahl
        else { return nil }
        mode = m; direction = d; entry = e; whenFits = w; speed = s; gap = g; holdMs = h
    }
}

/// Die Wochentagsleiste (`weekdayBar`, §10); `dateWeekdayBar` ist ohne Wirkung
/// und kommt nicht vor.
public struct Wochentagsleiste: Equatable, Sendable {
    public var show: Bool, startOnMonday: Bool
    public var weekendDays: [String]
    public var activeColor: String, inactiveColor: String
    public var weekendActiveColor: String, weekendInactiveColor: String

    init?(_ wert: JSONWert?) {
        guard case .objekt(let o)? = wert,
              case .bool(let s)? = o["show"], case .bool(let m)? = o["startOnMonday"],
              case .liste(let tage)? = o["weekendDays"],
              case .text(let a)? = o["activeColor"], case .text(let i)? = o["inactiveColor"],
              case .text(let wa)? = o["weekendActiveColor"], case .text(let wi)? = o["weekendInactiveColor"]
        else { return nil }
        show = s; startOnMonday = m; activeColor = a; inactiveColor = i
        weekendActiveColor = wa; weekendInactiveColor = wi
        weekendDays = tage.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
    }
}

/// Was die Uhr als Einstellungen meldet (`GET /api/v1/settings` und
/// `<P>/state/settings`, dieselbe Form), soweit diese App sie kennt.
public struct Geraeteeinstellungen: Equatable, Sendable {
    public enum Fehler: Error, LocalizedError, Equatable {
        case unlesbar
        public var errorDescription: String? { lok("Die Uhr hat keine lesbaren Einstellungen geliefert.") }
    }

    public private(set) var werte: [Geraeteeinstellung: JSONWert]
    /// Wie viele Schlüssel die Uhr insgesamt meldete (gemessen: 46); die übrigen
    /// kennt diese App nicht oder schreibt sie nie.
    public let schluesselinsgesamt: Int

    public init(werte: [Geraeteeinstellung: JSONWert] = [:], schluesselinsgesamt: Int? = nil) {
        self.werte = werte
        self.schluesselinsgesamt = schluesselinsgesamt ?? werte.count
    }

    public init(daten: Data) throws {
        guard case .objekt(let o)? = JSONWert.lesen(daten) else { throw Fehler.unlesbar }
        var w: [Geraeteeinstellung: JSONWert] = [:]
        for e in Geraeteeinstellung.allCases { if let v = o[e.rawValue] { w[e] = v } }
        self.init(werte: w, schluesselinsgesamt: o.count)
    }

    public subscript(_ e: Geraeteeinstellung) -> JSONWert? { werte[e] }

    public func ganzzahl(_ e: Geraeteeinstellung) -> Int? { werte[e]?.ganzzahl }
    public func wahrheit(_ e: Geraeteeinstellung) -> Bool? {
        if case .bool(let b)? = werte[e] { return b }
        return nil
    }
    public func text(_ e: Geraeteeinstellung) -> String? {
        if case .text(let t)? = werte[e] { return t }
        return nil
    }
    public var lauftext: Lauftext? { Lauftext(werte[.scroll]) }
    public var wochentagsleiste: Wochentagsleiste? { Wochentagsleiste(werte[.weekdayBar]) }

    /// Die Werte einer Gruppe in der Reihenfolge der Einstellungen, als Text.
    public func zeilen(in gruppe: Einstellungsgruppe) -> [(schluessel: String, wert: String)] {
        Geraeteeinstellung.allCases.filter { $0.gruppe == gruppe }.compactMap { e in
            werte[e].map { (e.rawValue, Einstellungsart.kurz($0)) }
        }
    }

    /// Eine Änderung aus Schlüssel und Wort (Kommandozeile). `scroll.speed` und
    /// `weekdayBar.show` setzen ein Unterfeld; weil die Doku nicht sagt, ob die
    /// Uhr verschachtelte Objekte beim `PATCH` zusammenführt (❓), geht das
    /// ganze Objekt hinaus, mit dem gelesenen Stand darunter.
    public func aenderung(schluessel: String, wert text: String,
                          faehigkeiten: Geraetefaehigkeiten? = nil) throws -> Einstellungsaenderung {
        let teile = schluessel.split(separator: ".", maxSplits: 1).map(String.init)
        guard let kopf = teile.first, let e = Geraeteeinstellung(rawValue: kopf) else {
            throw SteuerungsFehler.unbekannteEinstellung(schluessel)
        }
        guard e.schreibbar else { throw SteuerungsFehler.gesperrteEinstellung(kopf) }
        var a = Einstellungsaenderung()
        guard teile.count == 2 else {
            try a.setzen(e, try e.art.wert(aus: text, feld: schluessel), faehigkeiten: faehigkeiten)
            return a
        }
        guard case .objekt(let felder) = e.art, let art = felder[teile[1]] else {
            throw SteuerungsFehler.unbekannteEinstellung(schluessel)
        }
        guard case .objekt(var o)? = werte[e] else {
            throw SteuerungsFehler.falscheArt(feld: kopf, wert: "—", erwartet: lok("ein gelesener Stand"))
        }
        o[teile[1]] = try art.wert(aus: text, feld: schluessel)
        try a.setzen(e, .objekt(o), faehigkeiten: faehigkeiten)
        return a
    }
}

/// Eine Teilmenge von Einstellungen, geprüft und bereit für `PATCH`.
public struct Einstellungsaenderung: Equatable, Sendable {
    public private(set) var werte: [Geraeteeinstellung: JSONWert] = [:]

    public init() {}

    public var istLeer: Bool { werte.isEmpty }

    /// Prüft `wert` gegen Art und Bereich dieses Schlüssels und merkt ihn.
    public mutating func setzen(_ e: Geraeteeinstellung, _ wert: JSONWert,
                                faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        guard e.schreibbar else { throw SteuerungsFehler.gesperrteEinstellung(e.rawValue) }
        werte[e] = try e.art.pruefen(wert, feld: e.rawValue, faehigkeiten: faehigkeiten)
    }

    /// Nur die gesetzten Schlüssel, alphabetisch (damit Tests byteweise prüfen).
    public func json() throws -> String {
        guard !werte.isEmpty else { throw SteuerungsFehler.nichtsAngegeben }
        let paare = werte.sorted { $0.key.rawValue < $1.key.rawValue }.map { ($0.key.rawValue, $0.value) }
        return Steuerfarbe.json(paare)
    }
}
