import Foundation

/// Was auf einer Uhr liegt, soweit der Abgleich es braucht.
public struct Uhrenklaenge: Equatable, Sendable {
    /// Melodienname → RTTTL-Text, wie die Uhr ihn führt.
    public var melodien: [String: String]
    /// MP3-Name (ohne Endung) → Größe in Byte; `nil`, wenn die Uhr keine nennt.
    public var mp3: [String: Int?]
    public var belegteBytes: Int?
    public var gesamteBytes: Int?
    public var faehigkeiten: Geraetefaehigkeiten?

    public init(melodien: [String: String] = [:], mp3: [String: Int?] = [:], belegteBytes: Int? = nil,
                gesamteBytes: Int? = nil, faehigkeiten: Geraetefaehigkeiten? = nil) {
        self.melodien = melodien; self.mp3 = mp3
        self.belegteBytes = belegteBytes; self.gesamteBytes = gesamteBytes
        self.faehigkeiten = faehigkeiten
    }

    /// Freier Platz, soweit die Uhr ihn nennt. ❓ Ob `usedBytes` der Melodienliste
    /// und der MP3-Liste dieselbe Ablage meinen, ist nicht gemessen; der größere
    /// der beiden Werte ist die vorsichtige Annahme. Ein Fehlschlag beim Schreiben
    /// (`507`) fängt der Lauf trotzdem ab.
    var frei: Int? {
        guard let belegteBytes, let gesamteBytes else { return nil }
        return max(0, gesamteBytes - belegteBytes)
    }
}

public enum Abgleichgrund: Equatable, Sendable {
    case faehigkeitFehlt(String)
    case keinPlatz(noetig: Int, frei: Int)
    case nameAufUhrBelegt(Sammlungsart)
    case zuGross(Int)
    case abgewiesen(String)

    public var text: String {
        func menge(_ b: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file) }
        switch self {
        case .faehigkeitFehlt(let f): return lokf("Die Uhr kann das nicht (%@).", f)
        case .keinPlatz(let n, let f): return lokf("Kein Platz: nötig %@, frei %@.", menge(n), menge(f))
        case .nameAufUhrBelegt(let art):
            return art == .mp3 ? lok("Der Name ist auf der Uhr eine MP3.") : lok("Der Name ist auf der Uhr eine Melodie.")
        case .zuGross(let g): return lokf("Größer als %@.", menge(g))
        case .abgewiesen(let t): return t
        }
    }
}

public enum Abgleichschritt: Equatable, Sendable {
    case hinzufuegen(Sammlungsklang)
    case ersetzen(Sammlungsklang)

    public var klang: Sammlungsklang {
        switch self { case .hinzufuegen(let k), .ersetzen(let k): return k }
    }
}

public struct Abgleichplan: Equatable, Sendable {
    public var schritte: [Abgleichschritt] = []
    public var uebersprungen: [Uebersprungen] = []
    public var unveraendert: [String] = []

    public struct Uebersprungen: Equatable, Sendable {
        public var name: String
        public var art: Sammlungsart
        public var grund: Abgleichgrund

        public init(name: String, art: Sammlungsart, grund: Abgleichgrund) {
            self.name = name; self.art = art; self.grund = grund
        }
    }
}

/// Das Ergebnis für eine Uhr.
public struct Uhrenabgleich: Equatable, Sendable {
    public var uhr: String
    public var hinzugefuegt: [String] = []
    public var ersetzt: [String] = []
    public var uebersprungen: [Abgleichplan.Uebersprungen] = []
    public var unveraendert: [String] = []
    /// Die Uhr war nicht zu lesen; dann ist nichts geschehen.
    public var fehler: String?
    /// Nur geplant, nichts gesendet.
    public var trocken = false

    public init(uhr: String) { self.uhr = uhr }
}

/// Gleicht eine Uhr an die Klangsammlung an: Fehlendes kommt hinzu, Abweichendes
/// wird ersetzt, **Überzähliges bleibt auf der Uhr**. Gelöscht wird dort nur
/// einzeln, nicht beim Abgleich.
///
/// Verglichen wird eine Melodie über den RTTTL-Text mit dem Melodienamen als
/// Namensteil (die Uhr schreibt ihn so um), eine MP3 über die Größe. ❓ Einen
/// Prüfwert für gespeicherte MP3-Dateien nennt die Uhr nicht (SHA-256 gibt es nur
/// für Skriptklänge), eine gleich große, aber andere Datei bleibt also unbemerkt.
/// Nennt die Uhr zu einer MP3 keine Größe, gilt sie als gleich.
public enum Klangabgleich {
    public static func planen(sammlung: [Sammlungsklang], uhr: Uhrenklaenge) -> Abgleichplan {
        var plan = Abgleichplan()
        var frei = uhr.frei
        let melodieOK = uhr.faehigkeiten?.kann(.melodie) ?? true
        let mp3OK = Klangeignung.mp3Hochladbar(uhr.faehigkeiten)

        func ueberspringen(_ k: Sammlungsklang, _ g: Abgleichgrund) {
            plan.uebersprungen.append(.init(name: k.name, art: k.art, grund: g))
        }
        func platzReicht(_ k: Sammlungsklang, ersetzt alt: Int) -> Bool {
            guard let f = frei else { return true }
            if k.groesse - alt > f {
                ueberspringen(k, .keinPlatz(noetig: k.groesse - alt, frei: f))
                return false
            }
            frei = f - (k.groesse - alt)
            return true
        }

        // Melodien zuerst: Sie sind klein und gehen vor den Dateien.
        for k in sammlung where k.art == .melodie {
            guard melodieOK else { ueberspringen(k, .faehigkeitFehlt("audio.rtttl")); continue }
            if uhr.mp3[k.name] != nil { ueberspringen(k, .nameAufUhrBelegt(.mp3)); continue }
            let soll = k.rtttl.map { Rtttl.mitName($0, name: k.name) }
            if let alt = uhr.melodien[k.name] {
                if Rtttl.mitName(alt, name: k.name) == soll { plan.unveraendert.append(k.name); continue }
                if platzReicht(k, ersetzt: alt.utf8.count) { plan.schritte.append(.ersetzen(k)) }
            } else if platzReicht(k, ersetzt: 0) {
                plan.schritte.append(.hinzufuegen(k))
            }
        }
        for k in sammlung where k.art == .mp3 {
            guard mp3OK else { ueberspringen(k, .faehigkeitFehlt("audio.mp3")); continue }
            if k.groesse > Geraet.mp3Hoechstgroesse { ueberspringen(k, .zuGross(Geraet.mp3Hoechstgroesse)); continue }
            if uhr.melodien[k.name] != nil { ueberspringen(k, .nameAufUhrBelegt(.melodie)); continue }
            if let eintrag = uhr.mp3[k.name] {
                guard let alt = eintrag, alt != k.groesse else { plan.unveraendert.append(k.name); continue }
                if platzReicht(k, ersetzt: alt) { plan.schritte.append(.ersetzen(k)) }
            } else if platzReicht(k, ersetzt: 0) {
                plan.schritte.append(.hinzufuegen(k))
            }
        }
        return plan
    }

    /// Liest die Uhr (nur HTTP, auf dem aufrufenden Thread — blockierend).
    public static func lesen(_ geraet: Geraet, faehigkeiten: Geraetefaehigkeiten? = nil) throws -> Uhrenklaenge {
        let melodien = try geraet.melodien()
        let mp3 = try? geraet.mp3Dateien()
        var m: [String: String] = [:]
        for n in melodien.namen { m[n] = melodien.texte[n] ?? "" }
        var d: [String: Int?] = [:]
        for n in mp3?.namen ?? [] { d[n] = .some(mp3?.groessen[n]) }
        let belegt = [melodien.belegteBytes, mp3?.belegteBytes].compactMap { $0 }.max()
        let caps = faehigkeiten ?? (try? geraet.faehigkeiten()) ?? nil
        return Uhrenklaenge(melodien: m, mp3: d, belegteBytes: belegt,
                            gesamteBytes: melodien.gesamteBytes ?? mp3?.gesamteBytes, faehigkeiten: caps)
    }

    /// Plant und führt aus (blockierend; in der App im Hintergrund). `trocken`
    /// sendet nichts.
    public static func abgleichen(sammlung: [Sammlungsklang], geraet: Geraet, uhrname: String,
                                  faehigkeiten: Geraetefaehigkeiten? = nil,
                                  trocken: Bool = false) -> Uhrenabgleich {
        var ergebnis = Uhrenabgleich(uhr: uhrname)
        ergebnis.trocken = trocken
        let stand: Uhrenklaenge
        do { stand = try lesen(geraet, faehigkeiten: faehigkeiten) } catch {
            ergebnis.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return ergebnis
        }
        let plan = planen(sammlung: sammlung, uhr: stand)
        ergebnis.uebersprungen = plan.uebersprungen
        ergebnis.unveraendert = plan.unveraendert
        for schritt in plan.schritte {
            let k = schritt.klang
            if !trocken {
                do {
                    switch k.art {
                    case .melodie:
                        let json = try Klangbau.melodie(name: k.name, rtttl: k.rtttl ?? "")
                        try geraet.melodieSetzen(name: k.name, json: json)
                    case .mp3:
                        guard let daten = try? Data(contentsOf: k.datei) else {
                            throw SammlungFehler.nichtLesbar(k.name)
                        }
                        try geraet.mp3Hochladen(name: k.name, daten: daten, faehigkeiten: stand.faehigkeiten)
                    }
                } catch {
                    let text: Abgleichgrund
                    if case KlangFehler.mp3KeinPlatz = error {
                        text = .keinPlatz(noetig: k.groesse, frei: stand.frei ?? 0)
                    } else {
                        text = .abgewiesen((error as? LocalizedError)?.errorDescription ?? "\(error)")
                    }
                    ergebnis.uebersprungen.append(.init(name: k.name, art: k.art, grund: text))
                    continue
                }
            }
            if case .hinzufuegen = schritt { ergebnis.hinzugefuegt.append(k.name) } else { ergebnis.ersetzt.append(k.name) }
        }
        return ergebnis
    }
}
