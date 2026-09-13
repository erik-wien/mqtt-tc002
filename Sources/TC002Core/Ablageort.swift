import Foundation

/// Wo die vier Bestaende dieser Installation liegen — oertlich unter
/// `Application Support`, oder im iCloud-Behaelter.
///
/// **Die eine Stelle, an der das entschieden wird.** `Iconordner`,
/// `Bilderordner` und `Slotgedaechtnis` fragen hier nach, statt selbst zu
/// rechnen; damit sehen App, Kurzbefehle und Kommandozeilenwerkzeug
/// zwangslaeufig denselben Bestand. Ein Werkzeug, das andere Icons und andere
/// Slots saehe als die App, waere eine Falle — genau deshalb liegt diese
/// Entscheidung im Kern und nicht in der Oberflaeche.
///
/// **Gespiegelt wird nicht, umgezogen wird.** Ein Spiegel waere ein eigener
/// Abgleichmotor — zwei Richtungen, Grabsteine fuer Geloeschtes, eigene
/// Konfliktaufloesung. Ein Behaelter ist dasselbe Ergebnis, nur macht es das
/// System. Der **Hinweg kopiert trotzdem, statt zu verschieben**: Der
/// oertliche Bestand bleibt liegen, solange nichts ihn wegraeumt, und ist
/// damit der Rueckweg schon eingebaut (`Bestandsumzug`).
///
/// **Ohne Berechtigung passiert nichts.** `url(forUbiquityContainerIdentifier:)`
/// liefert ohne registrierten Behaelter und ohne die Eintraege in der Signatur
/// `nil`. Das ist kein Fehler, sondern der Normalfall auf einem Rechner ohne
/// Entwicklerkonto: `ferneWurzel` bleibt `nil`, `wirkt` bleibt `false`, und die
/// App arbeitet Zeichen fuer Zeichen wie bisher.
public struct Ablageort: Sendable, Equatable {
    /// Die vier Bestaende. Der `rawValue` ist der Ordnername — oertlich wie im
    /// Behaelter derselbe, damit ein Umzug nichts umbenennt.
    public enum Bestand: String, CaseIterable, Sendable {
        case icons8 = "Icons"
        case icons16 = "Icons16"
        case bilder = "Bilder"
        case slots = "Slots"
    }

    /// Die Kennung des iCloud-Behaelters. Apples Form ist `iCloud.` vor der
    /// Buendelkennung; genau so muss sie im Entwicklerkonto und in der
    /// Signatur stehen (`com.apple.developer.icloud-container-identifiers`).
    public static let behaelterKennung = "iCloud." + Einstellungen.kennung

    /// Unter welchem Schluessel die Wahl liegt. In den gewoehnlichen
    /// Einstellungen und **nicht** in der Wolke: Ob dieses Geraet abgleicht,
    /// ist eine Aussage ueber dieses Geraet. Ein abgeglichener Schalter wuerde
    /// ein zweites Geraet mit umschalten, das nie gefragt wurde.
    public static let schluessel = "icloud.abgleich"

    public let oertlicheWurzel: URL
    /// `nil` heisst: kein Behaelter erreichbar — keine Berechtigung, kein
    /// angemeldeter iCloud-Account, oder der Abgleich ist gar nicht gewuenscht.
    public let ferneWurzel: URL?
    /// Was der Nutzer gewaehlt hat — unabhaengig davon, ob es geht.
    public let gewuenscht: Bool

    public init(oertlicheWurzel: URL, ferneWurzel: URL?, gewuenscht: Bool) {
        self.oertlicheWurzel = oertlicheWurzel
        self.ferneWurzel = ferneWurzel
        self.gewuenscht = gewuenscht
    }

    /// Ob der Abgleich gewaehlt **und** moeglich ist. Nur dann liegen die
    /// Bestaende im Behaelter.
    public var wirkt: Bool { gewuenscht && ferneWurzel != nil }

    /// Wo die Bestaende gerade wirklich liegen.
    public var wurzel: URL { wirkt ? (ferneWurzel ?? oertlicheWurzel) : oertlicheWurzel }

    /// Der Ordner eines Bestands — **reine Rechnung, legt nichts an.** Er wird
    /// auf jedem Neuzeichnen gefragt (`AppZustand.slotzustand` fuenfmal je
    /// Bild); ein `createDirectory` an dieser Stelle liefe bei jedem
    /// Tastendruck mit. Angelegt wird einmal, in `angelegt()`.
    public func ordner(_ bestand: Bestand) -> URL {
        wurzel.appendingPathComponent(bestand.rawValue)
    }

    public func oertlicherOrdner(_ bestand: Bestand) -> URL {
        oertlicheWurzel.appendingPathComponent(bestand.rawValue)
    }

    public func fernerOrdner(_ bestand: Bestand) -> URL? {
        ferneWurzel?.appendingPathComponent(bestand.rawValue)
    }

    /// Legt die vier Ordner an und gibt sich selbst zurueck — einmal beim
    /// Ermitteln, nicht bei jedem Zugriff.
    @discardableResult
    public func angelegt() -> Ablageort {
        for bestand in Bestand.allCases {
            try? FileManager.default.createDirectory(at: ordner(bestand),
                                                     withIntermediateDirectories: true)
        }
        return self
    }
}

// MARK: - Die Ablage dieser Installation

extension Ablageort {
    /// `Application Support/MQTT-TC002` — wo die Bestaende seit jeher liegen.
    public static var oertlicheWurzelStandard: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MQTT-TC002")
    }

    /// `<Behaelter>/Documents` — **`Documents`, nicht die Wurzel des
    /// Behaelters.** Nur was dort liegt, taucht in „Dateien" und in iCloud
    /// Drive auf; das ist dieselbe Ueberlegung, aus der Icons und Bilder als
    /// GIF gesichert werden statt in einem eigenen Format: Man soll sie auch
    /// ausserhalb der App sehen koennen.
    ///
    /// **Blockiert beim ersten Aufruf** und gehoert deshalb nicht auf den
    /// Hauptthread (Apple sagt das ausdruecklich). `vorbereiten()` waermt den
    /// Zwischenspeicher losgeloest an.
    public static func behaelterErmitteln() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: behaelterKennung)?
            .appendingPathComponent("Documents")
    }

    /// Die gewaehlte Einstellung. Liegt in derselben Ablage, die auch das
    /// Werkzeug liest — dadurch folgt es dem Abgleich, ohne etwas davon zu
    /// wissen.
    public static func gewaehlt(bereich: String = Einstellungen.kennung) -> Bool {
        Einstellungen.ablage(bereich)?.bool(forKey: schluessel) ?? false
    }

    /// Schreibt die Wahl und wirft den Zwischenspeicher weg — der naechste
    /// Zugriff ermittelt neu.
    public static func waehlen(_ an: Bool, bereich: String = Einstellungen.kennung) {
        Einstellungen.ablage(bereich)?.set(an, forKey: schluessel)
        vergessen()
    }

    private static let sperre = NSLock()
    nonisolated(unsafe) private static var zwischenspeicher: Ablageort?

    /// Der Ort dieser Installation. Zwischengespeichert, weil
    /// `behaelterErmitteln()` teuer ist und weil `ordner(_:)` im Zeichenweg
    /// liegt.
    ///
    /// **Ist der Abgleich nicht gewaehlt, wird der Behaelter gar nicht erst
    /// gesucht** — dann kostet dieser Typ nichts und tut nichts, was es vorher
    /// nicht auch gab.
    public static var gemeinsam: Ablageort {
        sperre.lock()
        defer { sperre.unlock() }
        if let vorhanden = zwischenspeicher { return vorhanden }
        let an = gewaehlt()
        let ort = Ablageort(oertlicheWurzel: oertlicheWurzelStandard,
                            ferneWurzel: an ? behaelterErmitteln() : nil,
                            gewuenscht: an).angelegt()
        zwischenspeicher = ort
        return ort
    }

    /// Wirft den Zwischenspeicher weg. Nach dem Umschalten noetig, sonst
    /// zeigten `Iconordner` und Konsorten weiter auf den alten Ort.
    public static func vergessen() {
        sperre.lock()
        defer { sperre.unlock() }
        zwischenspeicher = nil
    }

    /// Ermittelt losgeloest vom Hauptthread vor, damit die erste Ansicht nicht
    /// darauf wartet.
    ///
    /// **Ohne gewaehlten Abgleich geschieht hier gar nichts** — es gaebe nichts
    /// vorzuwaermen, und ein losgeloester Task bei jedem Bauen von
    /// `AppZustand` waere Unruhe ohne Gegenwert (in den Tests wird dieser Typ
    /// hundertfach gebaut).
    public static func vorbereiten() {
        guard gewaehlt() else { return }
        Task.detached(priority: .utility) { _ = Ablageort.gemeinsam }
    }

    /// Stoesst das Herunterladen der Bestaende an. Eine Datei im Behaelter, die
    /// auf diesem Geraet noch nicht materialisiert ist, liegt als Platzhalter
    /// da — `contentsOfDirectory` sieht sie dann als `.name.gif.icloud`, und
    /// die Filter auf `gif`/`png` lassen sie fallen. Der Bestand waere also
    /// nicht falsch, nur unvollstaendig, bis das System nachgeladen hat.
    public func herunterladenAnstossen() {
        guard wirkt else { return }
        for bestand in Bestand.allCases {
            let ordner = ordner(bestand)
            let dateien = (try? FileManager.default.contentsOfDirectory(
                at: ordner, includingPropertiesForKeys: nil)) ?? []
            for datei in dateien {
                try? FileManager.default.startDownloadingUbiquitousItem(at: datei)
            }
        }
    }
}

// MARK: - Umschalten

/// Was beim Umschalten herauskam. `gewaehlt` ist, was **danach** gilt — nicht,
/// was gewuenscht war: Ohne Behaelter bleibt der Abgleich aus, statt auf „an"
/// zu stehen und nichts zu tun.
public struct Umschaltergebnis: Sendable, Equatable {
    public var gewaehlt: Bool
    public var bereit: Bool
    public var bilanz: Bestandsumzug.Bilanz

    public init(gewaehlt: Bool, bereit: Bool, bilanz: Bestandsumzug.Bilanz) {
        self.gewaehlt = gewaehlt
        self.bereit = bereit
        self.bilanz = bilanz
    }
}

extension Ablageort {
    /// Den Abgleich ein- oder ausschalten — mitsamt dem Umzug, der dazugehoert.
    ///
    /// **Blockiert** (`behaelterErmitteln`, dann kopieren) und gehoert deshalb
    /// nicht auf den Hauptthread.
    ///
    /// Die Reihenfolge ist beide Male dieselbe: **erst kopieren, dann die Wahl
    /// schreiben.** Umgekehrt zeigte `Ablageort.gemeinsam` schon auf den neuen
    /// Ort, waehrend der Umzug noch liefe — und ein Sendevorgang mittendrin
    /// schriebe in einen halb gefuellten Bestand.
    ///
    /// Ohne Behaelter wird **nichts** geschrieben und nichts kopiert. Das ist
    /// der Normalfall ohne Berechtigung: Die Wahl bleibt aus, die App arbeitet
    /// weiter oertlich, und niemand steht vor einem halben Zustand.
    public static func umschalten(_ an: Bool,
                                  bereich: String = Einstellungen.kennung,
                                  oertlicheWurzel: URL = oertlicheWurzelStandard,
                                  behaelter: () -> URL? = { behaelterErmitteln() })
        -> Umschaltergebnis {
        guard let fern = behaelter() else {
            // Kein Behaelter: Auch das Abschalten ist dann nur noch das
            // Streichen einer Wahl, die ohnehin nie gewirkt hat.
            if !an { waehlen(false, bereich: bereich) }
            return Umschaltergebnis(gewaehlt: false, bereit: false, bilanz: Bestandsumzug.Bilanz())
        }
        let ort = Ablageort(oertlicheWurzel: oertlicheWurzel, ferneWurzel: fern,
                            gewuenscht: true).angelegt()
        let bilanz = an ? Bestandsumzug.hinweg(ort) : Bestandsumzug.rueckweg(ort)
        waehlen(an, bereich: bereich)
        return Umschaltergebnis(gewaehlt: an, bereit: true, bilanz: bilanz)
    }
}
