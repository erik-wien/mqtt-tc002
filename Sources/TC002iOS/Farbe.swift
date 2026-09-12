import SwiftUI

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

    /// "#RRGGBB" aus der Farbe. Über sRGB, damit derselbe Farbwert
    /// herauskommt, den die Uhr später anzeigt. Die Mac-Fassung
    /// (`Sources/TC002App/VorschauView.swift:119`) nimmt dafür `NSColor`;
    /// unter iOS heißt dasselbe `UIColor`, und die Komponenten kommen über
    /// `getRed(_:green:blue:alpha:)` statt über Eigenschaften.
    var hexWert: String {
        // Der Umweg ueber CGColor ist noetig, nicht umstaendlich:
        // `getRed(_:green:blue:alpha:)` rechnet **nicht** um, sondern liefert die
        // Komponenten im Farbraum der Farbe. Ein iPhone-Farbwaehler gibt Display-P3
        // heraus; ohne diese Umrechnung kaeme fuer dieselbe optische Farbe ein
        // anderer Hexwert heraus als am Mac. Ausserhalb des sRGB-Umfangs liegende
        // Anteile werden dabei geklammert, und truncated wie am Mac gerundet.
        guard let ziel = CGColorSpace(name: CGColorSpace.sRGB),
              let teile = UIColor(self).cgColor
                  .converted(to: ziel, intent: .defaultIntent, options: nil)?.components,
              teile.count >= 3 else { return "#FFFFFF" }
        func stufe(_ wert: CGFloat) -> Int { Int(min(max(wert, 0), 1) * 255) }
        return String(format: "#%02X%02X%02X",
                      stufe(teile[0]), stufe(teile[1]), stufe(teile[2]))
    }
}
