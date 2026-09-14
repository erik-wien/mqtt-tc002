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
    case kurzbefehle = "Kurzbefehle"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return HilfeInhalt.wasEsTut
                + [
                    .absatz("Die Sendeansicht ist die ganze App: oben die Vorschau, darunter die fünf Plätze, unten die Formatpille und das Eingabefeld. „Verlauf“ und „Einstellungen“ gehen über die beiden Symbole rechts oben als Blatt auf."),
                    .absatz("Verweise auf die „Gerätereferenz“ meinen die Beschreibung der Uhr und ihres MQTT-Protokolls. Sie liegt der Mac-Fassung dieser App bei; in dieser Fassung ist sie nicht eingebaut."),
                ]
        case .verbindung:
            return HilfeInhalt.startOhneEinrichtung
                + [
                    .ueberschrift("Uhr hinzufügen"),
                    .absatz("Unter „Einstellungen“ trägt man die Adresse einer Uhr in das Feld unter der Liste ein, in dem eine Beispieladresse steht, und drückt „Hinzufügen“ oder die Eingabetaste. Eine bereits eingetragene Adresse lässt sich hier nicht ändern — dafür die Uhr entfernen und neu eintragen."),
                    .absatz("Beim ersten Zugriff auf Uhr oder Broker fragt iOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt. Zurücknehmen und wiedergeben lässt sich die Freigabe in der Einstellungen-App unter Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + HilfeInhalt.betriebsart
                + HilfeInhalt.geraeteart
                + [
                    .absatz("Auf dem Telefon steht die Wahl als Zweierschalter unter der Adresse der Uhr."),

                    .ueberschrift("Entfernen"),
                    .absatz("„Entfernen“ in der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),

                    .ueberschrift("Einstellungen der Uhr selbst"),
                    .absatz("Seitenwechsel und Scrolltempo der Uhr stellt diese Fassung nicht ein; beides sind Einstellungen des Geräts und betreffen nichts, was diese App sendet."),

                    .ueberschrift("Broker"),
                    .absatz("Unter „Broker“ stehen Adresse, Port, Benutzer und Kennwort."),
                ]
                + HilfeInhalt.brokerNurFuerMqtt
                + HilfeInhalt.brokerFelderLeer
                + HilfeInhalt.brokerKennwort
                + [
                    .absatz("Gesichert wird es, sobald man die Eingabetaste drückt, „Sichern und prüfen“ drückt oder das Blatt schließt — nicht bei jedem Tastendruck."),
                ]
                + HilfeInhalt.brokerPruefen
                + HilfeInhalt.virtuelleUhr
                + HilfeInhalt.wolkenabgleich
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
                + [.absatz("Die Dauer steht im Blatt „Format“ — dem Pinsel in der Formatpille, zusammen mit dem Weg und der Laufschrift. Den Seitenwechsel stellt diese Fassung nicht ein.")]
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
                    .absatz("In der großen Ansicht steht rechts oben ein Menü mit „Umbenennen“ und „Löschen“. Der Name ist frei; die Nummer bleibt dabei, wie sie ist — ein Kurzbefehl, der sich auf sie beruft, findet das Icon weiterhin. Gelöscht wird endgültig, und nur, was hier liegt: Der mitgelieferte Grundschatz hat kein Menü."),
                    .absatz("Über dem Raster lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen; das Icon steht danach bei den eigenen. Gemalt wird hier nicht — eigene Icons entstehen am Mac und auf dem iPad, wo ein Editor daneben Platz hat. Zur Wahl stehen beide Größen: die 8×8-Icons und die eigenen 16×16, die am Schreibtisch entstehen und über iCloud hier ankommen."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Uhr wählen"),
                    .absatz("Ab zwei eingerichteten Uhren wird der Titel oben zum Menü. Es wählt, welche Uhr man ansieht: Ihr Name steht im Titel, und die fünf Blöcke und der „Verlauf“ zeigen ihren Stand. Gesendet wird an dieselbe Uhr — am Telefon ist das eine Entscheidung und nicht zwei. Bei nur einer Uhr gibt es nichts zu wählen."),
                    .absatz("„An alle Uhren senden“ im selben Menü trennt beides wieder: Jede Sendung geht dann an alle eingerichteten Uhren, während Titel, Blöcke und „Verlauf“ bei der angesehenen bleiben — wie viele Uhren beliefert werden, sagt der Titel hinter ihrem Namen."),
                    .absatz("Eine Uhr, die nichts empfangen kann, wird beim Senden stillschweigend übersprungen: einer MQTT-Uhr fehlt dann das Präfix — dafür unter „Einstellungen“ „Abfragen“ antippen —, einer HTTP-Uhr die Adresse."),

                    .ueberschrift("Senden auslösen"),
                    .absatz("Der Pfeilknopf rechts neben dem Eingabefeld schickt die Anzeige; er ist gesperrt, solange das Textfeld leer ist oder eine Sendung läuft. Geht dabei etwas schief — die Uhr nicht erreichbar, die Uhr weist die Anzeige ab, falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint oben eine Hinweisleiste mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert."),
                    .absatz("Was es heißt, wenn die Leiste ausbleibt, hängt an der Betriebsart: Bei einer HTTP-Uhr hat sie die Anzeige angenommen und sagt es auch. Bei einer MQTT-Uhr heißt es nur, dass die Nachricht beim Broker angekommen ist — was damit noch nicht gesagt ist, steht unter „Wenn nichts erscheint“."),
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
        case .kurzbefehle:
            return [
                .absatz("Die App bringt zwei Kurzbefehle mit: „Meldung schicken“ und „Meldung nehmen“. Beide stehen von selbst in der Kurzbefehle-App und lassen sich in einen eigenen Ablauf, in eine Automation oder auf einen Knopf legen; Siri kennt sie ebenfalls."),

                .ueberschrift("Meldung schicken"),
                .absatz("Verlangt wird allein der Text. Alles Weitere ist wahlfrei und steht in der Kurzbefehle-App unter den aufklappbaren Angaben: Uhr, Icon-Nummer, Dauer, Slot — und das ganze Format."),
                .absatz("Was nicht angegeben ist, kommt aus dem, was zuletzt unter „Senden“ eingestellt war. Ein Kurzbefehl ohne Formatangaben schickt also genau das, was auch die App geschickt hätte; einer mit einer einzigen Angabe ändert genau diese eine."),

                .ueberschrift("Die Formatangaben"),
                .absatz("Weg, Schriftart, Farbe, die beiden Ausrichtungen und das Tempo sind Aufklappmenüs — vertippen kann man sich dort nicht. Fett, Großbuchstaben und „Icon mitscrollen“ sind Schalter, Rand und Abstand Zahlen von 0 bis 3. Alle haben dieselbe Wirkung wie die gleichnamigen Bedienelemente unter „Senden“; was dort ohne Wirkung bleibt — Fett bei einer Schrift ohne fetten Schnitt etwa —, bleibt es auch hier."),
                .absatz("Die Farbe ist eine Liste aus zehn Tönen, kein Farbrad: In einem Kurzbefehl bliebe nur ein Feld für einen Hexwert, und ein Tippfehler darin fiele niemandem auf. Wer einen anderen Ton braucht, stellt ihn in der App ein und gibt im Kurzbefehl keine Farbe an."),

                .ueberschrift("Größe im Kurzbefehl"),
                .absatz("Angeboten werden nur die Größen, die die App zu dieser Schriftart anbietet. Steht die verlangte nicht darauf, sendet der Kurzbefehl nicht, sondern fragt noch einmal und nennt die möglichen. Stillschweigend die nächstbeste zu nehmen hieße, etwas anderes zu senden, als im Kurzbefehl steht — und niemand sähe es."),
                .absatz("Wer nur die Schriftart wechselt und keine Größe angibt, bekommt die nächstgelegene ihrer Liste — genau wie beim Umschalten der Schriftart in der App."),

                .ueberschrift("Meldung nehmen"),
                .absatz("Nimmt einen der fünf Plätze wieder von der Uhr, wahlweise von einer bestimmten."),
                .absatz("Beide Kurzbefehle schreiben dasselbe Gedächtnis wie die App: Was ein Kurzbefehl auf einen der fünf Plätze geschickt hat, zeigt der Block unter „Senden“ auch nach einem Neustart, und ein Antippen holt die Regler zurück."),
                .absatz("Und beide folgen der Betriebsart, die für die Uhr eingestellt ist — es gibt dafür keine eigene Angabe im Kurzbefehl. Ein Werkzeug, das anders sendet als die App, wäre eine Falle: derselbe Platz, dieselbe Uhr, ein anderer Kanal, und niemand sähe es. Dasselbe gilt für das Kommandozeilenwerkzeug der Mac-Fassung."),
            ]
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
