import SwiftUI
import TC002Core

/// Was die App über einen der fünf festen Plätze weiß — nicht zwei bequeme
/// Fälle, sondern drei ehrliche (Entwurf, Abschnitt „Drei Zustände je Block“).
///
/// Die Uhr verrät über `customList` nur **Namen**, nie den Inhalt. Belegt
/// oder frei ist damit Tatsache; was darauf steht, weiß die App nur, wenn sie
/// die Sendung mitgelesen hat:
///
/// - `.frei` — kein Name auf diesem Platz.
/// - `.bekannt(punkte)` — ein Name ist da, und die App hat die Sendung
///   mitgelesen. `punkte` sind die 52×16 Pixel in derselben Form, die
///   `Meldungsbau.feld(...).punkteRoh` liefert — genau diese Form gibt auch
///   das Zerlegen einer mitgelesenen Nutzlast zurück.
/// - `.unbekannt` — ein Name ist da, aber die App weiß nicht, was darauf
///   steht (nie mitgelesen, oder ein Weg, der sich nicht zerlegen lässt, z. B.
///   ein Lauf-GIF). Das ist keine Lücke, sondern die Auskunft: ein Block, der
///   hier einen Inhalt zeigte, behauptete etwas, das niemand mehr belegen
///   kann.
///
/// Warum ein Platz `.unbekannt` ist, steht nicht hier — das sagt die Hilfe.
public enum Slotzustand: Equatable, Sendable {
    case frei
    case bekannt([String?])
    case unbekannt
}

/// Der Block als geteilte Ansicht: Slotnummer, Zustand, ob er gerade gewählt
/// ist. Geteilt zwischen allen Oberflächen (Mac, iPhone, künftig iPad).
///
/// Zeigt nur — rechnet nichts (`Meldungsbau` bleibt unberührt) und wählt
/// nichts selbst: Antippen wird von außen verdrahtet
/// (`Button { … } label: { Slotblock(…) } `), siehe die Sendeansichten.
///
/// Zustand hängt **nicht allein an der Farbe**: `.frei` (gestrichelter,
/// leerer Rahmen) und `.unbekannt` (gefüllter Rahmen mit dem Wort „belegt“)
/// unterscheiden sich auch in der Form; `.bekannt` zeigt die tatsächlichen
/// Pixel. Der gewählte Block trägt zusätzlich einen eigenen, sichtbaren
/// Rahmen — keine bloße Tönung.
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

    public init(platz: Int, zustand: Slotzustand, gewaehlt: Bool) {
        self.platz = platz
        self.zustand = zustand
        self.gewaehlt = gewaehlt
    }

    private static let seitenverhaeltnis = Double(Pixelfeld.breiteStandard) / Double(Pixelfeld.hoeheStandard)
    private static let eckenradius = 6.0

    public var body: some View {
        inhalt
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(beschriftung)
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
                    Slotraster(punkte: punkte)
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
        .aspectRatio(Self.seitenverhaeltnis, contentMode: .fit)
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

    var body: some View {
        Canvas { kontext, groesse in
            let spalten = Pixelfeld.breiteStandard
            let zeilen = Pixelfeld.hoeheStandard
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

private extension Color {
    /// Wandelt "#RRGGBB" in eine Farbe. Ungültige Angaben ergeben nil.
    ///
    /// Eigene, kleine Kopie: `TC002App`/`Sources/TC002App/VorschauView.swift`
    /// und `TC002iOS/Farbe.swift` haben dieselbe, aber `TC002Ansichten` ist ein
    /// eigenes Modul und teilt mit ihnen keine Typen.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((wert >> 16) & 0xFF) / 255,
                  green: Double((wert >> 8) & 0xFF) / 255,
                  blue: Double(wert & 0xFF) / 255)
    }
}
