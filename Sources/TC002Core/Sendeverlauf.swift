import Foundation

/// Was von hier aus geschickt wurde — mit allem, was dazugehoerte.
///
/// Nicht zu verwechseln mit zwei Nachbarn:
///
/// - Das Protokoll (`AppZustand.protokoll`) ist die technische Ebene:
///   fluechtig, ab Werk aus, fuer den Fall, dass etwas nicht klappt.
/// - Das Slotgedaechtnis merkt sich einen Stand je Platz, damit ein
///   Block seine Regler wiederherstellen kann. Es weiss nichts von gestern.
///
/// Der Verlauf ist das Dritte: eine Liste der Sendungen, aelteste zuletzt, mit
/// allen Reglern — damit ein Druck darauf genau dieselbe Meldung wieder
/// herstellt, nicht nur ihren Text.
public struct Verlaufseintrag: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let zeit: Date
    /// Der Platz, auf den gesendet wurde — `nil`, wo es keinen gab (das
    /// Kommandozeilenwerkzeug ohne `--name`).
    public let platz: Int?
    /// Name der Uhr zum Zeitpunkt der Sendung, nicht ihre Kennung: Eine
    /// geloeschte Uhr soll den Eintrag nicht unlesbar machen.
    public let uhr: String
    public let optionen: Meldungsoptionen
    public let iconNummer: String?
    public let iconKante: Int

    public init(id: UUID = UUID(), zeit: Date = Date(), platz: Int?, uhr: String,
                optionen: Meldungsoptionen, iconNummer: String?, iconKante: Int) {
        self.id = id
        self.zeit = zeit
        self.platz = platz
        self.uhr = uhr
        self.optionen = optionen
        self.iconNummer = iconNummer
        self.iconKante = iconKante
    }

    /// Ob zwei Sendungen dasselbe sagen — ohne Zeit und Kennung. Zwei gleiche
    /// hintereinander stehen nur einmal da: Wer dreimal „Kaffee" schickt, will
    /// keine drei Zeilen lesen.
    public func gleichtInhaltlich(_ andere: Verlaufseintrag) -> Bool {
        platz == andere.platz && uhr == andere.uhr && optionen == andere.optionen
            && iconNummer == andere.iconNummer && iconKante == andere.iconKante
    }
}

/// Die Ablage des Verlaufs: eine Datei je Installation, beim Lesen
/// zusammengefuehrt.
///
/// Warum nicht eine gemeinsame Datei: Sie liegt im iCloud-Behaelter, und
/// Mac und Telefon schreiben unabhaengig voneinander. Zwei Schreiber auf einer
/// Datei heisst: Wer zuletzt schreibt, hat die Eintraege des anderen
/// weggeworfen. Je Installation eine Datei ist dieselbe Ueberlegung wie „je Uhr
/// eine eigene MQTT-Client-Kennung" — getrennte Schreiber, getrennte Ablagen.
///
/// Gelesen wird alles, was im Ordner liegt, und nach Zeit sortiert. Damit
/// erscheint auf dem Telefon auch, was am Schreibtisch geschickt wurde, sobald
/// iCloud die Datei gebracht hat.
public final class Sendeverlauf: @unchecked Sendable {
    /// Mehr als das steht nicht an: Der Verlauf ist eine Erinnerungsstuetze,
    /// kein Archiv. Die Zahl gilt je Installation, nicht zusammengefuehrt.
    public static let obergrenze = 200

    private let ordner: URL
    private let eigeneDatei: URL

    public static var eigenerOrdner: URL { Ablageort.gemeinsam.ordner(.verlauf) }

    /// Die Kennung dieser Installation. Einmal gewuerfelt und in den
    /// Einstellungen behalten — sie benennt nur die Datei und sagt nichts ueber
    /// den Rechner.
    public static func eigeneKennung(_ ablage: UserDefaults = .standard) -> String {
        if let da = ablage.string(forKey: "verlauf.kennung") { return da }
        let neu = UUID().uuidString
        ablage.set(neu, forKey: "verlauf.kennung")
        return neu
    }

    public init(ordner: URL = Sendeverlauf.eigenerOrdner,
                kennung: String = Sendeverlauf.eigeneKennung()) {
        self.ordner = ordner
        self.eigeneDatei = ordner.appendingPathComponent("\(kennung).json")
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
    }

    private static let kodierer: JSONEncoder = {
        let k = JSONEncoder()
        k.dateEncodingStrategy = .iso8601
        return k
    }()
    private static let leser: JSONDecoder = {
        let l = JSONDecoder()
        l.dateDecodingStrategy = .iso8601
        return l
    }()

    /// Alle Eintraege aller Installationen, das Juengste zuerst.
    public func alle() -> [Verlaufseintrag] {
        let dateien = (try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: nil)) ?? []
        let eintraege = dateien.filter { $0.pathExtension == "json" }.flatMap { datei -> [Verlaufseintrag] in
            guard let daten = try? Data(contentsOf: datei),
                  let liste = try? Self.leser.decode([Verlaufseintrag].self, from: daten) else { return [] }
            return liste
        }
        return eintraege.sorted { $0.zeit > $1.zeit }
    }

    /// Nur die eigene Datei — die einzige, die diese Installation fortschreibt.
    private func eigene() -> [Verlaufseintrag] {
        guard let daten = try? Data(contentsOf: eigeneDatei),
              let liste = try? Self.leser.decode([Verlaufseintrag].self, from: daten) else { return [] }
        return liste
    }

    /// Haengt eine Sendung an. Gleicht sie inhaltlich der juengsten, wird nur
    /// deren Zeit erneuert — sonst stuenden drei „Kaffee" untereinander.
    @discardableResult
    public func merken(_ eintrag: Verlaufseintrag) -> Bool {
        var liste = eigene().sorted { $0.zeit > $1.zeit }
        if let erste = liste.first, erste.gleichtInhaltlich(eintrag) {
            liste.removeFirst()
        }
        liste.insert(eintrag, at: 0)
        if liste.count > Self.obergrenze { liste.removeLast(liste.count - Self.obergrenze) }
        return schreiben(liste)
    }

    /// Einen einzelnen Eintrag wegnehmen — geht nur bei eigenen: Die Datei
    /// eines anderen Geraets gehoert ihm.
    @discardableResult
    public func vergessen(_ id: UUID) -> Bool {
        var liste = eigene()
        guard liste.contains(where: { $0.id == id }) else { return false }
        liste.removeAll { $0.id == id }
        return schreiben(liste)
    }

    /// Alles wegwerfen, auch das der anderen Geraete: Wer den Verlauf
    /// loescht, meint ihn ganz — und die fremden Dateien kaemen beim naechsten
    /// Abgleich ohnehin zurueck, wenn dort noch etwas steht.
    @discardableResult
    public func leeren() -> Bool {
        let dateien = (try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: nil)) ?? []
        var alles = true
        for datei in dateien where datei.pathExtension == "json" {
            if (try? FileManager.default.removeItem(at: datei)) == nil { alles = false }
        }
        return alles
    }

    private func schreiben(_ liste: [Verlaufseintrag]) -> Bool {
        guard let daten = try? Self.kodierer.encode(liste) else { return false }
        return (try? daten.write(to: eigeneDatei, options: .atomic)) != nil
    }
}
