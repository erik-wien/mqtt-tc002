import AppKit
import CoreText
import Foundation

/// Rastert Text selbst, statt ihn dem Geraet zu ueberlassen. Das macht die Vorschau
/// exakt — sie entsteht aus demselben Raster —, erlaubt Umlaute und Satzzeichen,
/// die der Geraetefont nicht kennt, und laesst die Schriftart frei waehlen.
public enum Textraster {
    /// Erstellt die Schrift, wahlweise im fetten Schnitt — ueber die Merkmale,
    /// nicht ueber einen geratenen Schriftnamen, damit auch Schriften ohne eigene
    /// "…-Bold"-Variante einen fetten Schnitt liefern, sofern das System einen hat.
    private static func font(_ schrift: String, _ groesse: Double, fett: Bool) -> CTFont {
        let font = CTFontCreateWithName(schrift as CFString, groesse, nil)
        guard fett, let fetter = CTFontCreateCopyWithSymbolicTraits(
            font, groesse, nil, .boldTrait, .boldTrait) else { return font }
        return fetter
    }

    public static func breite(_ text: String, schrift: String, groesse: Double, fett: Bool = false) -> Int {
        guard !text.isEmpty else { return 0 }
        let zeile = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font(schrift, groesse, fett: fett)]))
        return Int(CTLineGetTypographicBounds(zeile, nil, nil, nil).rounded())
    }

    /// Hoehe der gesetzten Flaeche in Pixeln — nicht die Schriftgroesse, sondern was
    /// wirklich schwarz wird. Nur damit laesst sich senkrecht mitteln.
    public static func hoehe(_ text: String, schrift: String, groesse: Double, fett: Bool) -> Int {
        guard !text.isEmpty else { return 0 }
        let zeile = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font(schrift, groesse, fett: fett)]))
        let bounds = CTLineGetBoundsWithOptions(zeile, .useOpticalBounds)
        return Int(bounds.height.rounded(.up))
    }

    public static func rastern(_ text: String, schrift: String, groesse: Double,
                               farbe: String, x: Int, y: Int, feld: inout Pixelfeld, fett: Bool = false) {
        guard !text.isEmpty else { return }
        let b = feld.breite, h = feld.hoehe

        guard let ctx = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8,
                                  bytesPerRow: b, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        ctx.setShouldAntialias(false)
        ctx.setShouldSmoothFonts(false)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: b, height: h))

        let zeile = CTLineCreateWithAttributedString(NSAttributedString(
            string: text, attributes: [.font: font(schrift, groesse, fett: fett),
                                       .foregroundColor: NSColor.white.cgColor]))
        // Quartz zaehlt von unten: die Grundlinie liegt bei Hoehe minus y minus Schriftgroesse.
        ctx.textPosition = CGPoint(x: Double(x), y: Double(h - y) - groesse)
        CTLineDraw(zeile, ctx)

        guard let roh = ctx.data else { return }
        let puffer = roh.bindMemory(to: UInt8.self, capacity: b * h)
        // Der Bildspeicher beginnt oben links — hier wird NICHT gespiegelt.
        for zeileIdx in 0..<h {
            for spalte in 0..<b where puffer[zeileIdx * b + spalte] > 127 {
                feld.setzen(x: spalte, y: zeileIdx, farbe: farbe)
            }
        }
    }

    /// Rastert den Text in einen eigenen Puffer, immer in derselben Phase:
    /// x 0, y 0, volle Displayhoehe. Ausrichtung wird danach angewandt, indem das
    /// fertige Raster verschoben wird (`einsetzen`), nicht indem an anderer Stelle
    /// gerastert wird.
    ///
    /// Der Grund ist nicht Ordnungsliebe: bei 11 Punkt ohne Kantenglaettung
    /// entscheidet ein Pixel Versatz darueber, welche Punkte den Schwellwert von
    /// 127 ueberschreiten. Wer an zwei Stellen mit verschiedenem x rastert, bekommt
    /// dieselbe Schrift einmal duenner und einmal dicker — sichtbar, sobald die
    /// stehende Vorschau neben der laufenden steht.
    public static func rasterPuffer(_ text: String, schrift: String, groesse: Double,
                                    fett: Bool, farbe: String) -> Pixelfeld {
        // Zwei Spalten Zugabe: die typografische Breite rundet ab, die letzte
        // Glyphe darf daran nicht haengenbleiben.
        let spalten = max(breite(text, schrift: schrift, groesse: groesse, fett: fett) + 2, 1)
        var puffer = Pixelfeld(breite: spalten, hoehe: Pixelfeld.hoeheStandard)
        rastern(text, schrift: schrift, groesse: groesse, farbe: farbe,
                x: 0, y: 0, feld: &puffer, fett: fett)
        return puffer
    }

    /// Legt ein fertiges Raster an eine Stelle des Feldes. Nur gesetzte Punkte
    /// wandern mit — was darunter liegt, bleibt sonst stehen.
    public static func einsetzen(_ quelle: Pixelfeld, x: Int, y: Int, in feld: inout Pixelfeld) {
        for zeile in 0..<quelle.hoehe {
            for spalte in 0..<quelle.breite {
                guard let farbe = quelle.farbe(x: spalte, y: zeile) else { continue }
                feld.setzen(x: x + spalte, y: y + zeile, farbe: farbe)
            }
        }
    }

    /// Lage eines Icons im Bild: acht mal acht Punkte, senkrecht mittig, dahinter
    /// zwei Spalten Luft, bevor der Text beginnt.
    static let iconKante = 8
    static let iconY = 4
    static let iconLuecke = 2

    /// Laesst ein 52×16-Fenster ueber den gerasterten Text wandern — ein
    /// Einzelbild je `schrittweite` Pixel Versatz, von vollstaendig vor dem Text
    /// bis vollstaendig dahinter. Der gemeinsame Kern fuer die abspielende
    /// Vorschau (braucht die Farbraster direkt) und `laufschrift` unten (kodiert
    /// sie zu einem GIF) — siehe `docs/tc002-protokoll.md` §4.2a.
    ///
    /// `versatzY` verschiebt den Text senkrecht, genau wie im stehenden Weg — die
    /// Ausrichtung der Formatleiste gilt also auch hier.
    ///
    /// `iconBilder` sind die Einzelbilder eines 8×8-Icons (je 64 Eintraege,
    /// zeilenweise von oben links) oder leer. Sie werden **eingebacken**, statt
    /// als zweites `image` neben dem Lauf-GIF im Rahmen zu stehen: ob die Uhr
    /// zwei Bilder nebeneinander zeichnet oder das zweite das erste ersetzt, hat
    /// niemand geprueft. Ein animiertes Icon laeuft dabei mit, Bild fuer Bild.
    ///
    /// `iconLaeuftMit` entscheidet, wo es steht: standardmaessig fest links,
    /// waehrend der Text in den Spalten rechts daneben durchlaeuft — die Spalten
    /// unter dem Icon bleiben dabei in jedem Einzelbild schwarz, sonst blitzte
    /// der Text zwischen den Iconpunkten hindurch. Laeuft es mit, steht es am
    /// Anfang des Bandes und wandert mit hinaus; der Text nutzt dann alle Spalten.
    public static func laufschriftEinzelbilder(_ text: String, schrift: String, groesse: Double,
                                               fett: Bool, farbe: String, schrittweite: Int,
                                               bilddauer: Double, versatzY: Int = 0,
                                               iconBilder: [[String?]] = [],
                                               iconLaeuftMit: Bool = false) -> [Bildraster.Einzelbild] {
        let puffer = rasterPuffer(text, schrift: schrift, groesse: groesse, fett: fett, farbe: farbe)
        let hatIcon = !iconBilder.isEmpty
        let festesIcon = hatIcon && !iconLaeuftMit
        let fensterBreite = Pixelfeld.breiteStandard
        // Wo im Fenster der Text beginnt (feststehendes Icon) und wo er im
        // laufenden Band beginnt (mitlaufendes Icon).
        let fensterTextAb = festesIcon ? iconKante + iconLuecke : 0
        let bandTextAb = iconLaeuftMit ? iconKante + iconLuecke : 0
        let textbereich = fensterBreite - fensterTextAb
        // Ueber die typografische Breite, nicht ueber die des Puffers: dessen zwei
        // Spalten Zugabe sollen die letzte Glyphe auffangen, nicht den Lauf verlaengern.
        let bandBreite = bandTextAb + breite(text, schrift: schrift, groesse: groesse, fett: fett)
        let schritt = max(1, schrittweite)

        var einzelbilder: [Bildraster.Einzelbild] = []
        for (n, versatz) in stride(from: -textbereich, through: bandBreite, by: schritt).enumerated() {
            var fenster = [String?](repeating: nil, count: fensterBreite * Pixelfeld.hoeheStandard)
            let iconBild = hatIcon ? iconBilder[n % iconBilder.count] : nil

            for spalte in fensterTextAb..<fensterBreite {
                let bandSpalte = versatz + (spalte - fensterTextAb)
                for zeile in 0..<Pixelfeld.hoeheStandard {
                    guard let punkt = bandpunkt(bandSpalte, zeile, puffer: puffer, versatzY: versatzY,
                                                bandTextAb: bandTextAb, iconLaeuftMit: iconLaeuftMit,
                                                iconBild: iconBild) else { continue }
                    fenster[zeile * fensterBreite + spalte] = punkt
                }
            }
            if festesIcon, let iconBild {
                for y in 0..<iconKante {
                    for x in 0..<iconKante {
                        guard let punkt = iconBild[y * iconKante + x] else { continue }
                        fenster[(iconY + y) * fensterBreite + x] = punkt
                    }
                }
            }
            einzelbilder.append(Bildraster.Einzelbild(pixel: fenster, dauer: bilddauer))
        }
        return einzelbilder
    }

    /// Ein Punkt des laufenden Bandes: links das mitlaufende Icon, ab `bandTextAb`
    /// der gerasterte Text. Ausserhalb ist nichts — dort bleibt das Bild schwarz.
    private static func bandpunkt(_ spalte: Int, _ zeile: Int, puffer: Pixelfeld, versatzY: Int,
                                  bandTextAb: Int, iconLaeuftMit: Bool,
                                  iconBild: [String?]?) -> String? {
        if iconLaeuftMit, spalte < iconKante {
            guard spalte >= 0, let iconBild else { return nil }
            let y = zeile - iconY
            guard y >= 0, y < iconKante else { return nil }
            return iconBild[y * iconKante + spalte]
        }
        let x = spalte - bandTextAb
        let y = zeile - versatzY
        guard x >= 0, x < puffer.breite, y >= 0, y < puffer.hoehe else { return nil }
        return puffer.farbe(x: x, y: y)
    }

    /// Wie `laufschriftEinzelbilder`, aber als kodiertes, animiertes GIF in Form
    /// einer Daten-URI, wie `image` es erwartet — ein einziges Bild im Rahmen,
    /// Icon eingebacken.
    public static func laufschrift(_ text: String, schrift: String, groesse: Double,
                                   fett: Bool, farbe: String, schrittweite: Int,
                                   bilddauer: Double, versatzY: Int = 0,
                                   iconBilder: [[String?]] = [],
                                   iconLaeuftMit: Bool = false) throws -> String {
        let bilder = laufschriftEinzelbilder(text, schrift: schrift, groesse: groesse, fett: fett,
                                             farbe: farbe, schrittweite: schrittweite,
                                             bilddauer: bilddauer, versatzY: versatzY,
                                             iconBilder: iconBilder, iconLaeuftMit: iconLaeuftMit)
        return try Bildraster.alsDatenURI(bilder.map(\.pixel), breite: Pixelfeld.breiteStandard,
                                          hoehe: Pixelfeld.hoeheStandard, verzoegerung: bilddauer)
    }
}
