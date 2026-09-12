import Foundation

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit Icon).
public enum SendenHAusrichtung: String, CaseIterable, Identifiable {
    case links, mittig, rechts
    public var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
public enum SendenVAusrichtung: String, CaseIterable, Identifiable {
    case oben, mittig, unten
    public var id: String { rawValue }
}

/// Der Weg, auf dem der Text zur Uhr kommt. `.pixel` (Vorgabe) rastert die App
/// selbst — passt der Text, steht er starr, sonst laeuft er als GIF (siehe
/// `passt`). `.text` schickt ihn stattdessen als `Textblock`, den die Uhr mit
/// ihrer eigenen Schrift setzt und selbst zum Laufen bringt, wenn er nicht
/// passt (`docs/tc002-protokoll.md` §4.3, §5.4). Deren Schrift kennt weder
/// Schriftartwahl noch Fett — deshalb sind genau diese zwei Regler dort
/// gesperrt, nicht mehr.
public enum SendeWeg: String, CaseIterable, Identifiable {
    case pixel, text
    public var id: String { rawValue }
}

/// Wie schnell die Laufschrift durchlaeuft. Ein Regler statt zweier Zahlen:
/// Schrittweite und Bilddauer rechnet niemand im Kopf in ein Tempo um.
public enum Lauftempo: String, CaseIterable, Identifiable {
    case langsam, mittel, schnell
    public var id: String { rawValue }

    /// Pixel Versatz je Einzelbild — immer einer.
    ///
    /// „Schnell" nahm frueher Zweierschritte, mit der Begruendung, das halte die
    /// Nutzlast klein. Die Rechnung stimmte nicht: Die Zahl der Einzelbilder
    /// haengt allein an der Schrittweite, nicht an der Standzeit — Zweierschritte
    /// halbieren also die Nutzlast, kosten aber die Ruhe im Bild. Und zusammen
    /// mit der kuerzeren Standzeit ergab das fast das Dreifache von „mittel",
    /// also einen Sprung statt einer Stufe. Jetzt unterscheidet nur die Standzeit.
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
/// sonst liest eine laufende Installation ihre Einstellungen nicht mehr.
public struct Meldungsoptionen {
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

/// Baut aus Optionen und Icon den Rahmen, den die Uhr bekommt.
///
/// Wortgetreu aus `SendenView` gelöst. Keine Rechnung wurde dabei geändert;
/// die Schnappschusstests halten das fest.
public enum Meldungsbau {
    /// Wo das Icon endet: acht Pixel breit, zwei Pixel Luft.
    public static let iconBreite = 10

    public static func flaecheX(mitIcon: Bool) -> Int { mitIcon ? iconBreite : 0 }
    public static func flaecheBreite(mitIcon: Bool) -> Int {
        Pixelfeld.breiteStandard - flaecheX(mitIcon: mitIcon)
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    public static func puffer(_ o: Meldungsoptionen) -> Pixelfeld {
        Textraster.rasterPuffer(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                fett: o.fett, farbe: o.farbe, luecke: o.abstand)
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
    public static func passt(_ o: Meldungsoptionen, mitIcon: Bool) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    public static func versatzY(_ o: Meldungsoptionen) -> Int {
        guard let tinte = Textraster.tintenZeilen(puffer(o)) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        // Mehr Rand, als Platz da ist, gaebe es nicht — dann bliebe nur
        // Abschneiden, und das will niemand.
        let r = min(o.rand, max(0, (Pixelfeld.hoeheStandard - hoehe) / 2))
        switch o.senkrecht {
        case .oben:   return -tinte.erste + r
        case .mittig: return (Pixelfeld.hoeheStandard - hoehe) / 2 - tinte.erste
        case .unten:  return (Pixelfeld.hoeheStandard - hoehe) - tinte.erste - r
        }
    }

    public static func versatzX(_ o: Meldungsoptionen, mitIcon: Bool) -> Int {
        let x = flaecheX(mitIcon: mitIcon), b = flaecheBreite(mitIcon: mitIcon)
        switch o.waagrecht {
        case .links:  return x
        case .mittig: return x + max(0, (b - breite(o)) / 2)
        case .rechts: return x + max(0, b - breite(o))
        }
    }

    /// Vorschau und Sendung entstehen aus demselben Feld. Gerastert wird immer
    /// in derselben Phase, ausgerichtet wird durch Verschieben — sonst sähe
    /// dieselbe Schrift stehend anders aus als laufend.
    public static func feld(_ o: Meldungsoptionen, mitIcon: Bool) -> Pixelfeld {
        var f = Pixelfeld()
        Textraster.einsetzen(puffer(o), x: versatzX(o, mitIcon: mitIcon),
                             y: versatzY(o), in: &f)
        return f
    }

    /// Die Einzelbilder der Laufschrift. Getrennt von `rahmen`, weil die
    /// Vorschau sie zum Abspielen braucht, während `rahmen` sie bereits zu
    /// einem GIF verpackt hat.
    public static func laufschriftBilder(_ o: Meldungsoptionen,
                                  iconBilder: [[String?]]) -> [Bildraster.Einzelbild] {
        Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o), iconBilder: iconBilder,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
    }

    public static func textblock(_ o: Meldungsoptionen, mitIcon: Bool) -> Textblock {
        var t = Textblock(inhalt: o.gesendeterText)
        t.schrifthoehe = Int(o.groesse)
        t.x = flaecheX(mitIcon: mitIcon)
        t.y = 0
        t.farbe = o.farbe
        t.ausrichtung = o.geraeteAusrichtung
        t.vertikal = o.geraeteVertikal
        t.flaeche = [flaecheX(mitIcon: mitIcon), 0,
                     flaecheBreite(mitIcon: mitIcon), Pixelfeld.hoeheStandard]
        return t
    }

    /// Baut den Rahmen für den gewählten Weg. Beim Pixel-Weg zwei Fälle, einer
    /// je Entscheidung von `passt`: ein starrer `draw`-Rahmen mit dem Icon als
    /// zweitem Bild, oder ein einziges animiertes GIF, in dem das Icon schon
    /// steckt. Beim Text-Weg ein `Textblock`, den die Uhr selbst setzt.
    ///
    /// `vorberechnet` ist das bereits gebaute Laufschrift-GIF. Die Sendeansicht
    /// hat es für die Vorschau ohnehin erzeugt; es zweimal zu rastern wäre die
    /// teuerste Rechnung der App, doppelt ausgeführt.
    public static func rahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung,
                       vorberechnet: String? = nil) throws -> Frame {
        let mitIcon = icon != nil
        switch o.weg {
        case .pixel:
            guard passt(o, mitIcon: mitIcon) else {
                let uri: String
                if let fertig = vorberechnet, !fertig.isEmpty {
                    uri = fertig
                } else {
                    // Erst hier lesen: Liegt das GIF schon vor, waere das
                    // Oeffnen der Icondatei bei jedem Senden umsonst.
                    let iconBilder = icon.flatMap { i -> [[String?]]? in
                        try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
                    } ?? []
                    uri = try Textraster.laufschrift(
                        o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
                        farbe: o.farbe, schrittweite: o.tempo.schrittweite,
                        bilddauer: o.tempo.bilddauer, versatzY: versatzY(o),
                        iconBilder: iconBilder, iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
                }
                return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: o.dauer)
            }
            var frame = Frame(draw: feld(o, mitIcon: mitIcon).alsDrawBefehle(), dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        case .text:
            var frame = Frame(texte: [textblock(o, mitIcon: mitIcon)], dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        }
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
