import Foundation

/// Was auf dem Weg zu einer AWTRIX NG schiefgehen kann, **bevor** etwas
/// abgeschickt ist.
///
/// Beide Faelle haetten auf dem Geraet dasselbe Ergebnis: nichts. NG antwortet
/// auf ein Thema, das keine Route trifft, gar nicht, und ein Icon in einem
/// Format, das es nicht liest, faellt still auf „kein Icon" zurueck
/// (`docs/awtrix-ng-protokoll.md` §3.3, §5.3). Dieses Projekt ist auf der
/// Einsicht gebaut, dass ein Sender ohne Rueckkanal nichts beweist — also wird
/// hier gesagt, was nicht geht, statt es zu schicken und zu hoffen.
public enum NGFehler: Error, LocalizedError {
    /// Eine Sendung ohne Meldungsoptionen — ein gemaltes Bild, eine Bildersammlung.
    case keinPixelweg
    /// Ein Icon in einem Format, das NG nicht liest.
    case iconFormat(String)
    /// Ein Icon, das hoeher ist als die acht Zeilen von NG.
    case iconZuHoch(kante: Int)

    public var errorDescription: String? {
        switch self {
        case .keinPixelweg:
            return lok("Ein gemaltes Bild lässt sich nicht an eine AWTRIX NG schicken: Gemalt wird auf 52 × 16, ihre Anzeige ist 32 × 8. Sie nimmt Text, kein Pixelfeld.")
        case .iconFormat(let typ):
            return lokf("Die AWTRIX NG liest nur GIF und JPEG, dieses Icon ist %@. Ein anderes wählen oder es ohne Icon schicken.", typ)
        case .iconZuHoch(let kante):
            return lokf("Ein %d × %d-Icon passt nicht auf eine AWTRIX NG: Ihre Anzeige hat acht Zeilen, und ein zu hohes GIF spielt dort gar nicht. Ein 8 × 8-Icon wählen oder ohne Icon schicken.", kante, kante)
        }
    }
}

/// Was auf `<Thema>/result` stand.
///
/// Drei Faelle und nicht zwei: **Keine Antwort ist selbst eine Auskunft** — wer
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
/// An einer Stelle und nicht im Sendeweg verteilt: **Ein Thema, das keine
/// Route trifft, erzeugt bei NG gar keine Antwort** — kein Fehler, keine
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
    /// `{"ok":true}`; **bleibt die Antwort ganz aus, hat das Thema keine Route
    /// getroffen.**
    public static func ergebnis(zu thema: String) -> String { thema + "/result" }

    /// Alles, was auf dieser Uhr an Anzeigen geschickt wird — auch von fremden
    /// Absendern. Das Gegenstueck zu `<praefix>/custom/#` der Werksfirmware.
    /// Die `/result`-Antworten fallen unter dasselbe Muster und werden beim
    /// Lesen am Suffix auseinandergehalten.
    public static func anzeigenMuster(praefix: String) -> String {
        "\(praefix)/cmd/apps/pushed/#"
    }

    /// `online` bzw. — als Last Will — `offline`, aufbewahrt (§3.5). Das
    /// Gegenstueck zu `<praefix>/status` der Werksfirmware.
    public static func erreichbarkeit(praefix: String) -> String { "\(praefix)/availability" }
}

/// Aus `Meldungsoptionen` wird die Nutzlast einer AWTRIX-NG-Anzeige
/// (`docs/awtrix-ng-protokoll.md` §5).
///
/// **Eine reine Funktion, wie `Frame.alsJSON()`.** Sie schickt nichts, liest
/// nichts von der Platte und kennt weder Kanal noch Uhr — geprueft wird sie
/// byteweise gegen die Geraetereferenz.
///
/// Was hier **nicht** steht, ist so wichtig wie das, was dasteht: kein
/// `scroll.mode`, kein `whenFits`, kein `font`. Die Vorgaben von NG
/// (`wrap`, `static`, `small`) sind genau das Verhalten, das diese App auf der
/// Werksfirmware von Hand nachbaut — der Text laeuft, wenn er nicht passt, und
/// steht sonst still. Ein mitgeschickter Wert waere eine zweite Entscheidung
/// ueber dieselbe Sache.
public enum NGNutzlast {
    /// **Dasselbe Wort, dieselbe Geschwindigkeit — auf jeder Uhr.**
    ///
    /// `scroll.speed` ist bei NG ein Prozentsatz der Grundgeschwindigkeit von
    /// rund 21 Pixeln je Sekunde (§5.2); unsere drei Stufen sind Standzeiten je
    /// Einzelbild und ergeben 8, 12 und 18 Pixel je Sekunde. Umgerechnet wird
    /// deshalb auf die **Geschwindigkeit** — das ergibt 40 · 60 · 87 Prozent.
    ///
    /// Bis zum 18.09.2026 stand hier die Vorgabe des Geraets als Mitte:
    /// `mittel` war die 100. Das erhielt das Verhaeltnis der drei Stufen
    /// zueinander, nicht aber die Geschwindigkeit — auf einer NG lief `mittel`
    /// mit 21 statt 12 Pixeln je Sekunde, also fast doppelt so schnell wie
    /// dasselbe `mittel` auf der Werksfirmware. Zwei Uhren nebeneinander
    /// zeigten denselben Text verschieden schnell, und die Vorschau, die mit
    /// **unseren** Standzeiten abspielt, log bei NG systematisch zu langsam.
    ///
    /// Die Lesbarkeitsgrenze (200 auf acht Pixeln Hoehe) ist damit weit
    /// unterschritten.
    public static func tempo(_ t: Lauftempo) -> Int {
        let unsere = 1.0 / t.bilddauer   // Pixel je Sekunde, ein Pixel je Bild
        return Int((unsere / Geraetetyp.ngGrundgeschwindigkeit * 100).rounded())
    }

    /// Base64 eines Icons ohne den `data:…;base64,`-Vorsatz.
    ///
    /// **NG entscheidet allein nach der Laenge** (§5.3): bis 64 Zeichen eine
    /// Kennung im Dateisystem des Geraets, darueber Base64 unmittelbar im
    /// Text. Bliebe der Vorsatz stehen, waere es zwar weiter lang genug — aber
    /// die Bytes danach waeren kein Bild.
    ///
    /// PNG wird abgewiesen statt stillschweigend geschickt: NG liest nur GIF
    /// und JPEG und faellt sonst auf die Anordnung **ohne** Icon zurueck, ohne
    /// etwas zu melden.
    public static func icon(ausDatenURI uri: String) throws -> String {
        let teile = uri.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        guard teile.count == 2, teile[0].hasPrefix("data:") else { return uri }
        let kopf = teile[0].lowercased()
        if kopf.contains("image/png") { throw NGFehler.iconFormat("PNG") }
        guard kopf.contains("image/gif") || kopf.contains("image/jpeg") else {
            throw NGFehler.iconFormat(String(kopf.dropFirst("data:".count)
                .replacingOccurrences(of: ";base64", with: "")))
        }
        return String(teile[1])
    }

    /// Die Anzeige als JSON. Die Reihenfolge der Schluessel ist festgelegt,
    /// damit die Schnappschusstests Bytes vergleichen koennen und nicht Mengen.
    public static func anzeige(_ o: Meldungsoptionen, iconDatenURI: String? = nil,
                               iconKante: Int = 8) throws -> String {
        var teile: [String] = []
        // **Nicht `gesendeterText`.** Unser `uppercased()` macht aus „ß" ein
        // „SS"; NG versalisiert selbst und erhaelt dabei die Zeichen. Der
        // Schalter wandert deshalb nach `textCase`, der Text bleibt, wie er
        // eingetippt wurde.
        teile.append(#""text":"\#(jsonEscape(o.text))""#)
        // Ausdruecklich in **beide** Richtungen: Am gemessenen Geraet steht die
        // globale Einstellung `uppercase` auf `true`. Ohne `asTyped` kaeme also
        // auch bei ausgeschaltetem Schalter Versalschrift heraus.
        teile.append(#""textCase":"\#(o.grossbuchstaben ? "upper" : "asTyped")""#)
        teile.append(#""textColor":"\#(jsonEscape(o.farbe))""#)
        // Ebenfalls ausdruecklich: NGs Vorgabe ist `true`, unsere ist
        // linksbuendig. Rechtsbuendig kennt NG nicht — die Ansicht bietet es
        // dort gar nicht erst an (`Geraetetyp.waagrechteAusrichtungen`), und
        // wer eine alte Einstellung mitbringt, bekommt linksbuendig statt
        // einer stillen Umdeutung nach mittig.
        teile.append(#""textCenter":\#(o.waagrecht == .mittig)"#)
        teile.append(#""scroll":{"speed":\#(tempo(o.tempo))}"#)
        if let iconDatenURI, !iconDatenURI.isEmpty {
            // **Acht Zeilen sind acht Zeilen.** Ein GIF, dessen erstes Bild
            // hoeher ist als die Leinwand, spielt auf NG ueberhaupt nicht (§8)
            // — ohne Meldung, ohne Fehler. Ein 16×16-Icon ist dort also nicht
            // bloss zu gross, es faellt aus.
            guard Geraetetyp.awtrixNG.iconKanten.contains(iconKante) else {
                throw NGFehler.iconZuHoch(kante: iconKante)
            }
            teile.append(#""icon":"\#(jsonEscape(try icon(ausDatenURI: iconDatenURI)))""#)
            // `push` holt das Icon in jedem Laufdurchgang zurueck — das ist
            // die Frage, die „Icon mitlaufen lassen" stellt. `fixed` laesst es
            // stehen und den Text daran vorbeilaufen.
            teile.append(#""iconMode":"\#(o.iconLaeuftMit ? "push" : "fixed")""#)
        }
        // Sekunden bei der Werksfirmware, **Millisekunden** bei NG. Ein
        // mitgeschicktes `duration` waere ein unbekannter oberster Schluessel
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
