import AppKit
import SwiftUI
import TC002Core

/// Zeigt das 52×16-Feld vergroessert. Weil Vorschau und Sendung aus demselben
/// Pixelfeld stammen, stimmt das Bild — es gibt keine zweite Rasterung, die abweichen könnte.
///
/// Ein animiertes Icon spielt hier probeweise ab — als Pixel im selben Raster,
/// nicht als Bilddatei darueber, damit Lage und Groesse exakt die bleiben, mit
/// der die Uhr das Icon zusammen mit dem Text bekommt. Ob die Uhr selbst ein
/// animiertes Icon abspielt, ist damit nicht gezeigt und nicht geprueft — siehe
/// Hilfe → Senden.
struct VorschauView: View {
    let feld: Pixelfeld
    var kantenlaenge: Double = 8
    /// Wird an derselben Stelle und in derselben Groesse gezeigt, an der die Uhr es
    /// spaeter zeichnet — sonst zeigt die Vorschau etwas anderes als das Geraet.
    var icon: URL? = nil
    var iconX: Int = 0
    var iconY: Int = 4

    /// Einzelbilder des gewaehlten Icons mit ihren Standzeiten — einmal je
    /// Iconwechsel geladen (`.task(id:)`), nicht bei jedem Neuzeichnen. Ein
    /// unbewegtes Icon hat genau eines und bleibt stehen.
    @State private var einzelbilder: [Bildraster.Einzelbild] = []

    var body: some View {
        Group {
            if einzelbilder.count > 1 {
                TimelineView(.animation) { zeitpunkt in
                    rahmen(iconBild: einzelbild(bei: zeitpunkt.date))
                }
            } else {
                rahmen(iconBild: einzelbilder.first)
            }
        }
        .frame(width: Double(feld.breite) * kantenlaenge,
               height: Double(feld.hoehe) * kantenlaenge, alignment: .topLeading)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        .accessibilityLabel("Vorschau der Anzeige, 52 mal 16 Pixel")
        .task(id: icon) { einzelbilder = Self.geladen(icon) }
    }

    private func rahmen(iconBild: Bildraster.Einzelbild?) -> some View {
        Canvas { kontext, _ in
            for y in 0..<feld.hoehe {
                for x in 0..<feld.breite {
                    let kaestchen = CGRect(x: Double(x) * kantenlaenge, y: Double(y) * kantenlaenge,
                                           width: kantenlaenge - 1, height: kantenlaenge - 1)
                    let farbe = feld.farbe(x: x, y: y).flatMap(Color.init(hex:)) ?? Color.black
                    kontext.fill(Path(kaestchen), with: .color(farbe))
                }
            }
            guard let iconBild else { return }
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let hex = iconBild.pixel[y * 8 + x], let farbe = Color(hex: hex) else { continue }
                    let px = iconX + x, py = iconY + y
                    guard px >= 0, py >= 0, px < feld.breite, py < feld.hoehe else { continue }
                    let kaestchen = CGRect(x: Double(px) * kantenlaenge, y: Double(py) * kantenlaenge,
                                           width: kantenlaenge - 1, height: kantenlaenge - 1)
                    kontext.fill(Path(kaestchen), with: .color(farbe))
                }
            }
        }
    }

    /// Waehlt anhand der verstrichenen Zeit das faellige Einzelbild — in Schleife
    /// ueber alle, jedes mit seiner eigenen Standzeit.
    private func einzelbild(bei zeitpunkt: Date) -> Bildraster.Einzelbild? {
        guard !einzelbilder.isEmpty else { return nil }
        let gesamt = einzelbilder.reduce(0) { $0 + $1.dauer }
        guard gesamt > 0 else { return einzelbilder.first }
        var rest = zeitpunkt.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: gesamt)
        for bild in einzelbilder {
            if rest < bild.dauer { return bild }
            rest -= bild.dauer
        }
        return einzelbilder.last
    }

    private static func geladen(_ icon: URL?) -> [Bildraster.Einzelbild] {
        guard let icon else { return [] }
        return (try? Bildraster.lesenMitZeiten(icon, breite: 8, hoehe: 8)) ?? []
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
