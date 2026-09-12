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

/// Baut die Pakete, die zum Senden und zum Zuhoeren genuegen, und liest die
/// Antworten des Brokers. Reine Funktionen, damit sie Byte fuer Byte gegen eine
/// Aufzeichnung geprueft werden koennen.
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

    /// Liest eine Restlaenge ab dem Versatz `ab` — die Gegenrichtung zu
    /// `restlaenge(_:)`. Liefert den Wert und die Zahl der dafuer gelesenen
    /// Bytes; nil, solange noch nicht alle da sind. Mehr als vier Laengenbytes
    /// gibt es nicht, danach ist der Strom kaputt und es bleibt ebenfalls nil.
    static func restlaengeGelesen(_ daten: Data, ab: Int) -> (wert: Int, bytes: Int)? {
        var wert = 0, faktor = 1, versatz = ab
        while versatz < daten.count, versatz - ab < 4 {
            let b = daten[daten.startIndex + versatz]
            wert += Int(b & 0x7F) * faktor
            versatz += 1
            if b & 0x80 == 0 { return (wert, versatz - ab) }
            faktor *= 128
        }
        return nil
    }

    /// SUBSCRIBE fuer ein Thema. Der feste Kopf ist 0x82: die unteren vier Bit
    /// sind bei SUBSCRIBE laut Norm fest mit 0b0010 belegt, ein Broker weist
    /// alles andere ab. Abonniert wird mit Guetegrad 0 — hoehere Guetegrade
    /// braeuchten eine Empfangsbestaetigung je Nachricht.
    public static func subscribe(thema: String, paketID: UInt16) -> Data {
        var rumpf = Data([UInt8(paketID >> 8), UInt8(paketID & 0xFF)])
        rumpf += zeichenkette(thema)
        rumpf.append(0x00)                               // gewuenschter Guetegrad
        return Data([0x82]) + restlaenge(rumpf.count) + rumpf
    }

    /// PINGREQ. Ohne ihn wirft der Broker die Verbindung nach dem Anderthalbfachen
    /// der im CONNECT vereinbarten Frist hinaus.
    public static func pingreq() -> Data { Data([0xC0, 0x00]) }

    /// Liest ein SUBACK: Paketkennung und ob der Broker das Abonnement annimmt.
    /// 0x80 heisst abgelehnt, 0x00 bis 0x02 ist der gewaehrte Guetegrad.
    public static func subackGelesen(_ daten: Data) -> (paketID: UInt16, angenommen: Bool)? {
        let s = daten.startIndex
        guard daten.count >= 5, daten[s] == 0x90,
              let (_, laengenBytes) = restlaengeGelesen(daten, ab: 1),
              daten.count >= 1 + laengenBytes + 3 else { return nil }
        let ab = s + 1 + laengenBytes
        let id = UInt16(daten[ab]) << 8 | UInt16(daten[ab + 1])
        return (id, daten[ab + 2] != 0x80)
    }

    /// Zerlegt ein eintreffendes PUBLISH mit Guetegrad 0 in Thema und Nutzlast.
    /// Hoehere Guetegrade traegen zwischen Thema und Nutzlast noch eine
    /// Paketkennung; sie koennen hier nicht auftreten, weil mit Guetegrad 0
    /// abonniert wird — deshalb muessen die Guetegrad-Bits (1 und 2) leer sein.
    /// DUP (Bit 3) und RETAIN (Bit 0) dagegen aendern den Aufbau nicht und
    /// werden ausgeblendet: eine aufbewahrte Nachricht kommt als 0x31 an.
    public static func publishGelesen(_ daten: Data) -> (thema: String, nutzlast: Data)? {
        let s = daten.startIndex
        guard daten.count >= 2, daten[s] & 0xF6 == 0x30,
              let (rest, laengenBytes) = restlaengeGelesen(daten, ab: 1) else { return nil }
        let rumpfAb = 1 + laengenBytes
        guard rest >= 2, daten.count >= rumpfAb + rest else { return nil }
        let themaLaenge = Int(daten[s + rumpfAb]) << 8 | Int(daten[s + rumpfAb + 1])
        guard rest >= 2 + themaLaenge else { return nil }
        let themaAb = s + rumpfAb + 2
        guard let thema = String(data: daten[themaAb ..< themaAb + themaLaenge], encoding: .utf8) else { return nil }
        return (thema, Data(daten[(themaAb + themaLaenge) ..< (s + rumpfAb + rest)]))
    }
}
