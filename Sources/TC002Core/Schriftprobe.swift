import Foundation

/// Schliesst maschinell aus, ob ein Paar aus Schrift und Groesse fuer die
/// 52×16-Anzeige taugt — und sagt, woran es liegt.
///
/// Die Pruefung sagt nur Nein, nie Ja. Eine leere Liste heisst „nicht
/// ausgeschlossen", nicht „brauchbar": Zwei Zeichen koennen sich um ein
/// einziges Pixel unterscheiden und trotzdem unlesbar sein. Darueber urteilt
/// nur ein Augenpaar — dafuer gibt es die Schriftprobe in der App und die
/// Musterseite `erzeugt/schriftprobe.html`.
///
/// Das Verfahren ist das von `Textraster.kannKleinbuchstaben` und
/// `Textraster.kannFett`, nur nicht mehr auf einen Sonderfall beschraenkt:
/// rastern, die Pixel vergleichen, und aus gleichen Pixeln auf eine
/// verlorene Unterscheidung schliessen.
public enum Schriftprobe {
    /// Gemessen wird, was die Sendeansicht anbietet — alle acht Schriften, die
    /// mitgelieferten wie die des Systems. Die Liste steht in `Schriften`, an
    /// einer einzigen Stelle: Wer Menlo bei 6 px waehlen kann, soll auch sehen
    /// koennen, was das mit den Zeichen macht.
    public static var schriften: [String] { Schriften.auswahl }

    /// Davon die, die auf diesem Geraet wirklich installiert sind.
    ///
    /// Nur sie werden gemessen. Fehlt eine Schrift, rastert CoreText klaglos
    /// mit einer Ersatzschrift — das Ergebnis waere dann nicht falsch, sondern
    /// ueber etwas anderes gemacht als behauptet. Nicht jedes System bringt
    /// jede dieser Schriften mit; iOS etwa kennt weder Geneva noch Andale Mono.
    public static func vorhandeneSchriften() -> [String] {
        schriften.filter(Schriften.vorhanden)
    }

    /// Die Gegenliste: hier nicht installiert, also nicht gemessen. Ansicht und
    /// Musterseite sagen das dazu, statt eine Luecke zu lassen.
    public static func fehlendeSchriften() -> [String] {
        schriften.filter { !Schriften.vorhanden($0) }
    }

    /// Gemessen wird in ganzen Pixeln von 6 bis 16 — derselbe Bereich, aus dem
    /// die Sendeansicht waehlt (`Pixelgroessen.freierBereich`). Welche davon sie
    /// anbietet, entscheidet sie dort; diese Messung entscheidet nichts.
    public static let groessen: [Double] = Array(stride(from: 6.0, through: 16.0, by: 1.0))

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

    /// Alle Zeichen, deren Unterscheidung vom Umlaut abhaengt — die Umlaute
    /// selbst und das scharfe S.
    public static let umlautzeichen: Set<Character> = ["ä", "ö", "ü", "Ä", "Ö", "Ü", "ß"]

    /// Ein Wort mit allem, was die sechzehn Zeilen belasten kann: Oberlaenge
    /// (`F`, `b`), gleich drei Unterlaengen (`g`), ein Umlaut und das scharfe S.
    /// Es dient der Hoehenmessung und dem Gesamteindruck, nicht der
    /// Unterscheidbarkeit — die haengt an den Kollisionsgruppen.
    public static let musterwort = "Fußgängerzone"

    /// Eine volle Versalienzeile — fuer die Frage, ob Grossbuchstaben samt
    /// Umlautpunkten noch in die sechzehn Zeilen passen. `Q` traegt dabei die
    /// einzige Unterlaenge, die ein Grossbuchstabe hat.
    public static let versalien = "ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ"

    /// Jeder Umlaut neben seinem Grundbuchstaben: der entscheidende Fall auf
    /// einen Blick.
    public static let umlautprobe = "a ä o ö u ü s ß"

    /// Hoechstens so viele Kollisionsgruppen werden als Raster gezeigt — in der
    /// App wie auf der Musterseite, damit beide dasselbe zeigen.
    ///
    /// Die Zahl ist zugleich die Grenze zwischen den beiden Lagen (siehe
    /// `lage(_:)`): Bis hierher sieht man jede Gruppe und kann sie
    /// abwaegen; darueber hinaus faellt so viel zusammen, dass keine einzelne
    /// Gruppe mehr den Ausschlag gibt — und eine Wand aus Rastern liest
    /// niemand. Vier, weil das die groesste Zahl ist, die in den gemessenen
    /// Faellen noch vollstaendig gezeigt werden kann: Was darueber liegt,
    /// springt auf zehn und mehr.
    public static let gruppenObergrenze = 4

    /// Wie viel bei dieser Schrift und Groesse zusammenfaellt — die Auskunft,
    /// die entscheidet, ob sich Hinsehen ueberhaupt lohnt. Kein Urteil ueber
    /// die Groesse, sondern ueber die Zahl der Gruppen.
    public enum Lage: Equatable, Sendable {
        /// Kein einziges Zeichenpaar faellt zusammen — es gibt nichts zu
        /// vergleichen.
        case nichtsFaelltZusammen
        /// Wenige Gruppen, alle zu sehen: hier haengt es am Auge.
        case wenigeGruppen
        /// Mehr Gruppen als `gruppenObergrenze` — sie werden gekappt.
        case vieleGruppen
    }

    public static func lage(_ gruende: [Grund]) -> Lage {
        let gruppen = kollisionsgruppen(gruende)
        if gruppen.isEmpty { return .nichtsFaelltZusammen }
        return gruppen.count <= gruppenObergrenze ? .wenigeGruppen : .vieleGruppen
    }

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
        /// Zeichen ohne einen einzigen gesetzten Pixel — sie fehlen ersatzlos.
        case unsichtbar([Character])
        /// Diese Schrift kennt bei dieser Groesse keine eigenen
        /// Kleinbuchstaben. Kein Fehler der Groesse, sondern eine Eigenschaft
        /// der Schrift (dieselbe, die `Textraster.kannKleinbuchstaben`
        /// meldet) — und deshalb ein eigener Grund und keine Kollision:
        /// Sonst erschluegen allein die sechsundzwanzig Paare A=a, B=b, … in
        /// jeder Zeile alles andere.
        case nurGrossbuchstaben
        /// Gruppen von Zeichen, die zu demselben Pixelbild rastern. Jede
        /// Gruppe fuer sich ist eine verlorene Unterscheidung; die groessten
        /// stehen vorn.
        case zeichenFallenZusammen([[Character]])
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
        var gruende: [Grund] = []

        // Kennt die Schrift ueberhaupt Kleinbuchstaben? Wenn nicht, rastern
        // „a" und „A" dieselben Pixel — das ist keine verlorene Unterscheidung
        // dieser Groesse, sondern die Schrift selbst. Die Kleinbuchstaben
        // bleiben dann aussen vor, sonst bestuende die halbe Kollisionsliste
        // aus derselben Auskunft.
        let nurGross = !Textraster.kannKleinbuchstaben(schrift: schrift, groesse: groesse)
        let geprueft = nurGross ? vorrat.filter { !hatEigeneGrossform($0) } : vorrat

        // Teuer ist das Rastern, nicht das Vergleichen: je Zeichen ein
        // CGContext (`Textraster.zeichenTinte`). Also jedes Zeichen genau
        // einmal rastern, danach nur noch die fertigen Bilder ansehen.
        var felder: [Character: Pixelfeld] = [:]
        for zeichen in Set(geprueft).union(musterwort) {
            felder[zeichen] = Textraster.rasterPuffer(String(zeichen), schrift: schrift,
                                                      groesse: groesse, fett: false, farbe: tinte)
        }
        let bilder = felder.mapValues(signatur)

        // 1a. Die Umlaute zuerst, und getrennt von allem anderen.
        let verloreneUmlaute = umlautpaare.filter {
            guard let a = bilder[$0.eins], let b = bilder[$0.zwei] else { return false }
            return a == b
        }
        if !verloreneUmlaute.isEmpty { gruende.append(.umlautVerloren(verloreneUmlaute)) }

        // 2. Unsichtbare Zeichen. Vor den Gruppen ermittelt, denn unsichtbare
        //    Zeichen fallen untereinander natuerlich alle zusammen — das waere
        //    dieselbe Auskunft zweimal.
        let unsichtbare = geprueft.filter { bilder[$0]?.contains("1") == false }.sorted()
        if !unsichtbare.isEmpty { gruende.append(.unsichtbar(unsichtbare)) }

        if nurGross { gruende.append(.nurGrossbuchstaben) }

        // 1b. Alle Zeichen mit gleichem Pixelbild, nach Signatur gruppiert
        //     statt Paar fuer Paar verglichen: n Vergleiche statt n². Die
        //     Umlautpaare stehen hier gegebenenfalls noch einmal — die Gruppe
        //     ist der Befund, `umlautVerloren` seine Deutung.
        let unsichtbarMenge = Set(unsichtbare)
        var gruppen: [String: [Character]] = [:]
        for zeichen in geprueft where !unsichtbarMenge.contains(zeichen) {
            gruppen[bilder[zeichen]!, default: []].append(zeichen)
        }
        // Die groesste Gruppe zuerst: Sie richtet den meisten Schaden an, und
        // wer die Liste kappt, soll oben das Wichtigste sehen.
        let kollisionen = gruppen.values.filter { $0.count > 1 }.map { $0.sorted() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.lexicographicallyPrecedes($1) }
        if !kollisionen.isEmpty { gruende.append(.zeichenFallenZusammen(kollisionen)) }

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

    // MARK: - Ein fertiger Block

    /// Eine Kollisionsgruppe samt ihrem Bild — die Zeichen nebeneinander
    /// gesetzt, wie die Uhr sie zeigte.
    public struct Gruppenbild: Identifiable, Equatable, Sendable {
        public let id: Int
        /// Die Gruppe als Text, `H=K=X`.
        public let text: String
        public let bild: Pixelfeld
    }

    /// Alles, was eine Darstellung ueber ein Paar aus Schrift und Groesse
    /// braucht — fertig gerastert.
    ///
    /// Beide Fassungen bauen darauf: die Schriftprobe in der App und die
    /// Musterseite `erzeugt/schriftprobe.html`. Sonst zeigten sie frueher oder
    /// spaeter Verschiedenes und niemand wuesste, welche stimmt.
    public struct Messung: Identifiable, Equatable, Sendable {
        public var id: String { "\(schrift)|\(groesse)" }
        public let schrift: String
        public let groesse: Double
        public let gruende: [Grund]
        public let lage: Lage
        /// Hoechstens `gruppenObergrenze` Gruppen, die groesste zuerst.
        public let gruppen: [Gruppenbild]
        /// Die abgeschnittenen Gruppen, nur noch als Text — eine Wand aus
        /// Rastern liest niemand.
        public let weitereGruppen: [String]
        /// Die Umlautzeile, aber nur, wo ein Umlaut wirklich betroffen ist.
        /// Sonst waere sie Fuellung.
        public let umlautbild: Pixelfeld?
        /// Das Musterwort — fuer den Gesamteindruck, nicht fuer die
        /// Unterscheidbarkeit.
        public let musterbild: Pixelfeld
    }

    public static func messen(schrift: String, groesse: Double, abstand: Int = 1) -> Messung {
        let gruende = ausschlussgruende(schrift: schrift, groesse: groesse, abstand: abstand)
        let alle = kollisionsgruppen(gruende)
        let gezeigt = alle.prefix(gruppenObergrenze)
        func bild(_ text: String) -> Pixelfeld {
            Textraster.rasterPuffer(text, schrift: schrift, groesse: groesse,
                                    fett: false, farbe: tinte, luecke: max(0, abstand))
        }
        return Messung(
            schrift: schrift, groesse: groesse, gruende: gruende, lage: lage(gruende),
            gruppen: gezeigt.enumerated().map { i, gruppe in
                Gruppenbild(id: i, text: Grund.gruppentext(gruppe), bild: bild(String(gruppe)))
            },
            weitereGruppen: alle.dropFirst(gruppenObergrenze).map(Grund.gruppentext),
            umlautbild: umlauteBetroffen(gruende) ? bild(umlautprobe) : nil,
            musterbild: bild(musterwort))
    }

    /// Die ganze Tabelle: jede hier vorhandene Schrift in jeder gemessenen
    /// Groesse.
    ///
    /// Gemerkt, weil sie teuer und deterministisch ist: acht Schriften mal elf
    /// Groessen mal dreiundsiebzig Zeichen kosten in der ausgelieferten Fassung
    /// rund sechs Zehntelsekunden (mit den drei mitgelieferten Schriften allein
    /// zweieinhalb Zehntel, ohne Optimierung das Vier- bis Fuenffache). Das ist
    /// zu lang fuer einen Fensteraufbau und waere beim zweiten Oeffnen genau
    /// dieselbe Antwort.
    public static func alleMessungen(abstand: Int = 1) -> [Messung] {
        tabellensperre.lock(); defer { tabellensperre.unlock() }
        if let da = tabelle[abstand] { return da }
        let ergebnis = vorhandeneSchriften().flatMap { schrift in
            groessen.map { messen(schrift: schrift, groesse: $0, abstand: abstand) }
        }
        tabelle[abstand] = ergebnis
        return ergebnis
    }

    private static let tabellensperre = NSLock()
    private static var tabelle: [Int: [Messung]] = [:]

    // MARK: - Auskunft ueber ein Ergebnis

    /// Die Kollisionsgruppen aus einem Ergebnis, oder leer. Beide Darstellungen
    /// — die Schriftprobe in der App und die Musterseite — zeigen genau diese
    /// Gruppen als Raster; dort faellt die Entscheidung, ob man sie noch
    /// auseinanderhaelt.
    public static func kollisionsgruppen(_ gruende: [Grund]) -> [[Character]] {
        for grund in gruende {
            if case .zeichenFallenZusammen(let gruppen) = grund { return gruppen }
        }
        return []
    }

    /// Hat es einen Umlaut erwischt — als verlorenen Umlaut oder irgendwo in
    /// einer Kollisionsgruppe? Nur dann lohnt es, die Umlautzeile zu zeigen;
    /// sonst ist sie Fuellung.
    public static func umlauteBetroffen(_ gruende: [Grund]) -> Bool {
        for grund in gruende {
            if case .umlautVerloren = grund { return true }
        }
        return kollisionsgruppen(gruende).contains { gruppe in
            gruppe.contains { umlautzeichen.contains($0) }
        }
    }

    // MARK: - Messung

    /// Hat dieses Zeichen eine eigene Grossform, faellt also bei einer Schrift
    /// ohne Kleinbuchstaben mit ihr zusammen? `ß` nicht: Es wird zu „SS" und
    /// ist damit kein Fall von Gross gegen Klein, sondern ein Zeichen fuer sich.
    private static func hatEigeneGrossform(_ zeichen: Character) -> Bool {
        zeichen.isLowercase && String(zeichen).uppercased().count == 1
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
    /// Gemessen wird in einem dreifach hohen Feld mit sechzehn Zeilen
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
    /// Der Grund als Satz — fuer die Schriftprobe in der App, die Musterseite
    /// und die Testtabelle.
    ///
    /// Uebersetzt, denn dieser Satz steht in der Oberflaeche: `lok`/`lokf`, weil
    /// er als gewoehnliches `String` weitergereicht wird und deshalb nie durch
    /// SwiftUIs eigene Nachschlage geht. Die Zeichen selbst bleiben, wie sie
    /// sind — an „0=8=9" ist nichts zu uebersetzen.
    var beschreibung: String {
        switch self {
        case .umlautVerloren(let paare):
            return lokf("Umlaut verloren: %@", paare.map { "\($0.eins)=\($0.zwei)" }
                .joined(separator: ", "))
        case .unsichtbar(let zeichen):
            return lokf("unsichtbar: %@", zeichen.map(String.init).joined(separator: " "))
        case .nurGrossbuchstaben:
            return lok("Diese Schrift kennt keine eigenen Kleinbuchstaben — sie rastern wie Großbuchstaben und bleiben hier außer Betracht.")
        case .zeichenFallenZusammen(let gruppen):
            return lokf("Zeichen fallen zusammen: %@", gruppen.map(Self.gruppentext)
                .joined(separator: ", "))
        case .zuHoch(let text, let oben, let unten):
            if oben > 0, unten > 0 {
                return lokf("„%@“ passt nicht in die Anzeige: oben abgeschnitten um %@, unten um %@.",
                            text, Self.zeilen(oben), Self.zeilen(unten))
            }
            if oben > 0 {
                return lokf("„%@“ passt nicht in die Anzeige: oben abgeschnitten um %@.",
                            text, Self.zeilen(oben))
            }
            return lokf("„%@“ passt nicht in die Anzeige: unten abgeschnitten um %@.",
                        text, Self.zeilen(unten))
        case .zusammengelaufen(let paare):
            return lokf("keine Trennspalte zwischen: %@", paare.map { "\($0.eins)\($0.zwei)" }
                .joined(separator: ", "))
        }
    }

    /// „1 Zeile" oder „3 Zeilen" — eigene Schluessel statt eines Zaehlworts
    /// hinter `%d`, sonst stuende dort „1 Zeilen".
    private static func zeilen(_ anzahl: Int) -> String {
        anzahl == 1 ? lok("1 Zeile") : lokf("%d Zeilen", anzahl)
    }

    /// Eine Kollisionsgruppe als Text: `0=8=9=B`. Kein uebersetzbarer Satz,
    /// sondern die Zeichen selbst.
    static func gruppentext(_ gruppe: [Character]) -> String {
        gruppe.map(String.init).joined(separator: "=")
    }
}
