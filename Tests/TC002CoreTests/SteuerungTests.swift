import XCTest
@testable import TC002Core

/// Die Nutzlasten und Prüfungen der Steuerung, ohne Gerät und ohne Netz
/// (`docs/awtrix-ng-protokoll.md` §3.2, §4.2, §10, §11.1).
final class SteuerungTests: XCTestCase {

    // MARK: - Moodlight

    func testMoodlightMitFarbeUndHelligkeit() throws {
        XCTAssertEqual(try Moodlight(farbe: "#ff8800", helligkeit: 200).json(),
                       ##"{"color":"#FF8800","brightness":200}"##)
    }

    func testMoodlightMitKelvin() throws {
        XCTAssertEqual(try Moodlight(kelvin: 2700).json(), #"{"kelvin":2700}"#)
    }

    /// Eine Helligkeit, die die Uhr nicht prüft (300 → 44, 256 → 0), prüft die App.
    func testMoodlightHelligkeitAusserhalbWirdAbgewiesen() {
        for h in [-1, 256, 300] {
            XCTAssertThrowsError(try Moodlight(helligkeit: h).json(), "\(h)") {
                XCTAssertEqual($0 as? SteuerungsFehler,
                               .ausserhalb(feld: "brightness", wert: String(h), bereich: "0–255"))
            }
        }
        XCTAssertNoThrow(try Moodlight(helligkeit: 0).json())
        XCTAssertNoThrow(try Moodlight(helligkeit: 255).json())
    }

    func testMoodlightKelvinGrenzen() {
        XCTAssertThrowsError(try Moodlight(kelvin: 999).json())
        XCTAssertThrowsError(try Moodlight(kelvin: 40001).json())
        XCTAssertNoThrow(try Moodlight(kelvin: 1000).json())
        XCTAssertNoThrow(try Moodlight(kelvin: 40000).json())
    }

    func testMoodlightOhneAngabeUndMitFarbeUndKelvin() {
        XCTAssertThrowsError(try Moodlight().json()) { XCTAssertEqual($0 as? SteuerungsFehler, .nichtsAngegeben) }
        XCTAssertThrowsError(try Moodlight(farbe: "#FFFFFF", kelvin: 3000).json()) {
            XCTAssertEqual($0 as? SteuerungsFehler, .farbeUndKelvin)
        }
        XCTAssertThrowsError(try Moodlight(farbe: "rot").json())
    }

    // MARK: - Anzeiger

    func testIndikatorNutzlastUndGrenzen() throws {
        XCTAssertEqual(try Indikator(nummer: 2, farbe: "#00ff00", blinkMs: 500, fadeMs: 250).json(),
                       ##"{"color":"#00FF00","blinkMs":500,"fadeMs":250}"##)
        XCTAssertNoThrow(try Indikator(nummer: 1, farbe: "#FF0000", blinkMs: 65535, fadeMs: 0).json())
        XCTAssertThrowsError(try Indikator(nummer: 1, farbe: "#FF0000", blinkMs: 65536).json())
        XCTAssertThrowsError(try Indikator(nummer: 1, farbe: "#FF0000", fadeMs: -1).json())
        for n in [0, 4] {
            XCTAssertThrowsError(try Indikator(nummer: n, farbe: "#FF0000").json()) {
                XCTAssertEqual($0 as? SteuerungsFehler, .ungueltigeKennziffer(n))
            }
        }
    }

    // MARK: - Einstellungen

    private var faehigkeiten: Geraetefaehigkeiten {
        Geraetefaehigkeiten(overlays: ["rain", "snow"], uebergaenge: ["Slide", "Rain"], zifferblaetter: ["sheet", "ring"])
    }

    private func wert(_ e: Geraeteeinstellung, _ w: JSONWert) throws -> String {
        var a = Einstellungsaenderung()
        try a.setzen(e, w, faehigkeiten: faehigkeiten)
        return try a.json()
    }

    func testEinstellungsBereiche() throws {
        XCTAssertEqual(try wert(.brightness, .zahl(255)), #"{"brightness":255}"#)
        XCTAssertThrowsError(try wert(.brightness, .zahl(256)))
        XCTAssertThrowsError(try wert(.brightness, .zahl(-1)))
        XCTAssertThrowsError(try wert(.brightness, .zahl(12.5)))
        XCTAssertThrowsError(try wert(.saturation, .zahl(101)))
        XCTAssertThrowsError(try wert(.volume, .zahl(101)))
        XCTAssertThrowsError(try wert(.alertVolume, .zahl(-1)))
        XCTAssertThrowsError(try wert(.gamma, .zahl(0)))
        XCTAssertEqual(try wert(.gamma, .zahl(2.2)), #"{"gamma":2.2}"#)
        XCTAssertThrowsError(try wert(.transitionDurationMs, .zahl(2147483648)))
        XCTAssertThrowsError(try wert(.appDurationMs, .zahl(-1)))
        XCTAssertThrowsError(try wert(.uppercase, .text("ja")))
    }

    func testFarbenGrossUndNullNurWoErlaubt() throws {
        XCTAssertEqual(try wert(.textColor, .text("#aabbcc")), ##"{"textColor":"#AABBCC"}"##)
        XCTAssertThrowsError(try wert(.textColor, .null), "textColor ist nie null")
        XCTAssertEqual(try wert(.timeColor, .null), #"{"timeColor":null}"#)
        XCTAssertThrowsError(try wert(.calendarBodyColor, .null))
        XCTAssertThrowsError(try wert(.textColor, .text("weiß")))
    }

    func testUebergangUndZifferblattGegenDieFaehigkeiten() throws {
        XCTAssertEqual(try wert(.transitionEffect, .text("rain")), #"{"transitionEffect":"Rain"}"#,
                       "Schreibweise der Liste der Uhr")
        XCTAssertThrowsError(try wert(.transitionEffect, .text("Gibtsnicht")))
        XCTAssertEqual(try wert(.clockFace, .text("ring")), #"{"clockFace":"ring"}"#)
        XCTAssertThrowsError(try wert(.clockFace, .text("big")), "die Uhr in diesem Test kennt nur sheet und ring")
        var ohne = Einstellungsaenderung()
        XCTAssertNoThrow(try ohne.setzen(.clockFace, .text("big")), "ohne Auskunft gelten die fünf der Doku")
        XCTAssertNoThrow(try ohne.setzen(.transitionEffect, .text("irgendwas")), "ohne Auskunft ungeprüft")
    }

    func testAuswahlenSindGenauSoGeschrieben() throws {
        XCTAssertNoThrow(try wert(.timeSeparatorMode, .text("blink")))
        XCTAssertThrowsError(try wert(.timeSeparatorMode, .text("Blink")))
        XCTAssertNoThrow(try wert(.dateOrder, .text("yearMonthDay")))
        XCTAssertThrowsError(try wert(.dateYearMode, .text("threeDigit")))
        XCTAssertNoThrow(try wert(.musicSource, .text("microphone")))
        XCTAssertNoThrow(try wert(.transitionDirection, .text("reverse")))
    }

    func testEnlargeAppsIstGesperrt() {
        var a = Einstellungsaenderung()
        XCTAssertThrowsError(try a.setzen(.enlargeApps, .bool(false))) {
            XCTAssertEqual($0 as? SteuerungsFehler, .gesperrteEinstellung("enlargeApps"))
        }
        XCTAssertTrue(a.istLeer)
        XCTAssertFalse(Geraeteeinstellung.enlargeApps.schreibbar)
        XCTAssertTrue(Geraeteeinstellung.allCases.filter { $0 != .enlargeApps }.allSatisfy(\.schreibbar))
    }

    /// Nichts, was laut Doku ohne Wirkung ist, und nichts aus der Systemkonfiguration.
    func testKeinSchluesselDerSystemkonfigurationOderOhneWirkung() {
        let namen = Set(Geraeteeinstellung.allCases.map(\.rawValue))
        for verboten in ["autoBrightness", "timeMode", "dateWeekdayBar", "useCelsius", "temperatureColor",
                         "humidityColor", "batteryColor", "wifiSsid", "wifiPass", "mqttHost", "mqttPass",
                         "mqttPrefix", "mqttTls", "mqttTlsPin", "authEnabled", "authPass", "hostname",
                         "webPort", "swapButtons", "buttonCallback", "tz", "ntpServer"] {
            XCTAssertFalse(namen.contains(verboten), verboten)
        }
    }

    func testJedeEinstellungHatEineGruppe() {
        for g in Einstellungsgruppe.allCases {
            XCTAssertFalse(Geraeteeinstellung.allCases.filter { $0.gruppe == g }.isEmpty, "\(g)")
        }
    }

    func testObjekteWerdenFeldweiseGeprueft() throws {
        var a = Einstellungsaenderung()
        try a.setzen(.scroll, .objekt(["mode": .text("bounce"), "speed": .zahl(150)]))
        XCTAssertThrowsError(try a.setzen(.scroll, .objekt(["mode": .text("zoom")])))
        XCTAssertThrowsError(try a.setzen(.scroll, .objekt(["speed": .zahl(-1)])))
        XCTAssertThrowsError(try a.setzen(.scroll, .objekt(["sped": .zahl(1)])))
        XCTAssertThrowsError(try a.setzen(.weekdayBar, .objekt(["weekendDays": .liste([.text("funday")])])))
        XCTAssertThrowsError(try a.setzen(.weekdayBar, .objekt(["activeColor": .null])), "Farben nie null")
        try a.setzen(.weekdayBar, .objekt(["weekendDays": .liste([.text("sunday")]), "show": .bool(false)]))
    }

    // MARK: - Lesen und Ändern aus Text

    private let gelesen = ##"""
    {"brightness":128,"saturation":100,"gamma":1.9,"textColor":"#FFFFFF","uppercase":true,"enlargeApps":true,
     "scroll":{"mode":"wrap","direction":"left","entry":"inline","whenFits":"static","speed":100,"gap":8,"holdMs":1000},
     "weekdayBar":{"show":true,"startOnMonday":true,"weekendDays":["sunday","saturday"],
       "activeColor":"#FFFFFF","inactiveColor":"#666666","weekendActiveColor":"#FFFFFF","weekendInactiveColor":"#666666"},
     "autoBrightness":false,"timeMode":1,"clockFace":"sheet","volume":100}
    """##

    func testGelesenWirdGegliedertUndTypisiert() throws {
        let e = try Geraeteeinstellungen(daten: Data(gelesen.utf8))
        XCTAssertEqual(e.schluesselinsgesamt, 12)
        XCTAssertEqual(e.ganzzahl(.brightness), 128)
        XCTAssertEqual(e.wahrheit(.uppercase), true)
        XCTAssertEqual(e.text(.clockFace), "sheet")
        XCTAssertEqual(e.lauftext?.speed, 100)
        XCTAssertEqual(e.lauftext?.mode, "wrap")
        XCTAssertEqual(e.wochentagsleiste?.weekendDays, ["sunday", "saturday"])
        XCTAssertEqual(e.wochentagsleiste?.inactiveColor, "#666666")
        XCTAssertNil(e[.volume].flatMap { _ in e.ganzzahl(.radioVolume) }, "nicht gemeldet bleibt nil")
        XCTAssertEqual(e.zeilen(in: .helligkeitFarbe).map(\.schluessel), ["brightness", "saturation", "gamma"])
        XCTAssertNil(e[.timeColor])
        XCTAssertThrowsError(try Geraeteeinstellungen(daten: Data("[1]".utf8)))
    }

    func testAenderungAusSchluesselUndWort() throws {
        let e = try Geraeteeinstellungen(daten: Data(gelesen.utf8))
        XCTAssertEqual(try e.aenderung(schluessel: "brightness", wert: "40").json(), #"{"brightness":40}"#)
        XCTAssertEqual(try e.aenderung(schluessel: "uppercase", wert: "aus").json(), #"{"uppercase":false}"#)
        XCTAssertEqual(try e.aenderung(schluessel: "gamma", wert: "2,2").json(), #"{"gamma":2.2}"#)
        XCTAssertEqual(try e.aenderung(schluessel: "timeColor", wert: "aus").json(), #"{"timeColor":null}"#)
        XCTAssertThrowsError(try e.aenderung(schluessel: "brightness", wert: "viel"))
        XCTAssertThrowsError(try e.aenderung(schluessel: "brightness", wert: "300"))
        XCTAssertThrowsError(try e.aenderung(schluessel: "wifiPass", wert: "x")) {
            XCTAssertEqual($0 as? SteuerungsFehler, .unbekannteEinstellung("wifiPass"))
        }
        XCTAssertThrowsError(try e.aenderung(schluessel: "enlargeApps", wert: "aus")) {
            XCTAssertEqual($0 as? SteuerungsFehler, .gesperrteEinstellung("enlargeApps"))
        }
    }

    /// Ein Unterfeld geht als ganzes Objekt hinaus, mit dem gelesenen Stand darunter.
    func testEinUnterfeldSendetDasGanzeObjekt() throws {
        let e = try Geraeteeinstellungen(daten: Data(gelesen.utf8))
        let json = try e.aenderung(schluessel: "scroll.speed", wert: "250").json()
        XCTAssertEqual(json, #"{"scroll":{"direction":"left","entry":"inline","gap":8,"holdMs":1000,"mode":"wrap","speed":250,"whenFits":"static"}}"#)
        let tage = try e.aenderung(schluessel: "weekdayBar.weekendDays", wert: "saturday,sunday").json()
        XCTAssertTrue(tage.contains(#""weekendDays":["saturday","sunday"]"#), tage)
        XCTAssertThrowsError(try e.aenderung(schluessel: "scroll.nix", wert: "1"))
        XCTAssertThrowsError(try e.aenderung(schluessel: "scroll", wert: "1"), "ein Objekt nur über seine Felder")
        XCTAssertThrowsError(try Geraeteeinstellungen().aenderung(schluessel: "scroll.speed", wert: "1"),
                             "ohne gelesenen Stand kein Objekt")
    }

    // MARK: - Zustand lesen

    func testGeraetezustand() throws {
        let json = ##"""
        {"version":"1.2.2","uid":"x","boardType":"tc002","wifiRssi":-26,"uptimeSeconds":4421,"brightness":128,
         "batteryPercent":73,"lowBattery":false,"matrixPower":true,"currentApp":"Time",
         "indicators":[{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0},{"on":true,"color":"#FF0000","blinkMs":5,"fadeMs":6},{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0}],
         "messageCount":2,
         "wifi":{"enabled":true,"state":"connected","error":null,"lastError":null,"attempts":0},
         "mqtt":{"enabled":true,"state":"offline","error":"timeout","lastError":"timeout","attempts":85},
         "usbPower":false}
        """##
        let z = try Geraetezustand(daten: Data(json.utf8))
        XCTAssertEqual(z.fassung, "1.2.2")
        XCTAssertEqual(z.platine, "tc002")
        XCTAssertEqual(z.wlanSignal, -26)
        XCTAssertEqual(z.helligkeit, 128)
        XCTAssertEqual(z.panelAn, true)
        XCTAssertEqual(z.aktiveAnzeige, "Time")
        XCTAssertEqual(z.indikatoren.count, 3)
        XCTAssertEqual(z.indikatoren[1], Indikatorstand(an: true, farbe: "#FF0000", blinkMs: 5, fadeMs: 6))
        XCTAssertEqual(z.batterieProzent, 73)
        XCTAssertEqual(z.nachrichten, 2)
        XCTAssertEqual(z.wlan?.verbunden, true)
        XCTAssertEqual(z.mqtt?.verbunden, false)
        XCTAssertEqual(z.mqtt?.fehler, "timeout")
        XCTAssertEqual(z.mqtt?.versuche, 85)
        XCTAssertThrowsError(try Geraetezustand(daten: Data("kaputt".utf8)))
    }

    /// Die Batterieschlüssel fehlen ganz, solange das Gerät keine Batterie meldet (§7.1).
    func testOhneBatterieBleibenDieFelderLeer() throws {
        let z = try Geraetezustand(daten: Data(#"{"version":"1.2.2","brightness":1}"#.utf8))
        XCTAssertNil(z.batterieProzent)
        XCTAssertNil(z.batterieSchwach)
        XCTAssertNil(z.usbStrom)
        XCTAssertNil(z.wlan)
    }

    func testAnzeigestandMitUndOhneMoodlight() throws {
        let aus = try Anzeigestand(daten: Data(#"{"power":true,"brightness":128,"overlay":null,"overlaySettings":{"speed":1,"palette":null,"blend":true},"moodlight":null}"#.utf8))
        XCTAssertEqual(aus, try Anzeigestand(daten: Data(#"{"power":true,"brightness":128,"overlay":"","moodlight":null}"#.utf8)))
        XCTAssertNil(aus.moodlight)
        XCTAssertNil(aus.overlay)
        let an = try Anzeigestand(daten: Data(##"{"power":false,"brightness":7,"overlay":"rain","moodlight":{"color":"#FFAA00","brightness":120}}"##.utf8))
        XCTAssertFalse(an.an)
        XCTAssertEqual(an.overlay, "rain")
        XCTAssertEqual(an.moodlight, Moodlightstand(farbe: "#FFAA00", helligkeit: 120))
        let gepackt = try Anzeigestand(daten: Data(#"{"power":true,"brightness":1,"moodlight":{"color":16755200,"brightness":5}}"#.utf8))
        XCTAssertEqual(gepackt.moodlight?.farbe, "#FFAA00")
    }

    // MARK: - Ereignisse

    func testUhrenereignisse() {
        let p = "wz/uhr"
        func lesen(_ thema: String, _ nutzlast: String) -> Uhrenereignis? {
            Uhrenereignis.lesen(thema: p + thema, nutzlast: Data(nutzlast.utf8), praefix: p)
        }
        XCTAssertEqual(lesen("/state/apps/active", "Time"), .aktiveAnzeige("Time"), "blanke Zeichenkette")
        XCTAssertNil(lesen("/state/apps/active", ""))
        XCTAssertEqual(lesen("/state/buttons/left", "1"), .taste(.links, gedrueckt: true))
        XCTAssertEqual(lesen("/state/buttons/select", "0"), .taste(.mitte, gedrueckt: false))
        XCTAssertEqual(lesen("/state/buttons/right", "1"), .taste(.rechts, gedrueckt: true))
        XCTAssertEqual(lesen("/state/buttons/knob", "1"), .taste(.knopf, gedrueckt: true))
        XCTAssertNil(lesen("/state/buttons/knob", "2"))
        XCTAssertNil(lesen("/state/buttons/mitte", "1"))
        XCTAssertEqual(lesen("/event/knob", #"{"turn":-3}"#), .drehknopf(-3))
        XCTAssertEqual(lesen("/event/knob", #"{"turn":2}"#), .drehknopf(2))
        XCTAssertNil(lesen("/event/knob", "kaputt"))
        XCTAssertEqual(lesen("/event/error", #"{"source":"http","request":"PATCH /api/v1/settings","error":{"code":"validationFailed","message":"x","field":"brightness"}}"#),
                       .fehler(Uhrenfehler(quelle: "http", anfrage: "PATCH /api/v1/settings",
                                           fehler: "validationFailed (brightness)")))
        XCTAssertEqual(lesen("/event/error", #"{"source":"mqtt","request":"cmd/x","error":"nope"}"#),
                       .fehler(Uhrenfehler(quelle: "mqtt", anfrage: "cmd/x", fehler: "nope")))
        if case .geraet(let z)? = lesen("/state/device", #"{"version":"1.2.2","currentApp":"Status"}"#) {
            XCTAssertEqual(z.aktiveAnzeige, "Status")
        } else { XCTFail("kein Gerätezustand") }
        if case .einstellungen(let e)? = lesen("/state/settings", #"{"brightness":9}"#) {
            XCTAssertEqual(e.ganzzahl(.brightness), 9)
        } else { XCTFail("keine Einstellungen") }
        XCTAssertNil(lesen("/state/audio", "{}"), "nicht abonniert")
        XCTAssertNil(Uhrenereignis.lesen(thema: "andere/state/apps/active", nutzlast: Data("x".utf8), praefix: p))
    }

    func testDieZustandsthemenSindEinzelnGenannt() {
        XCTAssertEqual(NGThema.zustandsthemen(praefix: "wz/uhr"),
                       ["wz/uhr/state/device", "wz/uhr/state/settings", "wz/uhr/state/apps/active",
                        "wz/uhr/state/buttons/+", "wz/uhr/event/knob", "wz/uhr/event/error"])
    }

    // MARK: - TLS

    func testTLSStatusNurGemessenerWert() throws {
        let s = try TLSStatus(daten: Data(#"{"ca":"public","pending":null}"#.utf8))
        XCTAssertEqual(s.ca, "public")
        XCTAssertNil(s.pending)
        XCTAssertTrue(s.oeffentlich)
        let t = try TLSStatus(daten: Data(#"{"ca":"custom","pending":"abc","fingerprint":"00"}"#.utf8))
        XCTAssertFalse(t.oeffentlich)
        XCTAssertEqual(t.pending, "abc")
        XCTAssertThrowsError(try TLSStatus(daten: Data("{}".utf8)))
    }

    func testZertifikatGrenzeUndForm() throws {
        let pem = "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n"
        XCTAssertNoThrow(try TLSZertifikat.pruefen(pem: pem))
        XCTAssertThrowsError(try TLSZertifikat.pruefen(pem: "nur Text"))
        XCTAssertThrowsError(try TLSZertifikat.pruefen(pem: "-----BEGIN CERTIFICATE-----\n" + String(repeating: "A", count: 70_000) + "\n-----END CERTIFICATE-----"))
        let kopf = "-----BEGIN CERTIFICATE-----\n", fuss = "\n-----END CERTIFICATE-----"
        let genau = kopf + String(repeating: "A", count: 65536 - kopf.utf8.count - fuss.utf8.count) + fuss
        XCTAssertEqual(genau.utf8.count, 65536)
        XCTAssertThrowsError(try TLSZertifikat.pruefen(pem: genau + "A"))
        XCTAssertNoThrow(try TLSZertifikat.pruefen(pem: genau))
    }
}
