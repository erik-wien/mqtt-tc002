import Foundation

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit einem 8×8-Icon, ab Spalte 18 mit einem 16×16).
public enum SendenHAusrichtung: String, CaseIterable, Identifiable, Sendable {
    case links, mittig, rechts
    public var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
public enum SendenVAusrichtung: String, CaseIterable, Identifiable, Sendable {
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
public enum SendeWeg: String, CaseIterable, Identifiable, Sendable {
    case pixel, text
    public var id: String { rawValue }
}

/// Wie schnell die Laufschrift durchlaeuft. Ein Regler statt zweier Zahlen:
/// Schrittweite und Bilddauer rechnet niemand im Kopf in ein Tempo um.
public enum Lauftempo: String, CaseIterable, Identifiable, Sendable {
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
public struct Meldungsoptionen: Sendable, Equatable {
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
    /// **Die Vorschau einer NG-Uhr ist eine Näherung, und zwar immer dieselbe.**
    ///
    /// AWTRIX NG setzt den Text mit ihrer eigenen Schrift; unsere Schriftwahl
    /// ist dort gesperrt (`Geraetetyp.wirkt(.schriftart)`). Der gespeicherte
    /// Wert bleibt davon aber unberührt und kann „Tiny5, 16 px" sein — auf
    /// acht Zeilen gerastert wäre das abgeschnitten, und die Vorschau zeigte
    /// einen Fehler, den das Gerät gar nicht hat.
    ///
    /// Gewählt ist Silkscreen in 8 px: eine Pixelschrift, die auf der
    /// abgesegneten Liste steht (`Pixelgroessen.abgesegnet`) und in acht Zeilen
    /// vollständig Platz hat.
    ///
    /// Angerührt werden nur Schrift und Größe. Farbe, Ausrichtung, Abstand und
    /// das mitlaufende Icon sind Regler, die NG sehr wohl kennt
    /// (`Geraetetyp.wirkt`) — sie zu ersetzen hieße, die Vorschau von der
    /// Einstellung abzukoppeln, die wirklich gesendet wird.
    ///
    /// **Im Kern und nicht in den Ansichten**: Mac und iPhone rufen dasselbe.
    /// Zwei Abschriften derselben Tabelle laufen früher oder später
    /// auseinander, und die abweichende wäre die falsche — in diesem Projekt
    /// schon dreimal vorgekommen (siehe `Regler` in `Geraetetyp.swift`).
    public func naeherung(fuer gattung: Geraetetyp) -> Meldungsoptionen {
        guard gattung.setztSelbst else { return self }
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
    /// sechzehn Zeilen der Werksfirmware ergibt das bei 8×8 die bekannte 4 und
    /// bei 16×16 die 0 — ein 16×16 fuellt die volle Hoehe und schwimmt nicht.
    /// Auf den acht Zeilen einer NG-Uhr tut das ein 8×8.
    public static func iconY(kante: Int = 8, mass: Anzeigemass = .tc002) -> Int {
        mass.iconY(kante: kante)
    }

    /// `iconKante` hat ueberall eine Vorgabe: Jede Stelle, die frueher nur
    /// „Icon ja/nein" wusste, meinte damit ein 8×8 und rechnet unveraendert
    /// weiter.
    public static func flaecheX(mitIcon: Bool, iconKante: Int = 8) -> Int {
        mitIcon ? iconBreite(kante: iconKante) : 0
    }
    public static func flaecheBreite(mitIcon: Bool, iconKante: Int = 8,
                                     mass: Anzeigemass = .tc002) -> Int {
        mass.breite - flaecheX(mitIcon: mitIcon, iconKante: iconKante)
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    public static func puffer(_ o: Meldungsoptionen, mass: Anzeigemass = .tc002) -> Pixelfeld {
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
                             mass: Anzeigemass = .tc002) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    public static func versatzY(_ o: Meldungsoptionen, mass: Anzeigemass = .tc002) -> Int {
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
                                mass: Anzeigemass = .tc002) -> Int {
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
                            mass: Anzeigemass = .tc002) -> Pixelfeld {
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
                                  mass: Anzeigemass = .tc002) -> [Bildraster.Einzelbild] {
        Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o, mass: mass), iconBilder: iconBilder, iconKante: iconKante,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand, mass: mass)
    }

    public static func textblock(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                                 mass: Anzeigemass = .tc002) -> Textblock {
        var t = Textblock(inhalt: o.gesendeterText)
        t.schrifthoehe = Int(o.groesse)
        t.x = flaecheX(mitIcon: mitIcon, iconKante: iconKante)
        t.y = 0
        t.farbe = o.farbe
        t.ausrichtung = o.geraeteAusrichtung
        t.vertikal = o.geraeteVertikal
        t.flaeche = [flaecheX(mitIcon: mitIcon, iconKante: iconKante), 0,
                     flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass), mass.hoehe]
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
        var gebaut = try gebauterRahmen(o, icon: icon, sammlung: sammlung, vorberechnet: vorberechnet)
        // **Die Herkunft haengt an jedem Rahmen, den diese Funktion baut** —
        // und nur an ihnen. Ein gemaltes Bild kommt nicht hier vorbei, hat
        // keine Regler und kann deshalb auch keine mitgeben; genau daran
        // erkennt `Anzeigen`, dass es an eine AWTRIX NG nicht zu schicken ist.
        //
        // Das Icon wird hier **noch einmal** gelesen, obwohl der stehende Fall
        // es schon in `bilder` traegt: Im laufenden Fall steckt es im GIF und
        // liesse sich von dort nicht mehr herausloesen. Eine Stelle, an der es
        // immer dasteht, ist eine Icondatei je Sendung wert.
        gebaut.herkunft = Meldungsherkunft(
            optionen: o,
            iconDatenURI: try icon.map { try sammlung.datenURI(fuer: $0) },
            iconKante: icon?.kante ?? 8)
        return gebaut
    }

    /// Der Rahmen selbst, ohne Herkunft — der Rumpf von `rahmen`.
    private static func gebauterRahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung,
                                       vorberechnet: String?) throws -> Frame {
        let mitIcon = icon != nil
        // Die einzige Stelle, an der die Groesse des Icons wirklich entschieden
        // wird: Alles darunter rechnet mit ihr weiter, statt 8 anzunehmen.
        let kante = icon?.kante ?? 8
        switch o.weg {
        case .pixel:
            guard passt(o, mitIcon: mitIcon, iconKante: kante) else {
                let uri: String
                if let fertig = vorberechnet, !fertig.isEmpty {
                    uri = fertig
                } else {
                    // Erst hier lesen: Liegt das GIF schon vor, waere das
                    // Oeffnen der Icondatei bei jedem Senden umsonst.
                    let iconBilder = icon.flatMap { i -> [[String?]]? in
                        try? Bildraster.lesenMitZeiten(i.datei, breite: kante, hoehe: kante).map(\.pixel)
                    } ?? []
                    uri = try Textraster.laufschrift(
                        o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
                        farbe: o.farbe, schrittweite: o.tempo.schrittweite,
                        bilddauer: o.tempo.bilddauer, versatzY: versatzY(o),
                        iconBilder: iconBilder, iconKante: kante,
                        iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
                }
                return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: o.dauer)
            }
            var frame = Frame(draw: feld(o, mitIcon: mitIcon, iconKante: kante).alsDrawBefehle(),
                              dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon),
                                         x: 0, y: iconY(kante: kante)))
            }
            return frame
        case .text:
            var frame = Frame(texte: [textblock(o, mitIcon: mitIcon, iconKante: kante)], dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon),
                                         x: 0, y: iconY(kante: kante)))
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
