import SwiftUI
import TC002Core

/// Das Display, 52×16 Pixel, sechsfach vergroessert. Zeigt entweder ein
/// stehendes Feld oder spielt die Einzelbilder der Laufschrift ab.
struct VorschauiOS: View {
    let feld: Pixelfeld
    let icon: URL?
    let laufschriftBilder: [Bildraster.Einzelbild]?
    var kante: Double = 6

    var body: some View {
        TimelineView(.animation) { zeit in
            Canvas { kontext, _ in
                let punkte = punkteJetzt(zeit.date)
                for y in 0..<Pixelfeld.hoeheStandard {
                    for x in 0..<Pixelfeld.breiteStandard {
                        let farbe = punkte[y * Pixelfeld.breiteStandard + x]
                        guard let farbe, let c = Color(hex: farbe) else { continue }
                        kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                                 width: kante - 0.5, height: kante - 0.5)),
                                     with: .color(c))
                    }
                }
            }
        }
        .frame(width: Double(Pixelfeld.breiteStandard) * kante,
               height: Double(Pixelfeld.hoeheStandard) * kante)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Bei Laufschrift das Einzelbild, das jetzt an der Reihe ist; sonst das
    /// stehende Feld mit eingesetztem Icon.
    private func punkteJetzt(_ jetzt: Date) -> [String?] {
        if let bilder = laufschriftBilder, !bilder.isEmpty {
            let gesamt = bilder.reduce(0.0) { $0 + $1.dauer }
            guard gesamt > 0 else { return bilder[0].pixel }
            var rest = jetzt.timeIntervalSince1970.truncatingRemainder(dividingBy: gesamt)
            for bild in bilder {
                rest -= bild.dauer
                if rest <= 0 { return bild.pixel }
            }
            return bilder[bilder.count - 1].pixel
        }
        var punkte = feld.punkteRoh
        if let icon, let bilder = try? Bildraster.lesen(icon, breite: 8, hoehe: 8), let erstes = bilder.first {
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let p = erstes[y * 8 + x] else { continue }
                    punkte[(y + 4) * Pixelfeld.breiteStandard + x] = p
                }
            }
        }
        return punkte
    }
}
