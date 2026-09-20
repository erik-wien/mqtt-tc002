import SwiftUI
import TC002Core

/// Die Leinwand selbst — ein Raster aus Kaestchen, in das man malt, radiert
/// und Flaechen fuellt. Sonst nichts: Werkzeuge, Bildleiste und alles Weitere
/// stehen woanders (`EditorBereichView`).
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
/// Was ein Strich auf der Leinwand anrichtet. Ein Zustand mit drei Faellen
/// statt „radiert ja/nein" und einem dritten Schalter daneben: Der Waehler im
/// Inspektor kennt immer genau eines der drei.
enum Malwerkzeug: String, CaseIterable, Identifiable {
    case malen, radieren, fuellen
    var id: String { rawValue }
}

struct Malflaeche: View {
    @Binding var leinwand: Leinwand
    let farbe: Color
    let werkzeug: Malwerkzeug
    /// Einmal je Strich, vor dem ersten Pixel — der Platz fuer einen
    /// Schritt im Rueckgaengig-Stapel. Ein Strich ueber zwanzig Kaestchen ist
    /// ein Schritt, nicht zwanzig.
    var vorStrich: () -> Void = {}
    /// Beim Loslassen: der Aufrufer sichert seinen Arbeitsstand. Nicht bei
    /// jedem einzelnen Pixel — das waeren hunderte Schreibvorgaenge je Strich.
    var nachStrich: () -> Void = {}

    /// Was neben dem Raster steht — der Abspielknopf des Editors.
    ///
    /// Hier und nicht beim Aufrufer: Das Raster steht mittig in einer Flaeche,
    /// die viel groesser sein kann als es selbst; bei einem 8 × 8 liegt
    /// dazwischen fast das ganze Fenster. Nur diese Ansicht weiss, wo das Bild
    /// wirklich endet. `AnyView` statt eines Typparameters, damit der eine
    /// Aufrufer ohne Zubehoer nichts anzugeben braucht.
    ///
    /// **Neben dem Bild, nicht darin.** Ein Zeichen im Raster verdeckt Pixel,
    /// die man malen will, und liegt ueber einer Farbe, die niemand kennt.
    var zubehoer: AnyView?

    /// Wie breit und hoch das Zubehoer ist. Diese eine Zahl fehlt der
    /// Flaeche, um dem Raster den Platz daneben abzuziehen: Das Raster
    /// rechnet seine Kantenlaenge aus dem verfuegbaren Platz aus und nimmt
    /// ihn sonst ganz — das Zubehoer stuende dann ausserhalb des Sichtfelds.
    /// `AnyView` laesst sich nicht messen, ohne den Umbruch zu verzoegern.
    var zubehoerMass: Double = 0

    @State private var imStrich = false

    /// Ob das Bild breiter als hoch ist — die Anzeige (52 × 16) ist es, die
    /// beiden Icons sind quadratisch.
    private var breitesBild: Bool { leinwand.breite > leinwand.hoehe }

    /// Das Raster und, wo eines gereicht wird, sein Zubehoer daneben.
    ///
    /// Wohin, entscheidet die Form des Bildes: Ein Icon ist quadratisch und
    /// laesst rechts Platz; eine Anzeige ist dreimal so breit wie hoch und
    /// nimmt die Spalte ganz ein — dort steht das Zubehoer knapp darunter.
    @ViewBuilder
    private func mitZubehoer(kante: Double) -> some View {
        if breitesBild {
            VStack(alignment: .trailing, spacing: 8) {
                raster(kante: kante)
                zubehoer
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                raster(kante: kante)
                zubehoer
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            // Das Zubehoer steht neben einem Icon und unter einer Anzeige
            // (siehe `mitZubehoer`) — abgezogen wird es deshalb einmal
            // waagrecht, einmal senkrecht.
            let platz = zubehoer == nil ? 0 : zubehoerMass + 12
            let kante = Malraster.kante(breite: leinwand.breite, hoehe: leinwand.hoehe,
                                        verfuegbareBreite: geo.size.width - (breitesBild ? 0 : platz),
                                        verfuegbareHoehe: geo.size.height - (breitesBild ? platz : 0))
            ScrollView(.horizontal) {
                mitZubehoer(kante: kante)
                    // Passt es, steht das Raster mittig in der Spalte; passt es
                    // nicht, ist der Rahmen kleiner als der Inhalt und die
                    // Rolle greift.
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height,
                           alignment: .center)
            }
            .scrollIndicators(.automatic)
            .zeigerAmWerkzeug(werkzeugzeichen)
        }
    }

    /// Der Zeiger über dem Raster trägt das Werkzeug, das gerade gewählt ist —
    /// Pinsel, Radierer oder Farbeimer, dieselben Zeichen wie im Inspektor.
    ///
    /// Erik: *„können wir am mac die form der maus innerhalb des grafik
    /// rasters an die funktion anpassen?"* Ja, und ohne AppKit: `pointerStyle`
    /// ist SwiftUI und nimmt ein beliebiges Bild. Diese Datei bleibt damit
    /// plattformfrei (siehe `CLAUDE.md`).
    ///
    /// Es gibt den Aufruf ab macOS 15 und iPadOS 18; darunter bleibt der
    /// Systemzeiger. Das Fuellsymbol wiederum kam erst 2025 — ein unbekannter
    /// Name zeichnet nichts, und ein unsichtbarer Zeiger wäre schlimmer als
    /// ein gewöhnlicher.
    ///
    /// Die Spitze liegt links unten: Dort trägt der Pinsel seine Farbe, und
    /// der Eimer gießt dorthin.
    private var werkzeugzeichen: String {
        switch werkzeug {
        case .malen: return "paintbrush.pointed.fill"
        case .radieren: return "eraser.fill"
        case .fuellen:
            if #available(iOS 26, macOS 26, *) {
                return "paint.bucket.classic"
            }
            return "drop.fill"
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
                let beginnt = !imStrich
                if beginnt {
                    imStrich = true
                    vorStrich()
                }
                let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
                switch werkzeug {
                case .malen: leinwand.setzen(x: x, y: y, farbe: farbe.hexWert)
                case .radieren: leinwand.setzen(x: x, y: y, farbe: nil)
                // Der Eimer wirkt einmal je Beruehrung, dort wo sie beginnt.
                // Wuerde er jedem ueberfahrenen Kaestchen folgen, faerbte die
                // erste Fingerbewegung das ganze Bild ein.
                case .fuellen: if beginnt { leinwand.fuellen(x: x, y: y, farbe: farbe.hexWert) }
                }
            }
            .onEnded { _ in
                imStrich = false
                nachStrich()
            })
    }
}

extension View {
    /// Setzt das Werkzeugzeichen als Zeiger — wo es das gibt.
    ///
    /// Eigene Erweiterung und kein `if #available` mitten im Rumpf: Ein
    /// `some View`, dessen Typ vom Systemstand abhängt, lässt sich nicht
    /// schreiben, ohne beide Zweige gleich zu machen. So bleibt der Rumpf
    /// darüber lesbar.
    ///
    /// `pointerStyle` gibt es nur unter macOS — unter iPadOS gestaltet man
    /// den Zeiger über `hoverEffect`, und ein Finger hat ohnehin keinen. Kein
    /// `import AppKit`: Der Aufruf ist SwiftUI, die Datei bleibt
    /// plattformfrei (`CLAUDE.md`).
    @ViewBuilder
    func zeigerAmWerkzeug(_ zeichen: String) -> some View {
        #if os(macOS)
        if #available(macOS 15, *) {
            pointerStyle(.image(Image(systemName: zeichen), hotSpot: .bottomLeading))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
