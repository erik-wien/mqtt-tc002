import SwiftUI
import TC002Core

/// Die Bedienungshilfe der Mac-Fassung. Eigenes Fenster, Abschnitte links,
/// Text rechts. Die Darstellung (`HilfeabschnittView`) und die Absätze, die
/// auf beiden Geräten gelten (`HilfeInhalt`), liegen in `TC002Ansichten` —
/// hier steht nur, was diese Oberfläche auszeichnet: Fenster, Seitenleiste,
/// Menüs, Inspektor, Finder, Malen und der Icon-Editor.
///
/// Was das Gerät kann, steht in der Gerätereferenz (Hilfe -> Gerätereferenz,
/// aus docs/tc002-protokoll.md, siehe GeraeteReferenzView.swift); hier steht
/// nur, was man in der App klickt.
public struct HilfeView: View {
    @State private var abschnitt: Abschnitt? = .ueberblick

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(Abschnitt.allCases, selection: $abschnitt) { a in
                Text(lok(a.rawValue)).tag(a)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 260)
        } detail: {
            let a = abschnitt ?? .ueberblick
            ScrollView {
                HilfeabschnittView(Hilfeabschnitt(a.rawValue, a.bausteine))
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // Nur am Mac — siehe GeraeteReferenzView: 760 Punkte hat kein iPad
        // hochkant ausser dem 13-Zoll-Geraet.
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 540)
        #endif
    }
}

private enum Abschnitt: String, CaseIterable, Identifiable {
    case ueberblick = "Was das Programm tut"
    case verbindung = "Einstellungen"
    case senden = "Senden"
    case malen = "Malen"
    case icons = "Icons"
    case anzeigen = "Verlauf"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return HilfeInhalt.wasEsTut
                + [
                    .absatz("Nur für ein paar Abfragen und Einstellungen spricht die App eine Uhr selbst per HTTP an — das steht unten bei „Einstellungen“."),
                    .ueberschrift("Bereiche"),
                    .tabelle([
                        ("Senden", "Text und Icon verschicken"),
                        ("Malen", "ein frei gezeichnetes Bild verschicken"),
                        ("Verlauf", "bereits verschickte Inhalte und das Protokoll"),
                        ("Einstellungen", "Uhren, Broker sowie Seitenwechsel und Scrolltempo der aktiven Uhr"),
                        ("Icons", "eigene 8×8-Bildchen"),
                    ]),
                    .absatz("Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern unter „Hilfe → Gerätereferenz“. Diese Hilfe beschreibt nur, was man in der App klickt."),
                ]
        case .verbindung:
            return [
                    .ueberschrift("Uhr hinzufügen"),
                    .absatz("Unter „Einstellungen“ trägt man zuerst die Adresse einer Uhr ein (Feld „Adresse einer weiteren Uhr“, dann „Hinzufügen“ oder die Eingabetaste im Feld) oder passt eine vorhandene an. Der Radioknopf links in der Zeile wählt, welche Uhr gerade das Ziel beim Senden ist — bei nur einer Uhr ist das ohne Bedeutung."),
                    .absatz("Beim allerersten Start fragt macOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und die allererste „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt — einfach erlauben und erneut abfragen. Zurücknehmen lässt sich die Freigabe später unter Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + [
                    .absatz("Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand und zeigt in der Zeile wieder „—“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“."),
                    .ueberschrift("Entfernen"),
                    .absatz("„Entfernen“ am rechten Rand der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),
                    .ueberschrift("Einstellungen der aktiven Uhr"),
                    .punkte([
                        "„Seitenwechsel“: wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — „kein Wechsel“ bedeutet, die erste Anzeige bleibt stehen, egal was sonst ankommt.",
                        "„Scrolltempo“: wie schnell Text läuft, den die Uhr selbst setzt — eine Einstellung des Geräts, deren gültiger Wertebereich nicht dokumentiert ist.",
                    ]),
                    .absatz("Beide betreffen nichts, was diese App sendet: Sie rastert jeden Text selbst und bestimmt das Tempo einer Laufschrift unter „Senden“ eigenständig. Beides gilt immer für die gerade aktive Uhr — welche das ist, bestimmt der Radioknopf oben in der Liste."),
                    .absatz("Gelesen wird beim Öffnen des Bereichs direkt von der Uhr über HTTP, geschrieben erst, wenn man selbst etwas wählt; von sich aus ändert die App nichts am Gerät. Lässt sich ein Wert nicht lesen, sagt das ein Hinweisfenster statt stillschweigend einen falschen Stand zu zeigen."),
                    .ueberschrift("Broker"),
                    .absatz("Darunter steht der Broker: Adresse, Port, Benutzer und Kennwort."),
                ]
                + HilfeInhalt.brokerKennwort
                + [
                    .absatz("Gesichert wird es, sobald man das Feld verlässt, die Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei jedem Tastendruck."),
                ]
                + HilfeInhalt.brokerPruefen
        case .senden:
            return [
                    .ueberschrift("Meldung und Platz"),
                ]
                + HilfeInhalt.fuenfPlaetze
                + HilfeInhalt.blockwissenAnfang
                + [
                    .absatz("Für Gemaltes gilt das nicht: Ein gemaltes Bild hat keine Regler, es wird nicht gemerkt, und eine Sendung aus dem Malbereich wirft obendrein weg, was zu diesem Platz gemerkt war."),
                ]
                + HilfeInhalt.blockwissenSchluss
                + [
                    .ueberschrift("Weg: als Pixel oder als Text"),
                    .absatz("Über dem Textfeld liegt die Wahl „Weg“ mit zwei Einträgen: „als Pixel“ (Vorgabe) und „als Text“."),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text beim Weg „als Pixel“, erscheint über der Formatleiste eine Einstellung, die es sonst nicht gibt: „Tempo“ — langsam, mittel oder schnell. Darunter unter der Vorschau steht, wie viele Einzelbilder das ergibt und wie groß die Nutzlast wird."),
                    .absatz("Die Größe ist der Grund für die Angabe: Ein langer Text ergibt ein großes GIF, und wo die Grenze der Uhr liegt, weiß niemand (Gerätereferenz, §4.2a führt das als offene Frage). Wird es auffällig groß, sagt ein zusätzlicher Hinweis das."),
                    .absatz("Beim Weg „als Text“ rastert die App dagegen nichts — sie schickt den Text als eigenen Textblock, und die Uhr setzt ihn mit ihrer eingebauten Schrift (Gerätereferenz, §4.3). Dafür kann sie etwas, das „als Pixel“ nicht kann: Passt der Text nicht aufs Display, läuft er von selbst durch, ohne dass die App dafür ein GIF bauen muss — wie schnell, stellt „Scrolltempo“ unter „Einstellungen“ bei der aktiven Uhr ein (Gerätereferenz, §5.4). Eine Breitenwarnung gibt es hier deshalb nicht: Laufen ist auf diesem Weg der Normalfall, kein Fehler."),
                    .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                    .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Einstellung findet sich unter „Einstellungen“ bei der aktiven Uhr."),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [
                    .ueberschrift("Löschen und Dauer"),
                ]
                + HilfeInhalt.papierkorb
                + [
                    .absatz("Dasselbe tut unter „Verlauf“ der Knopf „Löschen“, nur dort, wo man den Platz gerade in der Hand hat. Im Malbereich sitzt er ebenso in der unteren Zeile neben den fünf Blöcken; „Leeren“ steht dagegen oben in der Werkzeugzeile. Die beiden meinen Verschiedenes: „Leeren“ macht die Malfläche leer, der Papierkorb löscht die Anzeige auf der Uhr."),
                ]
                + HilfeInhalt.dauer
                + HilfeInhalt.zeichen
                + [
                    .absatz("Enthält der Text etwas anderes, sagt die App das vor dem Senden: welche Zeichen betroffen sind, und dass „als Pixel“ sie kann. Ohne diese Warnung würde die Uhr die Zeichen wortlos weglassen."),
                    .ueberschrift("Formatleiste"),
                    .absatz("Oberhalb des Textfelds sitzt die Formatleiste, wie in einem Textprogramm: Schriftart, Größe, ein Fett- und ein Großbuchstaben-Knopf sowie zwei Gruppen aus je drei Symbolknöpfen für die waagrechte und die senkrechte Ausrichtung — welche Richtung ein Knopf setzt, sagt sein Einblendtext beim Verweilen mit der Maus."),
                    .absatz("Für den Weg „als Pixel“ gilt die ganze Leiste, auch für den laufenden Text: Er wird in derselben Phase gerastert wie der stehende, damit dieselbe Schrift nicht einmal dünner und einmal dicker aussieht; die waagrechte Ausrichtung wirkt sich beim laufenden Text naturgemäß nicht aus, die senkrechte schon."),
                ]
                + HilfeInhalt.schriftart
                + [
                    .absatz("Eine früher gewählte Schrift, die nicht mehr in dieser Auswahl steht, bleibt gesetzt und wählbar, abgesetzt unten in der Liste, bis man selbst etwas anderes wählt."),
                ]
                + HilfeInhalt.groesse
                + HilfeInhalt.microFuenf
                + HilfeInhalt.fettUndGross
                + HilfeInhalt.randUndAbstand
                + HilfeInhalt.breiteUndAusrichtung
                + [
                    .ueberschrift("Icon wählen"),
                    .absatz("Neben dem Textfeld steht ein Knopf, der ohne Wahl „Icon wählen…“ heißt und mit Wahl Vorschaubild und Namen des Icons zeigt — in beiden Fällen ein Druck, der ein Blatt mit Suchfeld und Raster öffnet, dazu ein Eintrag „ohne“, um die Wahl im Blatt loszuwerden, und „Schließen“ zum Beenden. Ist ein Icon gewählt, steht daneben ein kleiner Knopf zum Entfernen, ohne das Blatt erst öffnen zu müssen."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Sendeziel"),
                    .absatz("Rechts vom Sendeknopf steht ein Knopf, der das aktuelle Sendeziel nennt — etwa „an: Küche“, „an alle Uhren (3)“ oder „an 2 Uhren“. Ein Druck öffnet ein Blatt mit einer Zeile je eingerichteter Uhr: Name, Präfix und derselbe Verbindungsstand wie unter „Einstellungen“, dazu ein Haken zum An- und Abwählen; „Alle“ und „Keine“ wählen mit einem Klick, „Schließen“ beendet die Auswahl."),
                    .absatz("Eine Uhr ohne Präfix ist im Blatt als solche gekennzeichnet — sie kann erst empfangen, sobald sie unter „Einstellungen“ abgefragt wurde, und wird beim Senden stillschweigend übersprungen, solange das nicht geschehen ist. Ist nichts angehakt, geht die Sendung an die gerade aktive Uhr."),
                    .absatz("Dieser Knopf erscheint erst ab zwei eingerichteten Uhren; bei nur einer geht jede Sendung ohne weitere Wahl automatisch an sie. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Einstellungen“ eine Uhr einzutragen und abzufragen."),
                    .ueberschrift("Senden auslösen"),
                    .absatz("Die Eingabetaste löst „Senden“ aus, solange der Knopf nicht gesperrt ist. Geht dabei etwas schief — falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint ein Hinweisfenster mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert. Bleibt das Fenster aus, ist die Nachricht beim Broker angekommen — was das noch nicht heißt, steht unter „Wenn nichts erscheint“."),
                ]
        case .malen:
            return [
                    .ueberschrift("Zeichnen"),
                    .absatz("„Malen“ ist eine 52×16-Fläche zum freien Zeichnen. Der Systemfarbwähler oben links stellt die Farbe ein, „Radierer“ schaltet auf Löschen um, „Leeren“ macht die ganze Fläche leer. Gemalt wird mit gedrückter Maustaste."),
                    .absatz("Die Fläche passt ihre Kästchengröße dem Platz im Fenster an — in einem schmalen Fenster werden die Kästchen kleiner, statt dass die Fläche rechts abgeschnitten wird. Das zuletzt gemalte Bild bleibt über einen Neustart der App hinweg erhalten."),
                    .ueberschrift("Icon einfügen"),
                    .absatz("„Icon einfügen“ setzt eines der vorhandenen 8×8-Icons als Ausgangspunkt senkrecht mittig ins Feld — an derselben Stelle, an der es auch unter „Senden“ läge. Danach lässt sich frei weitermalen; durchsichtige Stellen im Icon lassen die Fläche dort unverändert."),
                    .ueberschrift("Bilder-Sammlung"),
                    .absatz("„Bilder“ öffnet die Sammlung mehrerer gesicherter 52×16-Bilder — anders als der eine Arbeitsstand, der ohnehin über Neustarts hinweg erhalten bleibt, sind das benannte Bilder zum Wiederverwenden. Ein Klick auf ein Bild lädt es ins Feld, mit Rückfrage, wenn die Fläche gerade nicht leer ist; „Löschen“ nimmt ein Bild wieder heraus."),
                    .absatz("Ein Name und „Sichern“ legen das aktuelle Feld ab — derselbe Name ersetzt das vorhandene Bild. Gesichert liegen sie unter `~/Library/Application Support/MQTT-TC002/Bilder`, erreichbar auch über „Ablage → Eigene Bilder im Finder zeigen“."),
                    .ueberschrift("Datei einlesen"),
                    .absatz("„Datei einlesen…“ im selben Blatt nimmt eine GIF-, PNG- oder JPEG-Datei in die Sammlung auf, auf 52×16 gerechnet, ohne Glättung. Danach folgt ein Feld für den Namen, mit dem Dateinamen als Vorschlag. Musste die Datei dafür umgerechnet werden, weil sie eine andere Größe hatte, steht das in der Meldung dazu. Ein animiertes GIF zählt hier nur mit seinem ersten Einzelbild — die Bildersammlung kennt, anders als die Icons, keine Animation."),
                    .ueberschrift("Senden"),
                    .absatz("Die fünf Slot-Blöcke stehen auch hier, mit denselben drei Zuständen und demselben Stand der aktiven Uhr wie unter „Senden“ — ein Antippen wählt hier aber nur den Platz: Regler, die sich wiederherstellen ließen, gibt es beim Malen nicht. Aus demselben Grund merkt sich die App ein gemaltes Bild nicht, und eine Sendung von hier wirft weg, was zu diesem Platz gemerkt war: Nach einem Neustart ohne Broker zeigt der Block dort „belegt“ ohne Inhalt — nicht mehr den Text, der vor dem Malen auf dem Platz stand."),
                    .absatz("„Dauer (Sek.)“, die Zielauswahl und „Senden“ funktionieren wie unter „Senden“ beschrieben — auch hier ersetzt ein erneutes Senden auf denselben Platz die vorherige Anzeige, und auch hier ist der Sendeknopf gesperrt, solange keine Uhr fertig eingerichtet ist; der Hinweis dazu steht darunter. Fehler beim Senden meldet dasselbe Hinweisfenster wie unter „Senden“."),
                    .absatz("Der Hinweis unter der Malfläche zeigt, wie viele Rechtecke die Uhr am Ende bekommt: waagrechte Läufe gleicher Farbe werden vor dem Senden zu einem Rechteck zusammengefasst. Das ändert am Ergebnis nichts, nur an der Größe der Nachricht."),
                ]
        case .icons:
            return [
                    .ueberschrift("Zeichnen"),
                    .absatz("Der Bereich „Icons“ malt eigene 8×8-Bildchen, die danach unter „Senden“ neben dem Text zur Wahl stehen. Der Systemfarbwähler „Farbe“ unter der Malfläche stellt die Farbe ein, „Radieren“ entfernt einzelne Pixel, „Alles löschen“ leert das gerade bearbeitete Einzelbild."),
                    .ueberschrift("Neu anfangen"),
                    .absatz("„Neu“ daneben setzt den ganzen Editor zurück, nicht nur das gerade bearbeitete Einzelbild: Malfläche, Bildleiste, „Nummer“ und „Name“ werden geleert und die Verzögerung auf ihren Anfangswert gestellt. Steht noch etwas Ungesichertes im Raster, fragt eine Rückfrage vorher nach, genau wie beim Löschen eines Icons."),
                    .ueberschrift("Mehrere Einzelbilder (Animation)"),
                    .absatz("Ein Icon kann aus mehreren Einzelbildern bestehen — das ergibt beim Sichern ein animiertes GIF. Die Leiste unter der Malfläche zeigt alle Einzelbilder, das gerade bearbeitete hervorgehoben; ein Klick auf eines schaltet die Malfläche darauf um."),
                    .absatz("„+“ hängt ein leeres Bild an, „Verdoppeln“ eine Kopie des aktuellen — das ist beim Zeichnen einer Bewegung meist der schnellste Weg. „Entfernen“ nimmt das aktuelle Bild wieder heraus und ist gesperrt, wenn nur noch eines übrig ist; die beiden Pfeile tauschen es mit dem Nachbarn."),
                    .absatz("„Verzögerung“ gilt für jedes Einzelbild gleich, in Sekunden. „Abspielen“ läuft die Leiste probeweise in Schleife durch, ohne dass vorher gesichert werden muss. Die Uhr spielt animierte GIFs ab, nicht nur deren erstes Einzelbild — am Gerät bestätigt (Hilfe → Gerätereferenz, §4.2)."),
                    .ueberschrift("Sichern und vorhandene Icons"),
                    .absatz("„Sichern“ legt das gemalte Icon — ein Einzelbild oder alle Bilder der Leiste — unter der eingetragenen „Nummer“ und dem „Name“ ab — die Nummer ist zugleich der Dateiname und muss deshalb eindeutig sein, der Name ist frei; die Eingabetaste löst „Sichern“ aus. Rechts in „Vorhandene Icons“ stehen alle verfügbaren Icons, durch das Suchfeld nach Name oder Nummer eingrenzbar; ein Klick lädt eines mit allen seinen Einzelbildern zurück in die Malfläche."),
                    .absatz("In der Zeile jedes Icons steht zusätzlich ein Papierkorb-Symbol zum Löschen, mit Rückfrage, die den Namen nennt; dasselbe bietet auch „Löschen“ im Kontextmenü der Zeile. War das gelöschte Icon gerade in die Malfläche geladen, bleibt das Bild dort stehen, nur „Nummer“ und „Name“ werden geleert — sonst würde ein erneutes „Sichern“ es unter demselben Namen wieder anlegen."),
                    .ueberschrift("Zurückladen und Transparenz"),
                    .absatz("„Aus“ und „schwarz gemalt“ sind zweierlei, auch nach dem Sichern: Ein ausgeschaltetes Pixel wird im GIF durchsichtig abgelegt, ein schwarz gemaltes deckend schwarz. Auf der Uhr sieht beides gleich aus, weil ihr Grund schwarz ist — im Editor kommt ein wieder geöffnetes Icon aber so zurück, wie es gemalt war. Dass „aus“ durchsichtig bleibt, ist nebenbei die Bedingung dafür, dass die Laufschrift auf der Uhr sauber läuft (Gerätereferenz, §4.2a)."),
                    .ueberschrift("Der Grundschatz"),
                    .absatz("Rund dreißig Icons liegen der App bei. Beim allerersten Start wandern sie einmalig in den eigenen Ordner — von da an sind es ganz normale eigene Icons: löschbar und überschreibbar wie jedes selbst gemalte oder von LaMetric geholte. Ein späterer Start holt sie nicht erneut, sonst käme ein zwischenzeitlich gelöschtes Icon wieder zurück."),
                    .absatz("Wer zu gründlich aufgeräumt hat, findet unter der Liste „Grundschatz wiederherstellen“: Es ergänzt nur, was im eigenen Ordner fehlt, und lässt Vorhandenes unangetastet — die Meldung danach nennt, wie viele Icons zurückkamen. Alle Icons, Grundschatz wie selbst angelegte, liegen unter `~/Library/Application Support/MQTT-TC002/Icons`, erreichbar auch über „Ablage → Eigene Icons im Finder zeigen“."),
                    .ueberschrift("Von LaMetric nachladen"),
                    .absatz("Über der Liste „Vorhandene Icons“ lässt sich außerdem eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen — die Eingabetaste im Feld tut dasselbe. Das Icon landet danach bei den eigenen und steht unter „Senden“ zur Wahl. Eine unbekannte Nummer ergibt eine verständliche Meldung und macht sonst nichts kaputt. Der Verweis „LaMetric Icon Gallery“ darüber öffnet die Übersicht im Browser, um erst eine passende Nummer herauszusuchen und dann hier einzutragen."),
                    .ueberschrift("Datei einlesen"),
                    .absatz("„Datei einlesen…“ daneben nimmt stattdessen eine GIF-, PNG- oder JPEG-Datei von der Platte auf, auf 8×8 gerechnet, ohne Glättung. Ein Blatt fragt danach nach Nummer und Name, mit dem Dateinamen als Vorschlag; wurde die Datei umgerechnet, weil sie eine andere Größe hatte, steht das in der Meldung nach dem Einlesen. Ein animiertes GIF behält dabei alle seine Einzelbilder, genau wie beim eigenen Malen mit mehreren Bildern."),
                ]
        case .anzeigen:
            return HilfeInhalt.verlaufHerkunft
                + [
                    .absatz("Je Uhr getrennt: die Liste wechselt mit, wenn man unter „Einstellungen“ eine andere Uhr zur aktiven macht."),
                ]
                + HilfeInhalt.verlaufEntstehung
                + [
                    .ueberschrift("Anzeigen und Löschen"),
                    .absatz("„Zeigen“ schaltet auf den Namen um, „Löschen“ entfernt ihn mit leerer Nachricht von der aktiven Uhr."),
                ]
                + HilfeInhalt.verlaufLoeschen
                + HilfeInhalt.protokollListe
                + [
                    .absatz("Dazu jede Änderung des Seitenwechsels."),
                ]
                + HilfeInhalt.protokollLeeren
                + [
                    .ueberschrift("Seitenwechsel"),
                    .absatz("Die Einstellung „Seitenwechsel“ — wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — findet sich nicht mehr hier, sondern unter „Einstellungen“ bei der jeweils aktiven Uhr, direkt neben der Liste der Uhren."),
                ]
        case .fehlersuche:
            return HilfeInhalt.fehlerStille
                + [
                    .absatz("Kam nach dem Senden kein Hinweisfenster, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter."),
                ]
                + HilfeInhalt.fehlerWelche
                + HilfeInhalt.fehlerReihe
                + [
                    .ueberschrift("Weitere Symptome"),
                    .absatz("Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind: „Seitenwechsel“ unter „Einstellungen“ steht vermutlich auf „kein Wechsel“."),
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es bei „Malen“ nicht geben und bei „Senden“ nur auf dem Weg „als Text“ — dort warnt die App vorher, welche Zeichen betroffen sind. Beim Weg „als Pixel“ rastert die App jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht."),
                ]
        }
    }
}
