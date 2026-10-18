import Foundation

/// Ein Zusatzicon: ein weiteres, einzeln bewegtes Icon neben dem normalen
/// (`icons[]` der Firmware, `docs/awtrix-ng-protokoll.md` §5.3).
///
/// `x` und `y` sind **Pixel der Anzeige** (obere linke Ecke des Icons, 0/0 ist die
/// Ecke der Anzeige). Was daraus auf der Uhr wird, hängt vom Weg ab: Im Pixelweg
/// backt die App das Icon an genau diese Stelle ein, bei der Schrift der Uhr
/// rechnet `Zusatzicons.seitenwert` in Spalten der Seite um, auf der die Uhr
/// zeichnet.
///
/// Dateiformat: `Meldungsoptionen` (Sendeverlauf) und `Slotstand` tragen die
/// Liste als optionales Feld; `kante == nil` heißt 8 wie bei `Slotstand.iconKante`,
/// damit ein 8×8 Byte für Byte so geschrieben wird wie ein gemerktes Icon.
public struct Zusatzicon: Codable, Hashable, Sendable {
    /// `Icon.nummer`, bei einem 16×16 der Dateiname.
    public var nummer: String
    public var kante: Int?
    public var x: Int
    public var y: Int

    public var kanteOderAcht: Int { kante ?? 8 }

    public init(nummer: String, kante: Int = 8, x: Int = 0, y: Int = 0) {
        self.nummer = nummer
        self.kante = kante == 8 ? nil : min(max(kante, 1), 64)
        self.x = Zusatzicons.klemmen(x)
        self.y = Zusatzicons.klemmen(y)
    }

    /// Eine fremde oder beschädigte Datei darf nichts mitbringen, womit später
    /// gerechnet wird: Koordinaten und Kante werden beim Lesen geklemmt.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(nummer: try c.decode(String.self, forKey: .nummer),
                  kante: try c.decodeIfPresent(Int.self, forKey: .kante) ?? 8,
                  x: try c.decodeIfPresent(Int.self, forKey: .x) ?? 0,
                  y: try c.decodeIfPresent(Int.self, forKey: .y) ?? 0)
    }

    public init(icon: Icon, x: Int = 0, y: Int = 0) {
        self.init(nummer: icon.nummer, kante: icon.kante, x: x, y: y)
    }

    /// Mit Koordinaten innerhalb von `Zusatzicons.xBereich` und `yBereich`.
    public var begrenzt: Zusatzicon {
        var z = self
        z.x = min(max(x, Zusatzicons.xBereich.lowerBound), Zusatzicons.xBereich.upperBound)
        z.y = min(max(y, Zusatzicons.yBereich.lowerBound), Zusatzicons.yBereich.upperBound)
        return z
    }
}

/// Ein aufgelöstes Zusatzicon für eine bestimmte Uhr: die Fassung, die ihr Maß
/// aufnimmt, mit allen Einzelbildern.
public struct Zusatzplatz: Equatable, Sendable {
    public let icon: Icon
    /// Pixel der Anzeige (`Zusatzicon.x`, `.y`).
    public let x: Int
    public let y: Int
    /// Die Einzelbilder (`icon.kante` im Quadrat), mit den Standzeiten der Datei.
    /// Nicht auf die Tinte zugeschnitten: x/y beziehen sich auf die Ecke der Datei,
    /// wie bei einer Kennung auf der Uhr. Nur ein deckend schwarzer Rand fällt weg,
    /// damit er den Text darunter nicht überdeckt (`Bildraster.schwarzrandBegrenzt`).
    public let bilder: [Bildraster.Einzelbild]
}

/// Was an die Uhr geht, wenn sie die Zusatzicons selbst zeichnet (`icons[]`).
public struct Zusatzsendung: Equatable, Sendable {
    /// GIF als vollständige Daten-URI.
    public var iconDatenURI: String
    /// Spalten und Zeilen der Seite, auf der die Uhr zeichnet.
    public var x: Int
    public var y: Int

    public init(iconDatenURI: String, x: Int, y: Int) {
        self.iconDatenURI = iconDatenURI
        self.x = x
        self.y = y
    }
}

/// Die Zusatzicons einer Anzeige: Grenzen, Umrechnung der Koordinaten und
/// Einbacken ins Raster — die einzige Stelle, an der das gerechnet wird. Die
/// Nutzlast (`NGNutzlast.anzeige`), der Pixelweg (`Meldungsbau.pixelinhalt`) und
/// beide Vorschauen lesen dieselben Zahlen.
///
/// Reihenfolge wie bei der Firmware (`RenderPipeline`): Hintergrund, Text, Icon,
/// dann die Zusatzicons in Feldreihenfolge — spätere decken frühere —, dann das
/// Overlay. Zusatzicons nehmen dem Text keinen Platz und laufen nicht mit
/// (`iconMode` gilt nur für das normale Icon).
public enum Zusatzicons {
    /// Mehr nimmt die Firmware nicht an (`422`, `field` = `icons[4]`…).
    public static let hoechstzahl = 4
    /// Eingabebereich der Oberfläche. Die Firmware nähme −65535…65535; die breiteste
    /// NG-Matrix hat 128 Spalten, die höchste 16 Zeilen.
    public static let xBereich = 0...127
    public static let yBereich = 0...15
    /// Grenzen der Firmware für `x` und `y`.
    static let firmwareBereich = -65535...65535

    /// Höchstens vier, mit begrenzten Koordinaten.
    public static func begrenzt(_ liste: [Zusatzicon]?) -> [Zusatzicon] {
        (liste ?? []).prefix(hoechstzahl).map(\.begrenzt)
    }

    /// Die Liste als Text für die Einstellungen der Oberfläche (ein Schlüssel für
    /// Mac, iPad und iPhone); leer für keine.
    public static func json(_ liste: [Zusatzicon]) -> String {
        guard !liste.isEmpty, let daten = try? JSONEncoder().encode(liste) else { return "" }
        return String(decoding: daten, as: UTF8.self)
    }

    /// Das Gegenstück; Unlesbares heißt keine.
    public static func aus(json: String) -> [Zusatzicon] {
        guard let liste = try? JSONDecoder().decode([Zusatzicon].self, from: Data(json.utf8)) else { return [] }
        return Array(liste.prefix(hoechstzahl))
    }

    /// Ob noch eines dazukommen darf.
    public static func kannHinzufuegen(_ liste: [Zusatzicon]) -> Bool { liste.count < hoechstzahl }

    /// Das Icon zu einem Eintrag; `nil` bei einem Eintrag ohne Wahl (leere Nummer)
    /// und bei einem, den es nicht mehr gibt.
    public static func icon(zu z: Zusatzicon, in sammlungen: [Iconsammlung]) -> Icon? {
        guard !z.nummer.isEmpty else { return nil }
        return sammlungen.flatMap { $0.alle() }.first { $0.nummer == z.nummer && $0.kante == z.kanteOderAcht }
    }

    /// Setzt oder löscht das Icon eines Eintrags, die Stelle bleibt.
    public static func setzen(_ icon: Icon?, in z: inout Zusatzicon) {
        z = Zusatzicon(nummer: icon?.nummer ?? "", kante: icon?.kante ?? 8, x: z.x, y: z.y)
    }

    /// Zählt die Seite der Uhr einen Anzeigepixel in `faktor` Punkten? Die
    /// Firmware blittet auf die Seite (`blit(page, icon.x, icon.y)`), und die ist
    /// auf der vergrößerten TC002 26 × 8: eine Spalte sind dort zwei Punkte der
    /// Anzeige. Abgerundet (auch bei Negativem), die Vorschau zeichnet dann an
    /// `seitenwert * faktor`.
    public static func seitenwert(_ anzeige: Int, faktor: Int) -> Int {
        let a = klemmen(anzeige), faktor = min(faktor, 8)
        guard faktor > 1 else { return a }
        if a >= 0 { return a / faktor }
        return -((-a + faktor - 1) / faktor)
    }

    /// Auf die Grenzen der Firmware, bevor damit gerechnet wird: Mit Werten bis
    /// ±65535 kann keine der Rechnungen hier überlaufen.
    static func klemmen(_ wert: Int) -> Int {
        min(max(wert, firmwareBereich.lowerBound), firmwareBereich.upperBound)
    }

    /// Die Anzeigepixel, an denen die Uhr das Icon tatsächlich zeichnet.
    public static func gezeichnet(_ anzeige: Int, faktor: Int) -> Int {
        seitenwert(anzeige, faktor: faktor) * min(max(1, faktor), 8)
    }

    /// Löst die gewählten Icons für eine Uhr auf. Ein Icon, das es nicht mehr gibt
    /// oder dessen Datei sich nicht lesen lässt, entfällt ohne Meldung (wie das
    /// normale Icon); eines, das höher oder breiter ist als die Anzeige, ebenso
    /// (die Firmware nimmt keines, das größer ist). Ein 16×16 wird auf einer Uhr
    /// mit acht Zeilen durch seine 8×8-Fassung ersetzt (`Iconbestaende.passend`).
    public static func laden(_ liste: [Zusatzicon]?, mass: Anzeigemass,
                             bestaende: (() -> [Iconsammlung])? = nil) -> [Zusatzplatz] {
        let gewaehlt = begrenzt(liste)
        guard !gewaehlt.isEmpty else { return [] }
        let sammlungen = (bestaende ?? Iconbestaende.alle)()
        let alle = sammlungen.flatMap { $0.alle() }
        return gewaehlt.compactMap { z in
            guard let treffer = alle.first(where: { $0.nummer == z.nummer && $0.kante == z.kanteOderAcht })
            else { return nil }
            let icon = Iconbestaende.passend(treffer, fuer: mass, in: { sammlungen })
            guard icon.kante <= mass.hoehe, icon.kante <= mass.breite,
                  let bilder = einzelbilder(icon) else { return nil }
            return Zusatzplatz(icon: icon, x: z.x, y: z.y, bilder: bilder)
        }
    }

    /// Welche Kanten die Zusatzicons haben, soweit die Oberfläche sie kennt.
    /// Die Firmware vergrößert eine Seite nur, wenn **jedes** Bild auf die
    /// 26 × 8 große Zwischenfläche passt (`PageZoom::enlarges`).
    static func kanten(_ liste: [Zusatzicon]?) -> [Int] {
        begrenzt(liste).map(\.kanteOderAcht)
    }

    /// Das GIF jedes Zusatzicons und seine Koordinaten in Spalten der Seite, auf
    /// der die Uhr zeichnet (`faktor`: 2 auf der vergrößerten TC002, sonst 1).
    /// Ein 8×8 wird dort mit verdoppelt, wie das normale Icon.
    static func sendungen(_ plaetze: [Zusatzplatz], faktor: Int,
                          sammlung: Iconsammlung) throws -> [Zusatzsendung] {
        try plaetze.map { p in
            let uri = try Meldungsbau.iconAlsGIF(p.icon, platz: .voll(kante: p.icon.kante), sammlung: sammlung)
            return Zusatzsendung(iconDatenURI: uri,
                                 x: seitenwert(p.x, faktor: faktor), y: seitenwert(p.y, faktor: faktor))
        }
    }

    /// Legt die Zusatzicons auf ein Einzelbild der Anzeige (`breite` × `hoehe`
    /// Punkte, zeilenweise). `bildnummern[i]` ist das Bild des i-ten Icons; zu
    /// große Nummern laufen in Schleife über die Bilder des Icons. `faktor`
    /// vergrößert die Icons und setzt sie auf das Raster der Seite
    /// (`gezeichnet`); im Pixelweg ist er 1. Nichts Durchsichtiges überschreibt.
    static func aufbringen(_ plaetze: [Zusatzplatz], bildnummern: [Int], faktor: Int,
                           auf pixel: inout [String?], breite: Int, hoehe: Int) {
        let f = min(max(1, faktor), 8)
        guard breite > 0, hoehe > 0, breite <= Pixelweg.hoechsteBreite, hoehe <= Pixelweg.hoechsteHoehe,
              pixel.count == breite * hoehe else { return }
        for (i, p) in plaetze.enumerated() {
            guard !p.bilder.isEmpty else { continue }
            let nummer = i < bildnummern.count ? max(0, bildnummern[i]) : 0
            let bild = p.bilder[nummer % p.bilder.count].pixel
            let kante = p.icon.kante
            guard bild.count == kante * kante else { continue }
            let x0 = gezeichnet(p.x, faktor: f), y0 = gezeichnet(p.y, faktor: f)
            for y in 0..<kante {
                for x in 0..<kante {
                    guard let farbe = bild[y * kante + x] else { continue }
                    for dy in 0..<f {
                        for dx in 0..<f {
                            let px = x0 + x * f + dx, py = y0 + y * f + dy
                            if px >= 0, py >= 0, px < breite, py < hoehe { pixel[py * breite + px] = farbe }
                        }
                    }
                }
            }
        }
    }

    /// Die gemeinsame Zeitleiste mehrerer Spuren, jede mit ihren Bildzeiten (in
    /// Sekunden). Jede Spur läuft in ihrer Schleife; ein neues Einzelbild beginnt
    /// überall dort, wo irgendeine Spur umschaltet. Eine Zeile je Einzelbild:
    /// seine Dauer und das Bild jeder Spur.
    ///
    /// Gerechnet wird über ein Vielfaches aller Schleifenlängen, damit die Spuren
    /// beim Wiederholen des GIFs in Phase bleiben. Wird das länger als
    /// `hoechstdauer` oder braucht mehr Einzelbilder als `hoechstzahl`, gilt die
    /// längste einzelne Schleife; die kürzeren sind dann an ihrem Ende nicht mehr
    /// in Phase. Reicht auch das nicht, wirft sie `laufschriftZuVieleBilder`.
    static func zeitleiste(spuren: [[Double]], hoechstdauer: Double = 30,
                           hoechstzahl: Int = Pixelweg.hoechsteBildzahl) throws
        -> [(dauer: Double, bilder: [Int])] {
        // Hundertstel, wie ein GIF sie trägt.
        let zeiten = spuren.map { $0.map { max(2, Int(($0 * 100).rounded())) } }
        let laengen = zeiten.map { $0.reduce(0, +) }
        let bewegt = zeiten.indices.filter { zeiten[$0].count > 1 }
        guard !bewegt.isEmpty else {
            return [(dauer: spuren.first?.first ?? 1, bilder: Array(repeating: 0, count: spuren.count))]
        }
        func ggT(_ a: Int, _ b: Int) -> Int { b == 0 ? a : ggT(b, a % b) }
        let vielfaches = bewegt.reduce(1) { $0 / ggT($0, laengen[$1]) * laengen[$1] }
        func wechselzeiten(_ periode: Int) -> [Int] {
            var t = Set<Int>([0])
            for i in bewegt {
                var start = 0
                while start < periode {
                    var summe = start
                    for z in zeiten[i] { t.insert(summe); summe += z }
                    start += laengen[i]
                }
            }
            return t.filter { $0 < periode }.sorted()
        }
        func bild(_ spur: Int, bei t: Int) -> Int {
            var rest = t % laengen[spur]
            for (n, z) in zeiten[spur].enumerated() {
                if rest < z { return n }
                rest -= z
            }
            return zeiten[spur].count - 1
        }
        var periode = vielfaches
        var grenzen = vielfaches <= Int(hoechstdauer * 100) ? wechselzeiten(periode) : []
        if grenzen.isEmpty || grenzen.count > hoechstzahl {
            periode = bewegt.map { laengen[$0] }.max() ?? 0
            grenzen = wechselzeiten(periode)
        }
        guard grenzen.count <= hoechstzahl else {
            throw NGFehler.laufschriftZuVieleBilder(bilder: grenzen.count)
        }
        return grenzen.enumerated().map { n, t in
            let ende = n + 1 < grenzen.count ? grenzen[n + 1] : periode
            return (dauer: Double(ende - t) / 100, bilder: spuren.indices.map { bild($0, bei: t) })
        }
    }

    // MARK: Lesen

    private struct Schluessel: Hashable { let pfad: String; let kante: Int; let geaendert: Date? }
    private final class Speicher: @unchecked Sendable {
        let sperre = NSLock()
        var bilder: [Schluessel: [Bildraster.Einzelbild]] = [:]
    }
    private static let speicher = Speicher()

    /// Gemerkt je Datei und Änderungszeit: Die Vorschau fragt bei jedem Neuzeichnen.
    private static func einzelbilder(_ icon: Icon) -> [Bildraster.Einzelbild]? {
        let schluessel = Schluessel(pfad: icon.datei.path, kante: icon.kante,
                                    geaendert: (try? icon.datei.resourceValues(forKeys: [.contentModificationDateKey]))?
                                        .contentModificationDate)
        speicher.sperre.lock()
        let bekannt = speicher.bilder[schluessel]
        speicher.sperre.unlock()
        if let bekannt { return bekannt }
        guard let gelesen = try? Bildraster.lesenMitZeiten(icon.datei, breite: icon.kante, hoehe: icon.kante),
              !gelesen.isEmpty else { return nil }
        let bilder = gelesen.map {
            Bildraster.Einzelbild(pixel: Bildraster.schwarzrandBegrenzt($0.pixel, breite: icon.kante, hoehe: icon.kante),
                                  dauer: Bildraster.gifZeit($0.dauer))
        }
        speicher.sperre.lock()
        if speicher.bilder.count >= 64 { speicher.bilder.removeAll() }
        speicher.bilder[schluessel] = bilder
        speicher.sperre.unlock()
        return bilder
    }
}
