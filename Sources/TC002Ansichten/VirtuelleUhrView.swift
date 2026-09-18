import SwiftUI
import TC002Core
import TC002Modell

/// Was auf der virtuellen Uhr steht — der Geräterahmen, das zuletzt
/// Angekommene, und das Blättern durch die belegten Plätze.
///
/// Gezeigt wird, was wirklich über den Draht kam: Die Nutzlast wird zurück in
/// Pixel zerlegt (`Anzeigen.pixelAusCustomNutzlast`), auf demselben Weg, den
/// die App beim Mitlesen über MQTT geht. Das ist der Unterschied zur Vorschau
/// im Sendebildschirm — die zeigt, was die App schicken will, diese
/// Ansicht, was angekommen ist.
public struct VirtuelleUhrView: View {
    private let betrieb: Virtuelleuhrbetrieb
    /// Welcher Platz gerade dran ist. Eine neue Anzeige holt sich die Ansicht
    /// sofort (so hält es die Firmware auch); danach wird im eingestellten
    /// Takt weitergeblättert.
    @State private var gezeigt: String?

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
            GeraeteRahmen(hoehe: Double(Pixelfeld.hoeheStandard) * Self.kante,
                          typ: .tc002) {
                anzeige
            }
            zeile
        }
        .padding()
        .frame(minWidth: 520)
        .onChange(of: betrieb.zustand.aktuelle) { _, neu in gezeigt = neu }
        .onAppear { gezeigt = betrieb.zustand.aktuelle }
        .task(id: takt) { await blaettern() }
    }

    /// Der Takt in Sekunden, `nil` heisst „kein Wechsel" — dann bleibt die
    /// Uhr beim ersten stehen, genau wie das Geraet bei `carouselSpeed 0`.
    private var takt: Int? {
        let wert = betrieb.zustand.seitenwechsel
        return wert > 0 ? wert : nil
    }

    @ViewBuilder
    private var anzeige: some View {
        if let feld = betrieb.bild(von: gezeigt) {
            Canvas { kontext, _ in
                for y in 0..<feld.hoehe {
                    for x in 0..<feld.breite {
                        guard let hex = feld.farbe(x: x, y: y), let farbe = Color(hex: hex) else { continue }
                        kontext.fill(Path(CGRect(x: Double(x) * Self.kante, y: Double(y) * Self.kante,
                                                 width: Self.kante, height: Self.kante)),
                                     with: .color(farbe))
                    }
                }
            }
        } else if gezeigt != nil {
            // Eine Nutzlast, die sich nicht in Rechtecke zerlegen laesst — ein
            // Lauf-GIF etwa. Die App weiss dann auch bei einer echten Uhr
            // nicht, was dort steht; hier ehrlich dasselbe zu sagen ist
            // besser, als ein Bild zu erfinden.
            Text("angekommen, aber nicht als Pixel zerlegbar")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
                .padding(6)
        }
    }

    private var zeile: some View {
        let belegt = betrieb.zustand.reihenfolge
        return VStack(spacing: 4) {
            if !betrieb.laeuft {
                Text("Die virtuelle Uhr läuft nicht — einzuschalten in den Einstellungen.")
            } else if belegt.isEmpty {
                Text("Noch nichts angekommen. Unter „Senden“ an die Uhr mit dieser Adresse schicken.")
            } else {
                Text(lokf("%@ — %d von %d belegt", gezeigt ?? "—", belegt.count, Meldungsplatz.anzahl))
                if takt == nil {
                    Text("kein Seitenwechsel — die Uhr bleibt beim ersten stehen")
                } else {
                    Text(lokf("blättert alle %d Sekunden", betrieb.zustand.seitenwechsel))
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    /// Blättert im Takt weiter — in der Reihenfolge des Eintreffens, die
    /// der Zustand führt. Ohne Takt (`kein Wechsel`) läuft nichts.
    private func blaettern() async {
        guard let takt else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double(takt)))
            guard !Task.isCancelled else { return }
            let liste = betrieb.zustand.reihenfolge
            guard liste.count > 1 else { continue }
            let jetzt = liste.firstIndex(of: gezeigt ?? "") ?? 0
            gezeigt = liste[(jetzt + 1) % liste.count]
        }
    }
}
