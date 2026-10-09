import Foundation

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit einem 8×8-Icon, ab Spalte 18 mit einem 16×16).
public enum SendenHAusrichtung: String, CaseIterable, Identifiable, Sendable, Codable {
    case links, mittig, rechts
    public var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
public enum SendenVAusrichtung: String, CaseIterable, Identifiable, Sendable, Codable {
    case oben, mittig, unten
    public var id: String { rawValue }
}

/// Der Weg, auf dem der Text zur Uhr kommt. AWTRIX NG setzt den Text selbst
/// (`Anzeigen.nutzlast`): Beide Stellungen schicken denselben Text samt
/// Reglern, die Uhr sieht unsere Pixel nie.
///
/// Das Feld bleibt, weil es Teil des Dateiformats von Slotgedaechtnis, Verlauf
/// und Formatangaben ist, das auch andere Geraete im iCloud-Behaelter lesen.
public enum SendeWeg: String, CaseIterable, Identifiable, Sendable, Codable {
    case pixel, text
    public var id: String { rawValue }
}

/// Wie schnell die Laufschrift durchlaeuft. Ein Regler statt zweier Zahlen:
/// Schrittweite und Bilddauer rechnet niemand im Kopf in ein Tempo um.
public enum Lauftempo: String, CaseIterable, Identifiable, Sendable, Codable {
    case langsam, mittel, schnell
    public var id: String { rawValue }

    /// Pixel Versatz je Einzelbild — immer einer. Zweierschritte wuerden die
    /// Zahl der Einzelbilder und damit die Nutzlast halbieren, kosten aber die
    /// Ruhe im Bild; zusammen mit einer kuerzeren Standzeit ergaebe das fast
    /// das Dreifache von „mittel" statt einer Stufe. Die Stufen unterscheiden
    /// sich deshalb nur in der Standzeit.
    public var schrittweite: Int { 1 }

    /// Standzeit je Einzelbild in Sekunden. Die Stufen liegen rund das
    /// Anderthalbfache auseinander — gleichmaessig statt sprunghaft.
    public var bilddauer: Double {
        switch self {
        case .langsam: return 0.12   //  8 Pixel je Sekunde
        case .mittel:  return 0.08   // 12
        case .schnell: return 0.055  // 18
        }
    }
}

/// Alles, was eine Meldung ausmacht — ohne Ansicht, ohne Zustand.
///
/// Die Felder entsprechen eins zu eins den `@AppStorage`-Werten der
/// Sendeansicht. Wer hier etwas umbenennt, muss dort denselben Namen benutzen,
/// sonst liest eine laufende Installation ihre Einstellungen nicht mehr. Der
/// Sendeverlauf schreibt diesen Typ unveraendert in seine Datei.
///
/// `Slotstand` (im Slotgedaechtnis) legt dieselben Angaben weiterhin flach ab,
/// Feld fuer Feld: Jene Datei liegt in einem iCloud-Behaelter, den auch
/// aeltere Fassungen auf anderen Geraeten lesen — ihr Format zu aendern hiesse,
/// ihnen das Gedaechtnis wegzunehmen. Ein neues Format faengt dagegen frei an.
public struct Meldungsoptionen: Sendable, Equatable, Codable {
    public var text: String
    public var weg: SendeWeg = .pixel
    public var schrift: String = "Silkscreen"
    public var groesse: Double = 8
    public var fett: Bool = false
    public var farbe: String = "#00FF66"
    public var grossbuchstaben: Bool = false
    public var waagrecht: SendenHAusrichtung = .links
    public var senkrecht: SendenVAusrichtung = .oben
    public var rand: Int = 1
    public var abstand: Int = 1
    public var tempo: Lauftempo = .mittel
    public var iconLaeuftMit: Bool = false
    public var dauer: Int?

    public init(text: String,
                weg: SendeWeg = .pixel,
                schrift: String = "Silkscreen",
                groesse: Double = 8,
                fett: Bool = false,
                farbe: String = "#00FF66",
                grossbuchstaben: Bool = false,
                waagrecht: SendenHAusrichtung = .links,
                senkrecht: SendenVAusrichtung = .oben,
                rand: Int = 1,
                abstand: Int = 1,
                tempo: Lauftempo = .mittel,
                iconLaeuftMit: Bool = false,
                dauer: Int? = nil) {
        self.text = text
        self.weg = weg
        self.schrift = schrift
        self.groesse = groesse
        self.fett = fett
        self.farbe = farbe
        self.grossbuchstaben = grossbuchstaben
        self.waagrecht = waagrecht
        self.senkrecht = senkrecht
        self.rand = rand
        self.abstand = abstand
        self.tempo = tempo
        self.iconLaeuftMit = iconLaeuftMit
        self.dauer = dauer
    }

    /// Der Text, wie er tatsächlich gerastert bzw. geschickt wird — die einzige
    /// Stelle, an der „Großbuchstaben" wirkt. Nebeneffekt von `uppercased()`:
    /// aus „ß" wird „SS".
    public var gesendeterText: String { grossbuchstaben ? text.uppercased() : text }

    /// `align`/`valign` in den Namen, die das Gerät für `text` erwartet (§4.3).
    public var geraeteAusrichtung: String {
        switch waagrecht { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    public var geraeteVertikal: String {
        switch senkrecht { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }
}

extension Meldungsoptionen {
    /// Die Vorschau einer NG-Uhr ist eine Näherung, immer dieselbe.
    ///
    /// AWTRIX NG setzt den Text mit ihrer eigenen Schrift; unsere Schriftwahl
    /// ist dort gesperrt (`AwtrixNG.wirkt(.schriftart)`). Der gespeicherte
    /// Wert bleibt davon aber unberührt und kann „Tiny5, 16 px" sein — die
    /// Vorschau zeigte dann eine Schrift, die das Gerät gar nicht hat.
    ///
    /// Gewählt ist Silkscreen in 8 px: eine Pixelschrift, die auf der
    /// abgesegneten Liste steht (`Pixelgroessen.abgesegnet`).
    ///
    /// Angerührt werden nur Schrift und Größe. Farbe, Ausrichtung, Abstand und
    /// das mitlaufende Icon sind Regler, die NG kennt (`AwtrixNG.wirkt`) —
    /// sie zu ersetzen hieße, die Vorschau von der Einstellung abzukoppeln,
    /// die wirklich gesendet wird.
    ///
    /// Im Kern und nicht in den Ansichten: Mac und iPhone rufen dasselbe, sonst
    /// laufen zwei Abschriften derselben Tabelle früher oder später auseinander
    /// (siehe `Regler` in `AwtrixNG.swift`).
    public var naeherung: Meldungsoptionen {
        var o = self
        o.schrift = "Silkscreen"
        o.groesse = 8
        return o
    }
}

/// Baut aus Optionen und Icon den Rahmen, den die Uhr bekommt.
///
/// Wortgetreu aus `SendenView` gelöst. Keine Rechnung wurde dabei geändert;
/// die Schnappschusstests halten das fest.
public enum Meldungsbau {
    /// Luft zwischen Icon und Text.
    public static let iconLuecke = 2

    /// Wo das Icon endet: seine Kante plus die Luft. Bei 8×8 zehn Spalten wie
    /// bisher, bei 16×16 achtzehn.
    public static func iconBreite(kante: Int = 8) -> Int { kante + iconLuecke }

    /// Auf welcher Zeile das Icon sitzt: senkrecht mittig im Feld. Auf den
    /// sechzehn Zeilen ergibt das bei 8×8 die 4 und bei 16×16 die 0 — ein
    /// 16×16 fuellt die volle Hoehe und schwimmt nicht.
    public static func iconY(kante: Int = 8, mass: Anzeigemass = .vorgabe) -> Int {
        mass.iconY(kante: kante)
    }

    /// `iconKante` hat ueberall eine Vorgabe: Jede Stelle, die frueher nur
    /// „Icon ja/nein" wusste, meinte damit ein 8×8 und rechnet unveraendert
    /// weiter.
    public static func flaecheX(mitIcon: Bool, iconKante: Int = 8) -> Int {
        mitIcon ? iconBreite(kante: iconKante) : 0
    }
    public static func flaecheBreite(mitIcon: Bool, iconKante: Int = 8,
                                     mass: Anzeigemass = .vorgabe) -> Int {
        mass.breite - flaecheX(mitIcon: mitIcon, iconKante: iconKante)
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    public static func puffer(_ o: Meldungsoptionen, mass: Anzeigemass = .vorgabe) -> Pixelfeld {
        Textraster.rasterPuffer(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                fett: o.fett, farbe: o.farbe, luecke: o.abstand, mass: mass)
    }

    public static func breite(_ o: Meldungsoptionen) -> Int {
        Textraster.breite(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                          fett: o.fett, luecke: o.abstand)
    }

    /// Passt der Text in die verfügbare Breite, steht er still — sonst läuft er
    /// als GIF durch. Gerechnet wird mit der Breite des stehenden Falls (mit
    /// Icon 42 Spalten). Hinge die Rechnung an „Icon mitscrollen", würde das
    /// Einschalten den Text passend machen, den Schalter verschwinden lassen
    /// und ihn wieder umwerfen.
    public static func passt(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                             mass: Anzeigemass = .vorgabe) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    public static func versatzY(_ o: Meldungsoptionen, mass: Anzeigemass = .vorgabe) -> Int {
        guard let tinte = Textraster.tintenZeilen(puffer(o, mass: mass)) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        // Mehr Rand, als Platz da ist, gaebe es nicht — dann bliebe nur
        // Abschneiden, und das will niemand.
        let r = min(o.rand, max(0, (mass.hoehe - hoehe) / 2))
        switch o.senkrecht {
        case .oben:   return -tinte.erste + r
        case .mittig: return (mass.hoehe - hoehe) / 2 - tinte.erste
        case .unten:  return (mass.hoehe - hoehe) - tinte.erste - r
        }
    }

    public static func versatzX(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                                mass: Anzeigemass = .vorgabe) -> Int {
        let x = flaecheX(mitIcon: mitIcon, iconKante: iconKante)
        let b = flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
        switch o.waagrecht {
        case .links:  return x
        case .mittig: return x + max(0, (b - breite(o)) / 2)
        case .rechts: return x + max(0, b - breite(o))
        }
    }

    /// Vorschau und Sendung entstehen aus demselben Feld. Gerastert wird immer
    /// in derselben Phase, ausgerichtet wird durch Verschieben — sonst sähe
    /// dieselbe Schrift stehend anders aus als laufend.
    public static func feld(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                            mass: Anzeigemass = .vorgabe) -> Pixelfeld {
        var f = Pixelfeld(breite: mass.breite, hoehe: mass.hoehe)
        Textraster.einsetzen(puffer(o, mass: mass),
                             x: versatzX(o, mitIcon: mitIcon, iconKante: iconKante, mass: mass),
                             y: versatzY(o, mass: mass), in: &f)
        return f
    }

    /// Die Einzelbilder der Laufschrift. Getrennt von `rahmen`, weil die
    /// Vorschau sie zum Abspielen braucht, während `rahmen` sie bereits zu
    /// einem GIF verpackt hat.
    public static func laufschriftBilder(_ o: Meldungsoptionen,
                                  iconBilder: [[String?]],
                                  iconKante: Int = 8,
                                  mass: Anzeigemass = .vorgabe) -> [Bildraster.Einzelbild] {
        Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o, mass: mass), iconBilder: iconBilder, iconKante: iconKante,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand, mass: mass)
    }

    /// Der Rahmen zu einer Meldung: Er traegt Text und Regler samt Icon als
    /// `Meldungsherkunft`, aus der AWTRIX NG die Anzeige baut
    /// (`NGNutzlast.anzeige`). Pixel traegt er nicht.
    public static func rahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung) throws -> Frame {
        Frame(dauer: o.dauer,
              herkunft: Meldungsherkunft(
                optionen: o,
                iconDatenURI: try icon.map { try sammlung.datenURI(fuer: $0) }))
    }
}

/// Die fünf Plätze, unter denen diese App Anzeigen auf der Uhr ablegt.
///
/// Der Name eines Platzes ist zugleich der Bezeichner der Anzeige auf dem
/// Gerät. Wer ihn ändert, findet die alten Anzeigen nicht mehr und kann sie
/// nicht mehr löschen.
public enum Meldungsplatz {
    public static let anzahl = 5
    public static func name(fuer platz: Int) -> String { "meldung\(platz)" }

    /// Die Kehrseite von `name(fuer:)`: welcher der fuenf Plaetze (falls
    /// einer) sich hinter einem Anzeigenamen verbirgt. `nil` fuer jeden
    /// anderen Namen — etwa eine frei gewaehlte Anzeige des
    /// Kommandozeilenwerkzeugs (Vorgabe „cli"), fuer die es keinen Platz
    /// gibt, den sich das Slotgedaechtnis merken koennte.
    public static func platz(fuerName name: String) -> Int? {
        (1...anzahl).first { Self.name(fuer: $0) == name }
    }
}
