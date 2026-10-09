import Foundation

/// Maskiert einen Text fuer die Verwendung als JSON-Zeichenkette (ohne umschliessende
/// Anfuehrungszeichen). Wird auf jeden nutzergesteuerten Text angewendet, bevor er in
/// die JSON-Nutzlast eingebettet wird — sonst erzeugt ein Anfuehrungszeichen, ein
/// Rueckwaertsstrich oder ein Steuerzeichen im Text ungueltiges JSON.
func jsonEscape(_ text: String) -> String {
    var ergebnis = ""
    ergebnis.reserveCapacity(text.count)
    for scalar in text.unicodeScalars {
        switch scalar {
        case "\"": ergebnis += "\\\""
        case "\\": ergebnis += "\\\\"
        case "\n": ergebnis += "\\n"
        case "\r": ergebnis += "\\r"
        case "\t": ergebnis += "\\t"
        default:
            if scalar.value < 0x20 {
                ergebnis += String(format: "\\u%04x", scalar.value)
            } else {
                ergebnis.unicodeScalars.append(scalar)
            }
        }
    }
    return ergebnis
}

/// Ein einzelner Zeichenbefehl: gefuelltes Rechteck. Mit Breite und Hoehe 1 ein Pixel.
public struct DrawBefehl: Equatable, Sendable {
    public var x: Int, y: Int, breite: Int, hoehe: Int, farbe: String
    public init(x: Int, y: Int, breite: Int, hoehe: Int, farbe: String) {
        self.x = x; self.y = y; self.breite = breite; self.hoehe = hoehe; self.farbe = farbe
    }
}

public struct Bild: Equatable, Sendable {
    public var datenURI: String
    public var x: Int
    public var y: Int
    public init(datenURI: String, x: Int = 0, y: Int = 0) {
        self.datenURI = datenURI; self.x = x; self.y = y
    }
}

/// Woraus ein Rahmen entstanden ist.
///
/// AWTRIX NG setzt den Text selbst; ihr nuetzen gerade die Pixel nichts, sie
/// braucht den Text und die Regler, aus denen er entstand
/// (`NGNutzlast.anzeige`).
///
/// Deshalb reist die Herkunft mit dem Rahmen mit, statt an vier Stellen
/// getrennt weitergereicht zu werden: Jeder Absender — App, Kommandozeilen-
/// werkzeug, Kurzbefehl — baut seinen Rahmen ueber `Meldungsbau.rahmen`. Wo es
/// keine Regler gibt (ein gemaltes Bild, ein Bild aus der Sammlung), bleibt sie
/// `nil` — und genau dann sagt `Anzeigen`, dass diese Sendung nicht geht,
/// statt sie ins Leere zu schicken.
public struct Meldungsherkunft: Equatable, Sendable {
    public var optionen: Meldungsoptionen
    /// Das Icon als vollstaendige Daten-URI. NG schneidet den Vorsatz selbst
    /// ab (`NGNutzlast.icon`).
    public var iconDatenURI: String?

    public init(optionen: Meldungsoptionen, iconDatenURI: String? = nil) {
        self.optionen = optionen
        self.iconDatenURI = iconDatenURI
    }
}

/// Ein Rahmen: gerasterte Rechtecke oder Bilder als Daten, die Standzeit und
/// seine Herkunft. Gesendet wird heute allein, was `herkunft` traegt.
public struct Frame: Equatable, Sendable {
    public var draw: [DrawBefehl] = []
    public var bilder: [Bild] = []
    public var dauer: Int?

    /// Was hier hinausgeht, in einem Satz — fuer das Protokoll: Rechtecke,
    /// Bilder, der Text samt Regler und die Standzeit.
    ///
    /// Ohne `lok`: Die Teile sind uebersetzt, zusammengesetzt wird mit
    /// Trennzeichen.
    public var beschreibung: String {
        var teile: [String] = []
        if !draw.isEmpty { teile.append(lokf("%d Rechtecke", draw.count)) }
        if !bilder.isEmpty { teile.append(lokf("%d Bilder", bilder.count)) }
        if let herkunft { teile.append(lokf("Text „%@“", herkunft.optionen.text)) }
        if let dauer { teile.append(lokf("%d s", dauer)) }
        return teile.joined(separator: " · ")
    }
    /// Siehe `Meldungsherkunft` — steht daneben, nicht darin.
    public var herkunft: Meldungsherkunft?

    public init(draw: [DrawBefehl] = [], bilder: [Bild] = [],
                dauer: Int? = nil, herkunft: Meldungsherkunft? = nil) {
        self.draw = draw; self.bilder = bilder; self.dauer = dauer
        self.herkunft = herkunft
    }
}
