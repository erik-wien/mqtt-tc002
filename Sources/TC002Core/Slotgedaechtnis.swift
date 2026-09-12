import Foundation
import CryptoKit

/// Die Regler, mit denen ein Slot zuletzt gesendet wurde — eine Erinnerung,
/// keine Tatsache. Ob sie noch gilt, entscheidet allein `pruefsumme` (siehe
/// dort); ihre Herkunft (App, Werkzeug, Kurzbefehl) ist absichtlich nicht
/// Teil der Ablage.
///
/// Die Codable-Form ist ein Dateiformat wie die von `Uhr`: App, Werkzeug und
/// Kurzbefehle schreiben dieselbe Datei. Wer hier ein Feld umbenennt, macht
/// die Ablage einer laufenden Installation unlesbar —
/// `testSlotstandBleibtLesbar` haelt die Feldnamen fest.
public struct Slotstand: Codable, Equatable, Sendable {
    public var platz: Int
    /// Der eingegebene Text, vor „Großbuchstaben" — wie im Editor, nicht wie
    /// gesendet. `Meldungsbau` wendet `grossbuchstaben` beim Neuberechnen
    /// selbst an (`Meldungsoptionen.gesendeterText`).
    ///
    /// Damit laesst sich das Bild eines Slots ueber `Meldungsbau` neu
    /// rechnen, statt es aus der Nutzlast zurueckzugewinnen — bei einem
    /// Lauf-GIF waere das ohne LZW- und Palettenzerlegung gar nicht moeglich.
    public var text: String
    public var weg: String
    public var schrift: String
    public var groesse: Double
    public var fett: Bool
    public var grossbuchstaben: Bool
    public var rand: Int
    public var abstand: Int
    public var waagrecht: String
    public var senkrecht: String
    public var farbe: String
    public var tempo: String
    public var iconLaeuftMit: Bool
    public var icon: String?
    public var dauer: Int?
    /// Fingerabdruck der Pixel, die diese Regler zum Sendezeitpunkt ergeben
    /// haben (`Slotgedaechtnis.pruefsumme(pixel:)`). Der Kern dieses Typs:
    /// Weicht die ueber den Broker gesehene Nutzlast davon ab — zerlegt in
    /// dieselben Pixel (`Anzeigen.pixelAusCustomNutzlast`) und erneut geprueft
    /// mit derselben Funktion —, hat ein fremder Absender geschrieben, und die
    /// Regler werden nicht angeruehrt.
    public var pruefsumme: String

    public init(platz: Int, text: String, weg: String, schrift: String, groesse: Double,
                fett: Bool, grossbuchstaben: Bool, rand: Int, abstand: Int, waagrecht: String,
                senkrecht: String, farbe: String, tempo: String, iconLaeuftMit: Bool,
                icon: String?, dauer: Int?, pruefsumme: String) {
        self.platz = platz
        self.text = text
        self.weg = weg
        self.schrift = schrift
        self.groesse = groesse
        self.fett = fett
        self.grossbuchstaben = grossbuchstaben
        self.rand = rand
        self.abstand = abstand
        self.waagrecht = waagrecht
        self.senkrecht = senkrecht
        self.farbe = farbe
        self.tempo = tempo
        self.iconLaeuftMit = iconLaeuftMit
        self.icon = icon
        self.dauer = dauer
        self.pruefsumme = pruefsumme
    }
}

/// Je Uhr eine Datei mit den Reglern, mit denen ihre fuenf Slots zuletzt
/// beschrieben wurden — geschrieben von allen drei Absendern (App, Werkzeug,
/// Kurzbefehle), gelesen beim Antippen eines Slot-Blocks.
///
/// Bewusst **keine** Einstellung: Das Werkzeug schreibt nie in die
/// Einstellungen der App (zwei Schreiber auf denselben Schluesseln waeren ein
/// Wettlauf) — diese Ablage ist eine eigene Datei je Uhr, dafuer gebaut, dass
/// mehrere Absender sie beschreiben.
public struct Slotgedaechtnis: Sendable {
    private let ordner: URL

    /// `Application Support/MQTT-TC002/Slots` — neben Icons und Bildern, aber
    /// eigener Unterordner. Tests geben eine eigene, wegwerfbare `ordner`
    /// hinein, statt hier zu landen.
    public static var eigenerOrdner: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MQTT-TC002/Slots")
    }

    public init(ordner: URL = Slotgedaechtnis.eigenerOrdner) {
        self.ordner = ordner
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
    }

    private func datei(fuer uhr: UUID) -> URL {
        ordner.appendingPathComponent("\(uhr.uuidString).json")
    }

    /// Alle gemerkten Slots einer Uhr. Eine fehlende oder unlesbare Datei
    /// zaehlt als leer statt abzustuerzen — von Hand verbogene oder aus einer
    /// aelteren Version stammende Dateien gibt es.
    private func alle(fuer uhr: UUID) -> [Slotstand] {
        guard let daten = try? Data(contentsOf: datei(fuer: uhr)),
              let gelesen = try? JSONDecoder().decode([Slotstand].self, from: daten)
        else { return [] }
        return gelesen
    }

    public func gemerkt(fuer uhr: UUID, platz: Int) -> Slotstand? {
        alle(fuer: uhr).first { $0.platz == platz }
    }

    /// Merkt sich die Regler, mit denen `platz` gerade gesendet wurde.
    ///
    /// Liest die vorhandene Datei, ersetzt darin nur `platz` und schreibt sie
    /// atomar zurueck (`.atomic`) — die andern vier Slots und ein zeitgleicher
    /// zweiter Schreiber auf einem anderen Platz derselben Uhr sollen dabei
    /// nicht verlorengehen. Ein Wettlauf zweier Schreiber auf demselben Platz
    /// bleibt moeglich (der letzte gewinnt); die Prüfsumme faengt das ab, denn
    /// wer auch immer zuletzt geschrieben hat, hat auch zuletzt gesendet.
    ///
    /// Gibt zurueck, ob das Schreiben gelungen ist — der Aufrufer entscheidet
    /// selbst, was ein Fehlschlagen bedeutet: Eine Sendung, die schon
    /// angekommen ist, wird dadurch nicht rueckgaengig gemacht, hoechstens
    /// eine Protokollzeile daraus (siehe `AppZustand.senden`).
    /// `@discardableResult`, weil ein Aufrufer ohne eigenes Protokoll
    /// (Werkzeug, Kurzbefehle) den Rueckgabewert nicht braucht.
    @discardableResult
    public func merken(_ optionen: Meldungsoptionen, dauer: Int?, icon: String?,
                       fuer uhr: UUID, platz: Int) -> Bool {
        let pixel = Meldungsbau.feld(optionen, mitIcon: icon != nil).punkteRoh
        let stand = Slotstand(
            platz: platz,
            text: optionen.text,
            weg: optionen.weg.rawValue,
            schrift: optionen.schrift,
            groesse: optionen.groesse,
            fett: optionen.fett,
            grossbuchstaben: optionen.grossbuchstaben,
            rand: optionen.rand,
            abstand: optionen.abstand,
            waagrecht: optionen.waagrecht.rawValue,
            senkrecht: optionen.senkrecht.rawValue,
            farbe: optionen.farbe,
            tempo: optionen.tempo.rawValue,
            iconLaeuftMit: optionen.iconLaeuftMit,
            icon: icon,
            dauer: dauer,
            pruefsumme: Self.pruefsumme(pixel: pixel))
        var neu = alle(fuer: uhr).filter { $0.platz != platz }
        neu.append(stand)
        guard let daten = try? JSONEncoder().encode(neu) else { return false }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard (try? daten.write(to: datei(fuer: uhr), options: .atomic)) != nil else { return false }
        return true
    }

    /// Der Fingerabdruck eines Pixelfelds — dieselbe Form, in der
    /// `Anzeigen.pixelAusCustomNutzlast` eine mitgelesene Nutzlast zurueckgibt
    /// (`[String?]`, `nil` heisst aus), damit sich beide Seiten ohne Umweg
    /// vergleichen lassen.
    ///
    /// Deckt damit denselben Ausschnitt ab, den auch der Mitleser aus dem
    /// Broker gewinnen kann: die stehenden Pixel des Textes. Ein Icon-Bild
    /// oder ein Lauf-GIF stecken in einem eigenen Teil der Nutzlast
    /// (`image` statt `draw`), den weder der Mitleser noch dieses
    /// Gedaechtnis aus den blossen Reglern zurueckrechnen — beide bleiben in
    /// diesem Fall bei „nicht nachpruefbar", nicht bei einer Behauptung.
    public static func pruefsumme(pixel: [String?]) -> String {
        let text = pixel.map { $0 ?? "-" }.joined(separator: "\u{1}")
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
