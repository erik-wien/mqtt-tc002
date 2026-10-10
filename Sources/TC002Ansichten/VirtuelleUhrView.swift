import SwiftUI
import TC002Core
import TC002Modell

/// Was auf der virtuellen Uhr steht — der Geräterahmen und das Bild der
/// aktiven Anzeige.
///
/// Gezeigt wird, was die Uhr in ihren Bildspeicher gezeichnet hat
/// (`VirtuelleNGUhr.bildschirm`): Zeichenbefehle, Text und Icons dagegen
/// nicht — die Ansicht bleibt dann schwarz. Das ist der Unterschied zur
/// Vorschau im Sendebildschirm: Die zeigt, was die App schicken will, diese
/// Ansicht, was angekommen ist.
public struct VirtuelleUhrView: View {
    private let betrieb: Virtuelleuhrbetrieb

    /// Ohne Vorgabewert: `Virtuelleuhrbetrieb.gemeinsam` ist an den
    /// Hauptthread gebunden, ein Vorgabewert im Kopf einer Funktion wird
    /// dagegen ausserhalb davon ausgewertet. Wer die Ansicht baut, steht
    /// ohnehin im Hauptthread und reicht sie herein.
    public init(betrieb: Virtuelleuhrbetrieb) {
        self.betrieb = betrieb
    }

    private static let kante = 8.0

    public var body: some View {
        VStack(spacing: 16) {
            GeraeteRahmen(hoehe: Double(VirtuelleNGUhr.hoehe) * Self.kante) {
                anzeige
                    .accessibilityElement()
                    .accessibilityLabel(Text(lokf("Anzeige der virtuellen Uhr, %d mal %d Pixel",
                                                  VirtuelleNGUhr.breite, VirtuelleNGUhr.hoehe)))
            }
            zeile
        }
        .padding()
        .frame(minWidth: 520)
    }

    private var anzeige: some View {
        let punkte = betrieb.bildschirm
        return Canvas { kontext, _ in
            for y in 0..<VirtuelleNGUhr.hoehe {
                for x in 0..<VirtuelleNGUhr.breite {
                    let wert = punkte[y * VirtuelleNGUhr.breite + x]
                    guard wert != 0 else { continue }
                    let farbe = Color(red: Double(wert >> 16 & 255) / 255,
                                      green: Double(wert >> 8 & 255) / 255,
                                      blue: Double(wert & 255) / 255)
                    kontext.fill(Path(CGRect(x: Double(x) * Self.kante, y: Double(y) * Self.kante,
                                             width: Self.kante, height: Self.kante)),
                                 with: .color(farbe))
                }
            }
        }
    }

    private var zeile: some View {
        let angekommen = betrieb.zustand.apps.filter { !$0.eingebaut }.count
        return VStack(spacing: 4) {
            if !betrieb.laeuft {
                Text("Die virtuelle Uhr läuft nicht — einzuschalten in den Einstellungen.")
            } else if angekommen == 0 {
                Text("Noch nichts angekommen. Unter „Senden“ an die Uhr mit dieser Adresse schicken.")
            } else {
                Text(lokf("%@ — %d angekommen", betrieb.zustand.aktiveApp, angekommen))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}
