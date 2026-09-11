import SwiftUI

/// Waehlt einen von fuenf festen Anzeigenplaetzen. Der gewaehlte Platz *ist* der
/// Anzeigenname ("meldung1" … "meldung5") — das ersetzt ein freies Namensfeld:
/// derselbe Platz ueberschreibt, was dort steht, ein anderer tritt daneben, und
/// die Uhr blaettert zwischen den belegten Plaetzen. Ein belegter Platz ist
/// orange umrandet, damit klar ist, was ein erneutes Senden ersetzen wuerde.
struct MeldungsplatzWahl: View {
    @Binding var platz: Int
    let belegtePlaetze: Set<Int>

    static let anzahl = 5
    private static let ziffern = ["①", "②", "③", "④", "⑤"]

    /// Der Anzeigenname eines Platzes — die einzige Stelle, die "meldung" + Zahl bildet.
    static func name(fuer platz: Int) -> String { "meldung\(platz)" }

    var body: some View {
        HStack(spacing: 4) {
            Text("Meldung").font(.caption).foregroundStyle(.secondary)
            ForEach(1...Self.anzahl, id: \.self) { i in
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
                .help(belegt ? "\(Self.name(fuer: i)) ist belegt — Senden ersetzt diese Anzeige."
                             : "\(Self.name(fuer: i)) ist frei.")
            }
        }
    }
}
