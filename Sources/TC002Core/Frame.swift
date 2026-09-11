import Foundation

/// Ein einzelner Zeichenbefehl: gefuelltes Rechteck. Mit Breite und Hoehe 1 ein Pixel.
public struct DrawBefehl: Equatable, Sendable {
    public var x: Int, y: Int, breite: Int, hoehe: Int, farbe: String
    public init(x: Int, y: Int, breite: Int, hoehe: Int, farbe: String) {
        self.x = x; self.y = y; self.breite = breite; self.hoehe = hoehe; self.farbe = farbe
    }
}

public struct Bild: Equatable, Sendable {
    public var datenURI: String
    public var position: [Int]
    public init(datenURI: String, position: [Int] = [0, 0]) {
        self.datenURI = datenURI; self.position = position
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

/// Was die Uhr als Nutzlast erwartet. Leere Bestandteile fallen weg — das Geraet
/// stolpert sonst ueber leere Felder, und die Nachrichten werden unnoetig gross.
public struct Frame: Equatable, Sendable {
    public var draw: [DrawBefehl] = []
    public var bilder: [Bild] = []
    public var texte: [Textblock] = []
    public var dauer: Int?

    public init(draw: [DrawBefehl] = [], bilder: [Bild] = [],
                texte: [Textblock] = [], dauer: Int? = nil) {
        self.draw = draw; self.bilder = bilder; self.texte = texte; self.dauer = dauer
    }

    public func alsJSON() throws -> String {
        var teile: [String] = []
        if !draw.isEmpty {
            let b = draw.map { #"{"df":[\#($0.x),\#($0.y),\#($0.breite),\#($0.hoehe),"\#($0.farbe)"]}"# }
            teile.append(#""draw":[\#(b.joined(separator: ","))]"#)
        }
        if !bilder.isEmpty {
            let b = bilder.map { #"{"data":"\#($0.datenURI)","position":[\#($0.position[0]),\#($0.position[1])]}"# }
            teile.append(#""image":[\#(b.joined(separator: ","))]"#)
        }
        if !texte.isEmpty {
            let b = texte.map { t in
                #"{"content":"\#(t.inhalt)","fontHeight":\#(t.schrifthoehe),"x":\#(t.x),"y":\#(t.y),"# +
                #""color":"\#(t.farbe)","align":"\#(t.ausrichtung)","valign":"\#(t.vertikal)","# +
                #""rect":[\#(t.flaeche.map(String.init).joined(separator: ","))],"charSpacing":\#(t.zeichenabstand)}"#
            }
            teile.append(#""text":[\#(b.joined(separator: ","))]"#)
        }
        if let dauer { teile.append(#""duration":\#(dauer)"#) }
        return "{" + teile.joined(separator: ",") + "}"
    }
}
