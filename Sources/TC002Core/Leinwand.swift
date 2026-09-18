import Foundation

/// Der Stand eines Editors: ein oder mehrere gleich grosse Farbraster und die
/// Standzeit, die zwischen ihnen gilt. Mehrere ergeben beim Sichern ein
/// animiertes GIF.
///
/// Das ist die ganze Rechnung hinter dem Editor — Malen, Radieren, die
/// Bildleiste und das Pfeilkreuz. Die Ansicht (`PixelEditor`) zeichnet nur,
/// was hier steht; damit laesst sich jede dieser Handlungen pruefen, ohne eine
/// Oberflaeche zu bauen.
///
/// Ein Raster ist zeilenweise von oben links abgelegt, `nil` heisst aus — die
/// Form, in der `Bildraster` liest und schreibt. Kein zweites Format daneben.
///
/// `Codable` ist hier ein Dateiformat. Der Bereich „Bilder" sichert seinen
/// Arbeitsstand damit in die App-Einstellungen; wer Feldnamen aendert, macht
/// den gemerkten Stand jeder laufenden Installation unlesbar.
public struct Leinwand: Equatable, Sendable, Codable {
    public let breite: Int
    public let hoehe: Int
    /// Mindestens ein Bild, alle mit `breite * hoehe` Eintraegen.
    public private(set) var bilder: [[String?]]
    /// Welches davon gerade bearbeitet wird — immer ein gueltiger Index.
    public private(set) var aktuell: Int
    /// Standzeit je Einzelbild in Sekunden, gemeinsam fuer die ganze Animation.
    public var verzoegerung: Double

    public init(breite: Int, hoehe: Int, verzoegerung: Double = 0.2) {
        self.breite = breite
        self.hoehe = hoehe
        self.bilder = [[String?](repeating: nil, count: breite * hoehe)]
        self.aktuell = 0
        self.verzoegerung = verzoegerung
    }

    /// Baut eine Leinwand aus fertigen Rastern. `nil`, wenn die Liste leer ist
    /// oder ein Raster nicht zur Groesse passt — lieber gar keine Leinwand als
    /// eine halbe.
    public init?(breite: Int, hoehe: Int, bilder: [[String?]], verzoegerung: Double = 0.2) {
        guard !bilder.isEmpty, bilder.allSatisfy({ $0.count == breite * hoehe }) else { return nil }
        self.breite = breite
        self.hoehe = hoehe
        self.bilder = bilder
        self.aktuell = 0
        self.verzoegerung = verzoegerung
    }

    /// Eine aus den Einstellungen gelesene Leinwand kann alles Moegliche
    /// enthalten — von Hand verbogen, aus einer aelteren Fassung, mit einer
    /// anderen Groesse gesichert. Statt abzustuerzen wird hier geradegezogen:
    /// unpassende Raster fliegen raus, bleibt nichts uebrig, beginnt die
    /// Leinwand leer.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let breite = try c.decode(Int.self, forKey: .breite)
        let hoehe = try c.decode(Int.self, forKey: .hoehe)
        guard breite > 0, hoehe > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .breite, in: c,
                                                   debugDescription: "Groesse muss positiv sein")
        }
        let gelesen = try c.decode([[String?]].self, forKey: .bilder)
            .filter { $0.count == breite * hoehe }
        self.breite = breite
        self.hoehe = hoehe
        self.bilder = gelesen.isEmpty ? [[String?](repeating: nil, count: breite * hoehe)] : gelesen
        self.verzoegerung = (try? c.decode(Double.self, forKey: .verzoegerung)) ?? 0.2
        let gewaehlt = (try? c.decode(Int.self, forKey: .aktuell)) ?? 0
        self.aktuell = self.bilder.indices.contains(gewaehlt) ? gewaehlt : 0
    }

    /// Das gerade bearbeitete Raster.
    public var bild: [String?] { bilder[aktuell] }

    /// Ob die ganze Leinwand unberuehrt ist: ein einziges, leeres Bild. Genau
    /// das entscheidet, ob „Neu" und „Laden" vorher nachfragen muessen.
    public var istLeer: Bool {
        bilder.count == 1 && bilder[0].allSatisfy { $0 == nil }
    }

    /// Ob hier dasselbe Bild steht wie in `andere`: dieselbe Groesse, dieselben
    /// Einzelbilder, dieselbe Standzeit — genau das, was beim Sichern in die
    /// Datei geht.
    ///
    /// Nicht dasselbe gewaehlte Einzelbild. Welches davon gerade bearbeitet
    /// wird, steht in keiner Datei, und ein Blick auf Bild drei aendert nichts
    /// daran, dass die Leinwand dem Bestand entspricht — `==` wuerde ihn als
    /// Abweichung zaehlen und eine Rueckfrage ausloesen, bei der nichts zu
    /// verlieren ist.
    public func gleichesBild(wie andere: Leinwand) -> Bool {
        breite == andere.breite && hoehe == andere.hoehe
            && verzoegerung == andere.verzoegerung && bilder == andere.bilder
    }

    public func farbe(x: Int, y: Int) -> String? {
        drin(x, y) ? bilder[aktuell][y * breite + x] : nil
    }

    private func drin(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < breite && y < hoehe
    }

    public mutating func setzen(x: Int, y: Int, farbe: String?) {
        guard drin(x, y) else { return }
        bilder[aktuell][y * breite + x] = farbe
    }

    public mutating func waehlen(_ index: Int) {
        guard bilder.indices.contains(index) else { return }
        aktuell = index
    }

    /// Leert das gerade bearbeitete Bild — die uebrigen bleiben stehen.
    public mutating func bildLeeren() {
        bilder[aktuell] = [String?](repeating: nil, count: breite * hoehe)
    }

    /// Zurueck auf den Anfang: ein einziges leeres Bild, Standzeit auf den
    /// Anfangswert.
    public mutating func zuruecksetzen() {
        bilder = [[String?](repeating: nil, count: breite * hoehe)]
        aktuell = 0
        verzoegerung = 0.2
    }

    /// Haengt ein leeres Bild an und schaltet darauf um.
    public mutating func anhaengen() {
        bilder.append([String?](repeating: nil, count: breite * hoehe))
        aktuell = bilder.count - 1
    }

    /// Legt eine Kopie des aktuellen Bildes dahinter und schaltet darauf um —
    /// beim Zeichnen einer Bewegung meist der schnellste Weg.
    public mutating func verdoppeln() {
        bilder.insert(bilder[aktuell], at: aktuell + 1)
        aktuell += 1
    }

    /// Nimmt das aktuelle Bild heraus. Das letzte bleibt stehen: eine Leinwand
    /// ohne Bild gibt es nicht.
    public mutating func entfernen() {
        guard bilder.count > 1 else { return }
        bilder.remove(at: aktuell)
        aktuell = min(aktuell, bilder.count - 1)
    }

    /// Tauscht das aktuelle Bild mit seinem Nachbarn und folgt ihm.
    public mutating func tauschen(um richtung: Int) {
        let ziel = aktuell + richtung
        guard bilder.indices.contains(ziel) else { return }
        bilder.swapAt(aktuell, ziel)
        aktuell = ziel
    }

    /// „Icon einfuegen": setzt ein fertiges Icon in diese Leinwand.
    ///
    /// Umrechnen ist ein Befehl, den man aufruft, kein stiller
    /// Nebeneffekt eines Imports (C2). Wohin und
    /// mit welchem Faktor, rechnet `Leinwandgroesse.einsatz(in:)`: 8×8 in ein
    /// 16×16 verdoppelt, 8×8 und 16×16 in die Anzeige in ihrer Groesse. Der
    /// umgekehrte Weg ist nicht vorgesehen und liefert `false`.
    ///
    /// Durchsichtige Quellpixel lassen die Flaeche unberuehrt, statt ein
    /// schwarzes Rechteck hineinzuradieren. Betroffen ist nur das gerade
    /// bearbeitete Einzelbild — eingesetzt wird ein Ausgangspunkt, nicht eine
    /// Animation.
    ///
    /// `false` heisst: Es ist nichts geschehen. Die Ansicht merkt sich
    /// dann auch keinen Schritt fuer „Rueckgaengig".
    @discardableResult
    public mutating func iconEinsetzen(_ pixel: [String?], groesse quelle: Leinwandgroesse) -> Bool {
        guard let ziel = Leinwandgroesse.fuer(breite: breite, hoehe: hoehe),
              let einsatz = quelle.einsatz(in: ziel),
              pixel.count == quelle.breite * quelle.hoehe else { return false }
        for qy in 0..<quelle.hoehe {
            for qx in 0..<quelle.breite {
                guard let farbe = pixel[qy * quelle.breite + qx] else { continue }
                for dy in 0..<einsatz.faktor {
                    for dx in 0..<einsatz.faktor {
                        setzen(x: einsatz.x + qx * einsatz.faktor + dx,
                               y: einsatz.y + qy * einsatz.faktor + dy, farbe: farbe)
                    }
                }
            }
        }
        return true
    }

    /// Schiebt die Grafik um `dx`/`dy` Pixel — das Pfeilkreuz.
    ///
    /// Was am Rand hinausgeschoben wird, kommt auf der anderen Seite wieder
    /// herein. Umlaufend, nicht abschneidend: Dieser Editor kennt kein
    /// Rueckgaengig. Umlaufend ist
    /// jeder Schritt durch den Gegenpfeil genau umkehrbar — viermal nach
    /// rechts und viermal nach links ergeben wieder das Ausgangsbild.
    /// Abschneidend waere jeder Schritt ein Verlust, den nichts zurueckholt,
    /// und ein Vertippen auf einem 8×8 kostete ein Achtel der Zeichnung. Wer
    /// das Hereingelaufene nicht will, radiert es weg; wer Abgeschnittenes
    /// zurueckwill, muesste es neu malen.
    ///
    /// Alle Einzelbilder zusammen, nicht nur das sichtbare: Eine
    /// Animation, deren Bilder gegeneinander verrutschen, waere kaputt, und
    /// die Bildleiste zeigt zu klein, dass es passiert ist.
    public mutating func verschieben(dx: Int, dy: Int) {
        guard breite > 0, hoehe > 0 else { return }
        // Der Rest-Operator von Swift kann negativ werden, ein Index nicht —
        // deshalb einmal die Kante dazu, bevor gerechnet wird.
        let vx = ((dx % breite) + breite) % breite
        let vy = ((dy % hoehe) + hoehe) % hoehe
        guard vx != 0 || vy != 0 else { return }
        for i in bilder.indices {
            var neu = [String?](repeating: nil, count: breite * hoehe)
            for y in 0..<hoehe {
                let zy = (y + vy) % hoehe
                for x in 0..<breite {
                    let zx = (x + vx) % breite
                    neu[zy * breite + zx] = bilder[i][y * breite + x]
                }
            }
            bilder[i] = neu
        }
    }
}
