import Foundation

/// Die eine `names.json`, die in `Icons`, `Icons16` und `Bilder` neben den
/// Dateien liegt: eine JSON-Liste flacher Woerterbuecher, je Eintrag entweder
/// `nummer` (Icons) oder `datei` (Bilder) als Schluessel.
///
/// Beim Umzug darf sie nicht wie eine gewoehnliche Datei behandelt werden.
/// Sie ueberschreiben hiesse, den Namen jedes Icons zu verlieren, das nur die
/// andere Seite kennt — die Datei waere da, ihr Name nicht, und im Bestand
/// stuende die nackte Nummer.
public enum Namensliste {
    static let dateiname = "names.json"

    /// Der Schluessel eines Eintrags. `nummer` bei Icons, `datei` bei Bildern —
    /// eine Regel fuer beide Formate, damit der Umzug nicht wissen muss, in
    /// welchem Bestand er gerade steht. Ein Eintrag ohne beides ist Schrott und
    /// faellt weg.
    static func schluessel(_ eintrag: [String: String]) -> String? {
        eintrag["nummer"] ?? eintrag["datei"]
    }

    static func gelesen(_ datei: URL) -> [[String: String]] {
        guard let daten = try? Data(contentsOf: datei),
              let liste = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return [] }
        return liste
    }

    /// Beide Listen unter einem Dach: Was `vorrang` kennt, gilt; was nur
    /// `nachrang` kennt, kommt dazu. Die Reihenfolge von `vorrang` bleibt
    /// vorn — die Datei soll sich nicht bei jedem Umzug umsortieren.
    public static func zusammengefuehrt(vorrang: [[String: String]],
                                        nachrang: [[String: String]]) -> [[String: String]] {
        var ergebnis = vorrang.filter { schluessel($0) != nil }
        let bekannt = Set(ergebnis.compactMap(schluessel))
        for eintrag in nachrang {
            guard let s = schluessel(eintrag), !bekannt.contains(s) else { continue }
            ergebnis.append(eintrag)
        }
        return ergebnis
    }

    @discardableResult
    static func schreiben(_ liste: [[String: String]], nach datei: URL) -> Bool {
        guard let daten = try? JSONSerialization.data(withJSONObject: liste,
                                                      options: [.prettyPrinted]) else { return false }
        return (try? daten.write(to: datei, options: .atomic)) != nil
    }
}

/// Der Hinweg in den iCloud-Behaelter und der Rueckweg heraus.
///
/// Kopiert wird, nicht verschoben — in beide Richtungen. Nach dem
/// Einschalten liegt der oertliche Bestand unveraendert da, wo er lag, und
/// wer den Abgleich wieder abschaltet, findet ihn vor.
///
/// Der Behaelter fuehrt, in beide Richtungen. Beim Einschalten, weil dort
/// schon der Bestand des anderen Geraets liegen kann — ihn zu ueberschreiben
/// waere genau das Gegenteil eines Abgleichs. Beim Abschalten, weil der
/// oertliche Bestand seither nur noch eine Momentaufnahme vom Tag des
/// Einschaltens ist.
///
/// Was das kostet, ehrlich benannt: Eine Datei, die im Behaelter geloescht
/// wurde, liegt oertlich noch und kommt beim Abschalten zurueck. Ein
/// aufgetauchtes Icon ist der Preis dafuer, dass Abschalten nie etwas
/// wegnimmt — und das ist die Richtung, in der ein Fehler verzeihlich ist.
public enum Bestandsumzug {
    public enum BeiKonflikt: Sendable {
        /// Was am Ziel schon liegt, bleibt liegen.
        case vorhandenesBehalten
        /// Was am Ziel liegt, wird ersetzt.
        case ueberschreiben
    }

    public struct Bilanz: Equatable, Sendable {
        public var kopiert = 0
        public var uebersprungen = 0
        public var fehlgeschlagen = 0

        public init(kopiert: Int = 0, uebersprungen: Int = 0, fehlgeschlagen: Int = 0) {
            self.kopiert = kopiert
            self.uebersprungen = uebersprungen
            self.fehlgeschlagen = fehlgeschlagen
        }

        static func + (a: Bilanz, b: Bilanz) -> Bilanz {
            Bilanz(kopiert: a.kopiert + b.kopiert,
                   uebersprungen: a.uebersprungen + b.uebersprungen,
                   fehlgeschlagen: a.fehlgeschlagen + b.fehlgeschlagen)
        }
    }

    /// Kopiert einen flachen Bestandsordner. `names.json` wird nicht kopiert,
    /// sondern zusammengefuehrt — der Zielordner behaelt die Namen, die nur er
    /// kennt, und bekommt die dazu, die nur die Quelle kennt.
    ///
    /// Unterordner gibt es in diesen Bestaenden nicht; einer, den doch jemand
    /// anlegt, bleibt liegen, statt den Umzug abzubrechen.
    @discardableResult
    /// Liegt dort schon etwas — auch wenn es noch nicht heruntergeladen
    /// ist?
    ///
    /// `FileManager.fileExists` sagt im iCloud-Behaelter nein zu einer Datei,
    /// die dort sehr wohl liegt, aber nur als Platzhalter: Der heisst
    /// `.82.gif.icloud` und traegt den Inhalt noch nicht. Haelt ein Geraet den
    /// Behaelter deshalb fuer leer und kopiert seinen ganzen Bestand hinein,
    /// macht iCloud aus den doppelten Schreibvorgaengen Konfliktkopien —
    /// `82 2.gif`, `Scan 2` — die im Bestand als eigene Icons stehen.
    ///
    /// Ein Platzhalter zaehlt deshalb als vorhanden. Lieber einmal zu wenig
    /// kopiert — die Datei ist ja da — als eine Kopie zu erzeugen, die niemand
    /// wieder loswird.
    static func vorhanden(_ ort: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: ort.path) { return true }
        let platzhalter = ort.deletingLastPathComponent()
            .appendingPathComponent(".\(ort.lastPathComponent).icloud")
        return fm.fileExists(atPath: platzhalter.path)
    }

    /// Legt die vier Ordner im Behaelter an — koordiniert.
    ///
    /// `NSFileCoordinator` mit `.forMerging` wartet, bis der Stand des Ortes
    /// wirklich bekannt ist, und haelt andere Schreiber derweil auf. Ohne das
    /// legten zwei Geraete dieselben vier Ordner unabhaengig an, jedes bevor
    /// der Behaelter bei ihm angekommen war, und iCloud machte acht daraus.
    ///
    /// Blockiert und gehoert deshalb nicht auf den Zeichenweg — gerufen
    /// wird nur beim Umschalten und beim Vorwaermen, beides ohnehin im
    /// Hintergrund.
    @discardableResult
    public static func behaelterVorbereiten(_ ort: Ablageort) -> Bool {
        guard let ferneWurzel = ort.ferneWurzel else { return false }
        var gelungen = false
        var fehler: NSError?
        NSFileCoordinator().coordinate(writingItemAt: ferneWurzel,
                                       options: .forMerging, error: &fehler) { wurzel in
            for bestand in Ablageort.Bestand.allCases {
                try? FileManager.default.createDirectory(
                    at: wurzel.appendingPathComponent(bestand.rawValue),
                    withIntermediateDirectories: true)
            }
            gelungen = true
        }
        return gelungen && fehler == nil
    }

    public static func ordnerKopieren(von quelle: URL, nach ziel: URL,
                                      bei konflikt: BeiKonflikt) -> Bilanz {
        let fm = FileManager.default
        guard let dateien = try? fm.contentsOfDirectory(at: quelle,
                                                        includingPropertiesForKeys: [.isRegularFileKey])
        else { return Bilanz() }
        guard (try? fm.createDirectory(at: ziel, withIntermediateDirectories: true)) != nil
        else { return Bilanz(fehlgeschlagen: dateien.count) }

        var bilanz = Bilanz()
        for datei in dateien {
            let name = datei.lastPathComponent
            if name == Namensliste.dateiname { continue }
            guard (try? datei.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }
            let amZiel = ziel.appendingPathComponent(name)
            if vorhanden(amZiel) {
                switch konflikt {
                case .vorhandenesBehalten:
                    bilanz.uebersprungen += 1
                    continue
                case .ueberschreiben:
                    guard (try? fm.removeItem(at: amZiel)) != nil else {
                        bilanz.fehlgeschlagen += 1
                        continue
                    }
                }
            }
            if (try? fm.copyItem(at: datei, to: amZiel)) != nil {
                bilanz.kopiert += 1
            } else {
                bilanz.fehlgeschlagen += 1
            }
        }
        namenZusammenfuehren(von: quelle, nach: ziel)
        return bilanz
    }

    /// Fuehrt die `names.json` der Quelle in die des Ziels — das Ziel fuehrt.
    private static func namenZusammenfuehren(von quelle: URL, nach ziel: URL) {
        let quelldatei = quelle.appendingPathComponent(Namensliste.dateiname)
        let zieldatei = ziel.appendingPathComponent(Namensliste.dateiname)
        let ausQuelle = Namensliste.gelesen(quelldatei)
        guard !ausQuelle.isEmpty else { return }
        let zusammen = Namensliste.zusammengefuehrt(vorrang: Namensliste.gelesen(zieldatei),
                                                    nachrang: ausQuelle)
        Namensliste.schreiben(zusammen, nach: zieldatei)
    }

    /// Einschalten: der oertliche Bestand in den Behaelter. Was dort schon
    /// liegt, bleibt — es kann der Bestand des anderen Geraets sein.
    @discardableResult
    public static func hinweg(_ ort: Ablageort) -> Bilanz {
        umzug(ort, hinein: true, bei: .vorhandenesBehalten)
    }

    /// Abschalten: der Bestand aus dem Behaelter zurueck auf die Platte, und
    /// zwar ueberschreibend — oertlich liegt nur noch der Stand vom Tag des
    /// Einschaltens.
    @discardableResult
    public static func rueckweg(_ ort: Ablageort) -> Bilanz {
        umzug(ort, hinein: false, bei: .ueberschreiben)
    }

    private static func umzug(_ ort: Ablageort, hinein: Bool, bei konflikt: BeiKonflikt) -> Bilanz {
        guard let ferneWurzel = ort.ferneWurzel else { return Bilanz() }
        var bilanz = Bilanz()
        for bestand in Ablageort.Bestand.allCases {
            let oertlich = ort.oertlicherOrdner(bestand)
            let fern = ferneWurzel.appendingPathComponent(bestand.rawValue)
            bilanz = bilanz + ordnerKopieren(von: hinein ? oertlich : fern,
                                             nach: hinein ? fern : oertlich,
                                             bei: konflikt)
        }
        return bilanz
    }
}
