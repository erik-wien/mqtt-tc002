import Foundation

/// Die drei Dinge, die man mit einer benannten Anzeige auf der Uhr tun kann.
public struct Anzeigen {
    private let sender: NachrichtSendend
    private let zugang: MQTTZugang
    private let praefix: String

    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String) {
        self.sender = sender
        self.zugang = zugang
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        self.praefix = normalisiert
    }

    public func zeigen(_ frame: Frame, auf name: String) throws {
        try sender.senden(Data(frame.alsJSON().utf8), an: "\(praefix)/custom/\(name)", zugang: zugang)
    }

    /// Eine leere Nutzlast entfernt die Anzeige vom Geraet.
    public func loeschen(_ name: String) throws {
        try sender.senden(Data(), an: "\(praefix)/custom/\(name)", zugang: zugang)
    }

    public func umschalten(auf name: String) throws {
        try sender.senden(Data(name.utf8), an: "\(praefix)/switchDiyApp", zugang: zugang)
    }
}
