// `NSAttributedString.Key.font` und `.foregroundColor` sind hier keine
// Foundation-Konstanten: Foundation kennt nur den Schluesseltyp selbst, die
// vorgegebenen Schluessel kommen von der Oberflaechen-Bibliothek — unter
// macOS aus AppKit, unter iOS aus UIKit.
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import CoreText
import Foundation

/// Rastert Text selbst, statt ihn dem Geraet zu ueberlassen. Das macht die Vorschau
/// exakt — sie entsteht aus demselben Raster —, erlaubt Umlaute und Satzzeichen,
/// die der Geraetefont nicht kennt, und laesst die Schriftart frei waehlen.
public enum Textraster {
    /// Leerzeichen haben keine eigene Tinte — ihre Breite laesst sich also nicht
    /// aus gesetzten Pixeln ableiten. Feste Breite statt einer nackten Zahl im
    /// Aufruf; mit den Luecken davor und danach (siehe `rasterPuffer`) ergibt das
    /// einen deutlich sichtbaren Wortabstand.
    static let leerzeichenBreite = 2

    /// Erstellt die Schrift, wahlweise im fetten Schnitt — ueber die Merkmale,
    /// nicht ueber einen geratenen Schriftnamen, damit auch Schriften ohne eigene
    /// "…-Bold"-Variante einen fetten Schnitt liefern, sofern das System einen hat.
    private static func font(_ schrift: String, _ groesse: Double, fett: Bool) -> CTFont {
        let font = CTFontCreateWithName(schrift as CFString, groesse, nil)
        guard fett, let fetter = CTFontCreateCopyWithSymbolicTraits(
            font, groesse, nil, .boldTrait, .boldTrait) else { return font }
        return fetter
    }

    /// Baut den attribuierten Text fuer Breitenmessung und Rasterung. Kein
    /// Kern-Attribut mehr: der Abstand zwischen Zeichen entsteht beim
    /// Zusammensetzen der einzeln gerasterten Zeichen (siehe `rasterPuffer`),
    /// nicht ueber die eingebaute Unterschneidung der Schrift — die ist fuer
    /// gedruckte Groessen gemacht und faellt auf sechzehn Pixeln mal zu eng,
    /// mal zu weit aus.
    private static func attribuiert(_ text: String, schrift: String, groesse: Double, fett: Bool,
                                    vordergrund: CGColor?) -> NSAttributedString {
        var attribute: [NSAttributedString.Key: Any] = [.font: font(schrift, groesse, fett: fett)]
        if let vordergrund { attribute[.foregroundColor] = vordergrund }
        return NSAttributedString(string: text, attributes: attribute)
    }

    /// Rohe typografische Breite eines einzelnen Zeichens — nur als Puffergroesse
    /// fuers Rastern gedacht (`zeichenTinte`), nicht als Antwort auf „wie breit
    /// wird der Text“. Die beantwortet `breite(...)` unten, ueber dieselbe
    /// Rechnung wie `rasterPuffer`.
    private static func schriftBreite(_ text: String, schrift: String, groesse: Double, fett: Bool) -> Int {
        guard !text.isEmpty else { return 0 }
        let zeile = CTLineCreateWithAttributedString(
            attribuiert(text, schrift: schrift, groesse: groesse, fett: fett, vordergrund: nil))
        return Int(CTLineGetTypographicBounds(zeile, nil, nil, nil).rounded())
    }

    /// Breite des zusammengesetzten Textes in Pixeln — dieselbe Rechnung wie
    /// `rasterPuffer`, damit „passt“/„passt nicht“ (siehe `SendenView.passt`)
    /// zum tatsaechlich gerasterten Ergebnis passt.
    public static func breite(_ text: String, schrift: String, groesse: Double, fett: Bool = false, luecke: Int = 0) -> Int {
        guard !text.isEmpty else { return 0 }
        return rasterPuffer(text, schrift: schrift, groesse: groesse, fett: fett, farbe: "#FFFFFF", luecke: luecke).breite
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

        let zeile = CTLineCreateWithAttributedString(
            attribuiert(text, schrift: schrift, groesse: groesse, fett: fett, vordergrund: CGColor(gray: 1, alpha: 1)))
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

    /// Bewirkt der fette Schnitt bei dieser Schrift und Groesse ueberhaupt etwas?
    ///
    /// Gemessen, nicht aus einer Liste gelesen: Manche Schriften haben keinen
    /// fetten Schnitt, bei anderen faellt er auf wenigen Pixeln mit dem normalen
    /// zusammen. Beides macht den Knopf wirkungslos, und ein Knopf ohne Wirkung
    /// ist schlimmer als keiner.
    public static func kannFett(schrift: String, groesse: Double) -> Bool {
        pruefung(schluessel: "fett|\(schrift)|\(groesse)") {
            rasterPuffer("Hallo", schrift: schrift, groesse: groesse, fett: false, farbe: "#FFFFFF")
                != rasterPuffer("Hallo", schrift: schrift, groesse: groesse, fett: true, farbe: "#FFFFFF")
        }
    }

    /// Kennt diese Schrift eigene Kleinbuchstaben, oder setzt sie alles in
    /// Versalien? Silkscreen etwa kennt keine — der Grossbuchstaben-Schalter
    /// bleibt dort ohne sichtbare Wirkung.
    public static func kannKleinbuchstaben(schrift: String, groesse: Double) -> Bool {
        pruefung(schluessel: "klein|\(schrift)|\(groesse)") {
            rasterPuffer("abc", schrift: schrift, groesse: groesse, fett: false, farbe: "#FFFFFF")
                != rasterPuffer("ABC", schrift: schrift, groesse: groesse, fett: false, farbe: "#FFFFFF")
        }
    }

    /// Beide Pruefungen rastern, das lohnt sich nur einmal je Schrift und Groesse.
    private static let sperre = NSLock()
    private static var gemerkt: [String: Bool] = [:]
    private static func pruefung(schluessel: String, _ messen: () -> Bool) -> Bool {
        // Das Schloss bleibt ueber die Messung: zwei Aufrufer mit derselben
        // Kombination sollen nicht beide rastern, sondern der zweite wartet.
        sperre.lock(); defer { sperre.unlock() }
        if let da = gemerkt[schluessel] { return da }
        let wert = messen()
        gemerkt[schluessel] = wert
        return wert
    }

    /// Erste und letzte **Zeile** mit mindestens einem gesetzten Pixel, oder `nil`
    /// bei leerem Feld. Die Gegenstueck zu `tintenSpalten` — und die Grundlage
    /// jeder senkrechten Ausrichtung: `rasterPuffer` legt die Tinte dorthin, wo
    /// die Grundlinie der Schrift sie hinlegt, nicht an den oberen Rand. Wer sie
    /// ausrichten will, muss erst wissen, wo sie liegt.
    public static func tintenZeilen(_ feld: Pixelfeld) -> (erste: Int, letzte: Int)? {
        var erste: Int?, letzte: Int?
        for zeile in 0..<feld.hoehe {
            let belegt = (0..<feld.breite).contains { feld.farbe(x: $0, y: zeile) != nil }
            if belegt {
                if erste == nil { erste = zeile }
                letzte = zeile
            }
        }
        guard let e = erste, let l = letzte else { return nil }
        return (e, l)
    }

    /// Erste und letzte Spalte mit mindestens einem gesetzten Pixel, oder `nil`,
    /// wenn das Feld ganz leer ist.
    private static func tintenSpalten(_ feld: Pixelfeld) -> (erste: Int, letzte: Int)? {
        var erste: Int?, letzte: Int?
        for spalte in 0..<feld.breite {
            guard (0..<feld.hoehe).contains(where: { feld.farbe(x: spalte, y: $0) != nil }) else { continue }
            if erste == nil { erste = spalte }
            letzte = spalte
        }
        guard let e = erste, let l = letzte else { return nil }
        return (e, l)
    }

    /// Rastert ein einzelnes Zeichen ueber die volle Displayhoehe und beschneidet
    /// es waagrecht auf die Spalten mit gesetzten Pixeln — nur diese Tinte zaehlt
    /// beim Zusammensetzen (siehe `rasterPuffer`), nicht die Vorschubbreite der
    /// Schrift. Senkrecht wird nie beschnitten: sonst saessen Buchstaben mit und
    /// ohne Unterlaenge auf verschiedenen Hoehen, und Umlautpunkte verschwaenden.
    /// Leerzeichen haben keine Tinte und bekommen stattdessen die feste Breite
    /// `leerzeichenBreite`.
    private static func zeichenTinte(_ zeichen: Character, schrift: String, groesse: Double,
                                     fett: Bool, farbe: String) -> Pixelfeld {
        guard zeichen != " " else {
            return Pixelfeld(breite: leerzeichenBreite, hoehe: Pixelfeld.hoeheStandard)
        }
        let text = String(zeichen)
        // Grosszuegiger Puffer, immer an derselben Stelle gerastert (x 4) — sonst
        // entscheidet der Zufall der Phase, welche Punkte bei ungeglaetteter
        // Schrift den Schwellwert von 127 ueberschreiten (siehe `rastern`).
        let breite = schriftBreite(text, schrift: schrift, groesse: groesse, fett: fett) + 12
        var roh = Pixelfeld(breite: breite, hoehe: Pixelfeld.hoeheStandard)
        rastern(text, schrift: schrift, groesse: groesse, farbe: farbe, x: 4, y: 0, feld: &roh, fett: fett)

        guard let (erste, letzte) = tintenSpalten(roh) else {
            return Pixelfeld(breite: 0, hoehe: Pixelfeld.hoeheStandard)
        }
        var ausschnitt = Pixelfeld(breite: letzte - erste + 1, hoehe: Pixelfeld.hoeheStandard)
        for zeile in 0..<roh.hoehe {
            for spalte in erste...letzte {
                guard let f = roh.farbe(x: spalte, y: zeile) else { continue }
                ausschnitt.setzen(x: spalte - erste, y: zeile, farbe: f)
            }
        }
        return ausschnitt
    }

    /// Rastert den Text Zeichen fuer Zeichen und setzt die Ausschnitte nach der
    /// Tinte aneinander, mit `luecke` leeren Spalten dazwischen — nicht nach den
    /// Vorschubbreiten der Schrift, die fuer gedruckte Groessen gemacht sind und
    /// auf sechzehn Pixeln mal zu eng, mal zu weit ausfallen. Der Abstand sitzt
    /// nur zwischen den Zeichen, nicht nach dem letzten.
    ///
    /// Jedes Zeichen wird fuer sich in derselben Phase gerastert (siehe
    /// `zeichenTinte`) und danach nur noch kopiert, nie erneut an anderer Stelle
    /// gerastert — genau das haette bei ungeglaetteter Schrift dieselben Zeichen
    /// mal duenner, mal dicker aussehen lassen.
    public static func rasterPuffer(_ text: String, schrift: String, groesse: Double,
                                    fett: Bool, farbe: String, luecke: Int = 0) -> Pixelfeld {
        let luecke = max(0, luecke)
        let zeichen = text.map { zeichenTinte($0, schrift: schrift, groesse: groesse, fett: fett, farbe: farbe) }
        let tintenbreite = zeichen.reduce(0) { $0 + $1.breite }
        let gesamtbreite = tintenbreite + luecke * max(0, zeichen.count - 1)
        var puffer = Pixelfeld(breite: max(gesamtbreite, 1), hoehe: Pixelfeld.hoeheStandard)

        var x = 0
        for (index, ausschnitt) in zeichen.enumerated() {
            einsetzen(ausschnitt, x: x, y: 0, in: &puffer)
            x += ausschnitt.breite
            if index < zeichen.count - 1 { x += luecke }
        }
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

    /// Lage eines Icons im Bild: quadratisch, senkrecht mittig, dahinter zwei
    /// Spalten Luft, bevor der Text beginnt. Die Kante ist ein Parameter, kein
    /// fester Wert — bei 8×8 sitzt es auf Zeile 4, bei 16×16 auf Zeile 0 und
    /// fuellt die volle Hoehe.
    static let iconLuecke = 2
    static func iconY(kante: Int) -> Int { (Pixelfeld.hoeheStandard - kante) / 2 }

    /// Laesst ein 52×16-Fenster ueber den gerasterten Text wandern — ein
    /// Einzelbild je `schrittweite` Pixel Versatz, von vollstaendig vor dem Text
    /// bis vollstaendig dahinter. Der gemeinsame Kern fuer die abspielende
    /// Vorschau (braucht die Farbraster direkt) und `laufschrift` unten (kodiert
    /// sie zu einem GIF) — siehe `docs/tc002-protokoll.md` §4.2a.
    ///
    /// `versatzY` verschiebt den Text senkrecht, genau wie im stehenden Weg — die
    /// Ausrichtung der Formatleiste gilt also auch hier.
    ///
    /// `iconBilder` sind die Einzelbilder eines Icons (je `iconKante` im Quadrat
    /// Eintraege, zeilenweise von oben links) oder leer. Sie werden **eingebacken**, statt
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
                                               iconBilder: [[String?]] = [], iconKante: Int = 8,
                                               iconLaeuftMit: Bool = false, luecke: Int = 0) -> [Bildraster.Einzelbild] {
        let puffer = rasterPuffer(text, schrift: schrift, groesse: groesse, fett: fett, farbe: farbe, luecke: luecke)
        let hatIcon = !iconBilder.isEmpty
        let iconY = iconY(kante: iconKante)
        let festesIcon = hatIcon && !iconLaeuftMit
        let fensterBreite = Pixelfeld.breiteStandard
        // Wo im Fenster der Text beginnt (feststehendes Icon) und wo er im
        // laufenden Band beginnt (mitlaufendes Icon).
        let fensterTextAb = festesIcon ? iconKante + iconLuecke : 0
        let bandTextAb = iconLaeuftMit ? iconKante + iconLuecke : 0
        let textbereich = fensterBreite - fensterTextAb
        // Der Puffer ist exakt so breit wie die Tinte plus die Luecken — keine
        // Zugabe mehr, die hier herausgerechnet werden muesste.
        let bandBreite = bandTextAb + puffer.breite
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
                                                iconBild: iconBild, iconKante: iconKante,
                                                iconY: iconY) else { continue }
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
                                  iconBild: [String?]?, iconKante: Int, iconY: Int) -> String? {
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
                                   iconBilder: [[String?]] = [], iconKante: Int = 8,
                                   iconLaeuftMit: Bool = false, luecke: Int = 0) throws -> String {
        let bilder = laufschriftEinzelbilder(text, schrift: schrift, groesse: groesse, fett: fett,
                                             farbe: farbe, schrittweite: schrittweite,
                                             bilddauer: bilddauer, versatzY: versatzY,
                                             iconBilder: iconBilder, iconKante: iconKante,
                                             iconLaeuftMit: iconLaeuftMit, luecke: luecke)
        return try Bildraster.alsDatenURI(bilder.map(\.pixel), breite: Pixelfeld.breiteStandard,
                                          hoehe: Pixelfeld.hoeheStandard, verzoegerung: bilddauer)
    }
}
