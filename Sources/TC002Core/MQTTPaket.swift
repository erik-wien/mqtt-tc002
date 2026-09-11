import Foundation

public enum MQTTFehler: Error, LocalizedError {
    case nichtVerbunden(String)
    case abgelehnt(code: UInt8)
    case zeitueberschreitung

    public var errorDescription: String? {
        switch self {
        case .nichtVerbunden(let grund):
            return "Der Broker ist nicht erreichbar: \(grund)"
        case .abgelehnt(let code):
            switch code {
            case 1: return "Der Broker spricht diese Protokollversion nicht."
            case 2: return "Die Client-Kennung wurde abgelehnt."
            case 3: return "Der Broker ist gerade nicht verfügbar."
            case 4: return "Benutzername oder Kennwort stimmen nicht."
            case 5: return "Dieses Konto darf sich nicht anmelden."
            default: return "Der Broker hat die Anmeldung abgelehnt (Code \(code))."
            }
        case .zeitueberschreitung:
            return "Der Broker hat nicht geantwortet."
        }
    }
}

/// Baut die drei Pakete, die zum Senden genuegen. Reine Funktionen, damit sie
/// Byte fuer Byte gegen eine Aufzeichnung geprueft werden koennen.
public enum MQTTPaket {
    /// MQTT-Restlaenge: sieben Bit je Byte, oberstes Bit heisst "es folgt noch eines".
    static func restlaenge(_ n: Int) -> Data {
        var rest = n, out = Data()
        repeat {
            var b = UInt8(rest & 0x7F)
            rest >>= 7
            if rest > 0 { b |= 0x80 }
            out.append(b)
        } while rest > 0
        return out
    }

    /// Laengenpraefigierte Zeichenkette: zwei Byte Laenge, dann UTF-8.
    static func zeichenkette(_ s: String) -> Data {
        let b = Data(s.utf8)
        return Data([UInt8(b.count >> 8), UInt8(b.count & 0xFF)]) + b
    }

    public static func connect(clientID: String, benutzer: String?,
                               kennwort: String?, frist: UInt16 = 60) -> Data {
        var merkmale: UInt8 = 0x02                       // saubere Sitzung
        if benutzer != nil { merkmale |= 0x80 }
        if kennwort != nil { merkmale |= 0x40 }
        var rumpf = zeichenkette("MQTT")
        rumpf.append(0x04)                               // Protokollversion 3.1.1
        rumpf.append(merkmale)
        rumpf.append(UInt8(frist >> 8)); rumpf.append(UInt8(frist & 0xFF))
        rumpf += zeichenkette(clientID)
        if let benutzer { rumpf += zeichenkette(benutzer) }
        if let kennwort { rumpf += zeichenkette(kennwort) }
        return Data([0x10]) + restlaenge(rumpf.count) + rumpf
    }

    public static func publish(thema: String, nutzlast: Data) -> Data {
        let rumpf = zeichenkette(thema) + nutzlast       // Guetegrad 0: keine Paketkennung
        return Data([0x30]) + restlaenge(rumpf.count) + rumpf
    }

    public static func disconnect() -> Data { Data([0xE0, 0x00]) }

    /// Liefert den Rueckgabecode eines CONNACK, oder nil wenn es keines ist.
    public static func connackCode(_ daten: Data) -> UInt8? {
        guard daten.count >= 4, daten[daten.startIndex] == 0x20 else { return nil }
        return daten[daten.startIndex + 3]
    }
}
