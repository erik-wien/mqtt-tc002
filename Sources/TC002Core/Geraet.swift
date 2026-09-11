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

    public var errorDescription: String? {
        switch self {
        case .nichtErreichbar(let g): return "Die Uhr ist nicht erreichbar: \(g)"
        case .unerwarteteAntwort(let w): return "Die Uhr hat unerwartet geantwortet: \(w)"
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
        let eingestellt = try mqttEinstellungen().praefix
        let mac = try basis().mac
        guard mac.count >= 4 else { return eingestellt }
        return eingestellt + "_" + String(mac.suffix(4))
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
        guard let objekt = try JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        return objekt
    }

    private func fuehreAus(_ anfrage: URLRequest) throws -> Data {
        var ergebnis: Data?
        var fehler: Error?
        let fertig = DispatchSemaphore(value: 0)
        sitzung.dataTask(with: anfrage) { d, _, f in
            ergebnis = d; fehler = f; fertig.signal()
        }.resume()
        guard fertig.wait(timeout: .now() + 10) == .success else {
            throw GeraetFehler.nichtErreichbar("keine Antwort")
        }
        if let fehler { throw GeraetFehler.nichtErreichbar(fehler.localizedDescription) }
        guard let ergebnis else { throw GeraetFehler.nichtErreichbar("leere Antwort") }
        return ergebnis
    }
}
