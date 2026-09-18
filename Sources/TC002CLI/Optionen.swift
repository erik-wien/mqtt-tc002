import Foundation
import TC002Core

/// Was auf der Kommandozeile stand, geprueft und in brauchbare Werte gewandelt.
///
/// Eigener Typ und nicht in `main.swift`, damit sich das Zerlegen pruefen laesst,
/// ohne zu senden — der Teil, in dem die Fehler stecken, ist das Zerlegen.
struct Optionen {
    enum Befehl: Equatable {
        case senden(text: String)
        case loeschen(anzeige: String)
        case umschalten(anzeige: String)
        case uhren
        case icons
        /// Ein fertiges Bild aus dem Bestand schicken — der Name, unter dem es
        /// im Editor gesichert wurde.
        case bild(name: String)
        /// Den Bilderbestand auflisten, wie `icons` die Icons.
        case bilder
        case hilfe
        case fassung
    }

    var befehl: Befehl = .hilfe
    var ziele: [String] = []
    var anzeigename = "cli"
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
    var geraeteschrift = false
    var tempo: Lauftempo = .mittel
    var trocken = false

    enum Fehler: Error, LocalizedError {
        case unbekannteOption(String)
        case fehlenderWert(String)
        case keineZahl(option: String, wert: String)
        case keineFarbe(String)
        case fehlenderText
        case fehlenderBildname

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

            switch arg {
            case "--an", "--to":          o.ziele.append(try wert())
            case "--name":                o.anzeigename = try wert()
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
            case "--geraeteschrift", "--device-font": o.geraeteschrift = true
            case "--trocken", "--dry-run": o.trocken = true
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
        case .senden:
            guard !freierText.isEmpty else { throw Fehler.fehlenderText }
            o.befehl = .senden(text: o.grossbuchstaben ? freierText.uppercased() : freierText)
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

    private static func istFarbe(_ s: String) -> Bool {
        guard s.hasPrefix("#"), s.count == 7 else { return false }
        return UInt32(s.dropFirst(), radix: 16) != nil
    }

    /// Die Optionen der Kommandozeile als das, was der Kern versteht.
    var meldung: Meldungsoptionen {
        var o = Meldungsoptionen(text: "")
        o.weg = geraeteschrift ? .text : .pixel
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
        return o
    }
}
