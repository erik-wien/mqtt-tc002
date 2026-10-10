import SwiftUI
import TC002Core

/// Der Block als geteilte Ansicht: Slotnummer, Zustand, ob er gerade gewählt
/// ist. Geteilt zwischen allen Oberflächen (Mac, iPhone, künftig iPad).
///
/// Zeigt nur — rechnet nichts (`Meldungsbau` bleibt unberührt) und wählt
/// nichts selbst: Antippen wird von außen verdrahtet
/// (`Button { … } label: { Slotblock(…) } `), siehe die Sendeansichten.
///
/// Zustand hängt nicht allein an der Farbe: `.frei` (gestrichelter,
/// leerer Rahmen) und `.unbekannt` (gefüllter Rahmen mit einem Fragezeichen)
/// unterscheiden sich auch in der Form; `.bekannt` zeigt Pixel. Ob die
/// mitgelesen oder aus dem Slotgedächtnis gerechnet sind, entscheidet
/// `AppZustand.slotzustand` und steht hier nicht mehr zur Debatte. Der
/// gewählte Block trägt zusätzlich einen eigenen, sichtbaren Rahmen — keine
/// bloße Tönung.
///
/// Die Trefferfläche (`.frame(minWidth:minHeight:)`) sitzt in dieser
/// Ansicht, nicht um sie herum — sonst träfe ein Fingertipp nur die kleine
/// Glyphe bzw. Pixelfläche, sobald ein Aufrufer diese Ansicht als Label eines
/// `Button` verwendet.
public struct Slotblock: View {
    /// 1…5, wie `Meldungsplatz`.
    public let platz: Int
    public let zustand: Slotzustand
    public let gewaehlt: Bool
    /// Das Mass der Uhr, deren Stand dieser Block zeigt: Eine NG kann ein
    /// 32×8-Bild zeigen statt der TC002-Groesse 52×16, und `Slotraster`
    /// braucht das richtige Mass — sonst erwartet es die falsche Punktzahl
    /// und der Block bleibt leer.
    public let mass: Anzeigemass
    /// Läuft die Anzeige in der Schleife der Uhr? Ausgeschaltet bleibt der
    /// Platz belegt, der Block erscheint grau (und sagt es der Sprachausgabe).
    public let inSchleife: Bool

    public init(platz: Int, zustand: Slotzustand, gewaehlt: Bool, mass: Anzeigemass = .vorgabe,
                inSchleife: Bool = true) {
        self.platz = platz
        self.zustand = zustand
        self.gewaehlt = gewaehlt
        self.mass = mass
        self.inSchleife = inSchleife
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
        // Die Wahl hängt sonst allein am Rahmen in der Akzentfarbe.
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }

    /// Die Slotnummer, sichtbar und nicht nur für die Sprachausgabe: Fünf
    /// gestrichelte Rahmen nebeneinander lassen sich sonst nur abzählen, und
    /// die Hilfe setzt darauf, dass Block und Gerätebezeichner (`meldung1`
    /// … `meldung5`) zusammenfinden. Ein Bezeichner, kein Erklärtext —
    /// erklärt wird in der Hilfe, nicht hier.
    ///
    /// Unter dem Block, nicht darin: Sie darf das Pixelbild nicht
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
                    Pixelraster(punkte: punkte, mass: mass)
                        .clipShape(RoundedRectangle(cornerRadius: Self.eckenradius))
                    RoundedRectangle(cornerRadius: Self.eckenradius).stroke(.quaternary)
                }
            case .unbekannt:
                // Ein Zeichen und kein Wort: „belegt“ in einem Kästchen von
                // 44 Punkten Höhe stand als Etikett dort, wo sonst Bilder
                // stehen. Das Fragezeichen sagt dasselbe in der Sprache der
                // Nachbarblöcke — da ist etwas, wir wissen nicht was. Für die
                // Sprachausgabe bleibt es „Slot 2, unbekannt“ (siehe
                // `beschriftung`), der Einblendtext sagt es am Zeiger aus.
                ZStack {
                    RoundedRectangle(cornerRadius: Self.eckenradius).fill(.quaternary)
                    Image(systemName: "questionmark")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .help(lok("belegt — von einer anderen Quelle"))
            }
        }
        .aspectRatio(seitenverhaeltnis, contentMode: .fit)
        // Grau und blass statt einer Farbe: Der Zustand hängt nicht allein am
        // Farbton, und das Motiv bleibt erkennbar.
        .saturation(inSchleife ? 1 : 0)
        .opacity(inSchleife ? 1 : 0.45)
        .overlay {
            if gewaehlt {
                RoundedRectangle(cornerRadius: Self.eckenradius)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    /// Slotnummer und Zustand als Wort — die Fassung für die Sprachausgabe.
    /// `.bekannt` und `.unbekannt` müssen sich hier unterscheiden: Sehende
    /// sehen den Unterschied an den Pixeln (da oder nicht), wer nicht sieht,
    /// braucht dafür ein eigenes Wort. Der Block selbst trägt keins mehr,
    /// sondern ein Fragezeichen.
    private var beschriftung: Text {
        switch zustand {
        case .frei:
            return Text(lokf("Platz %d, frei", platz))
        case .bekannt:
            return Text(inSchleife ? lokf("Platz %d, belegt", platz)
                                   : lokf("Platz %d, belegt, nicht in der Schleife", platz))
        case .unbekannt:
            return Text(inSchleife ? lokf("Platz %d, unbekannt", platz)
                                   : lokf("Platz %d, unbekannt, nicht in der Schleife", platz))
        }
    }
}

public extension View {
    /// Das Menü eines Slotblocks: „Zeigen" und „Löschen", beides nur an einem
    /// belegten Platz.
    ///
    /// Der lange Druck bzw. der Rechtsklick ist die Geste, die das System für
    /// die Handlungen an einem Element vorsieht. Vorher stand an jedem
    /// belegten Block ein rotes ⊗: Es verdeckte das Motiv, sah aus wie der
    /// Wackelmodus des Home-Bildschirms, und seine Trefferfläche lag auf dem
    /// Block, der selbst ein Knopf ist.
    ///
    /// Nur an belegten Blöcken, und deshalb hier statt am Aufrufer: Ein leerer
    /// Platz hat nichts zu löschen und nichts zu zeigen; ein leeres Menü wäre
    /// eine Geste, die nichts tut.
    ///
    /// Geteilt zwischen den Oberflächen — was der eine Block kann, kann der
    /// andere auch.
    ///
    /// „In der Schleife“ (nur wo `schalten` gereicht wird) nimmt die Anzeige
    /// aus dem Umlauf der Uhr, ohne sie zu löschen; das Häkchen zeigt, ob sie
    /// läuft.
    @ViewBuilder
    func slotmenue(belegt: Bool,
                   loeschen: @escaping () -> Void,
                   zeigen: @escaping () -> Void,
                   inSchleife: Bool = true,
                   schalten: ((Bool) -> Void)? = nil) -> some View {
        if belegt {
            contextMenu {
                Button(action: zeigen) { Label("Zeigen", systemImage: "eye") }
                if let schalten {
                    Button { schalten(!inSchleife) } label: {
                        if inSchleife {
                            Label("In der Schleife", systemImage: "checkmark")
                        } else {
                            Text("In der Schleife")
                        }
                    }
                }
                Button(role: .destructive, action: loeschen) {
                    Label("Löschen", systemImage: "trash")
                }
            }
        } else {
            self
        }
    }
}
