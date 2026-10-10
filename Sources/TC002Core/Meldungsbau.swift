import Foundation

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit einem 8×8-Icon, ab Spalte 18 mit einem 16×16).
public enum SendenHAusrichtung: String, CaseIterable, Identifiable, Sendable, Codable {
    case links, mittig, rechts
    public var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
public enum SendenVAusrichtung: String, CaseIterable, Identifiable, Sendable, Codable {
    case oben, mittig, unten
    public var id: String { rawValue }
}

/// Der Weg, auf dem der Text zur Uhr kommt. AWTRIX NG setzt den Text selbst
/// (`Anzeigen.nutzlast`): Beide Stellungen schicken denselben Text samt
/// Reglern, die Uhr sieht unsere Pixel nie.
///
/// Das Feld bleibt, weil es Teil des Dateiformats von Slotgedaechtnis, Verlauf
/// und Formatangaben ist, das auch andere Geraete im iCloud-Behaelter lesen.
public enum SendeWeg: String, CaseIterable, Identifiable, Sendable, Codable {
    case pixel, text
    public var id: String { rawValue }
}

/// Wie schnell die Laufschrift durchlaeuft. Ein Regler statt zweier Zahlen:
/// Schrittweite und Bilddauer rechnet niemand im Kopf in ein Tempo um.
public enum Lauftempo: String, CaseIterable, Identifiable, Sendable, Codable {
    case langsam, mittel, schnell
    public var id: String { rawValue }

    /// Pixel Versatz je Einzelbild — immer einer. Zweierschritte wuerden die
    /// Zahl der Einzelbilder und damit die Nutzlast halbieren, kosten aber die
    /// Ruhe im Bild; zusammen mit einer kuerzeren Standzeit ergaebe das fast
    /// das Dreifache von „mittel" statt einer Stufe. Die Stufen unterscheiden
    /// sich deshalb nur in der Standzeit.
    public var schrittweite: Int { 1 }

    /// Standzeit je Einzelbild in Sekunden. Die Stufen liegen rund das
    /// Anderthalbfache auseinander — gleichmaessig statt sprunghaft.
    public var bilddauer: Double {
        switch self {
        case .langsam: return 0.12   //  8 Pixel je Sekunde
        case .mittel:  return 0.08   // 12
        case .schnell: return 0.055  // 18
        }
    }
}

/// Was mit einer gepushten Anzeige geschieht, wenn ihre Lebensdauer um ist
/// (`lifetimeExpiry`, `docs/awtrix-ng-protokoll.md` §5.4).
public enum Lebensablauf: String, CaseIterable, Sendable, Codable {
    /// `remove`: die Uhr löscht die Anzeige.
    case entfernen
    /// `mark`: die Anzeige bleibt, mit einem dunkelroten 1-px-Rahmen.
    case markieren

    /// Das Wort, das die Uhr erwartet.
    var ng: String { self == .entfernen ? "remove" : "mark" }
}

/// Nach dieser Zeit verfällt eine Anzeige von selbst (`lifetimeMs`). Gilt nur
/// für Anzeigen; Benachrichtigungen nehmen den Schlüssel an und ignorieren ihn,
/// darum geht er dort gar nicht erst mit.
///
/// `sekunden == 0` heißt wie bei der Uhr: nie. So hat eine Anzeige drei
/// Zustände, ohne dass ein Dateiformat einen vierten Schlüssel braucht:
/// nichts gesetzt (`Meldungsoptionen.lebensdauer == nil`) gilt als `vorgabe`,
/// 0 als bewusst ausgeschaltet, alles andere als gewählt.
public struct Lebensdauer: Equatable, Sendable, Codable {
    public var sekunden: Int
    public var ablauf: Lebensablauf

    /// Eine neue Anzeige verschwindet nach 30 Minuten von selbst, wenn nichts
    /// anderes gewählt ist; wer sie behalten will, schaltet es ab.
    public static let vorgabe = Lebensdauer(sekunden: 30 * 60, ablauf: .entfernen)
    /// Bewusst keine: die Anzeige bleibt, bis sie ersetzt oder gelöscht wird.
    public static let aus = Lebensdauer(sekunden: 0)

    public init(sekunden: Int, ablauf: Lebensablauf = .entfernen) {
        self.sekunden = sekunden
        self.ablauf = ablauf
    }
}

/// Alles, was eine Meldung ausmacht — ohne Ansicht, ohne Zustand.
///
/// Die Felder entsprechen eins zu eins den `@AppStorage`-Werten der
/// Sendeansicht. Wer hier etwas umbenennt, muss dort denselben Namen benutzen,
/// sonst liest eine laufende Installation ihre Einstellungen nicht mehr. Der
/// Sendeverlauf schreibt diesen Typ unveraendert in seine Datei.
///
/// `Slotstand` (im Slotgedaechtnis) legt dieselben Angaben weiterhin flach ab,
/// Feld fuer Feld: Jene Datei liegt in einem iCloud-Behaelter, den auch
/// aeltere Fassungen auf anderen Geraeten lesen — ihr Format zu aendern hiesse,
/// ihnen das Gedaechtnis wegzunehmen. Ein neues Format faengt dagegen frei an.
public struct Meldungsoptionen: Sendable, Equatable, Codable {
    public var text: String
    public var weg: SendeWeg = .pixel
    public var schrift: String = "Silkscreen"
    public var groesse: Double = 8
    public var fett: Bool = false
    public var farbe: String = "#00FF66"
    public var grossbuchstaben: Bool = false
    public var waagrecht: SendenHAusrichtung = .links
    public var senkrecht: SendenVAusrichtung = .oben
    public var rand: Int = 1
    public var abstand: Int = 1
    public var tempo: Lauftempo = .mittel
    public var iconLaeuftMit: Bool = false
    public var dauer: Int?
    /// `nil` heißt `Lebensdauer.vorgabe`, nicht „keine": Ältere Verlaufsdateien und
    /// andere Schreiber kennen den Schlüssel nicht und müssen lesbar bleiben —
    /// ihre Anzeigen bekommen dann wie jede neue die Vorgabe. Ausgeschaltet ist
    /// `Lebensdauer.aus`.
    public var lebensdauer: Lebensdauer?
    /// Hintergrund, Effekt, Overlay und Palette, wie die Oberfläche sie gewählt
    /// hat. `nil` heißt nichts gewählt; ältere Dateien kennen den Schlüssel nicht.
    /// Was davon hinausgeht, entscheidet der Weg (`Darstellungswahl.darstellung`).
    public var darstellung: Darstellungswahl?

    /// Was die Uhr bekommt: die gewählte oder die Vorgabe; `nil`, wenn
    /// ausgeschaltet.
    public var wirksameLebensdauer: Lebensdauer? {
        let l = lebensdauer ?? .vorgabe
        return l.sekunden > 0 ? l : nil
    }

    public init(text: String,
                weg: SendeWeg = .pixel,
                schrift: String = "Silkscreen",
                groesse: Double = 8,
                fett: Bool = false,
                farbe: String = "#00FF66",
                grossbuchstaben: Bool = false,
                waagrecht: SendenHAusrichtung = .links,
                senkrecht: SendenVAusrichtung = .oben,
                rand: Int = 1,
                abstand: Int = 1,
                tempo: Lauftempo = .mittel,
                iconLaeuftMit: Bool = false,
                dauer: Int? = nil,
                lebensdauer: Lebensdauer? = nil,
                darstellung: Darstellungswahl? = nil) {
        self.text = text
        self.weg = weg
        self.schrift = schrift
        self.groesse = groesse
        self.fett = fett
        self.farbe = farbe
        self.grossbuchstaben = grossbuchstaben
        self.waagrecht = waagrecht
        self.senkrecht = senkrecht
        self.rand = rand
        self.abstand = abstand
        self.tempo = tempo
        self.iconLaeuftMit = iconLaeuftMit
        self.dauer = dauer
        self.lebensdauer = lebensdauer
        self.darstellung = darstellung
    }

    /// Der Text, wie er tatsächlich gerastert bzw. geschickt wird — die einzige
    /// Stelle, an der „Großbuchstaben" wirkt. Nebeneffekt von `uppercased()`:
    /// aus „ß" wird „SS".
    public var gesendeterText: String { grossbuchstaben ? text.uppercased() : text }

    /// `align`/`valign` in den Namen, die das Gerät für `text` erwartet (§4.3).
    public var geraeteAusrichtung: String {
        switch waagrecht { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    public var geraeteVertikal: String {
        switch senkrecht { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }
}

extension Meldungsoptionen {
    /// Die Optionen, mit denen die Vorschau rastert: auf dem Pixelweg die
    /// gesendeten selbst (die Vorschau zeigt genau das Feld, das hinausgeht),
    /// beim Text im Geraetefont die Naeherung.
    public var fuerVorschau: Meldungsoptionen { weg == .pixel ? self : naeherung }

    /// Die Vorschau von „als Text" ist eine Näherung, immer dieselbe.
    ///
    /// AWTRIX NG setzt den Text mit ihrer eigenen Schrift; unsere Schriftwahl
    /// ist dort gesperrt (`AwtrixNG.wirkt(.schriftart)`). Der gespeicherte
    /// Wert bleibt davon aber unberührt und kann „Tiny5, 16 px" sein — die
    /// Vorschau zeigte dann eine Schrift, die das Gerät gar nicht hat.
    ///
    /// Gewählt ist Silkscreen in 8 px: eine Pixelschrift, die auf der
    /// abgesegneten Liste steht (`Pixelgroessen.abgesegnet`).
    ///
    /// Angerührt werden nur Schrift und Größe. Farbe, Ausrichtung, Abstand und
    /// das mitlaufende Icon sind Regler, die NG kennt (`AwtrixNG.wirkt`) —
    /// sie zu ersetzen hieße, die Vorschau von der Einstellung abzukoppeln,
    /// die wirklich gesendet wird.
    ///
    /// Im Kern und nicht in den Ansichten: Mac und iPhone rufen dasselbe, sonst
    /// laufen zwei Abschriften derselben Tabelle früher oder später auseinander
    /// (siehe `Regler` in `AwtrixNG.swift`).
    public var naeherung: Meldungsoptionen {
        var o = self
        o.schrift = "Silkscreen"
        o.groesse = 8
        return o
    }
}

/// Baut aus Optionen und Icon den Rahmen, den die Uhr bekommt.
///
/// Wortgetreu aus `SendenView` gelöst. Keine Rechnung wurde dabei geändert;
/// die Schnappschusstests halten das fest.
public enum Meldungsbau {
    /// Luft zwischen Icon und Text.
    public static let iconLuecke = 2

    /// Wo das Icon endet: seine Kante plus die Luft. Bei 8×8 zehn Spalten wie
    /// bisher, bei 16×16 achtzehn.
    public static func iconBreite(kante: Int = 8) -> Int { kante + iconLuecke }

    /// Auf welcher Zeile das Icon sitzt: senkrecht mittig im Feld. Auf den
    /// sechzehn Zeilen ergibt das bei 8×8 die 4 und bei 16×16 die 0 — ein
    /// 16×16 fuellt die volle Hoehe und schwimmt nicht.
    public static func iconY(kante: Int = 8, mass: Anzeigemass = .vorgabe) -> Int {
        mass.iconY(kante: kante)
    }

    /// `iconKante` hat ueberall eine Vorgabe: Jede Stelle, die frueher nur
    /// „Icon ja/nein" wusste, meinte damit ein 8×8 und rechnet unveraendert
    /// weiter.
    public static func flaecheX(mitIcon: Bool, iconKante: Int = 8) -> Int {
        mitIcon ? iconBreite(kante: iconKante) : 0
    }
    public static func flaecheBreite(mitIcon: Bool, iconKante: Int = 8,
                                     mass: Anzeigemass = .vorgabe) -> Int {
        mass.breite - flaecheX(mitIcon: mitIcon, iconKante: iconKante)
    }

    /// Der Schlüssel der Rasterrechnung: genau die Größen, von denen
    /// `Textraster` abhängt. Alles andere an den Optionen (Ausrichtung, Rand,
    /// Tempo) ändert das Ergebnis nicht.
    private struct Rasterschluessel: Hashable {
        let text: String, schrift: String, groesse: Double, fett: Bool
        let farbe: String, luecke: Int, breite: Int, hoehe: Int
    }

    private final class Rasterspeicher: @unchecked Sendable {
        let sperre = NSLock()
        var puffer: [Rasterschluessel: Pixelfeld] = [:]
        var breiten: [Rasterschluessel: Int] = [:]
    }
    private static let rasterspeicher = Rasterspeicher()

    /// Eine Obergrenze, damit eine lange Sitzung den Speicher nicht füllt: Je
    /// Tastendruck entsteht ein neuer Schlüssel, gebraucht werden ein paar je Uhr.
    private static let rasterspeicherGrenze = 64

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    ///
    /// Zwischengespeichert, weil die Vorschau je Neuberechnung ihres Aufbaus
    /// `passt`, `feld` und `versatzY` für jede Uhr fragt — das sind je Uhr drei
    /// Rasterläufe (ein `CGContext` je Zeichen) für dieselben Werte, und
    /// jedes Layout der Vorschau wiederholt sie. Die Rechnung ist rein; der
    /// Schlüssel enthält alles, wovon sie abhängt.
    public static func puffer(_ o: Meldungsoptionen, mass: Anzeigemass = .vorgabe) -> Pixelfeld {
        let k = Rasterschluessel(text: o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                 fett: o.fett, farbe: o.farbe, luecke: o.abstand,
                                 breite: mass.breite, hoehe: mass.hoehe)
        rasterspeicher.sperre.lock()
        let bekannt = rasterspeicher.puffer[k]
        rasterspeicher.sperre.unlock()
        if let bekannt { return bekannt }
        let f = Textraster.rasterPuffer(k.text, schrift: k.schrift, groesse: k.groesse,
                                        fett: k.fett, farbe: k.farbe, luecke: k.luecke, mass: mass)
        rasterspeicher.sperre.lock()
        if rasterspeicher.puffer.count >= rasterspeicherGrenze { rasterspeicher.puffer.removeAll() }
        rasterspeicher.puffer[k] = f
        rasterspeicher.sperre.unlock()
        return f
    }

    /// Zwischengespeichert aus demselben Grund wie `puffer`; die Breite hängt
    /// nicht vom Anzeigemaß ab.
    public static func breite(_ o: Meldungsoptionen) -> Int {
        let k = Rasterschluessel(text: o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                 fett: o.fett, farbe: "", luecke: o.abstand, breite: 0, hoehe: 0)
        rasterspeicher.sperre.lock()
        let bekannt = rasterspeicher.breiten[k]
        rasterspeicher.sperre.unlock()
        if let bekannt { return bekannt }
        let b = Textraster.breite(k.text, schrift: k.schrift, groesse: k.groesse,
                                  fett: k.fett, luecke: k.luecke)
        rasterspeicher.sperre.lock()
        if rasterspeicher.breiten.count >= rasterspeicherGrenze { rasterspeicher.breiten.removeAll() }
        rasterspeicher.breiten[k] = b
        rasterspeicher.sperre.unlock()
        return b
    }

    /// Passt der Text in die verfügbare Breite, steht er still — sonst läuft er
    /// als GIF durch. Gerechnet wird mit der Breite des stehenden Falls (mit
    /// Icon 42 Spalten). Hinge die Rechnung an „Icon mitscrollen", würde das
    /// Einschalten den Text passend machen, den Schalter verschwinden lassen
    /// und ihn wieder umwerfen.
    public static func passt(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                             mass: Anzeigemass = .vorgabe) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    public static func versatzY(_ o: Meldungsoptionen, mass: Anzeigemass = .vorgabe) -> Int {
        guard let tinte = Textraster.tintenZeilen(puffer(o, mass: mass)) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        // Mehr Rand, als Platz da ist, gaebe es nicht — dann bliebe nur
        // Abschneiden, und das will niemand.
        let r = min(o.rand, max(0, (mass.hoehe - hoehe) / 2))
        switch o.senkrecht {
        case .oben:   return -tinte.erste + r
        case .mittig: return (mass.hoehe - hoehe) / 2 - tinte.erste
        case .unten:  return (mass.hoehe - hoehe) - tinte.erste - r
        }
    }

    public static func versatzX(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                                mass: Anzeigemass = .vorgabe) -> Int {
        let x = flaecheX(mitIcon: mitIcon, iconKante: iconKante)
        let b = flaecheBreite(mitIcon: mitIcon, iconKante: iconKante, mass: mass)
        switch o.waagrecht {
        case .links:  return x
        case .mittig: return x + max(0, (b - breite(o)) / 2)
        case .rechts: return x + max(0, b - breite(o))
        }
    }

    /// Vorschau und Sendung entstehen aus demselben Feld. Gerastert wird immer
    /// in derselben Phase, ausgerichtet wird durch Verschieben — sonst sähe
    /// dieselbe Schrift stehend anders aus als laufend.
    public static func feld(_ o: Meldungsoptionen, mitIcon: Bool, iconKante: Int = 8,
                            mass: Anzeigemass = .vorgabe) -> Pixelfeld {
        var f = Pixelfeld(breite: mass.breite, hoehe: mass.hoehe)
        Textraster.einsetzen(puffer(o, mass: mass),
                             x: versatzX(o, mitIcon: mitIcon, iconKante: iconKante, mass: mass),
                             y: versatzY(o, mass: mass), in: &f)
        // „Als Text" zeichnet NG vergroessert auf 26 × 8 (§1.1); die Vorschau
        // deutet das mit 2 × 2 grossen Punkten an.
        return o.weg == .text ? f.inDoppelpixeln() : f
    }

    /// Die Einzelbilder der Laufschrift. Getrennt von `rahmen`, weil die
    /// Vorschau sie zum Abspielen braucht, während `rahmen` sie bereits zu
    /// einem GIF verpackt hat.
    public static func laufschriftBilder(_ o: Meldungsoptionen,
                                  iconBilder: [[String?]],
                                  iconKante: Int = 8,
                                  mass: Anzeigemass = .vorgabe) -> [Bildraster.Einzelbild] {
        let bilder = Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o, mass: mass), iconBilder: iconBilder, iconKante: iconKante,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand, mass: mass)
        // Die Zeit, die das GIF tatsaechlich traegt (ganze Hundertstel):
        // Vorschau und Sendung laufen gleich schnell.
        return bilder.map { b in
            let pixel = o.weg == .text
                ? Pixelfeld(breite: mass.breite, hoehe: mass.hoehe, punkte: b.pixel)?
                    .inDoppelpixeln().punkteRoh ?? b.pixel
                : b.pixel
            return Bildraster.Einzelbild(pixel: pixel, dauer: Bildraster.gifZeit(b.dauer))
        }
    }

    /// Der Rahmen zu einer Meldung.
    ///
    /// `.pixel`: die App rastert selbst und schickt Pixel (`Pixelweg`) — ein
    /// Standbild, wenn der Text passt, sonst die Einzelbilder der Laufschrift,
    /// die auch die Vorschau abspielt. Ein Icon steckt in den Pixeln.
    ///
    /// `.text`: Text und Regler samt Icon als `Meldungsherkunft`, aus der NG
    /// die Anzeige in ihrer Schrift setzt (`NGNutzlast.anzeige`).
    public static func rahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung,
                              mass: Anzeigemass = .vorgabe) throws -> Frame {
        switch o.weg {
        case .text:
            return Frame(dauer: o.dauer,
                         herkunft: Meldungsherkunft(
                            optionen: o,
                            iconDatenURI: try icon.map { try iconAlsGIF($0, sammlung: sammlung) }),
                         lebensdauer: o.wirksameLebensdauer,
                         darstellung: o.darstellung?.darstellung(weg: .text))
        case .pixel:
            return Frame(pixel: try pixelinhalt(o, icon: icon, mass: mass), dauer: o.dauer,
                         lebensdauer: o.wirksameLebensdauer,
                         darstellung: o.darstellung?.darstellung(weg: .pixel))
        }
    }

    /// Die Pixel einer Meldung — dieselbe Rechnung, die die Vorschau zeigt.
    static func pixelinhalt(_ o: Meldungsoptionen, icon: Icon?, mass: Anzeigemass) throws -> Pixelinhalt {
        let mitIcon = icon != nil
        let kante = icon?.kante ?? 8
        let iconBilder = icon.flatMap {
            try? Bildraster.lesenMitZeiten($0.datei, breite: kante, hoehe: kante)
        } ?? []
        let bilder: [Bildraster.Einzelbild]
        if passt(o, mitIcon: mitIcon, iconKante: kante, mass: mass) {
            let text = feld(o, mitIcon: mitIcon, iconKante: kante, mass: mass)
            let y = iconY(kante: kante, mass: mass)
            // Ein bewegtes Icon neben stehendem Text: jedes Icon-Bild ein
            // Einzelbild, mit der Zeit aus der Datei.
            bilder = (iconBilder.isEmpty ? [nil] : iconBilder.map { Optional($0) }).map { ib in
                var f = text
                if let ib {
                    for dy in 0..<kante {
                        for dx in 0..<kante {
                            if let p = ib.pixel[dy * kante + dx] { f.setzen(x: dx, y: y + dy, farbe: p) }
                        }
                    }
                }
                return Bildraster.Einzelbild(pixel: f.punkteRoh, dauer: Bildraster.gifZeit(ib?.dauer ?? 1))
            }
        } else {
            bilder = laufschriftBilder(o, iconBilder: iconBilder.map(\.pixel), iconKante: kante, mass: mass)
        }
        let inhalt = Pixelinhalt(breite: mass.breite, hoehe: mass.hoehe, bilder: bilder)
        try Pixelweg.pruefen(inhalt)
        return inhalt
    }

    /// Das Icon als GIF-Data-URL; eine PNG- oder JPEG-Datei wird umgerechnet
    /// (`NGNutzlast.icon` nimmt nur GIF).
    static func iconAlsGIF(_ icon: Icon, sammlung: Iconsammlung) throws -> String {
        let uri = try sammlung.datenURI(fuer: icon)
        if uri.hasPrefix("data:image/gif;") { return uri }
        let bilder = try Bildraster.lesenMitZeiten(icon.datei, breite: icon.kante, hoehe: icon.kante)
        return try Pixelweg.gifDatenURI(Pixelinhalt(breite: icon.kante, hoehe: icon.kante, bilder: bilder))
    }
}

/// Die fünf Plätze, unter denen diese App Anzeigen auf der Uhr ablegt.
///
/// Der Name eines Platzes ist zugleich der Bezeichner der Anzeige auf dem
/// Gerät. Wer ihn ändert, findet die alten Anzeigen nicht mehr und kann sie
/// nicht mehr löschen.
public enum Meldungsplatz {
    public static let anzahl = 5
    public static func name(fuer platz: Int) -> String { "meldung\(platz)" }

    /// Die Kehrseite von `name(fuer:)`: welcher der fuenf Plaetze (falls
    /// einer) sich hinter einem Anzeigenamen verbirgt. `nil` fuer jeden
    /// anderen Namen — etwa eine frei gewaehlte Anzeige des
    /// Kommandozeilenwerkzeugs (Vorgabe „cli"), fuer die es keinen Platz
    /// gibt, den sich das Slotgedaechtnis merken koennte.
    public static func platz(fuerName name: String) -> Int? {
        (1...anzahl).first { Self.name(fuer: $0) == name }
    }
}
