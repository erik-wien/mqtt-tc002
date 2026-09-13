import SwiftUI
import TC002Ansichten
import TC002Core

/// Zeigt eine Bilddatei als Farbraster — die Vorschau von Icons (8×8) und
/// gesicherten Bildern (52×16) in Listen und Rastern.
///
/// Gelesen wird über `Bildraster`, also über `CGImageSource` aus der Datei.
/// Das ist nicht bloß der plattformfreie Weg, sondern auch der frische: Ein im
/// Editor geändertes Icon sieht hier sofort neu aus, weil es zwischen Datei und
/// Anzeige nichts gibt, das sich etwas merken könnte.
///
/// Gezeigt wird das **erste** Einzelbild. Ein animiertes Icon läuft in einer
/// Liste nicht — das wäre im Raster nur Unruhe; abgespielt wird es in der
/// Vorschau (`VorschauView`).
///
/// Der Hintergrund bleibt Sache des Aufrufers: „aus" ist durchsichtig, nicht
/// schwarz, und im Icon-Raster soll die Zelle durchscheinen.
struct Rasterbild: View {
    let datei: URL
    var breite: Int = 8
    var hoehe: Int = 8
    /// Kantenlänge eines Pixels in Punkten.
    let kante: Double

    var body: some View {
        let pixel = (try? Bildraster.lesen(datei, breite: breite, hoehe: hoehe))?.first ?? []
        Canvas { kontext, _ in
            guard pixel.count == breite * hoehe else { return }
            for y in 0..<hoehe {
                for x in 0..<breite {
                    guard let hex = pixel[y * breite + x], let farbe = Color(hex: hex) else { continue }
                    kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                             width: kante, height: kante)),
                                 with: .color(farbe))
                }
            }
        }
        .frame(width: Double(breite) * kante, height: Double(hoehe) * kante)
    }
}
