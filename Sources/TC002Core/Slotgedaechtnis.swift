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
public struct Slotstand: Codable, Hashable, Sendable {
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

    /// Baut aus dem gemerkten Stand wieder vollstaendige Optionen — oder nil,
    /// wenn eine der Kennungen (Weg, Ausrichtung, Tempo) nicht mehr zu einem
    /// bekannten Fall passt, etwa nach einer von Hand verbogenen Datei.
    ///
    /// Steht hier und nicht in den Ansichten, obwohl nur sie es brauchen: Die
    /// Rechnung ist rein und haengt an nichts Plattformabhaengigem, und in
    /// zwei Ansichten stand sie zeichengleich. Gebraucht an zwei Stellen —
    /// um die Pixel eines Slots ueber `Meldungsbau` neu zu rechnen
    /// (`AppZustand.slotzustand(_:belegt:)`) und um die Regler beim Antippen
    /// zu uebernehmen (`reglerUebernehmen` in den Sendeansichten).
    public var optionen: Meldungsoptionen? {
        guard let weg = SendeWeg(rawValue: weg),
              let waagrecht = SendenHAusrichtung(rawValue: waagrecht),
              let senkrecht = SendenVAusrichtung(rawValue: senkrecht),
              let tempo = Lauftempo(rawValue: tempo) else { return nil }
        return Meldungsoptionen(text: text, weg: weg, schrift: schrift,
                                groesse: groesse, fett: fett, farbe: farbe,
                                grossbuchstaben: grossbuchstaben, waagrecht: waagrecht,
                                senkrecht: senkrecht, rand: rand, abstand: abstand,
                                tempo: tempo, iconLaeuftMit: iconLaeuftMit, dauer: dauer)
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

    /// Eine gehaltene Fassung fuer die Oberflaeche. `init` legt den Ordner an,
    /// und `AppZustand.slotzustand` laeuft fuenfmal je Neuzeichnen — in
    /// `SendenView` also bei jedem Tastendruck im Textfeld, in `MalenView` bei
    /// jedem Strich. Als Vorgabewert eines Arguments wuerde `Slotgedaechtnis()`
    /// dabei jedes Mal neu ausgewertet und jedes Mal `createDirectory` rufen.
    ///
    /// Unbedenklich, weil der ganze Zustand dieses Typs der Ordnerpfad ist:
    /// Eine gehaltene Fassung verhaelt sich Zeichen fuer Zeichen wie eine
    /// frisch gebaute — jeder Lesezugriff geht ohnehin auf die Platte. Tests
    /// reichen weiterhin ihren eigenen, wegwerfbaren Ordner herein.
    public static let gemeinsam = Slotgedaechtnis()

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
    /// Die Dauer kommt aus `optionen`, nicht als eigener Parameter: Alle
    /// Aufrufer reichten dort ohnehin `optionen.dauer` herein, und ein zweiter,
    /// unabhaengig gefuellter Wert wuerde nie auffallen — die Pruefsumme deckt
    /// die Pixel ab, nicht die Dauer. Dieselbe Streichung wie eine Ebene hoeher
    /// in `AppZustand.senden`.
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
    public func merken(_ optionen: Meldungsoptionen, icon: String?,
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
            dauer: optionen.dauer,
            pruefsumme: Self.pruefsumme(pixel: pixel))
        var neu = alle(fuer: uhr).filter { $0.platz != platz }
        neu.append(stand)
        guard let daten = try? JSONEncoder().encode(neu) else { return false }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard (try? daten.write(to: datei(fuer: uhr), options: .atomic)) != nil else { return false }
        return true
    }

    /// Wirft die Datei einer Uhr weg — aufzurufen, wenn die Uhr selbst
    /// verschwindet (`AppZustand.uhrEntfernen`). Sonst bliebe je entfernter
    /// Uhr eine `<uuid>.json` unter Application Support liegen, die nie
    /// wieder jemand liest: Die Kennung einer geloeschten Uhr kommt nicht
    /// zurueck, eine neu eingetragene bekommt eine neue.
    ///
    /// Eine fehlende Datei ist kein Fehler — entfernt werden darf auch eine
    /// Uhr, auf die nie etwas gesendet wurde.
    public func vergessen(fuer uhr: UUID) {
        try? FileManager.default.removeItem(at: datei(fuer: uhr))
    }

    /// Wirft die Erinnerung an **einen** Platz weg — aufzurufen, wenn dieser
    /// Platz mit etwas ueberschrieben wird, das sich nicht merken laesst: Ein
    /// gemaltes Bild hat keine Regler (`MalenView`, und damit `AppZustand.senden`
    /// mit `slotPlatz`, aber ohne `slotOptionen`).
    ///
    /// Ohne das bliebe der Stand der letzten Textsendung liegen, und
    /// `AppZustand.slotzustand` rechnete beim naechsten Start ohne Broker
    /// daraus wieder ein Bild — den Text, der seit dem Malen gar nicht mehr
    /// auf dem Platz steht. Ohne Erinnerung faellt der Block stattdessen
    /// ehrlich auf „belegt, Inhalt unbekannt".
    ///
    /// Die andern vier Plaetze bleiben stehen, geschrieben wird atomar wie in
    /// `merken`. War zu diesem Platz nichts gemerkt, bleibt die Datei
    /// unangetastet. Der Rueckgabewert hat denselben Vertrag wie dort: Er sagt,
    /// ob es gelungen ist — eine schon angekommene Sendung kippt dadurch nicht.
    @discardableResult
    public func vergessen(fuer uhr: UUID, platz: Int) -> Bool {
        let vorhanden = alle(fuer: uhr)
        let uebrig = vorhanden.filter { $0.platz != platz }
        guard uebrig.count != vorhanden.count else { return true }
        guard !uebrig.isEmpty else {
            return (try? FileManager.default.removeItem(at: datei(fuer: uhr))) != nil
        }
        guard let daten = try? JSONEncoder().encode(uebrig) else { return false }
        return (try? daten.write(to: datei(fuer: uhr), options: .atomic)) != nil
    }

    /// Der Fingerabdruck eines Pixelfelds — dieselbe Form, in der
    /// `Anzeigen.pixelAusCustomNutzlast` eine mitgelesene Nutzlast zurueckgibt
    /// (`[String?]`, `nil` heisst aus), damit sich beide Seiten ohne Umweg
    /// vergleichen lassen.
    ///
    /// Deckt damit denselben Ausschnitt ab, den auch der Mitleser aus dem
    /// Broker gewinnen kann: die stehenden Pixel des Textes. Ein Lauf-GIF
    /// (`image`) und der Weg „als Text" (`text`) stehen in einem anderen Teil
    /// der Nutzlast, den der Mitleser gar nicht erst zerlegt — dort gibt es
    /// keine Pixel, gegen die zu pruefen waere, und der Vergleich findet
    /// nicht statt.
    ///
    /// Ein **Icon** dagegen faellt auf beiden Seiten gleich heraus: `merken`
    /// hasht `Meldungsbau.feld(o, mitIcon: true)`, und der Mitleser liest nur
    /// `draw` — das Icon liegt in `frame.bilder` und geht hier wie dort
    /// verloren. Die Pruefsumme passt also, und die Regler werden
    /// wiederhergestellt. Die Nebenfolge, ehrlich benannt: Ein fremder
    /// Absender mit gleichem Text, aber anderem Icon kommt durch die Pruefung
    /// und bekommt beim Antippen unser gemerktes Icon zurueckgesetzt.
    public static func pruefsumme(pixel: [String?]) -> String {
        let text = pixel.map { $0 ?? "-" }.joined(separator: "\u{1}")
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
