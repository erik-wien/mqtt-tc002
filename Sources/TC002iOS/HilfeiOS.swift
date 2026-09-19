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
/// Seitenwechsel und Scrolltempo stehen auch hier — unter „Einstellungen“,
/// bei der Uhr, fuer die sie gelten.
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
                    .absatz("Auf dem Telefon stehen Adresse, Präfix und Geräteart in einer Zeile unter dem Namen. Die Geräteart stellt „Abfragen“ selbst fest; von Hand wählt man sie über das Kontextmenü der Zeile — ein langer Druck darauf."),

                    .ueberschrift("Entfernen"),
                    .absatz("„Entfernen“ in der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),

                    .ueberschrift("Einstellungen der Uhr selbst"),
                    .absatz("„Seitenwechsel“ und „Scrolltempo“ stehen unter „Einstellungen“ bei der angesehenen Uhr: Beides sind Einstellungen des Geräts. Der Seitenwechsel ist der Takt, in dem die Uhr durch alles blättert, was auf ihr steht; das Scrolltempo gilt nur ihren eigenen Anzeigen und wirkt auf Meldungen dieser App nicht."),

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
                + HilfeInhalt.verlaufHerkunft
                + HilfeInhalt.verlaufEntstehung
                + HilfeInhalt.verlaufLoeschen
                + [
                    .ueberschrift("Stehen oder laufen"),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text, gilt „Tempo“ aus dem Blatt „Format“, das der Pinsel in der Formatpille öffnet — langsam, mittel oder schnell. Unter der Vorschau steht dann, aus wie vielen Einzelbildern der Lauf besteht."),

                    .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                    .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Fassung stellt ihn nicht ein."),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [.ueberschrift("Löschen und Dauer")]
                + HilfeInhalt.papierkorb
                + [.absatz("Dasselbe tut ein Wischen nach links in der Liste unter den Blöcken.")]
                + HilfeInhalt.dauer
                + [.absatz("Die Dauer steht im Blatt „Format“ — dem Pinsel in der Formatpille, zusammen mit dem Weg und der Laufschrift. Den Seitenwechsel stellt diese Fassung nicht ein.")]
                + HilfeInhalt.zeichen
                + [
                    .absatz("Enthält der Text etwas anderes, lässt die Uhr es wortlos weg — diese Fassung warnt vorher nicht davor."),

                    .ueberschrift("Ein Bild schicken"),
                    .absatz("Das Bildsymbol in der Formatpille öffnet den Bestand der 52 × 16-Anzeigen — jener Bilder, die im Editor am Mac und am iPad entstehen und über iCloud hier ankommen. Eines wählen, „Senden“: Es geht an den Platz, der gerade gewählt ist, und ersetzt dort Text und Icon, denn eine Anzeige füllt das ganze Display."),
                    .absatz("Gemalt wird am Telefon nicht — ein Raster mit dem Finger wäre keine Arbeitsfläche. Schicken ist etwas anderes als malen. Eine AWTRIX NG nimmt so ein Bild nicht: Gemalt wird auf 52 × 16, ihre Anzeige ist 32 × 8; sie lehnt mit Begründung ab."),

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
                    .absatz("Ganz links in der Formatpille sitzt der Icon-Knopf: ohne Wahl ein Smiley, mit Wahl das gewählte Icon. Ein Druck öffnet ein Blatt mit Suchfeld, Filterleiste und Raster — die Leiste grenzt nach Größe (8 × 8 oder 16 × 16) und auf bewegte Icons ein; ein Antippen zeigt ein Icon groß — bei einem animierten auch laufend —, „Übernehmen“ wählt es. „Kein Icon“ ganz oben nimmt die Wahl zurück, „Abbrechen“ schließt ohne Änderung."),
                    .absatz("In der großen Ansicht steht rechts oben ein Menü mit „Umbenennen“ und „Löschen“. Der Name ist frei; die Nummer bleibt dabei, wie sie ist — ein Kurzbefehl, der sich auf sie beruft, findet das Icon weiterhin. Gelöscht wird endgültig, und nur, was hier liegt: Der mitgelieferte Grundschatz hat kein Menü."),
                    .absatz("Über dem Raster lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen; das Icon steht danach bei den eigenen. Gemalt wird hier nicht — eigene Icons entstehen am Mac und auf dem iPad, wo ein Editor daneben Platz hat. Zur Wahl stehen beide Größen: die 8×8-Icons und die eigenen 16×16, die am Schreibtisch entstehen und über iCloud hier ankommen."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Uhr wählen"),
                    .absatz("Ab zwei eingerichteten Uhren wird der Titel oben zum Menü: Es wählt, welche Uhr man **ansieht**. Ihr Name steht im Titel, und Vorschau, die fünf Blöcke und die Liste darunter zeigen ihren Stand. Über der Vorschau blättert man zur nächsten, wie zwischen zwei Seiten; die Punktreihe darunter sagt, die wievielte es ist."),
                    .absatz("**Wohin** gesendet wird, steht links oben: „Empfänger“ mit der Zahl der gewählten Uhren. Jede Uhr lässt sich dort einzeln an- und abwählen, dazu „Alle“ und „Nur die angesehene“. Das Ziel folgt dem Blick nicht — wer die angesehene Uhr wechselt, sendet weiter dorthin, wo er es eingestellt hat."),
                    .absatz("Eine Uhr, die nichts empfangen kann, wird beim Senden stillschweigend übersprungen: einer MQTT-Uhr fehlt dann das Präfix — dafür unter „Einstellungen“ „Abfragen“ antippen —, einer HTTP-Uhr die Adresse."),

                    .ueberschrift("Senden auslösen"),
                    .abbildung(.sendezeile),
                    .absatz("Wie in Nachrichten: Die Eingabetaste schickt die Anzeige, statt einen Zeilenumbruch einzufügen, und am rechten Rand des Feldes steht dafür ein blauer runder Knopf mit Pfeil. Bei leerem Textfeld oder während eine Sendung läuft, ist das Feld gesperrt. Geht dabei etwas schief — die Uhr nicht erreichbar, die Uhr weist die Anzeige ab, falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint oben eine Hinweisleiste mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert."),
                    .absatz("Was es heißt, wenn die Leiste ausbleibt, hängt an der Betriebsart: Bei einer HTTP-Uhr hat sie die Anzeige angenommen und sagt es auch. Bei einer MQTT-Uhr heißt es nur, dass die Nachricht beim Broker angekommen ist — was damit noch nicht gesagt ist, steht unter „Wenn nichts erscheint“."),
                ]
        case .anzeigen:
            return [
                    .absatz("Dieses Blatt ist die technische Mitschrift und sonst nichts. Was auf der Uhr liegt, steht in der Sendeansicht unter den fünf Blöcken."),
                    .absatz("Ist „Protokoll führen“ unter „Einstellungen“ ausgeschaltet — und das ist es ab Werk —, verschwindet auch das Symbol dafür: Ein Blatt, das nichts zeigt, braucht keinen Knopf."),
                ]
                + HilfeInhalt.protokollListe
                + HilfeInhalt.protokollLeeren
        case .kurzbefehle:
            return [
                .absatz("Die App bringt zwei Kurzbefehle mit: „Meldung schicken“ und „Meldung nehmen“. Beide stehen von selbst in der Kurzbefehle-App und lassen sich in einen eigenen Ablauf, in eine Automation oder auf einen Knopf legen; Siri kennt sie ebenfalls."),

                .ueberschrift("Meldung schicken"),
                .absatz("Verlangt wird allein der Text. Alles Weitere ist wahlfrei und steht in der Kurzbefehle-App unter den aufklappbaren Angaben: Uhr, Icon-Nummer, Dauer, Slot — und das ganze Format."),
                .absatz("„Bild an die Uhr schicken“ ist der dritte: Er nimmt den Namen einer 52 × 16-Anzeige aus dem Bestand und schickt sie an einen Platz. Von den Angaben oben gelten dort nur Uhr, Slot und Dauer — alles Übrige formatiert Text, den ein Bild nicht hat. Kennt er den Namen nicht, nennt die Rückfrage alle vorhandenen."),
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
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es auf einer Ulanzi-Werksfirmware nicht geben: Die App rastert dorthin jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht. Auf einer TC001 unter AWTRIX NG setzt die Uhr selbst — dort hängt es an ihrer Schrift."),
                ]
        }
    }
}
