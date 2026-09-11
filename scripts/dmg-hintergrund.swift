#!/usr/bin/env swift
// Zeichnet den Hintergrund des Installationsabbilds.
//
//   swift scripts/dmg-hintergrund.swift Resources/dmg-hintergrund.png
//
// Die Bildsprache ist die der Uhr: dunkler Grund, Pixelraster, gerasterte
// Schrift in Displaygruen. Der Text wird mit demselben Verfahren gesetzt wie
// in der App — CoreText ohne Glaettung, dann Pixel fuer Pixel als Quadrate —,
// damit das Abbild aussieht wie das Geraet, um das es geht.

import AppKit
import CoreText
import Foundation

let ziel = URL(fileURLWithPath: CommandLine.arguments.count > 1
               ? CommandLine.arguments[1] : "Resources/dmg-hintergrund.png")

// Fenstermass des Abbilds, doppelt aufgeloest fuer Bildschirme mit feiner Rasterung.
let breite = 660.0, hoehe = 420.0
let skala = 2.0

let grund      = NSColor(srgbRed: 0.051, green: 0.059, blue: 0.071, alpha: 1)  // #0D0F12
let raster     = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.035)
let gruen      = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.4, alpha: 1)        // #00FF66
let gedaempft  = NSColor(srgbRed: 0.62, green: 0.66, blue: 0.70, alpha: 1)

guard let ctx = CGContext(data: nil, width: Int(breite * skala), height: Int(hoehe * skala),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("Kein Zeichenkontext\n", stderr); exit(1)
}
ctx.scaleBy(x: skala, y: skala)
ctx.setShouldAntialias(true)

// --- Grund und Raster -------------------------------------------------------
ctx.setFillColor(grund.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: breite, height: hoehe))

ctx.setStrokeColor(raster.cgColor)
ctx.setLineWidth(0.5)
for x in stride(from: 0.0, through: breite, by: 10) {
    ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: hoehe))
}
for y in stride(from: 0.0, through: hoehe, by: 10) {
    ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: breite, y: y))
}
ctx.strokePath()

// --- Pixelschrift, wie sie die Uhr zeigt ------------------------------------
/// Rastert Text und malt jeden gesetzten Punkt als Quadrat. `kante` ist die
/// Kantenlaenge eines Displaypixels, `x`/`y` die linke obere Ecke in Punkten.
func pixelschrift(_ text: String, x: Double, y: Double, kante: Double,
                  groesse: Double, farbe: NSColor, luecke: Double = 1) {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, groesse, nil)
    let zeile = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: font, .foregroundColor: NSColor.white.cgColor]))
    let b = Int(CTLineGetTypographicBounds(zeile, nil, nil, nil).rounded()) + 2
    let h = Int(groesse.rounded()) + 4
    guard b > 0, let mess = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8,
                                      bytesPerRow: b, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
    mess.setShouldAntialias(false)
    mess.setShouldSmoothFonts(false)
    mess.setFillColor(gray: 0, alpha: 1)
    mess.fill(CGRect(x: 0, y: 0, width: b, height: h))
    mess.textPosition = CGPoint(x: 1, y: 3)
    CTLineDraw(zeile, mess)
    guard let roh = mess.data else { return }
    let puffer = roh.bindMemory(to: UInt8.self, capacity: b * h)

    ctx.setFillColor(farbe.cgColor)
    for zy in 0..<h {
        for zx in 0..<b where puffer[zy * b + zx] > 127 {
            // Der Bildspeicher beginnt oben links, die Zeichenflaeche zaehlt von
            // unten — ohne diese Spiegelung steht die Schrift auf dem Kopf.
            ctx.fill(CGRect(x: x + Double(zx) * kante,
                            y: y + Double(h - 1 - zy) * kante,
                            width: kante - luecke, height: kante - luecke))
        }
    }
}

/// Die Breite, die `pixelschrift` belegen wird — zum Mittigsetzen.
func pixelbreite(_ text: String, kante: Double, groesse: Double) -> Double {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, groesse, nil)
    let zeile = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: font]))
    return (CTLineGetTypographicBounds(zeile, nil, nil, nil).rounded() + 2) * kante
}

// --- Das Display oben -------------------------------------------------------
// Ein angedeutetes Geraet: dunkles Feld mit Rahmen, darin der Name in Pixeln.
let displayBreite = 360.0, displayHoehe = 62.0
let displayX = (breite - displayBreite) / 2, displayY = hoehe - 108
let display = CGRect(x: displayX, y: displayY, width: displayBreite, height: displayHoehe)

ctx.setFillColor(NSColor(srgbRed: 0.02, green: 0.02, blue: 0.03, alpha: 1).cgColor)
ctx.addPath(CGPath(roundedRect: display, cornerWidth: 8, cornerHeight: 8, transform: nil))
ctx.fillPath()
ctx.setStrokeColor(NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10).cgColor)
ctx.setLineWidth(1)
ctx.addPath(CGPath(roundedRect: display, cornerWidth: 8, cornerHeight: 8, transform: nil))
ctx.strokePath()

let titel = "MQTT-TC002"
let titelKante = 3.5, titelGroesse = 11.0
let titelBreite = pixelbreite(titel, kante: titelKante, groesse: titelGroesse)
pixelschrift(titel,
             x: displayX + (displayBreite - titelBreite) / 2,
             y: displayY + 18, kante: titelKante, groesse: titelGroesse, farbe: gruen)

// --- Der Pfeil zwischen den beiden Symbolen ---------------------------------
// Die Symbole setzt das Abbild selbst bei x=165 und x=495, y=220 (von oben).
// Hier wird von unten gezaehlt, also liegt die Mitte bei hoehe-220.
let pfeilY = hoehe - 228.0
let pfeilVon = 250.0, pfeilBis = 410.0
let block = 8.0

// Schaft: eine Reihe Bloecke mit Luecke, wie eine Pixelzeile auf dem Display.
ctx.setFillColor(gruen.withAlphaComponent(0.9).cgColor)
let spitzeAb = pfeilBis - 5 * block
for x in stride(from: pfeilVon, to: spitzeAb, by: block) {
    ctx.fill(CGRect(x: x, y: pfeilY, width: block - 2, height: block - 2))
}
// Spitze als Winkel aus zwei Schenkeln — eine Treppe aus Saeulen las sich als
// Kreuz, weil sie hoeher war als breit. Zwei Diagonalen sind eindeutig.
for k in 0..<5 {
    let x = pfeilBis - Double(k) * block
    for versatz in [Double(k), -Double(k)] {
        ctx.fill(CGRect(x: x, y: pfeilY + versatz * block,
                        width: block - 2, height: block - 2))
    }
}

// --- Die Aufforderung unten -------------------------------------------------
func setze(_ text: String, y: Double, groesse: Double, farbe: NSColor, fett: Bool) {
    let font = fett ? NSFont.systemFont(ofSize: groesse, weight: .semibold)
                    : NSFont.systemFont(ofSize: groesse, weight: .regular)
    let attribute: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: farbe]
    let zeile = NSAttributedString(string: text, attributes: attribute)
    let b = zeile.size().width
    let line = CTLineCreateWithAttributedString(zeile)
    ctx.textPosition = CGPoint(x: (breite - b) / 2, y: y)
    CTLineDraw(line, ctx)
}

setze("Zieh MQTT-TC002 in den Ordner „Programme“", y: 74, groesse: 15, farbe: .white, fett: true)
setze("Beim ersten Start fragt macOS nach Zugriff auf das lokale Netz —",
      y: 50, groesse: 11.5, farbe: gedaempft, fett: false)
setze("ohne den erreicht die App weder Uhr noch Broker.",
      y: 33, groesse: 11.5, farbe: gedaempft, fett: false)

// --- Schreiben --------------------------------------------------------------
guard let bild = ctx.makeImage() else { fputs("Kein Bild\n", stderr); exit(1) }
let rep = NSBitmapImageRep(cgImage: bild)
rep.size = NSSize(width: breite, height: hoehe)   // Punkte, nicht Pixel
guard let daten = rep.representation(using: .png, properties: [:]) else { exit(1) }
try? FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
try daten.write(to: ziel)
print("geschrieben: \(ziel.path) (\(Int(breite))×\(Int(hoehe)) Punkte, \(Int(skala))×)")
