import Foundation

/// Schliesst maschinell aus, ob ein Paar aus Schrift und Groesse fuer die
/// 52×16-Anzeige taugt — und sagt, woran es liegt.
///
/// **Die Pruefung sagt nur Nein, nie Ja.** Eine leere Liste heisst „nicht
/// ausgeschlossen", nicht „brauchbar": Zwei Zeichen koennen sich um ein
/// einziges Pixel unterscheiden und trotzdem unlesbar sein. Darueber urteilt
/// nur ein Augenpaar — dafuer gibt es die Musterseite
/// (`SchriftprobeSeiteTests`).
///
/// Das Verfahren ist das von `Textraster.kannKleinbuchstaben` und
/// `Textraster.kannFett`, nur nicht mehr auf einen Sonderfall beschraenkt:
/// rastern, die Pixel vergleichen, und aus **gleichen** Pixeln auf eine
/// verlorene Unterscheidung schliessen.
public enum Schriftprobe {
    /// Der Zeichenvorrat, den die App auf dem Weg „als Pixel" wirklich schickt.
    ///
    /// Zusammengetragen, nicht erfunden: Klein-, Grossbuchstaben und Ziffern
    /// plus die vier Satzzeichen, die auch die Geraetschrift kennt
    /// (`SendenView.unbekannteZeichen`, `erlaubteSatzzeichen = Set("%.-:")`;
    /// Geraetereferenz §1) — und dazu die Umlaute und das scharfe S, wegen
    /// derer diese App ueberhaupt eigene Schriften mitbringt und selbst
    /// rastert.
    ///
    /// Das Leerzeichen fehlt mit Absicht: Es hat keine Tinte
    /// (`Textraster.leerzeichenBreite`) und wuerde jede Pruefung auf
    /// unsichtbare Zeichen ausloesen, ohne dass etwas falsch waere.
    public static let vorrat: [Character] = Array(
        "abcdefghijklmnopqrstuvwxyz"
        + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        + "0123456789"
        + "%.-:"
        + "äöüÄÖÜß")

    /// Die Paare, auf die es ankommt: ein Umlaut und der Buchstabe, von dem er
    /// sich unterscheiden muss. Faellt eines davon zusammen, ist die Groesse
    /// fuer deutschen Text wertlos — auch wenn sonst alles stimmt.
    ///
    /// `ß` steht hier neben `s`, nicht neben `B`: Wer „Grüße" liest und „Grüse"
    /// sieht, hat dasselbe Problem wie bei „Gruesse" statt „Grüße".
    public static let umlautpaare: [Zeichenpaar] = [
        Zeichenpaar("ä", "a"), Zeichenpaar("ö", "o"), Zeichenpaar("ü", "u"),
        Zeichenpaar("Ä", "A"), Zeichenpaar("Ö", "O"), Zeichenpaar("Ü", "U"),
        Zeichenpaar("ß", "s"),
    ]

    /// Oberlaenge (G, ß), Unterlaenge (ß) und ein Umlaut in einem Wort.
    public static let musterwort = "Grüße"

    /// Eine volle Versalienzeile — fuer die Frage, ob Grossbuchstaben samt
    /// Umlautpunkten noch in die sechzehn Zeilen passen.
    public static let versalien = "ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ"

    /// Zwei Zeichen, die miteinander zu tun haben. Eigener Typ statt eines
    /// Tupels, damit `Grund` vergleichbar bleibt.
    public struct Zeichenpaar: Equatable, Hashable, Sendable {
        public let eins: Character
        public let zwei: Character
        public init(_ eins: Character, _ zwei: Character) {
            self.eins = eins; self.zwei = zwei
        }
    }

    /// Ein einzelner Ausschlussgrund. Jeder nennt, was betroffen ist — „ä faellt
    /// mit a zusammen" ist die Auskunft, die zaehlt, nicht „1 Kollision".
    public enum Grund: Equatable, Sendable {
        /// Ein Umlaut ist von seinem Grundbuchstaben nicht zu unterscheiden.
        /// Der schwerste Fall, deshalb eigens und immer zuerst.
        case umlautVerloren([Zeichenpaar])
        /// Zwei sonstige Zeichen des Vorrats rastern zu demselben Bild.
        case zeichenFallenZusammen([Zeichenpaar])
        /// Zeichen ohne einen einzigen gesetzten Pixel — sie fehlen ersatzlos.
        case unsichtbar([Character])
        /// Der Text passt nicht in die sechzehn Zeilen der Anzeige — oben,
        /// unten oder beides geht Tinte verloren. Gezaehlt in Zeilen.
        case zuHoch(text: String, obenFehlt: Int, untenFehlt: Int)
        /// Zwischen zwei benachbarten Zeichen des Musterworts bleibt keine
        /// leere Spalte — sie laufen ineinander.
        case zusammengelaufen([Zeichenpaar])
    }

    /// Alle Gruende, dieses Paar aus Schrift und Groesse auszuschliessen.
    /// Leer heisst „nicht ausgeschlossen" — siehe den Typkommentar.
    ///
    /// `abstand` ist die Zahl leerer Spalten zwischen zwei Zeichen, wie sie die
    /// App einstellt (`Meldungsoptionen.abstand`, Vorgabe 1).
    public static func ausschlussgruende(schrift: String, groesse: Double,
                                         abstand: Int = 1) -> [Grund] {
        // Teuer ist das Rastern, nicht das Vergleichen: je Zeichen ein
        // CGContext (`Textraster.zeichenTinte`). Also jedes Zeichen genau
        // einmal rastern, danach nur noch die fertigen Bilder ansehen.
        var felder: [Character: Pixelfeld] = [:]
        for zeichen in Set(vorrat).union(musterwort) {
            felder[zeichen] = Textraster.rasterPuffer(String(zeichen), schrift: schrift,
                                                      groesse: groesse, fett: false, farbe: tinte)
        }
        let bilder = felder.mapValues(signatur)

        var gruende: [Grund] = []

        // 1a. Die Umlaute zuerst, und getrennt von allem anderen.
        let verloreneUmlaute = umlautpaare.filter { bilder[$0.eins] == bilder[$0.zwei] }
        if !verloreneUmlaute.isEmpty { gruende.append(.umlautVerloren(verloreneUmlaute)) }

        // 2. Unsichtbare Zeichen. Vor den uebrigen Kollisionen ermittelt, denn
        //    unsichtbare Zeichen fallen untereinander natuerlich alle zusammen —
        //    das ist dieselbe Auskunft zweimal.
        let unsichtbare = vorrat.filter { bilder[$0]?.contains("1") == false }.sorted()
        if !unsichtbare.isEmpty { gruende.append(.unsichtbar(unsichtbare)) }

        // 1b. Alle uebrigen Paare mit gleichem Pixelbild. Nach Signatur
        //     gruppiert statt Paar fuer Paar verglichen: n Vergleiche statt n².
        let unsichtbarMenge = Set(unsichtbare)
        var gruppen: [String: [Character]] = [:]
        for zeichen in vorrat where !unsichtbarMenge.contains(zeichen) {
            gruppen[bilder[zeichen]!, default: []].append(zeichen)
        }
        let schonGenannt = Set(verloreneUmlaute)
        var kollisionen: [Zeichenpaar] = []
        for gruppe in gruppen.values where gruppe.count > 1 {
            let sortiert = gruppe.sorted()
            for i in 0..<(sortiert.count - 1) {
                for j in (i + 1)..<sortiert.count {
                    let paar = Zeichenpaar(sortiert[i], sortiert[j])
                    guard !schonGenannt.contains(paar),
                          !schonGenannt.contains(Zeichenpaar(paar.zwei, paar.eins)) else { continue }
                    kollisionen.append(paar)
                }
            }
        }
        if !kollisionen.isEmpty {
            gruende.append(.zeichenFallenZusammen(kollisionen.sorted {
                ($0.eins, $0.zwei) < ($1.eins, $1.zwei)
            }))
        }

        // 3. Hoehe — passt das Musterwort, passt eine Versalienzeile?
        for text in [musterwort, versalien] {
            guard let (oben, unten) = abgeschnitten(text, schrift: schrift, groesse: groesse),
                  oben > 0 || unten > 0 else { continue }
            gruende.append(.zuHoch(text: text, obenFehlt: oben, untenFehlt: unten))
        }

        // 4. Trennspalten im Musterwort.
        let gelaufen = zusammengelaufen(felder: felder, schrift: schrift,
                                        groesse: groesse, abstand: abstand)
        if !gelaufen.isEmpty { gruende.append(.zusammengelaufen(gelaufen)) }
        return gruende
    }

    /// Benachbarte Zeichen des Musterworts, zwischen denen im fertig gesetzten
    /// Wort keine einzige leere Spalte bleibt.
    ///
    /// Ist ein Zeichen des Musterworts unsichtbar, bleibt die Liste leer: Das
    /// steht dann schon als eigener Grund da, und die Spaltenrechnung hier
    /// stimmte ohnehin nicht mehr (`rasterPuffer` gibt einem Wort ohne jede
    /// Tinte trotzdem eine Spalte Breite).
    private static func zusammengelaufen(felder: [Character: Pixelfeld], schrift: String,
                                         groesse: Double, abstand: Int) -> [Zeichenpaar] {
        let zeichen = Array(musterwort)
        guard zeichen.count > 1,
              zeichen.allSatisfy({ felder[$0].map(hatTinte) == true }) else { return [] }

        let puffer = Textraster.rasterPuffer(musterwort, schrift: schrift, groesse: groesse,
                                             fett: false, farbe: tinte, luecke: max(0, abstand))
        // Dieselbe Rechnung, mit der `rasterPuffer` die Ausschnitte aneinander
        // legt: Tintenbreite des Zeichens, dann `abstand` Spalten Luft.
        var ende: [Int] = [], anfang: [Int] = []
        var x = 0
        for (i, z) in zeichen.enumerated() {
            anfang.append(x)
            x += felder[z]!.breite
            ende.append(x)
            if i < zeichen.count - 1 { x += max(0, abstand) }
        }

        var gelaufen: [Zeichenpaar] = []
        for i in 0..<(zeichen.count - 1) {
            let luft = ende[i]..<anfang[i + 1]
            let trennt = luft.contains { spalte in
                (0..<puffer.hoehe).allSatisfy { puffer.farbe(x: spalte, y: $0) == nil }
            }
            if !trennt { gelaufen.append(Zeichenpaar(zeichen[i], zeichen[i + 1])) }
        }
        return gelaufen
    }

    /// Wie viele Zeilen Tinte oben und unten aus dem sechzehn Zeilen hohen
    /// Fenster herausfallen. `nil`, wenn der Text ueberhaupt keine Tinte hat.
    ///
    /// Gemessen wird in einem **dreifach hohen** Feld mit sechzehn Zeilen
    /// Vorlauf: `Textraster.rastern` setzt die Grundlinie auf
    /// `hoehe − y − groesse` von unten, also immer `groesse` Zeilen unter den
    /// oberen Rand des Feldes — mit `y = 16` liegt derselbe Satz sechzehn
    /// Zeilen tiefer, und was sonst ueber Zeile 0 hinausragte, wird sichtbar.
    ///
    /// Warum nicht `Textraster.hoehe`? Weil die Frage damit falsch beantwortet
    /// wuerde. Die optischen Grenzen einer Zeile (`.useOpticalBounds`)
    /// schliessen Ober- und Unterlaenge ein, die die Glyphen gar nicht
    /// ausnutzen: gemessen fuenf bis sechs Zeilen mehr, als wirklich schwarz
    /// wird. Sie meldet fuer Silkscreen in Groesse 16 einundzwanzig Zeilen —
    /// und wuerde damit genau die Groesse verwerfen, die die App bisher als
    /// sauber fuehrt. Hier zaehlen nur gesetzte Pixel.
    private static func abgeschnitten(_ text: String, schrift: String,
                                      groesse: Double) -> (oben: Int, unten: Int)? {
        let fenster = Pixelfeld.hoeheStandard
        // Breit und hoch genug, dass allein das Fenster beschneidet und nicht
        // der Messpuffer: je Zeichen hoechstens `groesse` Spalten Vorschub.
        let breite = Int(groesse.rounded(.up)) * text.count + 2 * fenster
        var feld = Pixelfeld(breite: max(breite, 1), hoehe: 3 * fenster)
        Textraster.rastern(text, schrift: schrift, groesse: groesse, farbe: tinte,
                           x: fenster, y: fenster, feld: &feld)
        guard let zeilen = Textraster.tintenZeilen(feld) else { return nil }
        return (oben: max(0, fenster - zeilen.erste),
                unten: max(0, zeilen.letzte - (2 * fenster - 1)))
    }

    private static func hatTinte(_ feld: Pixelfeld) -> Bool {
        (0..<feld.hoehe).contains { y in (0..<feld.breite).contains { feld.farbe(x: $0, y: y) != nil } }
    }

    /// Das Pixelbild als Zeichenkette: je Zeile eine Folge aus 0 und 1, durch
    /// `|` getrennt. Zwei Zeichen mit gleicher Signatur haben dasselbe Bild —
    /// verschieden breite Bilder koennen dabei nie gleich ausfallen.
    private static func signatur(_ feld: Pixelfeld) -> String {
        var s = ""
        s.reserveCapacity(feld.breite * feld.hoehe + feld.hoehe)
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite { s.append(feld.farbe(x: x, y: y) == nil ? "0" : "1") }
            s.append("|")
        }
        return s
    }

    /// Die Farbe ist fuer die Pruefung gleichgueltig — sie muss nur ueberall
    /// dieselbe sein, sonst verglichen sich Bilder nur ueber ihre Farbe.
    private static let tinte = "#FFFFFF"
}

public extension Schriftprobe.Grund {
    /// Der Grund als Satz, fuer die Musterseite und die Testausgabe.
    ///
    /// **Bewusst ohne `lok(…)`.** Diese Saetze stehen in einem Werkzeug — der
    /// erzeugten Musterseite und der Testtabelle —, nicht in der Oberflaeche
    /// der App. Wer sie eines Tages in einer Ansicht zeigt, muss sie durch
    /// `lok` schicken und die englischen Gegenstuecke nachtragen; bis dahin
    /// waeren es Uebersetzungsschluessel, die nie jemand nachschlaegt.
    var beschreibung: String {
        switch self {
        case .umlautVerloren(let paare):
            return "Umlaut verloren: " + paare.map(Self.paarText).joined(separator: ", ")
        case .zeichenFallenZusammen(let paare):
            return "Zeichen fallen zusammen: " + paare.map(Self.paarText).joined(separator: ", ")
        case .unsichtbar(let zeichen):
            return "unsichtbar: " + zeichen.map { "„\($0)“" }.joined(separator: ", ")
        case .zuHoch(let text, let oben, let unten):
            let wo = [oben > 0 ? "\(oben) Zeile(n) oben" : nil,
                      unten > 0 ? "\(unten) Zeile(n) unten" : nil].compactMap { $0 }
            return "„\(text)“ passt nicht in \(Pixelfeld.hoeheStandard) Zeilen: "
                + wo.joined(separator: " und ") + " fehlen"
        case .zusammengelaufen(let paare):
            return "keine Trennspalte: " + paare.map { "„\($0.eins)\($0.zwei)“" }.joined(separator: ", ")
        }
    }

    private static func paarText(_ paar: Schriftprobe.Zeichenpaar) -> String {
        "„\(paar.eins)“ = „\(paar.zwei)“"
    }
}
