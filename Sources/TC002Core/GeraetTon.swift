import Foundation

/// Klang über HTTP: Abspielen, Anhalten, Senderliste, Melodien und die
/// Lesewege (`docs/awtrix-ng-protokoll.md` §3.2.1, §4.2, §7.5). Das Hochladen von
/// MP3-Dateien (`multipart`) ist nicht dabei.
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
    public func mp3Dateien() throws -> Tonablage {
        Tonablage(antwort: try hole("/api/v1/audio/mp3"), liste: "files")
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
