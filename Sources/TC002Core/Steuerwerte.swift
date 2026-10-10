import Foundation

/// Wie die Steuerungsseite Werte der Uhr zeigt: die Helligkeit in Prozent, die
/// Laufzeit in Worten, die Zifferblätter unter deutschen Namen.
public enum Steuerwerte {
    /// 0–255 der Uhr als ganze Prozent. Die Uhr rechnet roh (§10); die Rundung
    /// ist hier und `helligkeitRoh` ihr Gegenstück, sodass jede Prozentstufe
    /// einen Rohwert trifft, der wieder dieselbe Stufe ergibt.
    public static func helligkeitProzent(roh: Int) -> Int {
        let begrenzt = min(max(roh, 0), 255)
        return Int((Double(begrenzt) * 100 / 255).rounded())
    }

    public static func helligkeitRoh(prozent: Int) -> Int {
        let begrenzt = min(max(prozent, 0), 100)
        return Int((Double(begrenzt) * 255 / 100).rounded())
    }

    /// „1 Std 14 Min“, „5 Min“, „42 s“, „2 Tg 3 Std“.
    public static func laufzeit(sekunden: Int) -> String {
        let s = max(sekunden, 0)
        let tage = s / 86_400, stunden = s % 86_400 / 3_600, minuten = s % 3_600 / 60
        if tage > 0 { return lokf("%d Tg %d Std", tage, stunden) }
        if stunden > 0 { return lokf("%d Std %d Min", stunden, minuten) }
        if minuten > 0 { return lokf("%d Min", minuten) }
        return lokf("%d s", s)
    }

    /// Der Name der Uhr (`sheet` …) in der App; ein Zifferblatt, das diese App
    /// nicht kennt, behält den Namen der Uhr.
    public static func zifferblattName(_ name: String) -> String {
        switch name {
        case "sheet": return lok("Blatt")
        case "ring": return lok("Ring")
        case "flap": return lok("Klappzahlen")
        case "month": return lok("Monat")
        case "big": return lok("Groß")
        default: return name
        }
    }
}
