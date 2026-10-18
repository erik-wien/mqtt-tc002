import Foundation

/// Unkomprimiertes Zip (Methode „stored“), das Sicherungsformat der AWTRIX-NG-
/// Weboberfläche. Geschrieben wird ohne Datenbeschreiber, gelesen über das
/// zentrale Verzeichnis; Zip64, Verschlüsselung und Deflate gibt es nicht und
/// weist der Leser ab.
public enum Sicherungszip {
    public struct Eintrag: Equatable, Sendable {
        public let pfad: String
        public let daten: Data
        public init(pfad: String, daten: Data) {
            self.pfad = pfad
            self.daten = daten
        }
    }

    public enum Fehler: Error, Equatable {
        case kaputt
        case nichtUnterstuetzt
        case pruefsummeFalsch(String)
        case keineSicherung
        case fremdeSicherung
        case fassungUnbekannt(Int)
    }

    /// Inhalt von `manifest.json`: `app`, `backupFormat`, `createdAt`.
    public static let appKennung = "awtrix-ng"
    public static let formatFassung = 1

    // MARK: CRC32

    private static let tabelle: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    /// CRC-32 nach IEEE 802.3 (wie Zip, PNG, zlib).
    public static func crc32(_ daten: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in daten { c = tabelle[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    // MARK: Schreiben

    /// Das Manifest, als erster Eintrag zu schreiben.
    public static func manifest(erstellt: Date) -> Eintrag {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let json: [String: Any] = [
            "app": appKennung,
            "backupFormat": formatFassung,
            "createdAt": iso.string(from: erstellt),
        ]
        let daten = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
        return Eintrag(pfad: "manifest.json", daten: daten)
    }

    /// Baut das Zip in der gegebenen Reihenfolge. Der Zeitstempel ist fest
    /// 1980-01-01, damit gleicher Inhalt gleiche Bytes ergibt.
    public static func schreiben(_ eintraege: [Eintrag]) -> Data {
        var aus = Data()
        var verzeichnis = Data()
        for e in eintraege {
            let name = Data(e.pfad.utf8)
            let crc = crc32(e.daten)
            let versatz = UInt32(aus.count)
            aus.le32(0x0403_4B50)
            aus.le16(20); aus.le16(0x0800); aus.le16(0)
            aus.le16(0); aus.le16(0x21)
            aus.le32(crc)
            aus.le32(UInt32(e.daten.count)); aus.le32(UInt32(e.daten.count))
            aus.le16(UInt16(name.count)); aus.le16(0)
            aus.append(name); aus.append(e.daten)

            verzeichnis.le32(0x0201_4B50)
            verzeichnis.le16(20); verzeichnis.le16(20); verzeichnis.le16(0x0800); verzeichnis.le16(0)
            verzeichnis.le16(0); verzeichnis.le16(0x21)
            verzeichnis.le32(crc)
            verzeichnis.le32(UInt32(e.daten.count)); verzeichnis.le32(UInt32(e.daten.count))
            verzeichnis.le16(UInt16(name.count)); verzeichnis.le16(0); verzeichnis.le16(0)
            verzeichnis.le16(0); verzeichnis.le16(0); verzeichnis.le32(0)
            verzeichnis.le32(versatz)
            verzeichnis.append(name)
        }
        let beginn = UInt32(aus.count)
        aus.append(verzeichnis)
        aus.le32(0x0605_4B50)
        aus.le16(0); aus.le16(0)
        aus.le16(UInt16(eintraege.count)); aus.le16(UInt16(eintraege.count))
        aus.le32(UInt32(verzeichnis.count)); aus.le32(beginn)
        aus.le16(0)
        return aus
    }

    // MARK: Lesen

    /// Alle Einträge in der Reihenfolge des zentralen Verzeichnisses.
    /// Verzeichniseinträge (Pfad endet auf `/`) werden übergangen.
    public static func lesen(_ zip: Data) throws -> [Eintrag] {
        let z = Data(zip)
        guard z.count >= 22 else { throw Fehler.kaputt }
        var ende = z.count - 22
        let untergrenze = max(0, z.count - 22 - 65535)
        while ende >= untergrenze, z.u32(ende) != 0x0605_4B50 { ende -= 1 }
        guard ende >= untergrenze else { throw Fehler.kaputt }
        let anzahl = Int(z.u16(ende + 10))
        var p = Int(z.u32(ende + 16))
        guard anzahl != 0xFFFF, p <= ende else { throw Fehler.nichtUnterstuetzt }
        var aus: [Eintrag] = []
        for _ in 0..<anzahl {
            guard p + 46 <= z.count, z.u32(p) == 0x0201_4B50 else { throw Fehler.kaputt }
            let flags = z.u16(p + 8), methode = z.u16(p + 10)
            let crc = z.u32(p + 16)
            let gepackt = Int(z.u32(p + 20)), gross = Int(z.u32(p + 24))
            let nl = Int(z.u16(p + 28)), el = Int(z.u16(p + 30)), kl = Int(z.u16(p + 32))
            let lokal = Int(z.u32(p + 42))
            guard p + 46 + nl <= z.count else { throw Fehler.kaputt }
            let pfad = String(decoding: z[p + 46 ..< p + 46 + nl], as: UTF8.self)
            p += 46 + nl + el + kl
            if flags & 1 != 0 || methode != 0 || gepackt != gross { throw Fehler.nichtUnterstuetzt }
            guard lokal + 30 <= z.count, z.u32(lokal) == 0x0403_4B50 else { throw Fehler.kaputt }
            let start = lokal + 30 + Int(z.u16(lokal + 26)) + Int(z.u16(lokal + 28))
            guard start + gross <= z.count else { throw Fehler.kaputt }
            if pfad.hasSuffix("/") { continue }
            let daten = Data(z[start ..< start + gross])
            guard crc32(daten) == crc else { throw Fehler.pruefsummeFalsch(pfad) }
            aus.append(Eintrag(pfad: pfad, daten: daten))
        }
        return aus
    }

    /// Prüft, ob die Einträge eine NG-Sicherung sind: `manifest.json` zuerst,
    /// `app` = `awtrix-ng`, `backupFormat` = 1. Gibt `createdAt` zurück (falls da).
    @discardableResult
    public static func pruefen(_ eintraege: [Eintrag]) throws -> String? {
        guard let erster = eintraege.first, erster.pfad == "manifest.json",
              let json = try? JSONSerialization.jsonObject(with: erster.daten) as? [String: Any]
        else { throw Fehler.keineSicherung }
        guard json["app"] as? String == appKennung else { throw Fehler.fremdeSicherung }
        guard let f = json["backupFormat"] as? Int else { throw Fehler.keineSicherung }
        guard f == formatFassung else { throw Fehler.fassungUnbekannt(f) }
        return json["createdAt"] as? String
    }
}

private extension Data {
    mutating func le16(_ v: UInt16) { append(UInt8(v & 0xFF)); append(UInt8(v >> 8)) }
    mutating func le32(_ v: UInt32) { le16(UInt16(v & 0xFFFF)); le16(UInt16(v >> 16)) }
    func u16(_ i: Int) -> UInt16 { UInt16(self[startIndex + i]) | UInt16(self[startIndex + i + 1]) << 8 }
    func u32(_ i: Int) -> UInt32 { UInt32(u16(i)) | UInt32(u16(i + 2)) << 16 }
}
