import Foundation

/// Was eine Benachrichtigung von einer Anzeige unterscheidet
/// (`docs/awtrix-ng-protokoll.md` §5.6): Sie unterbricht die Schleife einmalig,
/// statt in sie einzutreten. Text, Icon und Standzeit kommen aus demselben
/// Rahmen wie bei der Anzeige.
///
/// `sound` (§5.6) steht in `klang`; es gehört nicht zum gespeicherten Format
/// (`CodingKeys`): Ein Ton wird je Sendung gewählt, nicht gemerkt.
public struct Benachrichtigungsoptionen: Equatable, Sendable, Codable {
    /// Nur darüber lässt sie sich zurückziehen; ohne Namen nur die sichtbare.
    public var name: String?
    /// Bleibt stehen, bis sie zurückgezogen wird; `durationMs` gilt dann nicht.
    public var halten: Bool
    /// `true` reiht hinter den bestehenden ein, `false` ersetzt die sichtbare.
    public var einreihen: Bool
    /// Erscheint auch bei ausgeschaltetem Panel, danach wird es wieder dunkel.
    public var aufwecken: Bool
    /// Wie oft laufender Text über das Bild zieht (`repeat`).
    public var wiederholungen: Int?
    /// Der Ton beim Erscheinen (1–4 Klänge, die Uhr spielt den ersten
    /// spielbaren); leer heißt stumm.
    public var klang: [Klang] = []

    private enum CodingKeys: String, CodingKey {
        case name, halten, einreihen, aufwecken, wiederholungen
    }

    /// Die Vorgaben dieser App weichen von denen der Uhr ab: Eine Nachricht
    /// bleibt nicht stehen (`halten` aus: gemessen hält `hold:true` die Warteschlange
    /// an, jede spätere Nachricht wartet hinter ihr, bis sie weggenommen wird),
    /// ersetzt die sichtbare (`einreihen` aus), weckt das Panel (`aufwecken`) und
    /// läuft zweimal durch (`wiederholungen`). Darum geht `stack:false` und
    /// `wakeup:true` ausdrücklich hinaus.
    public init(name: String? = nil, halten: Bool = false, einreihen: Bool = false,
                aufwecken: Bool = true, wiederholungen: Int? = 2, klang: [Klang] = []) {
        self.klang = klang
        self.name = name
        self.halten = halten
        self.einreihen = einreihen
        self.aufwecken = aufwecken
        self.wiederholungen = wiederholungen
    }

    /// `[A-Za-z0-9_-]{1,32}` wie bei Anzeigen (§8). `active` ist als Name
    /// reserviert, weil `DELETE /api/v1/notifications/active` die sichtbare meint.
    public static func nameGueltig(_ name: String) -> Bool {
        name != "active" && Anzeigenname.gueltig(name)
    }

    /// Die Felder, die über die Anzeige hinausgehen. Nur, was von der Vorgabe
    /// der Uhr abweicht: Die MQTT-Grenze liegt bei 8192 Byte, und `stack:true`,
    /// `hold:false`, `wakeup:false` sind dort ohnehin die Vorgabe.
    func felder(faehigkeiten: Geraetefaehigkeiten? = nil) throws -> [String] {
        var felder: [String] = []
        if let name {
            guard Self.nameGueltig(name) else { throw NGFehler.ungueltigerName(name) }
            felder.append(#""name":"\#(name)""#)
        }
        if halten { felder.append(#""hold":true"#) }
        if !einreihen { felder.append(#""stack":false"#) }
        if aufwecken { felder.append(#""wakeup":true"#) }
        if let wiederholungen { felder.append(#""repeat":\#(wiederholungen)"#) }
        if !klang.isEmpty {
            felder.append(#""sound":\#(try Klangbau.benachrichtigungston(klang, faehigkeiten: faehigkeiten))"#)
        }
        return felder
    }
}

/// Die Namensregel der Uhr für Anzeigen und Benachrichtigungen (§8).
public enum Anzeigenname {
    public static func gueltig(_ name: String) -> Bool {
        (1...32).contains(name.utf8.count)
            && name.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
                || ($0 >= 97 && $0 <= 122) || $0 == 95 || $0 == 45 }
    }
}

extension NGNutzlast {
    /// Die Benachrichtigung als JSON: dieselbe Nutzlast wie die Anzeige, ohne
    /// `lifetimeMs` (eine Benachrichtigung ignoriert es), dazu die Felder aus §5.6.
    public static func benachrichtigung(_ rahmen: Frame, _ o: Benachrichtigungsoptionen,
                                        faehigkeiten: Geraetefaehigkeiten? = nil,
                                        mass: Anzeigemass? = nil) throws -> String {
        ergaenzt(try Anzeigen.grundnutzlast(rahmen, faehigkeiten: faehigkeiten, mass: mass), um: try o.felder(faehigkeiten: faehigkeiten))
    }
}
