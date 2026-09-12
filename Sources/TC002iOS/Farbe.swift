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
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
