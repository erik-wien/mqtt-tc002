import Foundation

public struct Basisdaten: Equatable, Sendable {
    public var mac: String, seriennummer: String, mcuVersion: String, appVersion: String
}

public struct MqttEinstellungen: Equatable, Sendable {
    public var aktiv: Bool, ip: String, port: String, benutzer: String, praefix: String
}

public enum GeraetFehler: Error, LocalizedError {
    case nichtErreichbar(String)
    case unerwarteteAntwort(String)
    case httpFehler(pfad: String, code: Int)
    case keinPraefix

    public var errorDescription: String? {
        switch self {
        case .nichtErreichbar(let g): return lokf("Die Uhr ist nicht erreichbar: %@ Kam dabei gerade die Frage nach dem Zugriff aufs lokale Netzwerk, bitte erlauben und danach erneut abfragen.", g)
        case .unerwarteteAntwort(let w): return lokf("Die Uhr hat unerwartet geantwortet: %@", w)
        case .httpFehler(let pfad, let code): return lokf("Die Uhr hat einen Fehler gemeldet: %@ (Status %d)", pfad, code)
        case .keinPraefix: return lok("Die Uhr hat kein MQTT-Präfix eingestellt. In Ulanzi Studio unter MQTT eines eintragen und dann erneut abfragen.")
        }
    }
}

/// Die HTTP-Schnittstelle der Uhr. Sie ist nirgends dokumentiert; die Endpunkte
/// stammen aus ihrer eigenen Weboberflaeche.
public struct Geraet {
    private let host: String
    private let sitzung: URLSession

    public init(host: String, sitzung: URLSession = .shared) {
        self.host = host; self.sitzung = sitzung
    }

    public func basis() throws -> Basisdaten {
        let d = try hole("/getBase")
        return Basisdaten(mac: d["mac"] as? String ?? "",
                          seriennummer: d["devSn"] as? String ?? "",
                          mcuVersion: d["mcuVer"] as? String ?? "",
                          appVersion: d["appVer"] as? String ?? "")
    }

    public func mqttEinstellungen() throws -> MqttEinstellungen {
        let d = try hole("/getMqttConfig")
        return MqttEinstellungen(aktiv: d["isMqtt"] as? Bool ?? false,
                                 ip: d["ip"] as? String ?? "",
                                 port: d["port"] as? String ?? "1883",
                                 benutzer: d["mqtt_name"] as? String ?? "",
                                 praefix: d["mqtt_prefix"] as? String ?? "")
    }

    /// Das tatsaechliche Themen-Praefix. Die Firmware haengt an das eingestellte
    /// Praefix einen Unterstrich und die letzten vier Stellen der MAC-Adresse.
    public func themenPraefix() throws -> String {
        try praefixUndBasis().praefix
    }

    /// Praefix und Basisdaten in einem Zug. Getrennt geholt wuerde `/getBase`
    /// zweimal abgefragt — einmal fuer das Praefix, einmal fuer die MAC.
    public func praefixUndBasis() throws -> (praefix: String, basis: Basisdaten) {
        let eingestellt = try mqttEinstellungen().praefix
        let b = try basis()
        // Ohne eingestelltes Praefix kaeme hier "_a86b" heraus — ein Thema, auf das
        // die Uhr nie hoert. Lieber sagen, was fehlt, als stumm ins Leere senden.
        guard !eingestellt.isEmpty else { throw GeraetFehler.keinPraefix }
        return (eingestellt + "_" + String(b.mac.suffix(4)), b)
    }

    public func verbunden() throws -> Bool {
        let d = try hole("/getMqttStatus")
        let daten = d["data"] as? [String: Any]
        return daten?["connected"] as? Bool ?? false
    }

    public func konfiguration() throws -> [String: Any] { try hole("/getConfig") }

    /// Liest die vollstaendige Konfiguration, aendert ein Feld und schickt alles
    /// zurueck — die Uhr erwartet das ganze Objekt, nicht nur die Aenderung.
    public func konfigurationSetzen(_ feld: String, _ wert: Any) throws {
        var k = try konfiguration()
        k[feld] = wert
        let koerper = try JSONSerialization.data(withJSONObject: k)
        var anfrage = URLRequest(url: URL(string: "http://\(host)/setConfig")!)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = koerper
        _ = try fuehreAus(anfrage)
    }

    private func hole(_ pfad: String) throws -> [String: Any] {
        let daten = try fuehreAus(URLRequest(url: URL(string: "http://\(host)\(pfad)")!))
        let objekt: Any
        do {
            objekt = try JSONSerialization.jsonObject(with: daten)
        } catch {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        guard let woerterbuch = objekt as? [String: Any] else {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        return woerterbuch
    }

    private func fuehreAus(_ anfrage: URLRequest) throws -> Data {
        var ergebnis: Data?
        var antwort: URLResponse?
        var fehler: Error?
        let fertig = DispatchSemaphore(value: 0)
        sitzung.dataTask(with: anfrage) { d, r, f in
            ergebnis = d; antwort = r; fehler = f; fertig.signal()
        }.resume()
        guard fertig.wait(timeout: .now() + 10) == .success else {
            throw GeraetFehler.nichtErreichbar("keine Antwort")
        }
        if let fehler { throw GeraetFehler.nichtErreichbar(fehler.localizedDescription) }
        let pfad = anfrage.url?.path ?? ""
        if let http = antwort as? HTTPURLResponse, http.statusCode >= 400 {
            throw GeraetFehler.httpFehler(pfad: pfad, code: http.statusCode)
        }
        guard let ergebnis else { throw GeraetFehler.nichtErreichbar("leere Antwort") }
        return ergebnis
    }
}
