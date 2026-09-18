import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public extension Color {
    /// Wandelt "#RRGGBB" in eine Farbe. Ungültige Angaben ergeben nil.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((wert >> 16) & 0xFF) / 255,
                  green: Double((wert >> 8) & 0xFF) / 255,
                  blue: Double(wert & 0xFF) / 255)
    }

    /// "#RRGGBB" aus der Farbe. Über sRGB, damit derselbe Farbwert herauskommt,
    /// den die Uhr später anzeigt.
    ///
    /// Der Umweg über `CGColor.converted(to:)` ist nötig, nicht umständlich:
    /// Ein Farbwähler gibt auf einem P3-Schirm Display-P3 heraus, und wer die
    /// Komponenten ungerechnet abliest, bekommt für dieselbe optische Farbe je
    /// nach Gerät einen anderen Hexwert. Außerhalb des sRGB-Umfangs liegende
    /// Anteile werden geklammert.
    ///
    /// Abgeschnitten, nicht gerundet, und zwar mit Absicht: Nur so liefern Mac
    /// und Telefon für dieselbe Farbe zeichengleiche Hexwerte.
    ///
    /// Der Preis dafür ist gemessen: `Color` hält seine Anteile als `Float`,
    /// und `Float(18/255) * 255` ergibt 17,999998 — abgeschnitten also 17. 85
    /// der 256 Stufen überleben den Rundlauf deshalb nicht, darunter die
    /// Vorgabefarbe `#00FF66`, die als `#00FF65` zurückkommt — dieselbe
    /// Abweichung wie in der früheren Mac-Fassung
    /// (`Int(f.redComponent * 255)`). `FarbeTests` hält beides fest: die
    /// Stufen, die tragen, und das Abschneiden selbst.
    var hexWert: String {
        #if canImport(AppKit)
        let quelle = NSColor(self).cgColor
        #elseif canImport(UIKit)
        let quelle = UIColor(self).cgColor
        #endif
        guard let ziel = CGColorSpace(name: CGColorSpace.sRGB),
              let teile = quelle.converted(to: ziel, intent: .defaultIntent, options: nil)?.components,
              teile.count >= 3 else { return "#FFFFFF" }
        func stufe(_ wert: CGFloat) -> Int { Int(min(max(wert, 0), 1) * 255) }
        return String(format: "#%02X%02X%02X",
                      stufe(teile[0]), stufe(teile[1]), stufe(teile[2]))
    }
}
