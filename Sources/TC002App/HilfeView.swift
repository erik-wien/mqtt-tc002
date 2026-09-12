import SwiftUI

/// Die Bedienungshilfe. Eigenes Fenster, Abschnitte links, Text rechts — reines
/// SwiftUI mit `Text`-Bausteinen, kein Markdown-Zerleger, kein Netzzugriff.
/// Was das Geraet kann, steht in der Geraetereferenz (Hilfe -> Geraetereferenz,
/// aus docs/tc002-protokoll.md, siehe GeraeteReferenzView.swift); hier steht
/// nur, was man in der App klickt.
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
                    ForEach(Array(a.bausteine.enumerated()), id: \.offset) { _, baustein in
                        bausteinView(baustein)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    /// Baut einen einzelnen Hilfebaustein. Zwischenüberschriften bekommen
    /// zusätzliche Luft davor, Aufzählungen und Tabellen einen Einzug.
    @ViewBuilder
    private func bausteinView(_ baustein: Hilfebaustein) -> some View {
        switch baustein {
        case .ueberschrift(let text):
            Text(text)
                .font(.headline)
                .padding(.top, 10)
        case .absatz(let text):
            // `lineSpacing` ist ein Zuschlag, kein Faktor: Fuer den
            // ueblichen Zeilenabstand von 1,2 kommen also 0,2 der
            // Schriftgroesse obendrauf, nicht das 1,2-fache davon.
            Text(text).lineSpacing(NSFont.systemFontSize * 0.2)
        case .punkte(let eintraege):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(eintraege.enumerated()), id: \.offset) { _, eintrag in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(eintrag).lineSpacing(NSFont.systemFontSize * 0.2)
                    }
                }
            }
            .padding(.leading, 8)
        case .tabelle(let zeilen):
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                    GridRow {
                        Text(zeile.0).fontWeight(.semibold)
                        Text(zeile.1).lineSpacing(NSFont.systemFontSize * 0.2)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }
}

/// Ein Baustein eines Hilfeabschnitts: Fließtext, Zwischenüberschrift,
/// Aufzählung oder zweispaltige Tabelle (für Zuordnungen wie „Schrift → Größen“).
private enum Hilfebaustein {
    case ueberschrift(String)
    case absatz(String)
    case punkte([String])
    case tabelle([(String, String)])
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

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return [
                .absatz("MQTT-TC002 schickt Anzeigen an eine oder mehrere Ulanzi-TC002-Pixeluhren. Es tut das nicht direkt: alle Nachrichten laufen über den MQTT-Broker im Haus, an den auch die Uhren angeschlossen sind. Nur für ein paar Abfragen und Einstellungen spricht die App eine Uhr selbst per HTTP an — das steht jeweils unten bei „Verbindung“ und „Anzeigen“."),
                .ueberschrift("Bereiche"),
                .tabelle([
                    ("Senden", "Text und Icon verschicken"),
                    ("Malen", "ein frei gezeichnetes Bild verschicken"),
                    ("Anzeigen", "bereits verschickte Inhalte und das Protokoll"),
                    ("Verbindung", "Uhren, Broker sowie Seitenwechsel und Scrolltempo der aktiven Uhr"),
                    ("Icons", "eigene 8×8-Bildchen"),
                ]),
                .absatz("Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern unter „Hilfe → Gerätereferenz“. Diese Hilfe beschreibt nur, was man in der App klickt."),
            ]
        case .verbindung:
            return [
                .ueberschrift("Uhr hinzufügen"),
                .absatz("Unter „Verbindung“ trägt man zuerst die Adresse einer Uhr ein (Feld „Adresse einer weiteren Uhr“, dann „Hinzufügen“ oder die Eingabetaste im Feld) oder passt eine vorhandene an. Der Radioknopf links in der Zeile wählt, welche Uhr gerade das Ziel beim Senden ist — bei nur einer Uhr ist das ohne Bedeutung."),
                .absatz("Beim allerersten Start fragt macOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und die allererste „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt — einfach erlauben und erneut abfragen. Zurücknehmen lässt sich die Freigabe später unter Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk."),

                .ueberschrift("Abfragen"),
                .absatz("„Abfragen“ holt von der Uhr selbst das Themen-Präfix und die MAC-Adresse und zeigt das Präfix monospaced in der Zeile an. Das Häkchen- oder Warndreieck-Symbol daneben sagt, ob die Uhr gerade beim Broker angemeldet ist — das ist aber nur die Anmeldung, keine Aussage darüber, ob die App auf das richtige Thema schreiben darf (mehr dazu unter „Wenn nichts erscheint“)."),
                .absatz("Das Präfix lässt sich absichtlich nicht von Hand eintragen: es ist nicht dasselbe wie das in Ulanzi Studio eingestellte, die Firmware hängt die letzten vier Stellen der MAC-Adresse an. „Abfragen“ ermittelt das wirksame Präfix selbst. Hat die Uhr gar kein Präfix eingestellt, sagt „Abfragen“ das — statt ein Thema zu bilden, auf das sie nie hört."),
                .absatz("Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand und zeigt in der Zeile wieder „—“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“."),

                .ueberschrift("Entfernen"),
                .absatz("„Entfernen“ am rechten Rand der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Anzeigen“ löschen."),

                .ueberschrift("Einstellungen der aktiven Uhr"),
                .punkte([
                    "„Seitenwechsel“: wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — „kein Wechsel“ bedeutet, die erste Anzeige bleibt stehen, egal was sonst ankommt.",
                    "„Scrolltempo“: wie schnell Text läuft, den die Uhr selbst setzt — eine Einstellung des Geräts, deren gültiger Wertebereich nicht dokumentiert ist.",
                ]),
                .absatz("Beide betreffen nichts, was diese App sendet: Sie rastert jeden Text selbst und bestimmt das Tempo einer Laufschrift unter „Senden“ eigenständig. Beides gilt immer für die gerade aktive Uhr — welche das ist, bestimmt der Radioknopf oben in der Liste."),
                .absatz("Gelesen wird beim Öffnen des Bereichs direkt von der Uhr über HTTP, geschrieben erst, wenn man selbst etwas wählt; von sich aus ändert die App nichts am Gerät. Lässt sich ein Wert nicht lesen, sagt das ein Hinweisfenster statt stillschweigend einen falschen Stand zu zeigen."),

                .ueberschrift("Broker"),
                .absatz("Darunter steht der Broker: Adresse, Port, Benutzer und Kennwort. Das Kennwort liegt im Schlüsselbund und nicht, wie die übrigen Felder, in den App-Einstellungen. Es wird gesichert, sobald man das Feld verlässt, die Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei jedem Tastendruck."),
                .absatz("„Sichern und prüfen“ schreibt Adresse, Port, Benutzer und Kennwort ausdrücklich fest und fragt danach den Broker, ob er die Anmeldung annimmt — das dauert bis zu acht Sekunden und läuft unter einer eigenen Client-Kennung, damit dabei keine laufende Sendung hinausfliegt."),
                .absatz("„Der Broker nimmt die Anmeldung an“ heißt aber nur: Benutzername und Kennwort stimmen. Ob die Uhr die Nachricht am Ende auch zeigt, hängt zusätzlich vom richtigen Präfix und davon ab, ob das Konto auf das Thema schreiben darf — beides meldet MQTT 3.1.1 nicht zurück (siehe „Wenn nichts erscheint“). Das Ergebnis der Prüfung steht auch im Protokoll unter „Anzeigen“."),
            ]
        case .senden:
            return [
                .ueberschrift("Meldung und Platz"),
                .absatz("„Senden“ setzt aus Text, Farbe und wahlweise einem Icon eine Anzeige zusammen und schickt sie an die Uhr. „Meldung“ ①–⑤ wählt einen von fünf festen Plätzen — der gewählte Platz ist zugleich der Bezeichner, unter dem die Anzeige danach bei „Anzeigen“ auftaucht (`meldung1` bis `meldung5`)."),
                .absatz("Auf denselben Platz senden ersetzt, was dort steht; ein anderer Platz tritt daneben, und die Uhr blättert zwischen den belegten Plätzen — ein orange umrandeter Platz ist bereits belegt, ein grau umrandeter frei. Das gilt für jede Zieluhr: ein Platz zählt schon als belegt, wenn ihn nur eine davon kennt."),

                .ueberschrift("Weg: als Pixel oder als Text"),
                .absatz("Über dem Textfeld liegt die Wahl „Weg“ mit zwei Einträgen: „als Pixel“ (Vorgabe) und „als Text“. Bei „als Pixel“ entscheidet die App selbst, ob der Text stehenbleibt oder durchläuft — es gibt dafür keinen eigenen Schalter."),
                .tabelle([
                    ("als Pixel", "Umlaute und „ß“ gehen; die App entscheidet selbst — passt der Text, bleibt er stehen, sonst läuft er als GIF."),
                    ("als Text", "nur `%`, `.`, `-` und `:` als Sonderzeichen; läuft von selbst durch, wenn nötig, ohne dass die App ein GIF bauen muss."),
                ]),
                .absatz("Sie rechnet die Breite des gesetzten Textes ohnehin aus, und daran hängt die Regel: Passt er in die verfügbare Breite (52 Pixel, mit Icon 42), geht er als starres Pixelbild an die Uhr und bleibt stehen — klein, schnell, exakt. Passt er nicht, rastert die App den Lauf selbst und schickt ihn als animiertes GIF, das die Uhr abspielt (Gerätereferenz, §4.2a): Der Text läuft durch, mit Umlauten und in der gewählten Schriftart."),
                .absatz("Läuft der Text beim Weg „als Pixel“, erscheint über der Formatleiste eine Einstellung, die es sonst nicht gibt: „Tempo“ — langsam, mittel oder schnell. Darunter unter der Vorschau steht, wie viele Einzelbilder das ergibt und wie groß die Nutzlast wird."),
                .absatz("Die Größe ist der Grund für die Angabe: Ein langer Text ergibt ein großes GIF, und wo die Grenze der Uhr liegt, weiß niemand (Gerätereferenz, §4.2a führt das als offene Frage). Wird es auffällig groß, sagt ein zusätzlicher Hinweis das."),
                .absatz("Beim Weg „als Text“ rastert die App dagegen nichts — sie schickt den Text als eigenen Textblock, und die Uhr setzt ihn mit ihrer eingebauten Schrift (Gerätereferenz, §4.3). Dafür kann sie etwas, das „als Pixel“ nicht kann: Passt der Text nicht aufs Display, läuft er von selbst durch, ohne dass die App dafür ein GIF bauen muss — wie schnell, stellt „Scrolltempo“ unter „Verbindung“ bei der aktiven Uhr ein (Gerätereferenz, §5.4). Eine Breitenwarnung gibt es hier deshalb nicht: Laufen ist auf diesem Weg der Normalfall, kein Fehler."),

                .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Einstellung findet sich unter „Verbindung“ bei der aktiven Uhr. Und egal wie viele Plätze belegt sind: Eine gerade angezeigte, stehende Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder ersetzt wird — deshalb ist „auf denselben Platz senden“ oft das, was man eigentlich will."),

                .ueberschrift("Löschen und Dauer"),
                .absatz("Der Papierkorb rechts neben der Platzwahl löscht den gewählten Platz auf den gewählten Uhren — dasselbe, was unter „Anzeigen“ der Knopf „Löschen“ tut, nur dort, wo man den Platz gerade in der Hand hat. Er ist gesperrt, solange der Platz leer ist. Im Malbereich steht er neben „Leeren“, und die beiden meinen Verschiedenes: „Leeren“ macht die Malfläche leer, der Papierkorb löscht die Anzeige auf der Uhr."),
                .absatz("„Dauer (Sek.)“ gibt der Uhr eine eigene Standzeit für diese eine Anzeige mit; leer oder 0 bedeutet keine Angabe, dann entscheidet allein der Seitenwechsel. Wie beides zusammenwirkt, ist nicht geklärt — ob die Dauer den Seitenwechsel für diese Anzeige überschreibt oder der kleinere Wert gewinnt, sagt die Herstellerdokumentation nicht (Hilfe → Gerätereferenz, §4.4)."),

                .ueberschrift("Zeichen: Umlaute und Sonderzeichen"),
                .absatz("Beim Weg „als Pixel“ wird der Text nicht als Zeichenkette verschickt, sondern von der App selbst in Pixel gerastert — deshalb gehen dort auch „ä“, „ö“, „ü“ und „ß“, und die Vorschau zeigt genau das, was gesendet wird: stehend, wenn der Text steht, laufend, wenn er läuft."),
                .absatz("Beim Weg „als Text“ ist es umgekehrt: Die Uhr setzt den Text mit ihrer eigenen, eingebauten Schrift, und die kennt weder Umlaute noch die meisten Satzzeichen — nur `%`, `.`, `-` und `:` gehen (Gerätereferenz, §1). Enthält der Text etwas anderes, sagt die App das vor dem Senden: welche Zeichen betroffen sind, und dass „als Pixel“ sie kann. Ohne diese Warnung würde die Uhr die Zeichen wortlos weglassen."),

                .ueberschrift("Formatleiste"),
                .absatz("Oberhalb des Textfelds sitzt die Formatleiste, wie in einem Textprogramm: Schriftart, Größe (6 bis 16 Pixel), ein Fett- und ein Großbuchstaben-Knopf sowie zwei Gruppen aus je drei Symbolknöpfen für die waagrechte und die senkrechte Ausrichtung — welche Richtung ein Knopf setzt, sagt sein Einblendtext beim Verweilen mit der Maus."),
                .absatz("Für den Weg „als Pixel“ gilt die ganze Leiste, auch für den laufenden Text: Er wird in derselben Phase gerastert wie der stehende, damit dieselbe Schrift nicht einmal dünner und einmal dicker aussieht; die waagrechte Ausrichtung wirkt sich beim laufenden Text naturgemäß nicht aus, die senkrechte schon."),

                .ueberschrift("Schriftart"),
                .absatz("Bei „Schriftart“ stehen nicht alle installierten Schriften zur Wahl, sondern eine kurze, geprüfte Auswahl — bei 16 Pixeln Displayhöhe fällt kaum eine Schrift sauber aufs Raster, die meisten proportionalen Schriften wirken bei dieser Größe eher wie ein Brei aus Pixeln."),
                .absatz("Vorgabe ist „Silkscreen“, eine mitgelieferte, eigens fürs 8-Pixel-Raster gezeichnete Schrift — anders als die eingebaute Gerätschrift kann sie Umlaute und „ß“; dasselbe gilt für „Micro 5“ und „Tiny5“, zwei weitere mitgelieferte Pixelschriften. Die drei unterscheiden sich in der Wirkung:"),
                .punkte([
                    "„Micro 5“ ist die schmalste und bringt am meisten Text stehend aufs Display, ohne zu laufen.",
                    "„Silkscreen“ ist die klassische Pixeloptik, gut lesbar.",
                    "„Tiny5“ wirkt bei großer Größe kräftig und plakativ.",
                ]),
                .absatz("Eine früher gewählte Schrift, die nicht mehr in dieser Auswahl steht, bleibt gesetzt und wählbar, abgesetzt unten in der Liste, bis man selbst etwas anderes wählt."),

                .ueberschrift("Größe"),
                .tabelle([
                    ("Silkscreen", "nur 8 oder 16 Pixel"),
                    ("alle anderen Schriften", "der volle Bereich 6 bis 16 Pixel"),
                ]),
                .absatz("Der Grund: Eine Pixelschrift franst zwischen ihrer Entwurfsgröße und deren Vielfachen ohne Kantenglättung willkürlich aus — geprüft und dafür eingeschränkt ist deshalb nur Silkscreen. Micro 5 und Tiny5 waren eine Zeit lang ebenso eingeschränkt — das war voreilig verallgemeinert, geprüft war nur Silkscreen."),
                .absatz("Micro 5 trägt in Größe 12 nur acht Zeilen Tinte und wirkt dadurch verloren auf einem sechzehn Zeilen hohen Display; erst bei 16 füllt sie es."),

                .ueberschrift("Fett und Großbuchstaben"),
                .absatz("Beim Weg „als Text“ sind Schriftart und Fett ausgegraut, mit Einblendtext, warum: Die Uhr hat nur eine eingebaute Schrift und keinen fetten Schnitt, beides bliebe dort ohne Wirkung. Größe, Ausrichtung und Farbe wirken dort trotzdem weiter — sie gehen dann nicht mehr in unser Raster, sondern direkt als `fontHeight`, `align`, `valign` und `color` in den Textblock, den die Uhr selbst setzt (Gerätereferenz, §4.3)."),
                .absatz("Auch beim Weg „als Pixel“ kann „Fett“ ausgegraut sein, und zwar je nach Schrift: Die App rastert beim Wechsel einmal mit und einmal ohne fetten Schnitt und vergleicht — ändert sich nichts, hat die Schrift bei dieser Größe keinen, und ein Knopf ohne Wirkung ist schlimmer als keiner. Von den angebotenen Schriften trifft das auf die meisten zu; nur Menlo und PT Mono haben einen echten fetten Schnitt."),
                .absatz("Nach demselben Verfahren ist „Großbuchstaben“ bei Silkscreen gesperrt: Sie kennt überhaupt nur Versalien, der Schalter bliebe folgenlos."),
                .absatz("„Großbuchstaben“ gilt anders als Schriftart und Fett auf beiden Wegen gleich und lässt das Eingabefeld selbst unangetastet — umgewandelt wird erst beim Senden bzw. für die Vorschau. Auf dem Weg „als Text“ ist der Schalter mit Vorsicht zu genießen: Belegt ist bisher nur, dass die Gerätschrift Kleinbuchstaben und Ziffern kennt — ob sie auch Versalien zeigt, hat noch niemand nachgesehen (Gerätereferenz, §1). Aus „ß“ wird dabei „SS“, „Ä“, „Ö“ und „Ü“ bleiben Umlaute und fehlen dort in jedem Fall."),

                .ueberschrift("Rand"),
                .absatz("„Rand“, 0 bis 3, Vorgabe 1: die Zahl Zeilen, die bei „oben“ und „unten“ frei bleiben — bei „mittig“ ist er gesperrt, dort hat er keinen Sinn."),
                .absatz("Ihn braucht es, weil bündig je nach Schrift verschieden aussieht: Manche bringen über der Großbuchstabenhöhe Platz mit, andere nicht, und dieselbe Ausrichtung wirkt dann bei der einen luftig und bei der anderen gequetscht. Der Rand macht den Eindruck davon unabhängig und ist auf den vorhandenen Platz gedeckelt — ein Text, der schon fast die volle Höhe füllt, wird nicht beschnitten."),

                .ueberschrift("Abstand"),
                .absatz("Ganz rechts liegt „Abstand“, 0 bis 3, Vorgabe 1 — anders als Großbuchstaben nur beim Weg „als Pixel“ wirksam."),
                .absatz("„Abstand“ ist wörtlich die Zahl leerer Spalten zwischen zwei Zeichen — 0 heißt Tinte an Tinte, 1 die Vorgabe, 2 und 3 sind luftiger —, und weil sie sich aus der Tinte ergibt statt aus der Schrift, wird derselbe Text bei gleicher Schrift und Größe meist schmaler als früher, es passt also mehr aufs Display."),
                .absatz("Hier rastert die App nämlich jedes Zeichen einzeln und setzt es nach seiner Tinte ans vorige, statt nach der Vorschubbreite der Schrift: Die ist für gedruckte Größen gemacht und fällt auf sechzehn Pixeln mal zu eng, mal zu weit aus, ein fester Zuschlag verschiebt das Problem nur."),
                .absatz("Beim Weg „als Text“ bleibt „Abstand“ ohne Wirkung: Dort rastert die Uhr selbst und bringt ihren eigenen, festen Zeichenabstand als `charSpacing` mit (Gerätereferenz, §4.3), unabhängig von dieser Einstellung."),

                .ueberschrift("Breite und Ausrichtung"),
                .absatz("Ohne Icon ist die verfügbare Breite die vollen 52 Pixel des Displays, mit Icon 42, weil das Icon die ersten zehn Spalten belegt — daran hängt auch die Entscheidung, ob der Text steht oder läuft, und der fette Schnitt zählt dabei mit. Steht er, richten die waagrechten Ausrichtungsknöpfe ihn innerhalb dieser Breite aus, die senkrechten innerhalb der 16 Zeilen, gerechnet über die tatsächlich gesetzte Höhe, nicht die Schriftgröße."),

                .ueberschrift("Icon wählen"),
                .absatz("Neben dem Textfeld steht ein Knopf, der ohne Wahl „Icon wählen…“ heißt und mit Wahl Vorschaubild und Namen des Icons zeigt — in beiden Fällen ein Druck, der ein Blatt mit Suchfeld und Raster öffnet, dazu ein Eintrag „ohne“, um die Wahl im Blatt loszuwerden, und „Schließen“ zum Beenden. Ist ein Icon gewählt, steht daneben ein kleiner Knopf zum Entfernen, ohne das Blatt erst öffnen zu müssen."),
                .absatz("Die Vorschau darunter zeigt ein gewähltes Icon an derselben Stelle mit, an der die Uhr es zeigt — so sieht man vor dem Senden, ob Icon und Text zusammenpassen. Ist das Icon animiert, spielt die Vorschau es probeweise in Schleife ab, so wie auch die Uhr animierte Icons abspielt (am Gerät bestätigt, Hilfe → Gerätereferenz, §4.2)."),
                .absatz("Läuft der Text beim Weg „als Pixel“, wird das Icon in die Laufschrift hineingerechnet, statt als zweites Bild danebenzustehen — ob die Uhr zwei Bilder in einem Rahmen nebeneinander zeichnet, hat niemand geprüft, und so stellt sich die Frage nicht. Es steht dann fest links, der Text läuft rechts daneben durch, und seine Spalten bleiben schwarz, damit der Text nicht hinter ihm durchblitzt."),
                .absatz("Wer es lieber mitwandern lässt, schaltet „Icon mitscrollen“ ein: Dann steht es am Anfang des Textes und läuft mit hinaus, und der Text nutzt die vollen 52 Spalten. Ein animiertes Icon spielt in beiden Fällen weiter ab. Beim Weg „als Text“ gibt es dieses Mitscrollen nicht: Das Icon steht dort immer fest links, gleich ob und wie schnell die Uhr den Text daneben laufen lässt."),

                .ueberschrift("Sendeziel"),
                .absatz("Rechts vom Sendeknopf steht ein Knopf, der das aktuelle Sendeziel nennt — etwa „an: Küche“, „an alle Uhren (3)“ oder „an 2 Uhren“. Ein Druck öffnet ein Blatt mit einer Zeile je eingerichteter Uhr: Name, Präfix und derselbe Verbindungsstand wie unter „Verbindung“, dazu ein Haken zum An- und Abwählen; „Alle“ und „Keine“ wählen mit einem Klick, „Schließen“ beendet die Auswahl."),
                .absatz("Eine Uhr ohne Präfix ist im Blatt als solche gekennzeichnet — sie kann erst empfangen, sobald sie unter „Verbindung“ abgefragt wurde, und wird beim Senden stillschweigend übersprungen, solange das nicht geschehen ist. Ist nichts angehakt, geht die Sendung an die gerade aktive Uhr."),
                .absatz("Dieser Knopf erscheint erst ab zwei eingerichteten Uhren; bei nur einer geht jede Sendung ohne weitere Wahl automatisch an sie. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Verbindung“ eine Uhr einzutragen und abzufragen."),

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
                .absatz("„Meldung“, „Dauer (Sek.)“, die Zielauswahl und „Senden“ funktionieren wie unter „Senden“ beschrieben — auch hier ersetzt ein erneutes Senden auf denselben Platz die vorherige Anzeige, und auch hier ist der Sendeknopf gesperrt, solange keine Uhr fertig eingerichtet ist; der Hinweis dazu steht darunter. Fehler beim Senden meldet dasselbe Hinweisfenster wie unter „Senden“."),
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
            return [
                .ueberschrift("Herkunft der Liste"),
                .absatz("„Anzeigen“ listet, was auf der aktiven Uhr steht. Der graue Zusatz neben der Überschrift sagt, woher die Liste kommt — und dieser Unterschied ist wichtig: „vom Gerät gemeldet“ heißt, die Uhr selbst hat sie veröffentlicht; dann steht dort alles, was wirklich auf ihr liegt, auch von einem anderen Werkzeug Angelegtes, und auch das lässt sich hier löschen."),
                .absatz("„von dieser App angelegt“ heißt dagegen, es ist nur die eigene Buchführung — das eine ist Tatsache, das andere Erinnerung. Je Uhr getrennt: die Liste wechselt mit, wenn man unter „Verbindung“ eine andere Uhr zur aktiven macht."),

                .ueberschrift("Wie die Liste entsteht"),
                .absatz("Die Uhr veröffentlicht ihre Anzeigenliste von sich aus über das MQTT-Thema `<präfix>/customList`, und über `<präfix>/status`, ob sie gerade am Broker hängt (Hilfe → Gerätereferenz, §3.4 und §3.5). Abfragen lässt sich beides nicht — es kommt, wenn die Uhr es schickt."),
                .absatz("Die App hört deshalb dauerhaft beim Broker mit, sobald eine Uhr ein Präfix hat. Steht neben der Überschrift „von dieser App angelegt“, ist noch nichts gemeldet worden: kein Broker erreichbar, die Uhr aus, oder unter „Verbindung“ noch nicht abgefragt. Reißt die Verbindung ab, fällt die Liste auf die Buchführung zurück und sagt es."),

                .ueberschrift("Anzeigen und Löschen"),
                .absatz("„Anzeigen“ schaltet auf den Namen um, „Löschen“ entfernt ihn mit leerer Nachricht von der aktiven Uhr. Ging dieselbe Anzeige über die Zielauswahl auch an andere Uhren, steht sie dort weiter und muss bei jeder einzeln gelöscht werden. Eine stehende, gerade gezeigte Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder unter demselben Namen ersetzt wird — das ist der häufigste Grund, warum eine frisch gesendete Anzeige nicht auftaucht."),

                .ueberschrift("Protokoll"),
                .absatz("Darunter steht das Protokoll — mit Uhrzeit, älteste Zeile oben, neueste unten. Aufgezeichnet wird:"),
                .punkte([
                    "jede Abfrage einer Uhr",
                    "jedes Umschalten und Löschen einer Anzeige",
                    "jede Änderung des Seitenwechsels",
                    "jede Broker-Prüfung",
                    "jede Meldung, die von einer Uhr hereinkommt",
                ]),
                .absatz("„Leeren“ macht die Liste leer. Fehler erscheinen zusätzlich zum Hinweisfenster auch hier, damit sie nach dem Wegklicken nicht verloren sind."),

                .ueberschrift("Seitenwechsel"),
                .absatz("Die Einstellung „Seitenwechsel“ — wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — findet sich nicht mehr hier, sondern unter „Verbindung“ bei der jeweils aktiven Uhr, direkt neben der Liste der Uhren."),
            ]
        case .fehlersuche:
            return [
                .ueberschrift("Was die App meldet — und was nicht"),
                .absatz("MQTT in der hier verwendeten Version 3.1.1 meldet eine abgelehnte Veröffentlichung nicht zurück. Egal ob das Konto keine Schreibrechte auf das Thema hat oder niemand darauf lauscht: Die App bekommt kein Fehlersignal, keine Warnung — nichts unterscheidet das von einer erfolgreichen Sendung. Erscheint nichts auf der Uhr, ist das also kein Rätsel dieser App, sondern die normale Stille von MQTT 3.1.1."),
                .absatz("Alles bis zur Anmeldung am Broker meldet die App dagegen sehr wohl: falsches Kennwort, unerreichbarer Broker, Zeitüberschreitung, fehlende Zugangsdaten. Kam nach dem Senden kein Hinweisfenster, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter."),

                .ueberschrift("Welche Meldung ist gemeint?"),
                .absatz("Das sind zwei verschiedene Suchen, und die Meldung sagt, welche gemeint ist. Nennt sie den Broker mit Adresse und Port („Der Broker 192.168.1.10:1883 antwortet nicht.“), ist die App gar nicht bis dorthin gekommen — dann hilft nur „Verbindung“ → „Sichern und prüfen“, und keine Uhr ist daran schuld; diese Meldung erscheint deshalb auch nur einmal, selbst wenn an fünf Uhren gesendet wurde. Beginnt die Meldung dagegen mit dem Namen einer Uhr, betrifft sie genau diese und die übrigen wurden beliefert."),

                .ueberschrift("Der Reihe nach prüfen"),
                .punkte([
                    "Erstens das Präfix — unter „Verbindung“ „Abfragen“ noch einmal ausführen und mit dem tatsächlichen Präfix vergleichen; es ist nicht das in Ulanzi Studio eingetragene.",
                    "Zweitens, ob die Uhr überhaupt beim Broker angemeldet ist — das Häkchen- oder Warndreieck-Symbol in derselben Zeile.",
                    "Drittens, ob das Broker-Konto auf dieses Thema schreiben darf. Das steht in der Rechtedatei des Brokers, nicht in dieser App, und lässt sich nur am Broker-Protokoll ablesen.",
                    "Viertens, ob unter „Anzeigen“ noch eine alte, stehende Anzeige blockiert — die zuerst löschen oder unter demselben Namen ersetzen.",
                ]),

                .ueberschrift("Weitere Symptome"),
                .absatz("Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind: „Seitenwechsel“ unter „Verbindung“ steht vermutlich auf „kein Wechsel“."),
                .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es bei „Malen“ nicht geben und bei „Senden“ nur auf dem Weg „als Text“ — dort warnt die App vorher, welche Zeichen betroffen sind. Beim Weg „als Pixel“ rastert die App jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht."),
            ]
        }
    }
}
