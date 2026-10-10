import Foundation

/// Ein Layout aus einer JSON-Datei, mit genau den Schlüsseln der Geräteauskunft
/// (`docs/awtrix-ng-protokoll.md` §9). Die Datei ist entweder der Block
/// `layout` selbst (`{"version":1,"regions":[…]}`) oder die Nutzlast einer
/// Anzeige, `{"layout":{…},"durationMs":10000}`. Neben `layout` nimmt die App
/// nur `durationMs` in ganzen Sekunden; Lebensdauer und Ablauf stehen als
/// Optionen am Werkzeug.
///
/// Gelesen wird streng: Ein Schlüssel, den die Uhr nicht kennt, ist ein Fehler
/// mit Pfad, statt still zu fehlen. Farben nur als `#RRGGBB` (oder `"palette"`),
/// die einzige Form, die diese App sendet.
public struct Layoutdatei: Equatable, Sendable {
    public var layout: Kastenlayout
    /// `durationMs` in Sekunden.
    public var dauer: Int?

    public static func lesen(_ daten: Data) throws -> Layoutdatei {
        guard let wert = JSONWert.lesen(daten) else { throw LayoutFehler.dateiUnlesbar(lok("kein JSON")) }
        guard case .objekt(let o) = wert else { throw LayoutFehler.dateiUnlesbar(lok("kein Objekt")) }
        if o["regions"] != nil {
            return Layoutdatei(layout: try Layoutleser.layout(o, pfad: "layout"), dauer: nil)
        }
        var dauer: Int?
        for k in o.keys.sorted() where !["layout", "durationMs"].contains(k) {
            throw LayoutFehler.unbekannterSchluessel(k)
        }
        if let d = o["durationMs"] {
            guard let ms = d.ganzzahl, ms > 0, ms % 1000 == 0 else {
                throw LayoutFehler.ungueltigerWert(feld: "durationMs", grund: lok("ganze Sekunden, in Millisekunden"))
            }
            dauer = ms / 1000
        }
        guard case .objekt(let l)? = o["layout"] else { throw LayoutFehler.dateiUnlesbar(lok("„layout“ fehlt")) }
        return Layoutdatei(layout: try Layoutleser.layout(l, pfad: "layout"), dauer: dauer)
    }

    public static func lesen(datei: URL) throws -> Layoutdatei {
        guard let daten = try? Data(contentsOf: datei) else {
            throw LayoutFehler.dateiUnlesbar(lokf("%@ lässt sich nicht öffnen", datei.lastPathComponent))
        }
        return try lesen(daten)
    }
}

private enum Layoutleser {
    typealias Objekt = [String: JSONWert]

    static func nurSchluessel(_ o: Objekt, _ erlaubt: Set<String>, pfad: String) throws {
        if let k = o.keys.sorted().first(where: { !erlaubt.contains($0) }) {
            throw LayoutFehler.unbekannterSchluessel(pfad + "." + k)
        }
    }

    static func falsch(_ pfad: String, _ grund: String) -> LayoutFehler {
        .ungueltigerWert(feld: pfad, grund: grund)
    }

    static func text(_ w: JSONWert?, _ pfad: String) throws -> String? {
        guard let w else { return nil }
        guard case .text(let s) = w else { throw falsch(pfad, lok("Text erwartet")) }
        return s
    }

    static func zahl(_ w: JSONWert?, _ pfad: String) throws -> Int? {
        guard let w else { return nil }
        guard let i = w.ganzzahl else { throw falsch(pfad, lok("ganze Zahl erwartet")) }
        return i
    }

    static func kommazahl(_ w: JSONWert?, _ pfad: String) throws -> Double? {
        guard let w else { return nil }
        guard case .zahl(let d) = w else { throw falsch(pfad, lok("Zahl erwartet")) }
        return d
    }

    static func wahrheit(_ w: JSONWert?, _ pfad: String) throws -> Bool? {
        guard let w else { return nil }
        guard case .bool(let b) = w else { throw falsch(pfad, lok("true oder false erwartet")) }
        return b
    }

    static func farbe(_ w: JSONWert?, _ pfad: String) throws -> String? {
        guard let s = try text(w, pfad) else { return nil }
        try Farbwert.pruefen(s, feld: pfad)
        return s
    }

    static func grafikfarbe(_ w: JSONWert?, _ pfad: String) throws -> Grafikfarbe? {
        guard let s = try text(w, pfad) else { return nil }
        return s == "palette" ? .palette : .farbe(try farbe(.text(s), pfad)!)
    }

    static func palette(_ w: JSONWert?, _ pfad: String) throws -> Palette? {
        guard let w, w != .null else { return nil }
        switch w {
        case .text(let n): return .name(n)
        case .liste(let l):
            if l.allSatisfy({ if case .text = $0 { return true } else { return false } }) {
                return .farben(try l.map { try farbe($0, pfad)! })
            }
            return .stellen(try l.map { e in
                guard case .objekt(let o) = e else { throw falsch(pfad, lok("Farben oder {color, pos}")) }
                try nurSchluessel(o, ["color", "pos"], pfad: pfad)
                guard let f = try farbe(o["color"], pfad + ".color"), let p = try zahl(o["pos"], pfad + ".pos") else {
                    throw falsch(pfad, lok("color und pos"))
                }
                return Palette.Stuetzstelle(farbe: f, pos: p)
            })
        default: throw falsch(pfad, lok("Name oder Liste"))
        }
    }

    static let layoutSchluessel: Set<String> = [
        "version", "regions", "backgroundColor", "effect", "effectSpeed", "overlay",
        "palette", "paletteBlend", "paletteSpan", "paletteSpeed"]

    static func layout(_ o: Objekt, pfad: String) throws -> Kastenlayout {
        try nurSchluessel(o, layoutSchluessel, pfad: pfad)
        if let v = o["version"], v.ganzzahl != Kastenlayout.fassung {
            throw falsch(pfad + ".version", lokf("nur Fassung %d", Kastenlayout.fassung))
        }
        guard case .liste(let rohe)? = o["regions"] else { throw falsch(pfad + ".regions", lok("Liste erwartet")) }
        var regionen: [Layoutregion] = []
        for (i, r) in rohe.enumerated() {
            guard case .objekt(let ro) = r else { throw falsch("\(pfad).regions[\(i)]", lok("Objekt erwartet")) }
            regionen.append(try region(ro, pfad: "\(pfad).regions[\(i)]"))
        }
        var d = Darstellung()
        d.hintergrundfarbe = try farbe(o["backgroundColor"], pfad + ".backgroundColor")
        d.effekt = try text(o["effect"], pfad + ".effect")
        d.effektTempo = try kommazahl(o["effectSpeed"], pfad + ".effectSpeed")
        d.overlay = try text(o["overlay"], pfad + ".overlay")
        d.palette = try palette(o["palette"], pfad + ".palette")
        d.paletteUeberblenden = try wahrheit(o["paletteBlend"], pfad + ".paletteBlend")
        d.paletteSpanne = try zahl(o["paletteSpan"], pfad + ".paletteSpan")
        d.paletteTempo = try kommazahl(o["paletteSpeed"], pfad + ".paletteSpeed")
        return Kastenlayout(regionen: regionen, darstellung: d)
    }

    static let inhaltsschluessel = ["text", "icon", "chart", "progress", "draw"]
    static let regionSchluessel: Set<String> = [
        "id", "box", "text", "icon", "chart", "progress", "draw", "align", "valign", "font", "color",
        "palette", "paletteBlend", "paletteSpan", "paletteSpeed", "textColor", "scroll", "repeat",
        "textCase", "textBlinkMs", "textFadeMs", "trackColor"]

    static func region(_ o: Objekt, pfad: String) throws -> Layoutregion {
        try nurSchluessel(o, regionSchluessel, pfad: pfad)
        guard let kennung = try text(o["id"], pfad + ".id") else { throw falsch(pfad + ".id", lok("fehlt")) }
        guard case .liste(let k)? = o["box"], k.count == 4, let z = Optional(k.compactMap(\.ganzzahl)), z.count == 4 else {
            throw falsch(pfad + ".box", lok("vier ganze Zahlen [x, y, Breite, Höhe]"))
        }
        let vorhanden = inhaltsschluessel.filter { o[$0] != nil }
        guard vorhanden.count == 1, let art = vorhanden.first else {
            throw falsch(pfad, lok("genau einer von text, icon, chart, progress, draw"))
        }
        let inhalt: Layoutinhalt
        switch art {
        case "text": inhalt = .text(try layouttext(o, pfad: pfad))
        case "icon":
            guard let s = try text(o["icon"], pfad + ".icon") else { throw falsch(pfad + ".icon", lok("fehlt")) }
            inhalt = .icon(s)
        case "chart": inhalt = .diagramm(try diagramm(o["chart"]!, pfad: pfad + ".chart"))
        case "progress":
            guard let p = try zahl(o["progress"], pfad + ".progress") else { throw falsch(pfad + ".progress", lok("fehlt")) }
            inhalt = .fortschritt(p)
        default:
            guard case .liste(let b)? = o["draw"] else { throw falsch(pfad + ".draw", lok("Liste erwartet")) }
            inhalt = .zeichnung(try b.enumerated().map { try zeichenbefehl($1, pfad: "\(pfad).draw[\($0)]") })
        }
        func ausrichtung(_ s: String) throws -> Layoutausrichtung? {
            guard let w = try text(o[s], pfad + "." + s) else { return nil }
            guard let a = Layoutausrichtung(rawValue: w) else { throw falsch(pfad + "." + s, "start, center, end") }
            return a
        }
        return Layoutregion(
            kennung: kennung, kasten: Kasten(x: z[0], y: z[1], breite: z[2], hoehe: z[3]), inhalt: inhalt,
            waagrecht: try ausrichtung("align"), senkrecht: try ausrichtung("valign"),
            farbe: try grafikfarbe(o["color"], pfad + ".color"), schrift: try text(o["font"], pfad + ".font"),
            palette: try palette(o["palette"], pfad + ".palette"),
            paletteUeberblenden: try wahrheit(o["paletteBlend"], pfad + ".paletteBlend"),
            paletteSpanne: try zahl(o["paletteSpan"], pfad + ".paletteSpan"),
            paletteTempo: try kommazahl(o["paletteSpeed"], pfad + ".paletteSpeed"),
            fortschrittsgrund: try farbe(o["trackColor"], pfad + ".trackColor"))
    }

    static func layouttext(_ o: Objekt, pfad: String) throws -> Layouttext {
        var t: Layouttext
        switch o["text"]! {
        case .text(let s): t = Layouttext(s)
        case .liste(let l):
            t = Layouttext(teile: try l.enumerated().map { i, e in
                guard case .objekt(let to) = e else { throw falsch("\(pfad).text[\(i)]", lok("Objekt erwartet")) }
                try nurSchluessel(to, ["text", "color"], pfad: "\(pfad).text[\(i)]")
                return Layouttext.Teil(text: try text(to["text"], "\(pfad).text[\(i)].text") ?? "",
                                       farbe: try farbe(to["color"], "\(pfad).text[\(i)].color"))
            })
        default: throw falsch(pfad + ".text", lok("Text oder Liste erwartet"))
        }
        switch o["scroll"] {
        case nil: break
        case .text(let m)?: t.lauf = Layoutlauf(modus: m)
        case .objekt(let so)?:
            try nurSchluessel(so, ["mode", "direction", "entry", "whenFits", "speed", "gap", "holdMs"],
                              pfad: pfad + ".scroll")
            t.lauf = Layoutlauf(modus: try text(so["mode"], pfad + ".scroll.mode"),
                                richtung: try text(so["direction"], pfad + ".scroll.direction"),
                                einlauf: try text(so["entry"], pfad + ".scroll.entry"),
                                wennPassend: try text(so["whenFits"], pfad + ".scroll.whenFits"),
                                tempo: try zahl(so["speed"], pfad + ".scroll.speed"),
                                haltMs: try zahl(so["holdMs"], pfad + ".scroll.holdMs"),
                                abstand: try zahl(so["gap"], pfad + ".scroll.gap"))
        default: throw falsch(pfad + ".scroll", lok("Modus oder Objekt erwartet"))
        }
        t.wiederholungen = try zahl(o["repeat"], pfad + ".repeat")
        t.schreibweise = try text(o["textCase"], pfad + ".textCase")
        t.blinkMs = try zahl(o["textBlinkMs"], pfad + ".textBlinkMs")
        t.faedeMs = try zahl(o["textFadeMs"], pfad + ".textFadeMs")
        t.farbeVonAnzeige = try text(o["textColor"], pfad + ".textColor")
        return t
    }

    static func diagramm(_ w: JSONWert, pfad: String) throws -> Layoutdiagramm {
        guard case .objekt(let o) = w else { throw falsch(pfad, lok("Objekt erwartet")) }
        try nurSchluessel(o, ["values", "type", "min", "max"], pfad: pfad)
        guard case .liste(let l)? = o["values"], l.allSatisfy({ $0.ganzzahl != nil }) else {
            throw falsch(pfad + ".values", lok("Liste ganzer Zahlen"))
        }
        guard let art = Layoutdiagramm.Art(rawValue: try text(o["type"], pfad + ".type") ?? "") else {
            throw falsch(pfad + ".type", "line, bar")
        }
        return Layoutdiagramm(art: art, werte: l.compactMap(\.ganzzahl),
                              untergrenze: try zahl(o["min"], pfad + ".min"),
                              obergrenze: try zahl(o["max"], pfad + ".max"))
    }

    static func zeichenbefehl(_ w: JSONWert, pfad: String) throws -> Zeichenbefehl {
        guard case .liste(let l) = w, case .text(let name)? = l.first else {
            throw falsch(pfad, lok("[Befehl, Argumente …]"))
        }
        let a = Array(l.dropFirst())
        func i(_ n: Int) throws -> Int {
            guard a.indices.contains(n), let z = a[n].ganzzahl else { throw falsch(pfad, lok("ganze Zahl erwartet")) }
            return z
        }
        func f(_ n: Int, ab erwartet: Int) throws -> String? {
            guard a.count >= erwartet, a.count <= erwartet + 1 else { throw falsch(pfad, lok("falsche Zahl an Argumenten")) }
            return a.count == erwartet + 1 ? try farbe(a[n], pfad) : nil
        }
        switch name {
        case "pixel": return .pixel(x: try i(0), y: try i(1), farbe: try f(2, ab: 2))
        case "pixels":
            guard let erstes = a.first else { throw falsch(pfad, lok("Farbe zuerst")) }
            return .pixels(farbe: erstes == .null ? nil : try farbe(erstes, pfad),
                           koordinaten: try a.indices.dropFirst().map { try i($0) })
        case "line": return .linie(x1: try i(0), y1: try i(1), x2: try i(2), y2: try i(3), farbe: try f(4, ab: 4))
        case "rect": return .rahmen(x: try i(0), y: try i(1), breite: try i(2), hoehe: try i(3), farbe: try f(4, ab: 4))
        case "rectFill": return .flaeche(x: try i(0), y: try i(1), breite: try i(2), hoehe: try i(3), farbe: try f(4, ab: 4))
        case "circle": return .kreis(x: try i(0), y: try i(1), radius: try i(2), farbe: try f(3, ab: 3))
        case "circleFill": return .kreisflaeche(x: try i(0), y: try i(1), radius: try i(2), farbe: try f(3, ab: 3))
        case "text":
            guard a.count >= 3, a.count <= 4, case .text(let t) = a[2] else { throw falsch(pfad, lok("x, y, Text, Farbe")) }
            return .text(x: try i(0), y: try i(1), text: t, farbe: a.count == 4 ? try farbe(a[3], pfad) : nil)
        case "bitmap":
            guard a.count == 5 else { throw falsch(pfad, lok("genau sechs Argumente")) }
            switch a[4] {
            case .text(let s):
                return .bild(x: try i(0), y: try i(1), breite: try i(2), hoehe: try i(3), daten: .rgbBase64(s))
            case .liste(let farben):
                return .bild(x: try i(0), y: try i(1), breite: try i(2), hoehe: try i(3),
                             daten: .farben(try farben.map { try farbe($0, pfad)! }))
            default: throw falsch(pfad, lok("Farben oder Base64"))
            }
        default: throw falsch(pfad, lokf("unbekannter Befehl „%@“", name))
        }
    }
}
