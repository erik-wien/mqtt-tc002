import Foundation

/// Der Abstand zwischen Icon und Text, den eine Uhr bekommt (`Uhr.iconAbstand`).
///
/// In Pixeln der Anzeige. Die Firmware kennt ihn nur als Schlüssel `iconGap`
/// einer einzelnen Anzeige, nicht als Einstellung der Uhr; er ist darum ein
/// Wert der App je Uhr.
public enum Iconabstand {
    /// Ein Pixel Luft, wie bisher im Pixelweg und wie die Vorgabe der Firmware.
    public static let vorgabe = 1
    public static let bereich = 0...16

    public static func begrenzt(_ wert: Int) -> Int { min(max(wert, bereich.lowerBound), bereich.upperBound) }
}

/// Wie viel Platz ein Icon braucht und wo der Text neben ihm beginnt — die
/// einzige Stelle, an der das gerechnet wird. Pixelweg, Schrift der Uhr, beide
/// Vorschauen, Slotgedächtnis und die Nutzlast (`iconGap`) lesen dieselben Zahlen,
/// sonst weicht die Vorschau vom Display ab.
///
/// Das Icon wird immer auf seine Tinte zugeschnitten, links und rechts
/// (`Bildraster.tintenKasten`: Schwarz zählt nicht, bei bewegten Icons gilt der
/// gemeinsame Kasten aller Bilder, damit nichts wandert). Die Höhe bleibt, das
/// Icon sitzt senkrecht mittig wie zuvor. Ein Icon ohne Tinte hat keinen
/// `Iconplatz` (`nil`) und verhält sich in jedem Weg wie kein Icon: kein
/// Zuschnitt auf null Spalten, kein Abstand.
public struct Iconplatz: Hashable, Sendable {
    /// Seitenlänge des Quellrasters (8 oder 16); die Höhe des Icons.
    public let kante: Int
    /// Spalten links der Tinte, die wegfallen.
    public let links: Int
    /// Breite des zugeschnittenen Icons in Spalten, mindestens 1.
    public let breite: Int
    /// Gewünschte Luft zwischen Icon und Text in Pixeln der Anzeige.
    public let abstand: Int

    public init(kante: Int, links: Int, breite: Int, abstand: Int = Iconabstand.vorgabe) {
        self.kante = kante
        self.links = max(0, links)
        self.breite = max(1, breite)
        self.abstand = Iconabstand.begrenzt(abstand)
    }

    /// Ein Icon, das nicht zugeschnitten ist: die volle Kante. Für Stellen, die
    /// das Icon nicht gelesen haben (Hilfebilder, Tests), und für den Rückfall.
    public static func voll(kante: Int = 8, abstand: Int = Iconabstand.vorgabe) -> Iconplatz {
        Iconplatz(kante: kante, links: 0, breite: kante, abstand: abstand)
    }

    /// Misst die Tinte über alle Einzelbilder (`kante` × `kante`, zeilenweise).
    /// `nil`, wenn keines Tinte hat.
    public static func vermessen(_ bilder: [[String?]], kante: Int,
                                 abstand: Int = Iconabstand.vorgabe) -> Iconplatz? {
        guard let k = Bildraster.tintenKasten(bilder, breite: kante, hoehe: kante) else { return nil }
        return Iconplatz(kante: kante, links: k.minX, breite: k.maxX - k.minX + 1, abstand: abstand)
    }

    /// Dasselbe an einer Icondatei. Gemerkt je Datei und Änderungszeit: Die
    /// Ansichten fragen bei jedem Neuzeichnen, das Lesen eines GIFs soll nicht
    /// jedes Mal stattfinden. Eine unlesbare Datei gilt als voll (das Senden meldet
    /// den Fehler selbst, die Vorschau bleibt bedienbar).
    public static func vermessen(_ icon: Icon, abstand: Int = Iconabstand.vorgabe) -> Iconplatz? {
        let schluessel = Messschluessel(pfad: icon.datei.path, kante: icon.kante,
                                        geaendert: (try? icon.datei.resourceValues(forKeys: [.contentModificationDateKey]))?
                                            .contentModificationDate)
        speicher.sperre.lock()
        let bekannt = speicher.messungen[schluessel]
        speicher.sperre.unlock()
        let messung: Messung
        if let bekannt {
            messung = bekannt
        } else {
            if let bilder = try? Bildraster.lesen(icon.datei, breite: icon.kante, hoehe: icon.kante) {
                if let k = Bildraster.tintenKasten(bilder, breite: icon.kante, hoehe: icon.kante) {
                    messung = .tinte(links: k.minX, breite: k.maxX - k.minX + 1)
                } else {
                    messung = .keine
                }
            } else {
                messung = .voll
            }
            speicher.sperre.lock()
            if speicher.messungen.count >= 256 { speicher.messungen.removeAll() }
            speicher.messungen[schluessel] = messung
            speicher.sperre.unlock()
        }
        switch messung {
        case .keine: return nil
        case .voll: return .voll(kante: icon.kante, abstand: abstand)
        case .tinte(let l, let b): return Iconplatz(kante: icon.kante, links: l, breite: b, abstand: abstand)
        }
    }

    private struct Messschluessel: Hashable { let pfad: String; let kante: Int; let geaendert: Date? }
    private enum Messung { case keine, voll, tinte(links: Int, breite: Int) }
    private final class Speicher: @unchecked Sendable {
        let sperre = NSLock()
        var messungen: [Messschluessel: Messung] = [:]
    }
    private static let speicher = Speicher()

    /// Ob nichts abgeschnitten wird.
    public var istVoll: Bool { links == 0 && breite == kante }

    /// Die Luft in Spalten der Seite, auf der die Uhr zeichnet. `faktor` ist die
    /// Vergrößerung (2 bei vergrößerten Anzeigen der TC002, sonst 1); `iconGap`
    /// zählt dort in Spalten des 26×8-Rasters, also in Doppelpixeln
    /// (`docs/awtrix-ng-protokoll.md` §5.3). Ungerade Wünsche runden auf, damit
    /// der Wert 1 der Vorgabe der Firmware entspricht.
    public func luecke(faktor: Int = 1) -> Int {
        faktor <= 1 ? abstand : (abstand + faktor - 1) / faktor
    }

    /// Spalte der Seite, in der der Text neben dem Icon beginnt.
    public func textAb(faktor: Int = 1) -> Int { breite + luecke(faktor: faktor) }

    /// Das Icon auf die Spalten seiner Tinte zugeschnitten (`breite` × `kante`).
    public func zuschneiden(_ pixel: [String?]) -> [String?] {
        guard pixel.count == kante * kante, !istVoll else { return pixel }
        var aus = [String?](repeating: nil, count: breite * kante)
        for y in 0..<kante {
            for x in 0..<breite { aus[y * breite + x] = pixel[y * kante + links + x] }
        }
        return aus
    }

    public func zuschneiden(_ bilder: [Bildraster.Einzelbild]) -> [Bildraster.Einzelbild] {
        bilder.map { Bildraster.Einzelbild(pixel: zuschneiden($0.pixel), dauer: $0.dauer) }
    }
}
