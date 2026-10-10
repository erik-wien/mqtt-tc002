import Foundation

public enum GeraetFehler: Error, LocalizedError {
    case nichtErreichbar(String)
    case unerwarteteAntwort(String)
    case httpFehler(pfad: String, code: Int)
    case keinPraefix
    /// Das Praefix der Uhr ist zu lang oder enthaelt Steuerzeichen, `#` oder `+`.
    case ungueltigesPraefix
    /// Die eingetragene Adresse ergibt keine gueltige URL — ein Leerzeichen
    /// genuegt dafuer schon.
    case ungueltigeAdresse(String)
    /// Die AWTRIX NG hat mit ihrem Fehlerrumpf geantwortet. `code` ist
    /// maschinenlesbar und stabil; auf `message` ist nicht zu prüfen.
    case ngAbgewiesen(status: Int, code: String, feld: String?)

    public var errorDescription: String? {
        switch self {
        // Ohne den Hinweis auf die Netzwerkfreigabe: Ob der plausibel ist,
        // weiss nur, wer alle Uhren sieht — melden sich drei von vier, liegt
        // es nicht an der Freigabe. Der Hinweis steht deshalb in der
        // Uhrenliste, und zwar nur, wenn keine einzige geantwortet hat.
        case .nichtErreichbar(let g): return lokf("Die Uhr ist nicht erreichbar: %@", g)
        case .unerwarteteAntwort(let w): return lokf("Die Uhr hat unerwartet geantwortet: %@", w)
        case .httpFehler(let pfad, let code): return lokf("Die Uhr hat einen Fehler gemeldet: %@ (Status %d)", pfad, code)
        case .keinPraefix: return lok("Die Uhr nennt weder ein MQTT-Präfix noch eine Kennung. Erneut abfragen.")
        case .ungueltigesPraefix: return lok("Das MQTT-Präfix der Uhr ist unbrauchbar (zu lang oder mit Steuerzeichen, „#“ oder „+“). In den Einstellungen der Uhr berichtigen.")
        case .ungueltigeAdresse(let a): return lokf("„%@“ ist keine gültige Adresse. In den Einstellungen die Adresse der Uhr berichtigen — ein Leerzeichen genügt schon, damit sie nicht mehr stimmt.", a)
        case .ngAbgewiesen(let status, let code, let feld):
            guard let feld else {
                return lokf("Die AWTRIX NG hat abgewiesen: %@ (Status %d)", code, status)
            }
            return lokf("Die AWTRIX NG hat abgewiesen: %@ im Feld %@ (Status %d)", code, feld, status)
        }
    }
}

/// Die HTTP-Schnittstelle der Uhr (AWTRIX NG, `docs/awtrix-ng-protokoll.md`
/// §4): `PUT` und `DELETE` mit echten Statuscodes und dem Fehlerrumpf
/// `{"error":{"code","message","field"}}`.
public struct Geraet {
    private let host: String
    private let sitzung: URLSession

    public init(host: String, sitzung: URLSession = .shared) {
        self.host = host; self.sitzung = sitzung
    }

    /// Das Themen-Praefix, unter dem die Uhr zuhoert.
    public func themenPraefix() throws -> String {
        try praefixUndBasis().praefix
    }

    /// Praefix, MAC und Anzeigemass in einem Zug: Die Antworten von
    /// `/api/v1/device`, `/api/v1/system` und `/api/v1/capabilities` werden je
    /// einmal geholt.
    ///
    /// Das Praefix ist `mqttPrefix` genau so, wie es dasteht, und nichts wird
    /// angehaengt (`docs/awtrix-ng-protokoll.md` §2). Ist es leer, tritt die
    /// uid an seine Stelle — die zwoelfstellige MAC. Es gibt also keinen Fall
    /// „kein Praefix eingestellt": Eines gibt es immer. Ein falsches waere
    /// dagegen unsichtbar, denn NG antwortet auf ein Thema ohne Route gar
    /// nicht.
    ///
    /// Die `mac` ist die uid der Geraeteauskunft, zwoelf Hexziffern.
    public func praefixUndBasis() throws -> (praefix: String, mac: String, mass: (breite: Int, hoehe: Int)?) {
        let geraet = try hole("/api/v1/device")
        let uid = geraet["uid"] as? String ?? ""
        let system = try hole("/api/v1/system")
        let eingestellt = (system["mqttPrefix"] as? String) ?? ""
        let praefix = eingestellt.isEmpty ? uid : eingestellt
        // Weder ein Praefix noch eine uid: Dann ist das keine AWTRIX, die man
        // ansprechen koennte — und ein leeres Thema waere `/cmd/apps/pushed/x`.
        guard !praefix.isEmpty else { throw GeraetFehler.keinPraefix }
        guard Themenpraefix.gueltig(praefix) else { throw GeraetFehler.ungueltigesPraefix }
        let mass = try? anzeigemass()
        return (praefix, uid, mass ?? nil)
    }

    /// Wie gross die Anzeige ist: `display.width` und `display.height` aus
    /// `GET /api/v1/capabilities` (§1, §7.4). `nil`, wo die Antwort keine
    /// brauchbare Zahl nennt — dann gilt weiter die Vorgabe.
    public func anzeigemass() throws -> (breite: Int, hoehe: Int)? {
        let anzeige = try hole("/api/v1/capabilities")["display"] as? [String: Any]
        guard let b = anzeige?["width"] as? Int, let h = anzeige?["height"] as? Int else { return nil }
        return AwtrixNG.plausiblesMass(breite: b, hoehe: h, maxPixel: anzeige?["maxPixels"] as? Int)
    }

    /// Die Namenslisten dieser Uhr (Effekte, Overlays, Paletten, Übergänge) aus
    /// `GET /api/v1/capabilities`. `nil`, wenn die Antwort keine davon trägt.
    public func faehigkeiten() throws -> Geraetefaehigkeiten? {
        Geraetefaehigkeiten(antwort: try hole("/api/v1/capabilities"))
    }

    /// Was das Display gerade zeigt (`GET /api/v1/display/screen`, §7.3).
    public func bildschirm() throws -> Bildschirmauszug {
        let pfad = "/api/v1/display/screen"
        do {
            return try Bildschirmauszug(daten: try fuehreAus(try anfrage(url(pfad))))
        } catch is Bildschirmauszug.Fehler {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
    }

    public func verbunden() throws -> Bool { try brokerstand().steht }

    /// Ob die Uhr am Broker haengt — und warum nicht.
    ///
    /// Der Grund ist die eigentliche Auskunft: Ein Warndreieck allein sagt
    /// nichts ueber die Ursache, etwa `badCredentials` nach mehreren
    /// Verbindungsversuchen.
    public func brokerstand() throws -> (steht: Bool, grund: String?) {
        // §7.1: Ob das Geraet am Broker haengt und warum nicht, steht unter
        // `mqtt` in der Geraeteauskunft.
        let mqtt = try hole("/api/v1/device")["mqtt"] as? [String: Any]
        let steht = mqtt?["state"] as? String == "connected"
        // `error` ist der laufende, `lastError` der letzte — nach einem
        // Fehlschlag steht in beiden dasselbe, vor dem ersten Versuch in
        // keinem.
        let grund = (mqtt?["error"] as? String) ?? (mqtt?["lastError"] as? String)
        return (steht, steht ? nil : grund)
    }

    /// Welche benannten Anzeigen gerade auf der Uhr stehen.
    ///
    /// `GET /api/v1/apps` nennt das ganze Inventar, je App mit `origin`
    /// (`builtin`, `pushed`, `script`, `module`). Auf `pushed` gefiltert sind
    /// das genau die Anzeigen, die jemand von aussen abgelegt hat.
    ///
    /// Ueber MQTT gibt es das nicht: „Eine Liste aller Anzeigen gibt es ueber
    /// MQTT nicht" (§3.5). Dieser Weg ist der einzige.
    public func anzeigennamen() throws -> [String] {
        try anzeigeninventar().filter(\.vorhanden).map(\.name)
    }

    /// Dasselbe mit `enabled` und `present` je Anzeige, samt Geistereinträgen.
    public func anzeigeninventar() throws -> [Inventareintrag] {
        guard let eintraege = Anzeigen.eintraegeAusNGInventar(try holeFeld("/api/v1/apps")) else {
            throw GeraetFehler.unerwarteteAntwort("/api/v1/apps")
        }
        return eintraege
    }

    /// Setzt eine benannte Anzeige — dieselbe Nutzlast wie ueber MQTT, nur ueber
    /// `PUT /api/v1/apps/pushed/{name}` (§4.2). Der Name kommt aus dem Pfad,
    /// nie aus dem Rumpf, und wird geprueft, bevor die Nutzlast gelesen wird.
    public func anzeigeSetzen(_ json: String, name: String) throws {
        try ngAnfrage("PUT", "/api/v1/apps/pushed/" + ngName(name), koerper: Data(json.utf8))
    }

    /// Entfernt eine benannte Anzeige mit `DELETE /api/v1/apps/{name}`. `{}`
    /// auf `PUT` loescht nicht, sondern antwortet `422` und verweist auf diese
    /// Route; ueber MQTT loescht dagegen die leere Nutzlast.
    public func anzeigeLoeschen(name: String) throws {
        try ngAnfrage("DELETE", "/api/v1/apps/" + ngName(name), koerper: nil)
    }

    /// Schaltet auf eine benannte Anzeige um (`PUT /api/v1/apps/active`). Einen
    /// Namen, den es nicht gibt, weist die Uhr mit `404` ab.
    public func umschalten(auf name: String) throws {
        try ngAnfrage("PUT", "/api/v1/apps/active",
                      koerper: Data(NGNutzlast.umschalten(auf: name).utf8))
    }

    /// Reiht eine Benachrichtigung ein (`POST /api/v1/notifications`, §5.6). Der
    /// Name steht im Rumpf; `409`-artige Fälle gibt es hier nicht, eine volle
    /// Warteschlange (32) ist `507`.
    public func benachrichtigen(_ json: String) throws {
        try ngAnfrage("POST", "/api/v1/notifications", koerper: Data(json.utf8))
    }

    /// Nimmt die sichtbare Benachrichtigung weg (`DELETE …/notifications/active`,
    /// immer `200`) oder die benannte, auch eine wartende (`404`, wenn keine so heißt).
    public func benachrichtigungZurueckziehen(name: String?) throws {
        try ngAnfrage("DELETE", "/api/v1/notifications/" + (name.map(ngName) ?? "active"), koerper: nil)
    }

    /// Schaltet eine Anzeige ein oder aus (`PUT /api/v1/apps/{name}/enabled`,
    /// Rumpf `true`/`false`). Eine abgeschaltete App behält ihren Platz in der Schleife.
    public func anzeigeSchalten(name: String, an: Bool) throws {
        try ngAnfrage("PUT", "/api/v1/apps/" + ngName(name) + "/enabled",
                      koerper: Data((an ? "true" : "false").utf8))
    }

    /// Eine Anzeige vor oder zurück (`POST /api/v1/apps/next` bzw. `/previous`).
    public func blaettern(vor: Bool) throws {
        try ngAnfrage("POST", "/api/v1/apps/" + (vor ? "next" : "previous"), koerper: nil)
    }

    /// Startet die Uhr neu (`POST /api/v1/device/reboot`, §4.2).
    ///
    /// Die Doku nennt keine Antwort. Eine Uhr, die sofort neu startet, kann die
    /// Verbindung kappen, bevor die Antwort draußen ist; eine abgebrochene
    /// Verbindung oder eine ausbleibende Antwort gilt darum als angenommen.
    /// Eine Abweisung (Statuscode ab 400) und eine Uhr, die gar nicht erst
    /// verbindet, bleiben Fehler.
    public func neustarten() throws {
        try ngAnfrage("POST", "/api/v1/device/reboot", koerper: nil, abbruchGilt: true)
    }

    /// Ein Anzeigenname im Pfad. `[A-Za-z0-9_-]{1,32}` ist alles, was NG
    /// annimmt (§8) — was daneben liegt, wird trotzdem kodiert statt von Hand
    /// eingesetzt, sonst zerlegte ein Schraegstrich im Namen die Route.
    /// `/` bleibt in `.urlPathAllowed` stehen und wird deshalb ausgenommen.
    static func ngName(_ name: String) -> String {
        name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(["/"])) ?? name
    }

    private func ngName(_ name: String) -> String { Self.ngName(name) }

    /// Eine Anfrage an die Schnittstelle von AWTRIX NG.
    ///
    /// Echte Statuscodes und ein einheitlicher Fehlerrumpf
    /// `{"error":{"code","message","field"}}` (§4.1). Gelesen wird daraus
    /// `code` — `message` ist englische Prosa fuer Menschen.
    ///
    /// `Content-Type: application/json` ist bei `PUT` Pflicht: Ohne ihn wird
    /// die Anfrage abgewiesen, bevor der Rumpf ueberhaupt gelesen wird.
    @discardableResult
    func ngAnfrage(_ methode: String, _ pfad: String, koerper: Data?,
                   inhaltsart: String = "application/json", frist: TimeInterval = 10,
                   abbruchGilt: Bool = false) throws -> Data {
        try ngAntwort(methode, pfad, koerper: koerper, inhaltsart: inhaltsart, frist: frist,
                      abbruchGilt: abbruchGilt).daten
    }

    /// Wie `ngAnfrage`, mit dem Statuscode der Antwort (`201` und `200` unterscheiden
    /// bei Melodien neu und ersetzt).
    func ngAntwort(_ methode: String, _ pfad: String, koerper: Data?,
                   inhaltsart: String = "application/json", frist: TimeInterval = 10,
                   abbruchGilt: Bool = false) throws -> (daten: Data, status: Int) {
        var anfrage = try self.anfrage(url(pfad))
        anfrage.httpMethod = methode
        if let koerper {
            anfrage.setValue(inhaltsart, forHTTPHeaderField: "Content-Type")
            anfrage.httpBody = koerper
        }
        anfrage.timeoutInterval = max(frist, 60)
        let (daten, status) = try fuehreAusMitStatus(anfrage, frist: frist, abbruchGilt: abbruchGilt)
        guard status >= 400 else { return (daten, status) }
        let rumpf = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
        let fehler = rumpf?["error"] as? [String: Any]
        let feld = fehler?["field"] as? String
        throw GeraetFehler.ngAbgewiesen(status: status,
                                        code: fehler?["code"] as? String ?? lok("ohne Begründung"),
                                        feld: (feld?.isEmpty ?? true) ? nil : feld)
    }

    /// Taugt diese Adresse überhaupt für eine Anfrage? — dieselbe Prüfung,
    /// die `url(_:)` zur Sendezeit macht, nur früher.
    ///
    /// Die Oberfläche kann damit beim Eintragen sagen, dass etwas nicht
    /// stimmt, statt es beim Senden als Fenster vorzuwerfen. Ein leerer Host
    /// ist dabei der Fall, den `URL(string:)` nicht fängt:
    /// `http:///api/v1/apps` ist eine gültige URL, die nirgendwohin zeigt.
    public static func adresseTaugt(_ host: String) -> Bool {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !host.contains(where: { "@/?#\\".contains($0) }),
              let url = URL(string: "http://\(host)/") else { return false }
        return !(url.host ?? "").isEmpty
    }

    /// Die Web-Oberfläche dieser Uhr — für den Knopf „Konfigurieren" in
    /// den Einstellungen. Beide Firmwares bringen eine mit, und alles, was
    /// diese App nicht einstellt (WLAN, Helligkeit, die eingebauten Anzeigen,
    /// bei NG der Broker samt Präfix), wird dort eingestellt.
    ///
    /// `nil` heißt: Daraus wird keine Adresse, hier gehört kein Knopf hin.
    /// Ein leerer Host ist der wichtigste Fall — `URL(string: "http://")`
    /// liefert brav eine URL, nur zeigt die nirgendwohin (siehe die
    /// Anmerkung bei `url(_:)` darunter). Deshalb wird zusätzlich geprüft,
    /// dass wirklich ein Rechnername darin steht.
    ///
    /// Wer selbst ein Schema einträgt („https://uhr.lan"), behält es; ohne
    /// eines wird `http://` vorangestellt — die Uhren sprechen im Hausnetz
    /// kein TLS.
    public static func weboberflaeche(host: String) -> URL? {
        let sauber = host.trimmingCharacters(in: .whitespaces)
        guard !sauber.isEmpty else { return nil }
        let mitSchema = sauber.contains("://") ? sauber : "http://" + sauber
        guard let url = URL(string: mitSchema), !(url.host ?? "").isEmpty else { return nil }
        return url
    }

    /// Jede Anfrage an die Uhr umgeht den lokalen Zwischenspeicher: Eine dort
    /// liegende Weiterleitung oder Antwort einer frueheren Firmware wuerde still
    /// befolgt, und Geraetezustand ist eine Momentaufnahme.
    private func anfrage(_ url: URL) -> URLRequest {
        URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    }

    /// Die einzige Stelle, an der aus Adresse und Pfad eine URL wird.
    ///
    /// Ein Leerzeichen in der eingetragenen Adresse laesst
    /// `URL(string:)` `nil` liefern; ein `!` dahinter macht daraus einen
    /// Absturz statt einer Meldung. Ein *leerer* Host tut das nicht — gemessen:
    /// `http:///api/v1/apps` ist eine gueltige URL.
    ///
    /// Eine Adresse kommt aus den Einstellungen, ist also von Hand eingetippt.
    /// Auf solche Eingaben gehoert kein `!`.
    private func url(_ pfad: String) throws -> URL {
        // Ein `@`, `/`, `?` oder `#` im Host machte aus „x@fremd/“ eine Anfrage
        // an einen anderen Rechner als den eingetragenen.
        guard !host.contains(where: { "@/?#\\".contains($0) }),
              let url = URL(string: "http://\(host)\(pfad)") else {
            throw GeraetFehler.ungueltigeAdresse(host)
        }
        return url
    }

    /// Wie `hole`, nur fuer eine Antwort, die oben ein Feld ist statt eines
    /// Objekts — `GET /api/v1/apps` ist die einzige, die diese App liest.
    private func holeFeld(_ pfad: String) throws -> [Any] {
        let daten = try fuehreAus(try anfrage(url(pfad)))
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let feld = objekt as? [Any] else {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        return feld
    }

    /// Der Rumpf einer `GET`-Antwort, ungelesen.
    func lesen(_ pfad: String) throws -> Data {
        try fuehreAus(try anfrage(url(pfad)))
    }

    func hole(_ pfad: String) throws -> [String: Any] {
        let daten = try fuehreAus(try anfrage(url(pfad)))
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

    /// Der Fehlerstatus wird hier zum Fehler — fuer jeden Aufrufer, der den
    /// Rumpf einer abgewiesenen Antwort nicht braucht.
    private func fuehreAus(_ anfrage: URLRequest) throws -> Data {
        let (daten, status) = try fuehreAusMitStatus(anfrage)
        if status >= 400 {
            throw GeraetFehler.httpFehler(pfad: anfrage.url?.path ?? "", code: status)
        }
        return daten
    }

    /// Dasselbe, aber mit dem Status statt eines Fehlers daraus.
    ///
    /// Fuer AWTRIX NG unentbehrlich: Dort steht die Begruendung im Rumpf
    /// einer Antwort mit Fehlerstatus, und wer den Status vorher zum Fehler
    /// macht, wirft die Begruendung weg und meldet „Status 422" statt
    /// „validationFailed im Feld durationMs".
    ///
    /// `abbruchGilt`: Eine Verbindung, die nach dem Senden abreißt, oder eine
    /// Antwort, die ausbleibt, ist dann kein Fehler (`neustarten`). Wer gar nicht
    /// erst verbindet, ist es weiterhin.
    private func fuehreAusMitStatus(_ anfrage: URLRequest, frist: TimeInterval = 10,
                                    abbruchGilt: Bool = false) throws -> (Data, Int) {
        var ergebnis: Data?
        var antwort: URLResponse?
        var fehler: Error?
        let fertig = DispatchSemaphore(value: 0)
        sitzung.dataTask(with: anfrage) { d, r, f in
            ergebnis = d; antwort = r; fehler = f; fertig.signal()
        }.resume()
        guard fertig.wait(timeout: .now() + frist) == .success else {
            if abbruchGilt { return (Data(), 200) }
            throw GeraetFehler.nichtErreichbar(lok("keine Antwort"))
        }
        if let fehler {
            let abgerissen: Set<URLError.Code> = [.networkConnectionLost, .timedOut, .badServerResponse,
                                                  .cannotParseResponse, .zeroByteResource]
            if abbruchGilt, let code = (fehler as? URLError)?.code, abgerissen.contains(code) {
                return (Data(), 200)
            }
            throw GeraetFehler.nichtErreichbar(fehler.localizedDescription)
        }
        guard let ergebnis else { throw GeraetFehler.nichtErreichbar("leere Antwort") }
        // Die Antworten, die diese App liest, sind wenige KiB gross.
        guard ergebnis.count <= 1 << 20 else { throw GeraetFehler.nichtErreichbar("Antwort zu gross") }
        return (ergebnis, (antwort as? HTTPURLResponse)?.statusCode ?? 200)
    }
}
