import Foundation

/// Fassung, Update und Neustart der virtuellen NG-Uhr.
public struct NGFirmware: Equatable, Sendable {
    /// Die laufende Fassung (`/api/v1/version`, `device.version`).
    public var fassung = "1.2.2"
    /// `device.updateImage`; die TC002 nimmt `awtrix-ng-tc002.awup`, ESP32 ein `.bin`.
    public var image = "awtrix-ng-tc002.awup"
    /// Der Einrichtungsmodus (eigener Hotspot): `403 forbidden`.
    public var einrichtungsmodus = false
    /// Ein anderes Update läuft oder wird noch bestätigt: `409 updateBusy`.
    public var belegt = false
    /// Wie viele Byte die Uhr für ein Paket aufnimmt (`409 insufficientStorage`).
    public var platz = 8 << 20
    /// `update.state`.
    public var stand = "idle"
    /// `update.error`.
    public var fehler = ""
    /// Das nächste Update scheitert beim Start: Die alte Fassung läuft weiter,
    /// `update.state` ist danach `failed`.
    public var startScheitert = false
    /// Wie viele Fragen nach `/api/v1/version` und `/api/v1/device` nach dem Hochladen
    /// noch die alte Fassung nennen, ehe die Uhr ausfällt.
    public var altAntworten = 1
    /// Wie viele Anfragen danach mit `503` scheitern (die Uhr startet neu).
    public var ausfaelle = 2

    // Nach dem Hochladen: die Fassung, die nach dem Neustart läuft.
    var ausstehend: String?
    var altRest = 0
    var ausfallRest = 0

    public init() {}

    /// Ein Paket, wie die virtuelle Uhr es liest. Das Format der echten Pakete ist nicht
    /// bekannt (❓): Die virtuelle Uhr erwartet nach der Kennung (`AWUPD003` bei `.awup`,
    /// Byte `0xE9` bei `.bin`) die Angabe `<Ziel>|<Fassung>` (`.awup`) bzw. `<Fassung>`
    /// (`.bin`), danach ein NUL und beliebige Füllbytes.
    public static func paket(dateiname: String = "awtrix-ng-tc002.awup", ziel: String = "tc002",
                             fassung: String, fuellung: Int = 64) -> Data {
        var d = Firmwarepakete.istAwup(dateiname) ? Data("AWUPD003".utf8) : Data([0xE9])
        d.append(Data((Firmwarepakete.istAwup(dateiname) ? ziel + "|" + fassung : fassung).utf8))
        d.append(0)
        d.append(Data(repeating: 0x5A, count: fuellung))
        return d
    }
}

/// `POST /update` und der Neustart danach.
///
/// Folgt `reference/http` (Firmware upload), `reference/errors` und `guides/updating`.
/// Annahmen, wo die Doku schweigt (❓):
/// - das Paketformat (`NGFirmware.paket`);
/// - die Reihenfolge der Prüfungen: Einrichtungsmodus, belegt, Datei, Größe, Kennung,
///   Ziel, Fassung, Speicher;
/// - die Fassungsprüfung (`notNewer`) gibt es nur bei `.awup`; die ESP32-Abbilder
///   nehmen jede Fassung (die Doku nennt dort nur `wrongChip`);
/// - der Neustart ist eine Folge von Anfragen: erst `altAntworten` Fragen nach der
///   Fassung mit der alten, dann `ausfaelle` Anfragen mit `503 serviceBusy`, dann
///   läuft die neue; `update.state` ist `applying`, danach `boot-pending` (bei
///   `.awup`) oder `idle`, bei `startScheitert` `failed`;
/// - die `insufficientStorage`-Nachricht nennt die fehlenden Megabyte, im Wortlaut
///   nicht gemessen.
extension VirtuelleNGUhr {
    /// Ein Upload darf größer sein als ein gewöhnlicher Rumpf.
    static func rumpfgrenze(methode: String, pfad: String) -> Int {
        methode == "POST" && pfad == "/update" ? (8 << 20) + (4 << 10) : maxRumpf
    }

    private static func kopfAngabe(_ daten: Data, nach: Int) -> [String]? {
        guard daten.count > nach else { return nil }
        let rest = daten.dropFirst(nach).prefix(64)
        guard let ende = rest.firstIndex(of: 0), let text = String(data: rest[rest.startIndex..<ende], encoding: .utf8)
        else { return nil }
        return text.components(separatedBy: "|")
    }

    static func firmwareEinspielen(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        let image = z.firmware.image
        let awup = Firmwarepakete.istAwup(image)
        if z.firmware.einrichtungsmodus { return fehler(403, "forbidden", "not allowed in setup mode") }
        if z.firmware.belegt || z.firmware.ausstehend != nil {
            return fehler(409, "updateBusy", "another update is running")
        }
        guard let teil = dateiteil(a, feld: "firmware") else { return fehler(400, "badRequest", "expected one file") }
        let paket = teil.inhalt
        guard paket.count <= Firmwarepakete.hoechstgroesse(image) else {
            return fehler(413, "payloadTooLarge", "payload too large")
        }
        let ungueltig = awup ? fehler(400, "invalidPackage", "invalid package")
            : fehler(400, "wrongChip", "not a firmware image for this chip")
        guard Firmwarepakete.kopfPasst(paket, dateiname: image),
              let angabe = kopfAngabe(paket, nach: awup ? 8 : 1) else { return ungueltig }
        let neu: String
        if awup {
            guard angabe.count == 2, Firmwareversion(angabe[1]) != nil else { return ungueltig }
            guard angabe[0] == "tc002" else { return fehler(400, "wrongTarget", "package is for another device") }
            neu = angabe[1]
            if let alt = Firmwareversion(z.firmware.fassung), let n = Firmwareversion(neu), n <= alt {
                return fehler(409, "notNewer", "package is not newer than the installed version")
            }
            if paket.count > z.firmware.platz {
                let fehlt = Double(paket.count - z.firmware.platz) / 1_048_576
                return fehler(409, "insufficientStorage",
                              "package is larger than the clock can hold, \(String(format: "%.1f", fehlt)) MB missing")
            }
        } else {
            guard angabe.count == 1, Firmwareversion(angabe[0]) != nil else { return ungueltig }
            neu = angabe[0]
        }
        z.firmware.ausstehend = neu
        z.firmware.altRest = z.firmware.altAntworten
        z.firmware.ausfallRest = z.firmware.ausfaelle
        z.firmware.stand = "applying"
        z.firmware.fehler = ""
        return json(awup ? .objekt(["ok": .bool(true), "applying": .bool(true)]) : .objekt(["ok": .bool(true)]))
    }

    /// Lässt den Neustart nach einem Upload ablaufen. `nil`: Die Anfrage wird
    /// gewöhnlich beantwortet.
    static func neustartVerlauf(_ route: Route, _ z: inout NGUhrzustand) -> Antwort? {
        guard let neu = z.firmware.ausstehend else { return nil }
        var fassungsfrage = false
        switch route {
        case .update: return nil
        case .version, .geraet: fassungsfrage = true
        default: break
        }
        if fassungsfrage, z.firmware.altRest > 0 {
            z.firmware.altRest -= 1
            return nil
        }
        if z.firmware.ausfallRest > 0 {
            z.firmware.ausfallRest -= 1
            return fehler(503, "serviceBusy", "restarting")
        }
        z.firmware.ausstehend = nil
        if z.firmware.startScheitert {
            z.firmware.stand = "failed"
            z.firmware.fehler = "new version failed to start"
        } else {
            z.firmware.fassung = neu
            z.firmware.stand = Firmwarepakete.istAwup(z.firmware.image) ? "boot-pending" : "idle"
        }
        return nil
    }
}
