import AppIntents
import TC002Core

/// Die Auswahllisten der Kurzbefehle.
///
/// Warum Listen und nicht Text: Ein Textfeld „Schriftart" nimmt auch
/// „Silkscren" entgegen, und der Kurzbefehl liefe damit durch, ohne dass sich
/// etwas änderte — der Fehler fiele erst an der Uhr auf, und auch dort nur
/// dem, der genau hinsieht. Ein `AppEnum` ist in der Kurzbefehle-App ein
/// Aufklappmenü: Was nicht darin steht, lässt sich gar nicht erst eintragen.
///
/// Warum eigene Typen und nicht die des Kerns: `SendeWeg`, `Lauftempo` und
/// die beiden Ausrichtungen liegen in `TC002Core`, und der bleibt
/// plattformfrei — AppIntents gehörte dort nicht hin. Die Umrechnung ist je
/// ein `kern`, und die Rohwerte sind absichtlich dieselben Wörter: Sie stehen
/// so auch in den Einstellungen.
///
/// Die Anzeigenamen sind die, die die App selbst benutzt (Formatpille,
/// Formatblatt) — dieselben Schlüssel, dieselbe Übersetzung. Zwei Wörter für
/// dieselbe Sache wären zwei Einträge in `en.lproj`, von denen einer irgendwann
/// vergessen wird.

enum WegAuswahl: String, AppEnum {
    case pixel, text

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Weg")
    }
    static var caseDisplayRepresentations: [WegAuswahl: DisplayRepresentation] = [
        .pixel: DisplayRepresentation(title: "als Pixel"),
        .text: DisplayRepresentation(title: "als Text"),
    ]

    var kern: SendeWeg { self == .pixel ? .pixel : .text }
}

/// Die acht Schriften der Sendeansicht — dieselben Namen wie
/// `Schriften.auswahl` im Kern. Dass sie hier ein zweites Mal stehen, ist der
/// Preis dafür, dass ein `AppEnum` feste Fälle braucht; `FormatangabenTests`
/// nagelt die Liste im Kern deshalb Wort für Wort fest.
///
/// Ungefiltert wie in `SendeniOS`: Ob eine Systemschrift auf diesem Gerät
/// wirklich liegt, weiß erst das Rastern. Eine Liste, die sich je nach Telefon
/// ändert, wäre in einem Kurzbefehl schlimmer — er liefe auf dem einen Gerät
/// und auf dem anderen nicht mehr.
enum SchriftAuswahl: String, AppEnum {
    case micro5 = "Micro 5"
    case silkscreen = "Silkscreen"
    case tiny5 = "Tiny5"
    case geneva = "Geneva"
    case monaco = "Monaco"
    case andaleMono = "Andale Mono"
    case menlo = "Menlo"
    case ptMono = "PT Mono"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Schriftart")
    }
    /// Eigennamen. Sie stehen trotzdem in `en.lproj`, wortgleich — der Sammler
    /// sieht jeden sichtbaren Text, und ein Eintrag, der sich nicht ändert,
    /// ist billiger als eine Ausnahme im Prüfskript.
    static var caseDisplayRepresentations: [SchriftAuswahl: DisplayRepresentation] = [
        .micro5: DisplayRepresentation(title: "Micro 5"),
        .silkscreen: DisplayRepresentation(title: "Silkscreen"),
        .tiny5: DisplayRepresentation(title: "Tiny5"),
        .geneva: DisplayRepresentation(title: "Geneva"),
        .monaco: DisplayRepresentation(title: "Monaco"),
        .andaleMono: DisplayRepresentation(title: "Andale Mono"),
        .menlo: DisplayRepresentation(title: "Menlo"),
        .ptMono: DisplayRepresentation(title: "PT Mono"),
    ]

    var kern: String { rawValue }
}

/// Zehn Farben statt eines Farbwählers: Auf dem Rad der App lässt sich jede
/// Farbe einstellen, in einem Kurzbefehl gibt es kein Rad — dort bliebe nur
/// ein Feld für „#RRGGBB", und wer sich vertippt, merkt es nicht.
///
/// Wer eine andere Farbe will, gibt keine an: Dann gilt die, die zuletzt unter
/// „Senden" eingestellt war, und die kommt vom Farbrad.
enum FarbAuswahl: String, AppEnum {
    case weiss, rot, orange, gelb, gruen, tuerkis, blau, violett, magenta, rosa

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Farbe")
    }
    static var caseDisplayRepresentations: [FarbAuswahl: DisplayRepresentation] = [
        .weiss: DisplayRepresentation(title: "Weiß"),
        .rot: DisplayRepresentation(title: "Rot"),
        .orange: DisplayRepresentation(title: "Orange"),
        .gelb: DisplayRepresentation(title: "Gelb"),
        .gruen: DisplayRepresentation(title: "Grün"),
        .tuerkis: DisplayRepresentation(title: "Türkis"),
        .blau: DisplayRepresentation(title: "Blau"),
        .violett: DisplayRepresentation(title: "Violett"),
        .magenta: DisplayRepresentation(title: "Magenta"),
        .rosa: DisplayRepresentation(title: "Rosa"),
    ]

    /// Voll ausgesteuerte Farben: Auf sechzehn Zeilen mit je einer Leuchtdiode
    /// bleibt von einem abgedunkelten Ton nichts übrig. „Grün" ist der Ton, mit
    /// dem die App ausgeliefert wird.
    var kern: String {
        switch self {
        case .weiss: return "#FFFFFF"
        case .rot: return "#FF0000"
        case .orange: return "#FF8000"
        case .gelb: return "#FFFF00"
        case .gruen: return "#00FF66"
        case .tuerkis: return "#00FFFF"
        case .blau: return "#0080FF"
        case .violett: return "#8000FF"
        case .magenta: return "#FF00FF"
        case .rosa: return "#FF80C0"
        }
    }
}

enum WaagrechtAuswahl: String, AppEnum {
    case links, mittig, rechts

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Waagrecht")
    }
    static var caseDisplayRepresentations: [WaagrechtAuswahl: DisplayRepresentation] = [
        .links: DisplayRepresentation(title: "Linksbündig"),
        .mittig: DisplayRepresentation(title: "Zentriert"),
        .rechts: DisplayRepresentation(title: "Rechtsbündig"),
    ]

    var kern: SendenHAusrichtung {
        switch self {
        case .links: return .links
        case .mittig: return .mittig
        case .rechts: return .rechts
        }
    }
}

enum SenkrechtAuswahl: String, AppEnum {
    case oben, mittig, unten

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Senkrecht")
    }
    static var caseDisplayRepresentations: [SenkrechtAuswahl: DisplayRepresentation] = [
        .oben: DisplayRepresentation(title: "Oben"),
        .mittig: DisplayRepresentation(title: "Mittig"),
        .unten: DisplayRepresentation(title: "Unten"),
    ]

    var kern: SendenVAusrichtung {
        switch self {
        case .oben: return .oben
        case .mittig: return .mittig
        case .unten: return .unten
        }
    }
}

enum TempoAuswahl: String, AppEnum {
    case langsam, mittel, schnell

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Tempo")
    }
    static var caseDisplayRepresentations: [TempoAuswahl: DisplayRepresentation] = [
        .langsam: DisplayRepresentation(title: "langsam"),
        .mittel: DisplayRepresentation(title: "mittel"),
        .schnell: DisplayRepresentation(title: "schnell"),
    ]

    var kern: Lauftempo {
        switch self {
        case .langsam: return .langsam
        case .mittel: return .mittel
        case .schnell: return .schnell
        }
    }
}
