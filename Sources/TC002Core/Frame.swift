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

public struct Textblock: Equatable, Sendable {
    public var inhalt: String
    public var schrifthoehe: Int = 10
    public var x: Int = 0, y: Int = 3
    public var farbe: String = "#FFFFFF"
    public var ausrichtung: String = "left"
    public var vertikal: String = "top"
    public var flaeche: [Int] = [0, 0, 52, 16]
    public var zeichenabstand: Int = 1
    public init(inhalt: String) { self.inhalt = inhalt }
}

/// Woraus ein Rahmen entstanden ist.
///
/// **Gehoert nicht zur Nutzlast** und kommt in `alsJSON()` nicht vor. Die
/// Werksfirmware bekommt fertige Pixel und braucht nichts weiter; eine AWTRIX
/// NG setzt den Text dagegen selbst, und ihr nuetzen gerade die Pixel nichts —
/// sie braucht den Text und die Regler, aus denen er entstand
/// (`NGNutzlast.anzeige`).
///
/// Deshalb reist die Herkunft mit dem Rahmen mit, statt an vier Stellen
/// getrennt weitergereicht zu werden: Jeder Absender — App, Kommandozeilen-
/// werkzeug, Kurzbefehl — baut seinen Rahmen ueber `Meldungsbau.rahmen`, und
/// damit kann jeder von ihnen an beide Gattungen senden, ohne es eigens zu
/// wissen. Wo es keine Regler gibt (ein gemaltes Bild, ein Bild aus der
/// Sammlung), bleibt sie `nil` — und genau dann sagt `Anzeigen`, dass diese
/// Sendung an eine AWTRIX nicht geht, statt sie ins Leere zu schicken.
public struct Meldungsherkunft: Equatable, Sendable {
    public var optionen: Meldungsoptionen
    /// Das Icon als vollstaendige Daten-URI — so, wie es die Werksfirmware
    /// bekommt. NG schneidet den Vorsatz selbst ab (`NGNutzlast.icon`).
    public var iconDatenURI: String?
    /// Die Kantenlaenge des Icons. Der Werksfirmware ist sie einerlei — sie
    /// bekommt das fertige Bild an der richtigen Stelle. Eine AWTRIX NG hat
    /// acht Zeilen, und ein 16×16-Icon spielt dort gar nicht; ohne diese
    /// Angabe liesse sich das erst am dunklen Geraet feststellen.
    public var iconKante: Int

    public init(optionen: Meldungsoptionen, iconDatenURI: String? = nil, iconKante: Int = 8) {
        self.optionen = optionen
        self.iconDatenURI = iconDatenURI
        self.iconKante = iconKante
    }
}

/// Was die Uhr als Nutzlast erwartet. Leere Bestandteile fallen weg — das Geraet
/// stolpert sonst ueber leere Felder, und die Nachrichten werden unnoetig gross.
public struct Frame: Equatable, Sendable {
    public var draw: [DrawBefehl] = []
    public var bilder: [Bild] = []
    public var texte: [Textblock] = []
    public var dauer: Int?
    /// Siehe `Meldungsherkunft` — steht daneben, nicht darin.
    public var herkunft: Meldungsherkunft?

    public init(draw: [DrawBefehl] = [], bilder: [Bild] = [],
                texte: [Textblock] = [], dauer: Int? = nil,
                herkunft: Meldungsherkunft? = nil) {
        self.draw = draw; self.bilder = bilder; self.texte = texte; self.dauer = dauer
        self.herkunft = herkunft
    }

    public func alsJSON() -> String {
        var teile: [String] = []
        if !draw.isEmpty {
            let b = draw.map { #"{"df":[\#($0.x),\#($0.y),\#($0.breite),\#($0.hoehe),"\#(jsonEscape($0.farbe))"]}"# }
            teile.append(#""draw":[\#(b.joined(separator: ","))]"#)
        }
        if !bilder.isEmpty {
            let b = bilder.map { #"{"data":"\#(jsonEscape($0.datenURI))","position":[\#($0.x),\#($0.y)]}"# }
            teile.append(#""image":[\#(b.joined(separator: ","))]"#)
        }
        if !texte.isEmpty {
            let b = texte.map { t in
                #"{"content":"\#(jsonEscape(t.inhalt))","fontHeight":\#(t.schrifthoehe),"x":\#(t.x),"y":\#(t.y),"# +
                #""color":"\#(jsonEscape(t.farbe))","align":"\#(jsonEscape(t.ausrichtung))","valign":"\#(jsonEscape(t.vertikal))","# +
                #""rect":[\#(t.flaeche.map(String.init).joined(separator: ","))],"charSpacing":\#(t.zeichenabstand)}"#
            }
            teile.append(#""text":[\#(b.joined(separator: ","))]"#)
        }
        if let dauer { teile.append(#""duration":\#(dauer)"#) }
        return "{" + teile.joined(separator: ",") + "}"
    }
}
