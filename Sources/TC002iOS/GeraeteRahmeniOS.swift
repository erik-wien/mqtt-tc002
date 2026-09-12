import SwiftUI

/// Rahmen um die Vorschau: die Zeichnung des Geraets aus dem Bildkatalog
/// (`Resources/Bilder.xcassets/GeraeteRahmen.imageset`, eine SVG-Frontansicht
/// der Ulanzi TC002), mit der fertigen Pixelvorschau (`inhalt`) unveraendert
/// in deren schwarzes Displayfeld eingesetzt.
///
/// Die Feldmasse sind an der Zeichnung abgelesen, nicht geschaetzt:
/// `viewBox="0 0 680 356"`, darin das schwarze Feld
/// `x=48 y=93 width=584 height=177`. `inhalt` bringt sein eigenes
/// Seitenverhaeltnis mit (52:16 = 3,25, siehe `VorschauiOS`); das Feld ist
/// minimal breiter (584:177 = 3,30). Deshalb wird `inhalt` an der Feldhoehe
/// ausgerichtet und horizontal zentriert — der schmale schwarze Rest links
/// und rechts faellt nicht auf, und die Pixel bleiben quadratisch. Das ruehrt
/// an nichts in `Meldungsbau`, das die tatsaechliche Nutzlast erzeugt; hier
/// geht es allein um Bildschirmgeometrie.
struct GeraeteRahmeniOS<Inhalt: View>: View {
    let breite: Double
    let hoehe: Double
    @ViewBuilder let inhalt: Inhalt

    // An der SVG abgelesen (viewBox 680x356, Feld x=48 y=93 b=584 h=177).
    // Computed statt gespeichert, weil generische Typen keine gespeicherten
    // statischen Eigenschaften haben duerfen.
    private static var bildBreite: Double { 680 }
    private static var bildHoehe: Double { 356 }
    private static var feldX: Double { 48 }
    private static var feldY: Double { 93 }
    private static var feldBreite: Double { 584 }
    private static var feldHoehe: Double { 177 }

    // Das Bild wird so gross gezeichnet, dass sein Displayfeld genau `hoehe`
    // hoch ist — damit passt `inhalt` in der Hoehe exakt hinein, ohne
    // Verzerrung (Breite und Hoehe skalieren gemeinsam mit dem Seiten-
    // verhaeltnis der Zeichnung).
    private var rahmenHoehe: Double { hoehe * Self.bildHoehe / Self.feldHoehe }
    private var rahmenBreite: Double { rahmenHoehe * Self.bildBreite / Self.bildHoehe }

    private var feldXReal: Double { rahmenBreite * Self.feldX / Self.bildBreite }
    private var feldYReal: Double { rahmenHoehe * Self.feldY / Self.bildHoehe }
    private var feldBreiteReal: Double { rahmenBreite * Self.feldBreite / Self.bildBreite }

    private var inhaltX: Double { feldXReal + (feldBreiteReal - breite) / 2 }
    private var inhaltY: Double { feldYReal }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("GeraeteRahmen")
                .resizable()
                .frame(width: rahmenBreite, height: rahmenHoehe)

            inhalt
                .offset(x: inhaltX, y: inhaltY)
        }
        .frame(width: rahmenBreite, height: rahmenHoehe)
    }
}
