import SwiftUI
import TC002Core

/// Rahmen um die Vorschau: die Frontansicht des Geraets, gezeichnet aus den
/// Daten in `Geraetezeichnung`, mit der fertigen Pixelvorschau (`inhalt`)
/// unveraendert in deren schwarzes Displayfeld eingesetzt.
///
/// Geteilt zwischen allen Oberflaechen (Mac, iPhone, kuenftig iPad) — deshalb
/// keine plattformeigenen Typen hier, nur SwiftUI.
///
/// Eine Komponente, zwei Geraetearten: Welche Front erscheint, entscheidet
/// allein `typ`; der Weg zum Bild ist fuer beide derselbe `Canvas`. Was sich
/// unterscheidet, sind die Zahlen in `Geraetezeichnung` — eine dritte Art
/// braucht hier keine Zeile.
///
/// Die Zeichnung wird so gross gezeichnet, dass ihr Displayfeld genau `hoehe`
/// hoch ist; `inhalt` passt damit in der Hoehe exakt hinein und wird oben und
/// links buendig eingesetzt, ohne irgendwo skaliert zu werden — wie auf dem
/// Geraet selbst, das eine Anzeige immer bei Spalte 0 beginnt. Die Pixel
/// bleiben quadratisch. Das ruehrt an nichts in `Meldungsbau`, das die
/// tatsaechliche Nutzlast erzeugt; hier geht es allein um Bildschirmgeometrie.
public struct GeraeteRahmen<Inhalt: View>: View {
    let hoehe: Double
    let zeichnung: Geraetezeichnung
    @ViewBuilder let inhalt: Inhalt

    /// `typ` ist `Optional`, weil `Uhr.typ` es ist: `nil` heisst `.tc002`.
    public init(hoehe: Double, typ: Geraetetyp? = nil,
                @ViewBuilder inhalt: () -> Inhalt) {
        self.hoehe = hoehe
        self.zeichnung = .fuer(typ)
        self.inhalt = inhalt()
    }

    private var masse: Geraetezeichnung.Masse { zeichnung.masse(inhaltHoehe: hoehe) }

    public var body: some View {
        let m = masse
        let ecke = zeichnung.inhaltEcke(inhaltHoehe: hoehe)
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
