import Foundation
import Security

/// Das Broker-Kennwort gehoert nicht in die Einstellungsdatei.
public enum Schluesselbund {
    private static let dienst = Einstellungen.kennung

    private static func basis(_ konto: String, dienst: String = dienst) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: dienst,
         kSecAttrAccount as String: konto]
    }

    /// Gibt zurueck, ob der Eintrag wirklich im Schluesselbund steht. Ohne das
    /// faellt ein gescheitertes Schreiben erst beim naechsten Start auf — dann ist
    /// das Kennwort weg und niemand weiss, warum.
    /// Ein leerer Wert loescht nur: SecItemAdd nimmt keine leere Nutzlast an.
    ///
    /// Vorhandenes wird mit `SecItemUpdate` ueberschrieben und nie vorher
    /// geloescht; legt `SecItemAdd` danach nichts an, bleibt das alte Kennwort.
    /// Angelegt wird nur bei `errSecItemNotFound`. Neue Eintraege tragen
    /// `kSecAttrAccessibleAfterFirstUnlock`, damit ein Kurzbefehl auf dem
    /// gesperrten iPhone das Kennwort lesen kann; bestehende behalten ihre
    /// Klasse (sie bleiben lesbar, die Abfrage filtert nicht danach).
    @discardableResult
    public static func setzen(_ wert: String, fuer konto: String,
                              dienst: String = Einstellungen.kennung) -> Bool {
        guard !wert.isEmpty else { loeschen(konto, dienst: dienst); return true }
        let daten = Data(wert.utf8)
        let stand = SecItemUpdate(basis(konto, dienst: dienst) as CFDictionary,
                                  [kSecValueData as String: daten] as CFDictionary)
        if stand == errSecSuccess { return true }
        guard stand == errSecItemNotFound else { return false }
        var eintrag = basis(konto, dienst: dienst)
        eintrag[kSecValueData as String] = daten
        eintrag[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(eintrag as CFDictionary, nil) == errSecSuccess
    }

    /// `dienst` weicht nur ab, wenn ein anderes Programm als die App liest —
    /// das Kommandozeilenwerkzeug etwa, das den Eintrag der App braucht.
    public static func lesen(_ konto: String, dienst: String = Einstellungen.kennung) -> String? {
        var frage = basis(konto, dienst: dienst)
        frage[kSecReturnData as String] = true
        frage[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(frage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data else { return nil }
        return String(data: daten, encoding: .utf8)
    }

    /// Ob ein Eintrag da ist, **ohne** seinen Inhalt zu verlangen.
    ///
    /// Ohne `kSecReturnData` entschluesselt der Schluesselbund nichts und
    /// prueft deshalb auch keine Zugriffsliste — die Frage zieht keinen Dialog
    /// auf. Genau das wird gebraucht: Die Einstellungen sollen sagen koennen,
    /// dass ein Kennwort hinterlegt ist, ohne danach zu fragen.
    public static func vorhanden(_ konto: String,
                                 dienst: String = Einstellungen.kennung) -> Bool {
        var frage = basis(konto, dienst: dienst)
        frage[kSecReturnData as String] = false
        frage[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(frage as CFDictionary, nil) == errSecSuccess
    }

    public static func loeschen(_ konto: String, dienst: String = Einstellungen.kennung) {
        SecItemDelete(basis(konto, dienst: dienst) as CFDictionary)
    }
}

/// Damit `AppZustand` gegen einen Doppelgaenger geprueft werden kann — wie
/// `NachrichtSendend` beim Senden.
///
/// Ein Testlauf, der den echten Schluesselbund befragt, zieht auf dem Rechner
/// eines Menschen einen Dialog auf und hat das Brokerkennwort schon einmal im
/// Klartext in die Fehlerausgabe getragen. Werkzeug und Kurzbefehle bleiben
/// davon unberuehrt: dort ist der echte Zugriff der richtige.
public protocol Schluesselbundzugriff {
    func lesen(_ konto: String) -> String?
    @discardableResult
    func setzen(_ wert: String, fuer konto: String) -> Bool
    /// Ob ein Eintrag da ist, ohne seinen Inhalt zu verlangen — siehe
    /// `Schluesselbund.vorhanden`.
    func vorhanden(_ konto: String) -> Bool
}

/// Der Schluesselbund des Nutzers — die Vorgabe ueberall ausser in Tests.
public struct EchterSchluesselbund: Schluesselbundzugriff {
    public init() {}

    public func lesen(_ konto: String) -> String? {
        Schluesselbund.lesen(konto)
    }

    @discardableResult
    public func setzen(_ wert: String, fuer konto: String) -> Bool {
        Schluesselbund.setzen(wert, fuer: konto)
    }

    public func vorhanden(_ konto: String) -> Bool {
        Schluesselbund.vorhanden(konto)
    }
}
