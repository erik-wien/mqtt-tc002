import SwiftUI
import TC002Ansichten
import TC002Core

/// Die Bedienungshilfe der iPhone-Fassung. Eine Liste der Abschnitte, jeder
/// als eigene Seite — kein Fenster mit Seitenleiste, das gibt es hier nicht.
///
/// Die Darstellung (`HilfeabschnittView`) und alle Absätze, die auf beiden
/// Geräten gelten (`HilfeInhalt`), kommen aus `TC002Ansichten`. Hier steht
/// nur, was diese Oberfläche auszeichnet: Blätter, die Formatpille, die obere
/// Leiste — und was diese Fassung **nicht** hat. Eine wortgleiche Fassung der
/// Mac-Hilfe wäre streckenweise schlicht falsch: Weder Malbereich noch
/// Icon-Editor, weder Inspektor noch Finder gibt es auf dem Telefon, und
/// Seitenwechsel und Scrolltempo der Uhr stellt diese Fassung nicht ein.
struct HilfeiOS: View {
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List(Abschnitt.allCases) { a in
                NavigationLink(lok(a.rawValue)) {
                    ScrollView {
                        // Ohne Titel im Text: Die Navigationsleiste trägt ihn
                        // schon, zweimal derselbe Satz wäre nur Rauschen.
                        HilfeabschnittView(Hilfeabschnitt(a.rawValue, a.bausteine),
                                           zeigtTitel: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                    }
                    .navigationTitle(lok(a.rawValue))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }
}

private enum Abschnitt: String, CaseIterable, Identifiable {
    case ueberblick = "Was das Programm tut"
    case verbindung = "Einstellungen"
    case senden = "Senden"
    case anzeigen = "Verlauf"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return HilfeInhalt.wasEsTut
                + [
                    .absatz("Die Sendeansicht ist die ganze App: oben die Vorschau, darunter die fünf Plätze und die Dauer, unten die Formatpille und das Eingabefeld. „Verlauf“ und „Einstellungen“ gehen über die beiden Symbole rechts oben als Blatt auf."),
                    .absatz("Verweise auf die „Gerätereferenz“ meinen die Beschreibung der Uhr und ihres MQTT-Protokolls. Sie liegt der Mac-Fassung dieser App bei; in dieser Fassung ist sie nicht eingebaut."),
                ]
        case .verbindung:
            return HilfeInhalt.startOhneEinrichtung
                + [
                    .ueberschrift("Uhr hinzufügen"),
                    .absatz("Unter „Einstellungen“ trägt man im Feld „Adresse einer weiteren Uhr“ die Adresse einer Uhr ein und drückt „Hinzufügen“ oder die Eingabetaste. Eine bereits eingetragene Adresse lässt sich hier nicht ändern — dafür die Uhr entfernen und neu eintragen."),
                    .absatz("Beim ersten Zugriff auf Uhr oder Broker fragt iOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt. Zurücknehmen und wiedergeben lässt sich die Freigabe in der Einstellungen-App unter Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + [
                    .ueberschrift("Entfernen"),
                    .absatz("„Entfernen“ in der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),

                    .ueberschrift("Einstellungen der Uhr selbst"),
                    .absatz("Seitenwechsel und Scrolltempo der Uhr stellt diese Fassung nicht ein; beides sind Einstellungen des Geräts und betreffen nichts, was diese App sendet."),

                    .ueberschrift("Broker"),
                    .absatz("Unter „Broker“ stehen Adresse, Port, Benutzer und Kennwort."),
                ]
                + HilfeInhalt.brokerKennwort
                + [
                    .absatz("Gesichert wird es, sobald man die Eingabetaste drückt, „Sichern und prüfen“ drückt oder das Blatt schließt — nicht bei jedem Tastendruck."),
                ]
                + HilfeInhalt.brokerPruefen
        case .senden:
            return [.ueberschrift("Meldung und Platz")]
                + HilfeInhalt.fuenfPlaetze
                + HilfeInhalt.blockwissenAnfang
                + HilfeInhalt.blockwissenSchluss
                + [
                    .ueberschrift("Weg: als Pixel oder als Text"),
                    .absatz("Der Pinsel in der Formatpille öffnet das Blatt „Format“; oben darin steht die Wahl „Weg“ mit zwei Einträgen: „als Pixel“ (Vorgabe) und „als Text“."),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text beim Weg „als Pixel“, gilt „Tempo“ aus demselben Blatt — langsam, mittel oder schnell. Unter der Vorschau steht dann, aus wie vielen Einzelbildern der Lauf besteht."),
                    .absatz("Beim Weg „als Text“ rastert die App dagegen nichts — sie schickt den Text als eigenen Textblock, und die Uhr setzt ihn mit ihrer eingebauten Schrift (Gerätereferenz, §4.3). Passt er nicht aufs Display, läuft er von selbst durch, ohne dass die App dafür ein GIF bauen muss; wie schnell, ist eine Einstellung der Uhr, die diese Fassung nicht anbietet."),

                    .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                    .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Fassung stellt ihn nicht ein."),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [.ueberschrift("Löschen und Dauer")]
                + HilfeInhalt.papierkorb
                + [.absatz("Dasselbe tut unter „Verlauf“ ein Wischen nach links.")]
                + HilfeInhalt.dauer
                + HilfeInhalt.zeichen
                + [
                    .absatz("Enthält der Text etwas anderes, lässt die Uhr es wortlos weg — diese Fassung warnt vorher nicht davor."),

                    .ueberschrift("Formatpille"),
                    .absatz("Über dem Eingabefeld liegt die Formatpille mit elf Bedienelementen: Icon, waagrechte und senkrechte Ausrichtung, Farbe, der Pinsel für das Blatt „Format“, Schriftart, Größe, Fett, Großbuchstaben, Rand und Abstand. Sie passen nicht alle nebeneinander auf ein Telefon — die Pille lässt sich seitwärts schieben, und der Pfeil an ihrem rechten Rand zeigt an, solange dort noch etwas liegt."),
                ]
                + HilfeInhalt.schriftart
                + HilfeInhalt.groesse
                + HilfeInhalt.microFuenf
                + HilfeInhalt.fettUndGross
                + HilfeInhalt.randUndAbstand
                + HilfeInhalt.breiteUndAusrichtung
                + [
                    .ueberschrift("Icon wählen"),
                    .absatz("Ganz links in der Formatpille sitzt der Icon-Knopf: ohne Wahl ein Smiley, mit Wahl das gewählte Icon. Ein Druck öffnet ein Blatt mit Suchfeld und Raster; ein Antippen zeigt ein Icon groß — bei einem animierten auch laufend —, „Übernehmen“ wählt es. „Kein Icon“ ganz oben nimmt die Wahl zurück, „Abbrechen“ schließt ohne Änderung."),
                    .absatz("Über dem Raster lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen; das Icon steht danach bei den eigenen. Gemalt wird hier nicht — eigene Icons entstehen in der Mac-Fassung, ein 8×8-Raster mit dem Finger wäre keine Arbeitsfläche."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Uhr wählen"),
                    .absatz("Ab zwei eingerichteten Uhren wird der Titel oben zum Menü. Es wählt, welche Uhr man ansieht: Ihr Name steht im Titel, und die fünf Blöcke und der „Verlauf“ zeigen ihren Stand. Gesendet wird an dieselbe Uhr — am Telefon ist das eine Entscheidung und nicht zwei. Bei nur einer Uhr gibt es nichts zu wählen."),
                    .absatz("„An alle Uhren senden“ im selben Menü trennt beides wieder: Jede Sendung geht dann an alle eingerichteten Uhren, während Titel, Blöcke und „Verlauf“ bei der angesehenen bleiben — wie viele Uhren beliefert werden, sagt der Titel hinter ihrem Namen."),
                    .absatz("Eine Uhr ohne Präfix wird beim Senden stillschweigend übersprungen — sie kann erst empfangen, sobald sie unter „Einstellungen“ abgefragt wurde."),

                    .ueberschrift("Senden auslösen"),
                    .absatz("Der Pfeilknopf rechts neben dem Eingabefeld schickt die Anzeige; er ist gesperrt, solange das Textfeld leer ist oder eine Sendung läuft. Geht dabei etwas schief — falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint oben eine Hinweisleiste mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert. Bleibt sie aus, ist die Nachricht beim Broker angekommen — was das noch nicht heißt, steht unter „Wenn nichts erscheint“."),
                ]
        case .anzeigen:
            return HilfeInhalt.verlaufHerkunft
                + HilfeInhalt.verlaufEntstehung
                + [
                    .ueberschrift("Anzeigen und Löschen"),
                    .absatz("Ein Wischen nach rechts schaltet die Uhr auf diese Anzeige um, ein Wischen nach links entfernt sie mit einer leeren Nachricht von der aktiven Uhr."),
                ]
                + HilfeInhalt.verlaufLoeschen
                + HilfeInhalt.protokollListe
                + HilfeInhalt.protokollLeeren
        case .fehlersuche:
            return HilfeInhalt.fehlerStille
                + [
                    .absatz("Blieb nach dem Senden die Hinweisleiste oben aus, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter."),
                ]
                + HilfeInhalt.fehlerWelche
                + HilfeInhalt.fehlerReihe
                + [
                    .ueberschrift("Weitere Symptome"),
                    .absatz("Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind, steht ihr Seitenwechsel vermutlich auf „kein Wechsel“ — diese Fassung stellt ihn nicht ein."),
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es nur auf dem Weg „als Text“ geben. Beim Weg „als Pixel“ rastert die App jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht."),
                ]
        }
    }
}
