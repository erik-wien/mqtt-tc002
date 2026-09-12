import SwiftUI

/// Zeichnerischer Rahmen um die Vorschau, der an die Ulanzi TC002 erinnert:
/// dunkles, abgerundetes Gehaeuse mit rotem Drehknopf oben links, schwarzer
/// Bedienleiste oben rechts und einem Sockel darunter. Ein
/// Wiedererkennungszeichen, keine Abbildung — deshalb ohne Beschriftung,
/// Schrauben oder Spiegelungen, und mit fest gewaehlten Farben, die sich
/// nicht dem hellen oder dunklen Bildschirm anpassen: Sie sollen auf beiden
/// gleich gut zu sehen sein.
///
/// Bekommt die fertige Pixelvorschau (`inhalt`) unveraendert und legt sich
/// nur *darum*. Die Randbreiten sind Bruchteile von `hoehe` — der Groesse,
/// die `inhalt` ohnehin schon hat (siehe `VorschauiOS`) — damit das
/// Gehaeusefenster immer exakt zum Pixelraster passt, ohne dessen Seiten-
/// verhaeltnis (52:16, am Herstellerbild gemessen 3,25:1) selbst nachzurechnen.
struct GeraeteRahmeniOS<Inhalt: View>: View {
    let breite: Double
    let hoehe: Double
    @ViewBuilder let inhalt: Inhalt

    // Am Herstellerbild abgelesen: unten ist der Steg deutlich breiter als
    // oben und an den Seiten (dort steht die Beschriftung, die wir hier
    // weglassen). Die uebrigen Anteile sind bewusst grob geschaetzt, nicht
    // vermessen — ein Wiedererkennungszeichen braucht keine Genauigkeit.
    private var seite: Double { hoehe * 0.28 }
    private var oben: Double { hoehe * 0.40 }
    private var unten: Double { hoehe * 0.95 }
    private var eckenradius: Double { hoehe * 0.25 }

    private var gehaeuseBreite: Double { breite + seite * 2 }
    private var gehaeuseHoehe: Double { hoehe + oben + unten }

    var body: some View {
        VStack(spacing: hoehe * 0.08) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: eckenradius)
                    .fill(Color(white: 0.16))
                    .frame(width: gehaeuseBreite, height: gehaeuseHoehe)
                    .overlay(
                        RoundedRectangle(cornerRadius: eckenradius)
                            .strokeBorder(Color(white: 0.55), lineWidth: max(1, hoehe * 0.015))
                    )

                inhalt
                    .offset(x: seite, y: oben)

                // Roter Drehknopf oben links, ragt ueber die Oberkante hinaus.
                Circle()
                    .fill(Color(red: 0.75, green: 0.14, blue: 0.12))
                    .frame(width: oben * 1.3, height: oben * 1.3)
                    .offset(x: seite * 0.7, y: -oben * 0.35)

                // Schwarze Bedienleiste oben rechts, auf dem Gehaeuse.
                RoundedRectangle(cornerRadius: oben * 0.2)
                    .fill(Color.black)
                    .frame(width: gehaeuseBreite * 0.22, height: oben * 0.42)
                    .offset(x: gehaeuseBreite - gehaeuseBreite * 0.22 - seite * 0.7,
                            y: oben * 0.3)
            }
            .frame(width: gehaeuseBreite, height: gehaeuseHoehe)

            // Sockel, auf dem das Geraet steht.
            RoundedRectangle(cornerRadius: hoehe * 0.06)
                .fill(Color(white: 0.12))
                .frame(width: gehaeuseBreite * 0.45, height: hoehe * 0.16)
        }
    }
}
