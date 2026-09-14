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
    /// Die eingetragene Adresse ergibt keine gueltige URL — ein Leerzeichen
    /// genuegt dafuer schon.
    case ungueltigeAdresse(String)
    case abgelehnt(name: String, code: Int, meldung: String)
    /// Die Schnittstelle verlangt eine Anmeldung (`authEnabled`, AWTRIX NG
    /// § 4.1). Dann ist nicht einmal die Geräteart festzustellen — deshalb ein
    /// eigener Fall und nicht bloß ein Status: Der Ausweg ist die Wahl von
    /// Hand, und das gehört gesagt.
    case anmeldungNoetig
    /// Die AWTRIX NG hat mit ihrem Fehlerrumpf geantwortet. `code` ist
    /// maschinenlesbar und stabil; auf `message` ist nicht zu prüfen.
    case ngAbgewiesen(status: Int, code: String, feld: String?)

    public var errorDescription: String? {
        switch self {
        case .nichtErreichbar(let g): return lokf("Die Uhr ist nicht erreichbar: %@ Kam dabei gerade die Frage nach dem Zugriff aufs lokale Netzwerk, bitte erlauben und danach erneut abfragen.", g)
        case .unerwarteteAntwort(let w): return lokf("Die Uhr hat unerwartet geantwortet: %@", w)
        case .httpFehler(let pfad, let code): return lokf("Die Uhr hat einen Fehler gemeldet: %@ (Status %d)", pfad, code)
        case .keinPraefix: return lok("Die Uhr hat kein MQTT-Präfix eingestellt. In Ulanzi Studio unter MQTT eines eintragen und dann erneut abfragen.")
        case .ungueltigeAdresse(let a): return lokf("„%@“ ist keine gültige Adresse. In den Einstellungen die Adresse der Uhr berichtigen — ein Leerzeichen genügt schon, damit sie nicht mehr stimmt.", a)
        case .abgelehnt(let name, let code, let meldung):
            return lokf("Die Uhr hat „%@“ abgelehnt: %@ (Code %d)", name, meldung, code)
        case .anmeldungNoetig:
            return lok("Die Uhr verlangt eine Anmeldung. Die App kann so nicht einmal feststellen, was für ein Gerät antwortet — die Geräteart unter „Einstellungen“ von Hand wählen.")
        case .ngAbgewiesen(let status, let code, let feld):
            guard let feld else {
                return lokf("Die AWTRIX NG hat abgewiesen: %@ (Status %d)", code, status)
            }
            return lokf("Die AWTRIX NG hat abgewiesen: %@ im Feld %@ (Status %d)", code, feld, status)
        }
    }
}

/// Die HTTP-Schnittstelle der Uhr.
///
/// **Zwei Firmwares, eine Schnittstelle nach aussen.** Die der Werksfirmware
/// ist nirgends dokumentiert; ihre Endpunkte stammen aus deren eigener
/// Weboberflaeche (`docs/tc002-protokoll.md` §5). Die der AWTRIX NG ist
/// dokumentiert und voellig anders geschnitten — andere Pfade, andere
/// Methoden, andere Fehlerform (`docs/awtrix-ng-protokoll.md` §4).
///
/// Welche antwortet, entscheidet `typ`. Wer ihn falsch setzt, bekommt keine
/// falsche Antwort, sondern gar keine: Die Pfade der einen gibt es bei der
/// anderen nicht. Ermittelt wird er deshalb einmal ueber `erkannteArt()` und
/// danach in der Uhr gefuehrt, statt bei jedem Aufruf geraten zu werden.
public struct Geraet {
    private let host: String
    private let sitzung: URLSession
    /// Welche Firmware hier antwortet. Vorgabe `.tc002` — jeder Aufrufer, der
    /// nichts davon weiss, meint die Werksfirmware, und das war bis heute
    /// jeder.
    public let typ: Geraetetyp

    public init(host: String, sitzung: URLSession = .shared, typ: Geraetetyp = .tc002) {
        self.host = host; self.sitzung = sitzung; self.typ = typ
    }

    /// Was fuer ein Geraet unter dieser Adresse antwortet.
    ///
    /// **Eine Frage, eine Antwort:** `GET /api/v1/device` gibt es nur bei
    /// AWTRIX NG, und nur dort steht `boardType` darin. Alles andere — ein
    /// 404, die Weboberflaeche, irgendein JSON ohne dieses Feld — ist keine
    /// NG-Antwort und damit die Werksfirmware.
    ///
    /// Zwei Faelle werden ausdruecklich **nicht** geraten, sondern gemeldet:
    ///
    /// - Es antwortet gar nichts. Daraus „TC002" zu machen hiesse, eine
    ///   ausgeschaltete AWTRIX beim naechsten Abfragen zur Ulanzi zu erklaeren.
    /// - Es antwortet `401`. NG kann seine ganze Schnittstelle hinter eine
    ///   Anmeldung stellen (§4.1); dann ist der Typ nicht festzustellen, und
    ///   der Ausweg ist die Wahl von Hand.
    /// **Jede Antwort ist eine Feststellung, jedes Ausbleiben ein Fehler.**
    ///
    /// NG kennt `/api/v1/device` und legt dort `boardType` hinein. Alles
    /// andere — ein `404`, eine Weboberflaeche in HTML, ein JSON ohne das Feld
    /// — beantwortet die Frage ebenso: Das Geraet antwortet, und es ist keine
    /// NG. Am 14.09.2026 habe ich daraus kurzzeitig ein `Optional` gemacht,
    /// um „nicht feststellbar" auszudruecken; `testEineAntwortOhneBoardTypeIst
    /// DieWerksfirmware` hat gezeigt, dass es diesen Fall kaum gibt und die
    /// Unterscheidung nur Entschlusskraft kostet.
    ///
    /// Drei Ausnahmen, und die werfen:
    ///
    /// - **nicht erreichbar** — gar keine Antwort, also kein Befund;
    /// - **401** — NG kann die ganze Schnittstelle hinter eine Anmeldung
    ///   stellen; „also eine TC002" waere die falsche Antwort auf eine Frage,
    ///   die nicht beantwortet wurde;
    /// - **ungueltige Adresse** — daran ist nichts festzustellen, und sie
    ///   stillschweigend zur Werksfirmware zu erklaeren verdeckte den
    ///   eigentlichen Fehler.
    public func erkannteArt() throws -> Geraetetyp {
        do {
            return try hole("/api/v1/device")["boardType"] is String ? .awtrixNG : .tc002
        } catch GeraetFehler.nichtErreichbar(let grund) {
            throw GeraetFehler.nichtErreichbar(grund)
        } catch GeraetFehler.httpFehler(_, let code) where code == 401 {
            throw GeraetFehler.anmeldungNoetig
        } catch GeraetFehler.ungueltigeAdresse(let adresse) {
            throw GeraetFehler.ungueltigeAdresse(adresse)
        } catch {
            return .tc002
        }
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
    /// `breite` ist die Anzeigenbreite in Pixeln und **nur bei AWTRIX NG eine
    /// Frage** — die Werksfirmware ist fest 52×16. Sie faellt hier mit an, weil
    /// sie in derselben Antwort steht: getrennt geholt waere `/api/v1/system`
    /// ein zweites Mal abgefragt, genau der Fehler, den dieser Aufruf fuer
    /// `/getBase` vermeidet.
    public func praefixUndBasis() throws -> (praefix: String, basis: Basisdaten, breite: Int?) {
        guard typ == .tc002 else { return try ngPraefixUndBasis() }
        let eingestellt = try mqttEinstellungen().praefix
        let b = try basis()
        // Ohne eingestelltes Praefix kaeme hier "_a86b" heraus — ein Thema, auf das
        // die Uhr nie hoert. Lieber sagen, was fehlt, als stumm ins Leere senden.
        guard !eingestellt.isEmpty else { throw GeraetFehler.keinPraefix }
        return (eingestellt + "_" + String(b.mac.suffix(4)), b, nil)
    }

    /// Dasselbe fuer AWTRIX NG — und **hier wird nichts angehaengt**.
    ///
    /// Das ist der gefaehrlichste Unterschied der beiden Firmwares. Die
    /// Werksfirmware haengt `_` und die letzten vier Stellen der MAC an ihr
    /// eingestelltes Praefix; NG nimmt `mqttPrefix` genau so, wie es dasteht
    /// (`docs/awtrix-ng-protokoll.md` §2). Liefe die Formel der Werksfirmware
    /// auch hier, schriebe die App auf ein Thema, das kein Geraet abonniert —
    /// und NG antwortet auf ein Thema ohne Route **gar nicht**: kein Fehler,
    /// keine Bestaetigung, ein gruener Bau und eine dunkle Uhr.
    ///
    /// Ist `mqttPrefix` leer, tritt die uid an seine Stelle — die zwoelfstellige
    /// MAC. Es gibt also, anders als bei der Werksfirmware, keinen Fall „kein
    /// Praefix eingestellt": Eines gibt es immer.
    ///
    /// `Basisdaten` ist die Form der Werksfirmware und passt nicht Feld fuer
    /// Feld. Gelesen wird davon ohnehin nur `mac`; die uebrigen drei tragen,
    /// was bei NG an derselben Stelle steht, damit sie nicht leer bleiben.
    private func ngPraefixUndBasis() throws -> (praefix: String, basis: Basisdaten, breite: Int?) {
        let geraet = try hole("/api/v1/device")
        let uid = geraet["uid"] as? String ?? ""
        let system = try hole("/api/v1/system")
        let eingestellt = (system["mqttPrefix"] as? String) ?? ""
        let praefix = eingestellt.isEmpty ? uid : eingestellt
        // Weder ein Praefix noch eine uid: Dann ist das keine AWTRIX, die man
        // ansprechen koennte — und ein leeres Thema waere `/cmd/apps/pushed/x`.
        guard !praefix.isEmpty else { throw GeraetFehler.keinPraefix }
        return (praefix,
                Basisdaten(mac: uid,
                           seriennummer: geraet["hostname"] as? String ?? "",
                           mcuVersion: geraet["soc"] as? String ?? "",
                           appVersion: geraet["version"] as? String ?? ""),
                Self.ngBreite(aus: system))
    }

    /// Wie breit die Anzeige dieser AWTRIX ist: `panelWidth × panels`.
    ///
    /// **Geholt und nicht angenommen.** Die Hoehe ist fest 8, die Breite muss
    /// zwischen 32 und 128 liegen (§1) — eine 64er oder 128er Kette ist
    /// vorgesehen, und eine App, die 32 einprogrammiert, zeigte dort das
    /// falsche Bild. Was ausserhalb des Bereichs steht, gilt als nicht
    /// beantwortet (`nil`): Das Geraet weist solche Werte selbst ab, ein
    /// gelesener Ausreisser ist also keine Breite, sondern ein Missverstaendnis.
    public static func ngBreite(aus system: [String: Any]) -> Int? {
        guard let panelWidth = system["panelWidth"] as? Int else { return nil }
        let panels = system["panels"] as? Int ?? 1
        let breite = panelWidth * panels
        return Geraetetyp.ngBreitenbereich.contains(breite) ? breite : nil
    }

    public func verbunden() throws -> Bool {
        guard typ == .tc002 else {
            // §7.1: Ob das Geraet am Broker haengt und warum nicht, steht unter
            // `mqtt` in der Geraeteauskunft. Ein eigener Endpunkt dafuer wie
            // `/getMqttStatus` existiert bei NG nicht.
            let mqtt = try hole("/api/v1/device")["mqtt"] as? [String: Any]
            return mqtt?["state"] as? String == "connected"
        }
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
        guard typ == .tc002 else { return try ngAnzeigennamen() }
        let d = try hole("/api/customList")
        guard let namen = Anzeigen.namenAusAppsFeld(d["apps"]) else {
            throw GeraetFehler.unerwarteteAntwort("/api/customList")
        }
        return namen
    }

    /// Dasselbe fuer AWTRIX NG — und **genauer als bei der Werksfirmware**.
    ///
    /// `GET /api/v1/apps` nennt das ganze Inventar, je App mit `origin`
    /// (`builtin`, `pushed`, `script`, `module`). Auf `pushed` gefiltert sind
    /// das genau die Anzeigen, die jemand von aussen abgelegt hat — die
    /// Werksfirmware kann eigene und eingebaute Anzeigen gar nicht
    /// auseinanderhalten.
    ///
    /// Ueber MQTT gibt es das nicht: „Eine Liste aller Anzeigen gibt es ueber
    /// MQTT nicht" (§3.5). Dieser Weg ist der einzige.
    private func ngAnzeigennamen() throws -> [String] {
        guard let namen = Anzeigen.namenAusNGInventar(try holeFeld("/api/v1/apps")) else {
            throw GeraetFehler.unerwarteteAntwort("/api/v1/apps")
        }
        return namen
    }

    /// Setzt eine benannte Anzeige — dieselbe Nutzlast wie ueber MQTT (§3.1),
    /// nur ueber `POST /api/custom?name=<name>` (§5.6). Die Uhr zeigt sie
    /// sofort und quittiert mit `{"code":200,"message":"ok"}`.
    public func anzeigeSetzen(_ json: String, name: String) throws {
        guard typ == .tc002 else {
            // §5: Der Name kommt aus dem Pfad, nie aus dem Rumpf, und wird
            // geprueft, bevor die Nutzlast gelesen wird.
            try ngAnfrage("PUT", "/api/v1/apps/pushed/" + ngName(name), koerper: Data(json.utf8))
            return
        }
        try _ = anAnzeige("/api/custom", name: name, koerper: Data(json.utf8))
    }

    /// Entfernt eine benannte Anzeige — **mit dem Rumpf `{}`**, nicht mit einem
    /// leeren (§5.6). Ueber MQTT ist es genau umgekehrt: Dort loescht die
    /// **leere** Nutzlast, und `{}` richtet nichts aus. Diese Verwechslung
    /// stand bis zum 13.09.2026 als Firmwaremangel in unserer eigenen Liste.
    public func anzeigeLoeschen(name: String) throws {
        guard typ == .tc002 else {
            // Bei NG ist es **wieder umgekehrt**: `{}` auf `PUT` loescht dort
            // gerade nicht, sondern antwortet `422` und verweist auf diese
            // Route hier. Ueber MQTT loescht bei NG dagegen genau das, was auch
            // bei der Werksfirmware loescht — die leere Nutzlast.
            try ngAnfrage("DELETE", "/api/v1/apps/" + ngName(name), koerper: nil)
            return
        }
        try _ = anAnzeige("/api/custom", name: name, koerper: Data("{}".utf8))
    }

    /// Schaltet auf eine benannte Anzeige um (§5.8). Anders als das
    /// MQTT-Gegenstueck (§3.3) antwortet dieser Weg — und weist einen Namen,
    /// den es nicht gibt, mit `{"code":404,"message":"custom app not found"}`
    /// ab.
    public func umschalten(auf name: String) throws {
        guard typ == .tc002 else {
            try ngAnfrage("PUT", "/api/v1/apps/active",
                          koerper: Data(NGNutzlast.umschalten(auf: name).utf8))
            return
        }
        try _ = anAnzeige("/api/switchDiyApp", name: name, koerper: nil)
    }

    /// Ein Anzeigenname im Pfad. `[A-Za-z0-9_-]{1,32}` ist alles, was NG
    /// annimmt (§8) — was daneben liegt, wird trotzdem kodiert statt von Hand
    /// eingesetzt, sonst zerlegte ein Schraegstrich im Namen die Route.
    private func ngName(_ name: String) -> String {
        name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
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
        var anfrage = URLRequest(url: try url("/setConfig"))
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = koerper
        _ = try fuehreAus(anfrage)
    }

    /// Eine Anfrage an die Schnittstelle von AWTRIX NG.
    ///
    /// **Andere Methoden und eine andere Fehlerform.** Wo die Werksfirmware
    /// alles mit `POST` erledigt und ihre Ablehnung im Rumpf einer `200`
    /// versteckt, benutzt NG `PUT` und `DELETE` und antwortet mit einem echten
    /// Status und einem einheitlichen Rumpf
    /// `{"error":{"code","message","field"}}` (§4.1). Gelesen wird daraus
    /// `code` — `message` ist englische Prosa fuer Menschen.
    ///
    /// `Content-Type: application/json` ist bei `PUT` Pflicht: Ohne ihn wird
    /// die Anfrage abgewiesen, **bevor** der Rumpf ueberhaupt gelesen wird.
    private func ngAnfrage(_ methode: String, _ pfad: String, koerper: Data?) throws {
        var anfrage = URLRequest(url: try url(pfad))
        anfrage.httpMethod = methode
        if let koerper {
            anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
            anfrage.httpBody = koerper
        }
        let (daten, status) = try fuehreAusMitStatus(anfrage)
        guard status >= 400 else { return }
        let rumpf = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
        let fehler = rumpf?["error"] as? [String: Any]
        let feld = fehler?["field"] as? String
        throw GeraetFehler.ngAbgewiesen(status: status,
                                        code: fehler?["code"] as? String ?? lok("ohne Begründung"),
                                        feld: (feld?.isEmpty ?? true) ? nil : feld)
    }

    /// **Die einzige Stelle, an der aus Adresse und Pfad eine URL wird.**
    ///
    /// Vorher stand an drei Stellen `URL(string: …)!`, und am 14.09.2026 hat
    /// genau das die iPad-Fassung umgebracht: Ein **Leerzeichen** in der
    /// eingetragenen Adresse laesst `URL(string:)` `nil` liefern, und das
    /// Ausrufezeichen dahinter macht daraus einen Absturz statt einer Meldung.
    /// (Ein *leerer* Host tut das uebrigens nicht — `http:///api/v1/apps` ist
    /// eine gueltige URL. Nachgemessen, nicht vermutet.)
    ///
    /// Eine Adresse kommt aus den Einstellungen, ist also von Hand eingetippt.
    /// Auf solche Eingaben gehoert kein `!`.
    private func url(_ pfad: String) throws -> URL {
        guard let url = URL(string: "http://\(host)\(pfad)") else {
            throw GeraetFehler.ungueltigeAdresse(host)
        }
        return url
    }

    /// Wie `hole`, nur fuer eine Antwort, die oben ein **Feld** ist statt eines
    /// Objekts — `GET /api/v1/apps` ist die einzige, die diese App liest.
    private func holeFeld(_ pfad: String) throws -> [Any] {
        let daten = try fuehreAus(URLRequest(url: try url(pfad)))
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let feld = objekt as? [Any] else {
            throw GeraetFehler.unerwarteteAntwort(pfad)
        }
        return feld
    }

    private func hole(_ pfad: String) throws -> [String: Any] {
        let daten = try fuehreAus(URLRequest(url: try url(pfad)))
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
    /// Fuer AWTRIX NG unentbehrlich: Dort steht die Begruendung im **Rumpf**
    /// einer Antwort mit Fehlerstatus, und wer den Status vorher zum Fehler
    /// macht, wirft die Begruendung weg und meldet „Status 422" statt
    /// „validationFailed im Feld durationMs".
    private func fuehreAusMitStatus(_ anfrage: URLRequest) throws -> (Data, Int) {
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
        guard let ergebnis else { throw GeraetFehler.nichtErreichbar("leere Antwort") }
        return (ergebnis, (antwort as? HTTPURLResponse)?.statusCode ?? 200)
    }
}
