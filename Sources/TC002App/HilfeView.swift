import SwiftUI

/// Die Bedienungshilfe. Eigenes Fenster, Abschnitte links, Text rechts — reines
/// SwiftUI mit `Text`-Bausteinen, kein Markdown-Zerleger, kein Netzzugriff.
/// Was das Geraet kann, steht in `docs/tc002-protokoll.md`; hier steht nur, was
/// man in der App klickt.
struct HilfeView: View {
    @State private var abschnitt: Abschnitt? = .ueberblick

    var body: some View {
        NavigationSplitView {
            List(Abschnitt.allCases, selection: $abschnitt) { a in
                Text(a.rawValue).tag(a)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 260)
        } detail: {
            let a = abschnitt ?? .ueberblick
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(a.rawValue).font(.title2).fontWeight(.semibold)
                    ForEach(a.absaetze, id: \.self) { absatz in
                        Text(absatz)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

private enum Abschnitt: String, CaseIterable, Identifiable {
    case ueberblick = "Was das Programm tut"
    case verbindung = "Verbindung"
    case senden = "Senden"
    case malen = "Malen"
    case icons = "Icons"
    case anzeigen = "Anzeigen"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var absaetze: [String] {
        switch self {
        case .ueberblick:
            return [
                "MQTT-TC002 schickt Anzeigen an eine oder mehrere Ulanzi-TC002-Pixeluhren. Es tut das nicht direkt: alle Nachrichten laufen über den MQTT-Broker im Haus, an den auch die Uhren angeschlossen sind. Nur für ein paar Abfragen und Einstellungen spricht die App eine Uhr selbst per HTTP an — das steht jeweils unten bei „Verbindung“ und „Anzeigen“.",
                "Links in der Seitenleiste liegen die fünf Bereiche: „Senden“ für Text und Icon, „Malen“ für ein frei gezeichnetes Bild, „Anzeigen“ für bereits verschickte Inhalte und das Protokoll, „Verbindung“ für Uhren, Broker und die Seitenwechsel-Einstellung der aktiven Uhr, „Icons“ für eigene 8×8-Bildchen.",
                "Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern in `docs/tc002-protokoll.md`. Diese Hilfe beschreibt nur, was man in der App klickt.",
            ]
        case .verbindung:
            return [
                "Unter „Verbindung“ trägt man zuerst die Adresse einer Uhr ein (Feld „Adresse einer weiteren Uhr“, dann „Hinzufügen“ oder die Eingabetaste im Feld) oder passt eine vorhandene an. Der Radioknopf links in der Zeile wählt, welche Uhr gerade das Ziel beim Senden ist — bei nur einer Uhr ist das ohne Bedeutung.",
                "Beim allerersten Start fragt macOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und die allererste „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt — einfach erlauben und erneut abfragen. Zurücknehmen lässt sich die Freigabe später unter Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk.",
                "„Abfragen“ holt von der Uhr selbst das Themen-Präfix und die MAC-Adresse und zeigt das Präfix monospaced in der Zeile an. Das Häkchen- oder Warndreieck-Symbol daneben sagt, ob die Uhr gerade beim Broker angemeldet ist — das ist aber nur die Anmeldung, keine Aussage darüber, ob die App auf das richtige Thema schreiben darf (mehr dazu unter „Wenn nichts erscheint“).",
                "Das Präfix lässt sich absichtlich nicht von Hand eintragen: es ist nicht dasselbe wie das in Ulanzi Studio eingestellte, die Firmware hängt die letzten vier Stellen der MAC-Adresse an. „Abfragen“ ermittelt das wirksame Präfix selbst. Hat die Uhr gar kein Präfix eingestellt, sagt „Abfragen“ das — statt ein Thema zu bilden, auf das sie nie hört.",
                "Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand und zeigt in der Zeile wieder „—“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“.",
                "„Entfernen“ am rechten Rand der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Anzeigen“ löschen.",
                "Darunter steht „Einstellungen der aktiven Uhr“ mit dem Seitenwechsel: wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert. Das betrifft immer die gerade aktive Uhr — welche das ist, bestimmt der Radioknopf oben in der Liste. Gelesen wird beim Öffnen des Bereichs direkt von der Uhr über HTTP, geschrieben erst, wenn man selbst etwas wählt; von sich aus ändert die App nichts am Gerät. Lässt sich der Wert nicht lesen, sagt das ein Hinweisfenster; der Picker behauptet dann nicht einfach „kein Wechsel“. „kein Wechsel“ bedeutet: die erste Anzeige bleibt stehen, egal was sonst ankommt.",
                "Darunter steht der Broker: Adresse, Port, Benutzer und Kennwort. Das Kennwort liegt im Schlüsselbund und nicht, wie die übrigen Felder, in den App-Einstellungen. Es wird gesichert, sobald man das Feld verlässt, die Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei jedem Tastendruck.",
                "„Sichern und prüfen“ schreibt Adresse, Port, Benutzer und Kennwort ausdrücklich fest und fragt danach den Broker, ob er die Anmeldung annimmt — das dauert bis zu acht Sekunden und läuft unter einer eigenen Client-Kennung, damit dabei keine laufende Sendung hinausfliegt. „Der Broker nimmt die Anmeldung an“ heißt aber nur: Benutzername und Kennwort stimmen. Ob die Uhr die Nachricht am Ende auch zeigt, hängt zusätzlich vom richtigen Präfix und davon ab, ob das Konto auf das Thema schreiben darf — beides meldet MQTT 3.1.1 nicht zurück (siehe „Wenn nichts erscheint“). Das Ergebnis der Prüfung steht auch im Protokoll unter „Anzeigen“.",
            ]
        case .senden:
            return [
                "„Senden“ setzt aus Text, Farbe und wahlweise einem Icon eine Anzeige zusammen und schickt sie an die Uhr. „Meldung“ ①–⑤ wählt einen von fünf festen Plätzen — der gewählte Platz ist zugleich der Bezeichner, unter dem die Anzeige danach bei „Anzeigen“ auftaucht (`meldung1` bis `meldung5`). Auf denselben Platz senden ersetzt, was dort steht; ein anderer Platz tritt daneben, und die Uhr blättert zwischen den belegten Plätzen — ein orange umrandeter Platz ist bereits belegt, ein grau umrandeter frei. Das gilt für jede Zieluhr: ein Platz zählt schon als belegt, wenn ihn nur eine davon kennt.",
                "Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Einstellung findet sich unter „Verbindung“ bei der aktiven Uhr. Und egal wie viele Plätze belegt sind: Eine gerade angezeigte, stehende Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder ersetzt wird — deshalb ist „auf denselben Platz senden“ oft das, was man eigentlich will.",
                "„Dauer (Sek.)“ gibt der Uhr eine eigene Standzeit für diese eine Anzeige mit; leer oder 0 bedeutet keine Angabe, dann entscheidet allein der Seitenwechsel. Wie beides zusammenwirkt, ist nicht geklärt — ob die Dauer den Seitenwechsel für diese Anzeige überschreibt oder der kleinere Wert gewinnt, sagt die Herstellerdokumentation nicht (`docs/tc002-protokoll.md` §4.4).",
                "Der Text wird nicht als Zeichenkette verschickt, sondern selbst in Pixel gerastert und als Zeichenflächen übertragen. Grund: Die eingebaute Schrift der Uhr kennt keine Umlaute und kaum Satzzeichen. Mit eigenem Rastern gehen „ä“, „ö“, „ü“ und „ß“ trotzdem, und die Vorschau links zeigt genau das Bild, das auch gesendet wird — sie entsteht aus demselben Pixelfeld.",
                "Oberhalb des Textfelds sitzt die Formatleiste, wie in einem Textprogramm: Schriftart, Größe (6 bis 16 Pixel), ein Fett-Knopf sowie zwei Gruppen aus je drei Symbolknöpfen für die waagrechte und die senkrechte Ausrichtung — welche Richtung ein Knopf setzt, sagt sein Einblendtext beim Verweilen mit der Maus. Bei 16 Pixeln Displayhöhe eignen sich schmale, dicktengleiche Schriften am besten — die meisten proportionalen Schriften wirken bei dieser Größe eher wie ein Brei aus Pixeln. Die Uhr selbst kennt für ihre eigene Schrift Felder wie Ausrichtung und Zeilenhöhe (siehe `docs/tc002-protokoll.md` §4.3) — diese App benutzt sie nicht, weil sie den Text ja bereits selbst gerastert an die Uhr schickt und diese Felder nur für unrasterten Gerätetext gelten.",
                "Passt der Text nicht in die verfügbare Breite, erscheint eine Warnung darunter; gesendet wird trotzdem, nur abgeschnitten, und die Warnung berücksichtigt auch den fetten Schnitt. Ohne Icon ist die verfügbare Breite die vollen 52 Pixel des Displays, mit Icon 42, weil das Icon die ersten zehn Spalten belegt — die waagrechten Ausrichtungsknöpfe richten den Text innerhalb dieser Breite aus, die senkrechten innerhalb der 16 Zeilen, gerechnet über die tatsächlich gesetzte Höhe, nicht die Schriftgröße. Neben dem Textfeld steht ein Knopf, der das gewählte Icon mit Vorschaubild und Namen nennt, oder „kein Icon“; ein Druck öffnet ein Blatt mit Suchfeld und Raster, dazu ein Eintrag „ohne“, um die Wahl wieder loszuwerden, und „Schließen“ zum Beenden. Die Vorschau darunter zeigt ein gewähltes Icon an derselben Stelle mit, an der die Uhr es zeigt — so sieht man vor dem Senden, ob Icon und Text zusammenpassen.",
                "Rechts vom Sendeknopf steht ein Knopf, der das aktuelle Sendeziel nennt — etwa „an: Küche“, „an alle Uhren (3)“ oder „an 2 Uhren“. Ein Druck öffnet ein Blatt mit einer Zeile je eingerichteter Uhr: Name, Präfix und derselbe Verbindungsstand wie unter „Verbindung“, dazu ein Haken zum An- und Abwählen; „Alle“ und „Keine“ wählen mit einem Klick, „Schließen“ beendet die Auswahl. Eine Uhr ohne Präfix ist im Blatt als solche gekennzeichnet — sie kann erst empfangen, sobald sie unter „Verbindung“ abgefragt wurde, und wird beim Senden stillschweigend übersprungen, solange das nicht geschehen ist. Ist nichts angehakt, geht die Sendung an die gerade aktive Uhr. Dieser Knopf erscheint erst ab zwei eingerichteten Uhren; bei nur einer geht jede Sendung ohne weitere Wahl automatisch an sie. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Verbindung“ eine Uhr einzutragen und abzufragen.",
                "Die Eingabetaste löst „Senden“ aus, solange der Knopf nicht gesperrt ist. Geht dabei etwas schief — falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint ein Hinweisfenster mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert. Bleibt das Fenster aus, ist die Nachricht beim Broker angekommen — was das noch nicht heißt, steht unter „Wenn nichts erscheint“.",
            ]
        case .malen:
            return [
                "„Malen“ ist eine 52×16-Fläche zum freien Zeichnen. Der Systemfarbwähler oben links stellt die Farbe ein, „Radierer“ schaltet auf Löschen um, „Leeren“ macht die ganze Fläche leer. Gemalt wird mit gedrückter Maustaste. Die Fläche passt ihre Kästchengröße dem Platz im Fenster an — in einem schmalen Fenster werden die Kästchen kleiner, statt dass die Fläche rechts abgeschnitten wird. Das zuletzt gemalte Bild bleibt über einen Neustart der App hinweg erhalten.",
                "„Icon einfügen“ setzt eines der vorhandenen 8×8-Icons als Ausgangspunkt senkrecht mittig ins Feld — an derselben Stelle, an der es auch unter „Senden“ läge. Danach lässt sich frei weitermalen; durchsichtige Stellen im Icon lassen die Fläche dort unverändert.",
                "„Meldung“, „Dauer (Sek.)“, die Zielauswahl und „Senden“ funktionieren wie unter „Senden“ beschrieben — auch hier ersetzt ein erneutes Senden auf denselben Platz die vorherige Anzeige, und auch hier ist der Sendeknopf gesperrt, solange keine Uhr fertig eingerichtet ist; der Hinweis dazu steht darunter. Fehler beim Senden meldet dasselbe Hinweisfenster wie unter „Senden“.",
                "Der Hinweis unter der Malfläche zeigt, wie viele Rechtecke die Uhr am Ende bekommt: waagrechte Läufe gleicher Farbe werden vor dem Senden zu einem Rechteck zusammengefasst. Das ändert am Ergebnis nichts, nur an der Größe der Nachricht.",
            ]
        case .icons:
            return [
                "Der Bereich „Icons“ malt eigene 8×8-Bildchen, die danach unter „Senden“ neben dem Text zur Wahl stehen. Der Systemfarbwähler „Farbe“ unter der Malfläche stellt die Farbe ein, „Radieren“ entfernt einzelne Pixel, „Alles löschen“ leert das gerade bearbeitete Einzelbild.",
                "Ein Icon kann aus mehreren Einzelbildern bestehen — das ergibt beim Sichern ein animiertes GIF. Die Leiste unter der Malfläche zeigt alle Einzelbilder, das gerade bearbeitete hervorgehoben; ein Klick auf eines schaltet die Malfläche darauf um. „+“ hängt ein leeres Bild an, „Verdoppeln“ eine Kopie des aktuellen — das ist beim Zeichnen einer Bewegung meist der schnellste Weg. „Entfernen“ nimmt das aktuelle Bild wieder heraus und ist gesperrt, wenn nur noch eines übrig ist; die beiden Pfeile tauschen es mit dem Nachbarn. „Verzögerung“ gilt für jedes Einzelbild gleich, in Sekunden. „Abspielen“ läuft die Leiste probeweise in Schleife durch, ohne dass vorher gesichert werden muss. Die Uhr spielt animierte GIFs laut Herstellerrepository ab, nicht nur deren erstes Einzelbild — am Gerät selbst ist das noch nicht nachgeprüft (`docs/tc002-protokoll.md` §4.2).",
                "„Sichern“ legt das gemalte Icon — ein Einzelbild oder alle Bilder der Leiste — unter der eingetragenen „Nummer“ und dem „Name“ ab — die Nummer ist zugleich der Dateiname und muss deshalb eindeutig sein, der Name ist frei; die Eingabetaste löst „Sichern“ aus. Rechts in „Vorhandene Icons“ stehen alle verfügbaren Icons, durch das Suchfeld nach Name oder Nummer eingrenzbar; ein Klick lädt eines mit allen seinen Einzelbildern zurück in die Malfläche, das Kontextmenü bietet „Öffnen“ und „Löschen“.",
                "Ein zurückgeladenes Icon kommt schwarz als schwarz zurück, nicht als leeres Pixel. Beim Sichern wird „aus“ nämlich zu Schwarz — GIF trägt hier keine Durchsichtigkeit, und die Uhr hat ohnehin einen schwarzen Grund. Nach einem Rundlauf sind „aus“ und „schwarz gemalt“ deshalb dasselbe und nicht mehr auseinanderzuhalten.",
                "Mitgelieferte Icons liegen im App-Paket und lassen sich nicht löschen — ein Versuch meldet das. Selbst gemalte liegen unter `~/Library/Application Support/MQTT-TC002/Icons`.",
                "Über der Liste „Vorhandene Icons“ lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen — die Eingabetaste im Feld tut dasselbe. Das Icon landet danach bei den eigenen und steht unter „Senden“ zur Wahl. Eine unbekannte Nummer ergibt eine verständliche Meldung und macht sonst nichts kaputt. Der Verweis „LaMetric Icon Gallery“ darüber öffnet die Übersicht im Browser, um erst eine passende Nummer herauszusuchen und dann hier einzutragen.",
            ]
        case .anzeigen:
            return [
                "„Angelegte Anzeigen“ listet, was die App bei der aktiven Uhr selbst schon angelegt hat — nicht was die Uhr kennt, denn das verrät sie nicht. Die Liste stammt also aus der App, nicht vom Gerät, und sie wird je Uhr getrennt geführt: sie wechselt mit, wenn man unter „Verbindung“ eine andere Uhr zur aktiven macht.",
                "„Anzeigen“ schaltet auf den Namen um, „Löschen“ entfernt ihn mit leerer Nachricht von der aktiven Uhr und streicht ihn nur dort aus der Liste. Ging dieselbe Anzeige über die Zielauswahl auch an andere Uhren, steht sie dort weiter und muss bei jeder einzeln gelöscht werden. Eine stehende, gerade gezeigte Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder unter demselben Namen ersetzt wird — das ist der häufigste Grund, warum eine frisch gesendete Anzeige nicht auftaucht.",
                "Darunter steht das Protokoll: jede Abfrage einer Uhr, jedes Umschalten und Löschen einer Anzeige, jede Änderung des Seitenwechsels und jede Broker-Prüfung — mit Uhrzeit, älteste Zeile oben, neueste unten. „Leeren“ macht die Liste leer. Fehler erscheinen zusätzlich zum Hinweisfenster auch hier, damit sie nach dem Wegklicken nicht verloren sind.",
                "Die Einstellung „Seitenwechsel“ — wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — findet sich nicht mehr hier, sondern unter „Verbindung“ bei der jeweils aktiven Uhr, direkt neben der Liste der Uhren.",
            ]
        case .fehlersuche:
            return [
                "MQTT in der hier verwendeten Version 3.1.1 meldet eine abgelehnte Veröffentlichung nicht zurück. Egal ob das Konto keine Schreibrechte auf das Thema hat oder niemand darauf lauscht: Die App bekommt kein Fehlersignal, keine Warnung — nichts unterscheidet das von einer erfolgreichen Sendung. Erscheint nichts auf der Uhr, ist das also kein Rätsel dieser App, sondern die normale Stille von MQTT 3.1.1.",
                "Alles bis zur Anmeldung am Broker meldet die App dagegen sehr wohl: falsches Kennwort, unerreichbarer Broker, Zeitüberschreitung, fehlende Zugangsdaten. Kam nach dem Senden kein Hinweisfenster, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter.",
                "Der Reihe nach nachsehen: Erstens das Präfix — unter „Verbindung“ „Abfragen“ noch einmal ausführen und mit dem tatsächlichen Präfix vergleichen; es ist nicht das in Ulanzi Studio eingetragene (siehe „Verbindung“). Zweitens, ob die Uhr überhaupt beim Broker angemeldet ist — das Häkchen- oder Warndreieck-Symbol in derselben Zeile.",
                "Drittens, ob das Broker-Konto auf dieses Thema schreiben darf. Das steht in der Rechtedatei des Brokers, nicht in dieser App, und lässt sich nur am Broker-Protokoll ablesen. Viertens, ob unter „Anzeigen“ noch eine alte, stehende Anzeige blockiert — die zuerst löschen oder unter demselben Namen ersetzen.",
                "Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind: „Seitenwechsel“ unter „Verbindung“ steht vermutlich auf „kein Wechsel“. Fehlen einzelne Zeichen, betrifft das nur Text, der außerhalb dieser App direkt an die Uhr geschickt wurde — „Senden“ hier rastert Text selbst und kennt dieses Problem nicht.",
            ]
        }
    }
}
