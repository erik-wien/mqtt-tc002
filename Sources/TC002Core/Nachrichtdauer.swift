import Foundation

/// Wie lange eine Nachricht steht — die eine Wahl „Steht …“ statt der früheren
/// drei Regler (Halten, Dauer, Durchläufe). Jede Art gehört zu genau einem
/// Feld der Nutzlast (`docs/awtrix-ng-protokoll.md` §5.6): `hold`,
/// `durationMs` oder `repeat`; die anderen beiden fehlen.
public enum Nachrichtdauer: Equatable, Sendable {
    /// `hold:true`; die Nachricht bleibt, bis sie zurückgezogen wird.
    case bisZurueckgezogen
    /// `durationMs` = Sekunden · 1000.
    case sekunden(Int)
    /// `repeat`: wie oft ein laufender Text durchzieht. Passt der Text ins
    /// Display, läuft nichts durch, und die Uhr nimmt ihre Anzeigedauer.
    case durchlaeufe(Int)

    public static let sekundenbereich = Kurzbefehlswerte.dauerbereich
    public static let durchlaufbereich = 1...Nachrichtwahl.hoechstdurchlaeufe

    /// `hold` der Nutzlast.
    public var halten: Bool { self == .bisZurueckgezogen }

    /// `durationMs / 1000`, in den Grenzen der Uhr.
    public var dauerSekunden: Int? {
        if case .sekunden(let n) = self { return Self.sekundenbereich.clamp(n) }
        return nil
    }

    /// `repeat`, in 1…`hoechstdurchlaeufe`.
    public var wiederholungen: Int? {
        if case .durchlaeufe(let n) = self { return Self.durchlaufbereich.clamp(n) }
        return nil
    }
}

/// Die Art der Wahl „Steht …“ ohne Zahl; der Rohwert liegt in `@AppStorage`.
public enum Nachrichtdauerart: String, CaseIterable, Sendable {
    case bisZurueckgezogen, sekunden, durchlaeufe
}

/// Was die Oberfläche von „Steht …“ speichert: die Art und beide Zahlen, damit
/// ein Wechsel der Art die Zahl der anderen nicht verliert.
public struct Nachrichtdauerwahl: Equatable, Sendable {
    public var art: Nachrichtdauerart
    public var sekunden: Int
    public var durchlaeufe: Int

    /// Die Vorgabe ist „bis ich sie zurückziehe“ (`hold:true`). Die Zahlen sind
    /// die Startwerte, falls jemand die Art wechselt.
    public init(art: Nachrichtdauerart = .bisZurueckgezogen, sekunden: Int = 10, durchlaeufe: Int = 2) {
        self.art = art
        self.sekunden = sekunden
        self.durchlaeufe = durchlaeufe
    }

    public var dauer: Nachrichtdauer {
        switch art {
        case .bisZurueckgezogen: return .bisZurueckgezogen
        case .sekunden: return .sekunden(sekunden)
        case .durchlaeufe: return .durchlaeufe(durchlaeufe)
        }
    }

    /// „N Durchläufe“ wirkt nur bei Text, der durchläuft. `textLaeuft` ist, ob
    /// er auf mindestens einer Zieluhr durchläuft (`Meldungsbau.passt` ist dort
    /// falsch). Die Art ist sperrbar, weil man einen längeren Text tippen kann.
    public static func durchlaeufeMoeglich(textLaeuft: Bool) -> Bool { textLaeuft }

    /// Ist „Durchläufe“ gewählt und läuft nichts durch, gilt die Anzeigedauer
    /// der Uhr (das sagt der Hinweis unter der Wahl).
    public func faelltAufAnzeigedauer(textLaeuft: Bool) -> Bool {
        art == .durchlaeufe && !textLaeuft
    }

    // MARK: Übernahme der drei alten Regler

    public static let schluessel = "senden.nachricht.steht"
    public static let sekundenSchluessel = "senden.nachricht.sekunden"
    public static let durchlaeufeSchluessel = "senden.nachricht.durchlaeufe"

    /// Aus den früheren Reglern: gehalten → „bis zurückgezogen“; sonst eine
    /// Dauer über 0 → Sekunden; sonst die Durchläufe mit dem alten Wert.
    public static func uebernommen(halten: Bool, dauerText: String, durchlaeufe: Int?) -> Nachrichtdauerwahl {
        var w = Nachrichtdauerwahl(art: .durchlaeufe)
        if let durchlaeufe { w.durchlaeufe = Nachrichtdauer.durchlaufbereich.clamp(durchlaeufe) }
        if let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 {
            w.sekunden = Nachrichtdauer.sekundenbereich.clamp(n)
            w.art = halten ? .bisZurueckgezogen : .sekunden
        } else {
            w.art = halten ? .bisZurueckgezogen : .durchlaeufe
        }
        return w
    }

    /// Einmalig beim Start: Fehlt der neue Schlüssel, wird aus den alten Werten
    /// (`senden.nachricht.halten`, `senden.dauer`, `senden.nachricht.durchlaeufe`)
    /// geschrieben. Der alte Halten-Schlüssel wird danach entfernt; die
    /// Anzeigedauer `senden.dauer` bleibt, sie gehört der Anzeige. Findet sich
    /// keiner der alten Schlüssel und auch kein gespeicherter Text, ist es eine
    /// frische Installation: Es gilt die Vorgabe.
    public static func uebernehmen(in ablage: UserDefaults) {
        guard ablage.object(forKey: schluessel) == nil else { return }
        let alt = ["senden.nachricht.halten", durchlaeufeSchluessel, "senden.dauer", "senden.text"]
        guard alt.contains(where: { ablage.object(forKey: $0) != nil }) else { return }
        let w = uebernommen(halten: ablage.bool(forKey: "senden.nachricht.halten"),
                            dauerText: ablage.string(forKey: "senden.dauer") ?? "",
                            durchlaeufe: ablage.object(forKey: durchlaeufeSchluessel) as? Int)
        ablage.set(w.art.rawValue, forKey: schluessel)
        ablage.set(w.sekunden, forKey: sekundenSchluessel)
        ablage.set(w.durchlaeufe, forKey: durchlaeufeSchluessel)
        ablage.removeObject(forKey: "senden.nachricht.halten")
    }
}

extension ClosedRange where Bound == Int {
    func clamp(_ n: Int) -> Int { Swift.min(Swift.max(n, lowerBound), upperBound) }
}
