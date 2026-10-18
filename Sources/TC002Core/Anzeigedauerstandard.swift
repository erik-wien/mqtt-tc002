import Foundation

/// Die Anzeigedauer der Uhr (`appDurationMs`), wie die Sendeansicht sie neben
/// „Leer oder 0: Es gilt die Anzeigedauer der Uhr“ nennt.
public enum Anzeigedauerstandard {
    /// Der Wert als Text („7 s“, „7–10 s“, „7,5 s“) für die Uhren, an die
    /// gesendet wird. `nil`, wenn keine davon ihren Wert genannt hat: Dann steht
    /// dort keine Zahl, statt einer geratenen. Unterscheiden sich die Uhren,
    /// steht der Bereich von der kleinsten bis zur größten.
    public static func text(millisekunden: [Int?]) -> String? {
        let bekannt = millisekunden.compactMap { $0 }.filter { $0 > 0 }
        guard let kleinste = bekannt.min(), let groesste = bekannt.max() else { return nil }
        if kleinste == groesste { return lokf("%@ s", sekunden(kleinste)) }
        return lokf("%@–%@ s", sekunden(kleinste), sekunden(groesste))
    }

    /// Ganze Sekunden ohne Nachkommastelle, sonst eine („7,5“) in der Schreibweise
    /// der Sprache.
    private static func sekunden(_ ms: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: Double(ms) / 1000)) ?? "\(ms / 1000)"
    }
}
