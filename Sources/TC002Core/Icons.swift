import Foundation

public struct Icon: Equatable, Sendable {
    public var nummer: String, name: String, kategorie: String
    public var datei: URL
    public init(nummer: String, name: String, kategorie: String, datei: URL) {
        self.nummer = nummer; self.name = name; self.kategorie = kategorie; self.datei = datei
    }
}

public enum IconFehler: Error, LocalizedError {
    case nichtLesbar(String)
    case nichtGefunden(String)

    public var errorDescription: String? {
        switch self {
        case .nichtLesbar(let n): return "Das Icon \(n) lässt sich nicht lesen."
        case .nichtGefunden(let n): return "Für die Nummer \(n) gibt es bei LaMetric kein Icon."
        }
    }
}

/// Die 8×8-Icons. Mitgeliefert im Ordner `Icons/`, erweiterbar ueber LaMetric-Nummern.
public struct Iconsammlung {
    private let ordner: URL

    public init(ordner: URL) { self.ordner = ordner }

    public func alle() -> [Icon] {
        let namen = geladeneNamen()
        let dateien = (try? FileManager.default.contentsOfDirectory(at: ordner,
                       includingPropertiesForKeys: nil)) ?? []
        return dateien
            .filter { ["gif", "png", "jpg"].contains($0.pathExtension.lowercased()) }
            .map { datei in
                let nummer = datei.deletingPathExtension().lastPathComponent
                let eintrag = namen[nummer]
                return Icon(nummer: nummer,
                            name: eintrag?.0 ?? nummer,
                            kategorie: eintrag?.1 ?? "",
                            datei: datei)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func datenURI(fuer icon: Icon) throws -> String {
        guard let daten = try? Data(contentsOf: icon.datei) else {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
        let typ: String
        switch icon.datei.pathExtension.lowercased() {
        case "png": typ = "image/png"
        case "jpg", "jpeg": typ = "image/jpeg"
        default: typ = "image/gif"
        }
        return "data:\(typ);base64," + daten.base64EncodedString()
    }

    /// Holt ein Icon ueber seine LaMetric-Nummer: erst das Bild, dann Name und
    /// Kategorie. Beides ohne Anmeldung erreichbar. Schlaegt nur die Namensabfrage
    /// fehl, bleibt das Icon trotzdem bestehen, dann eben mit der Nummer als Namen.
    public func holen(nummer: String, sitzung: URLSession = .shared) throws -> Icon {
        let bildURL = URL(string: "https://developer.lametric.com/content/apps/icon_thumbs/\(nummer)")!
        let bild = try fuehreAus(URLRequest(url: bildURL), sitzung: sitzung, nummer: nummer)
        guard bild.count > 16 else {
            throw IconFehler.nichtGefunden(nummer)
        }
        let ziel = ordner.appendingPathComponent("\(nummer).gif")
        try bild.write(to: ziel, options: .atomic)

        var name = nummer, kategorie = ""
        let infoURL = URL(string: "https://developer.lametric.com/api/v1/dev/preloadicons?icon_id=\(nummer)")!
        if let info = try? fuehreAus(URLRequest(url: infoURL), sitzung: sitzung, nummer: nummer),
           let objekt = try? JSONSerialization.jsonObject(with: info) as? [String: Any] {
            name = objekt["name"] as? String ?? nummer
            kategorie = objekt["category_name"] as? String ?? ""
        }
        namenErgaenzen(nummer: nummer, name: name, kategorie: kategorie)
        return Icon(nummer: nummer, name: name, kategorie: kategorie, datei: ziel)
    }

    /// Fuehrt eine Anfrage synchron ueber die uebergebene Sitzung aus, mit zehn
    /// Sekunden Frist. Ein Fehler, eine ueberschrittene Frist oder ein HTTP-Fehlercode
    /// zaehlen hier allesamt als "nicht gefunden" — LaMetric antwortet auf unbekannte
    /// Nummern nicht einheitlich.
    private func fuehreAus(_ anfrage: URLRequest, sitzung: URLSession, nummer: String) throws -> Data {
        var ergebnis: Data?
        var antwort: URLResponse?
        var netzwerkFehler: Error?
        let fertig = DispatchSemaphore(value: 0)
        sitzung.dataTask(with: anfrage) { d, r, f in
            ergebnis = d; antwort = r; netzwerkFehler = f; fertig.signal()
        }.resume()
        guard fertig.wait(timeout: .now() + 10) == .success else {
            throw IconFehler.nichtGefunden(nummer)
        }
        if netzwerkFehler != nil {
            throw IconFehler.nichtGefunden(nummer)
        }
        if let http = antwort as? HTTPURLResponse, http.statusCode >= 400 {
            throw IconFehler.nichtGefunden(nummer)
        }
        guard let ergebnis else { throw IconFehler.nichtGefunden(nummer) }
        return ergebnis
    }

    private func namenDatei() -> URL { ordner.appendingPathComponent("names.json") }

    private func geladeneNamen() -> [String: (String, String)] {
        guard let daten = try? Data(contentsOf: namenDatei()),
              let liste = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return [:] }
        var tabelle: [String: (String, String)] = [:]
        for e in liste {
            if let n = e["nummer"] { tabelle[n] = (e["name"] ?? n, e["kategorie"] ?? "") }
        }
        return tabelle
    }

    private func namenErgaenzen(nummer: String, name: String, kategorie: String) {
        var liste: [[String: String]] = []
        if let daten = try? Data(contentsOf: namenDatei()),
           let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]] {
            liste = vorhanden.filter { $0["nummer"] != nummer }
        }
        liste.append(["nummer": nummer, "name": name, "kategorie": kategorie])
        if let daten = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? daten.write(to: namenDatei())
        }
    }
}
