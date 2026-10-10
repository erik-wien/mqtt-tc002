import Foundation

/// Fehler einer RTTTL-Zeile (`Name:Einstellungen:Noten`).
public enum RtttlFehler: Error, LocalizedError, Equatable {
    case leer
    case mehrereZeilen
    case zuLang(Int)
    case teileFalsch
    case einstellung(String)
    case keineNoten
    case note(String)

    public var errorDescription: String? {
        switch self {
        case .leer: return lok("Die Melodie ist leer.")
        case .mehrereZeilen: return lok("Eine Melodie ist eine einzige Zeile.")
        case .zuLang(let grenze): return lokf("Eine Melodie hat höchstens %d Zeichen.", grenze)
        case .teileFalsch: return lok("Erwartet wird Name:Einstellungen:Noten, drei Teile mit Doppelpunkt getrennt.")
        case .einstellung(let s): return lokf("Unlesbare Einstellung „%@“. Erlaubt sind d=, o= und b= mit Zahlen.", s)
        case .keineNoten: return lok("Nach dem zweiten Doppelpunkt fehlen die Noten.")
        case .note(let n): return lokf("Unlesbare Note „%@“.", n)
        }
    }
}

/// RTTTL-Text: Syntaxprüfung, Namensteil und Vergleichsform. Geprüft wird nur
/// die Form (`docs/awtrix-ng-protokoll.md` §3.2.1); ob die Uhr eine Melodie
/// musikalisch gelten lässt, entscheidet sie selbst.
public enum Rtttl {
    /// Die Uhr nimmt höchstens so viele Zeichen (`Klang.textGrenze`).
    public static let hoechstlaenge = Klang.textGrenze

    /// Der Text ohne Rand, oder der Grund, warum er keine Melodie ist.
    public static func geprueft(_ roh: String) throws -> String {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw RtttlFehler.leer }
        guard !text.contains(where: \.isNewline) else { throw RtttlFehler.mehrereZeilen }
        guard text.count <= hoechstlaenge else { throw RtttlFehler.zuLang(hoechstlaenge) }
        let teile = text.split(separator: ":", omittingEmptySubsequences: false)
        guard teile.count == 3 else { throw RtttlFehler.teileFalsch }
        try einstellungenPruefen(String(teile[1]))
        let noten = teile[2].split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !noten.allSatisfy(\.isEmpty) else { throw RtttlFehler.keineNoten }
        for n in noten { try notePruefen(n) }
        return text
    }

    private static func einstellungenPruefen(_ s: String) throws {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return }
        for paar in t.split(separator: ",", omittingEmptySubsequences: false) {
            let kv = paar.split(separator: "=", omittingEmptySubsequences: false)
            guard kv.count == 2,
                  ["d", "o", "b"].contains(kv[0].trimmingCharacters(in: .whitespaces).lowercased()),
                  let wert = Int(kv[1].trimmingCharacters(in: .whitespaces)), wert > 0 else {
                throw RtttlFehler.einstellung(String(paar))
            }
        }
    }

    /// `[Dauer] Ton [#] [.] [Oktave] [.]` mit Ton `a`–`g`, `h` oder `p`.
    private static func notePruefen(_ n: String) throws {
        guard !n.isEmpty else { throw RtttlFehler.note(n) }
        var rest = Substring(n.lowercased())
        let ziffern = rest.prefix(while: \.isNumber)
        if !ziffern.isEmpty {
            guard let d = Int(ziffern), [1, 2, 4, 8, 16, 32, 64].contains(d) else { throw RtttlFehler.note(n) }
            rest = rest.dropFirst(ziffern.count)
        }
        guard let ton = rest.first, "abcdefghp".contains(ton) else { throw RtttlFehler.note(n) }
        rest = rest.dropFirst()
        if rest.first == "#" { rest = rest.dropFirst() }
        if rest.first == "." { rest = rest.dropFirst() }
        if let o = rest.first, o.isNumber { rest = rest.dropFirst() }
        if rest.first == "." { rest = rest.dropFirst() }
        guard rest.isEmpty else { throw RtttlFehler.note(n) }
    }

    /// Der Namensteil vor dem ersten Doppelpunkt.
    public static func namensteil(_ text: String) -> String {
        String(text.prefix(while: { $0 != ":" })).trimmingCharacters(in: .whitespaces)
    }

    /// Ein Melodiename für die Uhr aus dem Namensteil (`[A-Za-z0-9_-]`, 1–24
    /// Zeichen); fehlt er, `melodie`.
    public static func namensvorschlag(_ text: String) -> String {
        guard !namensteil(text).isEmpty else { return "melodie" }
        let roh = Klangname.vorschlag(ausDateiname: namensteil(text))
        let kurz = String(roh.prefix(Klangbau.melodienamenGrenze))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return kurz.isEmpty ? "melodie" : kurz
    }

    /// Der Text mit `name` als Namensteil — so führt ihn die Uhr (gemessen: sie
    /// schreibt den Namensteil auf den Melodienamen um).
    public static func mitName(_ text: String, name: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = t.firstIndex(of: ":") else { return t }
        return name + String(t[i...])
    }
}
