import Foundation

/// Rueckgaengig und Wiederherstellen fuer den Editor — und der Stand, der im
/// Bestand liegt.
///
/// Beides gehoert zusammen und nicht nebeneinander. Die Frage „weicht die
/// Leinwand vom Bestand ab?" stellt sich an denselben Stellen, an denen dieser
/// Stapel geleert wird, und beide Antworten haengen am selben Stand. Ein
/// zweites Gedaechtnis daneben liefe frueher oder spaeter auseinander.
///
/// Ein Strich ist ein Schritt, nicht ein Pixel. Wer mit dem Finger ueber
/// zwanzig Kaestchen faehrt, hat einmal gemalt und will einmal zurueck. Je ein
/// Schritt sind ausserdem: „Alles loeschen", jede Bewegung des
/// Verschiebekreuzes, ein Einzelbild hinzufuegen, verdoppeln oder entfernen,
/// und ein Groessenwechsel, der die Leinwand verwirft. Kein Schritt sind
/// Farbwahl, Werkzeugwechsel, Bildwahl, Verzoegerung, Name und Nummer — sie
/// aendern nichts an der Zeichnung.
///
/// Ein Stapel von Momentaufnahmen, weil `Leinwand` den ganzen Zustand haelt:
/// Raster, Einzelbilder, das gewaehlte Bild und die Verzoegerung. Ein Schritt
/// zurueck stellt damit auch die Groesse wieder her — was ein Groessenwechsel
/// verworfen hat, kommt zurueck.
///
/// Was ein Schritt kostet. Swift-Arrays kopieren erst beim Schreiben: Eine
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
/// Der Stapel ueberlebt den Programmlauf nicht. Er ist nicht `Codable` und
/// gehoert nicht in den gesicherten Arbeitsstand: Ein Rueckgaengig, das ueber
/// einen Neustart hinweg gilt, muesste erklaeren, wohin es zurueckfuehrt.
public struct Leinwandverlauf: Sendable {
    /// Fuenfzig Schritte. Mehr braucht niemand, und mehr kostet nur Speicher.
    public static let grenze = 50

    private var rueckwaerts: [Leinwand] = []
    private var vorwaerts: [Leinwand] = []
    /// Der Stand, der im Bestand liegt — gesetzt beim Sichern und nach dem
    /// Oeffnen. `nil` heisst: Was auf der Leinwand steht, liegt nirgends.
    private var gesichert: Leinwand?

    public init() {}

    public var kannZurueck: Bool { !rueckwaerts.isEmpty }
    public var kannVor: Bool { !vorwaerts.isEmpty }
    /// Nur fuer Tests und zum Nachsehen.
    public var tiefe: Int { rueckwaerts.count }

    /// Was jetzt im Bestand liegt — `nil`, wenn es dort nichts gibt, dem die
    /// Leinwand entspraeche: nach „Neu", nach einem Groessenwechsel und
    /// solange ueberhaupt nicht gesichert wurde.
    ///
    /// Zu rufen ist es genau dort, wo die Leinwand und der Bestand zur Deckung
    /// kommen (Sichern, Oeffnen) oder auseinanderfallen (Neu, Groessenwechsel)
    /// — nicht bei jeder Aenderung.
    public mutating func gesichertMerken(_ stand: Leinwand?) {
        gesichert = stand
    }

    /// Ob die Leinwand vom Bestand abweicht — die eine Frage vor jedem
    /// Schritt, der Gemaltes verwirft: „Neu", ein Groessenwechsel, ein
    /// geoeffnetes Bild, ein geladenes Icon.
    ///
    /// Gefragt wird nicht, ob etwas geschehen ist, sondern ob es jetzt
    /// anders aussieht als das, was im Bestand liegt. Daraus folgt dreierlei
    /// von selbst: Eine geladene und unveraenderte Leinwand weicht nicht ab.
    /// Eine Aenderung, die wieder rueckgaengig gemacht wurde, zaehlt nicht —
    /// es ist wieder derselbe Stand. Und wo es keinen gesicherten Stand gibt,
    /// weicht alles ab, was nicht leer ist.
    ///
    /// Ein gezaehlter Stapel taete das nicht. `kannZurueck` sagt nur, dass
    /// jemand etwas getan hat; nach einem Neustart ist der Stapel leer, der
    /// wiederhergestellte Arbeitsstand aber immer noch ungesichert.
    public func weichtAb(_ jetzt: Leinwand) -> Bool {
        guard let gesichert else { return !jetzt.istLeer }
        return !jetzt.gleichesBild(wie: gesichert)
    }

    /// Vor jeder Aenderung zu rufen: Der Stand von jetzt kommt auf den
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
    ///
    /// Der gesicherte Stand faellt dabei mit weg — wer den Weg wegwirft, hat
    /// auch ein anderes Blatt vor sich. Wer danach eines oeffnet, sagt mit
    /// `gesichertMerken` gleich, welches es ist; wer es vergisst, bekommt eine
    /// Rueckfrage zuviel und nicht eine zuwenig.
    public mutating func leeren() {
        rueckwaerts.removeAll()
        vorwaerts.removeAll()
        gesichert = nil
    }
}
