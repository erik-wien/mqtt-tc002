import Foundation

/// Die Vorschau der Schrift der Uhr (`SendeWeg.text`): eine 3×5-Pixelschrift
/// auf dem Raster, das AWTRIX NG für gepushte Anzeigen benutzt — auf der TC002
/// 26 × 8, jedes Pixel 2 × 2 gezeichnet (`enlargeApps`, §1.1), auf einer
/// 8-zeiligen Uhr 1:1.
///
/// Gemessen am 10.10.2026 (TC002, NG 1.2.2, `enlargeApps` an, ohne Icon,
/// gelesen über `display/screen`): Die Schrift `small` ist proportional
/// (meist 3 Pixel, „.“ und „!“ 1 Pixel, „W“ 5), setzt Großbuchstaben 5 Pixel
/// hoch in die Zeilen 1–5, Unterlängen in Zeile 6, mit 1 Pixel Luft; der Text
/// steht mittig. Die Tabelle ist aus diesen Messungen abgelesen, nichts ist
/// ergänzt (`glyphen`); die Vorschau bleibt eine Näherung
/// (`AwtrixNG.vorschauhinweis`). Passt der Text nicht, läuft er wie auf der
/// Uhr durch (`laufbilder`).
public enum Geraeteschrift {
    /// Ein Zeichen: sieben Zeilen (0–6 des Uhrenrasters) als „#“ und „.“. Die
    /// Breite ist je Zeichen verschieden (proportionale Schrift).
    struct Glyphe {
        let zeilen: [String]
        init(_ zeilen: [String]) { self.zeilen = zeilen }
        var breite: Int { zeilen[0].count }
    }

    /// Eine Lücke zwischen zwei Zeichen.
    static let luft = 1
    static let leerzeichen = 2

    /// Abgelesen am 10.10.2026 aus Bildschirmauszügen der TC002 (Texte
    /// `abcdef` … `<>@[]$`, dazu `MN`, `MNO`, `|~^{}` und Backslash/Backtick,
    /// `textCase: asTyped`). Nicht in der Tabelle sind alle Zeichen, die in
    /// keinem dieser Texte standen — die Vorschau zeichnet sie als „?“. „O“
    /// steht auch in der Messung von „Hello!“; „P“, „Q“, „R“ sind aus dem
    /// laufenden Auszug von `MNOPQR` gelesen (nicht im Fixture).
    static let glyphen: [Character: Glyphe] = [
        "!": Glyphe([".", "#", "#", "#", ".", "#", "."]),
        "\"": Glyphe(["...", "#.#", "#.#", "...", "...", "...", "..."]),
        "#": Glyphe(["...", "#.#", "###", "#.#", "###", "#.#", "..."]),
        "$": Glyphe(["...", ".##", "##.", ".##", "##.", ".#.", "..."]),
        "%": Glyphe(["...", "#.#", "..#", ".#.", "#..", "#.#", "..."]),
        "&": Glyphe(["...", "##.", "##.", "###", "#.#", ".##", "..."]),
        "'": Glyphe([".", "#", "#", ".", ".", ".", "."]),
        "(": Glyphe(["..", ".#", "#.", "#.", "#.", ".#", ".."]),
        ")": Glyphe(["..", "#.", ".#", ".#", ".#", "#.", ".."]),
        "*": Glyphe(["...", "#.#", ".#.", "#.#", "...", "...", "..."]),
        "+": Glyphe(["...", "...", ".#.", "###", ".#.", "...", "..."]),
        ",": Glyphe(["..", "..", "..", "..", "..", ".#", "#."]),
        "-": Glyphe(["...", "...", "...", "###", "...", "...", "..."]),
        ".": Glyphe([".", ".", ".", ".", ".", "#", "."]),
        "/": Glyphe(["...", "..#", "..#", ".#.", "#..", "#..", "..."]),
        ":": Glyphe([".", ".", "#", ".", "#", ".", "."]),
        ";": Glyphe(["..", "..", ".#", "..", ".#", "#.", ".."]),
        "<": Glyphe(["...", "..#", ".#.", "#..", ".#.", "..#", "..."]),
        "=": Glyphe(["...", "...", "###", "...", "###", "...", "..."]),
        ">": Glyphe(["...", "#..", ".#.", "..#", ".#.", "#..", "..."]),
        "?": Glyphe(["...", "###", "..#", ".#.", "...", ".#.", "..."]),
        "@": Glyphe(["...", ".#.", "#.#", "###", "#..", ".##", "..."]),
        "A": Glyphe(["...", "##.", "#.#", "###", "#.#", "#.#", "..."]),
        "B": Glyphe(["...", "##.", "#.#", "##.", "#.#", "##.", "..."]),
        "C": Glyphe(["...", ".#.", "#.#", "#..", "#.#", ".#.", "..."]),
        "D": Glyphe(["...", "##.", "#.#", "#.#", "#.#", "##.", "..."]),
        "E": Glyphe(["...", "###", "#..", "###", "#..", "###", "..."]),
        "F": Glyphe(["...", "###", "#..", "###", "#..", "#..", "..."]),
        "G": Glyphe(["...", ".##", "#..", "#.#", "#.#", ".##", "..."]),
        "H": Glyphe(["...", "#.#", "#.#", "###", "#.#", "#.#", "..."]),
        "I": Glyphe([".", "#", "#", "#", "#", "#", "."]),
        "J": Glyphe(["...", "..#", "..#", "..#", "#.#", ".#.", "..."]),
        "K": Glyphe(["...", "#.#", "#.#", "##.", "#.#", "#.#", "..."]),
        "L": Glyphe(["...", "#..", "#..", "#..", "#..", "###", "..."]),
        "O": Glyphe(["...", ".#.", "#.#", "#.#", "#.#", ".#.", "..."]),
        "P": Glyphe(["...", "###", "#.#", "##.", "#..", "#..", "..."]),
        "Q": Glyphe(["....", ".#..", "#.#.", "#.#.", "#.#.", ".###", "...."]),
        "R": Glyphe(["...", "###", "#.#", "##.", "#.#", "#.#", "..."]),
        "S": Glyphe(["...", "###", "#..", "###", "..#", "###", "..."]),
        "T": Glyphe(["...", "###", ".#.", ".#.", ".#.", ".#.", "..."]),
        "U": Glyphe(["...", "#.#", "#.#", "#.#", "#.#", "###", "..."]),
        "V": Glyphe(["...", "#.#", "#.#", "#.#", "#.#", ".#.", "..."]),
        "W": Glyphe([".....", "#...#", "#...#", "#...#", "#.#.#", ".#.#.", "....."]),
        "X": Glyphe(["...", "#.#", "#.#", ".#.", "#.#", "#.#", "..."]),
        "Y": Glyphe(["...", "#.#", "#.#", "###", "..#", "##.", "..."]),
        "Z": Glyphe(["...", "###", "..#", ".#.", "#..", "###", "..."]),
        "[": Glyphe(["...", "###", "#..", "#..", "#..", "###", "..."]),
        "]": Glyphe(["...", "###", "..#", "..#", "..#", "###", "..."]),
        "_": Glyphe(["...", "...", "...", "...", "...", "###", "..."]),
        "a": Glyphe(["...", "...", "##.", ".##", "#.#", "###", "..."]),
        "b": Glyphe(["...", "#..", "##.", "#.#", "#.#", "##.", "..."]),
        "c": Glyphe(["...", "...", ".##", "#..", "#..", ".##", "..."]),
        "d": Glyphe(["...", "..#", ".##", "#.#", "#.#", ".##", "..."]),
        "e": Glyphe(["...", "...", ".##", "#.#", "##.", ".##", "..."]),
        "f": Glyphe(["...", "..#", ".#.", "###", ".#.", ".#.", "..."]),
        "g": Glyphe(["...", "...", ".##", "#.#", "###", "..#", ".#."]),
        "h": Glyphe(["...", "#..", "##.", "#.#", "#.#", "#.#", "..."]),
        "i": Glyphe([".", "#", ".", "#", "#", "#", "."]),
        "j": Glyphe(["...", "..#", "...", "..#", "..#", "#.#", ".#."]),
        "k": Glyphe(["...", "#..", "#.#", "##.", "##.", "#.#", "..."]),
        "l": Glyphe(["...", "##.", ".#.", ".#.", ".#.", "###", "..."]),
        "m": Glyphe(["...", "...", "###", "###", "###", "#.#", "..."]),
        "n": Glyphe(["...", "...", "##.", "#.#", "#.#", "#.#", "..."]),
        "o": Glyphe(["...", "...", ".#.", "#.#", "#.#", ".#.", "..."]),
        "p": Glyphe(["...", "...", "##.", "#.#", "#.#", "##.", "#.."]),
        "q": Glyphe(["...", "...", ".##", "#.#", "#.#", ".##", "..#"]),
        "r": Glyphe(["...", "...", ".##", "#..", "#..", "#..", "..."]),
        "s": Glyphe(["...", "...", ".##", "##.", ".##", "##.", "..."]),
        "t": Glyphe(["...", ".#.", "###", ".#.", ".#.", ".##", "..."]),
        "u": Glyphe(["...", "...", "#.#", "#.#", "#.#", ".##", "..."]),
        "v": Glyphe(["...", "...", "#.#", "#.#", "###", ".#.", "..."]),
        "w": Glyphe(["...", "...", "#.#", "###", "###", "###", "..."]),
        "x": Glyphe(["...", "...", "#.#", ".#.", ".#.", "#.#", "..."]),
        "y": Glyphe(["...", "...", "#.#", "#.#", ".##", "..#", ".#."]),
        "z": Glyphe(["...", "...", "###", ".##", "##.", "###", "..."]),
        "°": Glyphe(["..", "##", "##", "..", "..", "..", ".."]),
        "Ä": Glyphe(["...", "#.#", ".#.", "#.#", "###", "#.#", "..."]),
        "Ö": Glyphe(["...", "#.#", "...", "###", "#.#", "###", "..."]),
        "Ü": Glyphe(["...", "#.#", "...", "#.#", "#.#", "###", "..."]),
        "ß": Glyphe(["...", ".##", "#.#", "##.", "#.#", "##.", "#.."]),
        "ä": Glyphe(["...", "#.#", "...", ".##", "#.#", "###", "..."]),
        "ö": Glyphe(["...", "#.#", "...", ".#.", "#.#", ".#.", "..."]),
        "ü": Glyphe(["...", "#.#", "...", "#.#", "#.#", ".##", "..."]),
        "€": Glyphe(["...", ".##", ".#.", "###", ".#.", ".##", "..."]),
        "0": Glyphe(["...", "###", "#.#", "#.#", "#.#", "###", "..."]),
        "1": Glyphe(["...", ".#.", "##.", ".#.", ".#.", "###", "..."]),
        "2": Glyphe(["...", "###", "..#", "###", "#..", "###", "..."]),
        "3": Glyphe(["...", "###", "..#", "###", "..#", "###", "..."]),
        "4": Glyphe(["...", "#.#", "#.#", "###", "..#", "..#", "..."]),
        "5": Glyphe(["...", "###", "#..", "###", "..#", "###", "..."]),
        "6": Glyphe(["...", "###", "#..", "###", "#.#", "###", "..."]),
        "7": Glyphe(["...", "###", "..#", "..#", "..#", "..#", "..."]),
        "8": Glyphe(["...", "###", "#.#", "###", "#.#", "###", "..."]),
        "9": Glyphe(["...", "###", "#.#", "###", "..#", "###", "..."]),
        "M": Glyphe([".....", "#...#", "##.##", "#.#.#", "#...#", "#...#", "....."]),
        "N": Glyphe(["....", "#..#", "##.#", "#.##", "#..#", "#..#", "...."]),
        "|": Glyphe([".", "#", "#", "#", "#", "#", "."]),
        "~": Glyphe(["...", "...", "...", ".##", "##.", "...", "..."]),
        "^": Glyphe(["...", ".#.", "#.#", "...", "...", "...", "..."]),
        "{": Glyphe(["...", ".##", ".#.", "#..", ".#.", ".##", "..."]),
        "}": Glyphe(["...", "##.", ".#.", "..#", ".#.", "##.", "..."]),
        "\\": Glyphe(["...", "...", "#..", ".#.", "..#", "...", "..."]),
        "`": Glyphe(["..", "#.", ".#", "..", "..", "..", ".."]),
    ]

    /// Was die Uhr für ein Zeichen ohne Abbildung zeigt: genau ein „?“ (§5.1).
    private static let ersatz = glyphen["?"]!

    /// Die Schreibweise, die die Uhr bekommt: Mit „Großbuchstaben“ versal,
    /// sonst wie getippt (`NGNutzlast.anzeige` schickt `textCase` in beide
    /// Richtungen). Zeichenweise, damit aus „ß“ kein „SS“ wird — die Uhr behält
    /// die Zeichen bei.
    static func geschrieben(_ o: Meldungsoptionen) -> [Character] {
        o.text.map { z in
            guard o.grossbuchstaben else { return z }
            let gross = z.uppercased()
            return gross.count == 1 ? Character(gross) : z
        }
    }

    private static func glyphe(_ z: Character) -> Glyphe {
        glyphen[z] ?? (z == " " ? Glyphe(Array(repeating: String(repeating: ".", count: leerzeichen), count: 7)) : ersatz)
    }

    /// Breite des Textes in Pixeln des Uhrenrasters.
    static func breite(_ zeichen: [Character]) -> Int {
        guard !zeichen.isEmpty else { return 0 }
        return zeichen.map { glyphe($0).breite }.reduce(0, +) + luft * (zeichen.count - 1)
    }

    /// Ob die Uhr diese Anzeige auf 26 × 8 vergrößert zeichnet: die TC002 mit
    /// einem Icon bis 8×8 oder ohne Icon (§1.1).
    ///
    /// Die Firmware vergrößert nur, wenn **jedes** Bild der Anzeige auf die
    /// 26 × 8 große Zwischenfläche passt (`PageZoom::enlarges`): auch die
    /// Zusatzicons. Ein einziges 16×16 darunter schaltet die ganze Anzeige auf
    /// das volle Raster (`zusatzkanten`).
    public static func vergroessert(mitIcon: Bool, iconKante: Int, mass: Anzeigemass,
                                    zusatzkanten: [Int] = []) -> Bool {
        mass.hoehe >= 16 && (!mitIcon || iconKante <= 8) && zusatzkanten.allSatisfy { $0 <= 8 }
    }

    /// Wie viele Punkte der Vorschau ein Pixel der Uhr belegt.
    public static func masstab(mitIcon: Bool, iconKante: Int, mass: Anzeigemass,
                               zusatzkanten: [Int] = []) -> Int {
        vergroessert(mitIcon: mitIcon, iconKante: iconKante, mass: mass, zusatzkanten: zusatzkanten) ? 2 : 1
    }

    /// Dasselbe für die Optionen einer Anzeige (mit ihren Zusatzicons).
    public static func masstab(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int,
                               mass: Anzeigemass) -> Int {
        masstab(mitIcon: mitIcon, iconKante: iconKante, mass: mass,
                zusatzkanten: Zusatzicons.kanten(o.zusatzicons))
    }

    /// Raster, auf dem die Uhr zeichnet, und die erste Spalte rechts vom Icon.
    ///
    /// Die Firmware rechnet in Spalten dieses Rasters: Das Icon belegt seine eigene
    /// (zugeschnittene) Breite, `iconGap` kommt dazu, und dahinter beginnt der Text
    /// (`RenderPipeline::iconColumn`, `SpecRenderer::textColumn`; §5.3). Auf der
    /// vergrößerten Seite ist eine Spalte zwei Punkte der Anzeige breit, darum
    /// ist die Luft dort ein Vielfaches davon (`Iconplatz.luecke`).
    private static func raster(_ o: Meldungsoptionen, icon: Iconplatz?, mass: Anzeigemass)
        -> (breite: Int, hoehe: Int, links: Int, faktor: Int) {
        let f = masstab(o, mitIcon: icon != nil, iconKante: icon?.kante ?? 8, mass: mass)
        return (mass.breite / f, mass.hoehe / f, icon?.textAb(faktor: f) ?? 0, f)
    }

    /// Ob der Text neben dem Icon ganz ins Raster passt; sonst läuft er auf der
    /// Uhr durch.
    public static func passt(_ o: Meldungsoptionen, icon: Iconplatz?, mass: Anzeigemass) -> Bool {
        let r = raster(o, icon: icon, mass: mass)
        return breite(geschrieben(o)) <= r.breite - r.links
    }

    /// Zeichnet `zeichen` ab Spalte `x` in Zeile `y0` ins Feld; was rechts von
    /// `bis` beginnt, entfällt.
    private static func zeichnen(_ zeichen: [Character], ab x: Int, y0: Int, bis: Int,
                                 farbe: String, in feld: inout Pixelfeld) {
        var x = x
        for z in zeichen {
            let gl = glyphe(z)
            if x >= bis { break }
            for (zeile, muster) in gl.zeilen.enumerated() {
                for (i, c) in muster.enumerated() where c == "#" {
                    feld.setzen(x: x + i, y: y0 + zeile, farbe: farbe)
                }
            }
            x += gl.breite + luft
        }
    }

    /// Das Uhrenraster `klein` auf die Größe der Anzeige bringen: jedes Pixel
    /// `faktor` × `faktor` Punkte.
    private static func vergroessert(_ klein: Pixelfeld, faktor: Int, mass: Anzeigemass) -> Pixelfeld {
        guard faktor > 1 else { return klein }
        var gross = Pixelfeld(breite: mass.breite, hoehe: mass.hoehe)
        for y in 0..<klein.hoehe {
            for xx in 0..<klein.breite {
                guard let farbe = klein.farbe(x: xx, y: y) else { continue }
                for dy in 0..<faktor { for dx in 0..<faktor {
                    gross.setzen(x: xx * faktor + dx, y: y * faktor + dy, farbe: farbe)
                } }
            }
        }
        return gross
    }

    /// Das Feld der Vorschau in der Größe der Anzeige.
    public static func feld(_ o: Meldungsoptionen, icon: Iconplatz?,
                            mass: Anzeigemass) -> Pixelfeld {
        let r = raster(o, icon: icon, mass: mass)
        let zeichen = geschrieben(o)
        let platz = r.breite - r.links
        let b = breite(zeichen)
        var x = r.links
        if b <= platz, o.waagrecht == .mittig || o.waagrecht == .rechts {
            // NG kennt nur „mittig oder links“ (`textCenter`); „rechts“ wird
            // linksbündig gesendet und hier ebenso gezeigt.
            x += o.waagrecht == .mittig ? (platz - b) / 2 : 0
        }
        var klein = Pixelfeld(breite: r.breite, hoehe: r.hoehe)
        zeichnen(zeichen, ab: x, y0: (r.hoehe - 8) / 2, bis: r.breite, farbe: o.farbe, in: &klein)
        return vergroessert(klein, faktor: r.faktor, mass: mass)
    }

    /// Die Pause vor dem Anlaufen (`scroll.holdMs`, global an allen Uhren 1000).
    static let haltezeit = 1.0

    /// Die Einzelbilder des Durchlaufs, wie ihn die Uhr zeigt, wenn der Text
    /// nicht passt; sonst `[]`. Vorgabe der Uhr (an allen gemessen): `wrap`,
    /// links, `inline`, `whenFits: static`, `holdMs` 1000 — der Text steht am
    /// Startanker (links vom Textbereich, rechts vom Icon), rührt sich nach
    /// der Haltezeit je Schritt um ein Pixel des Uhrenrasters nach links, bis
    /// er ganz hinausgelaufen ist, und springt dann zurück (§5.2). `textCenter`
    /// gilt nur für passenden Text und spielt hier keine Rolle.
    ///
    /// Tempo: `scroll.speed` ist `NGNutzlast.tempo(o.tempo)` Prozent der
    /// Grundgeschwindigkeit; ein Schritt dauert so lange wie ein Pixel bei
    /// dieser Geschwindigkeit, gerundet wie im Pixelweg (`Bildraster.gifZeit`).
    ///
    /// Icon (`iconBilder` leer = keines, `icon` ist sein zugeschnittener Platz):
    /// `fixed` bleibt stehen, der Text läuft am Icon vorbei und ist links von
    /// dessen Spalte samt Luft abgeschnitten (`textClipLeft`, §5.3); mit `push`
    /// läuft das Icon mit dem Text hinaus. Bei `pushOnce` ist der erste Durchlauf
    /// derselbe, danach steht der Text ohne Icon am linken Rand an und läuft von
    /// dort durch (`iconPushed`, `setStartX(0)`); die Vorschau zeigt diesen zweiten
    /// Durchlauf einmal, auf der Uhr wiederholt er sich. Ein bewegtes Icon
    /// wechselt seine Bilder je Schritt (nicht nach eigenen Standzeiten).
    public static func laufbilder(_ o: Meldungsoptionen, iconBilder: [[String?]], icon: Iconplatz?,
                                  mass: Anzeigemass) -> [Bildraster.Einzelbild] {
        let platz = iconBilder.isEmpty ? nil : icon
        guard !passt(o, icon: platz, mass: mass) else { return [] }
        let r = raster(o, icon: platz, mass: mass)
        let zeichen = geschrieben(o)
        let b = breite(zeichen)
        let prozent = NGNutzlast.tempo(o.tempo)
        guard prozent > 0 else { return [] }
        let schritt = Bildraster.gifZeit(1 / (Double(prozent) / 100 * AwtrixNG.grundgeschwindigkeit))
        let modus = platz == nil ? Iconmodus.fest : o.iconmodus
        let mitnehmen = modus != .fest
        // Textzeile einmal in voller Länge, Spalte 0 = Textanfang.
        var band = Pixelfeld(breite: max(b, 1), hoehe: r.hoehe)
        zeichnen(zeichen, ab: 0, y0: (r.hoehe - 8) / 2, bis: b, farbe: o.farbe, in: &band)
        // Der Text ist hinaus, wenn sein rechter Rand die Kante erreicht, an der
        // er verschwindet: das Panel (Icon läuft mit) oder das Icon (steht).
        let ende = mitnehmen ? r.links + b : b
        let schnittX = platz != nil && !mitnehmen ? r.links : 0
        let kante = platz?.kante ?? 8
        let iconYVorschau = Meldungsbau.iconY(kante: kante * r.faktor, mass: mass)
        let zugeschnitten = platz.map { p in iconBilder.map { p.zuschneiden($0) } } ?? []

        func bild(durchlauf d: Int, textAb: Int, schnitt: Int, mitIcon: Bool) -> Pixelfeld {
            var klein = Pixelfeld(breite: r.breite, hoehe: r.hoehe)
            for y in 0..<r.hoehe {
                for x in 0..<b {
                    guard let farbe = band.farbe(x: x, y: y) else { continue }
                    let cx = textAb - d + x
                    if cx >= schnitt, cx < r.breite { klein.setzen(x: cx, y: y, farbe: farbe) }
                }
            }
            var f = vergroessert(klein, faktor: r.faktor, mass: mass)
            if mitIcon, let platz {
                let bild = zugeschnitten[d % zugeschnitten.count]
                let versatz = mitnehmen ? -d * r.faktor : 0
                for y in 0..<kante { for x in 0..<platz.breite {
                    guard bild.count == platz.breite * kante, let farbe = bild[y * platz.breite + x] else { continue }
                    for dy in 0..<r.faktor { for dx in 0..<r.faktor {
                        f.setzen(x: x * r.faktor + dx + versatz, y: iconYVorschau + y * r.faktor + dy, farbe: farbe)
                    } }
                } }
            }
            return f
        }

        var bilder = (0...ende).map { d in
            Bildraster.Einzelbild(pixel: bild(durchlauf: d, textAb: r.links, schnitt: schnittX, mitIcon: platz != nil).punkteRoh,
                                  dauer: d == 0 ? haltezeit : schritt)
        }
        if modus == .einmal {
            bilder += (0...b).map { d in
                Bildraster.Einzelbild(pixel: bild(durchlauf: d, textAb: 0, schnitt: 0, mitIcon: false).punkteRoh,
                                      dauer: d == 0 ? haltezeit : schritt)
            }
        }
        return bilder
    }
}
