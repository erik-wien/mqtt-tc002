import Foundation

/// Was auf dem Weg zu einer AWTRIX NG schiefgehen kann, bevor etwas
/// abgeschickt ist.
///
/// Beide Faelle haetten auf dem Geraet dasselbe Ergebnis: nichts. NG antwortet
/// auf ein Thema, das keine Route trifft, gar nicht, und ein Icon in einem
/// Format, das es nicht liest, faellt still auf „kein Icon" zurueck
/// (`docs/awtrix-ng-protokoll.md` §3.3, §5.3). Dieses Projekt ist auf der
/// Einsicht gebaut, dass ein Sender ohne Rueckkanal nichts beweist — also wird
/// hier gesagt, was nicht geht, statt es zu schicken und zu hoffen.
public enum NGFehler: Error, LocalizedError {
    /// Ein Icon in einem Format, das NG hier nicht gebrauchen kann.
    case iconFormat(String)
    /// Eine Anzeige, die selbst ueber HTTP nicht passt (2 MiB, §8).
    case zuGross(bytes: Int)
    /// Eine Anzeige zu gross fuer MQTT, die Uhr hat aber keine Adresse fuer HTTP.
    case keineAdresseFuerGrosse(bytes: Int)
    /// Eine Laufschrift, deren GIF groesser ist als NG als `icon` annimmt.
    case laufschriftZuLang(bytes: Int)
    /// Ein Rahmen ohne Text und ohne Pixel.
    case leer
    /// Ein fertiges Bild, dessen Mass nicht das der Anzeige dieser Uhr ist. Ein
    /// GIF in anderer Groesse landet nicht pixelgenau (auf der TC002 kleiner als
    /// 26 x 8 vergroessert, sonst mittig oder abgeschnitten); gesendet wird es
    /// darum nicht.
    case massPasstNicht(bildBreite: Int, bildHoehe: Int, anzeigeBreite: Int, anzeigeHoehe: Int)
    /// Ein Name, den die Uhr nicht annimmt (`[A-Za-z0-9_-]{1,32}`, §8) — und der
    /// in einem MQTT-Thema ein Trennzeichen oder einen Platzhalter ergäbe.
    case ungueltigerName(String)
    /// `<Thema>/result` meldete `ok:false`; der Text nennt Code und Feld.
    case abgewiesen(String)

    public var errorDescription: String? {
        switch self {
        case .iconFormat(let typ):
            return lokf("Ein Icon schickt die App an die AWTRIX NG nur als GIF, dieses ist %@. Ein anderes wählen oder es ohne Icon schicken.", typ)
        case .zuGross(let bytes):
            return lokf("Diese Anzeige ist zu groß: %d KB, die Uhr nimmt höchstens 2 MB. Kürzeren Text oder weniger Bilder wählen.", (bytes + 1023) / 1024)
        case .keineAdresseFuerGrosse(let bytes):
            return lokf("Diese Anzeige ist mit %d KB zu groß für MQTT (höchstens 8 KB), und für die Uhr ist keine Adresse eingetragen, über die sie als HTTP-Anfrage ginge. Unter „Einstellungen“ die Adresse eintragen.", (bytes + 1023) / 1024)
        case .laufschriftZuLang(let bytes):
            return lokf("Diese Laufschrift ist zu lang: Ihr Bild wäre %d KB groß, die Uhr nimmt höchstens 56 KB. Den Text kürzen.", (bytes + 1023) / 1024)
        case .leer:
            return lok("Es gibt nichts zu senden.")
        case .massPasstNicht(let bb, let bh, let ab, let ah):
            return lokf("Dieses Bild ist %d × %d Punkte groß, die Anzeige dieser Uhr hat %d × %d. Es wurde nicht gesendet; ein Bild in der Größe der Anzeige wählen.", bb, bh, ab, ah)
        case .ungueltigerName(let name):
            return lokf("„%@“ ist kein Name, den die Uhr annimmt: erlaubt sind 1 bis 32 Zeichen aus Buchstaben, Ziffern, „_“ und „-“, und „active“ ist vergeben.", name)
        case .abgewiesen(let grund):
            return lokf("Die Uhr hat abgewiesen: %@", grund)
        }
    }
}

/// Was auf `<Thema>/result` stand.
///
/// Drei Faelle und nicht zwei: Keine Antwort ist selbst eine Auskunft — wer
/// gar nichts bekommt, hat ein Thema erwischt, das keine Route trifft. Dieser
/// Fall steht nicht hier drin, sondern darin, dass diese Antwort ausbleibt.
public enum NGErgebnis: Equatable, Sendable {
    /// Genau `{"ok":true}`.
    case gelungen
    /// `ok:false` samt Fehlercode und, falls genannt, dem Feld.
    case abgewiesen(String)
    /// Kein `ok` darin — das war keine Antwort auf ein Kommando.
    case unlesbar
}

/// Die Themen einer AWTRIX NG (`docs/awtrix-ng-protokoll.md` §3.2).
///
/// An einer Stelle und nicht im Sendeweg verteilt: Ein Thema, das keine
/// Route trifft, erzeugt bei NG gar keine Antwort — kein Fehler, keine
/// Bestaetigung. Ein Tippfehler waere damit unsichtbar, und die App ist
/// obendrein ihr eigener Mitleser: Sie hoerte ihre Sendung auf dem falschen
/// Thema zurueck und bestaetigte eine Anzeige, die es nie gegeben hat.
public enum NGThema {
    /// Eine benannte Anzeige setzen — und mit leerer Nutzlast loeschen (§3.2).
    public static func anzeige(praefix: String, name: String) -> String {
        "\(praefix)/cmd/apps/pushed/\(name)"
    }

    /// Auf eine Anzeige umschalten.
    public static func umschalten(praefix: String) -> String {
        "\(praefix)/cmd/apps/switch"
    }

    /// Eine Benachrichtigung einreihen (`POST /api/v1/notifications`).
    public static func benachrichtigung(praefix: String) -> String {
        "\(praefix)/cmd/notify"
    }

    /// Die sichtbare Benachrichtigung wegnehmen — oder, mit Namen, die benannte,
    /// auch eine wartende. Die Nutzlast wird ignoriert.
    public static func zurueckziehen(praefix: String, name: String? = nil) -> String {
        "\(praefix)/cmd/notify/dismiss" + (name.map { "/" + $0 } ?? "")
    }

    /// Eine Anzeige ein- oder ausschalten; die Nutzlast ist `true` oder `false`.
    public static func freigabe(praefix: String, name: String) -> String {
        "\(praefix)/cmd/apps/\(name)/enabled"
    }

    /// Vor und zurück in der Schleife; die Nutzlast wird ignoriert.
    public static func blaettern(praefix: String, vor: Bool) -> String {
        "\(praefix)/cmd/apps/" + (vor ? "next" : "previous")
    }

    /// Wo NG auf ein Kommando antwortet (§3.4). Erfolg ist genau
    /// `{"ok":true}`; bleibt die Antwort ganz aus, hat das Thema keine Route
    /// getroffen.
    public static func ergebnis(zu thema: String) -> String { thema + "/result" }

    /// Alles, was auf dieser Uhr an Anzeigen geschickt wird — auch von fremden
    /// Absendern.
    /// Die `/result`-Antworten fallen unter dasselbe Muster und werden beim
    /// Lesen am Suffix auseinandergehalten.
    public static func anzeigenMuster(praefix: String) -> String {
        "\(praefix)/cmd/apps/pushed/#"
    }

    /// Die Antworten auf Benachrichtigungen und ihr Zurückziehen. Das Muster
    /// trifft auch die Kommandos selbst; beim Lesen zählt das Suffix `/result`.
    public static func benachrichtigungenMuster(praefix: String) -> String {
        "\(praefix)/cmd/notify/#"
    }

    /// Die Antworten auf das Ein- und Ausschalten. `+` trifft den Namen; ein
    /// Muster auf `cmd/apps/#` hörte dagegen auch jede Sendung mit.
    public static func freigabeErgebnisse(praefix: String) -> String {
        "\(praefix)/cmd/apps/+/enabled/result"
    }

    /// Worauf ein `<Thema>/result` antwortet, in Worten für die Meldung — `nil`
    /// für alles, was kein Ergebnis eines Kommandos dieser App ist. Bei einer
    /// Anzeige ist es ihr Name, damit Meldungen und Frist unter demselben
    /// Schlüssel stehen.
    public static func ergebnisBezeichnung(thema: String, praefix: String) -> String? {
        let vorsilbe = "\(praefix)/cmd/"
        guard thema.hasPrefix(vorsilbe), thema.hasSuffix("/result") else { return nil }
        let teile = thema.dropFirst(vorsilbe.count).dropLast("/result".count)
            .split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        switch teile.count {
        case 3 where teile[0] == "apps" && teile[1] == "pushed" && !teile[2].isEmpty:
            return teile[2]
        case 3 where teile[0] == "apps" && teile[2] == "enabled" && !teile[1].isEmpty:
            return lokf("Schalter „%@“", teile[1])
        case 1 where teile[0] == "notify":
            return lok("Nachricht")
        case 2 where teile[0] == "notify" && teile[1] == "dismiss":
            return lok("Nachricht zurückziehen")
        case 3 where teile[0] == "notify" && teile[1] == "dismiss" && !teile[2].isEmpty:
            return lokf("Nachricht „%@“ zurückziehen", teile[2])
        default:
            return nil
        }
    }

    /// `online` bzw. — als Last Will — `offline`, aufbewahrt (§3.5).
    public static func erreichbarkeit(praefix: String) -> String { "\(praefix)/availability" }
}

/// Aus `Meldungsoptionen` wird die Nutzlast einer AWTRIX-NG-Anzeige
/// (`docs/awtrix-ng-protokoll.md` §5).
///
/// Eine reine Funktion. Sie schickt nichts, liest
/// nichts von der Platte und kennt weder Kanal noch Uhr — geprueft wird sie
/// byteweise gegen die Geraetereferenz.
///
/// Was hier nicht steht, ist so wichtig wie das, was dasteht: kein
/// `scroll.mode`, kein `whenFits`, kein `font`. Die Vorgaben von NG
/// (`wrap`, `static`, `small`) sind das gewuenschte Verhalten — der Text
/// laeuft, wenn er nicht passt, und steht sonst still. Ein mitgeschickter Wert waere eine zweite Entscheidung
/// ueber dieselbe Sache.
public enum NGNutzlast {
    /// Dasselbe Wort, dieselbe Geschwindigkeit — auf jeder Uhr.
    ///
    /// `scroll.speed` ist bei NG ein Prozentsatz der Grundgeschwindigkeit von
    /// rund 21 Pixeln je Sekunde (§5.2); unsere drei Stufen sind Standzeiten je
    /// Einzelbild und ergeben 8, 12 und 18 Pixel je Sekunde. Umgerechnet wird
    /// auf die Geschwindigkeit, nicht auf `mittel` als Mitte (100): Das
    /// erhaelt zwar das Verhaeltnis der drei Stufen zueinander, nicht aber die
    /// Geschwindigkeit — `mittel` liefe mit 21 statt 12 Pixeln je
    /// Sekunde, fast doppelt so schnell, und die
    /// Vorschau (die mit unseren Standzeiten abspielt) laege bei NG
    /// systematisch zu langsam.
    ///
    /// Umgerechnet auf die Geschwindigkeit ergibt das 40 · 60 · 87 Prozent —
    /// die Lesbarkeitsgrenze (200 auf acht Pixeln Hoehe) ist damit weit
    /// unterschritten.
    public static func tempo(_ t: Lauftempo) -> Int {
        let unsere = 1.0 / t.bilddauer   // Pixel je Sekunde, ein Pixel je Bild
        return Int((unsere / AwtrixNG.grundgeschwindigkeit * 100).rounded())
    }

    /// Das Icon so, wie es in `icon` steht: als Data-URL `data:image/gif;base64,…`.
    ///
    /// NG entscheidet nach der Form (§5.3): bis 64 Zeichen eine Kennung im
    /// Dateisystem der Uhr, eine Data-URL das Bild selbst, reines Base64 ohne
    /// Vorsatz ist `422`. Unsere Icons liegen in der App, nicht unter `/ICONS`
    /// der Uhr, also geht das Bild mit.
    ///
    /// Nur GIF: NG liest kein PNG (die Data-URL wird abgewiesen) und schneidet
    /// ein JPEG auf 8 × 8 zu; beides faellt sonst still auf „kein Icon" oder auf
    /// ein falsches Bild. Die Gegenseite (`Pixelweg.alsGIF`) wandelt vorher um.
    public static func icon(ausDatenURI uri: String) throws -> String {
        let teile = uri.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        guard teile.count == 2, teile[0].hasPrefix("data:") else { return uri }
        let kopf = teile[0].lowercased()
        guard kopf.hasPrefix("data:image/gif;base64") else {
            if kopf.contains("image/png") { throw NGFehler.iconFormat("PNG") }
            if kopf.contains("image/jpeg") { throw NGFehler.iconFormat("JPEG") }
            throw NGFehler.iconFormat(String(kopf.dropFirst("data:".count)
                .replacingOccurrences(of: ";base64", with: "")))
        }
        return uri
    }

    /// Die Anzeige als JSON. Die Reihenfolge der Schluessel ist festgelegt,
    /// damit die Schnappschusstests Bytes vergleichen koennen und nicht Mengen.
    ///
    /// `textfarbeAusPalette`: `textColor` ist dann `"palette"` statt der Farbe
    /// der Regler (§5.1).
    public static func anzeige(_ o: Meldungsoptionen, iconDatenURI: String? = nil,
                               textfarbeAusPalette: Bool = false) throws -> String {
        var teile: [String] = []
        // Nicht `gesendeterText`. Unser `uppercased()` macht aus „ß" ein
        // „SS"; NG versalisiert selbst und erhaelt dabei die Zeichen. Der
        // Schalter wandert deshalb nach `textCase`, der Text bleibt, wie er
        // eingetippt wurde.
        teile.append(#""text":"\#(jsonEscape(o.text))""#)
        // Ausdruecklich in beide Richtungen: Am gemessenen Geraet steht die
        // globale Einstellung `uppercase` auf `true`. Ohne `asTyped` kaeme also
        // auch bei ausgeschaltetem Schalter Versalschrift heraus.
        teile.append(#""textCase":"\#(o.grossbuchstaben ? "upper" : "asTyped")""#)
        teile.append(textfarbeAusPalette ? #""textColor":"palette""#
                                         : #""textColor":"\#(jsonEscape(o.farbe))""#)
        // Ebenfalls ausdruecklich: NGs Vorgabe ist `true`, unsere ist
        // linksbuendig. Rechtsbuendig kennt NG nicht — die Ansicht bietet es
        // dort gar nicht erst an (`AwtrixNG.waagrechteAusrichtungen`), und
        // wer eine alte Einstellung mitbringt, bekommt linksbuendig statt
        // einer stillen Umdeutung nach mittig.
        teile.append(#""textCenter":\#(o.waagrecht == .mittig)"#)
        teile.append(#""scroll":{"speed":\#(tempo(o.tempo))}"#)
        if let iconDatenURI, !iconDatenURI.isEmpty {
            teile.append(#""icon":"\#(jsonEscape(try icon(ausDatenURI: iconDatenURI)))""#)
            // `push` holt das Icon in jedem Laufdurchgang zurueck — das ist
            // die Frage, die „Icon mitlaufen lassen" stellt. `fixed` laesst es
            // stehen und den Text daran vorbeilaufen.
            teile.append(#""iconMode":"\#(o.iconLaeuftMit ? "push" : "fixed")""#)
        }
        // Millisekunden, nicht Sekunden. Ein mitgeschicktes `duration` waere ein unbekannter oberster Schluessel
        // und damit `422 validationFailed` — laut, aber nur auf `/result`.
        if let dauer = o.dauer { teile.append(#""durationMs":\#(dauer * 1000)"#) }
        return "{" + teile.joined(separator: ",") + "}"
    }

    /// Hängt Felder an ein fertiges JSON-Objekt, ohne es neu zu bauen: Der
    /// Pixelweg setzt sein JSON selbst zusammen, und die Schnappschusstests
    /// vergleichen Bytes.
    static func ergaenzt(_ json: String, um felder: [String]) -> String {
        guard !felder.isEmpty, json.hasSuffix("}") else { return json }
        return String(json.dropLast()) + "," + felder.joined(separator: ",") + "}"
    }

    /// `lifetimeMs` und `lifetimeExpiry` (§5.4) — ausdrücklich in beide
    /// Richtungen, damit eine Anzeige nicht von einer Vorgabe der Uhr abhängt.
    static func lebensdauerfelder(_ l: Lebensdauer) -> [String] {
        [#""lifetimeMs":\#(l.sekunden * 1000)"#, #""lifetimeExpiry":"\#(l.ablauf.ng)""#]
    }

    /// Der Rumpf zum Umschalten — als JSON und nicht als blanker Name.
    ///
    /// Ueber MQTT nimmt NG beides. Ueber HTTP ist `Content-Type:
    /// application/json` bei `PUT` Pflicht, und ein blanker Name waere keines.
    /// Ein Rumpf fuer beide Wege haelt zugleich die Zusicherung aus §3 ein:
    /// Die Nutzlast eines Kommandos ist byteweise dieselbe wie der Rumpf der
    /// entsprechenden HTTP-Anfrage.
    public static func umschalten(auf name: String) -> String {
        #"{"name":"\#(jsonEscape(name))"}"#
    }

    /// Was NG auf `<Thema>/result` geantwortet hat (§3.4).
    ///
    /// Geprueft wird auf `code`, nie auf `message` — das ist englische Prosa
    /// fuer Menschen, `code` ist maschinenlesbar und stabil.
    public static func ergebnis(_ daten: Data) -> NGErgebnis {
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any],
              let ok = woerterbuch["ok"] as? Bool else { return .unlesbar }
        guard !ok else { return .gelungen }
        let fehler = woerterbuch["error"] as? [String: Any]
        guard let code = fehler?["code"] as? String else { return .abgewiesen(lok("ohne Begründung")) }
        // Der Code bleibt stehen (er ist es, nach dem man sucht); davor in Worten,
        // was er heisst.
        let genannt = codeText(code).map { lokf("%@: %@", $0, code) } ?? code
        if let feld = fehler?["field"] as? String, !feld.isEmpty {
            return .abgewiesen(lokf("%@, Feld „%@“", genannt, feld))
        }
        return .abgewiesen(genannt)
    }

    /// Die Fehlercodes, die NG ueber MQTT meldet (§3.4).
    private static func codeText(_ code: String) -> String? {
        switch code {
        case "invalidJson": return lok("Kein gültiges JSON")
        case "validationFailed": return lok("Ungültiger Wert")
        case "notFound": return lok("Nicht gefunden")
        case "insufficientStorage": return lok("Speicher der Uhr voll")
        case "unavailable": return lok("Nicht verfügbar")
        case "internalError": return lok("Fehler in der Uhr")
        case "invalidName": return lok("Ungültiger Name")
        default: return nil
        }
    }
}
