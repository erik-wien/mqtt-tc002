import SwiftUI
import TC002Core

/// Rahmen um die Vorschau: die Frontansicht des Geraets, gezeichnet aus den
/// Daten in `Geraetezeichnung`, mit der fertigen Pixelvorschau (`inhalt`)
/// unveraendert in deren schwarzes Displayfeld eingesetzt.
///
/// Geteilt zwischen allen Oberflaechen (Mac, iPhone, kuenftig iPad) — deshalb
/// keine plattformeigenen Typen hier, nur SwiftUI.
///
/// Der Weg zum Bild ist ein `Canvas`; was sich pro Geraet unterscheidet, sind
/// die Zahlen in `Geraetezeichnung`.
///
/// Die Zeichnung wird so gross gezeichnet, dass ihr Displayfeld genau `hoehe`
/// hoch ist; `inhalt` passt damit in der Hoehe exakt hinein und wird oben und
/// links buendig eingesetzt, ohne irgendwo skaliert zu werden — wie auf dem
/// Geraet selbst, das eine Anzeige immer bei Spalte 0 beginnt. Die Pixel
/// bleiben quadratisch. Das ruehrt an nichts in `Meldungsbau`, das die
/// tatsaechliche Nutzlast erzeugt; hier geht es allein um Bildschirmgeometrie.
public struct GeraeteRahmen<Inhalt: View>: View {
    let hoehe: Double
    let mass: Anzeigemass
    let zeichnung: Geraetezeichnung
    @ViewBuilder let inhalt: Inhalt

    /// `mass` ist das Raster des Inhalts und waehlt die Zeichnung
    /// (`Geraetezeichnung.fuer`); `hoehe` ist seine Hoehe in Punkten.
    public init(hoehe: Double, mass: Anzeigemass = .vorgabe,
                @ViewBuilder inhalt: () -> Inhalt) {
        self.hoehe = hoehe
        self.mass = mass
        self.zeichnung = .fuer(mass)
        self.inhalt = inhalt()
    }

    private var masse: Geraetezeichnung.Masse {
        zeichnung.masse(fuer: mass, kante: hoehe / Double(mass.hoehe))
    }

    public var body: some View {
        let m = masse
        let ecke = (x: m.feldX, y: m.feldY)
        return ZStack(alignment: .topLeading) {
            Canvas { kontext, _ in
                Self.zeichnen(zeichnung, in: kontext, massstab: m.massstab)
            }
            .frame(width: m.rahmenBreite, height: m.rahmenHoehe)
            // Die Zeichnung ist ein Geraet, kein Bedienelement — VoiceOver
            // soll die Vorschau darin vorlesen, nicht den Rahmen ringsum.
            .accessibilityHidden(true)

            inhalt
                .offset(x: ecke.x, y: ecke.y)
        }
        .frame(width: m.rahmenBreite, height: m.rahmenHoehe)
    }

    /// Der ganze Zeichenweg an einer Stelle: Teile der Reihe nach, jeder mit
    /// `massstab` vom Zeichenraum in Punkte gebracht.
    private static func zeichnen(_ zeichnung: Geraetezeichnung,
                                 in kontext: GraphicsContext, massstab: Double) {
        for teil in zeichnung.teile {
            switch teil {
            case let .flaeche(rechteck, radius, farbe):
                guard let farbe = Color(hex: farbe) else { continue }
                let kasten = CGRect(x: rechteck.x * massstab, y: rechteck.y * massstab,
                                    width: rechteck.breite * massstab,
                                    height: rechteck.hoehe * massstab)
                let pfad = radius > 0
                    ? Path(roundedRect: kasten, cornerRadius: radius * massstab)
                    : Path(kasten)
                kontext.fill(pfad, with: .color(farbe))

            case let .schrift(wortlaut, x, grundlinie, groesse, farbe, rechtsbuendig):
                guard let farbe = Color(hex: farbe) else { continue }
                // `verbatim`: Der Wortlaut steht auf dem Geraet aufgedruckt.
                // Er wird nicht uebersetzt — sonst suchte die Oberflaeche
                // einen Schluessel „Ulanzi TC001", den es nie geben wird.
                let text = Text(verbatim: wortlaut)
                    .font(.system(size: groesse * massstab, weight: .regular, design: .default))
                    .kerning(0.6 * massstab)
                    .foregroundStyle(farbe)
                kontext.draw(text,
                             at: CGPoint(x: x * massstab, y: grundlinie * massstab),
                             anchor: rechtsbuendig ? .bottomTrailing : .bottomLeading)
            }
        }
    }
}
