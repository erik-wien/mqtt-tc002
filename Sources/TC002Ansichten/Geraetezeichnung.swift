import SwiftUI
import TC002Core

/// Die Frontansicht eines Geraets als **Daten** — Flaechen, Schriftzuege,
/// Displayfeld und Pixelstil in einem eigenen Zeichenraum.
///
/// Gezeichnet wird das in `GeraeteRahmen`, und zwar fuer jede Geraeteart mit
/// demselben Code: Was sich unterscheidet, sind die Zahlen hier, nicht der Weg
/// dorthin. Eine dritte Geraeteart waere ein dritter Eintrag in `fuer(_:)` und
/// sonst nichts.
///
/// **Warum gezeichnet und nicht als Bild eingesetzt.** Bis hierher kam die
/// TC002-Front als SVG aus dem Bildkatalog. Das taugte fuer **eine** Art: Eine
/// zweite haette eine zweite Datei gebraucht, und die Feldmasse waeren
/// weiterhin von Hand an der Zeichnung abgelesene Zahlen im Quelltext gewesen
/// — zwei Wahrheiten, die auseinanderlaufen koennen, ohne dass es auffaellt.
/// Hier sind Zeichnung und Masse dieselbe Angabe: `feld` wird gezeichnet
/// *und* gerechnet.
///
/// Kein Kernwissen, sondern Bildschirmgeometrie — deshalb liegt der Typ in
/// `TC002Ansichten` und nicht in `TC002Core`, und deshalb haengt an
/// `Geraetetyp` selbst keine einzige Masszahl.
public struct Geraetezeichnung: Equatable, Sendable {

    /// Ein Rechteck im Zeichenraum. Eigener Typ statt `CGRect`, damit die
    /// Angaben lesbar bleiben und `Sendable` ohne Umweg gilt.
    public struct Rechteck: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var breite: Double
        public var hoehe: Double

        public init(x: Double, y: Double, breite: Double, hoehe: Double) {
            self.x = x; self.y = y; self.breite = breite; self.hoehe = hoehe
        }

        public var rechts: Double { x + breite }
        public var unten: Double { y + hoehe }
    }

    /// Was gezeichnet wird, in genau dieser Reihenfolge — spaeter Genanntes
    /// liegt oben.
    public enum Teil: Equatable, Sendable {
        /// Eine gefuellte Flaeche mit runden Ecken. `radius` 0 heisst eckig.
        case flaeche(Rechteck, radius: Double, farbe: String)
        /// Ein aufgedruckter Schriftzug. **Teil der Zeichnung, nicht der
        /// Oberflaeche**: Auf dem Geraet steht dieser Wortlaut aufgedruckt, er
        /// wird darum nicht uebersetzt (`Text(verbatim:)` in `GeraeteRahmen`).
        /// `y` ist die Grundlinie, wie in einer SVG.
        case schrift(String, x: Double, grundlinie: Double, groesse: Double,
                     farbe: String, rechtsbuendig: Bool)
    }

    /// Wie ein einzelnes Displaypixel gezeichnet wird — beides als Anteil der
    /// Kantenlaenge einer Rasterzelle, nicht in Punkten: Sonst sieht dieselbe
    /// Vorschau am Mac (Kante 8) und am Telefon (Kante 6) verschieden aus.
    public struct Pixelstil: Equatable, Sendable {
        /// Wieviel der Zelle frei bleibt. Gross = kleine, einzeln stehende
        /// Punkte; klein = grosse, fast zusammenhaengende.
        public var lueckeAnteil: Double
        /// Eckenradius des Punktes, als Anteil seiner eigenen Kante.
        /// 0 = hart eckig.
        public var eckenAnteil: Double

        public init(lueckeAnteil: Double, eckenAnteil: Double) {
            self.lueckeAnteil = lueckeAnteil
            self.eckenAnteil = eckenAnteil
        }

        /// Kantenlaenge des gezeichneten Punktes bei gegebener Zellenkante.
        public func punktKante(zelle: Double) -> Double {
            max(0, zelle * (1 - lueckeAnteil))
        }

        /// Eckenradius des gezeichneten Punktes bei gegebener Zellenkante.
        public func punktRadius(zelle: Double) -> Double {
            punktKante(zelle: zelle) * eckenAnteil
        }

        /// Das Kaestchen eines einzelnen Punktes — **mittig** in seiner Zelle,
        /// nicht links oben angeschlagen: Sonst liegt die ganze Luecke rechts
        /// und unten, und das Raster sitzt um einen halben Punkt schief im
        /// Feld. Beide Vorschauen zeichnen darueber, damit die Punkte am Mac
        /// und am Telefon gleich aussehen.
        public func kaestchen(spalte: Int, zeile: Int, zelle: Double) -> CGRect {
            let kante = punktKante(zelle: zelle)
            let rand = (zelle - kante) / 2
            return CGRect(x: Double(spalte) * zelle + rand,
                          y: Double(zeile) * zelle + rand,
                          width: kante, height: kante)
        }

        /// Der Pfad dazu — eckig oder mit runden Ecken, je nach `eckenAnteil`.
        public func pfad(spalte: Int, zeile: Int, zelle: Double) -> Path {
            let kasten = kaestchen(spalte: spalte, zeile: zeile, zelle: zelle)
            let radius = punktRadius(zelle: zelle)
            return radius > 0 ? Path(roundedRect: kasten, cornerRadius: radius) : Path(kasten)
        }
    }

    /// Der Zeichenraum, in dem alle Masse stehen.
    public var breite: Double
    public var hoehe: Double
    /// Das schwarze Displayfeld. Hier hinein kommt die Pixelvorschau.
    public var feld: Rechteck
    /// Der Gehaeusekoerper — gebraucht, um zu sagen, was *ueber* ihm liegt
    /// (Knopf, Abdeckplatte) und wie rund seine Ecken sind.
    public var gehaeuse: Rechteck
    public var gehaeuseRadius: Double
    public var teile: [Teil]
    public var pixelstil: Pixelstil

    public init(breite: Double, hoehe: Double, feld: Rechteck,
                gehaeuse: Rechteck, gehaeuseRadius: Double,
                teile: [Teil], pixelstil: Pixelstil) {
        self.breite = breite
        self.hoehe = hoehe
        self.feld = feld
        self.gehaeuse = gehaeuse
        self.gehaeuseRadius = gehaeuseRadius
        self.teile = teile
        self.pixelstil = pixelstil
    }

    /// Welche Zeichnung fuer welche Geraeteart. `nil` heisst `.tc002` —
    /// dieselbe Lesart wie bei `Uhr.typ`.
    ///
    /// Das `switch` ist die eigentliche Zusicherung: Ein dritter `Geraetetyp`
    /// laesst den Uebersetzer hier stehenbleiben, statt still die TC002-Front
    /// um ein fremdes Geraet zu legen.
    public static func fuer(_ typ: Geraetetyp?) -> Geraetezeichnung {
        switch typ ?? .tc002 {
        case .tc002: return .tc002
        case .awtrixNG: return .awtrixNG
        }
    }

    // MARK: - Masse

    /// Was `GeraeteRahmen` ausrechnen muss, bevor es zeichnet.
    public struct Masse: Equatable, Sendable {
        /// Umrechnung Zeichenraum → Punkte. Ein einziger Faktor fuer beide
        /// Achsen — daran haengt, dass nichts verzerrt.
        public var massstab: Double
        public var rahmenBreite: Double
        public var rahmenHoehe: Double
        public var feldX: Double
        public var feldY: Double
        public var feldBreite: Double
        public var feldHoehe: Double
    }

    /// Die Zeichnung wird so gross gezeichnet, dass ihr Displayfeld genau
    /// `inhaltHoehe` hoch ist. Damit passt die Pixelvorschau in der Hoehe
    /// **exakt** hinein, ohne Skalierung und ohne Verzerrung; weil Breite und
    /// Hoehe mit demselben `massstab` wachsen, bleibt auch alles andere im
    /// Verhaeltnis.
    public func masse(inhaltHoehe: Double) -> Masse {
        let massstab = inhaltHoehe / feld.hoehe
        return Masse(massstab: massstab,
                     rahmenBreite: breite * massstab,
                     rahmenHoehe: hoehe * massstab,
                     feldX: feld.x * massstab,
                     feldY: feld.y * massstab,
                     feldBreite: feld.breite * massstab,
                     feldHoehe: feld.hoehe * massstab)
    }

    /// Um wieviel der ganze Rahmen breiter ist als sein Displayfeld. Wer den
    /// Rahmen in eine gegebene Flaeche einpassen will, rechnet damit von der
    /// Pixelbreite auf die Rahmenbreite hoch — ohne die Zahlen abzuschreiben.
    public var breitenFaktor: Double { breite / feld.breite }
    /// Dasselbe fuer die Hoehe.
    public var hoehenFaktor: Double { hoehe / feld.hoehe }

    /// Wo die Pixelvorschau im Rahmen sitzt: an der Feldhoehe ausgerichtet,
    /// waagrecht zentriert. Das Feld ist nie schmaler als der Inhalt, aber
    /// auch nie nennenswert breiter — der schwarze Rest links und rechts
    /// bleibt unter einer Pixelbreite (`GeraeterahmenTests` misst das nach).
    public func inhaltEcke(inhaltBreite: Double, inhaltHoehe: Double) -> (x: Double, y: Double) {
        let m = masse(inhaltHoehe: inhaltHoehe)
        return (m.feldX + (m.feldBreite - inhaltBreite) / 2, m.feldY)
    }

    // MARK: - Die Ulanzi TC002 mit Werksfirmware

    /// Die Front der TC002, Zeichnung fuer Zeichnung aus der bisherigen SVG
    /// uebernommen (`viewBox 680×356`, Displayfeld `48,93 584×177`) — bis auf
    /// den Weg dorthin also dasselbe Bild wie zuvor.
    ///
    /// Reihenfolge wie in der Vorlage: erst was hinter dem Gehaeuse
    /// hervorschaut (Drehknopf, Abdeckplatte, Seitentaste, Sockel), dann das
    /// Gehaeuse, dann das Display, zuletzt der Aufdruck.
    public static let tc002: Geraetezeichnung = {
        let gehaeuse = Rechteck(x: 38, y: 83, breite: 604, hoehe: 207)
        let feld = Rechteck(x: 48, y: 93, breite: 584, hoehe: 177)
        return Geraetezeichnung(
            breite: 680, hoehe: 356,
            feld: feld,
            gehaeuse: gehaeuse, gehaeuseRadius: 10,
            teile: [
                // Hals des Drehknopfs, hinter der Abdeckplatte
                .flaeche(Rechteck(x: 110, y: 64, breite: 44, hoehe: 22), radius: 0, farbe: "#7E2A1A"),
                .flaeche(Rechteck(x: 114, y: 64, breite: 36, hoehe: 22), radius: 0, farbe: "#93321F"),
                // Abdeckplatte oben rechts
                .flaeche(Rechteck(x: 214, y: 62, breite: 364, hoehe: 20), radius: 5, farbe: "#1C1C1E"),
                .flaeche(Rechteck(x: 214, y: 62, breite: 364, hoehe: 7), radius: 3.5, farbe: "#37373A"),
                .flaeche(Rechteck(x: 222, y: 62, breite: 348, hoehe: 3), radius: 1.5, farbe: "#4E4E52"),
                .flaeche(Rechteck(x: 214, y: 78, breite: 364, hoehe: 4), radius: 2, farbe: "#121213"),
                // Der rote T-Knopf oben links
                .flaeche(Rechteck(x: 90, y: 46, breite: 84, hoehe: 22), radius: 2.5, farbe: "#BF4026"),
                .flaeche(Rechteck(x: 90, y: 46, breite: 84, hoehe: 5), radius: 2.5, farbe: "#DD5B3D"),
                .flaeche(Rechteck(x: 90, y: 63, breite: 84, hoehe: 5), radius: 2.5, farbe: "#9C3320"),
                .flaeche(Rechteck(x: 90, y: 46, breite: 7, hoehe: 22), radius: 2.5, farbe: "#CF4C30"),
                .flaeche(Rechteck(x: 167, y: 46, breite: 7, hoehe: 22), radius: 2.5, farbe: "#A53420"),
                // Rote Taste an der linken Seite
                .flaeche(Rechteck(x: 27, y: 105, breite: 10, hoehe: 19), radius: 2.5, farbe: "#B93A22"),
                .flaeche(Rechteck(x: 27, y: 105, breite: 4, hoehe: 19), radius: 2, farbe: "#D24F33"),
                // Sockel mit Anschluessen und Lueftungsschlitzen
                .flaeche(Rechteck(x: 40, y: 286, breite: 588, hoehe: 42), radius: 4, farbe: "#141415"),
                .flaeche(Rechteck(x: 40, y: 286, breite: 588, hoehe: 6), radius: 0, farbe: "#2A2A2C"),
                .flaeche(Rechteck(x: 75, y: 292, breite: 2, hoehe: 36), radius: 0, farbe: "#242426"),
                .flaeche(Rechteck(x: 595, y: 292, breite: 2, hoehe: 36), radius: 0, farbe: "#242426"),
                .flaeche(Rechteck(x: 130, y: 294, breite: 1.5, hoehe: 30), radius: 0, farbe: "#202022"),
                .flaeche(Rechteck(x: 185, y: 294, breite: 1.5, hoehe: 30), radius: 0, farbe: "#202022"),
                .flaeche(Rechteck(x: 465, y: 294, breite: 1.5, hoehe: 30), radius: 0, farbe: "#202022"),
                .flaeche(Rechteck(x: 520, y: 294, breite: 1.5, hoehe: 30), radius: 0, farbe: "#202022"),
                .flaeche(Rechteck(x: 560, y: 294, breite: 1.5, hoehe: 30), radius: 0, farbe: "#202022"),
                .flaeche(Rechteck(x: 237, y: 299, breite: 26, hoehe: 20), radius: 2, farbe: "#0A0A0B"),
                .flaeche(Rechteck(x: 242, y: 304, breite: 16, hoehe: 9), radius: 1.5, farbe: "#2E2E31"),
                .flaeche(Rechteck(x: 408, y: 299, breite: 26, hoehe: 20), radius: 2, farbe: "#0A0A0B"),
                .flaeche(Rechteck(x: 413, y: 304, breite: 16, hoehe: 9), radius: 1.5, farbe: "#2E2E31"),
                .flaeche(Rechteck(x: 268, y: 303, breite: 134, hoehe: 9), radius: 2, farbe: "#070708"),
                .flaeche(Rechteck(x: 49, y: 320, breite: 34, hoehe: 9), radius: 2, farbe: "#0E0E0F"),
                .flaeche(Rechteck(x: 590, y: 320, breite: 34, hoehe: 9), radius: 2, farbe: "#0E0E0F"),
                // Gehaeuse: aussen hell, darunter zwei dunklere Lagen
                .flaeche(Rechteck(x: 34, y: 79, breite: 612, hoehe: 214), radius: 12, farbe: "#8B8B8F"),
                .flaeche(Rechteck(x: 35.5, y: 80.5, breite: 609, hoehe: 211), radius: 11, farbe: "#4A4A4D"),
                .flaeche(gehaeuse, radius: 10, farbe: "#333336"),
                .flaeche(Rechteck(x: 38, y: 83, breite: 604, hoehe: 3), radius: 1.5, farbe: "#5C5C60"),
                // Das Display selbst, mit Glanzkante oben und Schatten unten
                .flaeche(feld, radius: 3, farbe: "#0A0A0B"),
                .flaeche(Rechteck(x: 48, y: 93, breite: 584, hoehe: 4), radius: 2, farbe: "#121214"),
                .flaeche(Rechteck(x: 48, y: 266, breite: 584, hoehe: 4), radius: 2, farbe: "#070708"),
                // Aufdruck auf der Blende unter dem Display
                .schrift("U-Clock TC002", x: 52, grundlinie: 285, groesse: 12,
                         farbe: "#77777B", rechtsbuendig: false),
                .schrift("Pixbar", x: 628, grundlinie: 285, groesse: 12,
                         farbe: "#77777B", rechtsbuendig: true),
            ],
            // Die 52×16 der Werksfirmware auf einem kleinen Feld: viele kleine
            // Punkte. Ein Achtel Luecke ergibt bei Kante 8 genau den einen
            // Punkt Abstand, den beide Vorschauen bisher gezeichnet haben.
            pixelstil: Pixelstil(lueckeAnteil: 0.125, eckenAnteil: 0.25))
    }()

    // MARK: - Die Ulanzi TC001 mit AWTRIX NG

    /// Die Front der TC001 unter AWTRIX NG: gerade Ansicht, heller Koerper,
    /// runde Ecken, **keine Tasten oben**.
    ///
    /// Das Geraet ist im Wesentlichen ein schmaler weisser Rand um ein
    /// schwarzes Feld — von vorn und ohne Knopf ist da wenig zu zeichnen.
    /// Damit man trotzdem erkennt, welches Geraet gemeint ist, steht unten
    /// links der Aufdruck; die Blende unter dem Display ist dafuer tiefer als
    /// der Rand ringsum (16 gegen 40). Das ist eine bewusste Freiheit
    /// gegenueber dem echten Geraet, keine Messung.
    ///
    /// Das Feld ist 4:1 — AWTRIX NG zeigt 32×8 (`docs/awtrix-ng-protokoll.md`,
    /// §1), nicht 52×16 wie die Werksfirmware. Auf derselben Flaeche sind das
    /// deutlich weniger und deshalb groessere Punkte; `pixelstil` traegt dem
    /// Rechnung.
    public static let awtrixNG: Geraetezeichnung = {
        let gehaeuse = Rechteck(x: 8, y: 8, breite: 616, hoehe: 202)
        let feld = Rechteck(x: 24, y: 24, breite: 584, hoehe: 146)
        return Geraetezeichnung(
            breite: 632, hoehe: 218,
            feld: feld,
            gehaeuse: gehaeuse, gehaeuseRadius: 28,
            teile: [
                // Aussenkante und Fusskante in **einem** Stueck: derselbe
                // Koerper, eine Spur groesser und nach unten versetzt. Ein
                // waagrechter Balken taete es nicht — seine Enden stuenden bei
                // einem Radius von 28 ueber die runden Ecken hinaus, und genau
                // das war im ersten Entwurf als heller Streifen unter dem
                // Geraet zu sehen.
                .flaeche(Rechteck(x: 6, y: 8, breite: 620, hoehe: 206), radius: 29, farbe: "#BFBFC9"),
                .flaeche(gehaeuse, radius: 28, farbe: "#F7F7F9"),
                // Dunkle Fuge zwischen Koerper und Scheibe
                .flaeche(Rechteck(x: 20, y: 20, breite: 592, hoehe: 154), radius: 12, farbe: "#1E1E24"),
                .flaeche(feld, radius: 9, farbe: "#0A0A0B"),
                .flaeche(Rechteck(x: 24, y: 24, breite: 584, hoehe: 4), radius: 2, farbe: "#131318"),
                .schrift("Ulanzi TC001", x: 28, grundlinie: 196, groesse: 14,
                         farbe: "#85858D", rechtsbuendig: false),
            ],
            // 32×8 auf derselben Scheibe: jede Zelle ist rund anderthalbmal so
            // gross wie bei der Werksfirmware. Kleinere Luecke und harte Ecken
            // — so sieht ein grobes Panel aus der Naehe aus.
            pixelstil: Pixelstil(lueckeAnteil: 0.05, eckenAnteil: 0))
    }()
}
