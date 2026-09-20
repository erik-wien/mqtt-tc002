import SwiftUI
import TC002Core
import TC002Modell

/// Die fünf Meldungsplätze als Reihe — eine Fassung für alle drei
/// Sendeflächen (`SendenView`, `EditorBereichView`, `SendeniOS`).
///
/// Sie stand dreimal da, jedesmal mit eigenem Überfahren, eigenem
/// Kontextmenü und eigener ⊗-Überlagerung, und lief dabei auseinander: einmal
/// mit sechs Punkten Abstand, einmal mit acht, einmal mit gedehnten Blöcken
/// und einmal ohne. Der Auftraggeber: *„die anzeige des mittelteils ist sehr
/// unterschiedlich. verwende bitte möglichst das selbe objekt."*
///
/// Was die Aufrufer wirklich unterscheidet, ist einzig, was ein Druck auslöst:
/// Unter „Senden“ holt er zusätzlich die gemerkten Regler zurück, im Editor
/// wählt er nur den Platz. Deshalb ein Abschluss und kein `Binding`.
///
/// Alles andere holt sich die Leiste selbst aus dem Zustand — das Maß der
/// angesehenen Uhr und welche Plätze belegt sind. Beides stand vorher in jeder
/// der drei Ansichten noch einmal, zeichengleich.
public struct Slotleiste: View {
    @Bindable var zustand: AppZustand
    let gewaehlt: Int
    let waehlen: (Int) -> Void

    /// Über welchem Block der Zeiger steht — daran hängt allein das ⊗. Am
    /// Finger bleibt der Wert `nil`: Dort gibt es kein Überfahren, und
    /// gelöscht wird über das Kontextmenü (`slotmenue`).
    @State private var ueberfahren: Int?

    public init(zustand: AppZustand, gewaehlt: Int, waehlen: @escaping (Int) -> Void) {
        self.zustand = zustand
        self.gewaehlt = gewaehlt
        self.waehlen = waehlen
    }

    /// Das Maß der angesehenen Uhr: Eine AWTRIX NG zeigt 32 × 8, nicht die
    /// 52 × 16 der Werksfirmware, und `Slotblock` braucht die richtige
    /// Punktzahl — sonst bleibt der Block leer.
    private var mass: Anzeigemass { zustand.referenzUhr.map(Anzeigemass.fuer) ?? .tc002 }

    private var belegte: Set<Int> { zustand.belegtePlaetze() }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                Button { waehlen(i) } label: {
                    Slotblock(platz: i,
                              zustand: zustand.slotzustand(i, belegt: belegte.contains(i)),
                              gewaehlt: gewaehlt == i,
                              mass: mass)
                        // Die Blöcke teilen sich die Breite: Fünf Kästchen in
                        // der Mitte einer sonst leeren Zeile lasen sich wie
                        // eine Auswahl, die noch weitergeht.
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .onHover { drueber in ueberfahren = drueber ? i : nil }
                // Am Finger das Kontextmenü, am Zeiger zusätzlich das ⊗ beim
                // Überfahren. Ein dauerhaftes ⊗ sah aus wie der Wackelmodus
                // des Startbildschirms und verdeckte das Motiv des Blocks.
                .slotmenue(belegt: belegte.contains(i),
                           loeschen: { loeschen(i) },
                           zeigen: { zustand.umschalten(auf: Meldungsplatz.name(fuer: i)) })
                // Über dem Block und außerhalb seines Knopfes: Innen wäre es
                // Teil von dessen Beschriftung und löste beim Tippen die
                // Platzwahl aus statt zu löschen. Etwas nach außen versetzt,
                // damit es die Vorschau im Block nicht verdeckt.
                .overlay(alignment: .topTrailing) {
                    if ueberfahren == i {
                        MeldungLoeschenKnopf(zustand: zustand, platz: i,
                                             belegt: belegte.contains(i))
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
    }

    /// Räumt den Platz auf den gewählten Uhren — derselbe Weg, den auch das ⊗
    /// nimmt (`AppZustand.loeschen`), samt Slotgedächtnis.
    private func loeschen(_ i: Int) {
        Task { await zustand.loeschen(Meldungsplatz.name(fuer: i)) }
    }
}
