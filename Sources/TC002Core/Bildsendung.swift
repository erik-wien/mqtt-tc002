import Foundation

/// Ein fertiges Bild aus dem Bestand als Sendung — der Weg von einer Datei
/// zu dem, was über den Draht geht.
///
/// Am Schreibtisch entsteht dieser Rahmen aus der Leinwand, also aus Bildern,
/// die schon im Speicher liegen (`EditorBereichView.senden`). Wer ein Bild
/// dagegen aus dem Bestand schickt — am Telefon der einzige Weg —, hat nur die
/// Datei. Die Entscheidung dahinter ist in beiden Fällen dieselbe und steht
/// deshalb hier, einmal: Eine Anzeige geht als Pixelbild hinaus
/// (`Pixelweg`, ein Einzelbild als Standbild, mehrere als animiertes GIF), ein
/// Icon als Icon neben leerem Text.
public enum Bildsendung {
    /// Baut den Rahmen zu einer Bilddatei. `dauer` ist die eigene Standzeit
    /// dieser Anzeige in Sekunden; `nil` heißt: keine eigene Angabe.
    ///
    /// Die Datei wird gelesen, nicht geraten — auch die Zeiten zwischen
    /// den Einzelbildern stehen darin, und ein GIF, das mit anderen
    /// Standzeiten neu geschrieben wird, läuft anders als es aussah.
    public static func rahmen(aus datei: URL, breite: Int = Pixelfeld.breiteStandard,
                              hoehe: Int = Pixelfeld.hoeheStandard,
                              dauer: Int? = nil) throws -> Frame {
        let gelesen = try Bildraster.lesenMitZeiten(datei, breite: breite, hoehe: hoehe)
        return try rahmen(einzelbilder: gelesen, breite: breite, hoehe: hoehe, dauer: dauer)
    }

    /// Dasselbe aus Einzelbildern, die schon im Speicher liegen — der Weg des
    /// Editors, dessen Leinwand nicht aus einer Datei kommt.
    ///
    /// Eine Stelle für beide Wege, statt die Entscheidung ein zweites Mal in
    /// `EditorBereichView.senden` zu treffen: Zwei Abschriften derselben Regel
    /// liefen beim nächsten Griff sonst auseinander.
    public static func rahmen(aus bilder: [[String?]], breite: Int = Pixelfeld.breiteStandard,
                              hoehe: Int = Pixelfeld.hoeheStandard,
                              verzoegerung: Double, dauer: Int? = nil) throws -> Frame {
        try rahmen(einzelbilder: bilder.map { Bildraster.Einzelbild(pixel: $0, dauer: verzoegerung) },
                   breite: breite, hoehe: hoehe, dauer: dauer)
    }

    private static func rahmen(einzelbilder: [Bildraster.Einzelbild], breite: Int, hoehe: Int,
                               dauer: Int?) throws -> Frame {
        guard !einzelbilder.isEmpty else { throw BildrasterFehler.nichtLesbar }
        // Ein quadratisches Stueck ist ein Icon, und ein Icon nimmt AWTRIX NG
        // als GIF im Feld `icon` einer Anzeige (`NGNutzlast.icon`), nicht als
        // Pixelfeld ueber das ganze Display.
        //
        // Nur die Kante entscheidet, nicht der Bereich, aus dem es kommt: Was
        // 8 x 8 oder 16 x 16 ist, ist ein Icon, alles andere eine Anzeige.
        if breite == hoehe, breite == 8 || breite == 16 {
            let uri = try Pixelweg.gifDatenURI(Pixelinhalt(breite: breite, hoehe: hoehe,
                                                           bilder: einzelbilder))
            return Frame(dauer: dauer, herkunft: Meldungsherkunft(
                optionen: Meldungsoptionen(text: "", weg: .text), iconDatenURI: uri))
        }
        let inhalt = Pixelinhalt(breite: breite, hoehe: hoehe, bilder: einzelbilder)
        // Mass und Bildzahl jetzt, damit der Fehler beim Bauen kommt und nicht
        // erst beim Senden.
        try Pixelweg.pruefen(inhalt)
        return Frame(pixel: inhalt, dauer: dauer)
    }
}
