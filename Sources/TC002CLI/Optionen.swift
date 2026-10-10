import Foundation
import TC002Core

/// Was auf der Kommandozeile stand, geprueft und in brauchbare Werte gewandelt.
///
/// Eigener Typ und nicht in `main.swift`, damit sich das Zerlegen pruefen laesst,
/// ohne zu senden — der Teil, in dem die Fehler stecken, ist das Zerlegen.
struct Optionen {
    enum Befehl: Equatable {
        case senden(text: String)
        /// Eine einmalige Meldung über der Schleife (`cmd/notify`), keine Anzeige.
        case nachricht(text: String)
        /// Die sichtbare Benachrichtigung wegnehmen, mit Namen die benannte.
        case zurueckziehen(name: String?)
        case loeschen(anzeige: String)
        case umschalten(anzeige: String)
        case uhren
        case icons
        /// Ein fertiges Bild aus dem Bestand schicken — der Name, unter dem es
        /// im Editor gesichert wurde.
        case bild(name: String)
        /// Den Bilderbestand auflisten, wie `icons` die Icons.
        case bilder
        /// Effekte, Overlays und Paletten, die die Uhr in `capabilities` nennt.
        case effekte
        /// Ein Layout aus einer JSON-Datei senden (`docs/awtrix-ng-protokoll.md` §9).
        case layout(datei: String)
        /// Das Display der Uhr lesen und als Text ausgeben.
        case bildschirm
        // Fernsteuerung und Zustand (docs/awtrix-ng-protokoll.md §3.2, §4.2, §10, §11.1).
        /// Das Panel ein- oder ausschalten.
        case display(an: Bool)
        /// Die Helligkeit des Panels, 0–255.
        case helligkeit(Int)
        case moodlight(Moodlight)
        case moodlightAus
        case indikator(Indikator)
        case indikatorAus(nummer: Int)
        /// Eine Anzeige weiter oder zurück.
        case weiter, zurueck
        /// Die Uhr neu starten.
        case neustart
        /// Den Zustand der Uhr ausgeben.
        case zustand
        /// Die Einstellungen der Uhr ausgeben.
        case einstellungen
        case einstellungenSetzen(schluessel: String, wert: String)
        // Klang (docs/awtrix-ng-protokoll.md §3.2.1).
        case tonSpielen(Klang)
        /// Eine Gruppe anhalten, ohne Angabe alles.
        case tonStopp(Tongruppe?)
        case tonZustand
        case tonMelodien
        case tonMelodie(name: String, rtttl: String)
        case tonMelodieLoeschen(name: String)
        case tonSender
        case tonMP3Liste
        /// `name` ist `nil`, wenn der Vorschlag gelten soll.
        case tonMP3Hochladen(datei: String, name: String?, ersetzen: Bool)
        case tonMP3Loeschen(name: String)
        /// Der TLS-Stand für MQTT und die CA der Uhr (nie TLS selbst).
        case tls
        case tlsCA(datei: String)
        case tlsCAEntfernen
        case hilfe
        case fassung
    }

    var befehl: Befehl = .hilfe
    var ziele: [String] = []
    var anzeigename = "cli"
    /// `--name` stand da. Bei „senden" gilt sonst die Vorgabe „cli"; bei einer
    /// Benachrichtigung bedeutet kein Name: nur die sichtbare ist zurückziehbar.
    var nameAngegeben = false
    var farbe = "#00FF66"
    var iconNummer: String?
    var schrift = "Silkscreen"
    var groesse: Double = 8
    var fett = false
    var grossbuchstaben = false
    var waagrecht: SendenHAusrichtung = .links
    var senkrecht: SendenVAusrichtung = .mittig
    var rand = 1
    var abstand = 1
    var dauer: Int?
    var tempo: Lauftempo = .mittel
    var trocken = false
    /// Nur für Benachrichtigungen.
    var halten = false
    /// `--ersetzen` wurde angegeben. Für „ton mp3 hochladen“ heißt es „überschreiben“;
    /// bei einer Nachricht ist es die Vorgabe und ändert nichts (siehe `einreihen`).
    var ersetzen = false
    /// Nur für Benachrichtigungen: hinten anstellen statt die sichtbare zu ersetzen.
    var einreihen = false
    var aufwecken = true
    var wiederholungen: Int? = 2
    /// Die erste Option, die nur eine Nachricht kennt — für die Meldung, wenn
    /// sie bei „senden“ steht.
    var nachrichtenoption: String?
    /// Nur für „senden": nach dieser Zeit verfällt die Anzeige von selbst.
    var lebensdauer: Int?
    var ablauf: Lebensablauf?
    /// `--behalten`: die Anzeige verfällt nicht, sie bleibt bis zum Löschen.
    var behalten = false
    /// Hintergrund, Effekt, Overlay und Palette (§5.5) — für „senden“ und „nachricht“.
    var darstellung = Darstellung()
    /// Diagramm und Fortschritt; nur gültig, wenn eine der Optionen dazu stand.
    var grafik = Grafikinhalt()
    var grafikGesetzt = false
    /// Die erste Option, die nur „senden“ und „nachricht“ kennen — für die
    /// Meldung, wenn sie bei einem anderen Befehl steht.
    var darstellungsoption: String?
    /// `--farbe` stand da (die Vorgabe `#00FF66` gehört dem Text, nicht dem Moodlight).
    var farbeAngegeben = false
    var kelvin: Int?
    var steuerhelligkeit: Int?
    var blinken: Int?
    var blenden: Int?
    /// Die erste Option nur für Moodlight bzw. Anzeiger — für die Meldung, wenn sie
    /// bei einem anderen Befehl steht.
    var moodlightoption: String?
    var indikatoroption: String?
    /// `ton` stand als Befehlswort da; das Unterwort steht unter den freien Wörtern.
    var tonwort = false
    /// Die Klangquellen aus `--datei`, `--rtttl`, `--lied`, `--sprache`, `--sender`.
    var klangquellen: [Klang.Quelle] = []
    var wiederholen = false
    var melodieLoeschen = false
    /// Die erste Option, die nur ein Klang kennt — für die Meldung bei einem anderen Befehl.
    var klangoption: String?

    enum Fehler: Error, LocalizedError {
        case unbekannteOption(String)
        case fehlenderWert(String)
        case keineZahl(option: String, wert: String)
        case keineFarbe(String)
        case fehlenderText
        case fehlenderBildname
        case fehlendeLayoutdatei
        /// Eine Option, die der gewählte Befehl nicht kennt — sie würde sonst
        /// still nichts bewirken.
        case optionGiltNurFuer(option: String, befehl: String)
        case keinAblauf(String)
        case behaltenMitLebensdauer
        case nichtPositiv(option: String, wert: String)
        /// Werte, die als Liste ganzer Zahlen gemeint waren („1,2,3“).
        case keineListe(option: String, wert: String)
        /// Eine Palette aus Farben und Stützstellen gemischt.
        case paletteGemischt(String)
        /// Eine Farbe, die „palette“ oder #RRGGBB sein sollte.
        case keineGrafikfarbe(option: String, wert: String)
        /// Text und Grafik zugleich.
        case grafikMitText
        /// Ein Befehl, dem ein Wort fehlt (`display` ohne `an`/`aus`).
        case unvollstaendig(befehl: String, erwartet: String)
        /// Ein Wort, das der Befehl nicht kennt.
        case ueberzaehligesWort(befehl: String, wort: String)

        var errorDescription: String? {
            switch self {
            case .unbekannteOption(let o):
                return lokf("Unbekannte Option „%@“. „mqtttc002 hilfe“ zeigt alle.", o)
            case .fehlenderWert(let o):
                return lokf("Zu „%@“ fehlt der Wert.", o)
            case .keineZahl(let o, let w):
                return lokf("„%@“ erwartet eine Zahl, bekam aber „%@“.", o, w)
            case .keineFarbe(let w):
                return lokf("„%@“ ist keine Farbe der Form #RRGGBB.", w)
            case .fehlenderText:
                return lok("Was soll gesendet werden? Text als letztes Wort angeben.")
            case .fehlenderBildname:
                return lok("Welches Bild? Den Namen angeben — „mqtttc002 bilder“ zeigt alle.")
            case .fehlendeLayoutdatei:
                return lok("Welche Datei? Den Pfad einer Layoutdatei (JSON) angeben.")
            case .optionGiltNurFuer(let o, let b):
                return lokf("„%@“ gilt nur für „%@“.", o, b)
            case .keinAblauf(let w):
                return lokf("„%@“ ist kein Ablauf. Möglich: entfernen, markieren (remove, mark).", w)
            case .behaltenMitLebensdauer:
                return lok("„--behalten“ lässt die Anzeige stehen und verträgt sich nicht mit „--lebensdauer“ oder „--ablauf“.")
            case .nichtPositiv(let o, let w):
                return lokf("„%@“ erwartet eine Zahl größer als 0, bekam aber „%@“.", o, w)
            case .keineListe(let o, let w):
                return lokf("„%@“ erwartet ganze Zahlen mit Komma dazwischen (1,2,3), bekam aber „%@“.", o, w)
            case .paletteGemischt(let w):
                return lokf("Die Palette „%@“ mischt Farben mit und ohne Lage. Entweder alle „#RRGGBB“ oder alle „#RRGGBB@Lage“.", w)
            case .keineGrafikfarbe(let o, let w):
                return lokf("„%@“ erwartet #RRGGBB oder „palette“, bekam aber „%@“.", o, w)
            case .grafikMitText:
                return lok("Ein Diagramm oder Fortschritt hat keinen Text. Entweder Text angeben oder --balken, --linie, --fortschritt.")
            case .unvollstaendig(let b, let e):
                return lokf("„%@“ erwartet %@.", b, e)
            case .ueberzaehligesWort(let b, let w):
                return lokf("„%@“ kennt das Wort „%@“ nicht.", b, w)
            }
        }
    }

    /// Zerlegt die Argumente ohne das Programm selbst (also `dropFirst`).
    static func zerlegt(_ rohe: [String]) throws -> Optionen {
        // Zuerst heraus, was Foundation fuer sich beansprucht — sonst stuende
        // `-AppleLanguages` an der Stelle des Befehlsworts, und aus
        // `mqtttc002 -AppleLanguages "(en)" uhren` wuerde eine Sendung mit dem
        // Text „uhren".
        let argumente = ohneEinstellungsargumente(rohe)
        var o = Optionen()
        guard let erstes = argumente.first else { return o }

        var rest = Array(argumente.dropFirst())
        switch erstes {
        case "senden", "send":
            o.befehl = .senden(text: "")
        case "nachricht", "message":
            o.befehl = .nachricht(text: "")
        case "zurueckziehen", "dismiss":
            o.befehl = .zurueckziehen(name: nil)
        case "loeschen", "delete":
            o.befehl = .loeschen(anzeige: "")
        case "umschalten", "switch":
            o.befehl = .umschalten(anzeige: "")
        case "uhren", "clocks":
            o.befehl = .uhren
        case "icons":
            o.befehl = .icons
        case "bild", "image":
            o.befehl = .bild(name: "")
        case "bilder", "images":
            o.befehl = .bilder
        case "effekte", "effects":
            o.befehl = .effekte
        case "layout":
            o.befehl = .layout(datei: "")
        case "bildschirm", "screen":
            o.befehl = .bildschirm
        case "display":
            o.befehl = .display(an: true)
        case "helligkeit", "brightness":
            o.befehl = .helligkeit(0)
        case "moodlight":
            o.befehl = .moodlightAus
        case "indikator", "indicator":
            o.befehl = .indikatorAus(nummer: 0)
        case "weiter", "next":
            o.befehl = .weiter
        case "zurueck", "previous":
            o.befehl = .zurueck
        case "neustart", "reboot":
            o.befehl = .neustart
        case "zustand", "state":
            o.befehl = .zustand
        case "einstellungen", "settings":
            o.befehl = .einstellungen
        case "tls":
            o.befehl = .tls
        case "ton", "sound":
            o.befehl = .tonZustand
            o.tonwort = true
        case "hilfe", "help", "--help", "-h":
            return Optionen(befehl: .hilfe)
        case "fassung", "version", "--version":
            return Optionen(befehl: .fassung)
        default:
            // Ohne Befehlswort ist alles Text: `mqtttc002 "Hallo"` soll gehen.
            o.befehl = .senden(text: "")
            rest = argumente
        }

        // `ton --help` und `ton hilfe` zeigen die Hilfe, in der der Abschnitt KLANG steht.
        if o.tonwort, rest.contains(where: { ["--help", "-h", "hilfe", "help"].contains($0) }) {
            return Optionen(befehl: .hilfe)
        }

        var freie: [String] = []
        var i = 0
        while i < rest.count {
            let arg = rest[i]
            guard arg.hasPrefix("--") else { freie.append(arg); i += 1; continue }

            /// Holt den Wert hinter einer Option und schiebt den Zeiger weiter.
            func wert() throws -> String {
                guard i + 1 < rest.count else { throw Fehler.fehlenderWert(arg) }
                i += 1
                return rest[i]
            }
            func zahl() throws -> Int {
                let w = try wert()
                guard let z = Int(w) else { throw Fehler.keineZahl(option: arg, wert: w) }
                return z
            }

            func kommazahl() throws -> Double {
                let w = try wert()
                guard let z = Double(w.replacingOccurrences(of: ",", with: ".")) else {
                    throw Fehler.keineZahl(option: arg, wert: w)
                }
                return z
            }
            func farbe() throws -> String {
                let w = try wert()
                guard Self.istFarbe(w) else { throw Fehler.keineFarbe(w) }
                return w
            }
            func werte() throws -> [Int] {
                let w = try wert()
                let teile = w.split(separator: ",", omittingEmptySubsequences: false)
                let zahlen = teile.compactMap { Int($0) }
                guard zahlen.count == teile.count, !zahlen.isEmpty else {
                    throw Fehler.keineListe(option: arg, wert: w)
                }
                return zahlen
            }
            func grafikfarbe() throws -> Grafikfarbe {
                let w = try wert()
                if w == "palette" { return .palette }
                guard Self.istFarbe(w) else { throw Fehler.keineGrafikfarbe(option: arg, wert: w) }
                return .farbe(w)
            }
            /// Merkt die erste Option, die nur „senden“ und „nachricht“ kennen.
            func darstellungsoptionMerken() { o.darstellungsoption = o.darstellungsoption ?? arg }
            func grafikMerken() { o.grafikGesetzt = true; darstellungsoptionMerken() }

            switch arg {
            case "--hintergrund", "--background": o.darstellung.hintergrundfarbe = try farbe(); darstellungsoptionMerken()
            case "--effekt", "--effect":          o.darstellung.effekt = try wert(); darstellungsoptionMerken()
            case "--effekt-tempo", "--effect-speed": o.darstellung.effektTempo = try kommazahl(); darstellungsoptionMerken()
            case "--overlay":                     o.darstellung.overlay = try wert(); darstellungsoptionMerken()
            case "--palette":
                o.darstellung.palette = try Self.palette(try wert())
                darstellungsoptionMerken()
            case "--palette-hart", "--palette-stepped": o.darstellung.paletteUeberblenden = false; darstellungsoptionMerken()
            case "--palette-spanne", "--palette-span": o.darstellung.paletteSpanne = try zahl(); darstellungsoptionMerken()
            case "--palette-tempo", "--palette-speed": o.darstellung.paletteTempo = try kommazahl(); darstellungsoptionMerken()
            case "--text-palette":                o.darstellung.textfarbeAusPalette = true; darstellungsoptionMerken()
            case "--balken", "--bars":            o.grafik.diagramm = .balken(try werte()); grafikMerken()
            case "--linie", "--line":             o.grafik.diagramm = .linie(try werte()); grafikMerken()
            case "--feste-skala", "--fixed-scale": o.grafik.diagrammSkalieren = false; grafikMerken()
            case "--diagrammfarbe", "--chart-color": o.grafik.diagrammfarbe = try grafikfarbe(); grafikMerken()
            case "--fortschritt", "--progress":   o.grafik.fortschritt = try zahl(); grafikMerken()
            case "--fortschrittsfarbe", "--progress-color": o.grafik.fortschrittsfarbe = try grafikfarbe(); grafikMerken()
            case "--fortschrittsgrund", "--progress-track": o.grafik.fortschrittsgrund = try farbe(); grafikMerken()
            case "--kelvin":              o.kelvin = try zahl(); o.moodlightoption = o.moodlightoption ?? arg
            case "--helligkeit", "--brightness": o.steuerhelligkeit = try zahl(); o.moodlightoption = o.moodlightoption ?? arg
            case "--blinken", "--blink":  o.blinken = try zahl(); o.indikatoroption = o.indikatoroption ?? arg
            case "--blenden", "--fade":   o.blenden = try zahl(); o.indikatoroption = o.indikatoroption ?? arg
            case "--datei", "--file", "--klang", "--sound":
                o.klangquellen.append(.datei(try wert())); o.klangoption = o.klangoption ?? arg
            case "--rtttl":               o.klangquellen.append(.rtttl(try wert())); o.klangoption = o.klangoption ?? arg
            case "--lied", "--song":      o.klangquellen.append(.lied(try wert())); o.klangoption = o.klangoption ?? arg
            case "--sprache", "--speech": o.klangquellen.append(.sprache(try wert())); o.klangoption = o.klangoption ?? arg
            case "--sender", "--station":
                // Nur Ziffern sind eine Listenposition (ab 0), alles andere ein Name oder eine Adresse.
                let w = try wert()
                if !w.isEmpty, w.allSatisfy(\.isASCII), w.allSatisfy(\.isNumber), let n = Int(w) {
                    o.klangquellen.append(.senderPosition(n))
                } else {
                    o.klangquellen.append(.sender(w))
                }
                o.klangoption = o.klangoption ?? arg
            case "--wiederholen", "--loop": o.wiederholen = true; o.klangoption = o.klangoption ?? arg
            case "--loeschen", "--delete":  o.melodieLoeschen = true; o.klangoption = o.klangoption ?? arg
            case "--an", "--to":          o.ziele.append(try wert())
            case "--name":                o.anzeigename = try wert(); o.nameAngegeben = true
            case "--farbe", "--color":
                let w = try wert()
                guard Self.istFarbe(w) else { throw Fehler.keineFarbe(w) }
                o.farbe = w
                o.farbeAngegeben = true
            case "--icon":                o.iconNummer = try wert()
            case "--schrift", "--font":   o.schrift = try wert()
            case "--groesse", "--size":   o.groesse = Double(try zahl())
            case "--fett", "--bold":      o.fett = true
            case "--gross", "--upper":    o.grossbuchstaben = true
            case "--rand", "--margin":    o.rand = try zahl()
            case "--abstand", "--gap":    o.abstand = try zahl()
            case "--dauer", "--duration": o.dauer = try zahl()
            case "--trocken", "--dry-run": o.trocken = true
            // `--nicht-halten` und `--ersetzen` sind die frühere Schreibweise der heutigen
            // Vorgabe und bleiben als Wiederholung der Vorgabe gültig; die zuletzt
            // genannte Angabe gewinnt.
            case "--halten", "--hold":              o.halten = true; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--nicht-halten", "--no-hold":     o.halten = false; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--einreihen", "--queue":          o.einreihen = true; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--ersetzen", "--replace":         o.ersetzen = true; o.einreihen = false; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--nicht-wecken", "--no-wakeup":   o.aufwecken = false; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--wiederholungen", "--repeat":
                let w = try wert()
                guard let z = Int(w), z > 0 else { throw Fehler.nichtPositiv(option: arg, wert: w) }
                o.wiederholungen = z
                o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--lebensdauer", "--lifetime":
                let w = try wert()
                guard let z = Int(w) else { throw Fehler.keineZahl(option: arg, wert: w) }
                guard z > 0 else { throw Fehler.nichtPositiv(option: arg, wert: w) }
                o.lebensdauer = z
            case "--behalten", "--keep":  o.behalten = true
            case "--ablauf", "--expiry":
                let w = try wert()
                switch w {
                case "entfernen", "remove": o.ablauf = .entfernen
                case "markieren", "mark":   o.ablauf = .markieren
                default: throw Fehler.keinAblauf(w)
                }
            case "--tempo", "--speed":
                let w = try wert()
                guard let t = Lauftempo(rawValue: w) else {
                    throw Fehler.unbekannteOption("\(arg) \(w)")
                }
                o.tempo = t
            case "--oben", "--top":       o.senkrecht = .oben
            case "--mitte", "--middle":   o.senkrecht = .mittig
            case "--unten", "--bottom":   o.senkrecht = .unten
            case "--links", "--left":     o.waagrecht = .links
            case "--zentriert", "--center": o.waagrecht = .mittig
            case "--rechts", "--right":   o.waagrecht = .rechts
            default:
                throw Fehler.unbekannteOption(arg)
            }
            i += 1
        }

        let freierText = freie.joined(separator: " ")
        switch o.befehl {
        case .senden, .nachricht:
            if o.grafikGesetzt {
                guard freierText.isEmpty else { throw Fehler.grafikMitText }
                try o.grafik.pruefen(palette: o.darstellung.palette)
            }
            try o.darstellung.pruefen()
        default:
            if let option = o.darstellungsoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "senden") }
        }
        if o.behalten, o.lebensdauer != nil || o.ablauf != nil { throw Fehler.behaltenMitLebensdauer }
        try o.steuerbefehlPruefen(freie)
        try o.tonbefehlPruefen(freie)
        switch o.befehl {
        case .senden:
            guard !freierText.isEmpty || o.grafikGesetzt else { throw Fehler.fehlenderText }
            try o.nurFuerNachrichtenPruefen()
            o.befehl = .senden(text: o.grossbuchstaben ? freierText.uppercased() : freierText)
        case .nachricht:
            guard !freierText.isEmpty || o.grafikGesetzt else { throw Fehler.fehlenderText }
            // Eine Benachrichtigung ignoriert die Lebensdauer (§5.4); sie
            // wegzulassen, ohne es zu sagen, wäre eine stille Zusage.
            if let option = o.lebensdaueroption { throw Fehler.optionGiltNurFuer(option: option, befehl: "senden") }
            o.befehl = .nachricht(text: o.grossbuchstaben ? freierText.uppercased() : freierText)
        case .zurueckziehen:
            // Der Name steht als Wort hinter dem Befehl oder hinter `--name`;
            // fehlt beides, ist die sichtbare gemeint.
            o.befehl = .zurueckziehen(name: !freierText.isEmpty ? freierText : (o.nameAngegeben ? o.anzeigename : nil))
        case .loeschen:
            guard !freierText.isEmpty else { throw Fehler.fehlenderText }
            o.befehl = .loeschen(anzeige: freierText)
        case .umschalten:
            guard !freierText.isEmpty else { throw Fehler.fehlenderText }
            o.befehl = .umschalten(anzeige: freierText)
        case .bild:
            guard !freierText.isEmpty else { throw Fehler.fehlenderBildname }
            o.befehl = .bild(name: freierText)
        case .layout:
            guard !freierText.isEmpty else { throw Fehler.fehlendeLayoutdatei }
            try o.nurFuerNachrichtenPruefen()
            o.befehl = .layout(datei: freierText)
        default:
            break
        }
        return o
    }

    /// Der Klang einer `nachricht` bzw. von `ton spielen`: genau eine Quelle, geprüft vom Kern.
    var klang: [Klang] {
        klangquellen.first.map { [Klang($0, wiederholen: wiederholen)] } ?? []
    }

    /// `ton …` und die Klangoptionen an `nachricht`; die Grenzen prüft der Kern
    /// (`Klang`, `Klangbau`), damit dieselben gelten wie in der App.
    private mutating func tonbefehlPruefen(_ freie: [String]) throws {
        func quelle() throws -> Klang {
            guard !klangquellen.isEmpty else { throw KlangFehler.keineQuelle }
            guard klangquellen.count == 1 else { throw KlangFehler.mehrereQuellen }
            return Klang(klangquellen[0], wiederholen: wiederholen)
        }
        guard tonwort else {
            if case .nachricht = befehl {
                if wiederholen, klangquellen.isEmpty {
                    throw Fehler.unvollstaendig(befehl: "--wiederholen", erwartet: "--klang / --rtttl / --sprache")
                }
                if melodieLoeschen { throw Fehler.optionGiltNurFuer(option: "--loeschen", befehl: "ton melodie") }
                if !klangquellen.isEmpty { try quelle().pruefen(inBenachrichtigung: true) }
            } else if let option = klangoption {
                throw Fehler.optionGiltNurFuer(option: option, befehl: "nachricht")
            }
            return
        }
        guard let wort = freie.first?.lowercased() else {
            throw Fehler.unvollstaendig(befehl: "ton", erwartet: "spielen / stopp / zustand / melodien / melodie / mp3 / sender")
        }
        let rest = Array(freie.dropFirst())
        func hoechstens(_ n: Int, _ name: String) throws {
            if rest.count > n { throw Fehler.ueberzaehligesWort(befehl: name, wort: rest[n]) }
        }
        func ohneOptionen(_ name: String) throws {
            if let option = klangoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "ton spielen") }
            try hoechstens(0, name)
        }
        switch wort {
        case "spielen", "play":
            try hoechstens(0, "ton spielen")
            if melodieLoeschen { throw Fehler.optionGiltNurFuer(option: "--loeschen", befehl: "ton melodie") }
            let k = try quelle()
            try k.pruefen()
            befehl = .tonSpielen(k)
        case "stopp", "stop":
            if let option = klangoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "ton spielen") }
            try hoechstens(1, "ton stopp")
            var gruppe: Tongruppe?
            if let w = rest.first {
                guard let g = Tongruppe(wort: w) else { throw KlangFehler.ungueltigeGruppe(w) }
                gruppe = g
            }
            befehl = .tonStopp(gruppe)
        case "zustand", "state": try ohneOptionen("ton zustand"); befehl = .tonZustand
        case "melodien", "melodies": try ohneOptionen("ton melodien"); befehl = .tonMelodien
        case "sender", "stations": try ohneOptionen("ton sender"); befehl = .tonSender
        case "mp3":
            if let option = klangoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "ton spielen") }
            let unter = rest.first?.lowercased()
            let ersetzenOption = ersetzen ? "--ersetzen" : nil
            switch unter {
            case nil:
                try hoechstens(0, "ton mp3")
                if nameAngegeben { throw Fehler.optionGiltNurFuer(option: "--name", befehl: "ton mp3 hochladen") }
                if let option = ersetzenOption { throw Fehler.optionGiltNurFuer(option: option, befehl: "ton mp3 hochladen") }
                befehl = .tonMP3Liste
            case "hochladen", "upload":
                guard rest.count >= 2 else { throw Fehler.unvollstaendig(befehl: "ton mp3 hochladen", erwartet: "<Datei> [--name <Name>] [--ersetzen]") }
                try hoechstens(2, "ton mp3 hochladen")
                if nameAngegeben, !Klangname.gueltig(anzeigename) { throw KlangFehler.ungueltigerKlangname(anzeigename) }
                befehl = .tonMP3Hochladen(datei: rest[1], name: nameAngegeben ? anzeigename : nil, ersetzen: ersetzen)
            case "loeschen", "delete":
                guard rest.count >= 2 else { throw Fehler.unvollstaendig(befehl: "ton mp3 loeschen", erwartet: "<Name>") }
                try hoechstens(2, "ton mp3 loeschen")
                if nameAngegeben { throw Fehler.optionGiltNurFuer(option: "--name", befehl: "ton mp3 hochladen") }
                if let option = ersetzenOption { throw Fehler.optionGiltNurFuer(option: option, befehl: "ton mp3 hochladen") }
                let roh = rest[1]
                let name = roh.lowercased().hasSuffix(".mp3") ? String(roh.dropLast(4)) : roh
                guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
                befehl = .tonMP3Loeschen(name: name)
            default:
                throw Fehler.ueberzaehligesWort(befehl: "ton mp3", wort: rest[0])
            }
        case "melodie", "melody":
            guard let name = rest.first else {
                throw Fehler.unvollstaendig(befehl: "ton melodie", erwartet: "<Name> --rtttl \"…\" / --loeschen")
            }
            try hoechstens(1, "ton melodie")
            if wiederholen { throw Fehler.optionGiltNurFuer(option: "--wiederholen", befehl: "ton spielen") }
            if melodieLoeschen {
                guard klangquellen.isEmpty else {
                    throw Fehler.ueberzaehligesWort(befehl: "ton melodie --loeschen", wort: klangoption ?? "--rtttl")
                }
                try Klangbau.melodienameInOrdnung(name)
                befehl = .tonMelodieLoeschen(name: name)
            } else {
                guard klangquellen.count == 1, case .rtttl(let text) = klangquellen[0] else {
                    throw Fehler.unvollstaendig(befehl: "ton melodie", erwartet: "--rtttl \"…\" / --loeschen")
                }
                _ = try Klangbau.melodie(name: name, rtttl: text)
                befehl = .tonMelodie(name: name, rtttl: text)
            }
        default:
            throw Fehler.ueberzaehligesWort(befehl: "ton", wort: wort)
        }
    }

    /// Die Befehle der Fernsteuerung: ihre Wörter und Optionen prüfen und die
    /// Werte in den Befehl legen. Die Bereiche prüft der Kern (`Moodlight`,
    /// `Indikator`), damit dieselben Grenzen gelten wie in der App.
    private mutating func steuerbefehlPruefen(_ freie: [String]) throws {
        let name: String
        switch befehl {
        case .display: name = "display"
        case .helligkeit: name = "helligkeit"
        case .moodlightAus, .moodlight: name = "moodlight"
        case .indikatorAus, .indikator: name = "indikator"
        case .weiter: name = "weiter"
        case .zurueck: name = "zurueck"
        case .neustart: name = "neustart"
        case .zustand: name = "zustand"
        case .einstellungen: name = "einstellungen"
        case .tls: name = "tls"
        default:
            if let option = moodlightoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "moodlight") }
            if let option = indikatoroption { throw Fehler.optionGiltNurFuer(option: option, befehl: "indikator") }
            return
        }
        let istMoodlight = name == "moodlight", istIndikator = name == "indikator"
        if !istMoodlight, let option = moodlightoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "moodlight") }
        if !istIndikator, let option = indikatoroption { throw Fehler.optionGiltNurFuer(option: option, befehl: "indikator") }
        if !istMoodlight, !istIndikator, farbeAngegeben {
            // `--farbe` gehört dem Text, dem Moodlight und dem Anzeiger.
            throw Fehler.optionGiltNurFuer(option: "--farbe", befehl: "moodlight")
        }
        func keinWeiteres(ab i: Int) throws {
            if freie.count > i { throw Fehler.ueberzaehligesWort(befehl: name, wort: freie[i]) }
        }
        switch befehl {
        case .display:
            guard let w = freie.first?.lowercased() else { throw Fehler.unvollstaendig(befehl: name, erwartet: "an / aus") }
            switch w {
            case "an", "ein", "on": befehl = .display(an: true)
            case "aus", "off": befehl = .display(an: false)
            default: throw Fehler.unvollstaendig(befehl: name, erwartet: "an / aus")
            }
            try keinWeiteres(ab: 1)
        case .helligkeit:
            guard let w = freie.first else { throw Fehler.unvollstaendig(befehl: name, erwartet: "0–255") }
            guard let n = Int(w) else { throw Fehler.keineZahl(option: name, wert: w) }
            guard (0...255).contains(n) else {
                throw SteuerungsFehler.ausserhalb(feld: "brightness", wert: String(n), bereich: "0–255")
            }
            befehl = .helligkeit(n)
            try keinWeiteres(ab: 1)
        case .moodlightAus, .moodlight:
            if let w = freie.first?.lowercased(), ["aus", "off"].contains(w) {
                guard !farbeAngegeben, kelvin == nil, steuerhelligkeit == nil else {
                    throw Fehler.ueberzaehligesWort(befehl: "moodlight aus", wort: moodlightoption ?? "--farbe")
                }
                befehl = .moodlightAus
                try keinWeiteres(ab: 1)
                return
            }
            // Eine Farbe darf auch als Wort dastehen: `moodlight "#FF8800"`.
            var wahl = farbeAngegeben ? self.farbe : nil
            if let w = freie.first {
                guard Self.istFarbe(w) else { throw Fehler.keineFarbe(w) }
                wahl = w
                try keinWeiteres(ab: 1)
            }
            let licht = Moodlight(farbe: wahl, kelvin: kelvin, helligkeit: steuerhelligkeit)
            try licht.pruefen()
            befehl = .moodlight(licht)
        case .indikatorAus, .indikator:
            guard let erstes = freie.first else { throw Fehler.unvollstaendig(befehl: name, erwartet: "1–3") }
            guard let n = Int(erstes), Indikator.nummern.contains(n) else {
                throw SteuerungsFehler.ungueltigeKennziffer(Int(erstes) ?? 0)
            }
            if let w = freie.dropFirst().first?.lowercased(), ["aus", "off"].contains(w) {
                guard !farbeAngegeben, blinken == nil, blenden == nil else {
                    throw Fehler.ueberzaehligesWort(befehl: "indikator aus", wort: indikatoroption ?? "--farbe")
                }
                befehl = .indikatorAus(nummer: n)
                try keinWeiteres(ab: 2)
                return
            }
            guard farbeAngegeben else { throw Fehler.unvollstaendig(befehl: name, erwartet: "aus / --farbe #RRGGBB") }
            try keinWeiteres(ab: 1)
            let stand = Indikator(nummer: n, farbe: farbe, blinkMs: blinken ?? 0, fadeMs: blenden ?? 0)
            try stand.pruefen()
            befehl = .indikator(stand)
        case .weiter, .zurueck, .zustand, .neustart:
            try keinWeiteres(ab: 0)
        case .einstellungen:
            guard let w = freie.first else { return }
            guard ["setzen", "set"].contains(w.lowercased()) else {
                throw Fehler.ueberzaehligesWort(befehl: name, wort: w)
            }
            guard freie.count >= 3 else { throw Fehler.unvollstaendig(befehl: name + " setzen", erwartet: "<Schlüssel> <Wert>") }
            try keinWeiteres(ab: 3)
            befehl = .einstellungenSetzen(schluessel: freie[1], wert: freie[2])
        case .tls:
            guard let w = freie.first else { return }
            guard w.lowercased() == "ca" else { throw Fehler.ueberzaehligesWort(befehl: name, wort: w) }
            guard freie.count >= 2 else { throw Fehler.unvollstaendig(befehl: "tls ca", erwartet: "<Datei.pem> / entfernen") }
            if ["entfernen", "remove"].contains(freie[1].lowercased()) {
                befehl = .tlsCAEntfernen
            } else {
                befehl = .tlsCA(datei: freie[1])
            }
            try keinWeiteres(ab: 2)
        default:
            break
        }
    }

    /// Entfernt die Argumente, die Foundation fuer sich beansprucht, samt ihrem
    /// Wert: ein Strich, dann ein Grossbuchstabe (`-AppleLanguages "(en)"`,
    /// `-AppleLocale`, `-NSShowAllViews`). Damit laesst sich das Werkzeug
    /// einmalig in einer anderen Sprache starten, ohne etwas umzustellen.
    ///
    /// Muss vor allem anderen geschehen: Solche Argumente koennen an jeder
    /// Stelle stehen, auch vor dem Befehlswort.
    static func ohneEinstellungsargumente(_ argumente: [String]) -> [String] {
        var ergebnis: [String] = []
        var i = 0
        while i < argumente.count {
            let arg = argumente[i]
            if arg.count > 1, arg.hasPrefix("-"), !arg.hasPrefix("--"),
               arg.dropFirst().first?.isUppercase == true {
                i += 2                                    // Name und Wert
                continue
            }
            ergebnis.append(arg)
            i += 1
        }
        return ergebnis
    }

    /// Die erste Lebensdauer-Option, die da stand — an einer Nachricht ist keine
    /// erlaubt.
    var lebensdaueroption: String? {
        if behalten { return "--behalten" }
        if lebensdauer != nil { return "--lebensdauer" }
        return ablauf != nil ? "--ablauf" : nil
    }

    /// Die Felder aus §5.6 gehören einer Benachrichtigung; an einer Anzeige wären
    /// sie `422`.
    private func nurFuerNachrichtenPruefen() throws {
        if let option = nachrichtenoption { throw Fehler.optionGiltNurFuer(option: option, befehl: "nachricht") }
    }

    /// Eine Palette: ein Name, oder Farben mit Komma dazwischen
    /// (`#FF0000,#0000FF`), oder Farben mit Lage 0–100 (`#FF0000@0,#0000FF@100`).
    static func palette(_ wort: String) throws -> Palette {
        guard wort.hasPrefix("#") else { return .name(wort) }
        let teile = wort.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let mitLage = teile.map { $0.contains("@") }
        guard Set(mitLage).count == 1 else { throw Fehler.paletteGemischt(wort) }
        func farbe(_ s: String) throws -> String {
            guard istFarbe(s) else { throw Fehler.keineFarbe(s) }
            return s
        }
        if mitLage[0] {
            return .stellen(try teile.map { t in
                let paar = t.split(separator: "@", omittingEmptySubsequences: false).map(String.init)
                guard paar.count == 2, let pos = Int(paar[1]) else { throw Fehler.keineFarbe(t) }
                return .init(farbe: try farbe(paar[0]), pos: pos)
            })
        }
        return .farben(try teile.map(farbe))
    }

    private static func istFarbe(_ s: String) -> Bool {
        guard s.hasPrefix("#"), s.count == 7 else { return false }
        return UInt32(s.dropFirst(), radix: 16) != nil
    }

    /// Die Optionen der Kommandozeile als das, was der Kern versteht.
    var meldung: Meldungsoptionen {
        var o = Meldungsoptionen(text: "")
        o.schrift = schrift
        o.groesse = groesse
        o.fett = fett
        o.farbe = farbe
        o.waagrecht = waagrecht
        o.senkrecht = senkrecht
        o.rand = rand
        o.abstand = abstand
        o.tempo = tempo
        o.dauer = dauer
        // Ohne jede Angabe bleibt es `nil`, und das heißt: die Vorgabe (30 Minuten).
        if istAnzeige {
            if behalten {
                o.lebensdauer = .aus
            } else if lebensdauer != nil || ablauf != nil {
                o.lebensdauer = Lebensdauer(sekunden: lebensdauer ?? Lebensdauer.vorgabe.sekunden,
                                            ablauf: ablauf ?? .entfernen)
            }
        }
        return o
    }

    /// Eine Anzeige mit Lebensdauer: Text oder Layout.
    private var istAnzeige: Bool {
        switch befehl {
        case .senden, .layout: return true
        default: return false
        }
    }

    /// Die Felder einer Benachrichtigung (§5.6). Ohne `--name` hat sie keinen.
    var benachrichtigung: Benachrichtigungsoptionen {
        Benachrichtigungsoptionen(name: nameAngegeben ? anzeigename : nil, halten: halten,
                                  einreihen: einreihen, aufwecken: aufwecken,
                                  wiederholungen: wiederholungen, klang: klang)
    }

    /// Den Rahmen um das ergänzen, was die Kommandozeile zur Darstellung sagt. Ein
    /// Diagramm oder Fortschritt ersetzt den Rahmen ganz (kein Text, kein Bild).
    func mitDarstellung(_ rahmen: Frame) -> Frame {
        var f = rahmen
        if grafikGesetzt {
            f = Frame(dauer: rahmen.dauer, lebensdauer: rahmen.lebensdauer, grafik: grafik)
        }
        f.darstellung = darstellung.istLeer ? nil : darstellung
        return f
    }

    /// Ein Rahmen aus der Grafik allein, wo kein Text zu rastern ist.
    var grafikrahmen: Frame {
        mitDarstellung(Frame(dauer: dauer, lebensdauer: meldung.wirksameLebensdauer))
    }
}
