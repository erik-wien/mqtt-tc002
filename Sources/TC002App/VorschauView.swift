import AppKit
import SwiftUI
import TC002Core

/// Zeigt das 52×16-Feld vergroessert. Weil Vorschau und Sendung aus demselben
/// Pixelfeld stammen, stimmt das Bild — es gibt keine zweite Rasterung, die abweichen könnte.
struct VorschauView: View {
    let feld: Pixelfeld
    var kantenlaenge: Double = 8
    /// Wird an derselben Stelle und in derselben Groesse gezeigt, an der die Uhr es
    /// spaeter zeichnet — sonst zeigt die Vorschau etwas anderes als das Geraet.
    var icon: URL? = nil
    var iconX: Int = 0
    var iconY: Int = 4

    /// Gecacht statt bei jedem Neuaufbau von der Platte gelesen — `NSImage(contentsOf:)`
    /// kostet eine Dateizugriff, `.task(id:)` laedt nur bei einer geaenderten Wahl neu.
    @State private var iconBild: NSImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { kontext, _ in
                for y in 0..<feld.hoehe {
                    for x in 0..<feld.breite {
                        let kaestchen = CGRect(x: Double(x) * kantenlaenge, y: Double(y) * kantenlaenge,
                                               width: kantenlaenge - 1, height: kantenlaenge - 1)
                        let farbe = feld.farbe(x: x, y: y).flatMap(Color.init(hex:)) ?? Color.black
                        kontext.fill(Path(kaestchen), with: .color(farbe))
                    }
                }
            }
            if let iconBild {
                Image(nsImage: iconBild)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: kantenlaenge * 8, height: kantenlaenge * 8)
                    .offset(x: Double(iconX) * kantenlaenge, y: Double(iconY) * kantenlaenge)
            }
        }
        .frame(width: Double(feld.breite) * kantenlaenge,
               height: Double(feld.hoehe) * kantenlaenge, alignment: .topLeading)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        .accessibilityLabel("Vorschau der Anzeige, 52 mal 16 Pixel")
        .task(id: icon) { iconBild = icon.flatMap(NSImage.init(contentsOf:)) }
    }
}

extension Color {
    /// Wandelt "#RRGGBB" in eine Farbe. Ungültige Angaben ergeben nil.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((wert >> 16) & 0xFF) / 255,
                  green: Double((wert >> 8) & 0xFF) / 255,
                  blue: Double(wert & 0xFF) / 255)
    }

    /// "#RRGGBB" aus der Farbe. Ueber sRGB, damit derselbe Farbwert herauskommt,
    /// den die Uhr spaeter anzeigt.
    var hexWert: String {
        let f = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "#%02X%02X%02X",
                      Int(f.redComponent * 255), Int(f.greenComponent * 255), Int(f.blueComponent * 255))
    }
}
