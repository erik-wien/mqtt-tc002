import Foundation

/// Die Vorschau der Schrift der Uhr (`SendeWeg.text`): eine 3×5-Pixelschrift
/// auf dem Raster, das AWTRIX NG für gepushte Anzeigen benutzt — auf der TC002
/// 26 × 8, jedes Pixel 2 × 2 gezeichnet (`enlargeApps`, §1.1), auf einer
/// 8-zeiligen Uhr 1:1.
///
/// Gemessen am 10.10.2026 (TC002, NG 1.2.2, `enlargeApps` an, `uppercase` an,
/// `{"text":"Hello!"}` ohne Icon, gelesen über `display/screen`): Die Schrift
/// `small` setzt Großbuchstaben 5 Pixel hoch in die Zeilen 1–5, 3 Pixel breit
/// mit 1 Pixel Luft; „!“ ist 1 Pixel breit; der Text steht mittig. Mehr ist
/// nicht gemessen: Die Zeichen außerhalb von „HELO!“ sind nach dem Muster
/// gezeichnet, nicht abgelesen, und die Vorschau bleibt eine Näherung
/// (`AwtrixNG.vorschauhinweis`). Eine Laufschrift zeigt ihren Anfang.
public enum Geraeteschrift {
    /// Ein Zeichen: die Zeilen 1–5 als „#“ und „.“, dazu optional die Zeile 0
    /// (Punkte über Umlauten) und die Zeile 6 (Unterlängen).
    struct Glyphe {
        let zeilen: [String]
        var ueber: String? = nil
        var unter: String? = nil
        var breite: Int { zeilen[0].count }
    }

    /// Eine Lücke zwischen zwei Zeichen.
    static let luft = 1
    static let leerzeichen = 2

    private static func g(_ z: [String], ueber: String? = nil, unter: String? = nil) -> Glyphe {
        Glyphe(zeilen: z, ueber: ueber, unter: unter)
    }

    private static let grossA = [".#.", "#.#", "###", "#.#", "#.#"]
    private static let grossO = [".#.", "#.#", "#.#", "#.#", ".#."]
    private static let grossU = ["#.#", "#.#", "#.#", "#.#", "###"]

    static let glyphen: [Character: Glyphe] = [
        "A": g(grossA), "B": g(["##.", "#.#", "##.", "#.#", "##."]),
        "C": g([".##", "#..", "#..", "#..", ".##"]), "D": g(["##.", "#.#", "#.#", "#.#", "##."]),
        "E": g(["###", "#..", "###", "#..", "###"]), "F": g(["###", "#..", "###", "#..", "#.."]),
        "G": g([".##", "#..", "#.#", "#.#", ".##"]), "H": g(["#.#", "#.#", "###", "#.#", "#.#"]),
        "I": g(["###", ".#.", ".#.", ".#.", "###"]), "J": g(["..#", "..#", "..#", "#.#", ".#."]),
        "K": g(["#.#", "#.#", "##.", "#.#", "#.#"]), "L": g(["#..", "#..", "#..", "#..", "###"]),
        "M": g(["###", "###", "#.#", "#.#", "#.#"]), "N": g(["##.", "#.#", "#.#", "#.#", "#.#"]),
        "O": g(grossO), "P": g(["##.", "#.#", "##.", "#..", "#.."]),
        "Q": g([".#.", "#.#", "#.#", "###", ".##"]), "R": g(["##.", "#.#", "##.", "#.#", "#.#"]),
        "S": g([".##", "#..", ".#.", "..#", "##."]), "T": g(["###", ".#.", ".#.", ".#.", ".#."]),
        "U": g(grossU), "V": g(["#.#", "#.#", "#.#", "#.#", ".#."]),
        "W": g(["#.#", "#.#", "#.#", "###", "###"]), "X": g(["#.#", "#.#", ".#.", "#.#", "#.#"]),
        "Y": g(["#.#", "#.#", ".#.", ".#.", ".#."]), "Z": g(["###", "..#", ".#.", "#..", "###"]),
        "Ä": g(grossA, ueber: "#.#"), "Ö": g(grossO, ueber: "#.#"), "Ü": g(grossU, ueber: "#.#"),
        "ß": g([".##", "#.#", "##.", "#.#", "##."]),

        "a": g(["...", "...", ".##", "#.#", ".##"]), "b": g(["#..", "#..", "##.", "#.#", "##."]),
        "c": g(["...", "...", ".##", "#..", ".##"]), "d": g(["..#", "..#", ".##", "#.#", ".##"]),
        "e": g(["...", "...", ".#.", "###", ".##"]), "f": g([".##", "#..", "##.", "#..", "#.."]),
        "g": g(["...", "...", ".##", "#.#", ".##"], unter: "##."),
        "h": g(["#..", "#..", "##.", "#.#", "#.#"]), "i": g([".#.", "...", ".#.", ".#.", ".#."]),
        "j": g(["..#", "...", "..#", "..#", "..#"], unter: "##."),
        "k": g(["#..", "#..", "#.#", "##.", "#.#"]), "l": g(["##.", ".#.", ".#.", ".#.", ".##"]),
        "m": g(["...", "...", "###", "###", "#.#"]), "n": g(["...", "...", "##.", "#.#", "#.#"]),
        "o": g(["...", "...", ".#.", "#.#", ".#."]),
        "p": g(["...", "...", "##.", "#.#", "##."], unter: "#.."),
        "q": g(["...", "...", ".##", "#.#", ".##"], unter: "..#"),
        "r": g(["...", "...", ".##", "#..", "#.."]), "s": g(["...", "...", ".##", ".#.", "##."]),
        "t": g([".#.", "###", ".#.", ".#.", ".##"]), "u": g(["...", "...", "#.#", "#.#", ".##"]),
        "v": g(["...", "...", "#.#", "#.#", ".#."]), "w": g(["...", "...", "#.#", "###", "###"]),
        "x": g(["...", "...", "#.#", ".#.", "#.#"]),
        "y": g(["...", "...", "#.#", "#.#", ".##"], unter: "##."),
        "z": g(["...", "...", "##.", ".#.", ".##"]),
        "ä": g(["...", "#.#", ".##", "#.#", ".##"]), "ö": g(["...", "#.#", ".#.", "#.#", ".#."]),
        "ü": g(["...", "#.#", "#.#", "#.#", ".##"]),

        "0": g(["###", "#.#", "#.#", "#.#", "###"]), "1": g([".#.", "##.", ".#.", ".#.", "###"]),
        "2": g(["##.", "..#", ".#.", "#..", "###"]), "3": g(["##.", "..#", ".#.", "..#", "##."]),
        "4": g(["#.#", "#.#", "###", "..#", "..#"]), "5": g(["###", "#..", "##.", "..#", "##."]),
        "6": g([".##", "#..", "###", "#.#", "###"]), "7": g(["###", "..#", ".#.", ".#.", ".#."]),
        "8": g(["###", "#.#", "###", "#.#", "###"]), "9": g(["###", "#.#", "###", "..#", "##."]),

        "!": g(["#", "#", "#", ".", "#"]), ".": g([".", ".", ".", ".", "#"]),
        ",": g([".", ".", ".", ".", "#"], unter: "#"), ":": g([".", "#", ".", "#", "."]),
        ";": g([".", "#", ".", "#", "."], unter: "#"), "'": g(["#", "#", ".", ".", "."]),
        "?": g(["##.", "..#", ".#.", "...", ".#."]), "-": g(["...", "...", "###", "...", "..."]),
        "+": g(["...", ".#.", "###", ".#.", "..."]), "/": g(["..#", "..#", ".#.", "#..", "#.."]),
        "(": g([".#", "#.", "#.", "#.", ".#"]), ")": g(["#.", ".#", ".#", ".#", "#."]),
        "%": g(["#.#", "..#", ".#.", "#..", "#.#"]), "=": g(["...", "###", "...", "###", "..."]),
        "_": g(["...", "...", "...", "...", "###"]), "*": g(["#.#", ".#.", "###", ".#.", "#.#"]),
        "@": g([".##", "#.#", "###", "#..", ".##"]), "#": g(["#.#", "###", "#.#", "###", "#.#"]),
        "&": g([".#.", "#.#", ".#.", "#.#", ".##"]), "\"": g(["#.#", "#.#", "...", "...", "..."]),
        "€": g([".##", "###", "##.", "###", ".##"]), "°": g([".#.", "#.#", ".#.", "...", "..."]),
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
        glyphen[z] ?? (z == " " ? Glyphe(zeilen: [String(repeating: ".", count: leerzeichen)]) : ersatz)
    }

    /// Breite des Textes in Pixeln des Uhrenrasters.
    static func breite(_ zeichen: [Character]) -> Int {
        guard !zeichen.isEmpty else { return 0 }
        return zeichen.map { glyphe($0).breite }.reduce(0, +) + luft * (zeichen.count - 1)
    }

    /// Ob die Uhr diese Anzeige auf 26 × 8 vergrößert zeichnet: die TC002 mit
    /// einem Icon bis 8×8 oder ohne Icon (§1.1).
    public static func vergroessert(mitIcon: Bool, iconKante: Int, mass: Anzeigemass) -> Bool {
        mass.hoehe >= 16 && (!mitIcon || iconKante <= 8)
    }

    /// Wie viele Punkte der Vorschau ein Pixel der Uhr belegt.
    public static func masstab(mitIcon: Bool, iconKante: Int, mass: Anzeigemass) -> Int {
        vergroessert(mitIcon: mitIcon, iconKante: iconKante, mass: mass) ? 2 : 1
    }

    /// Raster, auf dem die Uhr zeichnet, und die erste Spalte rechts vom Icon.
    private static func raster(mitIcon: Bool, iconKante: Int, mass: Anzeigemass)
        -> (breite: Int, hoehe: Int, links: Int, faktor: Int) {
        let f = masstab(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
        return (mass.breite / f, mass.hoehe / f, mitIcon ? iconKante + 1 : 0, f)
    }

    /// Ob der Text neben dem Icon ganz ins Raster passt; sonst läuft er auf der
    /// Uhr durch.
    public static func passt(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int, mass: Anzeigemass) -> Bool {
        let r = raster(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
        return breite(geschrieben(o)) <= r.breite - r.links
    }

    /// Das Feld der Vorschau in der Größe der Anzeige.
    public static func feld(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int,
                            mass: Anzeigemass) -> Pixelfeld {
        let r = raster(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
        let zeichen = geschrieben(o)
        let platz = r.breite - r.links
        let b = breite(zeichen)
        var x = r.links
        if b <= platz, o.waagrecht == .mittig || o.waagrecht == .rechts {
            // NG kennt nur „mittig oder links“ (`textCenter`); „rechts“ wird
            // linksbündig gesendet und hier ebenso gezeigt.
            x += o.waagrecht == .mittig ? (platz - b) / 2 : 0
        }
        let y0 = (r.hoehe - 8) / 2
        var klein = Pixelfeld(breite: r.breite, hoehe: r.hoehe)
        for z in zeichen {
            let gl = glyphe(z)
            if x >= r.breite { break }
            var reihen: [(Int, String)] = gl.zeilen.enumerated().map { ($0.offset + 1, $0.element) }
            if let u = gl.ueber { reihen.append((0, u)) }
            if let u = gl.unter { reihen.append((6, u)) }
            for (zeile, muster) in reihen {
                for (i, c) in muster.enumerated() where c == "#" {
                    klein.setzen(x: x + i, y: y0 + zeile, farbe: o.farbe)
                }
            }
            x += gl.breite + luft
        }
        guard r.faktor > 1 else { return klein }
        var gross = Pixelfeld(breite: mass.breite, hoehe: mass.hoehe)
        for y in 0..<r.hoehe {
            for xx in 0..<r.breite {
                guard let farbe = klein.farbe(x: xx, y: y) else { continue }
                for dy in 0..<r.faktor { for dx in 0..<r.faktor {
                    gross.setzen(x: xx * r.faktor + dx, y: y * r.faktor + dy, farbe: farbe)
                } }
            }
        }
        return gross
    }
}
