import Foundation

/// Layouts (`docs/awtrix-ng-protokoll.md` §9) und die obersten Schlüssel einer
/// Nutzlast in der virtuellen NG-Uhr: prüfen, wie die Uhr es tut, und in den
/// Bildspeicher zeichnen.
///
/// Gezeichnet wird, soweit es plausibel ist, nicht firmwaregenau: Text mit
/// der Pixelschrift der App (die Uhr hat eine eigene), Diagramme und Fortschritt
/// als einfache Pixelbilder, Zeichenbefehle genau (bis auf Kreise, ❓ §6 nennt das
/// Verfahren nicht). Effekt und Overlay sind nicht dargestellt. Ein Text, der
/// läuft, steht im ersten Bild an seinem Startanker.
extension VirtuelleNGUhr {
    // MARK: - Oberste Schlüssel

    /// Alles, was §5 für eine Anzeige oder Benachrichtigung auflistet, dazu
    /// `textCenter`, das NG 1.2.2 weiter annimmt (gemessen 09.10.2026). Jeder
    /// andere oberste Schlüssel ist `422`, `field` = der Schlüssel (§5.8).
    static let anzeigeschluessel: Set<String> = [
        "text", "textCase", "font", "textColor", "textBlinkMs", "textFadeMs", "textAlign", "textCenter",
        "scroll", "textOffsetX", "textInFront", "icon", "iconMode", "iconOffsetX", "iconGap", "icons",
        "durationMs", "lifetimeMs", "lifetimeExpiry", "repeat", "backgroundColor", "barChart", "lineChart",
        "chartAutoscale", "chartColor", "progress", "progressColor", "progressTrackColor", "effect",
        "effectSpeed", "palette", "paletteBlend", "paletteSpan", "paletteSpeed", "overlay", "layout", "draw",
    ]

    static func pruefeSchluessel(_ o: [String: JSONWert]) -> Antwort? {
        guard let falsch = o.keys.sorted().first(where: {
            !anzeigeschluessel.contains($0) && !nurFuerBenachrichtigungen.contains($0)
        }) else { return nil }
        return ungueltig("unknown field", feld: falsch)
    }

    // MARK: - Zeichenbefehle

    /// Befehl → (Zahl der Argumente nach dem Namen, davon vorn ganzzahlige Koordinaten) (§6).
    private static let befehle: [String: (anzahl: ClosedRange<Int>, koordinaten: Int)] = [
        "pixel": (2...3, 2), "line": (4...5, 4), "rect": (4...5, 4), "rectFill": (4...5, 4),
        "circle": (3...4, 3), "circleFill": (3...4, 3), "text": (3...4, 2), "bitmap": (5...5, 4),
    ]

    /// `422`, `field` = `draw[<i>]` bei unbekanntem Befehl, falscher Argumentzahl,
    /// nicht numerischer Koordinate oder `pixels` mit ungerader Koordinatenzahl
    /// (§5.8).
    static func pruefeZeichenbefehle(_ w: JSONWert, feld: String) -> Antwort? {
        guard case .liste(let liste) = w else { return ungueltig("must be an array", feld: feld) }
        for (i, b) in liste.enumerated() {
            let stelle = "\(feld)[\(i)]"
            guard case .liste(let teile) = b, case .text(let name)? = teile.first else {
                return ungueltig("invalid draw command", feld: stelle)
            }
            let a = Array(teile.dropFirst())
            if name == "pixels" {
                guard !a.isEmpty, a.dropFirst().count % 2 == 0, a.dropFirst().allSatisfy({ $0.ganzzahl != nil }) else {
                    return ungueltig("invalid draw command", feld: stelle)
                }
                continue
            }
            guard let regel = befehle[name], regel.anzahl.contains(a.count),
                  a.prefix(regel.koordinaten).allSatisfy({ $0.ganzzahl != nil }) else {
                return ungueltig("invalid draw command", feld: stelle)
            }
        }
        return nil
    }

    // MARK: - Layout prüfen

    private static let layoutSchluessel: Set<String> = [
        "version", "regions", "backgroundColor", "effect", "effectSpeed", "overlay",
        "palette", "paletteBlend", "paletteSpan", "paletteSpeed"]
    private static let regionSchluessel: Set<String> = [
        "id", "box", "text", "icon", "chart", "progress", "draw", "align", "valign", "font", "color",
        "palette", "paletteBlend", "paletteSpan", "paletteSpeed", "textColor", "scroll", "repeat",
        "textCase", "textBlinkMs", "textFadeMs", "trackColor"]
    private static let inhalte = ["text", "icon", "chart", "progress", "draw"]
    /// Neben `layout` gelten nur diese Schlüssel (§9.4).
    private static let neben: Set<String> = ["layout", "durationMs", "repeat", "lifetimeMs", "lifetimeExpiry"]

    private static func grenze(_ name: String) -> Int {
        if case .objekt(let c) = capabilities, case .objekt(let l)? = c["layouts"],
           case .objekt(let g)? = l["limits"], let n = g[name]?.ganzzahl { return n }
        return 0
    }

    /// Ob `scroll` einer Textregion sie laufen lässt (§9.3: außer `static`).
    private static func laeuft(_ r: [String: JSONWert]) -> Bool {
        switch r["scroll"] {
        case .text(let m)?: return m != "static"
        case .objekt(let o)?: return o["mode"] != .text("static")
        default: return true
        }
    }

    /// Prüft `layout` wie die Uhr (§9): Form, Kästen im Display, genau ein Inhalt
    /// je Region, die Grenzen aus `capabilities.layouts.limits`. Die Feldnamen
    /// folgen der Messung (`layout.regions[0].icon`).
    ///
    /// Annahmen (❓), wo die Doku schweigt: Eine leere Regionenliste ist gültig;
    /// ein fehlendes `version` ist gültig; ein Icon als Data-URL über 8192 Zeichen
    /// ist `invalid icon` (gemessen: 7508 angenommen, 8796 abgewiesen); ein
    /// Diagramm braucht mindestens einen Wert.
    static func pruefeLayout(_ w: JSONWert, daneben o: [String: JSONWert]) -> Antwort? {
        if let k = o.keys.sorted().first(where: { !neben.contains($0) && !nurFuerBenachrichtigungen.contains($0) }) {
            return ungueltig("not allowed with layout", feld: k)
        }
        guard case .objekt(let l) = w else { return ungueltig("must be an object", feld: "layout") }
        if let k = l.keys.sorted().first(where: { !layoutSchluessel.contains($0) }) {
            return ungueltig("unknown field", feld: "layout." + k)
        }
        if let v = l["version"], v.ganzzahl != 1 { return ungueltig("unsupported version", feld: "layout.version") }
        guard case .liste(let regionen)? = l["regions"] else {
            return ungueltig("must be an array", feld: "layout.regions")
        }
        guard regionen.count <= grenze("regions") else { return ungueltig("too many regions", feld: "layout.regions") }

        if let b = l["backgroundColor"], farbe(b) == nil { return ungueltig("invalid color", feld: "layout.backgroundColor") }
        if case .text(let e)? = l["effect"], !e.isEmpty {
            guard listeEnthaelt("effects", e) else { return ungueltig("unknown effect", feld: "layout.effect") }
            if l["backgroundColor"] != nil { return ungueltig("not allowed with backgroundColor", feld: "layout.effect") }
        }
        if case .text(let ov)? = l["overlay"], !ov.isEmpty, !listeEnthaelt("overlays", ov) {
            return ungueltig("unknown overlay", feld: "layout.overlay")
        }
        if let falsch = pruefePalette(l["palette"], feld: "layout.palette") { return falsch }

        var kennungen = Set<String>()
        var laufende = 0, icons = 0, textBytes = 0
        for (i, wert) in regionen.enumerated() {
            let pfad = "layout.regions[\(i)]"
            guard case .objekt(let r) = wert else { return ungueltig("must be an object", feld: pfad) }
            if let k = r.keys.sorted().first(where: { !regionSchluessel.contains($0) }) {
                return ungueltig("unknown field", feld: pfad + "." + k)
            }
            guard case .text(let id)? = r["id"], (1...64).contains(id.utf8.count), kennungen.insert(id).inserted else {
                return ungueltig("invalid id", feld: pfad + ".id")
            }
            guard case .liste(let k)? = r["box"], k.count == 4, k.allSatisfy({ $0.ganzzahl != nil }) else {
                return ungueltig("invalid box", feld: pfad + ".box")
            }
            let z = k.compactMap(\.ganzzahl)
            guard z[0] >= 0, z[1] >= 0, z[2] > 0, z[3] > 0, z[0] + z[2] <= breite, z[1] + z[3] <= hoehe else {
                return ungueltig("outside the display", feld: pfad + ".box")
            }
            let gesetzt = inhalte.filter { r[$0] != nil }
            guard gesetzt.count == 1, let art = gesetzt.first else {
                return ungueltig("exactly one content", feld: pfad)
            }
            switch art {
            case "text":
                switch r["text"] {
                case .text(let t)?: textBytes += t.utf8.count
                case .liste(let teile)?:
                    for teil in teile {
                        guard case .objekt(let to) = teil, case .text(let t)? = to["text"] ?? .text("") else {
                            return ungueltig("invalid text", feld: pfad + ".text")
                        }
                        if let c = to["color"], farbe(c) == nil { return ungueltig("invalid color", feld: pfad + ".text") }
                        textBytes += t.utf8.count
                    }
                default: return ungueltig("invalid text", feld: pfad + ".text")
                }
                if laeuft(r) { laufende += 1 }
            case "icon":
                icons += 1
                guard case .text(let s)? = r["icon"], !s.isEmpty, s.utf8.count <= 8192 else {
                    return ungueltig("invalid icon", feld: pfad + ".icon")
                }
                if s.hasPrefix("data:"), !s.hasPrefix("data:image/gif;base64,"), !s.hasPrefix("data:image/jpeg;base64,") {
                    return ungueltig("invalid icon", feld: pfad + ".icon")
                }
            case "chart":
                guard case .objekt(let c)? = r["chart"], case .liste(let werte)? = c["values"], !werte.isEmpty,
                      werte.allSatisfy({ $0.ganzzahl != nil }),
                      c["type"] == .text("line") || c["type"] == .text("bar") else {
                    return ungueltig("invalid chart", feld: pfad + ".chart")
                }
                if werte.count > grenze("chartPoints") { return ungueltig("too many values", feld: pfad + ".chart.values") }
                if (c["min"] == nil) != (c["max"] == nil) { return ungueltig("min and max go together", feld: pfad + ".chart") }
                if let u = c["min"]?.ganzzahl, let ob = c["max"]?.ganzzahl, u >= ob {
                    return ungueltig("min must be below max", feld: pfad + ".chart")
                }
            case "progress":
                guard let p = r["progress"]?.ganzzahl, (0...100).contains(p) else {
                    return ungueltig("invalid progress", feld: pfad + ".progress")
                }
            default:
                guard let d = r["draw"] else { break }
                if let falsch = pruefeZeichenbefehle(d, feld: pfad + ".draw") { return falsch }
            }
            for feld in ["align", "valign"] {
                if let a = r[feld], !["start", "center", "end"].contains(where: { a == .text($0) }) {
                    return ungueltig("invalid alignment", feld: pfad + "." + feld)
                }
            }
            for feld in ["color", "trackColor"] {
                if let c = r[feld], !(feld == "color" && c == .text("palette")), farbe(c) == nil {
                    return ungueltig("invalid color", feld: pfad + "." + feld)
                }
            }
            if r["color"] == .text("palette"), r["palette"] == nil, l["palette"] == nil {
                return ungueltig("palette required", feld: pfad + ".color")
            }
            if let falsch = pruefePalette(r["palette"], feld: pfad + ".palette") { return falsch }
        }
        if laufende > grenze("scrollers") { return ungueltig("too many scrolling texts", feld: "layout.regions") }
        if icons > grenze("assets") { return ungueltig("too many icons", feld: "layout.regions") }
        if textBytes > grenze("textBytes") { return ungueltig("text too long", feld: "layout.regions") }
        return nil
    }

    // MARK: - Layout zeichnen

    static func layoutBild(_ layout: [String: JSONWert], vorgabe: Int,
                           einstellungen: [String: JSONWert]) -> Brett {
        var bild = Brett(breite: breite, hoehe: hoehe)
        if let w = layout["backgroundColor"], let f = farbwert(w) {
            bild = Brett(breite: breite, hoehe: hoehe, fuellung: f)
        }
        guard case .liste(let regionen)? = layout["regions"] else { return bild }
        for region in regionen {
            guard case .objekt(let r) = region, case .liste(let kasten)? = r["box"] else { continue }
            let k = kasten.compactMap(\.ganzzahl)
            // Box und Ursprung kommen vom Absender; ein Feld in dieser
            // Groesse gaebe es nie, und es wuerde Speicher kosten.
            guard k.count == 4, k[2] > 0, k[3] > 0, k[2] <= 1024, k[3] <= 1024,
                  k[2] * k[3] <= 65536, abs(k[0]) <= 1024, abs(k[1]) <= 1024 else { continue }
            var farbe = vorgabe
            if let w = r["color"], let f = farbwert(w) { farbe = f }
            var brett = Brett(breite: k[2], hoehe: k[3])
            if case .liste(let befehle)? = r["draw"] {
                for befehl in befehle { zeichne(befehl, auf: &brett, farbe: farbe) }
            } else if case .text(let uri)? = r["icon"], let g = gifBild(uri) {
                // Dunkel in einem Bild ist schwarz, im ersten Bild sind
                // durchsichtige Pixel schwarz (§5.3); was nicht passt, wird
                // abgeschnitten (`setze`).
                let (ox, oy) = lage(g.breite, g.hoehe, in: brett, r)
                for y in 0..<g.hoehe {
                    for x in 0..<g.breite { brett.setze(ox + x, oy + y, g.punkte[y * g.breite + x]) }
                }
            } else if let p = r["progress"]?.ganzzahl {
                fortschritt(p, r, farbe: r["color"] == nil ? 0x00FF00 : farbe, auf: &brett)
            } else if case .objekt(let c)? = r["chart"] {
                diagramm(c, farbe: vorgabe, auf: &brett)
            } else if let t = r["text"] {
                text(t, r, farbe: farbe, einstellungen: einstellungen, auf: &brett)
            }
            for y in 0..<k[3] {
                for x in 0..<k[2] where brett.belegt[y * k[2] + x] {
                    bild.setze(k[0] + x, k[1] + y, brett.punkte[y * k[2] + x])
                }
            }
        }
        return bild
    }

    /// Oben links eines Inhalts in einem Kasten nach `align`/`valign`
    /// (Vorgabe mittig, §9.2).
    private static func lage(_ b: Int, _ h: Int, in brett: Brett, _ r: [String: JSONWert]) -> (Int, Int) {
        func achse(_ ausrichtung: JSONWert?, _ innen: Int, _ aussen: Int) -> Int {
            switch ausrichtung {
            case .text("start")?: return 0
            case .text("end")?: return aussen - innen
            default: return (aussen - innen) / 2
            }
        }
        return (achse(r["align"], b, brett.breite), achse(r["valign"], h, brett.hoehe))
    }

    /// Füllt von links; der Rest des Kastens ist die Spur (§9.3).
    private static func fortschritt(_ prozent: Int, _ r: [String: JSONWert], farbe: Int, auf brett: inout Brett) {
        let spur = r["trackColor"].flatMap(farbwert) ?? 0x202020
        let gefuellt = brett.breite * min(max(prozent, 0), 100) / 100
        for y in 0..<brett.hoehe {
            for x in 0..<brett.breite { brett.setze(x, y, x < gefuellt ? farbe : spur) }
        }
    }

    /// Balken wachsen von der Nulllinie, die Linie verbindet die Werte. Ohne
    /// `min`/`max` skaliert das Diagramm selbst und schließt die Null ein (§9.3).
    private static func diagramm(_ c: [String: JSONWert], farbe: Int, auf brett: inout Brett) {
        guard case .liste(let l)? = c["values"] else { return }
        let werte = l.compactMap(\.ganzzahl)
        guard !werte.isEmpty else { return }
        let unten = c["min"]?.ganzzahl ?? min(werte.min()!, 0)
        let oben = max(c["max"]?.ganzzahl ?? max(werte.max()!, 0), unten + 1)
        let h = brett.hoehe
        func zeile(_ v: Int) -> Int {
            let anteil = Double(min(max(v, unten), oben) - unten) / Double(oben - unten)
            return h - 1 - Int((anteil * Double(h - 1)).rounded())
        }
        let nullzeile = zeile(0)
        if c["type"] == .text("bar") {
            // Mindestens 1 px breit mit 1 px Lücke, soweit es passt.
            let platz = brett.breite
            let breiteJeBalken = max(1, (platz + 1) / werte.count - 1)
            for (i, v) in werte.enumerated() {
                let x0 = i * (breiteJeBalken + 1)
                for dx in 0..<breiteJeBalken {
                    for y in min(zeile(v), nullzeile)...max(zeile(v), nullzeile) { brett.setze(x0 + dx, y, farbe) }
                }
            }
        } else {
            var vorige: (Int, Int)?
            for (i, v) in werte.enumerated() {
                let x = werte.count == 1 ? 0 : i * (brett.breite - 1) / (werte.count - 1)
                let p = (x, zeile(v))
                if let vorige { linie(vorige.0, vorige.1, p.0, p.1, farbe, auf: &brett) } else { brett.setze(p.0, p.1, farbe) }
                vorige = p
            }
        }
    }

    /// Text mit der Pixelschrift der App. Ruhender Text steht nach `align`/`valign`,
    /// laufender an seinem Startanker links; Überhang wird abgeschnitten.
    private static func text(_ wert: JSONWert, _ r: [String: JSONWert], farbe: Int,
                             einstellungen: [String: JSONWert], auf brett: inout Brett) {
        var klar = ""
        var teilfarbe: Int?
        switch wert {
        case .text(let s): klar = s
        case .liste(let l):
            for case .objekt(let o) in l {
                if case .text(let s)? = o["text"] { klar += s }
                if teilfarbe == nil, let c = o["color"] { teilfarbe = farbwert(c) }
            }
        default: return
        }
        // `textCase inherit` folgt der globalen Einstellung `uppercase` (§5.1).
        let gross = r["textCase"] == .text("upper")
            || (r["textCase"] != .text("asTyped") && einstellungen["uppercase"] == .bool(true))
        if gross { klar = klar.uppercased() }
        guard !klar.isEmpty else { return }
        let f = r["color"] == nil ? (teilfarbe ?? farbe) : farbe
        let hex = String(format: "#%06X", f)
        let puffer = Textraster.rasterPuffer(klar, schrift: "Silkscreen", groesse: brett.hoehe >= 8 ? 8 : 6,
                                             fett: false, farbe: hex, luecke: 1,
                                             mass: Anzeigemass(breite: brett.breite, hoehe: brett.hoehe))
        let tinte = Textraster.tintenZeilen(puffer) ?? (erste: 0, letzte: puffer.hoehe - 1)
        let tintenhoehe = tinte.letzte - tinte.erste + 1
        var (ox, oy) = lage(puffer.breite, tintenhoehe, in: brett, r)
        if laeuft(r) { ox = 0 }
        ox = max(ox, 0)
        for y in 0..<puffer.hoehe {
            for x in 0..<puffer.breite {
                guard puffer.farbe(x: x, y: y) != nil else { continue }
                brett.setze(ox + x, oy + y - tinte.erste, f)
            }
        }
    }

    // MARK: - MQTT

    /// Die Antwort einer NG-Uhr auf eine MQTT-Nachricht, soweit die App sie
    /// braucht: Anzeige setzen und löschen (`cmd/apps/pushed/<name>`), umschalten
    /// (`cmd/apps/switch`), Benachrichtigung (`cmd/notify`) und das Display (`cmd/screen/get` →
    /// `state/screen`). Jede Antwort ist eine Nachricht an die Uhr zurück:
    /// `<Thema>/result` mit `{"ok":true}` oder `{"ok":false,"error":{…}}`.
    ///
    /// Was samt Thema 8192 Byte übersteigt, verwirft die Uhr **ohne Antwort**
    /// (§8). Alles andere ist die HTTP-Logik: dieselbe Nutzlast, dieselben Fehler.
    /// Was die Uhr beim Verbinden aufbewahrt hinterlegt (§3.5): `state/device`,
    /// `state/settings`, `state/apps/active`, `availability`.
    public static func aufbewahrt(praefix: String, _ z: NGUhrzustand) -> [(thema: String, nutzlast: Data)] {
        [(praefix + "/state/device", geraet(z).daten),
         (praefix + "/state/settings", JSONWert.objekt(z.einstellungen).daten),
         (praefix + "/state/apps/active", Data(z.aktiveApp.utf8)),
         (praefix + "/availability", Data("online".utf8))]
    }

    public static func nachricht(thema: String, nutzlast: Data, praefix: String,
                                 _ z: inout NGUhrzustand) -> [(thema: String, nutzlast: Data)] {
        guard thema.utf8.count + nutzlast.count <= 8192 else { return [] }
        let vorsilbe = praefix + "/cmd/"
        guard thema.hasPrefix(vorsilbe) else { return [] }
        let rest = String(thema.dropFirst(vorsilbe.count))
        let kopf = ["content-type": "application/json"]

        func ergebnis(_ a: Antwort) -> [(thema: String, nutzlast: Data)] {
            var inhalt = Data(#"{"ok":true}"#.utf8)
            if a.status >= 400 {
                let fehler = JSONWert.lesen(a.koerper).flatMap { w -> JSONWert? in
                    if case .objekt(let o) = w { return o["error"] }
                    return nil
                } ?? .null
                inhalt = JSONWert.objekt(["ok": .bool(false), "error": fehler]).daten
                // ❓ Die Doku nennt für `event/error` nur die Schlüssel `source`,
                // `request` und `error`, nicht ihre Form; `request` ist hier das Thema.
                let ereignis = JSONWert.objekt(["source": .text("mqtt"), "request": .text(thema),
                                                "error": fehler]).daten
                return [(thema + "/result", inhalt), (praefix + "/event/error", ereignis)]
            }
            return [(thema + "/result", inhalt)]
        }

        switch rest {
        case "screen/get":
            return [(praefix + "/state/screen", bildschirmantwort(z))]
        case "apps/switch":
            return ergebnis(beantworten(Anfrage("PUT", "/api/v1/apps/active", koerper: nutzlast, kopf: kopf), &z))
        case "notify":
            return ergebnis(beantworten(Anfrage("POST", "/api/v1/notifications", koerper: nutzlast, kopf: kopf), &z))
        case "display":
            return ergebnis(beantworten(Anfrage("PATCH", "/api/v1/display", koerper: nutzlast, kopf: kopf), &z))
        case "settings":
            return ergebnis(beantworten(Anfrage("PATCH", "/api/v1/settings", koerper: nutzlast, kopf: kopf), &z))
        case "apps/next", "apps/previous":
            return ergebnis(beantworten(Anfrage("POST", "/api/v1/" + rest), &z))
        case "display/moodlight":
            // Über MQTT schaltet ein leerer Rumpf aus; `{}` ist (wie über HTTP) `422`.
            let leer = nutzlast.isEmpty
            return ergebnis(beantworten(leer ? Anfrage("DELETE", "/api/v1/display/moodlight")
                                             : Anfrage("PUT", "/api/v1/display/moodlight", koerper: nutzlast, kopf: kopf), &z))
        case _ where rest.hasPrefix("indicators/"):
            // Die Kennziffer ist ein einzelnes Zeichen; alles andere trifft keine Route.
            let id = String(rest.dropFirst("indicators/".count))
            guard id.count == 1, ["1", "2", "3"].contains(id) else { return [] }
            let leer = nutzlast.isEmpty || String(decoding: nutzlast, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "{}"
            return ergebnis(beantworten(leer ? Anfrage("DELETE", "/api/v1/indicators/" + id)
                                             : Anfrage("PUT", "/api/v1/indicators/" + id, koerper: nutzlast, kopf: kopf), &z))
        case _ where rest.hasPrefix("apps/pushed/"):
            let name = String(rest.dropFirst("apps/pushed/".count))
            guard !name.isEmpty else { return [] }
            let leer = nutzlast.isEmpty || String(decoding: nutzlast, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "{}"
            let anfrage = leer ? Anfrage("DELETE", "/api/v1/apps/" + name)
                               : Anfrage("PUT", "/api/v1/apps/pushed/" + name, koerper: nutzlast, kopf: kopf)
            return ergebnis(beantworten(anfrage, &z))
        default:
            return []
        }
    }
}
