import CryptoKit
import Foundation

/// Ein SHA-256-Fingerabdruck über mehrere Angaben, um Änderungen zu erkennen,
/// ohne sie im Klartext zu halten — etwa das Brokerkennwort in einem
/// Vergleichsfeld, das sonst in Speicherauszügen und Protokollen stünde.
///
/// Die Teile werden durch ein Zeichen getrennt, das in keinem vorkommt (NUL),
/// damit ("a", "bc") und ("ab", "c") verschieden bleiben.
public enum Fingerabdruck {
    public static func von(_ teile: [String]) -> String {
        let daten = Data(teile.joined(separator: "\u{0}").utf8)
        return SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
    }
}
