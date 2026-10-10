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
/// (`AwtrixNG.vorschauhinweis`), und eine Laufschrift zeigt ihren Anfang.
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

    /// Abgelesen am 10.10.2026 aus 16 Bildschirmauszügen der TC002 (Texte
    /// `abcdef` … `<>@[]$`, `textCase: asTyped`). Nicht gemessen und darum nicht
    /// in der Tabelle: „M“ und „N“ (der Text lief durch, der Auszug zeigt sie
    /// nicht) sowie alle Zeichen, die in keinem der 16 Texte standen — sie
    /// zeichnet die Vorschau als „?“. „O“ stammt aus der Messung von „Hello!“.
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
            for (zeile, muster) in gl.zeilen.enumerated() {
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
