import Foundation

/// Welche Palette gewählt ist: keine, eine der Uhr mit Namen, oder die eigene.
public enum Palettenwahl: Hashable, Sendable, Codable {
    case keine
    case name(String)
    case eigene
}

/// Die eigene Palette der Oberfläche: 1 bis 16 Farben, entweder gleichmäßig
/// verteilt oder mit einer Lage 0–100 je Stütze. Gemischt geht nicht (`Palette`),
/// darum gilt `mitPosition` für die ganze Palette.
public struct Eigenepalette: Hashable, Sendable, Codable {
    public struct Stelle: Hashable, Sendable, Codable {
        public var farbe: String
        public var pos: Int
        public init(farbe: String, pos: Int) {
            self.farbe = farbe
            self.pos = pos
        }
    }

    public static let hoechstzahl = Palette.hoechstzahlStellen

    public var stellen: [Stelle]
    public var mitPosition: Bool

    /// Rot, Gelb, Blau: drei Farben, die sich auf der Uhr deutlich trennen.
    public init(stellen: [Stelle] = [Stelle(farbe: "#FF0000", pos: 0),
                                     Stelle(farbe: "#FFFF00", pos: 50),
                                     Stelle(farbe: "#0000FF", pos: 100)],
                mitPosition: Bool = false) {
        self.stellen = stellen
        self.mitPosition = mitPosition
    }

    /// Gleichmäßige Lagen für `n` Stützen von 0 bis 100.
    public static func gleichmaessigeLagen(_ n: Int) -> [Int] {
        guard n > 1 else { return [0] }
        return (0..<n).map { Int((Double($0) * 100 / Double(n - 1)).rounded()) }
    }

    /// Eine Stütze mehr, ans Ende gesetzt (bis 16). Bei Lage steht sie bei 100;
    /// die Lagen der übrigen bleiben, wie sie sind.
    public mutating func hinzufuegen(farbe: String = "#FFFFFF") {
        guard stellen.count < Self.hoechstzahl else { return }
        stellen.append(Stelle(farbe: farbe, pos: 100))
    }

    /// Die letzte Stütze weg; eine bleibt immer.
    public mutating func entfernen() {
        guard stellen.count > 1 else { return }
        stellen.removeLast()
    }

    /// Beim Umschalten auf „gleichmäßig" die Lagen neu verteilen, damit das,
    /// was die Oberfläche zeigt, mit dem übereinstimmt, was später bei
    /// „mit Position" steht.
    public mutating func gleichmaessigVerteilen() {
        let lagen = Self.gleichmaessigeLagen(stellen.count)
        for i in stellen.indices { stellen[i].pos = lagen[i] }
    }

    public var palette: Palette {
        mitPosition
            ? .stellen(stellen.map { Palette.Stuetzstelle(farbe: $0.farbe, pos: $0.pos) })
            : .farben(stellen.map(\.farbe))
    }
}

/// Alles, was der Reiter „Darstellung" einstellt, als ein Wert: Er wird
/// gespeichert (`@AppStorage` als JSON), mit dem Platz gemerkt
/// (`Meldungsoptionen.darstellung`) und zu einer `Darstellung` für den Rahmen
/// gemacht. Welche Regler dabei gelten, sagt `Darstellungsregeln`; was gesperrt
/// ist, geht nie hinaus.
public struct Darstellungswahl: Hashable, Sendable, Codable {
    /// Schwarz heißt: keine Hintergrundfarbe. Die Uhr zeigt ohnehin Schwarz, und
    /// ein Farbkreis kennt kein „aus".
    public static let keinHintergrund = "#000000"

    public var hintergrundfarbe = Darstellungswahl.keinHintergrund
    /// Ein Name aus `capabilities.effects`; `nil` heißt „Keiner".
    public var effekt: String?
    /// `effectSpeed`, 0.1–10; für Effekt und Overlay.
    public var tempo = 1.0
    /// Ein Name aus `capabilities.overlays`; `nil` heißt „Keines".
    public var overlay: String?
    public var palette = Palettenwahl.keine
    public var eigenePalette = Eigenepalette()
    /// `paletteBlend`; die Uhr überblendet ohne Angabe.
    public var ueberblenden = true
    /// `textColor: "palette"`.
    public var textAusPalette = false
    /// `paletteSpan` in Pixeln, 0 = dehnen.
    public var spanne = 0
    /// `paletteSpeed`, 0–10, 0 = Stillstand.
    public var lauf = 0.0

    public static let tempobereich = 0.1...10.0
    public static let laufbereich = 0.0...10.0
    public static let hoechstspanne = 128

    public init() {}

    // Von Hand und nachsichtig: Die Wahl liegt in Dateien, die auch eine ältere
    // oder neuere Fassung auf einem anderen Gerät liest. Ein fehlendes Feld
    // heißt Vorgabe, nicht „unlesbar". Von Hand auch, damit die Vorgabe von
    // `RawRepresentable` (Kodieren über `rawValue`) nicht in sich selbst läuft.
    private enum CodingKeys: String, CodingKey {
        case hintergrundfarbe, effekt, tempo, overlay, palette, eigenePalette
        case ueberblenden, textAusPalette, spanne, lauf
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hintergrundfarbe = try c.decodeIfPresent(String.self, forKey: .hintergrundfarbe) ?? hintergrundfarbe
        effekt = try c.decodeIfPresent(String.self, forKey: .effekt)
        tempo = try c.decodeIfPresent(Double.self, forKey: .tempo) ?? tempo
        overlay = try c.decodeIfPresent(String.self, forKey: .overlay)
        palette = try c.decodeIfPresent(Palettenwahl.self, forKey: .palette) ?? palette
        eigenePalette = try c.decodeIfPresent(Eigenepalette.self, forKey: .eigenePalette) ?? eigenePalette
        ueberblenden = try c.decodeIfPresent(Bool.self, forKey: .ueberblenden) ?? ueberblenden
        textAusPalette = try c.decodeIfPresent(Bool.self, forKey: .textAusPalette) ?? textAusPalette
        spanne = try c.decodeIfPresent(Int.self, forKey: .spanne) ?? spanne
        lauf = try c.decodeIfPresent(Double.self, forKey: .lauf) ?? lauf
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hintergrundfarbe, forKey: .hintergrundfarbe)
        try c.encodeIfPresent(effekt, forKey: .effekt)
        try c.encode(tempo, forKey: .tempo)
        try c.encodeIfPresent(overlay, forKey: .overlay)
        try c.encode(palette, forKey: .palette)
        try c.encode(eigenePalette, forKey: .eigenePalette)
        try c.encode(ueberblenden, forKey: .ueberblenden)
        try c.encode(textAusPalette, forKey: .textAusPalette)
        try c.encode(spanne, forKey: .spanne)
        try c.encode(lauf, forKey: .lauf)
    }

    /// Die Darstellung für den Rahmen — `nil`, wenn nichts zu senden ist. Was der
    /// Weg sperrt (`Darstellungsregeln`), fehlt; sonst wiese `Anzeigen` es mit
    /// `DarstellungsFehler.vomBildVerdeckt` ab.
    public func darstellung(weg: SendeWeg) -> Darstellung? {
        let regeln = Darstellungsregeln(weg: weg, wahl: self)
        var d = Darstellung()
        if !regeln.effektGesperrt, let effekt, !effekt.isEmpty {
            d.effekt = effekt
        } else if !regeln.farbeGesperrt, hintergrundfarbe != Self.keinHintergrund {
            d.hintergrundfarbe = hintergrundfarbe
        }
        if !regeln.tempoGesperrt {
            d.effektTempo = (tempo * 10).rounded() / 10
        }
        if let overlay, !overlay.isEmpty { d.overlay = overlay }
        if !regeln.paletteGesperrt {
            switch palette {
            case .keine: break
            case .name(let n): if !n.isEmpty { d.palette = .name(n) }
            case .eigene: d.palette = eigenePalette.palette
            }
        }
        if d.palette != nil { d.paletteUeberblenden = ueberblenden }
        if !regeln.textMalenGesperrt, textAusPalette {
            d.textfarbeAusPalette = true
            d.paletteSpanne = spanne
            d.paletteTempo = (lauf * 10).rounded() / 10
        }
        return d.istLeer ? nil : d
    }
}

extension Darstellungswahl: RawRepresentable {
    /// Als JSON-Text: `@AppStorage` kennt nur einfache Typen.
    public init?(rawValue: String) {
        guard let daten = rawValue.data(using: .utf8),
              let w = try? JSONDecoder().decode(Darstellungswahl.self, from: daten) else { return nil }
        self = w
    }

    public var rawValue: String {
        let k = JSONEncoder()
        k.outputFormatting = [.sortedKeys]
        return (try? k.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}

/// Was die Oberfläche je Weg sperrt (`Darstellung`, §5.3, §5.5): Ein Bild in
/// Anzeigegröße — jeder gerasterte Text — deckt Hintergrundfarbe und Effekt zu,
/// das Overlay geht, die Palette nur mit Overlay. Text malen aus der Palette gibt es nur, wo die Uhr
/// den Text selbst setzt. Dieselben Fälle weist `Anzeigen.grundnutzlast` mit
/// `DarstellungsFehler.vomBildVerdeckt` und `ohneText` ab; die Oberfläche sperrt sie,
/// bevor es dazu kommt.
public struct Darstellungsregeln: Equatable, Sendable {
    public let weg: SendeWeg
    public let wahl: Darstellungswahl

    public init(weg: SendeWeg, wahl: Darstellungswahl) {
        self.weg = weg
        self.wahl = wahl
    }

    /// Text als Bild (`SendeWeg.pixel`).
    public var textAlsBild: Bool { weg == .pixel }

    public var effektGesperrt: Bool { textAlsBild }
    /// Ein Effekt ersetzt die Hintergrundfarbe (`DarstellungsFehler.farbeUndEffekt`).
    public var farbeDurchEffekt: Bool { !textAlsBild && wahl.effekt?.isEmpty == false }
    public var farbeGesperrt: Bool { textAlsBild || farbeDurchEffekt }
    /// Das Tempo gilt für Effekt und Overlay.
    public var tempoGesperrt: Bool {
        let effektWirkt = !effektGesperrt && wahl.effekt?.isEmpty == false
        let overlayWirkt = wahl.overlay?.isEmpty == false
        return !(effektWirkt || overlayWirkt)
    }
    public var textMalenGesperrt: Bool { textAlsBild }

    public var overlayGewaehlt: Bool { wahl.overlay?.isEmpty == false }
    /// Palette, eigene Palette und Überblenden sind gesperrt, solange nichts
    /// sie nutzen kann. Genutzt wird sie von Effekt, Overlay und „Text aus
    /// Palette“ (§5.5). Im Bildweg sind Effekt und Text malen gesperrt, übrig
    /// bleibt das Overlay: Ohne eines ist die Palette dort gesperrt. Mit der
    /// Schrift der Uhr ist sie frei; ob sie dann wirkt, sagt `paletteWirkt`.
    /// Eine gesperrte Palette geht nicht hinaus (`Darstellungswahl.darstellung`).
    public var paletteGesperrt: Bool { textAlsBild && !overlayGewaehlt }
    /// Spanne und Lauf gehören zum Malen aus der Palette.
    public var spanneLaufGesperrt: Bool { textMalenGesperrt || !wahl.textAusPalette }

    /// Ob die gewählte Palette auf der Uhr etwas färbt: ein Overlay, ein Effekt,
    /// der sie nutzt (`Geraetefaehigkeiten.nutztPalette`), oder der Text. Ohne
    /// Liste der Uhr gilt ein Effekt als einer, der sie nutzt.
    public func paletteWirkt(faehigkeiten: Geraetefaehigkeiten?) -> Bool {
        if wahl.overlay?.isEmpty == false { return true }
        if !effektGesperrt, let e = wahl.effekt, !e.isEmpty,
           faehigkeiten?.nutztPalette(effekt: e) ?? true { return true }
        return !textMalenGesperrt && wahl.textAusPalette
    }
}
