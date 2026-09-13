import Foundation

/// Die drei Dinge, die man mit einer benannten Anzeige auf der Uhr tun kann —
/// auf dem Kanal, den die Uhr eingestellt hat (`Uhr.wirksameBetriebsart`).
///
/// **Dieselbe Nutzlast, anderer Kanal.** Der Rahmenbau (`Meldungsbau`) weiss
/// von dieser Unterscheidung nichts und soll es nicht: Was ueber MQTT auf
/// `<praefix>/custom/<name>` geht, geht ueber HTTP als Rumpf von
/// `POST /api/custom?name=<name>` — Byte fuer Byte dasselbe (§3.1, §5.6).
///
/// Nur das **Loeschen** faellt auseinander, und zwar gegenlaeufig: Ueber MQTT
/// loescht die **leere** Nutzlast und `{}` richtet nichts aus, ueber HTTP
/// loescht `{}` und ein leerer Rumpf richtet nichts aus. Beides ist gemessen;
/// die Verwechslung hat uns drei Eintraege in der Maengelliste gekostet.
public struct Anzeigen {
    /// Wohin die Bytes gehen. Ein Aufzaehlungstyp und nicht zwei Klassen: Die
    /// drei Taetigkeiten sind auf beiden Wegen dieselben, und jeder Aufrufer
    /// — App, Werkzeug, Kurzbefehl — soll genau einen Typ kennen.
    private enum Kanal {
        case mqtt(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String)
        case http(Geraet)
    }
    private let kanal: Kanal
    /// Welche Firmware am anderen Ende steht. **Zwei Achsen, nicht eine:** Der
    /// Kanal sagt, wie die Bytes hinkommen, die Gattung, welche Bytes es sind.
    /// Beide zusammen ergeben vier Faelle, und alle vier kommen vor.
    public let gattung: Geraetetyp

    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String,
                gattung: Geraetetyp = .tc002) {
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        kanal = .mqtt(sender: sender, zugang: zugang, praefix: normalisiert)
        self.gattung = gattung
    }

    /// Der HTTP-Kanal. Kein Praefix, kein Broker — nur die Adresse der Uhr.
    /// Die Gattung kennt das `Geraet` bereits; sie wird nicht zweimal gefuehrt.
    public init(geraet: Geraet) {
        kanal = .http(geraet)
        gattung = geraet.typ
    }

    /// Das Thema, auf dem eine benannte Anzeige liegt — je Gattung ein anderes.
    ///
    /// Ein Schreibfehler waere hier auf beiden Gattungen unsichtbar: MQTT 3.1.1
    /// kennt keinen Rueckkanal fuer eine abgelehnte Veroeffentlichung, und NG
    /// antwortet auf ein Thema ohne Route ueberhaupt nicht. Deshalb steht das
    /// Thema an einer Stelle und wird dort geprueft.
    private func anzeigenthema(_ praefix: String, _ name: String) -> String {
        switch gattung {
        case .tc002: return "\(praefix)/custom/\(name)"
        case .awtrixNG: return NGThema.anzeige(praefix: praefix, name: name)
        }
    }

    /// Was auf dem Thema landet bzw. im Rumpf steht — dieselben Bytes auf
    /// beiden Kanaelen, verschiedene auf beiden Gattungen.
    ///
    /// Die Werksfirmware bekommt den fertigen Rahmen. AWTRIX NG setzt den Text
    /// selbst; ihr nuetzen unsere Pixel nichts, sie braucht die Regler, aus
    /// denen sie entstanden (`Frame.herkunft`). Fehlen die — ein gemaltes Bild,
    /// ein Bild aus der Sammlung —, **wird nichts geschickt und gesagt, warum**.
    /// Ein auf acht Zeilen gestauchtes 52×16-Bild waere nicht dasselbe Bild,
    /// und stillschweigend nichts zu tun ist das Gegenteil einer Loesung.
    private func nutzlast(_ frame: Frame) throws -> String {
        switch gattung {
        case .tc002: return frame.alsJSON()
        case .awtrixNG:
            guard let herkunft = frame.herkunft else { throw NGFehler.keinPixelweg }
            return try NGNutzlast.anzeige(herkunft.optionen,
                                          iconDatenURI: herkunft.iconDatenURI,
                                          iconKante: herkunft.iconKante)
        }
    }

    public func zeigen(_ frame: Frame, auf name: String) throws {
        let json = try nutzlast(frame)
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            try sender.senden(Data(json.utf8), an: anzeigenthema(praefix, name), zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeSetzen(json, name: name)
        }
    }

    /// Entfernt die Anzeige vom Geraet — ueber MQTT mit einer leeren Nutzlast,
    /// ueber HTTP mit dem Rumpf `{}`. Siehe oben: Die beiden Wege meinen mit
    /// „leer" genau das Gegenteil voneinander.
    ///
    /// **Ueber MQTT gilt das fuer beide Gattungen gleich**: genau null Bytes
    /// loeschen, bei der Werksfirmware wie bei NG. Nur das Thema wechselt.
    /// Ueber HTTP gehen die beiden auseinander, und zwar wieder gegenlaeufig —
    /// das erledigt `Geraet.anzeigeLoeschen`.
    public func loeschen(_ name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            try sender.senden(Data(), an: anzeigenthema(praefix, name), zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeLoeschen(name: name)
        }
    }

    public func umschalten(auf name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            switch gattung {
            case .tc002:
                try sender.senden(Data(name.utf8), an: "\(praefix)/switchDiyApp", zugang: zugang)
            case .awtrixNG:
                try sender.senden(Data(NGNutzlast.umschalten(auf: name).utf8),
                                  an: NGThema.umschalten(praefix: praefix), zugang: zugang)
            }
        case .http(let geraet):
            try geraet.umschalten(auf: name)
        }
    }

    /// Ob dieser Kanal eine Rueckmeldung gibt — ueber HTTP heisst „kein
    /// Fehler" wirklich „angekommen", ueber MQTT nur „abgeschickt".
    ///
    /// **Nur die Tests fragen das heute**, und sie brauchen es: `kanal` ist
    /// privat, und ohne diese Naht liesse sich gar nicht nachmessen, ob
    /// `fuer(_:brokerzugang:)` den richtigen Weg gewaehlt hat. Dieselbe Sorte
    /// Zugang wie `gedaechtnis:` bei den Slots und `sitzung:` bei den
    /// HTTP-Wegen.
    public var quittiert: Bool {
        if case .http = kanal { return true }
        return false
    }

    /// Der Kanal einer Uhr — **die eine Stelle**, an der aus einer `Uhr` ein
    /// `Anzeigen` wird. App (`AppZustand.anzeigen(fuer:)`), Werkzeug und
    /// Kurzbefehle rufen alle hierher: Ein Werkzeug, das anders sendet als die
    /// App, waere eine Falle, und drei Abschriften derselben Regel liefen
    /// frueher oder spaeter auseinander.
    ///
    /// `nil` heisst „an diese Uhr laesst sich nicht senden": ohne Adresse im
    /// HTTP-Betrieb, ohne Praefix oder ohne Brokerzugang im MQTT-Betrieb.
    /// Warum — das sagt der Aufrufer, der den Fall besser kennt
    /// (`AppZustand.zugangsmeldung`).
    /// **`brokerzugang` ist ein `@autoclosure`, und das ist kein Feinschliff.**
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
            return Anzeigen(geraet: Geraet(host: uhr.host, sitzung: sitzung, typ: uhr.gattung))
        case .mqtt:
            guard !uhr.praefix.isEmpty, let zugang = brokerzugang() else { return nil }
            return Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: uhr.praefix,
                            gattung: uhr.gattung)
        }
    }
}

extension Anzeigen {
    /// Liest die Anzeigenliste, die die Uhr selbst veroeffentlicht (§3.5):
    /// `{"apps":[{"appName":"scrolltest"}],"count":1}`.
    ///
    /// nil heisst „das war keine lesbare Liste" — etwas anderes als die leere
    /// Liste, die sehr wohl eine Aussage ist: auf der Uhr steht gerade nichts.
    public static func namenAusCustomList(_ daten: Data) -> [String]? {
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any] else { return nil }
        return namenAusAppsFeld(woerterbuch["apps"])
    }

    /// Das Feld `apps` — in **zwei** Schreibweisen, denn dieselbe Liste kommt
    /// ueber die beiden Wege verschieden herein (§3.5, §5.7):
    ///
    ///   - MQTT: `[{"appName":"scrolltest"}]`
    ///   - HTTP: `["meldung2","meldung5"]`
    ///
    /// Ein Leser fuer beide, weil es dieselbe Auskunft ist. Ein zweiter neben
    /// diesem waere eine zweite Stelle, an der sich die Form aendern koennte.
    ///
    /// nil heisst „das war keine lesbare Liste"; die leere Liste heisst „auf der
    /// Uhr steht gerade nichts".
    /// Das Inventar einer AWTRIX NG (`GET /api/v1/apps`, §7.2) — gefiltert auf
    /// das, was jemand von aussen abgelegt hat.
    ///
    /// ```json
    /// [{"name":"Time","origin":"builtin"}, {"name":"meldung1","origin":"pushed"}]
    /// ```
    ///
    /// **Genauer als `customList` der Werksfirmware**, und deshalb ein eigener
    /// Leser statt einer dritten Schreibweise in `namenAusAppsFeld`: Was dort
    /// eine Liste von Namen ist, ist hier eine Liste von Apps mit Herkunft, und
    /// nur `pushed` sind unsere. Die eingebauten (`Time`, `Battery`, …) und die
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

    static func namenAusAppsFeld(_ feld: Any?) -> [String]? {
        if let namen = feld as? [String] { return namen }
        if let eintraege = feld as? [[String: Any]] {
            return eintraege.compactMap { $0["appName"] as? String }
        }
        return nil
    }

    /// Zerlegt eine mitgelesene `custom`-Nutzlast (unser eigenes Format,
    /// `Frame.alsJSON()`) in die 52×16-Pixel, die daraus auf der Uhr staenden.
    ///
    /// Deckt den stehenden Fall ab: `draw` mit Rechtecken. Ein Bild-Weg
    /// (`image`: eine Icon-Bitmap oder ein Lauf-GIF als Daten-URI) und der
    /// Geraeteschrift-Weg (`text`) liefern noch keine Pixel — nil heisst
    /// „nicht zerlegbar", nicht „leer".
    public static func pixelAusCustomNutzlast(_ daten: Data) -> [String?]? {
        guard !daten.isEmpty,
              let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any],
              let rechtecke = woerterbuch["draw"] as? [[String: Any]] else { return nil }
        var feld = Pixelfeld()
        for rechteck in rechtecke {
            guard let df = rechteck["df"] as? [Any], df.count == 5,
                  let x = df[0] as? Int, let y = df[1] as? Int,
                  let breite = df[2] as? Int, let hoehe = df[3] as? Int,
                  let farbe = df[4] as? String else { continue }
            for dy in 0..<max(0, hoehe) {
                for dx in 0..<max(0, breite) {
                    feld.setzen(x: x + dx, y: y + dy, farbe: farbe)
                }
            }
        }
        return feld.punkteRoh
    }
}

/// Was zuletzt auf einem Slot der Uhr zu sehen war — aus einer mitgelesenen
/// `custom`-Nutzlast gewonnen, nicht von der Uhr erfragt (sie verraet den
/// Inhalt selbst nicht, siehe `namenAusCustomList`).
public struct Slotbild: Equatable, Sendable {
    public var pixel: [String?]
    public init(pixel: [String?]) {
        self.pixel = pixel
    }
}

/// Was die App über einen der fünf festen Plätze weiß — nicht zwei bequeme
/// Fälle, sondern drei ehrliche (Entwurf, Abschnitt „Drei Zustände je Block“).
///
/// Die Uhr verrät über `customList` nur **Namen**, nie den Inhalt. Belegt
/// oder frei ist damit Tatsache; was darauf steht, weiß die App nur, wenn sie
/// die Sendung mitgelesen hat oder sich die Regler gemerkt hat:
///
/// - `.frei` — kein Name auf diesem Platz.
/// - `.bekannt(punkte)` — ein Name ist da, und die App hat ein Bild dazu.
///   `punkte` sind die 52×16 Pixel in derselben Form, die
///   `Meldungsbau.feld(...).punkteRoh` liefert — genau diese Form gibt auch
///   das Zerlegen einer mitgelesenen Nutzlast zurück. **Woher** das Bild
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
