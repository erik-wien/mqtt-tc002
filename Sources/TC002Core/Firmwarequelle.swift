import Foundation

/// Die einzige Stelle, an der die App GitHub anspricht: das neueste Release von
/// `Blueforcer/awtrix-ng` lesen und das Paket laden. Ohne Anmeldung, ohne Kennung,
/// und nur auf ausdrücklichen Druck (`Firmwareupdate`) — nie von selbst.
///
/// Vorbild ist der Installer des Herstellers (`tools/tc002/desktop/native/src/download.rs`
/// im Repository, aus dem Quelltext gelesen): `releases/latest` (ohne Entwürfe und
/// Vorabfassungen), genau ein Anhang mit dem Namen, den die Uhr als `updateImage`
/// nennt, `state` `uploaded`, die Adresse genau
/// `https://github.com/Blueforcer/awtrix-ng/releases/download/<tag>/<name>`, die
/// Prüfsumme aus `digest` (`sha256:<64 Hexziffern>`). Das Paket ist nicht signiert;
/// die Prüfsumme schützt nur vor einer beschädigten oder ausgetauschten Datei, nicht
/// vor einem Release, das der Hersteller selbst falsch baut.
///
/// Die Weboberfläche der Uhr lädt stattdessen von einem Spiegel auf
/// `blueforcer.github.io`; hier gilt die Herstelleradresse auf github.com.
public struct Firmwarequelle: Sendable {
    public static let freigabeAdresse = URL(string: "https://api.github.com/repos/Blueforcer/awtrix-ng/releases/latest")!
    public static let herkunft = "github.com/Blueforcer/awtrix-ng"
    static let ladeAdresse = "https://github.com/Blueforcer/awtrix-ng/releases/download/"
    /// Die Angaben zum Release sind Text im KiB-Bereich.
    static let hoechstMetadaten = 1 << 20

    private let sitzung: URLSession

    public init(sitzung: URLSession = .shared) { self.sitzung = sitzung }

    /// Hosts, auf die ein Download weitergeleitet werden darf (wie im Installer).
    /// Nur `https`, ohne Zugangsdaten, Port und Fragment.
    public static func weiterleitungErlaubt(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && url.port == nil
            && url.fragment == nil
            && ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"]
                .contains(url.host ?? "")
    }

    // MARK: - Suchen

    /// Fragt das neueste Release und vergleicht es mit der Fassung der Uhr.
    /// `updateImage` ist der Name, den die Uhr nennt.
    public func suchen(updateImage: String, installiert: String) async throws -> Firmwareangebot {
        guard Firmwarepakete.erlaubt.contains(updateImage) else { throw Firmwarefehler.keinPaketFuerDieseUhr }
        guard let aktuell = Firmwareversion(installiert) else { throw Firmwarefehler.installierteFassungUnbekannt }
        var anfrage = URLRequest(url: Self.freigabeAdresse, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 30)
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        anfrage.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        anfrage.setValue("PixelClockMessenger", forHTTPHeaderField: "User-Agent")
        let daten: Data, antwort: URLResponse
        do { (daten, antwort) = try await sitzung.data(for: anfrage) } catch {
            throw Firmwarefehler.githubNichtErreichbar
        }
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw status == 403 || status == 429 ? Firmwarefehler.githubBegrenzt : Firmwarefehler.githubFehler(status)
        }
        guard daten.count <= Self.hoechstMetadaten else { throw Firmwarefehler.freigabeUnbrauchbar }
        return try Self.angebot(aus: daten, updateImage: updateImage, installiert: aktuell, installiertText: installiert)
    }

    /// Liest die Antwort von `releases/latest`.
    static func angebot(aus daten: Data, updateImage: String, installiert: Firmwareversion,
                        installiertText: String) throws -> Firmwareangebot {
        guard let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any],
              let tag = o["tag_name"] as? String,
              o["draft"] as? Bool == false, o["prerelease"] as? Bool == false,
              !tag.isEmpty, tag.count <= 100,
              tag.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122)
                  || [46, 95, 43, 45].contains($0) }),
              let neu = Firmwareversion(tag) else { throw Firmwarefehler.freigabeUnbrauchbar }
        // Eine neuere Nummer allein genügt nicht, aber eine gleiche oder ältere
        // braucht keine Prüfung des Anhangs.
        guard neu > installiert else { return .aktuell(installiert: installiertText) }
        let fassung = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let passende = ((o["assets"] as? [[String: Any]]) ?? []).filter { $0["name"] as? String == updateImage }
        guard let anhang = passende.first else { return .keinPaket(fassung: fassung, dateiname: updateImage) }
        let adresse = Self.ladeAdresse + tag + "/" + updateImage
        guard passende.count == 1, anhang["state"] as? String == "uploaded",
              let groesse = anhang["size"] as? Int, groesse > 0, groesse <= Firmwarepakete.hoechstgroesse(updateImage),
              anhang["browser_download_url"] as? String == adresse, let url = URL(string: adresse),
              let digest = anhang["digest"] as? String, digest.hasPrefix("sha256:") else {
            throw Firmwarefehler.freigabeUnbrauchbar
        }
        let summe = String(digest.dropFirst("sha256:".count))
        guard summe.count == 64, summe.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) else {
            throw Firmwarefehler.freigabeUnbrauchbar
        }
        return .verfuegbar(Firmwarepaket(fassung: fassung, tag: tag, dateiname: updateImage, groesse: groesse,
                                         sha256: summe, adresse: url,
                                         notizen: (o["html_url"] as? String).flatMap(URL.init(string:))))
    }

    // MARK: - Laden

    /// Lädt das Paket in den Speicher (nie auf die Platte) und prüft Größe, Kopf und
    /// Prüfsumme. Mehr als `groesse` Byte brechen ab.
    public func laden(_ paket: Firmwarepaket, fortschritt: @Sendable (Double) -> Void) async throws -> Data {
        var anfrage = URLRequest(url: paket.adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        anfrage.setValue("PixelClockMessenger", forHTTPHeaderField: "User-Agent")
        let waechter = Weiterleitungswaechter()
        var daten = Data()
        daten.reserveCapacity(paket.groesse)
        do {
            let (strom, antwort) = try await sitzung.bytes(for: anfrage, delegate: waechter)
            if waechter.verweigert { throw Firmwarefehler.herkunftUnerlaubt }
            let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                throw status == 403 || status == 429 ? Firmwarefehler.githubBegrenzt : Firmwarefehler.githubFehler(status)
            }
            if antwort.expectedContentLength > Int64(paket.groesse) { throw Firmwarefehler.pruefungFehlgeschlagen }
            var stueck = Data()
            for try await byte in strom {
                stueck.append(byte)
                if stueck.count >= 64 << 10 {
                    daten.append(stueck)
                    stueck.removeAll(keepingCapacity: true)
                    guard daten.count <= paket.groesse else { throw Firmwarefehler.pruefungFehlgeschlagen }
                    fortschritt(Double(daten.count) / Double(paket.groesse))
                }
            }
            daten.append(stueck)
        } catch let fehler as Firmwarefehler {
            throw fehler
        } catch {
            throw waechter.verweigert ? Firmwarefehler.herkunftUnerlaubt : Firmwarefehler.ladenAbgebrochen
        }
        fortschritt(1)
        try Firmwarepakete.pruefen(daten, gegen: paket)
        return daten
    }
}

/// Lässt eine Weiterleitung nur auf die Hosts von `Firmwarequelle.weiterleitungErlaubt`
/// zu, höchstens fünfmal. Bei einem Verstoß endet der Abruf mit der Weiterleitung als
/// Antwort, die `laden` als `herkunftUnerlaubt` meldet.
final class Weiterleitungswaechter: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let sperre = NSLock()
    private var spruenge = 0
    private var _verweigert = false

    var verweigert: Bool { sperre.lock(); defer { sperre.unlock() }; return _verweigert }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        sperre.lock()
        spruenge += 1
        let ok = spruenge <= 5 && (request.url.map(Firmwarequelle.weiterleitungErlaubt) ?? false)
        if !ok { _verweigert = true }
        sperre.unlock()
        completionHandler(ok ? request : nil)
    }
}
