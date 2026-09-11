import SwiftUI
import TC002Core

/// Zeigt das 52×16-Feld vergroessert. Weil Vorschau und Sendung aus demselben
/// Pixelfeld stammen, stimmt das Bild — es gibt keine zweite Rasterung, die abweichen könnte.
struct VorschauView: View {
    let feld: Pixelfeld
    var kantenlaenge: Double = 8

    var body: some View {
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
        .frame(width: Double(feld.breite) * kantenlaenge,
               height: Double(feld.hoehe) * kantenlaenge)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        .accessibilityLabel("Vorschau der Anzeige, 52 mal 16 Pixel")
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
}
