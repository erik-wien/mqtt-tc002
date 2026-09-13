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
    case abgelehnt(name: String, code: Int, meldung: String)

    public var errorDescription: String? {
        switch self {
        case .nichtErreichbar(let g): return lokf("Die Uhr ist nicht erreichbar: %@ Kam dabei gerade die Frage nach dem Zugriff aufs lokale Netzwerk, bitte erlauben und danach erneut abfragen.", g)
        case .unerwarteteAntwort(let w): return lokf("Die Uhr hat unerwartet geantwortet: %@", w)
        case .httpFehler(let pfad, let code): return lokf("Die Uhr hat einen Fehler gemeldet: %@ (Status %d)", pfad, code)
        case .keinPraefix: return lok("Die Uhr hat kein MQTT-Präfix eingestellt. In Ulanzi Studio unter MQTT eines eintragen und dann erneut abfragen.")
        case .abgelehnt(let name, let code, let meldung):
            return lokf("Die Uhr hat „%@“ abgelehnt: %@ (Code %d)", name, meldung, code)
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

    /// Welche benannten Anzeigen gerade auf der Uhr stehen (§5.7):
    /// `{"apps":["meldung2","meldung5","meldung3"],"count":3}`.
    ///
    /// Der Pfad ist `/api/customList`, **nicht** `/customList` — letzterer
    /// liefert nichts, und das hat uns lange wie ein Mangel der Firmware
    /// ausgesehen.
    ///
    /// Es sind **nur Namen**. Was auf einem Platz steht, verraet die Uhr auch
    /// hierueber nicht; belegt oder frei ist damit Tatsache, der Inhalt bleibt
    /// geraten.
    public func anzeigennamen() throws -> [String] {
        let d = try hole("/api/customList")
        guard let namen = Anzeigen.namenAusAppsFeld(d["apps"]) else {
            throw GeraetFehler.unerwarteteAntwort("/api/customList")
        }
        return namen
    }

    /// Setzt eine benannte Anzeige — dieselbe Nutzlast wie ueber MQTT (§3.1),
    /// nur ueber `POST /api/custom?name=<name>` (§5.6). Die Uhr zeigt sie
    /// sofort und quittiert mit `{"code":200,"message":"ok"}`.
    public func anzeigeSetzen(_ json: String, name: String) throws {
        try _ = anAnzeige("/api/custom", name: name, koerper: Data(json.utf8))
    }

    /// Entfernt eine benannte Anzeige — **mit dem Rumpf `{}`**, nicht mit einem
    /// leeren (§5.6). Ueber MQTT ist es genau umgekehrt: Dort loescht die
    /// **leere** Nutzlast, und `{}` richtet nichts aus. Diese Verwechslung
    /// stand bis zum 13.09.2026 als Firmwaremangel in unserer eigenen Liste.
    public func anzeigeLoeschen(name: String) throws {
        try _ = anAnzeige("/api/custom", name: name, koerper: Data("{}".utf8))
    }

    /// Schaltet auf eine benannte Anzeige um (§5.8). Anders als das
    /// MQTT-Gegenstueck (§3.3) antwortet dieser Weg — und weist einen Namen,
    /// den es nicht gibt, mit `{"code":404,"message":"custom app not found"}`
    /// ab.
    public func umschalten(auf name: String) throws {
        try _ = anAnzeige("/api/switchDiyApp", name: name, koerper: nil)
    }

    /// Der gemeinsame Rumpf der drei: POST auf einen `/api`-Pfad mit dem
    /// Anzeigenamen in der Abfrage.
    ///
    /// **Zwei Fehlerquellen, nicht eine.** Der HTTP-Status faengt `fuehreAus`
    /// ab; die Uhr meldet aber auch im Rumpf einen eigenen `code` — die
    /// gemessene 404 fuer einen unbekannten Namen steht genau dort (§5.8).
    /// Wer nur auf den Status sieht, haelt eine Ablehnung fuer einen Erfolg.
    @discardableResult
    private func anAnzeige(_ pfad: String, name: String, koerper: Data?) throws -> [String: Any] {
        var teile = URLComponents()
        teile.scheme = "http"
        teile.host = host
        teile.path = pfad
        // Nicht von Hand zusammengesetzt: Ein Anzeigename darf alles
        // enthalten, was ein Mensch eintippt, und `URLComponents` kodiert es.
        teile.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = teile.url else { throw GeraetFehler.unerwarteteAntwort(pfad) }
        var anfrage = URLRequest(url: url)
        anfrage.httpMethod = "POST"
        if let koerper {
            anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
            anfrage.httpBody = koerper
        }
        let daten = try fuehreAus(anfrage)
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any] else {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        if let code = woerterbuch["code"] as? Int, code != 200 {
            let meldung = woerterbuch["message"] as? String ?? lok("ohne Begründung")
            throw GeraetFehler.abgelehnt(name: name, code: code, meldung: meldung)
        }
        return woerterbuch
    }

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
            throw GeraetFehler.nichtErreichbar(lok("keine Antwort"))
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
