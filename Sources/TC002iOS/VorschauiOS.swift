import SwiftUI
import TC002Ansichten
import TC002Core

/// Das Display, 52×16 Pixel, sechsfach vergroessert. Zeigt entweder ein
/// stehendes Feld (mit eingesetztem Icon) oder spielt die Einzelbilder der
/// Laufschrift ab.
///
/// Bauart wie die Mac-Fassung (`Sources/TC002App/VorschauView.swift`): Das
/// Icon wird einmal je Wechsel ueber `.task(id:)` in `@State` gelesen, nicht
/// bei jedem Neuzeichnen — `Bildraster.lesen` dekodiert alle Einzelbilder
/// einer Datei, und der Zeichenblock liefe unter `TimelineView(.animation)`
/// 60 bis 120 mal je Sekunde auf dem Hauptthread. `TimelineView` wird
/// ausserdem nur montiert, wenn tatsaechlich mehr als ein Einzelbild
/// abzuspielen ist; ein stehendes Bild zeichnet sich einmal und bleibt dann
/// in Ruhe. Nebeneffekt: ein animiertes Icon spielt auch hier, wie am Mac.
struct VorschauiOS: View {
    let feld: Pixelfeld
    let icon: URL?
    let laufschriftBilder: [Bildraster.Einzelbild]?
    var kante: Double = 6
    /// Welche Geraetefront darum liegt und wie die Punkte darin aussehen.
    /// `Optional` wie `Uhr.typ`: `nil` heisst `.tc002`.
    var typ: Geraetetyp? = nil

    /// Einzelbilder des gewaehlten Icons mit ihren Standzeiten — einmal je
    /// Iconwechsel geladen. Ein unbewegtes Icon hat genau eines.
    @State private var iconBilder: [Bildraster.Einzelbild] = []

    /// Wie ein einzelner Punkt gezeichnet wird — dieselbe Quelle wie der
    /// Rahmen, damit Mac und Telefon dasselbe Raster zeigen.
    private var pixelstil: Geraetezeichnung.Pixelstil { Geraetezeichnung.fuer(typ).pixelstil }

    var body: some View {
        // Das Pixelraster selbst (Groesse, Rasterung) bleibt unveraendert; der
        // Geraeterahmen legt sich nur darum, siehe `GeraeteRahmen` (TC002Ansichten).
        GeraeteRahmen(hoehe: Double(feld.hoehe) * kante, typ: typ) {
            Group {
                if let bilder = laufschriftBilder, !bilder.isEmpty {
                    if bilder.count > 1 {
                        TimelineView(.animation) { zeit in
                            anzeige(Self.einzelbild(aus: bilder, bei: zeit.date)?.pixel ?? bilder[0].pixel)
                        }
                    } else {
                        anzeige(bilder[0].pixel)
                    }
                } else if iconBilder.count > 1 {
                    TimelineView(.animation) { zeit in
                        anzeige(mitIcon(Self.einzelbild(aus: iconBilder, bei: zeit.date)))
                    }
                } else {
                    anzeige(mitIcon(iconBilder.first))
                }
            }
            .frame(width: Double(feld.breite) * kante,
                   height: Double(feld.hoehe) * kante)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(lokf("Vorschau der Anzeige, %d mal %d Pixel", feld.breite, feld.hoehe))
            .task(id: icon) { iconBilder = Self.geladen(icon) }
        }
    }

    /// Zeichnet das volle Punkteraster — so gross wie die Anzeige der Uhr, auf
    /// die sich die Vorschau bezieht. Nicht fest 52×16: Eine NG-Uhr hat
    /// 32×8, und ein Raster der falschen Groesse liefe hier ins Leere und im
    /// Rahmen ueber (siehe `Anzeigemass`).
    private func anzeige(_ punkte: [String?]) -> some View {
        let stil = pixelstil
        return Canvas { kontext, _ in
            for y in 0..<feld.hoehe {
                for x in 0..<feld.breite where y * feld.breite + x < punkte.count {
                    let farbe = punkte[y * feld.breite + x]
                    guard let farbe, let c = Color(hex: farbe) else { continue }
                    kontext.fill(stil.pfad(spalte: x, zeile: y, zelle: kante), with: .color(c))
                }
            }
        }
    }

    /// Das stehende Feld mit eingesetztem Icon-Einzelbild, falls eines da ist.
    ///
    /// Die Zeile, auf der es sitzt, ist die senkrechte Mitte des Feldes und
    /// nicht die feste 4: Auf den acht Zeilen einer NG-Uhr saesse ein 8×8
    /// dort halb ausserhalb — geschrieben wuerde dabei hinter das Ende des
    /// Rasters, und das ist kein schiefes Bild, sondern ein Absturz.
    private func mitIcon(_ iconBild: Bildraster.Einzelbild?) -> [String?] {
        var punkte = feld.punkteRoh
        guard let iconBild else { return punkte }
        let y0 = Anzeigemass(breite: feld.breite, hoehe: feld.hoehe).iconY(kante: 8)
        for y in 0..<8 where (0..<feld.hoehe).contains(y0 + y) {
            for x in 0..<8 where x < feld.breite {
                guard let p = iconBild.pixel[y * 8 + x] else { continue }
                punkte[(y0 + y) * feld.breite + x] = p
            }
        }
        return punkte
    }

    /// Waehlt anhand der verstrichenen Zeit das faellige Einzelbild aus einer
    /// Liste — wie in der Mac-Fassung, in Schleife ueber alle, jedes mit
    /// seiner eigenen Standzeit.
    private static func einzelbild(aus liste: [Bildraster.Einzelbild], bei zeitpunkt: Date) -> Bildraster.Einzelbild? {
        guard !liste.isEmpty else { return nil }
        let gesamt = liste.reduce(0) { $0 + $1.dauer }
        guard gesamt > 0 else { return liste.first }
        var rest = zeitpunkt.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: gesamt)
        for bild in liste {
            if rest < bild.dauer { return bild }
            rest -= bild.dauer
        }
        return liste.last
    }

    /// Liest das Icon einmal, mit seinen Standzeiten — fuer den unbewegten
    /// Fall genau ein Einzelbild.
    private static func geladen(_ icon: URL?) -> [Bildraster.Einzelbild] {
        guard let icon else { return [] }
        return (try? Bildraster.lesenMitZeiten(icon, breite: 8, hoehe: 8)) ?? []
    }
}
