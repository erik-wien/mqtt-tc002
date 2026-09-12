import Foundation

/// Uebersetzt einen sichtbaren Text.
///
/// Der deutsche Wortlaut ist zugleich der Schluessel. Das hat zwei Gruende:
/// Der Quelltext bleibt lesbar — `lok("Die Uhr ist nicht erreichbar.")` sagt,
/// was dasteht, `lok("fehler.uhr.weg")` nicht —, und eine fehlende Uebersetzung
/// faellt auf den deutschen Satz zurueck statt auf einen Schluesselnamen.
///
/// SwiftUI braucht das hier nicht: Was als `LocalizedStringKey` ankommt —
/// `Text`, `Button`, `.help` und die anderen —, schlaegt es selbst nach. `lok`
/// ist fuer alles, was als gewoehnliches `String` weitergereicht wird: Fehler-
/// texte, Meldungen, die Hilfebausteine, das Kommandozeilenwerkzeug.
///
/// Nachgesehen wird im Buendel, in dem das Programm steckt (siehe
/// `Programmbuendel`) — in der App das App-Buendel, beim Werkzeug dasselbe,
/// weil es darin mitreist. In Tests gibt es dort nichts zu finden, und es
/// bleibt beim deutschen Wortlaut.
public func lok(_ deutsch: String) -> String {
    Programmbuendel.eigenes.localizedString(forKey: deutsch, value: deutsch, table: nil)
}

/// Wie `lok`, mit Platzhaltern. Im Schluessel stehen `%@` und `%d` — nicht die
/// Werte selbst, sonst waere jeder Text sein eigener Schluessel.
public func lokf(_ deutsch: String, _ argumente: CVarArg...) -> String {
    String(format: lok(deutsch), arguments: argumente)
}

/// Wie `lok`, aber mit einem eigenen Schluessel.
///
/// Fuer die wenigen Texte, die zu lang oder zu mehrzeilig sind, um selbst als
/// Schluessel zu taugen — der Hilfetext des Kommandozeilenwerkzeugs etwa.
/// `vorgabe` ist der deutsche Wortlaut und zugleich der Rueckfall, falls keine
/// Uebersetzung da ist.
public func lok(_ schluessel: String, vorgabe: String) -> String {
    Programmbuendel.eigenes.localizedString(forKey: schluessel, value: vorgabe, table: nil)
}
