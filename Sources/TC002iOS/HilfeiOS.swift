import SwiftUI
import TC002Ansichten
import TC002Core

/// Die Bedienungshilfe der iPhone-Fassung. Eine Liste der Abschnitte, jeder
/// als eigene Seite — kein Fenster mit Seitenleiste, das gibt es hier nicht.
///
/// Die Darstellung (`HilfeabschnittView`) und alle Absätze, die auf beiden
/// Geräten gelten (`HilfeInhalt`), kommen aus `TC002Ansichten`. Hier steht
/// nur, was diese Oberfläche auszeichnet: Blätter, die Formatpille, die obere
/// Leiste — und was diese Fassung nicht hat. Eine wortgleiche Fassung der
/// Mac-Hilfe wäre streckenweise schlicht falsch: Weder Malbereich noch
/// Icon-Editor, weder Inspektor noch Finder gibt es auf dem Telefon.
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
    case uhr = "Uhr"
    case anzeigen = "Protokoll"
    case kurzbefehle = "Kurzbefehle"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return HilfeInhalt.wasEsTut
                + [
                    .absatz("Die Sendeansicht ist die ganze App: oben die Vorschau, darunter die fünf Plätze und die Liste mit dem, was auf der Uhr liegt und zuletzt geschickt wurde, unten die Formatpille und das Eingabefeld. Links oben stehen die Empfänger, rechts oben die Einstellungen — und das Protokoll, solange es eingeschaltet ist."),
                    .absatz("Verweise auf die „Gerätereferenz“ meinen die Beschreibung der Uhr und ihres Protokolls — das Dokument zur Uhr. Sie liegt der Fassung für Mac und iPad bei; in dieser Fassung ist sie nicht eingebaut."),
                ]
        case .verbindung:
            return HilfeInhalt.themen
                + HilfeInhalt.startOhneEinrichtung
                + HilfeInhalt.uhrHinzufuegen
                + [
                    .absatz("Beim ersten Zugriff auf Uhr oder Broker fragt iOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt. Zurücknehmen und wiedergeben lässt sich die Freigabe in der Einstellungen-App unter Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + HilfeInhalt.betriebsart
                + HilfeInhalt.geraeteart
                + HilfeInhalt.uhrEntfernen
                + HilfeInhalt.brokerEintragen
                + HilfeInhalt.brokerNurFuerMqtt
                + HilfeInhalt.brokerFelderLeer
                + HilfeInhalt.brokerKennwort
                + HilfeInhalt.brokerSichern
                + HilfeInhalt.brokerPruefen
                + HilfeInhalt.virtuelleUhr
                + HilfeInhalt.wolkenabgleich
        case .senden:
            return [.ueberschrift("Meldung und Platz")]
                + HilfeInhalt.fuenfPlaetze
                + HilfeInhalt.blockwissenAnfang
                + HilfeInhalt.blockwissenSchluss
                + HilfeInhalt.verlaufHerkunft
                + HilfeInhalt.verlaufEntstehung
                + HilfeInhalt.verlaufLoeschen
                + [
                    .ueberschrift("Stehen oder laufen"),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text, gilt „Tempo“ aus dem Blatt „Zeit“, das die Uhr in der Formatpille öffnet — langsam, mittel oder schnell."),

                    .ueberschrift("Blockierende Anzeigen"),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [.ueberschrift("Löschen und Dauer")]
                + HilfeInhalt.blockLoeschen
                + [.absatz("Dasselbe tut ein Wischen nach links in der Liste unter den Blöcken.")]
                + HilfeInhalt.dauer
                + [.absatz("Die Dauer steht im Blatt „Zeit“ — der Uhr in der Formatpille, zusammen mit der Laufschrift.")]
                + HilfeInhalt.nachricht
                + HilfeInhalt.lebensdauer
                + [.absatz("Die Darstellung steht im Blatt „Darstellung“ — dem Pinsel in der Formatpille.")]
                + HilfeInhalt.darstellung
                + HilfeInhalt.zeichen
                + [
                    .absatz("Enthält der Text etwas anderes, lässt die Uhr es wortlos weg — diese Fassung warnt vorher nicht davor."),

                    .ueberschrift("Ein Bild schicken"),
                ]
                + HilfeInhalt.iconOderAnzeige
                + [
                    .absatz("Der Icon-Knopf in der Formatpille öffnet das Blatt „Icons“, und dort steht unter „52 × 16“ der Bestand der ganzen Anzeigen — jener Bilder, die im Editor am Mac und am iPad entstehen und über iCloud hier ankommen. Eine antippen führt auf ihre Seite: die Vorschau, darunter die fünf Plätze und „An Platz N senden“. Den Platz wählst du dort, auf der Seite des Bildes."),
                    .absatz("Gemalt wird am Telefon nicht — ein Raster mit dem Finger wäre keine Arbeitsfläche."),

                    .ueberschrift("Formatpille"),
                    .absatz("In der Pille über dem Eingabefeld steht links, was man am häufigsten ändert: Icon, Schrift, Größe, Fett, Großbuchstaben, Farbe. Dahinter die beiden Ausrichtungen, Rand und Abstand, und ganz hinten die Uhr für das Blatt „Zeit“ (Dauer, Lauftempo, mitlaufendes Icon) und der Pinsel für die Darstellung. Sie passen nicht alle nebeneinander auf ein Telefon: Wo die Pille am rechten Rand ausblendet, geht es weiter — dort schieben."),
                ]
                + HilfeInhalt.schriftart
                + HilfeInhalt.groesse
                + HilfeInhalt.microFuenf
                + HilfeInhalt.fettUndGross
                + HilfeInhalt.randUndAbstand
                + HilfeInhalt.breiteUndAusrichtung
                + [
                    .ueberschrift("Icons"),
                    .absatz("Ganz links in der Formatpille sitzt der Icon-Knopf: ohne Wahl ein Smiley, mit Wahl das gewählte Icon. Ein Druck öffnet das Blatt „Icons“ — die ganze Sammlung, nach Größe gruppiert: die 8 × 8-Icons, die eigenen 16 × 16 und die 52 × 16-Anzeigen. Darüber stehen ein Suchfeld und eine Filterleiste, die nach Größe und auf bewegte Einträge eingrenzt; „Zurücksetzen“ steht nur da, solange etwas eingeschränkt ist."),
                    .absatz("Ein Icon antippen zeigt es groß — bei einem animierten auch laufend —, „Übernehmen“ wählt es. „Kein Icon“ ganz oben nimmt die Wahl zurück, „Abbrechen“ schließt ohne Änderung."),
                    .absatz("In der großen Ansicht steht rechts oben ein Menü mit „Umbenennen“ und „Löschen“. Der Name ist frei; die Nummer bleibt dabei, wie sie ist — ein Kurzbefehl, der sich auf sie beruft, findet das Icon weiterhin. Gelöscht wird endgültig, und nur, was hier liegt: Der mitgelieferte Grundschatz hat kein Menü."),
                    .absatz("Ganz oben unter „Hinzufügen“ stehen zwei Wege: eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen, oder „Dateien …“ — eine GIF-, PNG- oder JPEG-Datei aus den Dateien. Sie landet im Bestand ihrer eigenen Größe; Kleineres wird mittig eingepasst, Größeres als die Anzeige abgelehnt, denn verkleinert wird nicht. Gemalt wird hier nicht — eigene Icons entstehen am Mac und auf dem iPad, wo ein Editor daneben Platz hat. Zu den Icons des Grundschatzes gibt es eigens gezeichnete 16×16-Varianten; sie liegen von Haus aus im 16×16-Bestand."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Uhr wählen"),
                    .absatz("Ab zwei eingerichteten Uhren wird der Titel oben zum Menü: Es wählt, welche Uhr man **ansieht**. Ihr Name steht im Titel, und Vorschau, die fünf Blöcke und die Liste darunter zeigen ihren Stand. Über der Vorschau blättert man zur nächsten, wie zwischen zwei Seiten; die Punktreihe darunter sagt, die wievielte es ist."),
                    .absatz("**Wohin** gesendet wird, steht links oben: „Empfänger“ mit der Zahl der gewählten Uhren. Jede Uhr lässt sich dort einzeln an- und abwählen, dazu „Alle“ und „Nur die angesehene“. Das Ziel folgt dem Blick nicht — wer die angesehene Uhr wechselt, sendet weiter dorthin, wo er es eingestellt hat."),
                    .absatz("Eine Uhr, die nichts empfangen kann, wird beim Senden stillschweigend übersprungen: einer MQTT-Uhr fehlt dann das Präfix — dafür unter „Einstellungen“ „Abfragen“ antippen —, einer HTTP-Uhr die Adresse."),

                    .ueberschrift("Senden auslösen"),
                    .abbildung(.sendezeile),
                    .absatz("Wie in Nachrichten: Rechts im Feld steht ein blauer runder Knopf mit Pfeil, sobald etwas darin steht. Während des Sendens weicht er einem Fortschrittsdreher; ist die Anzeige hinaus, wird er eine Sekunde lang grün und zeigt einen Haken — die Rückmeldung sitzt da, wo du getippt hast. Links daneben leert ein ⊗ das Feld. Die Eingabetaste der Bildschirmtastatur tut dasselbe, sie heißt dort „Senden“."),
                    .absatz("Solange die Sendung läuft, dreht sich rechts neben dem Feld ein Rädchen, und das Feld ist derweil gesperrt. Ist die Anzeige hinaus, steht dort eine Sekunde lang ein grüner Haken — sonst sagte nichts, dass etwas hinausging."),
                    .absatz("Geht etwas schief — die Uhr nicht erreichbar, die Uhr weist die Anzeige ab, falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint oben eine Hinweisleiste mit dem Grund. Bei mehreren Zieluhren steht dort eine Zeile je betroffener Uhr; die übrigen werden trotzdem beliefert."),
                    .absatz("Was es heißt, wenn die Leiste ausbleibt, hängt an der Betriebsart: Bei einer HTTP-Uhr hat sie die Anzeige angenommen und sagt es auch. Bei einer MQTT-Uhr heißt es nur, dass die Nachricht beim Broker angekommen ist — was damit noch nicht gesagt ist, steht unter „Wenn nichts erscheint“."),
                ]
        case .uhr:
            return [
                    .absatz("Der Name der angesehenen Uhr oben in der Sendeansicht ist ein Menü. „Steuerung …“ öffnet die Fernbedienung der Uhr als Blatt, „Einstellungen der Uhr …“ ihre Seite mit den gespeicherten Einstellungen; bei mehreren Uhren steht dort auch die Wahl der Uhr."),
                ]
                + HilfeInhalt.fernbedienung
                + HilfeInhalt.uhreinstellungen
        case .anzeigen:
            return [
                    .absatz("Dieses Blatt ist die technische Mitschrift und sonst nichts. Was auf der Uhr liegt, steht in der Sendeansicht unter den fünf Blöcken."),
                    .absatz("Ist „Protokoll führen“ unter „Einstellungen“ → „Aufzeichnung“ ausgeschaltet — und das ist es ab Werk —, verschwindet auch das Symbol dafür: Ein Blatt, das nichts zeigt, braucht keinen Knopf. Dort steht auch „Verlauf führen“ mitsamt „Verlauf löschen“."),
                ]
                + HilfeInhalt.protokollListe
                + HilfeInhalt.protokollLeeren
        case .kurzbefehle:
            return HilfeInhalt.kurzbefehle
        case .fehlersuche:
            return HilfeInhalt.fehlerStille
                + [
                    .absatz("Blieb nach dem Senden die Hinweisleiste oben aus, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter."),
                ]
                + HilfeInhalt.fehlerWelche
                + HilfeInhalt.fehlerReihe
                + [
                    .ueberschrift("Weitere Symptome"),
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, gibt es auf AWTRIX NG nicht: Ihre Schrift kennt sie; ein unbekanntes Zeichen wird zum Fragezeichen."),
                ]
        }
    }
}
