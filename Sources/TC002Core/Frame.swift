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

/// Text und Regler, aus denen die Uhr eine Anzeige in ihrer eigenen Schrift
/// setzt (`SendeWeg.text`, `NGNutzlast.anzeige`) — und das Icon neben dem Text.
///
/// Sie reist mit dem Rahmen mit, statt an vier Stellen getrennt weitergereicht
/// zu werden: Jeder Absender — App, Kommandozeilenwerkzeug, Kurzbefehl — baut
/// seinen Rahmen ueber `Meldungsbau.rahmen`.
public struct Meldungsherkunft: Equatable, Sendable {
    public var optionen: Meldungsoptionen
    /// Das Icon als vollstaendige Daten-URI, GIF (`NGNutzlast.icon`).
    public var iconDatenURI: String?

    public init(optionen: Meldungsoptionen, iconDatenURI: String? = nil) {
        self.optionen = optionen
        self.iconDatenURI = iconDatenURI
    }
}

/// Ein Rahmen: entweder Pixel, die die App gerastert hat (`pixel`, der
/// Pixelweg), oder Text samt Reglern (`herkunft`, den die Uhr in ihrer Schrift
/// setzt), dazu die Standzeit. `pixel` geht vor.
public struct Frame: Equatable, Sendable {
    public var pixel: Pixelinhalt?
    public var dauer: Int?
    /// Siehe `Meldungsherkunft` — steht daneben, nicht darin.
    public var herkunft: Meldungsherkunft?

    /// Was hier hinausgeht, in einem Satz — fuer das Protokoll.
    public var beschreibung: String {
        var teile: [String] = []
        if let pixel {
            teile.append(pixel.istBewegt ? lokf("%d Bilder", pixel.bilder.count) : lok("Pixelbild"))
        } else if let herkunft {
            teile.append(lokf("Text „%@“", herkunft.optionen.text))
        }
        if let dauer { teile.append(lokf("%d s", dauer)) }
        return teile.joined(separator: " · ")
    }

    public init(pixel: Pixelinhalt? = nil, dauer: Int? = nil, herkunft: Meldungsherkunft? = nil) {
        self.pixel = pixel; self.dauer = dauer
        self.herkunft = herkunft
    }
}
