import Foundation

/// Was bei einer Darstellung nicht geht, bevor etwas abgeschickt ist. Die Uhr
/// würde dieselben Fälle mit `422 validationFailed` abweisen oder — bei einem
/// verdeckten Hintergrund — still nichts zeigen (`docs/awtrix-ng-protokoll.md`
/// §5.3, §5.5, §5.8).
public enum DarstellungsFehler: Error, LocalizedError, Equatable {
    /// Keine Farbe der Form `#RRGGBB`.
    case keineFarbe(feld: String, wert: String)
    /// Eine Zahl außerhalb ihres Bereichs.
    case ausserhalb(feld: String, bereich: String)
    /// Ein Name, den die Uhr nicht kennt (`capabilities`).
    case unbekannterName(feld: String, name: String)
    /// Hintergrundfarbe und Effekt zugleich: bei gesetztem `effect` übergangen.
    case farbeUndEffekt
    /// Eine Palettenfarbe (`"palette"`) ohne Palette.
    case paletteFehlt(feld: String)
    /// Die Palette selbst ist falsch gebaut (leer, über 16 Stützstellen, `pos` fehlt).
    case paletteUngueltig(grund: String)
    /// Ein Bild in voller Anzeigegröße ersetzt Hintergrundfarbe und Effekt (§5.3).
    case vomBildVerdeckt(feld: String)
    /// Ein Diagramm oder Fortschritt hat weder Text noch Bild neben sich.
    case grafikMitInhalt
    /// Weder Diagramm noch Fortschritt.
    case grafikLeer
    /// Liniendiagramm mit weniger als zwei Werten.
    case zuWenigeWerte
    /// `textColor: "palette"` ohne Text von der Uhr.
    case ohneText

    public var errorDescription: String? {
        switch self {
        case .keineFarbe(let feld, let wert):
            return lokf("„%@“ ist im Feld %@ keine Farbe der Form #RRGGBB.", wert, feld)
        case .ausserhalb(let feld, let bereich):
            return lokf("Das Feld %@ erwartet einen Wert im Bereich %@.", feld, bereich)
        case .unbekannterName(let feld, let name):
            return lokf("Die Uhr kennt für %@ keinen Namen „%@“. Die Liste der Uhr zeigt, was möglich ist.", feld, name)
        case .farbeUndEffekt:
            return lok("Hintergrundfarbe und Effekt schließen sich aus: Mit einem Effekt wird die Farbe übergangen.")
        case .paletteFehlt(let feld):
            return lokf("%@ nimmt die Farben der Palette, aber es ist keine Palette gewählt.", feld)
        case .paletteUngueltig(let grund):
            return lokf("Die Palette ist ungültig: %@", grund)
        case .vomBildVerdeckt(let feld):
            return lokf("%@ wäre nicht zu sehen: Ein Bild in der Größe der Anzeige deckt den Hintergrund ganz zu. Ohne Bild senden oder %@ weglassen.", feld, feld)
        case .grafikMitInhalt:
            return lok("Ein Diagramm oder Fortschritt ist eine eigene Anzeige und hat weder Text noch Bild.")
        case .grafikLeer:
            return lok("Es gibt nichts zu zeichnen: weder ein Diagramm noch einen Fortschritt.")
        case .zuWenigeWerte:
            return lok("Ein Liniendiagramm braucht mindestens zwei Werte.")
        case .ohneText:
            return lok("Es gibt keinen Text, den die Palette malen könnte.")
        }
    }
}

/// Eine Farbe der Form `#RRGGBB` — die einzige Form, die diese App sendet. Die
/// Uhr nähme fünf (§1.4); eine zu senden genügt.
enum Farbwert {
    static func gueltig(_ s: String) -> Bool {
        s.count == 7 && s.hasPrefix("#") && s.dropFirst().allSatisfy(\.isHexDigit)
    }

    static func pruefen(_ s: String, feld: String) throws {
        guard gueltig(s) else { throw DarstellungsFehler.keineFarbe(feld: feld, wert: s) }
    }
}

/// Die Palette einer Anzeige (`palette`, §5.5).
public enum Palette: Equatable, Sendable {
    /// Ein Name aus `capabilities.palettes`.
    case name(String)
    /// 1 bis 16 Farben, gleichmäßig verteilt.
    case farben([String])
    /// 1 bis 16 Stützstellen mit Lage `pos` 0–100.
    case stellen([Stuetzstelle])

    public struct Stuetzstelle: Equatable, Sendable {
        public var farbe: String
        public var pos: Int
        public init(farbe: String, pos: Int) {
            self.farbe = farbe
            self.pos = pos
        }
    }

    public static let hoechstzahlStellen = 16

    func pruefen(gegen f: Geraetefaehigkeiten?) throws {
        switch self {
        case .name(let n):
            guard !n.isEmpty else { throw DarstellungsFehler.paletteUngueltig(grund: lok("leerer Name")) }
            // Eine Datei `/PALETTES/<name>.txt` auf der Uhr kennt die Liste
            // womöglich nicht (❓, §5.5): Ist die Liste leer, wird nicht geprüft.
            if let f, !f.paletten.isEmpty, Geraetefaehigkeiten.aufgeloest(n, in: f.paletten) == nil {
                throw DarstellungsFehler.unbekannterName(feld: "palette", name: n)
            }
        case .farben(let farben):
            guard (1...Self.hoechstzahlStellen).contains(farben.count) else {
                throw DarstellungsFehler.paletteUngueltig(grund: lok("1 bis 16 Farben"))
            }
            for farbe in farben { try Farbwert.pruefen(farbe, feld: "palette") }
        case .stellen(let stellen):
            guard (1...Self.hoechstzahlStellen).contains(stellen.count) else {
                throw DarstellungsFehler.paletteUngueltig(grund: lok("1 bis 16 Stützstellen"))
            }
            for s in stellen {
                try Farbwert.pruefen(s.farbe, feld: "palette")
                guard (0...100).contains(s.pos) else {
                    throw DarstellungsFehler.ausserhalb(feld: "palette.pos", bereich: "0–100")
                }
            }
        }
    }

    /// Der JSON-Wert, ohne Schlüssel. Ein Name wird in der Schreibweise der
    /// Uhr gesendet, wenn die Liste bekannt ist.
    func json(gegen f: Geraetefaehigkeiten?) -> String {
        switch self {
        case .name(let n):
            let genau = f.flatMap { Geraetefaehigkeiten.aufgeloest(n, in: $0.paletten) } ?? n
            return #""\#(jsonEscape(genau))""#
        case .farben(let farben):
            return "[" + farben.map { #""\#($0.uppercased())""# }.joined(separator: ",") + "]"
        case .stellen(let stellen):
            return "[" + stellen.map { #"{"color":"\#($0.farbe.uppercased())","pos":\#($0.pos)}"# }
                .joined(separator: ",") + "]"
        }
    }
}

/// Die Farbe von Diagramm und Fortschritt: eine einfache Farbe oder
/// `"palette"` (aus der Palette der Anzeige gemalt, §5.5).
public enum Grafikfarbe: Equatable, Sendable {
    case farbe(String)
    case palette

    func pruefen(feld: String, palette: Palette?) throws {
        switch self {
        case .farbe(let f): try Farbwert.pruefen(f, feld: feld)
        // ❓ §5.5 sagt nur für `textColor` ausdrücklich „bei gesetzter
        // `palette`“. Für Diagramm und Fortschritt gilt hier dieselbe Annahme:
        // Ohne Palette gibt es nichts zu malen, und die Uhr zeigte etwas
        // Unbestimmtes.
        case .palette: if palette == nil { throw DarstellungsFehler.paletteFehlt(feld: feld) }
        }
    }

    var json: String {
        switch self {
        case .farbe(let f): return #""\#(f.uppercased())""#
        case .palette: return #""palette""#
        }
    }
}

/// Hintergrund, Effekt, Overlay und Palette einer Anzeige oder Benachrichtigung
/// (`docs/awtrix-ng-protokoll.md` §5.5). Alles ist freiwillig: Was nicht gesetzt
/// ist, wird nicht gesendet, und die Uhr nimmt ihre Vorgabe — die Anzeige wird
/// ohnehin ganz ersetzt.
///
/// Wie das mit dem Inhalt zusammengeht (`Frame`):
///
/// - **Text von der Uhr gesetzt** (`herkunft`): alles gilt. Die Palette malt den
///   Text nur, wenn `textfarbeAusPalette` gesetzt ist (`textColor: "palette"`).
/// - **Gerasterter Text oder Bild** (`pixel`, ein GIF in voller Anzeigegröße im
///   `icon`): das GIF gilt als Hintergrund und ersetzt `backgroundColor` und jeden
///   `effect` (§5.3). Beide würden still nichts bewirken, darum weist
///   `Anzeigen.grundnutzlast` sie ab (`DarstellungsFehler.vomBildVerdeckt`). Ein
///   `overlay` liegt über allem und geht, samt Tempo und Palette, die Overlays
///   nutzen (§5.5). Ein Text zum Malen aus der Palette fehlt (`ohneText`).
/// - **Diagramm oder Fortschritt** (`Grafikinhalt`): eigene Anzeige ohne Text und
///   Bild; Hintergrund, Effekt, Overlay und Palette gelten.
public struct Darstellung: Equatable, Sendable {
    /// `backgroundColor`: einfarbige Füllung, bei gesetztem Effekt übergangen.
    public var hintergrundfarbe: String?
    /// `effect`: ein Name aus `capabilities.effects`.
    public var effekt: String?
    /// `effectSpeed`, 0.1–10.0 (die Uhr klemmt Werte außerhalb; hier ist es ein
    /// Fehler, damit nichts anderes läuft als gewählt). Tempo von Effekt und Overlay.
    public var effektTempo: Double?
    /// `overlay`: ein Name aus `capabilities.overlays` (`rain`, `snow`, …).
    public var overlay: String?
    public var palette: Palette?
    /// `paletteBlend`; die Uhr überblendet standardmäßig.
    public var paletteUeberblenden: Bool?
    /// `paletteSpan` in Pixeln je Durchlauf beim Malen von Text, 0 = dehnen.
    public var paletteSpanne: Int?
    /// `paletteSpeed`, 0.0–10.0, Durchläufe je Sekunde beim Malen von Text.
    public var paletteTempo: Double?
    /// `textColor: "palette"`: der Text der Uhr wird aus der Palette gemalt;
    /// `textBlinkMs` und `textFadeMs` gelten dann nicht (§5.1). Nur mit Text
    /// von der Uhr.
    public var textfarbeAusPalette = false

    public init(hintergrundfarbe: String? = nil, effekt: String? = nil, effektTempo: Double? = nil,
                overlay: String? = nil, palette: Palette? = nil, paletteUeberblenden: Bool? = nil,
                paletteSpanne: Int? = nil, paletteTempo: Double? = nil,
                textfarbeAusPalette: Bool = false) {
        self.hintergrundfarbe = hintergrundfarbe
        self.effekt = effekt
        self.effektTempo = effektTempo
        self.overlay = overlay
        self.palette = palette
        self.paletteUeberblenden = paletteUeberblenden
        self.paletteSpanne = paletteSpanne
        self.paletteTempo = paletteTempo
        self.textfarbeAusPalette = textfarbeAusPalette
    }

    public var istLeer: Bool { self == Darstellung() }

    /// Ob ein Palettenfeld gesetzt ist, das ohne Palette nichts bewirkt.
    private var palettenfeldGesetzt: Bool {
        paletteUeberblenden != nil || paletteSpanne != nil || paletteTempo != nil
    }

    /// Prüft Bereiche, Farben und Formen; mit `faehigkeiten` auch die Namen
    /// gegen die Listen der Uhr. Ohne sie bleiben nur die Namen ungeprüft.
    public func pruefen(gegen faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        if let h = hintergrundfarbe { try Farbwert.pruefen(h, feld: "backgroundColor") }
        if let e = effekt, !e.isEmpty {
            if hintergrundfarbe != nil { throw DarstellungsFehler.farbeUndEffekt }
            if let f = faehigkeiten, Geraetefaehigkeiten.aufgeloest(e, in: f.effekte) == nil {
                throw DarstellungsFehler.unbekannterName(feld: "effect", name: e)
            }
        }
        if let t = effektTempo {
            guard t.isFinite, (0.1...10.0).contains(t) else {
                throw DarstellungsFehler.ausserhalb(feld: "effectSpeed", bereich: "0.1–10")
            }
        }
        if let o = overlay, !o.isEmpty, let f = faehigkeiten,
           Geraetefaehigkeiten.aufgeloest(o, in: f.overlays) == nil {
            throw DarstellungsFehler.unbekannterName(feld: "overlay", name: o)
        }
        try palette?.pruefen(gegen: faehigkeiten)
        if let s = paletteSpanne, s < 0 {
            throw DarstellungsFehler.ausserhalb(feld: "paletteSpan", bereich: "≥ 0")
        }
        if let t = paletteTempo {
            guard t.isFinite, (0.0...10.0).contains(t) else {
                throw DarstellungsFehler.ausserhalb(feld: "paletteSpeed", bereich: "0–10")
            }
        }
        if palette == nil, palettenfeldGesetzt || textfarbeAusPalette {
            throw DarstellungsFehler.paletteFehlt(feld: textfarbeAusPalette ? "textColor" : "palette")
        }
    }

    /// Die Felder als JSON-Schlüssel-Wert-Paare, in fester Reihenfolge. Ein Name
    /// wird mit der Schreibweise der Uhr gesendet, wenn deren Liste bekannt ist.
    func felder(gegen f: Geraetefaehigkeiten? = nil) -> [String] {
        var teile: [String] = []
        if let h = hintergrundfarbe { teile.append(#""backgroundColor":"\#(h.uppercased())""#) }
        if let e = effekt {
            let genau = f.flatMap { Geraetefaehigkeiten.aufgeloest(e, in: $0.effekte) } ?? e
            teile.append(#""effect":"\#(jsonEscape(genau))""#)
        }
        if let t = effektTempo { teile.append(#""effectSpeed":\#(t)"#) }
        if let o = overlay {
            let genau = f.flatMap { Geraetefaehigkeiten.aufgeloest(o, in: $0.overlays) } ?? o
            teile.append(#""overlay":"\#(jsonEscape(genau))""#)
        }
        if let p = palette { teile.append(#""palette":\#(p.json(gegen: f))"#) }
        if let b = paletteUeberblenden { teile.append(#""paletteBlend":\#(b)"#) }
        if let s = paletteSpanne { teile.append(#""paletteSpan":\#(s)"#) }
        if let t = paletteTempo { teile.append(#""paletteSpeed":\#(t)"#) }
        return teile
    }

    /// In einem Satz, für das Protokoll.
    public var beschreibung: String {
        var teile: [String] = []
        if hintergrundfarbe != nil { teile.append(lok("Hintergrund")) }
        if let e = effekt, !e.isEmpty { teile.append(e) }
        if let o = overlay, !o.isEmpty { teile.append(o) }
        if palette != nil { teile.append(lok("Palette")) }
        return teile.joined(separator: " · ")
    }
}

/// Ein Diagramm und/oder ein Fortschrittsbalken als eigene Anzeige — ohne Text,
/// ohne Icon (`docs/awtrix-ng-protokoll.md` §5.5).
///
/// Warum eine eigene Art Inhalt und nicht Zusatzfelder am Text: Die Uhr malt
/// Diagramme und Balken zwar neben Text (`textInFront`), aber alles Gerasterte
/// geht als GIF in `icon` und ein GIF in Anzeigegröße deckt Diagramm und Balken
/// zu — oder ein schmaleres rückt sie ein (§1.2). Ein Rahmen ist darum entweder
/// Text/Bild oder Grafik (`Frame`), nie beides.
public struct Grafikinhalt: Equatable, Sendable {
    public enum Diagramm: Equatable, Sendable {
        /// `barChart`: wächst von der Nulllinie, negative Werte hängen darunter.
        case balken([Int])
        /// `lineChart`: mindestens zwei Werte.
        case linie([Int])

        public var werte: [Int] {
            switch self {
            case .balken(let w), .linie(let w): return w
            }
        }
    }

    /// Höchstens 16 Werte (§5.5, §8). Mehr fielen auf der Uhr still weg; hier
    /// ist es ein Fehler.
    public static let hoechstzahlWerte = 16

    public var diagramm: Diagramm?
    /// `chartAutoscale`; die Uhr skaliert standardmäßig selbst. `false` ist
    /// fest 0–8, Werte darüber werden abgeschnitten.
    public var diagrammSkalieren: Bool?
    /// `chartColor`; ohne Angabe die Textfarbe der Uhr.
    public var diagrammfarbe: Grafikfarbe?
    /// `progress` in Prozent (0–100); in der untersten Zeile. `nil` = aus.
    public var fortschritt: Int?
    /// `progressColor`; die Uhr nimmt `#00FF00`.
    public var fortschrittsfarbe: Grafikfarbe?
    /// `progressTrackColor`, immer eine einfache Farbe; die Uhr nimmt `#FFFFFF`.
    public var fortschrittsgrund: String?

    public init(diagramm: Diagramm? = nil, diagrammSkalieren: Bool? = nil,
                diagrammfarbe: Grafikfarbe? = nil, fortschritt: Int? = nil,
                fortschrittsfarbe: Grafikfarbe? = nil, fortschrittsgrund: String? = nil) {
        self.diagramm = diagramm
        self.diagrammSkalieren = diagrammSkalieren
        self.diagrammfarbe = diagrammfarbe
        self.fortschritt = fortschritt
        self.fortschrittsfarbe = fortschrittsfarbe
        self.fortschrittsgrund = fortschrittsgrund
    }

    /// `palette` ist die Palette der Darstellung, falls eine Farbe daraus malen soll.
    public func pruefen(palette: Palette?) throws {
        guard diagramm != nil || fortschritt != nil else { throw DarstellungsFehler.grafikLeer }
        if let d = diagramm {
            guard d.werte.count <= Self.hoechstzahlWerte else {
                throw DarstellungsFehler.ausserhalb(feld: "barChart/lineChart", bereich: "≤ 16 Werte")
            }
            if case .linie(let w) = d, w.count < 2 { throw DarstellungsFehler.zuWenigeWerte }
            if case .balken(let w) = d, w.isEmpty { throw DarstellungsFehler.grafikLeer }
        }
        try diagrammfarbe?.pruefen(feld: "chartColor", palette: palette)
        if let p = fortschritt {
            // §5.5: unter 0 = aus, über 100 zählt als 100 — als Wahl gibt es
            // nur 0–100; „aus“ ist `nil`.
            guard (0...100).contains(p) else {
                throw DarstellungsFehler.ausserhalb(feld: "progress", bereich: "0–100")
            }
        }
        try fortschrittsfarbe?.pruefen(feld: "progressColor", palette: palette)
        if let g = fortschrittsgrund { try Farbwert.pruefen(g, feld: "progressTrackColor") }
    }

    func felder() -> [String] {
        var teile: [String] = []
        switch diagramm {
        case .balken(let w)?: teile.append(#""barChart":\#(w)"#)
        case .linie(let w)?: teile.append(#""lineChart":\#(w)"#)
        case nil: break
        }
        if let s = diagrammSkalieren { teile.append(#""chartAutoscale":\#(s)"#) }
        if let f = diagrammfarbe { teile.append(#""chartColor":\#(f.json)"#) }
        if let p = fortschritt { teile.append(#""progress":\#(p)"#) }
        if let f = fortschrittsfarbe { teile.append(#""progressColor":\#(f.json)"#) }
        if let g = fortschrittsgrund { teile.append(#""progressTrackColor":"\#(g.uppercased())""#) }
        return teile
    }
}
