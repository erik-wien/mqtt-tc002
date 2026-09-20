import SwiftUI
import TC002Core

/// Zeichnet ein Punkteraster in die verfügbare Fläche — das eine Objekt für
/// jedes kleine Pixelbild der App.
///
/// Es stand dreimal da: als `Slotraster` im Slotblock, als `bildVorschau` in
/// der Einzelbildleiste des Editors und als `IconRasteriOS` im Icons-Blatt des
/// Telefons. Dreimal dieselbe Doppelschleife, dreimal ein anderes Ergebnis —
/// die Kacheln der Einzelbildleiste waren 34 Punkte breit, die Blöcke darunter
/// das Vierfache. Der Auftraggeber: *„die anzeige des mittelteils ist sehr
/// unterschiedlich. verwende bitte möglichst das selbe objekt."*
///
/// Rein darstellend, wie `GeraeteRahmen`: keine eigene Rasterung, kein Bezug
/// zu `Meldungsbau`. Was es nicht zeichnet, ist ein ausgeschalteter Punkt
/// (`nil`) — dort bleibt durchsichtig, und der Aufrufer legt Schwarz darunter.
/// So trägt jeder Aufrufer seine eigene Fassung: der Slotblock einen Rahmen,
/// die Kachel eine Auswahlkante.
public struct Pixelraster: View {
    let punkte: [String?]
    let mass: Anzeigemass

    public init(punkte: [String?], mass: Anzeigemass) {
        self.punkte = punkte
        self.mass = mass
    }

    public var body: some View {
        Canvas { kontext, groesse in
            let spalten = mass.breite
            let zeilen = mass.hoehe
            guard punkte.count == spalten * zeilen else { return }
            let kante = groesse.width / Double(spalten)
            for y in 0..<zeilen {
                for x in 0..<spalten {
                    guard let hex = punkte[y * spalten + x], let farbe = Color(hex: hex) else { continue }
                    let kaestchen = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                           width: kante, height: kante)
                    kontext.fill(Path(kaestchen), with: .color(farbe))
                }
            }
        }
        // Das Seitenverhältnis des Feldes: Bei 52 × 16 ist ein Quadrat nicht
        // dasselbe Bild, sondern ein anderes.
        .aspectRatio(Double(mass.breite) / Double(mass.hoehe), contentMode: .fit)
    }
}
