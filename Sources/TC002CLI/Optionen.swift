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
    var halten = true
    var ersetzen = false
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

    enum Fehler: Error, LocalizedError {
        case unbekannteOption(String)
        case fehlenderWert(String)
        case keineZahl(option: String, wert: String)
        case keineFarbe(String)
        case fehlenderText
        case fehlenderBildname
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
        case "hilfe", "help", "--help", "-h":
            return Optionen(befehl: .hilfe)
        case "fassung", "version", "--version":
            return Optionen(befehl: .fassung)
        default:
            // Ohne Befehlswort ist alles Text: `mqtttc002 "Hallo"` soll gehen.
            o.befehl = .senden(text: "")
            rest = argumente
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
            case "--an", "--to":          o.ziele.append(try wert())
            case "--name":                o.anzeigename = try wert(); o.nameAngegeben = true
            case "--farbe", "--color":
                let w = try wert()
                guard Self.istFarbe(w) else { throw Fehler.keineFarbe(w) }
                o.farbe = w
            case "--icon":                o.iconNummer = try wert()
            case "--schrift", "--font":   o.schrift = try wert()
            case "--groesse", "--size":   o.groesse = Double(try zahl())
            case "--fett", "--bold":      o.fett = true
            case "--gross", "--upper":    o.grossbuchstaben = true
            case "--rand", "--margin":    o.rand = try zahl()
            case "--abstand", "--gap":    o.abstand = try zahl()
            case "--dauer", "--duration": o.dauer = try zahl()
            case "--trocken", "--dry-run": o.trocken = true
            case "--nicht-halten", "--no-hold":     o.halten = false; o.nachrichtenoption = o.nachrichtenoption ?? arg
            case "--ersetzen", "--replace":         o.ersetzen = true; o.nachrichtenoption = o.nachrichtenoption ?? arg
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
        default:
            break
        }
        return o
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
        if case .senden = befehl {
            if behalten {
                o.lebensdauer = .aus
            } else if lebensdauer != nil || ablauf != nil {
                o.lebensdauer = Lebensdauer(sekunden: lebensdauer ?? Lebensdauer.vorgabe.sekunden,
                                            ablauf: ablauf ?? .entfernen)
            }
        }
        return o
    }

    /// Die Felder einer Benachrichtigung (§5.6). Ohne `--name` hat sie keinen.
    var benachrichtigung: Benachrichtigungsoptionen {
        Benachrichtigungsoptionen(name: nameAngegeben ? anzeigename : nil, halten: halten,
                                  einreihen: !ersetzen, aufwecken: aufwecken,
                                  wiederholungen: wiederholungen)
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
