import Foundation

/// Was an einem Layout nicht geht, bevor etwas abgeschickt ist. Die Uhr weist
/// dieselben Fälle mit `422 validationFailed` ab; eine Nutzlast über 8192 Byte
/// verwirft sie über MQTT sogar ohne Antwort (`docs/awtrix-ng-protokoll.md`
/// §8, §9).
public enum LayoutFehler: Error, LocalizedError, Equatable {
    /// Die Uhr hat keine Layouts (`capabilities.layout` fehlt oder ist `false`).
    case nichtUnterstuetzt
    /// Ein Layout ohne Regionen zeigt nichts.
    case keineRegionen
    case zuvieleRegionen(hoechstens: Int)
    case zuvieleLaufschriften(hoechstens: Int)
    case zuvieleIcons(hoechstens: Int)
    case zuvieleWerte(region: String, hoechstens: Int)
    case textZuLang(hoechstens: Int)
    case ungueltigeKennung(String)
    case doppelteKennung(String)
    case kastenAusserhalb(region: String, breite: Int, hoehe: Int)
    /// Ein Feld, das zu dieser Art Inhalt nicht gehört (`color` an einem Icon).
    case feldPasstNicht(region: String, feld: String)
    case diagrammGrenzen(region: String)
    case iconZuGross(region: String, zeichen: Int, hoechstens: Int)
    case zeichnungUngueltig(region: String, grund: String)
    case ungueltigerWert(feld: String, grund: String)
    /// Neben dem Layout stehen Text, Bild, Grafik oder Darstellung des Rahmens.
    case mitAnderemInhalt
    /// In der Datei steht etwas, das die Uhr nicht kennt.
    case unbekannterSchluessel(String)
    case dateiUnlesbar(String)

    public var errorDescription: String? {
        switch self {
        case .nichtUnterstuetzt:
            return lok("Diese Uhr kann keine Layouts. Sie meldet keine Layouts unter ihren Fähigkeiten (die TC001 hat keine).")
        case .keineRegionen:
            return lok("Ein Layout braucht mindestens eine Region.")
        case .zuvieleRegionen(let n):
            return lokf("Ein Layout hat höchstens %d Regionen.", n)
        case .zuvieleLaufschriften(let n):
            return lokf("Höchstens %d Texte eines Layouts dürfen laufen. Die übrigen brauchen „static“.", n)
        case .zuvieleIcons(let n):
            return lokf("Ein Layout hat höchstens %d Icons.", n)
        case .zuvieleWerte(let r, let n):
            return lokf("Das Diagramm der Region „%@“ hat zu viele Werte (höchstens %d).", r, n)
        case .textZuLang(let n):
            return lokf("Der Text eines Layouts ist zusammen höchstens %d Byte lang.", n)
        case .ungueltigeKennung(let k):
            return lokf("„%@“ ist keine Kennung für eine Region: 1 bis 64 Byte.", k)
        case .doppelteKennung(let k):
            return lokf("Die Kennung „%@“ kommt in diesem Layout zweimal vor.", k)
        case .kastenAusserhalb(let r, let b, let h):
            return lokf("Der Kasten der Region „%@“ liegt nicht ganz im Display (%d × %d) oder hat keine Fläche.", r, b, h)
        case .feldPasstNicht(let r, let f):
            return lokf("Das Feld „%@“ gehört nicht zum Inhalt der Region „%@“.", f, r)
        case .diagrammGrenzen(let r):
            return lokf("Das Diagramm der Region „%@“ braucht Werte; „min“ und „max“ stehen nur zusammen, mit min kleiner als max.", r)
        case .iconZuGross(let r, let z, let h):
            return lokf("Das Icon der Region „%@“ ist mit %d Zeichen zu groß (höchstens %d Zeichen Base64 gemessen). Ein kleineres Bild wählen.", r, z, h)
        case .zeichnungUngueltig(let r, let g):
            return lokf("Die Zeichnung der Region „%@“ ist ungültig: %@", r, g)
        case .ungueltigerWert(let f, let g):
            return lokf("Das Feld %@ ist ungültig: %@", f, g)
        case .mitAnderemInhalt:
            return lok("Ein Layout ist eine eigene Anzeige: Text, Bild, Grafik und Darstellung gehören in seine Regionen.")
        case .unbekannterSchluessel(let pfad):
            return lokf("Den Schlüssel „%@“ kennt die Uhr nicht.", pfad)
        case .dateiUnlesbar(let g):
            return lokf("Die Layoutdatei ist nicht lesbar: %@", g)
        }
    }
}

/// Die Grenzen eines Layouts (`docs/awtrix-ng-protokoll.md` §9.5). Die Uhr
/// nennt sie unter `capabilities.layouts.limits`; ohne Auskunft gelten die
/// gemessenen Werte der TC002.
public struct Layoutgrenzen: Equatable, Sendable {
    public var regionen = 16
    public var laufschriften = 8
    public var icons = 4
    public var diagrammwerte = 128
    public var textBytes = 8192

    public init() {}

    /// Aus `layouts.limits`; fehlende oder falsch getypte Felder behalten die Vorgabe.
    init(antwort: [String: Any]) {
        regionen = antwort["regions"] as? Int ?? regionen
        laufschriften = antwort["scrollers"] as? Int ?? laufschriften
        icons = antwort["assets"] as? Int ?? icons
        diagrammwerte = antwort["chartPoints"] as? Int ?? diagrammwerte
        textBytes = antwort["textBytes"] as? Int ?? textBytes
    }

    /// Größtes gemessenes GIF als Data-URL im `icon` einer Region (7508 Zeichen
    /// Base64 angenommen, 8796 abgewiesen; §5.3). Dazwischen ist nichts
    /// gemessen; die App bleibt unter dem Gemessenen.
    public static let iconZeichen = 7508
}

/// Ein Kasten `[x, y, Breite, Höhe]` auf dem vollen Raster der Uhr (§9.1).
public struct Kasten: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var breite: Int
    public var hoehe: Int

    public init(x: Int, y: Int, breite: Int, hoehe: Int) {
        self.x = x; self.y = y; self.breite = breite; self.hoehe = hoehe
    }

    /// Ganz im Display und mit Fläche. Die Uhr weist alles andere mit `422` ab.
    public func liegtIn(_ mass: Anzeigemass) -> Bool {
        x >= 0 && y >= 0 && breite > 0 && hoehe > 0 && x + breite <= mass.breite && y + hoehe <= mass.hoehe
    }

    var json: String { "[\(x),\(y),\(breite),\(hoehe)]" }
}

/// `align` und `valign` einer Region (§9.2).
public enum Layoutausrichtung: String, Equatable, Sendable, CaseIterable {
    case anfang = "start"
    case mitte = "center"
    case ende = "end"
}

/// Ein Zeichenbefehl (§6). Die Farbe darf fehlen: Der Befehl nimmt dann die
/// Farbe der Region.
public enum Zeichenbefehl: Equatable, Sendable {
    /// Die Daten eines `bitmap`: ein Feld aus `Breite × Höhe` Farben oder
    /// Base64 von `Breite × Höhe × 3` rohen RGB-Bytes.
    public enum Bilddaten: Equatable, Sendable {
        case farben([String])
        case rgbBase64(String)
    }

    case pixel(x: Int, y: Int, farbe: String?)
    /// Die Koordinaten flach: `x1, y1, x2, y2, …`.
    case pixels(farbe: String?, koordinaten: [Int])
    case linie(x1: Int, y1: Int, x2: Int, y2: Int, farbe: String?)
    case rahmen(x: Int, y: Int, breite: Int, hoehe: Int, farbe: String?)
    case flaeche(x: Int, y: Int, breite: Int, hoehe: Int, farbe: String?)
    case kreis(x: Int, y: Int, radius: Int, farbe: String?)
    case kreisflaeche(x: Int, y: Int, radius: Int, farbe: String?)
    case text(x: Int, y: Int, text: String, farbe: String?)
    case bild(x: Int, y: Int, breite: Int, hoehe: Int, daten: Bilddaten)

    func pruefen() throws {
        func farbe(_ f: String?) throws { if let f { try Farbwert.pruefen(f, feld: "draw") } }
        switch self {
        case .pixel(_, _, let f), .kreis(_, _, _, let f), .kreisflaeche(_, _, _, let f),
             .text(_, _, _, let f), .linie(_, _, _, _, let f):
            try farbe(f)
        case .rahmen(_, _, _, _, let f), .flaeche(_, _, _, _, let f):
            try farbe(f)
        case .pixels(let f, let k):
            try farbe(f)
            guard k.count % 2 == 0 else {
                throw LayoutFehler.ungueltigerWert(feld: "pixels", grund: lok("gerade Zahl an Koordinaten"))
            }
        case .bild(_, _, let b, let h, let daten):
            guard b > 0, h > 0, b <= 4096, h <= 4096 else {
                throw LayoutFehler.ungueltigerWert(feld: "bitmap", grund: lok("Breite und Höhe über 0"))
            }
            switch daten {
            case .farben(let farben):
                guard farben.count == b * h else {
                    throw LayoutFehler.ungueltigerWert(feld: "bitmap", grund: lok("Breite × Höhe Farben"))
                }
                for f in farben { try Farbwert.pruefen(f, feld: "bitmap") }
            case .rgbBase64(let roh):
                guard let d = Data(base64Encoded: roh), d.count == b * h * 3 else {
                    throw LayoutFehler.ungueltigerWert(feld: "bitmap", grund: lok("Base64 von Breite × Höhe × 3 Byte"))
                }
            }
        }
    }

    var json: String {
        func f(_ farbe: String?) -> String { farbe.map { #","\#($0.uppercased())""# } ?? "" }
        switch self {
        case .pixel(let x, let y, let c): return #"["pixel",\#(x),\#(y)\#(f(c))]"#
        case .pixels(let c, let k):
            return #"["pixels",\#(c.map { #""\#($0.uppercased())""# } ?? "null")\#(k.map { ",\($0)" }.joined())]"#
        case .linie(let a, let b, let c, let d, let col): return #"["line",\#(a),\#(b),\#(c),\#(d)\#(f(col))]"#
        case .rahmen(let x, let y, let b, let h, let c): return #"["rect",\#(x),\#(y),\#(b),\#(h)\#(f(c))]"#
        case .flaeche(let x, let y, let b, let h, let c): return #"["rectFill",\#(x),\#(y),\#(b),\#(h)\#(f(c))]"#
        case .kreis(let x, let y, let r, let c): return #"["circle",\#(x),\#(y),\#(r)\#(f(c))]"#
        case .kreisflaeche(let x, let y, let r, let c): return #"["circleFill",\#(x),\#(y),\#(r)\#(f(c))]"#
        case .text(let x, let y, let t, let c): return #"["text",\#(x),\#(y),"\#(jsonEscape(t))"\#(f(c))]"#
        case .bild(let x, let y, let b, let h, let d):
            let daten: String
            switch d {
            case .farben(let l): daten = "[" + l.map { #""\#($0.uppercased())""# }.joined(separator: ",") + "]"
            case .rgbBase64(let s): daten = #""\#(s)""#
            }
            return #"["bitmap",\#(x),\#(y),\#(b),\#(h),\#(daten)]"#
        }
    }
}

/// Wie ein Text läuft (`scroll`, §5.2). Fehlende Felder nimmt die Uhr aus ihrer
/// globalen Einstellung `scroll`.
public struct Layoutlauf: Equatable, Sendable {
    public static let modi = ["static", "wrap", "loop", "bounce"]
    public static let richtungen = ["left", "right"]
    public static let einlaeufe = ["inline", "offscreen"]
    public static let wennPassend = ["static", "scroll"]

    public var modus: String?
    public var richtung: String?
    public var einlauf: String?
    public var wennPassend: String?
    public var tempo: Int?
    public var haltMs: Int?
    public var abstand: Int?

    public init(modus: String? = nil, richtung: String? = nil, einlauf: String? = nil,
                wennPassend: String? = nil, tempo: Int? = nil, haltMs: Int? = nil, abstand: Int? = nil) {
        self.modus = modus; self.richtung = richtung; self.einlauf = einlauf
        self.wennPassend = wennPassend; self.tempo = tempo; self.haltMs = haltMs; self.abstand = abstand
    }

    /// Ruhender Text.
    public static let ruhend = Layoutlauf(modus: "static")

    func pruefen() throws {
        func wahl(_ w: String?, _ erlaubt: [String], _ feld: String) throws {
            if let w, !erlaubt.contains(w) {
                throw LayoutFehler.ungueltigerWert(feld: "scroll." + feld, grund: erlaubt.joined(separator: ", "))
            }
        }
        try wahl(modus, Self.modi, "mode")
        try wahl(richtung, Self.richtungen, "direction")
        try wahl(einlauf, Self.einlaeufe, "entry")
        try wahl(wennPassend, Self.wennPassend, "whenFits")
        for (w, feld, oben) in [(tempo, "speed", 1_000_000), (haltMs, "holdMs", 1_000_000), (abstand, "gap", 32_767)] {
            if let w, !(0...oben).contains(w) {
                throw LayoutFehler.ungueltigerWert(feld: "scroll." + feld, grund: "0–\(oben)")
            }
        }
    }

    var json: String {
        var t: [String] = []
        if let modus { t.append(#""mode":"\#(modus)""#) }
        if let richtung { t.append(#""direction":"\#(richtung)""#) }
        if let einlauf { t.append(#""entry":"\#(einlauf)""#) }
        if let wennPassend { t.append(#""whenFits":"\#(wennPassend)""#) }
        if let tempo { t.append(#""speed":\#(tempo)"#) }
        if let abstand { t.append(#""gap":\#(abstand)"#) }
        if let haltMs { t.append(#""holdMs":\#(haltMs)"#) }
        return "{" + t.joined(separator: ",") + "}"
    }
}

/// Der Text einer Region (§9.3).
public struct Layouttext: Equatable, Sendable {
    /// Ein eingefärbter Teil (§5.1); ohne Farbe ist er weiß.
    public struct Teil: Equatable, Sendable {
        public var text: String
        public var farbe: String?
        public init(text: String, farbe: String? = nil) { self.text = text; self.farbe = farbe }
    }

    public enum Inhalt: Equatable, Sendable {
        case einfach(String)
        case teile([Teil])
    }

    public var inhalt: Inhalt
    /// `scroll`; `nil` heißt: Die Uhr läuft nach ihrer Einstellung, und der
    /// Text läuft, auch wenn er passt (§9.3).
    public var lauf: Layoutlauf?
    /// `repeat`: wie oft der Text läuft, 0 = die Anzeige wartet nicht auf ihn.
    public var wiederholungen: Int?
    /// `textCase`: `inherit`, `upper`, `asTyped`.
    public var schreibweise: String?
    public var blinkMs: Int?
    public var faedeMs: Int?
    /// `textColor`: Name einer gepushten Anzeige, deren Farbe der Text nimmt.
    public var farbeVonAnzeige: String?

    public static let schreibweisen = ["inherit", "upper", "asTyped"]

    public init(_ text: String, lauf: Layoutlauf? = nil) {
        inhalt = .einfach(text); self.lauf = lauf
    }

    public init(teile: [Teil], lauf: Layoutlauf? = nil) {
        inhalt = .teile(teile); self.lauf = lauf
    }

    /// Läuft der Text? Er tut es, solange er nicht ausdrücklich ruht (§9.3).
    public var laeuft: Bool { lauf?.modus != "static" }

    /// Alle Bytes, die gegen `textBytes` zählen.
    var bytes: Int {
        switch inhalt {
        case .einfach(let t): return t.utf8.count
        case .teile(let l): return l.reduce(0) { $0 + $1.text.utf8.count }
        }
    }

    /// Der Text ohne Färbung.
    public var klartext: String {
        switch inhalt {
        case .einfach(let t): return t
        case .teile(let l): return l.map(\.text).joined()
        }
    }

    func pruefen() throws {
        if case .teile(let l) = inhalt {
            for t in l { if let f = t.farbe { try Farbwert.pruefen(f, feld: "text") } }
        }
        try lauf?.pruefen()
        if let s = schreibweise, !Self.schreibweisen.contains(s) {
            throw LayoutFehler.ungueltigerWert(feld: "textCase", grund: Self.schreibweisen.joined(separator: ", "))
        }
        for (w, feld) in [(blinkMs, "textBlinkMs"), (faedeMs, "textFadeMs"), (wiederholungen, "repeat")] {
            if let w, w < 0 { throw LayoutFehler.ungueltigerWert(feld: feld, grund: "≥ 0") }
        }
        if let a = farbeVonAnzeige, !Anzeigenname.gueltig(a) {
            throw LayoutFehler.ungueltigerWert(feld: "textColor", grund: lok("kein Anzeigenname"))
        }
    }
}

/// Ein Diagramm in einer Region (§9.3).
public struct Layoutdiagramm: Equatable, Sendable {
    public enum Art: String, Equatable, Sendable { case linie = "line", balken = "bar" }

    public var art: Art
    public var werte: [Int]
    /// `min` und `max` stehen nur zusammen; ohne beide skaliert die Uhr selbst.
    public var untergrenze: Int?
    public var obergrenze: Int?

    public init(art: Art, werte: [Int], untergrenze: Int? = nil, obergrenze: Int? = nil) {
        self.art = art; self.werte = werte; self.untergrenze = untergrenze; self.obergrenze = obergrenze
    }

    var json: String {
        var t = [#""values":[\#(werte.map(String.init).joined(separator: ","))]"#, #""type":"\#(art.rawValue)""#]
        if let u = untergrenze, let o = obergrenze { t += [#""min":\#(u)"#, #""max":\#(o)"#] }
        return "{" + t.joined(separator: ",") + "}"
    }
}

/// Genau ein Inhalt je Region (§9.2).
public enum Layoutinhalt: Equatable, Sendable {
    case text(Layouttext)
    /// Kennung, Data-URL oder Webadresse; die Region füllt es.
    case icon(String)
    case diagramm(Layoutdiagramm)
    /// 0–100, füllt von links.
    case fortschritt(Int)
    /// Zeichenbefehle, von der linken oberen Ecke des Kastens gezählt.
    case zeichnung([Zeichenbefehl])
}

/// Eine Region: ein Kasten mit einem Inhalt (`docs/awtrix-ng-protokoll.md` §9.2).
public struct Layoutregion: Equatable, Sendable {
    public var kennung: String
    public var kasten: Kasten
    public var inhalt: Layoutinhalt
    /// `align` / `valign`; Vorgabe der Uhr ist mittig.
    public var waagrecht: Layoutausrichtung?
    public var senkrecht: Layoutausrichtung?
    /// `color` — Text, Fortschritt und Zeichnung; sonst nichts.
    public var farbe: Grafikfarbe?
    /// `font` — Text und Zeichnung; `small`, `large` oder ein Name aus `capabilities.fonts`.
    public var schrift: String?
    public var palette: Palette?
    public var paletteUeberblenden: Bool?
    public var paletteSpanne: Int?
    public var paletteTempo: Double?
    /// `trackColor` — nur Fortschritt; Vorgabe der Uhr `#202020`.
    public var fortschrittsgrund: String?

    public init(kennung: String, kasten: Kasten, inhalt: Layoutinhalt,
                waagrecht: Layoutausrichtung? = nil, senkrecht: Layoutausrichtung? = nil,
                farbe: Grafikfarbe? = nil, schrift: String? = nil, palette: Palette? = nil,
                paletteUeberblenden: Bool? = nil, paletteSpanne: Int? = nil, paletteTempo: Double? = nil,
                fortschrittsgrund: String? = nil) {
        self.kennung = kennung; self.kasten = kasten; self.inhalt = inhalt
        self.waagrecht = waagrecht; self.senkrecht = senkrecht
        self.farbe = farbe; self.schrift = schrift; self.palette = palette
        self.paletteUeberblenden = paletteUeberblenden; self.paletteSpanne = paletteSpanne
        self.paletteTempo = paletteTempo; self.fortschrittsgrund = fortschrittsgrund
    }

    func json(gegen f: Geraetefaehigkeiten?) -> String {
        var t = [#""id":"\#(jsonEscape(kennung))""#, #""box":\#(kasten.json)"#]
        switch inhalt {
        case .text(let x):
            switch x.inhalt {
            case .einfach(let s): t.append(#""text":"\#(jsonEscape(s))""#)
            case .teile(let l):
                t.append(#""text":["# + l.map { teil in
                    #"{"text":"\#(jsonEscape(teil.text))""# + (teil.farbe.map { #","color":"\#($0.uppercased())""# } ?? "") + "}"
                }.joined(separator: ",") + "]")
            }
        case .icon(let s): t.append(#""icon":"\#(jsonEscape(s))""#)
        case .diagramm(let d): t.append(#""chart":\#(d.json)"#)
        case .fortschritt(let p): t.append(#""progress":\#(p)"#)
        case .zeichnung(let b): t.append(#""draw":["# + b.map(\.json).joined(separator: ",") + "]")
        }
        if let waagrecht { t.append(#""align":"\#(waagrecht.rawValue)""#) }
        if let senkrecht { t.append(#""valign":"\#(senkrecht.rawValue)""#) }
        if let schrift { t.append(#""font":"\#(jsonEscape(schrift))""#) }
        if let farbe { t.append(#""color":\#(farbe.json)"#) }
        if let palette { t.append(#""palette":\#(palette.json(gegen: f))"#) }
        if let b = paletteUeberblenden { t.append(#""paletteBlend":\#(b)"#) }
        if let s = paletteSpanne { t.append(#""paletteSpan":\#(s)"#) }
        if let s = paletteTempo { t.append(#""paletteSpeed":\#(s)"#) }
        if case .text(let x) = inhalt {
            if let s = x.lauf { t.append(#""scroll":\#(s.json)"#) }
            if let r = x.wiederholungen { t.append(#""repeat":\#(r)"#) }
            if let s = x.schreibweise { t.append(#""textCase":"\#(s)""#) }
            if let b = x.blinkMs { t.append(#""textBlinkMs":\#(b)"#) }
            if let b = x.faedeMs { t.append(#""textFadeMs":\#(b)"#) }
            if let a = x.farbeVonAnzeige { t.append(#""textColor":"\#(jsonEscape(a))""#) }
        }
        if let g = fortschrittsgrund { t.append(#""trackColor":"\#(g.uppercased())""#) }
        return "{" + t.joined(separator: ",") + "}"
    }
}

/// Ein Layout: Kästen auf dem vollen Raster der Uhr, jeder mit einem Inhalt
/// (`docs/awtrix-ng-protokoll.md` §9). Eine eigene Art Anzeige: Es ersetzt
/// Text, Bild und Grafik des Rahmens (`Frame.layout`), und die Darstellung
/// (Hintergrund, Effekt, Overlay, Palette) gehört auf die Ebene des Layouts.
///
/// Die TC001 (ESP32) hat keine Layouts; ob eine Uhr sie kann, sagt
/// `Geraetefaehigkeiten.layoutUnterstuetzt`, nie der Name oder das Maß.
public struct Kastenlayout: Equatable, Sendable {
    public static let fassung = 1

    public var regionen: [Layoutregion]
    /// `backgroundColor`, `effect`, `effectSpeed`, `overlay`, `palette`,
    /// `paletteBlend`, `paletteSpan`, `paletteSpeed` auf Layout-Ebene.
    /// `textfarbeAusPalette` gibt es hier nicht; die Farbe wählt jede Region.
    public var darstellung: Darstellung

    public init(regionen: [Layoutregion], darstellung: Darstellung = Darstellung()) {
        self.regionen = regionen; self.darstellung = darstellung
    }

    /// Wie viele Texte laufen.
    public var laufschriften: Int {
        regionen.filter { if case .text(let t) = $0.inhalt { return t.laeuft } else { return false } }.count
    }

    public var iconzahl: Int {
        regionen.filter { if case .icon = $0.inhalt { return true } else { return false } }.count
    }

    /// Prüft gegen die Grenzen der Uhr und ihr Anzeigemaß. Ohne `faehigkeiten`
    /// gelten die gemessenen Grenzen der TC002, und ob die Uhr Layouts kann,
    /// bleibt offen.
    public func pruefen(mass: Anzeigemass = .vorgabe, faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        if faehigkeiten?.layoutUnterstuetzt == false { throw LayoutFehler.nichtUnterstuetzt }
        let grenzen = faehigkeiten?.layoutGrenzen ?? Layoutgrenzen()
        guard !regionen.isEmpty else { throw LayoutFehler.keineRegionen }
        guard regionen.count <= grenzen.regionen else {
            throw LayoutFehler.zuvieleRegionen(hoechstens: grenzen.regionen)
        }
        guard laufschriften <= grenzen.laufschriften else {
            throw LayoutFehler.zuvieleLaufschriften(hoechstens: grenzen.laufschriften)
        }
        guard iconzahl <= grenzen.icons else { throw LayoutFehler.zuvieleIcons(hoechstens: grenzen.icons) }

        try darstellung.pruefen(gegen: faehigkeiten)
        if darstellung.textfarbeAusPalette {
            throw LayoutFehler.ungueltigerWert(feld: "textColor", grund: lok("gehört in die Region"))
        }

        var gesehen = Set<String>()
        var textBytes = 0
        for r in regionen {
            guard (1...64).contains(r.kennung.utf8.count) else { throw LayoutFehler.ungueltigeKennung(r.kennung) }
            guard gesehen.insert(r.kennung).inserted else { throw LayoutFehler.doppelteKennung(r.kennung) }
            guard r.kasten.liegtIn(mass) else {
                throw LayoutFehler.kastenAusserhalb(region: r.kennung, breite: mass.breite, hoehe: mass.hoehe)
            }
            try pruefen(r, grenzen: grenzen, faehigkeiten: faehigkeiten)
            if case .text(let t) = r.inhalt { textBytes += t.bytes }
        }
        guard textBytes <= grenzen.textBytes else { throw LayoutFehler.textZuLang(hoechstens: grenzen.textBytes) }
    }

    private func pruefen(_ r: Layoutregion, grenzen: Layoutgrenzen, faehigkeiten: Geraetefaehigkeiten?) throws {
        func passt(_ feld: String, _ gesetzt: Bool, wenn ok: Bool) throws {
            if gesetzt && !ok { throw LayoutFehler.feldPasstNicht(region: r.kennung, feld: feld) }
        }
        var istText = false, istIcon = false, istFortschritt = false, istZeichnung = false
        switch r.inhalt {
        case .text(let t): istText = true; try t.pruefen()
        case .icon(let s):
            istIcon = true
            if s.isEmpty { throw LayoutFehler.ungueltigerWert(feld: "icon", grund: lok("leer")) }
            if s.hasPrefix("data:") {
                _ = try NGNutzlast.icon(ausDatenURI: s)
                let zeichen = s.utf8.count - (s.firstIndex(of: ",").map { s.distance(from: s.startIndex, to: $0) + 1 } ?? 0)
                guard zeichen <= Layoutgrenzen.iconZeichen else {
                    throw LayoutFehler.iconZuGross(region: r.kennung, zeichen: zeichen,
                                                   hoechstens: Layoutgrenzen.iconZeichen)
                }
            }
        case .diagramm(let d):
            guard d.werte.count <= grenzen.diagrammwerte else {
                throw LayoutFehler.zuvieleWerte(region: r.kennung, hoechstens: grenzen.diagrammwerte)
            }
            // ❓ §9.3 nennt keine Mindestzahl; eine leere Liste zeichnet nichts.
            guard !d.werte.isEmpty, (d.untergrenze == nil) == (d.obergrenze == nil),
                  (d.untergrenze ?? 0) < (d.obergrenze ?? 1) else {
                throw LayoutFehler.diagrammGrenzen(region: r.kennung)
            }
        case .fortschritt(let p):
            istFortschritt = true
            guard (0...100).contains(p) else { throw LayoutFehler.ungueltigerWert(feld: "progress", grund: "0–100") }
        case .zeichnung(let befehle):
            istZeichnung = true
            do { for b in befehle { try b.pruefen() } } catch let f as LayoutFehler {
                throw LayoutFehler.zeichnungUngueltig(region: r.kennung, grund: f.errorDescription ?? "")
            } catch let f as DarstellungsFehler {
                throw LayoutFehler.zeichnungUngueltig(region: r.kennung, grund: f.errorDescription ?? "")
            }
        }
        try passt("align/valign", r.waagrecht != nil || r.senkrecht != nil, wenn: istText || istIcon)
        try passt("color", r.farbe != nil, wenn: istText || istFortschritt || istZeichnung)
        try passt("font", r.schrift != nil, wenn: istText || istZeichnung)
        try passt("palette", r.palette != nil || r.paletteUeberblenden != nil
                  || r.paletteSpanne != nil || r.paletteTempo != nil, wenn: istText || istFortschritt)
        try passt("trackColor", r.fortschrittsgrund != nil, wenn: istFortschritt)

        let palette = r.palette ?? darstellung.palette
        try r.farbe?.pruefen(feld: "color", palette: palette)
        try r.palette?.pruefen(gegen: faehigkeiten)
        if r.palette == nil, r.paletteUeberblenden != nil || r.paletteSpanne != nil || r.paletteTempo != nil {
            throw DarstellungsFehler.paletteFehlt(feld: "palette")
        }
        if let s = r.paletteSpanne, s < 0 { throw DarstellungsFehler.ausserhalb(feld: "paletteSpan", bereich: "≥ 0") }
        if let t = r.paletteTempo, !(t.isFinite && (0.0...10.0).contains(t)) {
            throw DarstellungsFehler.ausserhalb(feld: "paletteSpeed", bereich: "0–10")
        }
        if let g = r.fortschrittsgrund { try Farbwert.pruefen(g, feld: "trackColor") }
    }

    /// Der Block `layout` als JSON-Objekt. Geprüft wird getrennt (`pruefen`).
    func json(gegen f: Geraetefaehigkeiten? = nil) -> String {
        let regionen = self.regionen.map { $0.json(gegen: f) }.joined(separator: ",")
        let felder = darstellung.felder(gegen: f)
        return #"{"version":\#(Self.fassung),"regions":[\#(regionen)]"# + felder.map { "," + $0 }.joined() + "}"
    }

    /// In einem Satz, für das Protokoll.
    public var beschreibung: String {
        lokf("Layout · %d Regionen", regionen.count)
    }
}
