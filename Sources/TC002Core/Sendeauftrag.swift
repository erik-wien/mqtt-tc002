import Foundation

/// Alles, was die Senden-Ansichten zum Senden brauchen, als ein Wert: die
/// Optionen, das Icon, der Platz, die Nachrichtregler und die aufgelösten Ziele.
/// Liest und schreibt dieselben Schlüssel wie die `@AppStorage`-Felder von
/// `SendenView` und `SendeniOS` und ist damit die einzige Stelle, die deren
/// Kodierung kennt.
///
/// Anders als `Meldungsoptionen.ausAblage` liest `aus` auch die Darstellung:
/// Das hier ist der Stand der Ansicht, nicht der eines Kurzbefehls.
public struct Sendeauftrag: Codable, Equatable, Sendable {
    public var optionen: Meldungsoptionen
    /// `nil` heißt ohne Icon.
    public var iconNummer: String?
    /// 8 oder 16; zusammen mit der Nummer, weil beide Bestände denselben Namen tragen dürfen.
    public var iconKante: Int
    /// 1…5
    public var platz: Int
    /// `nil` heißt Anzeige, gesetzt heißt Nachricht.
    public var nachricht: Nachrichtwahl?
    /// Aufgelöst; leer heißt hier nicht „aktive Uhr“.
    public var zielIDs: [UUID]

    public init(optionen: Meldungsoptionen, iconNummer: String? = nil, iconKante: Int = 8,
                platz: Int = 1, nachricht: Nachrichtwahl? = nil, zielIDs: [UUID] = []) {
        self.optionen = optionen
        self.iconNummer = iconNummer
        self.iconKante = iconKante
        self.platz = platz
        self.nachricht = nachricht
        self.zielIDs = zielIDs
    }

    // Nachsichtig wie die übrigen Dateiformate: Die Datei kann in iCloud liegen
    // und von älteren oder neueren Fassungen geschrieben sein.
    private enum CodingKeys: String, CodingKey {
        case optionen, iconNummer, iconKante, platz, nachricht, zielIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        optionen = try c.decode(Meldungsoptionen.self, forKey: .optionen)
        iconNummer = try c.decodeIfPresent(String.self, forKey: .iconNummer)
        iconKante = try c.decodeIfPresent(Int.self, forKey: .iconKante) ?? 8
        platz = try c.decodeIfPresent(Int.self, forKey: .platz) ?? 1
        nachricht = try c.decodeIfPresent(Nachrichtwahl.self, forKey: .nachricht)
        zielIDs = try c.decodeIfPresent([UUID].self, forKey: .zielIDs) ?? []
    }

    private static let platzbereich = 1...5

    /// Liest den Stand der Ansicht; fehlende oder unlesbare Schlüssel ergeben die
    /// Vorgaben der `@AppStorage`-Deklarationen.
    public static func aus(_ d: UserDefaults, zielIDs: [UUID]) -> Sendeauftrag {
        func text(_ k: String) -> String? { d.string(forKey: k) }
        func gesetzt(_ k: String) -> Bool { d.object(forKey: k) != nil }
        func wahr(_ k: String, _ vorgabe: Bool) -> Bool { gesetzt(k) ? d.bool(forKey: k) : vorgabe }
        func ganz(_ k: String, _ vorgabe: Int) -> Int { gesetzt(k) ? d.integer(forKey: k) : vorgabe }
        func wert<T: RawRepresentable>(_ k: String, _ vorgabe: T) -> T where T.RawValue == String {
            text(k).flatMap(T.init(rawValue:)) ?? vorgabe
        }

        let lebensdauer = Lebensdauerwahl(
            behalten: wahr("senden.lebensdauer.behalten", false),
            zahl: ganz("senden.lebensdauer.zahl", 30),
            einheit: wert("senden.lebensdauer.einheit", .minuten),
            ablauf: wert("senden.lebensdauer.ablauf", .entfernen))
        let darstellung = text("senden.darstellung").flatMap(Darstellungswahl.init(rawValue:)) ?? Darstellungswahl()
        let dauer = text("senden.dauer").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }.flatMap { $0 > 0 ? $0 : nil }

        let optionen = Meldungsoptionen(
            text: text("senden.text") ?? "Hallo",
            weg: wert("senden.weg", .pixel),
            schrift: text("senden.schriftart") ?? "Silkscreen",
            groesse: gesetzt("senden.groesse") ? d.double(forKey: "senden.groesse") : 8,
            fett: wahr("senden.fett", false),
            farbe: text("senden.farbe") ?? "#00FF66",
            grossbuchstaben: wahr("senden.grossbuchstaben", false),
            waagrecht: wert("senden.horizontal", .links),
            senkrecht: wert("senden.vertikal", .mittig),
            rand: ganz("senden.rand", 1),
            abstand: ganz("senden.luecke", 1),
            tempo: wert("senden.tempo", .mittel),
            dauer: dauer,
            lebensdauer: lebensdauer == Lebensdauerwahl() ? nil : lebensdauer.lebensdauer,
            darstellung: darstellung == Darstellungswahl() ? nil : darstellung,
            iconmodus: Iconmodus(laeuftMit: wahr("senden.iconmitlaufend", false),
                                 einmal: wahr("senden.iconeinmal", false)),
            zusatzicons: Zusatzicons.aus(json: text("senden.zusatzicons") ?? ""))

        var nachricht: Nachrichtwahl?
        if text("senden.art") == "nachricht" {
            nachricht = Nachrichtwahl(
                steht: Nachrichtdauerwahl(art: wert(Nachrichtdauerwahl.schluessel, .bisZurueckgezogen),
                                          sekunden: ganz(Nachrichtdauerwahl.sekundenSchluessel, 10),
                                          durchlaeufe: ganz(Nachrichtdauerwahl.durchlaeufeSchluessel, 2)),
                aufwecken: wahr("senden.nachricht.aufwecken", true),
                ersetzen: wahr("senden.nachricht.ersetzen", true),
                klang: text("senden.nachricht.klang").flatMap(Klangwahl.init(rawValue:)) ?? Klangwahl())
        }

        let nummer = text("senden.icon") ?? ""
        return Sendeauftrag(optionen: optionen,
                            iconNummer: nummer.isEmpty ? nil : nummer,
                            iconKante: ganz("senden.iconkante", 8),
                            platz: platzbereich.clamp(ganz("senden.meldungsplatz", 1)),
                            nachricht: nachricht,
                            zielIDs: zielIDs)
    }

    /// Schreibt den Auftrag in die Schlüssel der Ansichten. Ohne Nachricht
    /// bleiben die `senden.nachricht.*`-Schlüssel unberührt, damit deren Regler
    /// nach einer Anzeige noch dastehen. `zielIDs` hat keinen Schlüssel.
    public func schreiben(in d: UserDefaults) {
        let o = optionen
        d.set(o.text, forKey: "senden.text")
        d.set(o.weg.rawValue, forKey: "senden.weg")
        d.set(o.schrift, forKey: "senden.schriftart")
        d.set(o.groesse, forKey: "senden.groesse")
        d.set(o.fett, forKey: "senden.fett")
        d.set(o.farbe, forKey: "senden.farbe")
        d.set(o.grossbuchstaben, forKey: "senden.grossbuchstaben")
        d.set(o.waagrecht.rawValue, forKey: "senden.horizontal")
        d.set(o.senkrecht.rawValue, forKey: "senden.vertikal")
        d.set(o.rand, forKey: "senden.rand")
        d.set(o.abstand, forKey: "senden.luecke")
        d.set(o.tempo.rawValue, forKey: "senden.tempo")
        d.set(o.iconmodus.laeuftMit, forKey: "senden.iconmitlaufend")
        d.set(o.iconmodus.einmal, forKey: "senden.iconeinmal")
        d.set(o.dauer.map(String.init) ?? "", forKey: "senden.dauer")
        d.set((o.darstellung ?? Darstellungswahl()).rawValue, forKey: "senden.darstellung")
        d.set(Zusatzicons.json(o.zusatzicons ?? []), forKey: "senden.zusatzicons")
        let l = Lebensdauerwahl(o.lebensdauer)
        d.set(l.behalten, forKey: "senden.lebensdauer.behalten")
        d.set(l.zahl, forKey: "senden.lebensdauer.zahl")
        d.set(l.einheit.rawValue, forKey: "senden.lebensdauer.einheit")
        d.set(l.ablauf.rawValue, forKey: "senden.lebensdauer.ablauf")
        d.set(iconNummer ?? "", forKey: "senden.icon")
        d.set(iconKante, forKey: "senden.iconkante")
        d.set(platz, forKey: "senden.meldungsplatz")
        if let n = nachricht {
            d.set("nachricht", forKey: "senden.art")
            d.set(n.steht.art.rawValue, forKey: Nachrichtdauerwahl.schluessel)
            d.set(n.steht.sekunden, forKey: Nachrichtdauerwahl.sekundenSchluessel)
            d.set(n.steht.durchlaeufe, forKey: Nachrichtdauerwahl.durchlaeufeSchluessel)
            d.set(n.aufwecken, forKey: "senden.nachricht.aufwecken")
            d.set(n.ersetzen, forKey: "senden.nachricht.ersetzen")
            d.set(n.klang.rawValue, forKey: "senden.nachricht.klang")
        } else {
            d.set("anzeige", forKey: "senden.art")
        }
    }
}
