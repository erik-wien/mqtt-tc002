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
                "Links in der Seitenleiste liegen die fünf Bereiche: „Senden“ für Text und Icon, „Malen“ für ein frei gezeichnetes Bild, „Anzeigen“ für bereits verschickte Inhalte und die Seitenwechsel-Einstellung der Uhr, „Verbindung“ für Uhren und Broker, „Icons“ für eigene 8×8-Bildchen.",
                "Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern in `docs/tc002-protokoll.md`. Diese Hilfe beschreibt nur, was man in der App klickt.",
            ]
        case .verbindung:
            return [
                "Unter „Verbindung“ trägt man zuerst die Adresse einer Uhr ein (Feld „Adresse einer weiteren Uhr“, dann „Hinzufügen“) oder passt eine vorhandene an. Der Radioknopf links in der Zeile wählt, welche Uhr gerade das Ziel beim Senden ist — bei nur einer Uhr ist das ohne Bedeutung.",
                "„Abfragen“ holt von der Uhr selbst das Themen-Präfix und die MAC-Adresse und zeigt das Präfix monospaced in der Zeile an. Das Häkchen- oder Warndreieck-Symbol daneben sagt, ob die Uhr gerade beim Broker angemeldet ist — das ist aber nur die Anmeldung, keine Aussage darüber, ob die App auf das richtige Thema schreiben darf (mehr dazu unter „Wenn nichts erscheint“).",
                "Das Präfix lässt sich absichtlich nicht von Hand eintragen: es ist nicht dasselbe wie das in Ulanzi Studio eingestellte, die Firmware hängt die letzten vier Stellen der MAC-Adresse an. „Abfragen“ ermittelt das wirksame Präfix selbst. Hat die Uhr gar kein Präfix eingestellt, sagt „Abfragen“ das — statt ein Thema zu bilden, auf das sie nie hört.",
                "Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand und zeigt in der Zeile wieder „—“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“.",
                "„Entfernen“ am rechten Rand der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Anzeigen“ löschen.",
                "Darunter steht der Broker: Adresse, Port, Benutzer und Kennwort. Das Kennwort liegt im Schlüsselbund und nicht, wie die übrigen Felder, in den App-Einstellungen. Es wird gesichert, sobald man das Feld verlässt, die Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei jedem Tastendruck.",
            ]
        case .senden:
            return [
                "„Senden“ setzt aus Name, Text, Farbe und wahlweise einem Icon eine Anzeige zusammen und schickt sie an die Uhr. Der Name legt fest, unter welchem Bezeichner sie danach unter „Anzeigen“ auftaucht — dieselbe Anzeige erneut schicken ersetzt sie.",
                "Der Text wird nicht als Zeichenkette verschickt, sondern selbst in Pixel gerastert und als Zeichenflächen übertragen. Grund: Die eingebaute Schrift der Uhr kennt keine Umlaute und kaum Satzzeichen. Mit eigenem Rastern gehen „ä“, „ö“, „ü“ und „ß“ trotzdem, und die Vorschau links zeigt genau das Bild, das auch gesendet wird — sie entsteht aus demselben Pixelfeld.",
                "Passt der Text nicht in die verfügbare Breite, erscheint eine Warnung darunter; gesendet wird trotzdem, nur abgeschnitten. Das Display ist 52 Pixel breit, der Text beginnt aber eine Spalte vom Rand — ohne Icon bleiben also 51 Pixel, mit Icon 42, weil das Icon die ersten Spalten belegt. Rechts daneben lässt sich ein Icon aus der Sammlung wählen oder „ohne“.",
                "„an alle Uhren“ schickt dieselbe Anzeige gleichzeitig an jede eingerichtete Uhr, die bereits ein Präfix hat — nicht nur an die aktive. Der Schalter lässt sich erst ab zwei eingerichteten Uhren einschalten. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Verbindung“ eine Uhr einzutragen und abzufragen.",
                "Die Eingabetaste löst „Senden“ aus, solange der Knopf nicht gesperrt ist. Geht dabei etwas schief — falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint ein Hinweisfenster mit dem Grund; bei „an alle Uhren“ eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert. Bleibt das Fenster aus, ist die Nachricht beim Broker angekommen — was das noch nicht heißt, steht unter „Wenn nichts erscheint“.",
            ]
        case .malen:
            return [
                "„Malen“ ist eine 52×16-Fläche zum freien Zeichnen. Die Farbpunkte oben wählen die Farbe, „Radierer“ schaltet auf Löschen um, „Leeren“ macht die ganze Fläche leer. Gemalt wird mit gedrückter Maustaste.",
                "Name, „an alle“ und „Senden“ funktionieren wie unter „Senden“ — auch hier ersetzt ein erneutes Senden unter demselben Namen die vorherige Anzeige, auch hier löst die Eingabetaste das Senden aus, und auch hier ist der Knopf gesperrt, solange keine Uhr fertig eingerichtet ist; der Hinweis dazu steht darunter. Fehler beim Senden meldet dasselbe Hinweisfenster wie unter „Senden“.",
                "Der Hinweis unter der Malfläche zeigt, wie viele Rechtecke die Uhr am Ende bekommt: waagrechte Läufe gleicher Farbe werden vor dem Senden zu einem Rechteck zusammengefasst. Das ändert am Ergebnis nichts, nur an der Größe der Nachricht.",
            ]
        case .icons:
            return [
                "Der Bereich „Icons“ malt eigene 8×8-Bildchen, die danach unter „Senden“ neben dem Text zur Wahl stehen. Die Farbe wählt das unbeschriftete Farbfeld unter der Malfläche, „Radieren“ entfernt einzelne Pixel, „Alles löschen“ die ganze Fläche.",
                "„Sichern“ legt das gemalte Icon unter der eingetragenen „Nummer“ und dem „Name“ ab — die Nummer muss ausgefüllt sein, der Name ist frei; die Eingabetaste löst „Sichern“ aus. Rechts in „Vorhandene Icons“ stehen alle verfügbaren Icons; ein Klick lädt eines zurück in die Malfläche, das Kontextmenü bietet „Öffnen“ und „Löschen“.",
                "Ein zurückgeladenes Icon kommt schwarz als schwarz zurück, nicht als leeres Pixel. Beim Sichern wird „aus“ nämlich zu Schwarz — GIF trägt hier keine Durchsichtigkeit, und die Uhr hat ohnehin einen schwarzen Grund. Nach einem Rundlauf sind „aus“ und „schwarz gemalt“ deshalb dasselbe und nicht mehr auseinanderzuhalten.",
                "Mitgelieferte Icons liegen im App-Paket und lassen sich nicht löschen — ein Versuch meldet das. Selbst gemalte liegen unter `~/Library/Application Support/MQTT-TC002/Icons`.",
                "Über der Liste „Vorhandene Icons“ lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen — die Eingabetaste im Feld tut dasselbe. Das Icon landet danach bei den eigenen und steht unter „Senden“ zur Wahl. Eine unbekannte Nummer ergibt eine verständliche Meldung und macht sonst nichts kaputt.",
            ]
        case .anzeigen:
            return [
                "„Angelegte Anzeigen“ listet, was die App bei der aktiven Uhr selbst schon angelegt hat — nicht was die Uhr kennt, denn das verrät sie nicht. Die Liste stammt also aus der App, nicht vom Gerät, und sie wird je Uhr getrennt geführt: sie wechselt mit, wenn man unter „Verbindung“ eine andere Uhr zur aktiven macht.",
                "„Anzeigen“ schaltet auf den Namen um, „Löschen“ entfernt ihn mit leerer Nachricht von der aktiven Uhr und streicht ihn nur dort aus der Liste. Ging dieselbe Anzeige über „an alle“ auch an andere Uhren, steht sie dort weiter und muss bei jeder einzeln gelöscht werden. Eine stehende, gerade gezeigte Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder unter demselben Namen ersetzt wird — das ist der häufigste Grund, warum eine frisch gesendete Anzeige nicht auftaucht.",
                "„Seitenwechsel“ darunter liest und setzt die Standzeit je Seite direkt auf der aktiven Uhr, über HTTP statt über den Broker. Gelesen wird beim Öffnen des Bereichs, geschrieben erst, wenn man selbst etwas wählt — von sich aus ändert die App nichts am Gerät. Lässt sich der Wert nicht lesen, sagt das ein Hinweisfenster; der Picker behauptet dann nicht einfach „kein Wechsel“. „kein Wechsel“ bedeutet: die erste Anzeige bleibt stehen, egal was sonst ankommt.",
            ]
        case .fehlersuche:
            return [
                "MQTT in der hier verwendeten Version 3.1.1 meldet eine abgelehnte Veröffentlichung nicht zurück. Egal ob das Konto keine Schreibrechte auf das Thema hat oder niemand darauf lauscht: Die App bekommt kein Fehlersignal, keine Warnung — nichts unterscheidet das von einer erfolgreichen Sendung. Erscheint nichts auf der Uhr, ist das also kein Rätsel dieser App, sondern die normale Stille von MQTT 3.1.1.",
                "Alles bis zur Anmeldung am Broker meldet die App dagegen sehr wohl: falsches Kennwort, unerreichbarer Broker, Zeitüberschreitung, fehlende Zugangsdaten. Kam nach dem Senden kein Hinweisfenster, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter.",
                "Der Reihe nach nachsehen: Erstens das Präfix — unter „Verbindung“ „Abfragen“ noch einmal ausführen und mit dem tatsächlichen Präfix vergleichen; es ist nicht das in Ulanzi Studio eingetragene (siehe „Verbindung“). Zweitens, ob die Uhr überhaupt beim Broker angemeldet ist — das Häkchen- oder Warndreieck-Symbol in derselben Zeile.",
                "Drittens, ob das Broker-Konto auf dieses Thema schreiben darf. Das steht in der Rechtedatei des Brokers, nicht in dieser App, und lässt sich nur am Broker-Protokoll ablesen. Viertens, ob unter „Anzeigen“ noch eine alte, stehende Anzeige blockiert — die zuerst löschen oder unter demselben Namen ersetzen.",
                "Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind: „Seitenwechsel“ unter „Anzeigen“ steht vermutlich auf „kein Wechsel“. Fehlen einzelne Zeichen, betrifft das nur Text, der außerhalb dieser App direkt an die Uhr geschickt wurde — „Senden“ hier rastert Text selbst und kennt dieses Problem nicht.",
            ]
        }
    }
}
