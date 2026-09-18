import SwiftUI
import TC002Core

/// Der Block als geteilte Ansicht: Slotnummer, Zustand, ob er gerade gewählt
/// ist. Geteilt zwischen allen Oberflächen (Mac, iPhone, künftig iPad).
///
/// Zeigt nur — rechnet nichts (`Meldungsbau` bleibt unberührt) und wählt
/// nichts selbst: Antippen wird von außen verdrahtet
/// (`Button { … } label: { Slotblock(…) } `), siehe die Sendeansichten.
///
/// Zustand hängt **nicht allein an der Farbe**: `.frei` (gestrichelter,
/// leerer Rahmen) und `.unbekannt` (gefüllter Rahmen mit dem Wort „belegt“)
/// unterscheiden sich auch in der Form; `.bekannt` zeigt Pixel. Ob die
/// mitgelesen oder aus dem Slotgedächtnis gerechnet sind, entscheidet
/// `AppZustand.slotzustand` und steht hier nicht mehr zur Debatte. Der
/// gewählte Block trägt zusätzlich einen eigenen, sichtbaren Rahmen — keine
/// bloße Tönung.
///
/// Die Trefferfläche (`.frame(minWidth:minHeight:)`) sitzt **in** dieser
/// Ansicht, nicht um sie herum — sonst träfe ein Fingertipp nur die kleine
/// Glyphe bzw. Pixelfläche, sobald ein Aufrufer diese Ansicht als Label eines
/// `Button` verwendet.
public struct Slotblock: View {
    /// 1…5, wie `Meldungsplatz`.
    public let platz: Int
    public let zustand: Slotzustand
    public let gewaehlt: Bool
    /// **Das Mass der Uhr, deren Stand dieser Block zeigt.** Bis zum
    /// 18.09.2026 war es fest 52×16; seit die Bloecke auch fuer eine NG ein
    /// Bild zeigen duerfen, muessen sie deren 32×8 kennen — sonst faende die
    /// Wache in `Slotraster` die falsche Punktzahl vor und liesse den Block
    /// leer.
    public let mass: Anzeigemass

    public init(platz: Int, zustand: Slotzustand, gewaehlt: Bool, mass: Anzeigemass = .tc002) {
        self.platz = platz
        self.zustand = zustand
        self.gewaehlt = gewaehlt
        self.mass = mass
    }

    private var seitenverhaeltnis: Double { Double(mass.breite) / Double(mass.hoehe) }
    private static let eckenradius = 6.0

    public var body: some View {
        VStack(spacing: 2) {
            inhalt
            nummer
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschriftung)
    }

    /// Die Slotnummer, sichtbar und nicht nur für die Sprachausgabe: Fünf
    /// gestrichelte Rahmen nebeneinander lassen sich sonst nur abzählen, und
    /// die Hilfe setzt darauf, dass Block und Gerätebezeichner (`meldung1`
    /// … `meldung5`) zusammenfinden. Ein Bezeichner, kein Erklärtext —
    /// erklärt wird in der Hilfe, nicht hier.
    ///
    /// **Unter** dem Block, nicht darin: Sie darf das Pixelbild nicht
    /// verdecken. Und schmaler als er, damit die Zeile am iPhone weiterhin
    /// 6 × 44pt + 5 × 6pt = 294pt misst — zusätzliche Höhe ist dort frei,
    /// zusätzliche Breite nicht.
    ///
    /// `String(platz)` statt eines Texts mit Platzhalter: An einer bloßen
    /// Ziffer ist nichts zu übersetzen, und ein `LocalizedStringKey` „%d“
    /// stünde ohne Not in der Sprachdatei.
    private var nummer: some View {
        Text(String(platz))
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var inhalt: some View {
        Group {
            switch zustand {
            case .frei:
                RoundedRectangle(cornerRadius: Self.eckenradius)
                    .stroke(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            case .bekannt(let punkte):
                ZStack {
                    RoundedRectangle(cornerRadius: Self.eckenradius).fill(.black)
                    Slotraster(punkte: punkte, mass: mass)
                        .clipShape(RoundedRectangle(cornerRadius: Self.eckenradius))
                    RoundedRectangle(cornerRadius: Self.eckenradius).stroke(.quaternary)
                }
            case .unbekannt:
                ZStack {
                    RoundedRectangle(cornerRadius: Self.eckenradius).fill(.quaternary)
                    Text(lok("belegt")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(seitenverhaeltnis, contentMode: .fit)
        .overlay {
            if gewaehlt {
                RoundedRectangle(cornerRadius: Self.eckenradius)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    /// Slotnummer und Zustand als Wort — die Fassung für die Sprachausgabe.
    /// `.bekannt` und `.unbekannt` müssen sich hier unterscheiden, obwohl das
    /// Wort im Block für `.unbekannt` ebenfalls „belegt“ heißt: Sehende sehen
    /// den Unterschied an den Pixeln (da oder nicht), wer nicht sieht, braucht
    /// dafür ein eigenes Wort.
    private var beschriftung: Text {
        switch zustand {
        case .frei:
            return Text(lokf("Slot %d, frei", platz))
        case .bekannt:
            return Text(lokf("Slot %d, belegt", platz))
        case .unbekannt:
            return Text(lokf("Slot %d, unbekannt", platz))
        }
    }
}

/// Zeichnet ein volles 52×16-Punkteraster in die verfügbare Fläche — dieselbe
/// Form, die `Slotzustand.bekannt` trägt. Rein darstellend, wie `GeraeteRahmen`:
/// keine eigene Rasterung, kein Bezug zu `Meldungsbau`.
private struct Slotraster: View {
    let punkte: [String?]
    let mass: Anzeigemass

    var body: some View {
        Canvas { kontext, groesse in
            let spalten = mass.breite
            let zeilen = mass.hoehe
            guard punkte.count == spalten * zeilen else { return }
            let kante = groesse.width / Double(spalten)
            for y in 0..<zeilen {
                for x in 0..<spalten {
                    guard let hex = punkte[y * spalten + x], let farbe = Color(hex: hex) else { continue }
                    let kaestchen = CGRect(x: Double(x) * kante, y: Double(y) * kante, width: kante, height: kante)
                    kontext.fill(Path(kaestchen), with: .color(farbe))
                }
            }
        }
    }
}
