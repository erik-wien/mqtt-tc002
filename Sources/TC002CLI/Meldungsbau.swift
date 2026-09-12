import Foundation
import TC002Core

/// Baut aus den Optionen den Rahmen, den die Uhr bekommt.
///
/// Dieselben drei Faelle wie in der App: eigenes Raster, Laufschrift als GIF
/// (wenn der Text nicht in die Breite passt), oder ein Textblock, den die Uhr
/// mit ihrer eingebauten Schrift selbst setzt. Gerechnet wird mit denselben
/// Funktionen aus `Textraster` — die Ausrichtung ist am Bildschirm erarbeitet
/// worden und soll hier nicht ein zweites Mal erfunden werden.
enum Meldungsbau {
    /// Wo das Icon endet: acht Pixel breit, zwei Pixel Luft.
    static let iconBreite = 10

    static func rahmen(text: String, optionen o: Optionen,
                       icon: Icon?, sammlung: Iconsammlung) throws -> Frame {
        let flaecheX = icon == nil ? 0 : iconBreite
        let flaecheBreite = Pixelfeld.breiteStandard - flaecheX
        let iconURI = try icon.map { try sammlung.datenURI(fuer: $0) }

        if o.geraeteschrift {
            var block = Textblock(inhalt: text)
            block.schrifthoehe = Int(o.groesse)
            block.x = flaecheX
            block.y = 0
            block.farbe = o.farbe
            block.ausrichtung = o.geraeteAusrichtung
            block.vertikal = o.geraeteVertikal
            block.flaeche = [flaecheX, 0, flaecheBreite, Pixelfeld.hoeheStandard]
            var frame = Frame(texte: [block], dauer: o.dauer)
            if let iconURI { frame.bilder.append(Bild(datenURI: iconURI, x: 0, y: 4)) }
            return frame
        }

        let puffer = Textraster.rasterPuffer(text, schrift: o.schrift, groesse: o.groesse,
                                             fett: o.fett, farbe: o.farbe, luecke: o.abstand)
        let breite = Textraster.breite(text, schrift: o.schrift, groesse: o.groesse,
                                       fett: o.fett, luecke: o.abstand)
        let y = versatzY(puffer: puffer, optionen: o)

        guard breite <= flaecheBreite else {
            // Zu langer Text ist kein Fehler, sondern der Grund fuers Laufen.
            let iconBilder = icon.flatMap { i -> [[String?]]? in
                try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
            } ?? []
            let uri = try Textraster.laufschrift(
                text, schrift: o.schrift, groesse: o.groesse, fett: o.fett, farbe: o.farbe,
                schrittweite: 1, bilddauer: o.tempo.bilddauer, versatzY: y,
                iconBilder: iconBilder, iconLaeuftMit: false, luecke: o.abstand)
            return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: o.dauer)
        }

        var feld = Pixelfeld()
        Textraster.einsetzen(puffer, x: versatzX(breite: breite, flaecheX: flaecheX,
                                                 flaecheBreite: flaecheBreite, optionen: o),
                             y: y, in: &feld)
        var frame = Frame(draw: feld.alsDrawBefehle(), dauer: o.dauer)
        if let iconURI { frame.bilder.append(Bild(datenURI: iconURI, x: 0, y: 4)) }
        return frame
    }

    /// Senkrechte Ausrichtung ueber die tatsaechliche Tinte, nicht ueber die
    /// Schriftgroesse: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    static func versatzY(puffer: Pixelfeld, optionen o: Optionen) -> Int {
        guard let tinte = Textraster.tintenZeilen(puffer) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        // Mehr Rand, als Platz da ist, gaebe es nicht.
        let r = min(o.rand, max(0, (Pixelfeld.hoeheStandard - hoehe) / 2))
        switch o.senkrecht {
        case .oben:  return -tinte.erste + r
        case .mitte: return (Pixelfeld.hoeheStandard - hoehe) / 2 - tinte.erste
        case .unten: return (Pixelfeld.hoeheStandard - hoehe) - tinte.erste - r
        }
    }

    static func versatzX(breite: Int, flaecheX: Int, flaecheBreite: Int, optionen o: Optionen) -> Int {
        switch o.waagrecht {
        case .links:  return flaecheX
        case .mitte:  return flaecheX + max(0, (flaecheBreite - breite) / 2)
        case .rechts: return flaecheX + max(0, flaecheBreite - breite)
        }
    }
}
