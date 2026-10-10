import Foundation
import TC002Core

/// Die Namen der Einstellungen einer Uhr, wie die App sie zeigt. Die Schlüssel
/// der Uhr sind englisch und stehen als Pfad da (`scroll.speed`); jeder braucht
/// hier einen deutschen Titel, und `UhrgruppenTests` hält fest, dass keiner fehlt.
enum Uhrbeschriftung {
    static func titel(_ pfad: String) -> String {
        switch pfad {
        case "brightness": return lok("Helligkeit")
        case "autoBrightness": return lok("Automatisch")
        case "saturation": return lok("Sättigung")
        case "gamma": return lok("Gamma")
        case "colorCorrection": return lok("Farbkorrektur")
        case "colorTint": return lok("Farbton")
        case "textColor": return lok("Textfarbe")
        case "uppercase": return lok("Großbuchstaben")
        case "scroll.mode": return lok("Bewegung")
        case "scroll.direction": return lok("Richtung")
        case "scroll.entry": return lok("Einlauf")
        case "scroll.whenFits": return lok("Text, der passt")
        case "scroll.speed": return lok("Tempo")
        case "scroll.gap": return lok("Abstand")
        case "scroll.holdMs": return lok("Pause")
        case "autoTransition": return lok("Automatisch weiterblättern")
        case "appDurationMs": return lok("Anzeigedauer")
        case "transitionEffect": return lok("Übergang")
        case "transitionDirection": return lok("Richtung")
        case "transitionDurationMs": return lok("Dauer des Übergangs")
        case "clockFace": return lok("Zifferblatt")
        case "timeColor": return lok("Farbe der Uhrzeit")
        case "calendarHeaderColor": return lok("Kalenderkopf")
        case "calendarTextColor": return lok("Kalendertext")
        case "calendarBodyColor": return lok("Kalenderfläche")
        case "calendarAnimation": return lok("Kalender bewegt")
        case "time24h": return lok("24-Stunden-Anzeige")
        case "timeLeadingZero": return lok("Führende Null")
        case "timeShowSeconds": return lok("Sekunden")
        case "timeShowAmPm": return lok("AM/PM")
        case "timeSeparatorMode": return lok("Doppelpunkt")
        case "dateOrder": return lok("Reihenfolge")
        case "dateSeparator": return lok("Trenner")
        case "dateYearMode": return lok("Jahr")
        case "dateShowWeekday": return lok("Wochentag")
        case "dateMonthNames": return lok("Monatsname")
        case "dateColor": return lok("Farbe des Datums")
        case "weekdayBar.show": return lok("Anzeigen")
        case "weekdayBar.startOnMonday": return lok("Woche beginnt am Montag")
        case "weekdayBar.weekendDays": return lok("Wochenende")
        case "weekdayBar.activeColor": return lok("Tag aktiv")
        case "weekdayBar.inactiveColor": return lok("Tag inaktiv")
        case "weekdayBar.weekendActiveColor": return lok("Wochenende aktiv")
        case "weekdayBar.weekendInactiveColor": return lok("Wochenende inaktiv")
        case "volume": return lok("Gesamt")
        case "radioVolume": return lok("Radio")
        case "appVolume": return lok("Anzeigen-Klänge")
        case "alertVolume": return lok("Alarm")
        case "bootSound": return lok("Startklang")
        case "musicSource": return lok("Musikquelle")
        default: return pfad
        }
    }

    /// Der Name eines Wertes aus einer festen Liste (`dateOrder` → `dayMonthYear`).
    /// Ein Wert, den diese App nicht kennt, behält seinen Namen.
    static func wert(_ pfad: String, _ wert: String) -> String {
        switch (pfad, wert) {
        case ("scroll.mode", "static"): return lok("Fest")
        case ("scroll.mode", "wrap"): return lok("Durchlauf")
        case ("scroll.mode", "loop"): return lok("Endlos")
        case ("scroll.mode", "bounce"): return lok("Pendeln")
        case ("scroll.direction", "left"): return lok("Nach links")
        case ("scroll.direction", "right"): return lok("Nach rechts")
        case ("scroll.entry", "inline"): return lok("Vom Anker")
        case ("scroll.entry", "offscreen"): return lok("Von außen")
        case ("scroll.whenFits", "static"): return lok("Steht")
        case ("scroll.whenFits", "scroll"): return lok("Läuft trotzdem")
        case ("transitionDirection", "normal"): return lok("Vor")
        case ("transitionDirection", "reverse"): return lok("Zurück")
        case ("timeSeparatorMode", "steady"): return lok("Fest")
        case ("timeSeparatorMode", "blink"): return lok("Blinkt")
        case ("timeSeparatorMode", "pulse"): return lok("Pulsiert")
        case ("dateOrder", "dayMonthYear"): return lok("Tag Monat Jahr")
        case ("dateOrder", "monthDayYear"): return lok("Monat Tag Jahr")
        case ("dateOrder", "yearMonthDay"): return lok("Jahr Monat Tag")
        case ("dateSeparator", "dot"): return lok("Punkt")
        case ("dateSeparator", "slash"): return lok("Schrägstrich")
        case ("dateSeparator", "dash"): return lok("Strich")
        case ("dateYearMode", "none"): return lok("Ohne")
        case ("dateYearMode", "twoDigit"): return lok("2-stellig")
        case ("dateYearMode", "fourDigit"): return lok("4-stellig")
        case ("musicSource", "auto"): return lok("Automatisch")
        case ("musicSource", "playback"): return lok("Wiedergabe")
        case ("musicSource", "microphone"): return lok("Mikrofon")
        case ("clockFace", _): return Steuerwerte.zifferblattName(wert)
        default: return wert
        }
    }

    /// Die sieben Tage in der Reihenfolge der Uhr (`weekendDays`).
    static var wochentage: [(schluessel: String, name: String)] { [
        ("monday", lok("Montag")), ("tuesday", lok("Dienstag")), ("wednesday", lok("Mittwoch")),
        ("thursday", lok("Donnerstag")), ("friday", lok("Freitag")), ("saturday", lok("Samstag")),
        ("sunday", lok("Sonntag")),
    ] }
}
