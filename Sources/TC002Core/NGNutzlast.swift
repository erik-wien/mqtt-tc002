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
    public static func anzeige(_ o: Meldungsoptionen, iconDatenURI: String? = nil) throws -> String {
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
        teile.append(#""textColor":"\#(jsonEscape(o.farbe))""#)
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
        let code = fehler?["code"] as? String ?? lok("ohne Begründung")
        if let feld = fehler?["field"] as? String, !feld.isEmpty {
            return .abgewiesen(lokf("%@ (%@)", code, feld))
        }
        return .abgewiesen(code)
    }
}
