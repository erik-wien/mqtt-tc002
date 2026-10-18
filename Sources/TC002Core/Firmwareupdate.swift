import Foundation

/// Eine Firmware-Fassung mit Vorabkennung: `1.3.0-beta.2` liegt vor `1.3.0`.
/// Ein führendes `v` und `+Bauangabe` bleiben unbeachtet, fehlende Zahlen gelten
/// als 0 (`1.2` = `1.2.0`). Die Vorabkennung wird wie bei SemVer geordnet: Zahlen
/// vor Wörtern, Zahlen nach ihrem Wert, kürzere Folge vor längerer.
public struct Firmwareversion: Comparable, Sendable {
    public let zahlen: [Int]
    public let vorab: [String]

    /// `nil`, wenn keine Zahl am Anfang steht, eine Gruppe leer oder keine Ziffernfolge
    /// ist oder die Vorabkennung eine leere Gruppe hat.
    public init?(_ text: String) {
        var rest = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if rest.first == "v" || rest.first == "V" { rest = rest.dropFirst() }
        if let plus = rest.firstIndex(of: "+") { rest = rest[..<plus] }
        var kopf = rest, kennung: Substring?
        if let strich = rest.firstIndex(of: "-") {
            kopf = rest[..<strich]
            kennung = rest[rest.index(after: strich)...]
        }
        guard !kopf.isEmpty else { return nil }
        var zahlen: [Int] = []
        for gruppe in kopf.split(separator: ".", omittingEmptySubsequences: false) {
            guard !gruppe.isEmpty, gruppe.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(gruppe) else { return nil }
            zahlen.append(n)
        }
        var vorab: [String] = []
        if let kennung {
            for gruppe in kennung.split(separator: ".", omittingEmptySubsequences: false) {
                guard !gruppe.isEmpty else { return nil }
                vorab.append(String(gruppe))
            }
        }
        self.zahlen = zahlen
        self.vorab = vorab
    }

    private static func ordnen(_ a: Firmwareversion, _ b: Firmwareversion) -> ComparisonResult {
        for i in 0..<max(a.zahlen.count, b.zahlen.count) {
            let x = i < a.zahlen.count ? a.zahlen[i] : 0, y = i < b.zahlen.count ? b.zahlen[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        switch (a.vorab.isEmpty, b.vorab.isEmpty) {
        case (true, true): return .orderedSame
        case (true, false): return .orderedDescending
        case (false, true): return .orderedAscending
        case (false, false): break
        }
        for (x, y) in zip(a.vorab, b.vorab) where x != y {
            switch (Int(x), Int(y)) {
            case (let m?, let n?): return m < n ? .orderedAscending : .orderedDescending
            case (_?, nil): return .orderedAscending
            case (nil, _?): return .orderedDescending
            case (nil, nil): return x < y ? .orderedAscending : .orderedDescending
            }
        }
        if a.vorab.count == b.vorab.count { return .orderedSame }
        return a.vorab.count < b.vorab.count ? .orderedAscending : .orderedDescending
    }

    public static func < (a: Firmwareversion, b: Firmwareversion) -> Bool { ordnen(a, b) == .orderedAscending }
    public static func == (a: Firmwareversion, b: Firmwareversion) -> Bool { ordnen(a, b) == .orderedSame }
}

/// Ein Paket aus einem Release von `Blueforcer/awtrix-ng`, das diese Uhr annimmt:
/// nach Name, Größe, Adresse und Prüfsumme aus den Angaben von GitHub gelesen und
/// geprüft (`Firmwarequelle`).
public struct Firmwarepaket: Equatable, Sendable {
    /// Die Fassung ohne `v`.
    public let fassung: String
    public let tag: String
    /// Genau der Name, den die Uhr als `updateImage` nennt.
    public let dateiname: String
    public let groesse: Int
    /// 64 Hexziffern klein.
    public let sha256: String
    public let adresse: URL
    /// Die Seite des Release auf GitHub.
    public let notizen: URL?

    public init(fassung: String, tag: String, dateiname: String, groesse: Int, sha256: String,
                adresse: URL, notizen: URL?) {
        self.fassung = fassung; self.tag = tag; self.dateiname = dateiname; self.groesse = groesse
        self.sha256 = sha256; self.adresse = adresse; self.notizen = notizen
    }
}

/// Das Ergebnis von „Nach Update suchen“.
public enum Firmwareangebot: Equatable, Sendable {
    /// Das neueste Release ist nicht neuer als die Uhr.
    case aktuell(installiert: String)
    case verfuegbar(Firmwarepaket)
    /// Das neueste Release ist neuer, hat aber keine Datei dieses Namens für diese Uhr.
    case keinPaket(fassung: String, dateiname: String)
}

/// Welche Pakete es gibt und was vor dem Hochladen an ihnen geprüft wird
/// (`docs/awtrix-ng-protokoll.md` §7.6).
public enum Firmwarepakete {
    /// Die Dateinamen, die eine Uhr als `updateImage` nennt. Was anders heißt,
    /// wird nicht angeboten, statt zu raten.
    public static let erlaubt = ["awtrix-ng-tc002.awup", "firmware-awtrix-ng.bin",
                                 "firmware-awtrix-ng-s3-octal.bin", "firmware-awtrix-ng-s3-quad.bin"]

    public static func istAwup(_ dateiname: String) -> Bool { dateiname.hasSuffix(".awup") }

    /// TC002: 8 MiB; ESP32: 1 769 472 Byte (`guides/updating`).
    public static func hoechstgroesse(_ dateiname: String) -> Int {
        istAwup(dateiname) ? 8 << 20 : 1_769_472
    }

    /// Erkennungsbytes am Anfang: `AWUPD003` bei `.awup`, `0xE9` bei den ESP32-Abbildern
    /// (Weboberfläche, `maintenance.js`).
    public static func kopfPasst(_ daten: Data, dateiname: String) -> Bool {
        if istAwup(dateiname) { return daten.starts(with: Data("AWUPD003".utf8)) }
        return daten.first == 0xE9
    }

    /// Groesse, Kopf und Prüfsumme eines geladenen Pakets.
    static func pruefen(_ daten: Data, gegen paket: Firmwarepaket) throws {
        guard daten.count == paket.groesse, kopfPasst(daten, dateiname: paket.dateiname),
              Fingerabdruck.sha256(daten) == paket.sha256 else { throw Firmwarefehler.pruefungFehlgeschlagen }
    }
}

/// Was die Oberfläche zum Firmware-Update einer Uhr zeigt.
public enum Firmwarelage: Equatable, Sendable {
    /// Die Uhr nimmt hier nie ein Update an (ältere Fassung ohne `updateImage` oder
    /// ein unbekannter Dateiname): weder Zeile noch Hinweis.
    case verborgen
    /// Ohne Adresse gibt es kein HTTP; der Nutzer trägt sie ein.
    case ohneAdresse
    case bereit

    /// Eine Uhr, deren Zustand nie gelesen wurde (`zustand == nil`), gilt als bereit.
    public static func fuer(adresse: Bool, zustand: Geraetezustand?) -> Firmwarelage {
        guard adresse else { return .ohneAdresse }
        if let zustand, !Firmwarepakete.erlaubt.contains(zustand.updateImage ?? "") { return .verborgen }
        return .bereit
    }
}

/// Wo ein Update gerade steht; die Oberfläche zeigt es als Fortschritt.
public enum Firmwarestufe: Equatable, Sendable {
    case laedt(Double)
    case uebertraegt(Double)
    case startetNeu
}

public enum Firmwarefehler: Error, LocalizedError, Equatable {
    // GitHub
    case githubNichtErreichbar
    case githubBegrenzt
    case githubFehler(Int)
    case freigabeUnbrauchbar
    case installierteFassungUnbekannt
    case keinPaketFuerDieseUhr
    case ladenAbgebrochen
    case herkunftUnerlaubt
    case pruefungFehlgeschlagen
    // die Uhr (`POST /update`)
    case nichtNeuer
    case paketBeschaedigt
    case falschesZiel
    case falscherChip
    case speicherZuKlein(String)
    case updateBelegt
    case einrichtungsmodus
    case fremdeHerkunft
    case anmeldungFehlt
    case paketZuGross
    case zuWenigArbeitsspeicher
    case schreibenFehlgeschlagen
    case keinPaketErkannt
    case abgewiesen(status: Int, code: String)
    // danach
    case neustartAusgeblieben
    case fassungUnveraendert(String)
    case startFehlgeschlagen(String)

    /// Die Antwort von `POST /update` als Fehler; `code` und `message` aus dem
    /// Fehlerrumpf. Geschaltet wird auf den Code: Dieselbe Abweisung kommt je nach
    /// Uhr mit anderem Status (`insufficientStorage` ist bei der TC002 `409`,
    /// sonst `507`).
    public static func aus(status: Int, code: String?, message: String?) -> Firmwarefehler {
        switch code {
        case "notNewer": return .nichtNeuer
        case "invalidPackage": return .paketBeschaedigt
        case "wrongTarget": return .falschesZiel
        case "wrongChip": return .falscherChip
        case "insufficientStorage": return .speicherZuKlein(message ?? "")
        case "updateBusy": return .updateBelegt
        case "forbidden": return .einrichtungsmodus
        case "forbiddenOrigin": return .fremdeHerkunft
        case "payloadTooLarge": return .paketZuGross
        case "insufficientMemory": return .zuWenigArbeitsspeicher
        case "internalError": return .schreibenFehlgeschlagen
        case "badRequest": return .keinPaketErkannt
        default:
            if status == 401 { return .anmeldungFehlt }
            return .abgewiesen(status: status, code: code ?? lok("ohne Begründung"))
        }
    }

    public var errorDescription: String? {
        switch self {
        case .githubNichtErreichbar:
            return lok("GitHub ist nicht erreichbar. Internetverbindung prüfen und erneut versuchen.")
        case .githubBegrenzt:
            return lok("GitHub begrenzt die Anfragen aus diesem Netz gerade. Später erneut versuchen.")
        case .githubFehler(let status):
            return lokf("GitHub hat die Anfrage nicht beantwortet (Status %d). Später erneut versuchen.", status)
        case .freigabeUnbrauchbar:
            return lok("Die Angaben zum neuesten Release sind unbrauchbar. Das Paket wird nicht angeboten.")
        case .installierteFassungUnbekannt:
            return lok("Die Fassung der Uhr ist nicht bekannt. Zuerst die Uhr abfragen.")
        case .keinPaketFuerDieseUhr:
            return lok("Diese Uhr nennt kein Paket, das die App einspielen darf.")
        case .ladenAbgebrochen:
            return lok("Das Laden des Pakets ist abgebrochen. Internetverbindung prüfen und erneut versuchen.")
        case .herkunftUnerlaubt:
            return lok("Der Download wurde auf eine Adresse außerhalb von GitHub umgeleitet und abgebrochen.")
        case .pruefungFehlgeschlagen:
            return lok("Das geladene Paket stimmt nicht mit den Angaben von GitHub überein (Größe, Kennung oder Prüfsumme). Es wurde nicht an die Uhr geschickt.")
        case .nichtNeuer:
            return lok("Die Uhr hat diese Fassung oder eine neuere schon. Eine ältere lässt sich nur per USB einspielen.")
        case .paketBeschaedigt:
            return lok("Das Paket ist beschädigt, unvollständig oder in einem unbekannten Format. Bitte erneut laden.")
        case .falschesZiel:
            return lok("Das Paket ist für ein anderes Gerät gemacht.")
        case .falscherChip:
            return lok("Das Paket passt nicht zu dieser Uhr: anderer Chip, anderer Speichertyp oder eine Datei für die Erstinstallation per USB.")
        case .speicherZuKlein(let angabe):
            let rest = angabe.isEmpty ? "" : " " + lokf("Die Uhr schreibt dazu: %@", angabe)
            return lok("Das Paket ist größer, als die Uhr aufnehmen kann.") + rest
        case .updateBelegt:
            return lok("Die Uhr nimmt gerade ein anderes Update an oder bestätigt noch das letzte. In einigen Minuten erneut versuchen.")
        case .einrichtungsmodus:
            return lok("Im Einrichtungsmodus nimmt die Uhr kein Update an. Zuerst ins WLAN bringen.")
        case .fremdeHerkunft:
            return lok("Die Uhr hat die Anfrage als Anfrage einer fremden Webseite abgewiesen.")
        case .anmeldungFehlt:
            return lok("Die Anmeldung an der Uhr ist fehlgeschlagen.")
        case .paketZuGross:
            return lok("Das Paket ist größer als erlaubt.")
        case .zuWenigArbeitsspeicher:
            return lok("Die Uhr hat gerade zu wenig freien Arbeitsspeicher für das Paket. Später erneut versuchen.")
        case .schreibenFehlgeschlagen:
            return lok("Die Uhr konnte das Paket nicht schreiben.")
        case .keinPaketErkannt:
            return lok("Die Uhr hat nicht genau ein Paket erkannt.")
        case .abgewiesen(let status, let code):
            return lokf("Die Uhr hat das Paket abgewiesen: %@ (Status %d)", code, status)
        case .neustartAusgeblieben:
            return lok("Die Uhr hat sich nach dem Update nicht wieder gemeldet. Strom und WLAN prüfen; startet die neue Fassung dreimal nicht, zeigt die Uhr „USB RECOVERY“ und ist nur per USB zu retten.")
        case .fassungUnveraendert(let fassung):
            return lokf("Die Uhr läuft weiter mit Fassung %@. Das Update ist nicht angekommen.", fassung)
        case .startFehlgeschlagen(let grund):
            return grund.isEmpty ? lok("Die neue Fassung ist nicht gestartet.")
                : lokf("Die neue Fassung ist nicht gestartet: %@", grund)
        }
    }
}
