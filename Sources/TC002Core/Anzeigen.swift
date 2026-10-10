import Foundation

/// Die drei Dinge, die man mit einer benannten Anzeige auf der Uhr tun kann —
/// auf dem Kanal, den die Uhr eingestellt hat (`Uhr.wirksameBetriebsart`).
///
/// Dieselbe Nutzlast, anderer Kanal. Der Rahmenbau (`Meldungsbau`) weiss
/// von dieser Unterscheidung nichts und soll es nicht: Was ueber MQTT auf
/// `<praefix>/cmd/apps/pushed/<name>` geht, geht ueber HTTP als Rumpf von
/// `PUT /api/v1/apps/pushed/<name>` — Byte fuer Byte dasselbe
/// (`docs/awtrix-ng-protokoll.md` §3).
///
/// Nur das Loeschen faellt auseinander: Ueber MQTT loescht die leere
/// Nutzlast, ueber HTTP `DELETE /api/v1/apps/<name>` (`{}` auf `PUT` ist `422`).
public struct Anzeigen {
    /// Wohin die Bytes gehen. Ein Aufzaehlungstyp und nicht zwei Klassen: Die
    /// drei Taetigkeiten sind auf beiden Wegen dieselben, und jeder Aufrufer
    /// — App, Werkzeug, Kurzbefehl — soll genau einen Typ kennen.
    enum Kanal {
        case mqtt(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String, ausweich: Geraet?)
        case http(Geraet)
    }
    let kanal: Kanal

    /// Wie lange und von wem auf `<Thema>/result` gewartet wird — nur für
    /// Absender, die nicht ohnehin am Broker mitlesen (Werkzeug, Kurzbefehle).
    private struct Quittung {
        let lauscher: ErgebnisLauschend
        let frist: TimeInterval
        let beiAusbleiben: @Sendable (String) -> Void
    }
    private var quittung: Quittung?
    /// Das Anzeigemass der Ziel-Uhr, falls bekannt: Ein fertiges Bild in anderer
    /// Groesse wird vor dem Senden abgewiesen (`NGFehler.massPasstNicht`).
    private let anzeigemass: Anzeigemass?

    /// `ausweich`: dieselbe Uhr ueber HTTP, fuer die eine Anzeige, die nicht in
    /// eine MQTT-Nachricht passt (`Pixelweg.zustellweg`).
    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String,
                ausweich: Geraet? = nil, anzeigemass: Anzeigemass? = nil) {
        self.anzeigemass = anzeigemass
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        kanal = .mqtt(sender: sender, zugang: zugang, praefix: normalisiert, ausweich: ausweich)
    }

    /// Der HTTP-Kanal. Kein Praefix, kein Broker — nur die Adresse der Uhr.
    public init(geraet: Geraet, anzeigemass: Anzeigemass? = nil) {
        self.anzeigemass = anzeigemass
        kanal = .http(geraet)
    }

    /// Dieselbe Uhr, aber jede MQTT-Sendung wartet auf die Antwort der Uhr
    /// (`<Thema>/result`, §3.4): `ok:false` wirft `NGFehler.abgewiesen`, bleibt
    /// die Antwort bis `frist` aus, ruft es `beiAusbleiben` mit dem Thema — eine
    /// Warnung und kein Fehler, denn es kann auch am Mitlesen liegen (dieselbe
    /// Bedeutung wie in der App). Über HTTP ändert sich nichts: Dort ist der
    /// Status die Antwort.
    public func quittierend(frist: TimeInterval = 5,
                            lauscher: ErgebnisLauschend = MQTTErgebnislauscher(),
                            beiAusbleiben: @escaping @Sendable (String) -> Void) -> Anzeigen {
        var kopie = self
        kopie.quittung = Quittung(lauscher: lauscher, frist: frist, beiAusbleiben: beiAusbleiben)
        return kopie
    }

    /// Veröffentlicht, und wartet dabei — falls gewünscht — auf die Antwort.
    func veroeffentlichen(_ daten: Data, an thema: String, sender: NachrichtSendend,
                                  zugang: MQTTZugang) throws {
        guard let quittung else {
            try sender.senden(daten, an: thema, zugang: zugang)
            return
        }
        let antwort = try quittung.lauscher.erwarten(thema: thema, zugang: zugang, frist: quittung.frist) {
            try sender.senden(daten, an: thema, zugang: zugang)
        }
        guard let antwort else { quittung.beiAusbleiben(thema); return }
        // `.unlesbar` ist keine Antwort auf ein Kommando; die App liest es ebenso.
        if case .abgewiesen(let grund) = NGNutzlast.ergebnis(antwort) {
            throw NGFehler.abgewiesen(grund)
        }
    }

    /// Was auf dem Thema landet bzw. im Rumpf steht — dieselben Bytes auf
    /// beiden Kanaelen.
    ///
    /// Pixel (`Frame.pixel`) gehen als GIF-Icon hinaus (`Pixelweg`), Text samt
    /// Reglern setzt die Uhr selbst (`Frame.herkunft`). Ein Rahmen ohne beides
    /// wird nicht geschickt: MQTT 3.1.1 kennt keinen Rueckkanal fuer eine
    /// abgelehnte Veroeffentlichung, und stillschweigend nichts zu tun ist das
    /// Gegenteil einer Loesung.
    ///
    /// `mass` ist das Anzeigemaß der Ziel-Uhr; nur ein Layout braucht es (seine
    /// Kästen müssen ganz darin liegen). Ohne Angabe gilt 52 × 16.
    public static func nutzlast(_ frame: Frame, faehigkeiten: Geraetefaehigkeiten? = nil,
                                mass: Anzeigemass? = nil) throws -> String {
        let grund = try grundnutzlast(frame, faehigkeiten: faehigkeiten, mass: mass)
        guard let lebensdauer = frame.lebensdauer else { return grund }
        return NGNutzlast.ergaenzt(grund, um: NGNutzlast.lebensdauerfelder(lebensdauer))
    }

    /// Die Nutzlast ohne `lifetimeMs`/`lifetimeExpiry`: Eine Benachrichtigung
    /// nimmt beide an und ignoriert sie, sie gehören nur in eine Anzeige.
    ///
    /// Die Darstellung wird geprüft und angehängt; `faehigkeiten` sind die
    /// Namenslisten der Ziel-Uhr (ohne sie bleiben Namen ungeprüft).
    static func grundnutzlast(_ frame: Frame, faehigkeiten: Geraetefaehigkeiten? = nil,
                              mass: Anzeigemass? = nil) throws -> String {
        if let layout = frame.layout {
            // Neben `layout` sind nur Standzeit, Lebensdauer und die Felder einer
            // Benachrichtigung zulässig (§9.4); die Darstellung steht im Layout.
            guard frame.pixel == nil, frame.herkunft == nil, frame.grafik == nil,
                  frame.darstellung?.istLeer ?? true else { throw LayoutFehler.mitAnderemInhalt }
            try layout.pruefen(mass: mass ?? .vorgabe, faehigkeiten: faehigkeiten)
            let dauer = frame.dauer.map { #","durationMs":\#($0 * 1000)"# } ?? ""
            return #"{"layout":\#(layout.json(gegen: faehigkeiten))\#(dauer)}"#
        }
        let darstellung = frame.darstellung ?? Darstellung()
        try darstellung.pruefen(gegen: faehigkeiten)
        let json: String
        if let grafik = frame.grafik {
            guard frame.pixel == nil, frame.herkunft == nil else { throw DarstellungsFehler.grafikMitInhalt }
            if darstellung.textfarbeAusPalette { throw DarstellungsFehler.ohneText }
            try grafik.pruefen(palette: darstellung.palette)
            var teile = grafik.felder()
            if let dauer = frame.dauer { teile.append(#""durationMs":\#(dauer * 1000)"#) }
            json = "{" + teile.joined(separator: ",") + "}"
        } else if let pixel = frame.pixel {
            // Das GIF in Anzeigegröße ist der Hintergrund (§5.3).
            if darstellung.hintergrundfarbe != nil { throw DarstellungsFehler.vomBildVerdeckt(feld: "backgroundColor") }
            if let e = darstellung.effekt, !e.isEmpty { throw DarstellungsFehler.vomBildVerdeckt(feld: "effect") }
            if darstellung.textfarbeAusPalette { throw DarstellungsFehler.ohneText }
            json = try Pixelweg.nutzlast(pixel, dauer: frame.dauer)
        } else {
            guard let herkunft = frame.herkunft else { throw NGFehler.leer }
            json = try NGNutzlast.anzeige(herkunft.optionen, iconDatenURI: herkunft.iconDatenURI,
                                          textfarbeAusPalette: darstellung.textfarbeAusPalette)
        }
        return NGNutzlast.ergaenzt(json, um: darstellung.felder(gegen: faehigkeiten))
    }

    /// Schickt die Anzeige. Passt sie ueber MQTT samt Thema nicht in 8192 Byte,
    /// geht sie ueber HTTP an dieselbe Uhr: NG verwirft Groesseres ohne
    /// Antwort, und eine stumm verlorene Sendung waere das Schlimmste.
    @discardableResult
    public func zeigen(_ frame: Frame, auf name: String,
                       faehigkeiten: Geraetefaehigkeiten? = nil) throws -> Zustellweg {
        if let mass = anzeigemass, let pixel = frame.pixel,
           pixel.breite != mass.breite || pixel.hoehe != mass.hoehe {
            throw NGFehler.massPasstNicht(bildBreite: pixel.breite, bildHoehe: pixel.hoehe,
                                          anzeigeBreite: mass.breite, anzeigeHoehe: mass.hoehe)
        }
        let json = try Self.nutzlast(frame, faehigkeiten: faehigkeiten, mass: anzeigemass)
        let daten = Data(json.utf8)
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, let ausweich):
            let thema = NGThema.anzeige(praefix: praefix, name: name)
            let weg = try Pixelweg.zustellweg(nutzlastBytes: daten.count,
                                              themaBytes: thema.utf8.count, betriebsart: .mqtt)
            switch weg {
            case .mqtt:
                try veroeffentlichen(daten, an: thema, sender: sender, zugang: zugang)
            case .http:
                guard let ausweich else { throw NGFehler.keineAdresseFuerGrosse(bytes: daten.count) }
                try ausweich.anzeigeSetzen(json, name: name)
            }
            return weg
        case .http(let geraet):
            _ = try Pixelweg.zustellweg(nutzlastBytes: daten.count, themaBytes: 0, betriebsart: .http)
            try geraet.anzeigeSetzen(json, name: name)
            return .http
        }
    }

    /// Entfernt die Anzeige vom Geraet — ueber MQTT mit einer leeren Nutzlast,
    /// ueber HTTP mit `DELETE`. Genau null Bytes loeschen (§3.2).
    public func loeschen(_ name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(Data(), an: NGThema.anzeige(praefix: praefix, name: name),
                                 sender: sender, zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeLoeschen(name: name)
        }
    }

    public func umschalten(auf name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(Data(NGNutzlast.umschalten(auf: name).utf8),
                                 an: NGThema.umschalten(praefix: praefix), sender: sender, zugang: zugang)
        case .http(let geraet):
            try geraet.umschalten(auf: name)
        }
    }

    /// Reiht eine Benachrichtigung ein (`cmd/notify` bzw. `POST /api/v1/notifications`).
    /// Dieselbe Rasterung, dieselbe Größenweiche MQTT ↔ HTTP wie `zeigen` — nur
    /// ohne Lebensdauer und mit den Feldern aus §5.6.
    @discardableResult
    public func benachrichtigen(_ frame: Frame, _ optionen: Benachrichtigungsoptionen = .init(),
                                faehigkeiten: Geraetefaehigkeiten? = nil) throws -> Zustellweg {
        if let mass = anzeigemass, let pixel = frame.pixel,
           pixel.breite != mass.breite || pixel.hoehe != mass.hoehe {
            throw NGFehler.massPasstNicht(bildBreite: pixel.breite, bildHoehe: pixel.hoehe,
                                          anzeigeBreite: mass.breite, anzeigeHoehe: mass.hoehe)
        }
        let json = try NGNutzlast.benachrichtigung(frame, optionen, faehigkeiten: faehigkeiten,
                                                   mass: anzeigemass)
        let daten = Data(json.utf8)
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, let ausweich):
            let thema = NGThema.benachrichtigung(praefix: praefix)
            let weg = try Pixelweg.zustellweg(nutzlastBytes: daten.count,
                                              themaBytes: thema.utf8.count, betriebsart: .mqtt)
            switch weg {
            case .mqtt:
                try veroeffentlichen(daten, an: thema, sender: sender, zugang: zugang)
            case .http:
                guard let ausweich else { throw NGFehler.keineAdresseFuerGrosse(bytes: daten.count) }
                try ausweich.benachrichtigen(json)
            }
            return weg
        case .http(let geraet):
            _ = try Pixelweg.zustellweg(nutzlastBytes: daten.count, themaBytes: 0, betriebsart: .http)
            try geraet.benachrichtigen(json)
            return .http
        }
    }

    /// Nimmt die sichtbare Benachrichtigung weg, mit `name` die benannte (auch
    /// eine wartende). Die sichtbare zu nehmen ist immer `200`, auch wenn keine
    /// zu sehen ist; ein Name, den es nicht gibt, ist `404` bzw. `notFound`.
    public func benachrichtigungZurueckziehen(name: String? = nil) throws {
        if let name, !Benachrichtigungsoptionen.nameGueltig(name) {
            throw NGFehler.ungueltigerName(name)
        }
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(Data(), an: NGThema.zurueckziehen(praefix: praefix, name: name),
                                 sender: sender, zugang: zugang)
        case .http(let geraet):
            try geraet.benachrichtigungZurueckziehen(name: name)
        }
    }

    /// Schaltet eine Anzeige ein oder aus (`cmd/apps/<name>/enabled`). Sie behält
    /// ihren Platz in der Schleife; nur ihr Auftritt entfällt.
    public func schalten(_ name: String, an: Bool) throws {
        guard Anzeigenname.gueltig(name) else { throw NGFehler.ungueltigerName(name) }
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(Data((an ? "true" : "false").utf8),
                                 an: NGThema.freigabe(praefix: praefix, name: name),
                                 sender: sender, zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeSchalten(name: name, an: an)
        }
    }

    /// Eine Anzeige vor oder zurück in der Schleife.
    public func blaettern(vor: Bool) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try veroeffentlichen(Data(), an: NGThema.blaettern(praefix: praefix, vor: vor),
                                 sender: sender, zugang: zugang)
        case .http(let geraet):
            try geraet.blaettern(vor: vor)
        }
    }

    /// Ob dieser Kanal eine Rueckmeldung gibt — ueber HTTP heisst „kein
    /// Fehler" wirklich „angekommen", ueber MQTT nur „abgeschickt".
    ///
    /// Nur die Tests fragen das heute, und sie brauchen es: `kanal` ist
    /// privat, und ohne diese Naht liesse sich gar nicht nachmessen, ob
    /// `fuer(_:brokerzugang:)` den richtigen Weg gewaehlt hat. Dieselbe Sorte
    /// Zugang wie `gedaechtnis:` bei den Slots und `sitzung:` bei den
    /// HTTP-Wegen.
    public var quittiert: Bool {
        if case .http = kanal { return true }
        return false
    }

    /// Der Kanal einer Uhr — die eine Stelle, an der aus einer `Uhr` ein
    /// `Anzeigen` wird. App (`AppZustand.anzeigen(fuer:)`), Werkzeug und
    /// Kurzbefehle rufen alle hierher: Ein Werkzeug, das anders sendet als die
    /// App, waere eine Falle, und drei Abschriften derselben Regel liefen
    /// frueher oder spaeter auseinander.
    ///
    /// `nil` heisst „an diese Uhr laesst sich nicht senden": ohne Adresse im
    /// HTTP-Betrieb, ohne Praefix oder ohne Brokerzugang im MQTT-Betrieb.
    /// Warum — das sagt der Aufrufer, der den Fall besser kennt
    /// (`AppZustand.zugangsmeldung`).
    /// `brokerzugang` ist ein `@autoclosure`, und das ist kein Feinschliff.
    /// `Einstellungen.zugang(clientID:)` liest das Kennwort aus dem
    /// Schluesselbund, und das oeffnet auf dem Rechner eines Menschen einen
    /// Dialog. Eifrig ausgewertet fragte eine reine HTTP-Sendung aus dem
    /// Werkzeug oder einem Kurzbefehl nach einem Brokerkennwort, das sie
    /// nirgends benutzt — bei einer Automation ohne jemanden davor.
    public static func fuer(_ uhr: Uhr, brokerzugang: @autoclosure () -> MQTTZugang?,
                            sitzung: URLSession = .shared,
                            sender: NachrichtSendend = MQTTSender()) -> Anzeigen? {
        switch uhr.wirksameBetriebsart {
        case .http:
            guard !uhr.host.isEmpty else { return nil }
            return Anzeigen(geraet: Geraet(host: uhr.host, sitzung: sitzung),
                            anzeigemass: Anzeigemass.fuer(uhr))
        case .mqtt:
            guard !uhr.praefix.isEmpty, let zugang = brokerzugang() else { return nil }
            // Mit Adresse ueber HTTP erreichbar, falls eine Anzeige fuer MQTT zu
            // gross ist; ohne bleibt es bei der Meldung vor dem Senden.
            let ausweich = uhr.host.isEmpty ? nil : Geraet(host: uhr.host, sitzung: sitzung)
            return Anzeigen(sender: sender, zugang: zugang, praefix: uhr.praefix,
                            ausweich: ausweich, anzeigemass: Anzeigemass.fuer(uhr))
        }
    }
}

extension Anzeigen {
    /// Das Inventar einer AWTRIX NG (`GET /api/v1/apps`, §7.2) — gefiltert auf
    /// das, was jemand von aussen abgelegt hat.
    ///
    /// ```json
    /// [{"name":"Time","origin":"builtin"}, {"name":"meldung1","origin":"pushed"}]
    /// ```
    ///
    /// Eine Liste von Apps mit Herkunft; nur `pushed` sind unsere. Die eingebauten (`Time`, `Battery`, …) und die
    /// von Berry-Skripten mitzuzaehlen hiesse, fuenf Bloecke als belegt zu
    /// zeigen, weil das Geraet eine Uhrzeit anzeigt.
    ///
    /// `nil` heisst „das war kein lesbares Inventar"; die leere Liste heisst
    /// „es liegt keine eigene Anzeige darauf".
    ///
    /// Nur `present:true` zählt als belegt: Eine ausgeschaltete Anzeige, die
    /// gelöscht wurde, bleibt als Geistereintrag (`present:false`) im Inventar
    /// (gemessen 09.10.2026, `docs/awtrix-ng-protokoll.md` §7.2).
    public static func namenAusNGInventar(_ feld: Any?) -> [String]? {
        eintraegeAusNGInventar(feld)?.filter(\.vorhanden).map(\.name)
    }

    /// Wie `namenAusNGInventar`, aber mit `enabled` und `present` und auch mit
    /// den Geistereinträgen. Fehlt ein Feld, gilt die Anzeige als eingeschaltet
    /// und vorhanden (ältere Firmware nennt beides nicht).
    public static func eintraegeAusNGInventar(_ feld: Any?) -> [Inventareintrag]? {
        guard let eintraege = feld as? [[String: Any]] else { return nil }
        return eintraege.compactMap { eintrag in
            guard eintrag["origin"] as? String == "pushed",
                  let name = eintrag["name"] as? String else { return nil }
            return Inventareintrag(name: name,
                                   aktiv: eintrag["enabled"] as? Bool ?? true,
                                   vorhanden: eintrag["present"] as? Bool ?? true)
        }
    }
}

/// Eine eigene Anzeige im Inventar der Uhr. `aktiv == false` heißt: nicht in der
/// Schleife (`enabled`). `vorhanden == false` ist ein Geistereintrag: Der Inhalt
/// ist gelöscht, die Abschaltung bleibt, und eine spätere Sendung unter demselben
/// Namen wäre unsichtbar, bis jemand `enabled true` setzt.
public struct Inventareintrag: Equatable, Sendable {
    public var name: String
    public var aktiv: Bool
    public var vorhanden: Bool

    public init(name: String, aktiv: Bool = true, vorhanden: Bool = true) {
        self.name = name
        self.aktiv = aktiv
        self.vorhanden = vorhanden
    }
}

/// Was zuletzt auf einem Slot der Uhr zu sehen war — gemerkt oder mitgelesen,
/// nicht von der Uhr erfragt (die Liste der Apps nennt nur Namen).
public struct Slotbild: Equatable, Sendable {
    public var pixel: [String?]
    public init(pixel: [String?]) {
        self.pixel = pixel
    }
}

/// Was die App über einen der fünf festen Plätze weiß — nicht zwei bequeme
/// Fälle, sondern drei ehrliche (Entwurf, Abschnitt „Drei Zustände je Block“).
///
/// Die Uhr verrät über `GET /api/v1/apps` nur Namen, nie den Inhalt. Belegt
/// oder frei ist damit Tatsache; was darauf steht, weiß die App nur, wenn sie
/// die Sendung mitgelesen hat oder sich die Regler gemerkt hat:
///
/// - `.frei` — kein Name auf diesem Platz.
/// - `.bekannt(punkte)` — ein Name ist da, und die App hat ein Bild dazu.
///   `punkte` sind die 52×16 Pixel in derselben Form, die
///   `Meldungsbau.feld(...).punkteRoh` liefert — genau diese Form gibt auch
///   das Zerlegen einer mitgelesenen Nutzlast zurück. Woher das Bild
///   stammt, steht nicht mehr darin: mitgelesen (Tatsache) oder aus dem
///   Slotgedächtnis neu gerechnet (Erinnerung). Wer darauf angewiesen ist,
///   fragt das Gedächtnis und die Prüfsumme selbst — siehe `slotWaehlen` in
///   den Sendeansichten.
/// - `.unbekannt` — ein Name ist da, aber die App weiß nicht, was darauf
///   steht (nie mitgelesen und nichts gemerkt, oder ein Weg, der sich nicht
///   zerlegen lässt, z. B. ein Lauf-GIF eines fremden Absenders). Das ist
///   keine Lücke, sondern die Auskunft: ein Block, der hier einen Inhalt
///   zeigte, behauptete etwas, das niemand mehr belegen kann.
///
/// Warum ein Platz `.unbekannt` ist, steht nicht hier — das sagt die Hilfe.
///
/// Liegt im Kern und nicht bei `Slotblock`, weil beide Seiten ihn brauchen:
/// `AppZustand.slotzustand(_:belegt:)` entscheidet ihn, `Slotblock` zeigt ihn.
public enum Slotzustand: Equatable, Sendable {
    case frei
    case bekannt([String?])
    case unbekannt
}
