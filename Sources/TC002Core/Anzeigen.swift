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

    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String) {
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        kanal = .mqtt(sender: sender, zugang: zugang, praefix: normalisiert)
    }

    /// Der HTTP-Kanal. Kein Praefix, kein Broker — nur die Adresse der Uhr.
    public init(geraet: Geraet) {
        kanal = .http(geraet)
    }

    public func zeigen(_ frame: Frame, auf name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            try sender.senden(Data(frame.alsJSON().utf8), an: "\(praefix)/custom/\(name)", zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeSetzen(frame.alsJSON(), name: name)
        }
    }

    /// Entfernt die Anzeige vom Geraet — ueber MQTT mit einer leeren Nutzlast,
    /// ueber HTTP mit dem Rumpf `{}`. Siehe oben: Die beiden Wege meinen mit
    /// „leer" genau das Gegenteil voneinander.
    public func loeschen(_ name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            try sender.senden(Data(), an: "\(praefix)/custom/\(name)", zugang: zugang)
        case .http(let geraet):
            try geraet.anzeigeLoeschen(name: name)
        }
    }

    public func umschalten(auf name: String) throws {
        switch kanal {
        case .mqtt(let sender, let zugang, let praefix):
            try sender.senden(Data(name.utf8), an: "\(praefix)/switchDiyApp", zugang: zugang)
        case .http(let geraet):
            try geraet.umschalten(auf: name)
        }
    }

    /// Ob dieser Kanal eine Rueckmeldung gibt. Der eine Unterschied, den die
    /// Oberflaechen kennen muessen: Ueber HTTP heisst „kein Fehler" wirklich
    /// „angekommen", ueber MQTT heisst es nur „abgeschickt".
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
    public static func fuer(_ uhr: Uhr, brokerzugang: MQTTZugang?,
                            sitzung: URLSession = .shared) -> Anzeigen? {
        switch uhr.wirksameBetriebsart {
        case .http:
            guard !uhr.host.isEmpty else { return nil }
            return Anzeigen(geraet: Geraet(host: uhr.host, sitzung: sitzung))
        case .mqtt:
            guard !uhr.praefix.isEmpty, let brokerzugang else { return nil }
            return Anzeigen(sender: MQTTSender(), zugang: brokerzugang, praefix: uhr.praefix)
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
