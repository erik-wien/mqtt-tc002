import SwiftUI
import TC002Core
import TC002Modell

/// Waehlt einen von fuenf festen Anzeigenplaetzen. Der gewaehlte Platz *ist* der
/// Anzeigenname ("meldung1" … "meldung5") — das ersetzt ein freies Namensfeld:
/// derselbe Platz ueberschreibt, was dort steht, ein anderer tritt daneben, und
/// die Uhr blaettert zwischen den belegten Plaetzen. Ein belegter Platz ist
/// orange umrandet, damit klar ist, was ein erneutes Senden ersetzen wuerde.
struct MeldungsplatzWahl: View {
    @Binding var platz: Int
    let belegtePlaetze: Set<Int>

    private static let ziffern = ["①", "②", "③", "④", "⑤"]

    var body: some View {
        HStack(spacing: 4) {
            Text("Meldung").font(.caption).foregroundStyle(.secondary)
            ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                let belegt = belegtePlaetze.contains(i)
                Button { platz = i } label: {
                    Text(Self.ziffern[i - 1]).font(.title3)
                        .frame(width: 26, height: 24)
                }
                .buttonStyle(.plain)
                .background(platz == i ? Color.accentColor.opacity(0.3) : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(belegt ? Color.orange : Color.secondary.opacity(0.4), lineWidth: belegt ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .help(belegt ? lokf("%@ ist belegt — Senden ersetzt diese Anzeige.", Meldungsplatz.name(fuer: i))
                             : lokf("%@ ist frei.", Meldungsplatz.name(fuer: i)))
            }
        }
    }
}

/// Löscht den gewählten Meldungsplatz auf den gewählten Uhren. Er steht neben
/// der Platzwahl, weil man den Platz dort gerade in der Hand hat — unter
/// „Anzeigen" geht es weiterhin auch, nur eben nicht dort, wo man arbeitet.
///
/// Symbol und Einblendtext sagen ausdrücklich, dass es die Uhr betrifft: im
/// Malbereich sitzt daneben „Leeren", und das meint das Bild, nicht das Gerät.
struct MeldungLoeschenKnopf: View {
    @Bindable var zustand: AppZustand
    let platz: Int
    /// Ein leerer Platz lässt sich nicht löschen. Woher das bekannt ist, steht
    /// bei `belegtePlaetze`: gemeldet schlägt gemerkt.
    let belegt: Bool

    @State private var laeuft = false

    var body: some View {
        Button {
            laeuft = true
            let name = Meldungsplatz.name(fuer: platz)
            Task { await zustand.loeschen(name); laeuft = false }
        } label: {
            Image(systemName: "trash")
        }
        .disabled(!belegt || laeuft || zustand.ziele().isEmpty)
        .help(lokf("Meldung %d auf der Uhr löschen", platz))
    }
}
