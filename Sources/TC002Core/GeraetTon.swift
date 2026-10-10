import Foundation

/// Klang über HTTP: Abspielen, Anhalten, Senderliste, Melodien, MP3-Dateien
/// hoch- und herunterladen und die Lesewege (`docs/awtrix-ng-protokoll.md` §3.2.1,
/// §4.2, §7.5).
extension Geraet {
    /// `GET /api/v1/audio`: Wiedergabezustand und Senderliste.
    public func tonzustand() throws -> Tonzustand {
        guard let z = Tonzustand(antwort: try hole("/api/v1/audio")) else {
            throw GeraetFehler.unerwarteteAntwort("/api/v1/audio")
        }
        return z
    }

    /// `GET /api/v1/audio/melodies`.
    public func melodien() throws -> Tonablage {
        Tonablage(antwort: try hole("/api/v1/audio/melodies"), liste: "melodies")
    }

    /// `GET /api/v1/audio/mp3` (nur `files`; die Skriptklänge in `scripts` bleiben außen vor).
    /// Die Uhr führt `x.mp3`; hier steht `x`, so wie Abspielen und Löschen es brauchen.
    public func mp3Dateien() throws -> Tonablage {
        Tonablage(antwort: try hole("/api/v1/audio/mp3"), liste: "files", endung: ".mp3")
    }

    /// Mehr als eine MP3-Datei dieser Größe nimmt die App nicht zum Hochladen.
    /// ❓ Die Doku nennt keine Grenze für das Hochladen; 4 MB ist die der MP3 von
    /// einer Adresse (§5), und die Uhr lehnt mit `507` ab, was nicht passt.
    public static let mp3Hoechstgroesse = 4 * 1000 * 1000

    /// `POST /api/v1/audio/mp3`, `multipart`, Feld `file`; der Dateiname im Teil
    /// ist der Name auf der Uhr. Eine gleichnamige MP3 überschreibt die Uhr
    /// still (gemessen); Melodien sind `409`. Name und Größe prüft der Kern vorher.
    public func mp3Hochladen(name: String, daten: Data, faehigkeiten: Geraetefaehigkeiten? = nil) throws {
        guard Klangeignung.mp3Hochladbar(faehigkeiten) else { throw KlangFehler.mp3NichtSpielbar }
        guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
        guard !daten.isEmpty else { throw KlangFehler.mp3Leer }
        guard daten.count <= Self.mp3Hoechstgroesse else {
            throw KlangFehler.mp3ZuGross(bytes: daten.count, grenze: Self.mp3Hoechstgroesse)
        }
        let grenze = "TC002-" + UUID().uuidString
        var rumpf = Data("--\(grenze)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name).mp3\"\r\nContent-Type: audio/mpeg\r\n\r\n".utf8)
        rumpf.append(daten)
        rumpf.append(Data("\r\n--\(grenze)--\r\n".utf8))
        do {
            try ngAnfrage("POST", "/api/v1/audio/mp3", koerper: rumpf,
                          inhaltsart: "multipart/form-data; boundary=\(grenze)", frist: 60)
        } catch GeraetFehler.ngAbgewiesen(let status, let code, _) {
            switch (status, code) {
            case (400, "invalidName"): throw KlangFehler.ungueltigerKlangname(name)
            case (409, _): throw KlangFehler.mp3NameBelegt(name)
            case (415, _): throw KlangFehler.keinMP3
            case (413, _), (507, _): throw KlangFehler.mp3KeinPlatz
            default: throw GeraetFehler.ngAbgewiesen(status: status, code: code, feld: nil)
            }
        }
    }

    /// `DELETE /api/v1/audio/mp3/{name}` (ohne `.mp3`).
    public func mp3Loeschen(name: String) throws {
        guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
        do {
            try ngAnfrage("DELETE", "/api/v1/audio/mp3/" + Self.ngName(name), koerper: nil)
        } catch GeraetFehler.ngAbgewiesen(404, _, _) {
            throw KlangFehler.mp3Unbekannt(name)
        }
    }

    /// `GET /api/v1/audio/stations`.
    public func senderliste() throws -> [Radiosender] {
        Tonzustand.sender(aus: try hole("/api/v1/audio/stations")["stations"])
    }

    /// `POST /api/v1/audio/play` mit dem fertigen JSON (`Klangbau.spielen`).
    public func tonSpielen(_ json: String) throws {
        try ngAnfrage("POST", "/api/v1/audio/play", koerper: Data(json.utf8))
    }

    /// `POST /api/v1/audio/stop`; `{}` hält alles an.
    public func tonStoppen(_ json: String) throws {
        try ngAnfrage("POST", "/api/v1/audio/stop", koerper: Data(json.utf8))
    }

    /// `PUT /api/v1/audio/stations`: ersetzt die ganze Liste.
    public func senderSetzen(_ json: String) throws {
        try ngAnfrage("PUT", "/api/v1/audio/stations", koerper: Data(json.utf8))
    }

    /// `PUT /api/v1/audio/melodies/{name}`: `true` bei `201` (neu), `false` bei `200` (ersetzt).
    @discardableResult
    public func melodieSetzen(name: String, json: String) throws -> Bool {
        try ngAntwort("PUT", "/api/v1/audio/melodies/" + Self.ngName(name), koerper: Data(json.utf8)).status == 201
    }

    /// `DELETE /api/v1/audio/melodies/{name}`; `404`, wenn es keine so heißende gibt.
    public func melodieLoeschen(name: String) throws {
        try ngAnfrage("DELETE", "/api/v1/audio/melodies/" + Self.ngName(name), koerper: nil)
    }
}
