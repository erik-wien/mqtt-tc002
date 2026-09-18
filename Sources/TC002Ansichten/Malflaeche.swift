import SwiftUI
import TC002Core

/// Die Leinwand selbst — ein Raster aus Kaestchen, in das man malt und
/// radiert. Sonst nichts: Werkzeuge, Bildleiste und alles Weitere stehen
/// woanders (`EditorBereichView`).
///
/// Sie macht ihre Spalte nie breiter, als diese ist. Der `GeometryReader`
/// steht ueber dem Raster, nicht als Hintergrund darunter: So bekommt die
/// Rechnung den Platz, den der Bereich hergibt, und nicht die Breite, die das
/// Raster sich selbst schon genommen hat. Ein `GeometryReader` gibt die
/// Groesse seines Inhalts auch nicht nach oben weiter — er kann die Spalte
/// also nicht aufblaehen.
///
/// Reicht die Breite selbst bei der kleinsten Kantenlaenge nicht (Slide Over:
/// 52 Kaestchen zu sechs Punkten sind 312), rollt die Leinwand waagrecht,
/// statt ueber ihren Bereich hinauszuzeichnen.
struct Malflaeche: View {
    @Binding var leinwand: Leinwand
    let farbe: Color
    let radiert: Bool
    /// Einmal je Strich, vor dem ersten Pixel — der Platz fuer einen
    /// Schritt im Rueckgaengig-Stapel. Ein Strich ueber zwanzig Kaestchen ist
    /// ein Schritt, nicht zwanzig.
    var vorStrich: () -> Void = {}
    /// Beim Loslassen: der Aufrufer sichert seinen Arbeitsstand. Nicht bei
    /// jedem einzelnen Pixel — das waeren hunderte Schreibvorgaenge je Strich.
    var nachStrich: () -> Void = {}

    /// Was unten rechts am Raster steht — der Abspielknopf des Editors.
    ///
    /// Hier und nicht beim Aufrufer: Das Raster steht mittig in einer Flaeche,
    /// die viel groesser sein kann als es selbst; bei einem 8 × 8 liegt
    /// dazwischen fast das ganze Fenster. Nur diese Ansicht weiss, wo das Bild
    /// wirklich endet. `AnyView` statt eines Typparameters, damit der eine
    /// Aufrufer ohne Zubehoer nichts anzugeben braucht.
    var zubehoer: AnyView?

    @State private var imStrich = false

    var body: some View {
        GeometryReader { geo in
            let kante = Malraster.kante(breite: leinwand.breite, hoehe: leinwand.hoehe,
                                        verfuegbareBreite: geo.size.width,
                                        verfuegbareHoehe: geo.size.height)
            ScrollView(.horizontal) {
                raster(kante: kante)
                    .overlay(alignment: .bottomTrailing) {
                        if let zubehoer { zubehoer.padding(6) }
                    }
                    // Passt es, steht das Raster mittig in der Spalte; passt es
                    // nicht, ist der Rahmen kleiner als der Inhalt und die
                    // Rolle greift.
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height,
                           alignment: .center)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func raster(kante: Double) -> some View {
        Canvas { kontext, _ in
            for y in 0..<leinwand.hoehe {
                for x in 0..<leinwand.breite {
                    let r = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                   width: kante - 1, height: kante - 1)
                    let f = leinwand.farbe(x: x, y: y).flatMap(Color.init(hex:)) ?? Color(white: 0.12)
                    kontext.fill(Path(r), with: .color(f))
                }
            }
        }
        .frame(width: Double(leinwand.breite) * kante, height: Double(leinwand.hoehe) * kante)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { wert in
                if !imStrich {
                    imStrich = true
                    vorStrich()
                }
                let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
                leinwand.setzen(x: x, y: y, farbe: radiert ? nil : farbe.hexWert)
            }
            .onEnded { _ in
                imStrich = false
                nachStrich()
            })
    }
}
