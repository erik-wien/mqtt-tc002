import Foundation

/// Ein Eintrag in der Liste der vorhandenen Zeichnungen — gleich aus welchem
/// der drei Bestaende. Die Groesse ist sein Merkmal, nicht die Liste, in der er
/// steht.
public struct Editoreintrag: Equatable, Sendable, Identifiable {
    public var groesse: Leinwandgroesse
    public var name: String
    /// Die LaMetric-Nummer — nur beim kanonischen 8×8, sonst `nil`.
    public var nummer: String?
    public var datei: URL

    public init(groesse: Leinwandgroesse, name: String, nummer: String?, datei: URL) {
        self.groesse = groesse
        self.name = name
        self.nummer = nummer
        self.datei = datei
    }

    /// Datei und Groesse zusammen: Ein 8×8 und ein 16×16 duerfen denselben
    /// Namen tragen, und tun es.
    public var id: String { "\(groesse.rawValue)/\(datei.path)" }
}

public extension Array where Element == Editoreintrag {
    /// Filtert nach Name und Nummer, unabhaengig von Gross- und
    /// Kleinschreibung. Eine leere Suche laesst die Liste unveraendert — die
    /// Ansicht sucht damit in dem, was sie ohnehin schon gelesen hat, statt bei
    /// jedem Tastendruck neu ins Dateisystem zu gehen.
    func gefiltert(nach suche: String) -> [Editoreintrag] {
        let s = suche.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return self }
        return filter {
            $0.name.localizedCaseInsensitiveContains(s)
                || ($0.nummer?.localizedCaseInsensitiveContains(s) ?? false)
        }
    }
}

/// Die drei Bestaende unter einem Dach.
///
/// **Sie bleiben, wie sie sind** — `Icons`, `Icons16` und `Bilder`, jeder mit
/// seinem eigenen Ordner und seiner eigenen `names.json`. Bestehende Dateien
/// muessen lesbar bleiben; in diesem Projekt hat ein Formatwechsel schon
/// einmal beinahe alle Einstellungen unlesbar gemacht. Zusammengefasst wird
/// allein die **Anzeige**: eine Liste, die Groesse am Eintrag.
///
/// Wohin etwas gehoert, entscheidet die Groesse — nirgends sonst.
public struct Editorbestand {
    private let icons8: Iconsammlung
    private let icons16: Iconsammlung
    private let bilder: Bildersammlung

    public init(icons8: Iconsammlung, icons16: Iconsammlung, bilder: Bildersammlung) {
        self.icons8 = icons8
        self.icons16 = icons16
        self.bilder = bilder
    }

    /// Die Bestaende dieser Installation.
    public static var eigene: Editorbestand {
        Editorbestand(icons8: Iconsammlung(schreibordner: Iconordner.eigene),
                      icons16: Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16),
                      bilder: Bildersammlung(ordner: Bilderordner.eigene))
    }

    /// Die Sammlung, in der eine Groesse zu Hause ist. `nil` fuer die Anzeige —
    /// die liegt in `Bildersammlung`, nicht in einer `Iconsammlung`.
    public func iconsammlung(fuer groesse: Leinwandgroesse) -> Iconsammlung? {
        switch groesse {
        case .icon8: return icons8
        case .icon16: return icons16
        case .anzeige: return nil
        }
    }

    /// Alles, sortiert nach Groesse und darin nach Namen. Die Sortierung ist
    /// Teil des Versprechens: Eine Liste, in der 8×8 und 16×16 durcheinander
    /// stehen, macht das Merkmal am Eintrag zur Suchaufgabe.
    public func alle() -> [Editoreintrag] {
        var ergebnis: [Editoreintrag] = []
        for groesse in Leinwandgroesse.allCases {
            switch groesse {
            case .icon8, .icon16:
                let sammlung = groesse == .icon8 ? icons8 : icons16
                ergebnis += sammlung.alle().map {
                    Editoreintrag(groesse: groesse, name: $0.name,
                                  nummer: groesse.mitNummer ? $0.nummer : nil,
                                  datei: $0.datei)
                }
            case .anzeige:
                ergebnis += bilder.alle().map {
                    Editoreintrag(groesse: groesse, name: $0.name, nummer: nil, datei: $0.datei)
                }
            }
        }
        return ergebnis
    }

    /// Nach Name und Nummer, unabhaengig von Gross- und Kleinschreibung.
    public func gefiltert(nach suche: String) -> [Editoreintrag] {
        alle().gefiltert(nach: suche)
    }

    /// Legt ab, was gerade gemalt ist. `nummer` gilt nur beim 8×8 — bei den
    /// anderen beiden ist der Name der Dateiname.
    @discardableResult
    public func sichern(_ leinwand: Leinwand, name: String, nummer: String) throws -> Editoreintrag {
        guard let groesse = Leinwandgroesse.fuer(leinwand) else {
            throw EditorbestandFehler.unbekannteGroesse
        }
        switch groesse {
        case .icon8, .icon16:
            let sammlung = groesse == .icon8 ? icons8 : icons16
            let schluessel = groesse.mitNummer
                ? nummer.trimmingCharacters(in: .whitespaces)
                : Dateiname.aus(name)
            guard !schluessel.isEmpty else { throw EditorbestandFehler.leererName }
            let sauber = name.trimmingCharacters(in: .whitespaces)
            let icon = try sammlung.sichern(nummer: schluessel,
                                            name: sauber.isEmpty ? schluessel : sauber,
                                            bilder: leinwand.bilder,
                                            verzoegerung: leinwand.verzoegerung)
            return Editoreintrag(groesse: groesse, name: icon.name,
                                 nummer: groesse.mitNummer ? icon.nummer : nil,
                                 datei: icon.datei)
        case .anzeige:
            let sauber = name.trimmingCharacters(in: .whitespaces)
            guard !sauber.isEmpty else { throw EditorbestandFehler.leererName }
            let eintrag = try bilder.sichern(name: sauber, bilder: leinwand.bilder,
                                             verzoegerung: leinwand.verzoegerung)
            return Editoreintrag(groesse: groesse, name: eintrag.name, nummer: nil,
                                 datei: eintrag.datei)
        }
    }

    /// Liest einen Eintrag zurueck auf die Leinwand — alle Einzelbilder, nicht
    /// nur das erste, und mit der Standzeit aus der Datei statt mit dem
    /// Anfangswert: sonst ueberschriebe das naechste Sichern sie still.
    public func oeffnen(_ eintrag: Editoreintrag) throws -> Leinwand {
        let gelesen = try Bildraster.lesenMitZeiten(eintrag.datei,
                                                    breite: eintrag.groesse.breite,
                                                    hoehe: eintrag.groesse.hoehe)
        let zeit = gelesen.first.map { $0.dauer > 0 ? $0.dauer : 0.2 } ?? 0.2
        guard let leinwand = Leinwand(breite: eintrag.groesse.breite,
                                      hoehe: eintrag.groesse.hoehe,
                                      bilder: gelesen.map(\.pixel), verzoegerung: zeit) else {
            throw EditorbestandFehler.nichtLesbar
        }
        return leinwand
    }

    public func loeschen(_ eintrag: Editoreintrag) throws {
        switch eintrag.groesse {
        case .icon8, .icon16:
            let sammlung = eintrag.groesse == .icon8 ? icons8 : icons16
            try sammlung.loeschen(Icon(nummer: eintrag.nummer
                                        ?? eintrag.datei.deletingPathExtension().lastPathComponent,
                                       name: eintrag.name, kategorie: "",
                                       datei: eintrag.datei,
                                       kante: eintrag.groesse.breite))
        case .anzeige:
            try bilder.loeschen(Gemaltes(name: eintrag.name, datei: eintrag.datei))
        }
    }

    /// In welchem Bestand eine Datei landet: in dem **ihrer eigenen Groesse**.
    ///
    /// **Der Editor stellt sich auf die Datei ein, nicht umgekehrt.** Bis zum
    /// 13.09.2026 wurde jede Datei auf die gerade eingestellte Leinwandgroesse
    /// heruntergerechnet — ein 16×16-GIF landete als 8×8, wenn der Editor auf
    /// 8×8 stand, ohne dass jemand danach gefragt haette. Genau daran ist der
    /// Auftraggeber mit zwei `maze`-GIFs haengengeblieben.
    ///
    /// Eine Groesse, die keine der drei ist, wird **abgelehnt** und nicht auf
    /// die naechstliegende gerechnet (entschieden am 13.09.2026): Verkleinern
    /// zerstoert, und es geschah bisher unsichtbar.
    public static func zielgroesse(fuer daten: Data) throws -> Leinwandgroesse {
        guard let masse = Bildraster.groesse(daten) else {
            throw EditorbestandFehler.keinBild
        }
        guard let groesse = Leinwandgroesse.fuer(breite: masse.breite, hoehe: masse.hoehe) else {
            throw EditorbestandFehler.fremdeGroesse(breite: masse.breite, hoehe: masse.hoehe)
        }
        return groesse
    }

    /// Liest eine schon gelesene Bilddatei in den Bestand **ihrer eigenen**
    /// Groesse (siehe `zielgroesse(fuer:)`). Gerechnet wird dabei nichts mehr.
    ///
    /// **`Data`, nicht `URL`.** Eine URL aus dem Dateiwaehler gilt nur zwischen
    /// `startAccessingSecurityScopedResource` und `stop…`; wer sie sich merkt
    /// und hier noch einmal liest, greift am iPad ins Leere. Die Ansicht liest
    /// die Datei deshalb sofort und reicht die Bytes weiter.
    @discardableResult
    public func einlesen(daten: Data, nummer: String, name: String) throws -> Editoreintrag {
        let groesse = try Self.zielgroesse(fuer: daten)
        switch groesse {
        case .icon8, .icon16:
            let sammlung = groesse == .icon8 ? icons8 : icons16
            let schluessel = groesse.mitNummer
                ? nummer.trimmingCharacters(in: .whitespaces)
                : Dateiname.aus(name)
            guard !schluessel.isEmpty else { throw EditorbestandFehler.leererName }
            let sauber = name.trimmingCharacters(in: .whitespaces)
            let icon = try sammlung.einfuegen(daten: daten, nummer: schluessel,
                                              name: sauber.isEmpty ? schluessel : sauber)
            return Editoreintrag(groesse: groesse, name: icon.name,
                                 nummer: groesse.mitNummer ? icon.nummer : nil,
                                 datei: icon.datei)
        case .anzeige:
            let sauber = name.trimmingCharacters(in: .whitespaces)
            guard !sauber.isEmpty else { throw EditorbestandFehler.leererName }
            let eintrag = try bilder.einfuegen(daten: daten, name: sauber)
            return Editoreintrag(groesse: groesse, name: eintrag.name, nummer: nil,
                                 datei: eintrag.datei)
        }
    }
}

public enum EditorbestandFehler: Error, LocalizedError {
    /// Eine Leinwand, die keine der drei Groessen hat — von Hand verbogen oder
    /// aus einer Fassung, die es noch nicht gibt.
    case unbekannteGroesse
    case leererName
    case nichtLesbar
    /// Die gewaehlte Datei ist gar kein Bild.
    case keinBild
    /// Ein Bild, das keine der drei Groessen hat. Es wird abgelehnt, nicht
    /// gerechnet — und die Begruendung nennt beides: was es ist und was geht.
    case fremdeGroesse(breite: Int, hoehe: Int)

    public var errorDescription: String? {
        switch self {
        case .unbekannteGroesse: return lok("Diese Größe lässt sich nicht sichern.")
        case .leererName: return lok("Ohne Namen lässt sich nichts sichern.")
        case .nichtLesbar: return lok("Das lässt sich nicht öffnen.")
        case .keinBild: return lok("Das lässt sich nicht als Bild lesen.")
        case .fremdeGroesse(let breite, let hoehe):
            return lokf("Das Bild ist %d×%d. Aufgenommen werden 8×8, 16×16 und 16×52.",
                        breite, hoehe)
        }
    }
}
