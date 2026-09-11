import AppKit
import CoreText
import Foundation

/// Rastert Text selbst, statt ihn dem Geraet zu ueberlassen. Das macht die Vorschau
/// exakt — sie entsteht aus demselben Raster —, erlaubt Umlaute und Satzzeichen,
/// die der Geraetefont nicht kennt, und laesst die Schriftart frei waehlen.
public enum Textraster {
    public static func breite(_ text: String, schrift: String, groesse: Double) -> Int {
        guard !text.isEmpty else { return 0 }
        let font = CTFontCreateWithName(schrift as CFString, groesse, nil)
        let zeile = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]))
        return Int(CTLineGetTypographicBounds(zeile, nil, nil, nil).rounded())
    }

    public static func rastern(_ text: String, schrift: String, groesse: Double,
                               farbe: String, x: Int, y: Int, feld: inout Pixelfeld) {
        guard !text.isEmpty else { return }
        let b = feld.breite, h = feld.hoehe

        guard let ctx = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8,
                                  bytesPerRow: b, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        ctx.setShouldAntialias(false)
        ctx.setShouldSmoothFonts(false)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: b, height: h))

        let font = CTFontCreateWithName(schrift as CFString, groesse, nil)
        let zeile = CTLineCreateWithAttributedString(NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: NSColor.white.cgColor]))
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
}
