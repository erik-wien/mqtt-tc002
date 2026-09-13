import Foundation

/// Rueckgaengig und Wiederherstellen fuer den Editor.
///
/// **Ein Strich ist ein Schritt, nicht ein Pixel.** Wer mit dem Finger ueber
/// zwanzig Kaestchen faehrt, hat einmal gemalt und will einmal zurueck. Je ein
/// Schritt sind ausserdem: „Alles loeschen", jede Bewegung des
/// Verschiebekreuzes, ein Einzelbild hinzufuegen, verdoppeln oder entfernen,
/// und ein Groessenwechsel, der die Leinwand verwirft. **Kein Schritt** sind
/// Farbwahl, Werkzeugwechsel, Bildwahl, Verzoegerung, Name und Nummer — sie
/// aendern nichts an der Zeichnung.
///
/// Ein Stapel von Momentaufnahmen, weil `Leinwand` den ganzen Zustand haelt:
/// Raster, Einzelbilder, das gewaehlte Bild und die Verzoegerung. Ein Schritt
/// zurueck stellt damit auch die Groesse wieder her — was ein Groessenwechsel
/// verworfen hat, kommt zurueck.
///
/// **Was ein Schritt kostet.** Swift-Arrays kopieren erst beim Schreiben: Eine
/// Momentaufnahme kostet zunaechst nichts, und erst die naechste Aenderung
/// legt das *veraenderte* Einzelbild neu an. Ein 52×16 hat 832 Felder zu je
/// 16 Byte (ein `String?` mit „#RRGGBB" passt in die kurze Form), also rund
/// 13 KB je Einzelbild. Ein Strich beruehrt ein Einzelbild — 13 KB. Das
/// Verschiebekreuz schreibt alle, bei einer Animation aus zehn Bildern also
/// 130 KB. Bei fuenfzig Schritten und einem ebenso tiefen Stapel fuer
/// Wiederherstellen liegt die Obergrenze damit bei rund 1,3 MB fuer Striche
/// und rund 13 MB fuer den ungemuetlichsten denkbaren Fall (fuenfzigmal das
/// Kreuz auf einer zehnbildrigen Anzeige). Deshalb die Grenze.
///
/// **Der Stapel ueberlebt den Programmlauf nicht.** Er ist nicht `Codable` und
/// gehoert nicht in den gesicherten Arbeitsstand: Ein Rueckgaengig, das ueber
/// einen Neustart hinweg gilt, muesste erklaeren, wohin es zurueckfuehrt.
public struct Leinwandverlauf: Sendable {
    /// Fuenfzig Schritte. Mehr braucht niemand, und mehr kostet nur Speicher.
    public static let grenze = 50

    private var rueckwaerts: [Leinwand] = []
    private var vorwaerts: [Leinwand] = []

    public init() {}

    public var kannZurueck: Bool { !rueckwaerts.isEmpty }
    public var kannVor: Bool { !vorwaerts.isEmpty }
    /// Nur fuer Tests und zum Nachsehen.
    public var tiefe: Int { rueckwaerts.count }

    /// **Vor** jeder Aenderung zu rufen: Der Stand von jetzt kommt auf den
    /// Stapel. Ein neuer Schritt macht jedes Wiederherstellen hinfaellig —
    /// von hier aus fuehrt der alte Weg nach vorn nicht mehr weiter.
    public mutating func merken(_ stand: Leinwand) {
        rueckwaerts.append(stand)
        if rueckwaerts.count > Self.grenze { rueckwaerts.removeFirst() }
        vorwaerts.removeAll()
    }

    /// Einen Schritt zurueck. `jetzt` ist der aktuelle Stand, der dabei auf den
    /// Vorwaertsstapel wandert; zurueck kommt der vorige. `nil` heisst: nichts
    /// mehr da.
    public mutating func zurueck(von jetzt: Leinwand) -> Leinwand? {
        guard let vorheriger = rueckwaerts.popLast() else { return nil }
        vorwaerts.append(jetzt)
        if vorwaerts.count > Self.grenze { vorwaerts.removeFirst() }
        return vorheriger
    }

    /// Und einen wieder nach vorn.
    public mutating func vor(von jetzt: Leinwand) -> Leinwand? {
        guard let naechster = vorwaerts.popLast() else { return nil }
        rueckwaerts.append(jetzt)
        if rueckwaerts.count > Self.grenze { rueckwaerts.removeFirst() }
        return naechster
    }

    /// Nach „Neu" und nach dem Oeffnen eines vorhandenen Bildes: Der bisherige
    /// Weg fuehrt nicht mehr zu dem, was auf dem Tisch liegt.
    public mutating func leeren() {
        rueckwaerts.removeAll()
        vorwaerts.removeAll()
    }
}
