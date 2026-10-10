import Foundation

/// Die Steuerung der virtuellen NG-Uhr: Einstellungen mit ihren Bereichen
/// (§10), Moodlight (§4.2) und der Vertrauensstand für MQTT über TLS (§11.1).
extension VirtuelleNGUhr {
    /// Wie ein Einstellungswert aussieht (§10). Unabhängig von `Geraeteeinstellung`
    /// im Kern geschrieben: Die virtuelle Uhr ist die Gegenprobe, und eine
    /// gemeinsame Tabelle prüfte sich nur selbst.
    private indirect enum Regel {
        case wahrheit, zahl, farbe, farbeOderNull
        case ganz(ClosedRange<Int>)
        case wort([String])
        /// Ein Name aus einer Liste von `capabilities`, Groß-/Kleinschreibung gleich.
        case liste(String)
        case objekt([String: Regel])
        case wochentage
    }

    private static let wochentagsleiste: Regel = .objekt([
        "show": .wahrheit, "startOnMonday": .wahrheit, "weekendDays": .wochentage,
        "activeColor": .farbe, "inactiveColor": .farbe,
        "weekendActiveColor": .farbe, "weekendInactiveColor": .farbe,
    ])

    private static let regeln: [String: Regel] = [
        "brightness": .ganz(0...255), "autoBrightness": .wahrheit,
        "saturation": .ganz(0...100), "gamma": .zahl,
        "colorCorrection": .farbeOderNull, "colorTint": .farbeOderNull,
        "textColor": .farbe, "uppercase": .wahrheit, "enlargeApps": .wahrheit,
        "scroll": .objekt(["mode": .wort(["static", "wrap", "loop", "bounce"]),
                           "direction": .wort(["left", "right"]),
                           "entry": .wort(["inline", "offscreen"]),
                           "whenFits": .wort(["static", "scroll"]),
                           "speed": .ganz(0...Int(Int32.max)), "gap": .ganz(0...Int(Int32.max)),
                           "holdMs": .ganz(0...Int(Int32.max))]),
        "autoTransition": .wahrheit, "appDurationMs": .ganz(0...Int(Int32.max)),
        "transitionEffect": .liste("transitions"),
        "transitionDirection": .wort(["normal", "reverse"]),
        "transitionDurationMs": .ganz(0...2147483647),
        "clockFace": .liste("clockFaces"),
        "timeColor": .farbeOderNull, "dateColor": .farbeOderNull,
        "calendarHeaderColor": .farbe, "calendarTextColor": .farbe, "calendarBodyColor": .farbe,
        "calendarAnimation": .wahrheit, "timeMode": .ganz(0...6),
        "time24h": .wahrheit, "timeLeadingZero": .wahrheit, "timeShowSeconds": .wahrheit,
        "timeShowAmPm": .wahrheit, "timeSeparatorMode": .wort(["steady", "blink", "pulse"]),
        "dateOrder": .wort(["dayMonthYear", "monthDayYear", "yearMonthDay"]),
        "dateSeparator": .wort(["dot", "slash", "dash"]),
        "dateYearMode": .wort(["none", "twoDigit", "fourDigit"]),
        "dateShowWeekday": .wahrheit, "dateMonthNames": .wahrheit,
        "weekdayBar": wochentagsleiste, "dateWeekdayBar": wochentagsleiste,
        "useCelsius": .wahrheit, "temperatureColor": .farbeOderNull,
        "humidityColor": .farbeOderNull, "batteryColor": .farbeOderNull,
        "volume": .ganz(0...100), "radioVolume": .ganz(0...100), "appVolume": .ganz(0...100),
        "alertVolume": .ganz(0...100), "bootSound": .wahrheit,
        "musicSource": .wort(["auto", "playback", "microphone"]),
        "blockNavigation": .wahrheit,
    ]

    /// Der Wert in der Schreibweise, die die Uhr behält, oder die Antwort `422`.
    private static func einstellungspruefung(_ regel: Regel, _ v: JSONWert,
                                             feld: String) -> (JSONWert?, Antwort?) {
        func falsch(_ meldung: String) -> (JSONWert?, Antwort?) { (nil, ungueltig(meldung, feld: feld)) }
        switch regel {
        case .wahrheit:
            guard case .bool = v else { return falsch("wrong type") }
            return (v, nil)
        case .zahl:
            guard case .zahl(let d) = v else { return falsch("wrong type") }
            return d > 0 ? (v, nil) : falsch("out of range")
        case .ganz(let bereich):
            guard case .zahl = v else { return falsch("wrong type") }
            guard let n = v.ganzzahl else { return falsch("must be an integer") }
            return bereich.contains(n) ? (v, nil) : falsch("out of range")
        case .farbe, .farbeOderNull:
            if case .null = v, case .farbeOderNull = regel { return (v, nil) }
            guard let hex = farbe(v) else { return falsch("invalid color") }
            return (.text(hex), nil)
        case .wort(let liste):
            guard case .text(let t) = v else { return falsch("wrong type") }
            return liste.contains(t) ? (v, nil) : falsch("unknown value")
        case .liste(let name):
            guard case .text(let t) = v else { return falsch("wrong type") }
            guard case .objekt(let o) = capabilities, case .liste(let l)? = o[name],
                  let treffer = l.first(where: {
                      if case .text(let x) = $0 { return x.lowercased() == t.lowercased() } else { return false }
                  }) else { return falsch("unknown value") }
            return (treffer, nil)
        case .wochentage:
            guard case .liste(let l) = v else { return falsch("wrong type") }
            let tage = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            let gut = l.allSatisfy { if case .text(let t) = $0 { return tage.contains(t) } else { return false } }
            return gut ? (v, nil) : falsch("unknown value")
        case .objekt(let felder):
            guard case .objekt(let o) = v else { return falsch("wrong type") }
            var ergebnis: [String: JSONWert] = [:]
            for (k, teil) in o {
                guard let r = felder[k] else { return (nil, ungueltig("unknown field", feld: feld + "." + k)) }
                let (w, fehler) = einstellungspruefung(r, teil, feld: feld + "." + k)
                if let fehler { return (nil, fehler) }
                ergebnis[k] = w
            }
            return (.objekt(ergebnis), nil)
        }
    }

    /// `PATCH /api/v1/settings`: erst alles prüfen, dann schreiben.
    ///
    /// ❓ Ob die Uhr ein Teilobjekt (`scroll`, `weekdayBar`) mit dem gespeicherten
    /// zusammenführt oder ersetzt, steht nicht in der Doku; die Emulation führt
    /// zusammen. Die App schickt darum immer das ganze Objekt.
    static func einstellungenAendern(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let neu) = wert else { return ungueltig("body required") }
        var zu: [String: JSONWert] = [:]
        for schluessel in neu.keys.sorted() {
            guard let alt = z.einstellungen[schluessel], let v = neu[schluessel] else {
                return ungueltig("unknown field", feld: schluessel)
            }
            guard let regel = regeln[schluessel] else {
                switch (alt, v) {
                case (.null, _), (.bool, .bool), (.zahl, .zahl), (.text, .text),
                     (.liste, .liste), (.objekt, .objekt):
                    zu[schluessel] = v
                    continue
                default:
                    return ungueltig("wrong type", feld: schluessel)
                }
            }
            let (w, fehler) = einstellungspruefung(regel, v, feld: schluessel)
            if let fehler { return fehler }
            if case .objekt(let teil)? = w, case .objekt(let bisher) = alt {
                zu[schluessel] = .objekt(bisher.merging(teil) { _, n in n })
            } else {
                zu[schluessel] = w
            }
        }
        for (k, v) in zu { z.einstellungen[k] = v }
        return json(.objekt(z.einstellungen))
    }

    // MARK: - Moodlight

    /// Kelvin → `#RRGGBB` nach der gängigen Näherung (Tanner Helland). ❓ Die
    /// Firmware nennt ihre Umrechnung nicht.
    static func kelvinfarbe(_ kelvin: Int) -> String {
        let t = Double(kelvin) / 100
        func kanal(_ w: Double) -> Int { Int(min(max(w, 0), 255).rounded()) }
        let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        return String(format: "#%02X%02X%02X", kanal(r), kanal(g), kanal(b))
    }

    /// `PUT`/`DELETE /api/v1/display/moodlight` (§4.2).
    static func moodlight(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        if a.methode == "DELETE" { z.moodlight = nil; return ok }
        let leer = a.koerper.allSatisfy { $0 == 32 || $0 == 10 || $0 == 13 || $0 == 9 }
        guard !leer else { return ungueltig("body required") }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let o) = wert, !o.isEmpty else { return ungueltig("body required") }
        var neu = z.moodlight ?? NGMoodlight()
        // Kelvin gewinnt über die Farbe; fehlende Felder behalten ihren Wert.
        if let k = o["kelvin"] {
            // ❓ Dass der Bereich geprüft wird, steht nicht da (die Helligkeit wird es nicht).
            guard let n = k.ganzzahl else { return ungueltig("must be a number", feld: "kelvin") }
            guard (1000...40000).contains(n) else { return ungueltig("out of range", feld: "kelvin") }
            neu.farbe = kelvinfarbe(n)
        } else if let c = o["color"] {
            guard let hex = farbe(c) else { return ungueltig("invalid color", feld: "color") }
            neu.farbe = hex
        }
        if let b = o["brightness"] {
            guard let n = b.ganzzahl else { return ungueltig("must be a number", feld: "brightness") }
            // Gemessen: nicht geprüft, 300 wird zu 44, 256 zu 0 — ein Byte.
            neu.helligkeit = n & 255
        }
        z.moodlight = neu
        return ok
    }

    // MARK: - MQTT über TLS

    /// `GET /api/v1/mqtt/tls` (§11.1). ❓ Gemessen ist nur `public`/`null`; der Wert
    /// nach einem Hochladen ist erfunden.
    static func tlsStand(_ z: NGUhrzustand) -> JSONWert {
        .objekt(["ca": .text(z.eigeneCA ? "custom" : "public"), "pending": .null])
    }

    /// `PUT`/`DELETE /api/v1/mqtt/tls/ca`. ❓ Dass ein Rumpf ohne PEM-Block `422`
    /// ist und was das `PUT` antwortet, steht nicht da; die Grenze von 65536 Byte
    /// und die Antwort des `DELETE` (der Stand) schon.
    static func tlsCA(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        if a.methode == "DELETE" { z.eigeneCA = false; return json(tlsStand(z)) }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let o) = wert, case .text(let pem)? = o["certificate"] else {
            return ungueltig("body required", feld: "certificate")
        }
        guard pem.utf8.count <= 65536 else { return ungueltig("certificate too large", feld: "certificate") }
        guard pem.contains("-----BEGIN CERTIFICATE-----") else {
            return ungueltig("invalid certificate", feld: "certificate")
        }
        z.eigeneCA = true
        return json(tlsStand(z))
    }
}
