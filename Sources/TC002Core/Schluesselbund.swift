import Foundation
import Security

/// Das Broker-Kennwort gehoert nicht in die Einstellungsdatei.
public enum Schluesselbund {
    private static let dienst = "cloud.eriks.mqtt-tc002"

    private static func basis(_ konto: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: dienst,
         kSecAttrAccount as String: konto]
    }

    public static func setzen(_ wert: String, fuer konto: String) {
        loeschen(konto)
        var eintrag = basis(konto)
        eintrag[kSecValueData as String] = Data(wert.utf8)
        SecItemAdd(eintrag as CFDictionary, nil)
    }

    public static func lesen(_ konto: String) -> String? {
        var frage = basis(konto)
        frage[kSecReturnData as String] = true
        frage[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(frage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data else { return nil }
        return String(data: daten, encoding: .utf8)
    }

    public static func loeschen(_ konto: String) {
        SecItemDelete(basis(konto) as CFDictionary)
    }
}
