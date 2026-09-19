import Foundation

/// Ein Eintrag in der Liste der vorhandenen Zeichnungen — gleich aus welchem
/// der drei Bestaende. Die Groesse ist sein Merkmal, nicht die Liste, in der er
/// steht.
///
/// `Hashable`, weil er am Telefon der Wert eines Navigationspfads ist
/// (`NavigationStack(path:)`).
public struct Editoreintrag: Hashable, Sendable, Identifiable {
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

    /// Der Dateiname ohne Endung — genau der Schluessel, unter dem dieser
    /// Eintrag liegt (`Editorbestand.schluessel(groesse:nummer:name:)`).
    public var schluessel: String { datei.deletingPathExtension().lastPathComponent }
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
/// Sie bleiben, wie sie sind — `Icons`, `Icons16` und `Bilder`, jeder mit
/// seinem eigenen Ordner und seiner eigenen `names.json`. Bestehende Dateien
/// muessen lesbar bleiben. Zusammengefasst wird allein die Anzeige: eine
/// Liste, die Groesse am Eintrag.
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
                    Editoreintrag(groesse: groesse, name: $0.name, nummer: $0.nummer,
                                  datei: $0.datei)
                }
            }
        }
        return ergebnis
    }

    /// Der Eintrag zu einem Icon einer Sammlung — fuer den Weg, der ein Icon
    /// holt und es danach auf die Leinwand legen soll.
    ///
    /// Die Groesse kommt aus der Kante des Icons, nicht aus der Annahme,
    /// ein geholtes sei immer 8×8 — sonst rechnet der Import ein 16×16 auf die
    /// eingestellte Leinwandgroesse herunter. `nil`, wenn die Kante keine der
    /// drei Groessen ist.
    public static func eintrag(fuer icon: Icon) -> Editoreintrag? {
        guard let groesse = Leinwandgroesse.fuer(breite: icon.kante, hoehe: icon.kante) else {
            return nil
        }
        return Editoreintrag(groesse: groesse, name: icon.name,
                             nummer: groesse.mitNummer ? icon.nummer : nil, datei: icon.datei)
    }

    /// Nach Name und Nummer, unabhaengig von Gross- und Kleinschreibung.
    public func gefiltert(nach suche: String) -> [Editoreintrag] {
        alle().gefiltert(nach: suche)
    }

    /// Unter welchem Namen etwas abgelegt wird: bei 8×8 die Nummer, sonst der
    /// Name als Dateiname. Leer heisst, dass sich so nichts sichern laesst.
    ///
    /// Eine Stelle, weil drei davon abhaengen: das Sichern, das Einlesen
    /// und die Frage, ob dort schon etwas liegt. Liefen sie auseinander,
    /// warnte das Blatt vor einer Belegung, die es nicht gibt — oder schwiege
    /// zu einer, die es gibt.
    /// `nummerIstDateiname`, nicht `mitNummer`: Ein 52×16 *hat* eine
    /// Nummer, *heisst* aber weiter nach seinem Namen — sonst laege jede
    /// bestehende Bildersammlung unter neuen Schluesseln.
    public static func schluessel(groesse: Leinwandgroesse,
                                  nummer: String, name: String) -> String {
        groesse.nummerIstDateiname ? nummer.trimmingCharacters(in: .whitespaces)
                                   : Dateiname.aus(name)
    }

    /// Was unter diesem Schluessel schon liegt — der Eintrag, den ein Sichern
    /// oder Einlesen ersetzen wuerde, sonst `nil`.
    ///
    /// Gesucht wird in einer schon gelesenen Liste und nicht im Dateisystem:
    /// Die Ansicht fragt bei jedem Tastendruck.
    public static func belegt(in vorhandene: [Editoreintrag], groesse: Leinwandgroesse,
                              nummer: String, name: String) -> Editoreintrag? {
        let gesucht = schluessel(groesse: groesse, nummer: nummer, name: name)
        guard !gesucht.isEmpty else { return nil }
        // Ohne Ruecksicht auf Gross- und Kleinschreibung: Die Dateisysteme,
        // auf denen diese App laeuft, unterscheiden sie ueblicherweise nicht
        // — „maze.gif" ersetzt dort „Maze.gif". Eine Warnung, die das
        // uebersieht, waere genau der Fehler, gegen den sie steht.
        return vorhandene.first {
            $0.groesse == groesse && $0.schluessel.caseInsensitiveCompare(gesucht) == .orderedSame
        }
    }

    /// Nummer und Name, aus einem Dateinamen ohne Endung erraten.
    ///
    /// LaMetric-Icons heissen ueblicherweise `<Nummer>_<Titel>`: Aus
    /// `2981_Severe TStorm` wird die Nummer `2981` und der Titel
    /// `Severe TStorm`.
    ///
    /// Nur eine reine Ziffernfolge vor dem ersten Unterstrich zaehlt;
    /// `maze_2` ist keine Nummer, sondern ein Name. Besteht der Dateiname aus
    /// nichts als Ziffern, ist er beides. Und wo nichts zu erraten ist, bleibt
    /// die Nummer leer, statt einen Dateinamen als LaMetric-Nummer
    /// auszugeben: „Öffnen" bleibt dann gesperrt, bis jemand eine eintraegt.
    public static func vorschlag(fuerDateinamen basis: String) -> (nummer: String, name: String) {
        let sauber = basis.trimmingCharacters(in: .whitespaces)
        func istZiffern(_ s: Substring) -> Bool {
            !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber }
        }
        if istZiffern(Substring(sauber)) { return (sauber, sauber) }
        if let strich = sauber.firstIndex(of: "_") {
            let vorn = sauber[sauber.startIndex..<strich]
            let hinten = sauber[sauber.index(after: strich)...]
                .trimmingCharacters(in: .whitespaces)
            if istZiffern(vorn), !hinten.isEmpty { return (String(vorn), hinten) }
        }
        return ("", sauber)
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
            let schluessel = Self.schluessel(groesse: groesse, nummer: nummer, name: name)
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
                                             verzoegerung: leinwand.verzoegerung,
                                             nummer: nummer)
            return Editoreintrag(groesse: groesse, name: eintrag.name, nummer: eintrag.nummer,
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

    /// Benennt einen Eintrag um — Name und, wo es eine gibt, Nummer.
    ///
    /// Eine Umbenennung benennt eine Datei um, und deshalb gelten dieselben
    /// Regeln wie beim Sichern: Wohin es gehoert, entscheidet die Groesse;
    /// unter welchem Schluessel es liegt, `schluessel(groesse:nummer:name:)`;
    /// und was dort schon liegt, wird ersetzt statt abgewiesen (die Oberflaeche
    /// sagt es vorher). Bei 52×16 aendert eine neue Werknummer nichts am
    /// Dateinamen — sie heisst weiter nach ihrem Namen.
    @discardableResult
    public func umbenennen(_ eintrag: Editoreintrag, name: String,
                           nummer: String) throws -> Editoreintrag {
        switch eintrag.groesse {
        case .icon8, .icon16:
            let sammlung = eintrag.groesse == .icon8 ? icons8 : icons16
            let schluessel = Self.schluessel(groesse: eintrag.groesse, nummer: nummer, name: name)
            guard !schluessel.isEmpty else { throw EditorbestandFehler.leererName }
            // Die Kategorie schlaegt die Sammlung selbst nach; hier ist sie
            // nicht bekannt, und eine erfundene stuende hinterher in der Datei.
            let alt = Icon(nummer: eintrag.schluessel, name: eintrag.name, kategorie: "",
                           datei: eintrag.datei, kante: eintrag.groesse.breite)
            let icon = try sammlung.umbenennen(alt, nummer: schluessel, name: name)
            return Editoreintrag(groesse: eintrag.groesse, name: icon.name,
                                 nummer: eintrag.groesse.mitNummer ? icon.nummer : nil,
                                 datei: icon.datei)
        case .anzeige:
            let alt = Gemaltes(name: eintrag.name, nummer: eintrag.nummer, datei: eintrag.datei)
            let neu = try bilder.umbenennen(alt, name: name, nummer: nummer)
            return Editoreintrag(groesse: eintrag.groesse, name: neu.name, nummer: neu.nummer,
                                 datei: neu.datei)
        }
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

    /// In welchem Bestand eine Datei landet: im kleinsten Raster, der sie
    /// fasst. Passt sie genau, bleibt sie Byte fuer Byte; ist sie kleiner,
    /// wird sie beim Einlesen mittig eingepasst (`Bildraster.eingepasst`).
    ///
    /// Der Editor stellt sich auf die Datei ein, nicht umgekehrt. Ein
    /// Herunterrechnen auf die gerade eingestellte Leinwandgroesse liesse ein
    /// 16×16-GIF unbemerkt als 8×8 landen, sobald der Editor auf 8×8 steht.
    /// Groesser als die Anzeige wird abgelehnt statt verkleinert: Verkleinern
    /// zerstoert, und unsichtbar geschehen darf das nicht.
    public static func zielgroesse(fuer daten: Data) throws -> Leinwandgroesse {
        guard let masse = Bildraster.groesse(daten) else {
            throw EditorbestandFehler.keinBild
        }
        guard let groesse = Leinwandgroesse.passend(breite: masse.breite, hoehe: masse.hoehe) else {
            throw EditorbestandFehler.fremdeGroesse(breite: masse.breite, hoehe: masse.hoehe)
        }
        return groesse
    }

    /// Liest eine schon gelesene Bilddatei in den Bestand ihrer eigenen
    /// Groesse (siehe `zielgroesse(fuer:)`). Gerechnet wird dabei nichts mehr.
    ///
    /// `Data`, nicht `URL`. Eine URL aus dem Dateiwaehler gilt nur zwischen
    /// `startAccessingSecurityScopedResource` und `stop…`; wer sie sich merkt
    /// und hier noch einmal liest, greift am iPad ins Leere. Die Ansicht liest
    /// die Datei deshalb sofort und reicht die Bytes weiter.
    @discardableResult
    public func einlesen(daten: Data, nummer: String, name: String) throws -> Editoreintrag {
        let groesse = try Self.zielgroesse(fuer: daten)
        // Kleineres wird eingepasst, Passendes bleibt Byte fuer Byte, wie es
        // war.
        let passend = try Bildraster.eingepasst(daten, breite: groesse.breite, hoehe: groesse.hoehe)
        switch groesse {
        case .icon8, .icon16:
            let sammlung = groesse == .icon8 ? icons8 : icons16
            let schluessel = Self.schluessel(groesse: groesse, nummer: nummer, name: name)
            guard !schluessel.isEmpty else { throw EditorbestandFehler.leererName }
            let sauber = name.trimmingCharacters(in: .whitespaces)
            let icon = try sammlung.einfuegen(daten: passend, nummer: schluessel,
                                              name: sauber.isEmpty ? schluessel : sauber)
            return Editoreintrag(groesse: groesse, name: icon.name,
                                 nummer: groesse.mitNummer ? icon.nummer : nil,
                                 datei: icon.datei)
        case .anzeige:
            let sauber = name.trimmingCharacters(in: .whitespaces)
            guard !sauber.isEmpty else { throw EditorbestandFehler.leererName }
            let eintrag = try bilder.einfuegen(daten: passend, name: sauber, nummer: nummer)
            return Editoreintrag(groesse: groesse, name: eintrag.name, nummer: eintrag.nummer,
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
    /// Ein Bild, das nicht auf die Anzeige passt. Es wird abgelehnt, nicht
    /// verkleinert — und die Begruendung nennt beides: was es ist und was geht.
    case fremdeGroesse(breite: Int, hoehe: Int)

    public var errorDescription: String? {
        switch self {
        case .unbekannteGroesse: return lok("Diese Größe lässt sich nicht sichern.")
        case .leererName: return lok("Ohne Namen lässt sich nichts sichern.")
        case .nichtLesbar: return lok("Das lässt sich nicht öffnen.")
        case .keinBild: return lok("Das lässt sich nicht als Bild lesen.")
        case .fremdeGroesse(let breite, let hoehe):
            return lokf("Das Bild ist %d×%d und passt nicht auf die Anzeige (52×16). Verkleinert wird nicht.",
                        breite, hoehe)
        }
    }
}
