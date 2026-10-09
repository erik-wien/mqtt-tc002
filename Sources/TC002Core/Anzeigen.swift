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
    private enum Kanal {
        case mqtt(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String, ausweich: Geraet?)
        case http(Geraet)
    }
    private let kanal: Kanal

    /// `ausweich`: dieselbe Uhr ueber HTTP, fuer die eine Anzeige, die nicht in
    /// eine MQTT-Nachricht passt (`Pixelweg.zustellweg`).
    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String,
                ausweich: Geraet? = nil) {
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        kanal = .mqtt(sender: sender, zugang: zugang, praefix: normalisiert, ausweich: ausweich)
    }

    /// Der HTTP-Kanal. Kein Praefix, kein Broker — nur die Adresse der Uhr.
    public init(geraet: Geraet) {
        kanal = .http(geraet)
    }

    /// Was auf dem Thema landet bzw. im Rumpf steht — dieselben Bytes auf
    /// beiden Kanaelen.
    ///
    /// Pixel (`Frame.pixel`) gehen als Layout hinaus (`Pixelweg`), Text samt
    /// Reglern setzt die Uhr selbst (`Frame.herkunft`). Ein Rahmen ohne beides
    /// wird nicht geschickt: MQTT 3.1.1 kennt keinen Rueckkanal fuer eine
    /// abgelehnte Veroeffentlichung, und stillschweigend nichts zu tun ist das
    /// Gegenteil einer Loesung.
    public static func nutzlast(_ frame: Frame) throws -> String {
        if let pixel = frame.pixel { return try Pixelweg.nutzlast(pixel, dauer: frame.dauer) }
        guard let herkunft = frame.herkunft else { throw NGFehler.leer }
        return try NGNutzlast.anzeige(herkunft.optionen,
                                      iconDatenURI: herkunft.iconDatenURI)
    }

    /// Schickt die Anzeige. Passt sie ueber MQTT samt Thema nicht in 8192 Byte,
    /// geht sie ueber HTTP an dieselbe Uhr: NG verwirft Groesseres ohne
    /// Antwort, und eine stumm verlorene Sendung waere das Schlimmste.
    public func zeigen(_ frame: Frame, auf name: String) throws {
        let json = try Self.nutzlast(frame)
        let daten = Data(json.utf8)
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, let ausweich):
            let thema = NGThema.anzeige(praefix: praefix, name: name)
            let weg = try Pixelweg.zustellweg(nutzlastBytes: daten.count,
                                              themaBytes: thema.utf8.count, betriebsart: .mqtt)
            switch weg {
            case .mqtt:
                try sender.senden(daten, an: thema, zugang: zugang)
            case .http:
                guard let ausweich else { throw NGFehler.keineAdresseFuerGrosse(bytes: daten.count) }
                try ausweich.anzeigeSetzen(json, name: name)
            }
        case .http(let geraet):
            _ = try Pixelweg.zustellweg(nutzlastBytes: daten.count, themaBytes: 0, betriebsart: .http)
            try geraet.anzeigeSetzen(json, name: name)
        }
    }

    /// Entfernt die Anzeige vom Geraet — ueber MQTT mit einer leeren Nutzlast,
    /// ueber HTTP mit `DELETE`. Genau null Bytes loeschen (§3.2).
    public func loeschen(_ name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try sender.senden(Data(), an: NGThema.anzeige(praefix: praefix, name: name), zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeLoeschen(name: name)
        }
    }

    public func umschalten(auf name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix, _):
            try sender.senden(Data(NGNutzlast.umschalten(auf: name).utf8),
                              an: NGThema.umschalten(praefix: praefix), zugang: zugang)
        case .http(let geraet):
            try geraet.umschalten(auf: name)
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
                            sitzung: URLSession = .shared) -> Anzeigen? {
        switch uhr.wirksameBetriebsart {
        case .http:
            guard !uhr.host.isEmpty else { return nil }
            return Anzeigen(geraet: Geraet(host: uhr.host, sitzung: sitzung))
        case .mqtt:
            guard !uhr.praefix.isEmpty, let zugang = brokerzugang() else { return nil }
            // Mit Adresse ueber HTTP erreichbar, falls eine Anzeige fuer MQTT zu
            // gross ist; ohne bleibt es bei der Meldung vor dem Senden.
            let ausweich = uhr.host.isEmpty ? nil : Geraet(host: uhr.host, sitzung: sitzung)
            return Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: uhr.praefix,
                            ausweich: ausweich)
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
    public static func namenAusNGInventar(_ feld: Any?) -> [String]? {
        guard let eintraege = feld as? [[String: Any]] else { return nil }
        return eintraege.compactMap { eintrag in
            guard eintrag["origin"] as? String == "pushed",
                  let name = eintrag["name"] as? String else { return nil }
            return name
        }
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
