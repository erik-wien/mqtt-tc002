import Foundation

/// **Ein fertiges Bild aus dem Bestand als Sendung** — der Weg von einer Datei
/// zu dem, was über den Draht geht.
///
/// Am Schreibtisch entsteht dieser Rahmen aus der Leinwand, also aus Bildern,
/// die schon im Speicher liegen (`EditorBereichView.senden`). Wer ein Bild
/// dagegen aus dem Bestand schickt — am Telefon der einzige Weg —, hat nur die
/// Datei. Die Entscheidung dahinter ist in beiden Fällen dieselbe und steht
/// deshalb hier, einmal:
///
/// - **Ein** Einzelbild geht als `draw` hinaus: Rechtecke, klein und exakt.
/// - **Mehrere** gehen als animiertes GIF — Rechtecke kennen keine Zeit.
public enum Bildsendung {
    /// Baut den Rahmen zu einer Bilddatei. `dauer` ist die eigene Standzeit
    /// dieser Anzeige in Sekunden; `nil` heißt: keine eigene Angabe.
    ///
    /// **Die Datei wird gelesen, nicht geraten** — auch die Zeiten zwischen
    /// den Einzelbildern stehen darin, und ein GIF, das mit anderen
    /// Standzeiten neu geschrieben wird, läuft anders als es aussah.
    public static func rahmen(aus datei: URL, breite: Int = Pixelfeld.breiteStandard,
                              hoehe: Int = Pixelfeld.hoeheStandard,
                              dauer: Int? = nil) throws -> Frame {
        let gelesen = try Bildraster.lesenMitZeiten(datei, breite: breite, hoehe: hoehe)
        guard let erstes = gelesen.first else { throw BildrasterFehler.nichtLesbar }
        // Die Standzeit des ersten Bildes gilt für alle — mehr gibt der
        // Rahmenbau nicht her, und die Dateien dieses Bestands entstehen im
        // Editor mit einer einzigen Verzögerung.
        return try rahmen(aus: gelesen.map(\.pixel), breite: breite, hoehe: hoehe,
                          verzoegerung: erstes.dauer, dauer: dauer)
    }

    /// Dasselbe aus Einzelbildern, die schon im Speicher liegen — der Weg des
    /// Editors, dessen Leinwand nicht aus einer Datei kommt.
    ///
    /// **Eine Stelle für beide Wege.** Bis zum 14.09.2026 stand die
    /// Entscheidung „eines als `draw`, mehrere als GIF" auch in
    /// `EditorBereichView.senden` — dieselbe Regel an zwei Stellen, und die
    /// zweite hätte beim nächsten Griff an den Rahmenbau still etwas anderes
    /// getan.
    public static func rahmen(aus bilder: [[String?]], breite: Int = Pixelfeld.breiteStandard,
                              hoehe: Int = Pixelfeld.hoeheStandard,
                              verzoegerung: Double, dauer: Int? = nil) throws -> Frame {
        guard let erstes = bilder.first else { throw BildrasterFehler.nichtLesbar }
        guard bilder.count > 1 else {
            guard let feld = Pixelfeld(breite: breite, hoehe: hoehe, punkte: erstes) else {
                throw BildrasterFehler.nichtLesbar
            }
            return Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
        }
        let uri = try Bildraster.alsDatenURI(bilder, breite: breite, hoehe: hoehe,
                                             verzoegerung: verzoegerung)
        return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: dauer)
    }
}
