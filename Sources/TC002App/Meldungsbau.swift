import Foundation
import TC002Core

/// Alles, was eine Meldung ausmacht — ohne Ansicht, ohne Zustand.
///
/// Die Felder entsprechen eins zu eins den `@AppStorage`-Werten der
/// Sendeansicht. Wer hier etwas umbenennt, muss dort denselben Namen benutzen,
/// sonst liest eine laufende Installation ihre Einstellungen nicht mehr.
struct Meldungsoptionen {
    var text: String
    var weg: SendeWeg = .pixel
    var schrift: String = "Silkscreen"
    var groesse: Double = 8
    var fett: Bool = false
    var farbe: String = "#00FF66"
    var grossbuchstaben: Bool = false
    var waagrecht: SendenHAusrichtung = .links
    var senkrecht: SendenVAusrichtung = .oben
    var rand: Int = 1
    var abstand: Int = 1
    var tempo: Lauftempo = .mittel
    var iconLaeuftMit: Bool = false
    var dauer: Int?

    /// Der Text, wie er tatsächlich gerastert bzw. geschickt wird — die einzige
    /// Stelle, an der „Großbuchstaben" wirkt. Nebeneffekt von `uppercased()`:
    /// aus „ß" wird „SS".
    var gesendeterText: String { grossbuchstaben ? text.uppercased() : text }

    /// `align`/`valign` in den Namen, die das Gerät für `text` erwartet (§4.3).
    var geraeteAusrichtung: String {
        switch waagrecht { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    var geraeteVertikal: String {
        switch senkrecht { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }
}

/// Baut aus Optionen und Icon den Rahmen, den die Uhr bekommt.
///
/// Wortgetreu aus `SendenView` gelöst. Keine Rechnung wurde dabei geändert;
/// die Schnappschusstests halten das fest.
enum Meldungsbau {
    /// Wo das Icon endet: acht Pixel breit, zwei Pixel Luft.
    static let iconBreite = 10

    static func flaecheX(mitIcon: Bool) -> Int { mitIcon ? iconBreite : 0 }
    static func flaecheBreite(mitIcon: Bool) -> Int {
        Pixelfeld.breiteStandard - flaecheX(mitIcon: mitIcon)
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    static func puffer(_ o: Meldungsoptionen) -> Pixelfeld {
        Textraster.rasterPuffer(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                fett: o.fett, farbe: o.farbe, luecke: o.abstand)
    }

    static func breite(_ o: Meldungsoptionen) -> Int {
        Textraster.breite(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                          fett: o.fett, luecke: o.abstand)
    }

    /// Passt der Text in die verfügbare Breite, steht er still — sonst läuft er
    /// als GIF durch. Gerechnet wird mit der Breite des stehenden Falls (mit
    /// Icon 42 Spalten). Hinge die Rechnung an „Icon mitscrollen", würde das
    /// Einschalten den Text passend machen, den Schalter verschwinden lassen
    /// und ihn wieder umwerfen.
    static func passt(_ o: Meldungsoptionen, mitIcon: Bool) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    static func versatzY(_ o: Meldungsoptionen) -> Int {
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

    static func versatzX(_ o: Meldungsoptionen, mitIcon: Bool) -> Int {
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
    static func feld(_ o: Meldungsoptionen, mitIcon: Bool) -> Pixelfeld {
        var f = Pixelfeld()
        Textraster.einsetzen(puffer(o), x: versatzX(o, mitIcon: mitIcon),
                             y: versatzY(o), in: &f)
        return f
    }

    /// Die Einzelbilder der Laufschrift. Getrennt von `rahmen`, weil die
    /// Vorschau sie zum Abspielen braucht, während `rahmen` sie bereits zu
    /// einem GIF verpackt hat.
    static func laufschriftBilder(_ o: Meldungsoptionen,
                                  iconBilder: [[String?]]) -> [Bildraster.Einzelbild] {
        Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o), iconBilder: iconBilder,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
    }

    static func textblock(_ o: Meldungsoptionen, mitIcon: Bool) -> Textblock {
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
    static func rahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung,
                       vorberechnet: String? = nil) throws -> Frame {
        let mitIcon = icon != nil
        switch o.weg {
        case .pixel:
            guard passt(o, mitIcon: mitIcon) else {
                let iconBilder = icon.flatMap { i -> [[String?]]? in
                    try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
                } ?? []
                let uri = try vorberechnet.flatMap { $0.isEmpty ? nil : $0 }
                    ?? Textraster.laufschrift(
                        o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
                        farbe: o.farbe, schrittweite: o.tempo.schrittweite,
                        bilddauer: o.tempo.bilddauer, versatzY: versatzY(o),
                        iconBilder: iconBilder, iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
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
