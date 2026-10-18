import Foundation

/// Wie lange nach dem Hochladen auf die neue Fassung gewartet wird. Die Weboberfläche
/// wartet 15 s und fragt dann alle 3 s bis höchstens 180 s (`maintenance.js`).
/// Gezählt wird in Fragen, nicht nach der Uhr: Das Ende hängt so nicht davon ab, wie
/// lange eine einzelne Frage braucht, und Tests laufen ohne Warten.
public struct Firmwarewartezeit: Sendable {
    public var vorlauf: TimeInterval
    public var takt: TimeInterval
    public var fragen: Int

    public init(vorlauf: TimeInterval = 15, takt: TimeInterval = 3, fragen: Int = 60) {
        self.vorlauf = vorlauf; self.takt = takt; self.fragen = fragen
    }
}

/// Die neue Fassung läuft.
public struct Firmwareergebnis: Equatable, Sendable {
    public let fassung: String
    /// `update.state` ist `boot-pending`: Die TC002 sperrt weitere Uploads, bis die
    /// neue Fassung eine Minute gelaufen ist, und fällt sonst zurück.
    public let bestaetigungAusstehend: Bool
}

/// Das Firmware-Update über HTTP (`docs/awtrix-ng-protokoll.md` §7.6).
extension Geraet {
    /// `POST /update`, `multipart`, Feld `firmware`. `true`, wenn die Uhr das Paket
    /// annimmt und es erst danach einspielt (TC002: `{"ok":true,"applying":true}`);
    /// `false` bei `{"ok":true}`, wo sie sofort neu startet (ESP32).
    public func firmwareHochladen(_ paket: Data, dateiname: String,
                                  fortschritt: @escaping @Sendable (Double) -> Void) async throws -> Bool {
        let name = dateiname.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" && $0 != "\\" }
        let grenze = "TC002-" + UUID().uuidString
        var rumpf = Data("--\(grenze)\r\nContent-Disposition: form-data; name=\"firmware\"; filename=\"\(name)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
        rumpf.append(paket)
        rumpf.append(Data("\r\n--\(grenze)--\r\n".utf8))
        let (daten, status) = try await hochladen("POST", "/update", koerper: rumpf,
                                                  inhaltsart: "multipart/form-data; boundary=\(grenze)",
                                                  frist: 120, fortschritt: fortschritt)
        let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
        if status == 200 {
            guard o?["ok"] as? Bool == true else { throw GeraetFehler.unerwarteteAntwort("/update") }
            return o?["applying"] as? Bool == true
        }
        let fehler = o?["error"] as? [String: Any]
        throw Firmwarefehler.aus(status: status, code: fehler?["code"] as? String, message: fehler?["message"] as? String)
    }

    /// `GET /api/v1/version`.
    public func laufendeFassung() throws -> String {
        guard let fassung = try hole("/api/v1/version")["version"] as? String else {
            throw GeraetFehler.unerwarteteAntwort("/api/v1/version")
        }
        return fassung
    }

    /// Wartet, bis die Uhr mit `erwartet` antwortet. Die alte Fassung antwortet nach
    /// dem Hochladen eine Weile weiter, und während des Neustarts gar nicht: Weder das
    /// eine noch das andere ist ein Ergebnis. Erfolg heißt nur: die erwartete Fassung
    /// antwortet.
    ///
    /// Wirft `startFehlgeschlagen`, wenn die Uhr nach einem Ausfall wieder antwortet,
    /// `update.state` `failed` ist und die alte Fassung läuft; am Ende der Fragen
    /// `neustartAusgeblieben` (nie wieder eine Antwort) oder `fassungUnveraendert`.
    /// `schlafen` ist für Tests ersetzbar.
    public func neustartAbwarten(erwartet: String, zeit: Firmwarewartezeit = Firmwarewartezeit(),
                                 schlafen: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }) throws -> Firmwareergebnis {
        guard let ziel = Firmwareversion(erwartet) else { throw Firmwarefehler.freigabeUnbrauchbar }
        schlafen(zeit.vorlauf)
        var ausgefallen = false
        var letzte: String?
        for frage in 0..<max(1, zeit.fragen) {
            if frage > 0 { schlafen(zeit.takt) }
            guard let gelesen = try? laufendeFassung() else {
                ausgefallen = true
                letzte = nil
                continue
            }
            letzte = gelesen
            if let v = Firmwareversion(gelesen), v == ziel {
                let stand = try? geraetezustand().updatestand
                return Firmwareergebnis(fassung: gelesen, bestaetigungAusstehend: stand == "boot-pending")
            }
            if ausgefallen, let z = try? geraetezustand(), z.updatestand == "failed" {
                throw Firmwarefehler.startFehlgeschlagen(z.updatefehler ?? "")
            }
        }
        if let letzte { throw Firmwarefehler.fassungUnveraendert(letzte) }
        throw Firmwarefehler.neustartAusgeblieben
    }
}
