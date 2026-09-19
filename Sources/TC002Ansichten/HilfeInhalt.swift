import TC002Core

/// Die Absätze der Hilfe, die auf beiden Geräten gelten.
///
/// Jeder Satz hier muss für beide Oberflächen wahr sein — was nur einen Knopf
/// einer bestimmten Oberfläche beschreibt, gehört in deren eigenes Dokument
/// (`HilfeView` am Mac, `HilfeiOS` am iPhone). Geteilt ist, was an der Uhr,
/// am Protokoll oder am gemeinsamen Kern hängt.
///
/// Warum als Konstanten und nicht zweimal geschrieben: Der deutsche Wortlaut
/// ist der Übersetzungsschlüssel. Ein zweiter Satz mit derselben Aussage wäre
/// ein zweiter Schlüssel und müsste ein zweites Mal übersetzt werden — und
/// könnte beim nächsten Mal nur an einer der beiden Stellen berichtigt
/// werden.
public enum HilfeInhalt {
    /// Was die App ueberhaupt tut und wo die Nachrichten langlaufen.
    ///
    /// **Der Unterschied der beiden Wege steht hier und nicht erst bei den
    /// Einstellungen.** Er ist die Entscheidung, die alles Weitere traegt:
    /// Ob eine Sendung quittiert wird, ob ein Block eine fremde Anzeige zeigen
    /// kann, ob es ein Praefix braucht — alles haengt daran. Wer ihn erst
    /// hinter der Haelfte der Hilfe erfaehrt, hat bis dahin Saetze gelesen,
    /// die nur fuer einen der beiden gelten.
    ///
    /// Und ein Absatz „Was ist MQTT" — genau einer. Ohne ihn ist „Broker" ein
    /// Wort, das Vorwissen verlangt, und die Einstellungen sind ein Formular
    /// fuer etwas, das man nicht kennt.
    ///
    /// Beide Bauarten schon im ersten Satz (`Geraetetyp`): Wer die Einleitung
    /// liest, hat die Uhr vor sich, die er einrichten will, und eine
    /// Einleitung, die nur eine Bauart nennt, schliesst die andere aus.
    public static let wasEsTut: [Hilfebaustein] = [
        .absatz("Pixel Clock Messenger schickt Text, Farbe und kleine Bilder an eine Pixeluhr: an eine Ulanzi TC002 mit ihrer Werksfirmware — der Software, die ab Werk darauf läuft — oder an eine TC001 mit der freien Firmware AWTRIX NG. Du tippst den Text unten ein, die Vorschau darüber zeigt, wie er auf der Uhr aussehen wird, und die Eingabetaste schickt ihn hin."),
        .ueberschrift("Zwei Wege zur Uhr"),
        .absatz("Wie die Anzeige zur Uhr kommt, legst du je Uhr unter „Einstellungen“ fest. Es gibt zwei Wege, und sie unterscheiden sich vor allem darin, was du hinterher weißt."),
        .untertitel("Direkt über HTTP"),
        .absatz("Die App spricht die Uhr unmittelbar an, so wie ein Browser eine Seite holt. Die Uhr antwortet auf jede Sendung: Du erfährst, ob sie die Anzeige genommen hat, und wenn nicht, warum. Mehr als ihre Adresse brauchst du dafür nicht. Eine neu eingetragene Uhr steht auf diesem Weg."),
        .untertitel("Indirekt über einen MQTT-Server"),
        .absatz("Die App legt die Anzeige bei einem Vermittler im eigenen Netz ab, und die Uhr holt sie dort. Eine Rückmeldung bekommst du auf diesem Weg nie — auch dann nicht, wenn die Uhr ausgeschaltet ist. Dafür liest die App mit: Schickt ein anderes Programm etwas an dieselbe Uhr, sieht sie es und zeigt es dir an."),
        .ueberschrift("Was ist MQTT?"),
        .absatz("MQTT ist die Sprache, in der Geräte im Haus einander Nachrichten hinterlassen. In der Mitte steht ein Programm, das die Nachrichten annimmt und weiterreicht: der **MQTT-Broker**, meist ein kleiner Server im eigenen Netz. Wer etwas zu sagen hat, legt es dort unter einem Namen ab — dem Thema —, und wer es haben will, meldet sich für dieses Thema an und bekommt jede neue Nachricht zugestellt. Die Uhren hängen selbst an einem solchen Broker; diese App legt ihre Anzeigen dort für sie ab."),
        .ueberschrift("Zwei Bauarten von Uhr"),
        .absatz("Welche Bauart eine Uhr ist, steht ebenfalls unter „Einstellungen“, und sie entscheidet, was die Regler bewirken. Auf einer Ulanzi mit Werksfirmware setzt **diese App** den Text in Pixel um; Schriftart, Größe, Fett, Rand und Abstand gelten also. Eine AWTRIX NG setzt ihn mit ihrer eigenen Schrift — dort stehen dieselben Regler gesperrt da und sagen beim Antippen, warum."),
        .absatz("Ein paar Dinge macht die App immer selbst über HTTP, gleich welcher Weg für eine Uhr eingestellt ist: die Uhr abfragen, holen, welche Anzeigen gerade auf ihr stehen, und die Einstellungen des Geräts schreiben."),
    ]

    /// Die Wahl selbst — was sie bedeutet und was sie kostet. Gehoert hierher
    /// und nicht in die Oberflaeche: Dort steht ein Satz, der den Tausch
    /// benennt, und alles Weitere hier.
    ///
    /// Der Absatz ueber den Broker als Ohr ist kein Nebensatz, sondern der
    /// Grund fuer den ganzen Zuschnitt: Waere es anders, saehe der HTTP-Betrieb
    /// anders aus.
    public static let betriebsart: [Hilfebaustein] = [
        .ueberschrift("Betriebsart: HTTP oder MQTT"),
        .absatz("Auf der Seite jeder Uhr wählst du, auf welchem der beiden Wege sie beschickt wird: „HTTP“ oder „MQTT“. Die Anzeige selbst ist auf beiden Wegen dieselbe — an Text, Schrift, Farbe und Icon ändert sich nichts. Was sich ändert, ist, was du hinterher weißt."),
        .untertitel("HTTP"),
        .absatz("Die Uhr antwortet. Sie bestätigt jede Anzeige, jede Löschung und jedes Umschalten, und eine abgewiesene Sendung erkennst du als solche. Du brauchst dafür weder einen MQTT-Broker noch ein Themen-Präfix — nur die Adresse der Uhr."),
        .untertitel("MQTT"),
        .absatz("Die Uhr antwortet nie; was das für die Fehlersuche heißt, steht unter „Wenn nichts erscheint“. Dafür liest die App am MQTT-Broker mit, was andere Programme an dieselbe Uhr schicken — nur so kann einer der fünf Blöcke eine fremde Sendung zeigen."),
        .absatz("Beides zugleich gibt es nicht. Ein MQTT-Broker kann die HTTP-Sendungen nicht nebenbei mithören: Die Uhr reicht sie nicht an ihn weiter. Nachgemessen am 13.09.2026 — 45 Sekunden auf allen drei Themen einer Uhr gehorcht, mit einer Löschung über HTTP mittendrin, und es kam eine einzige Nachricht, die nur sagte, dass die Uhr online ist. Ein zusätzlich eingetragener Broker bringt im HTTP-Betrieb deshalb kein halbes Mitlesen, sondern gar keines."),
        .absatz("Eine neu eingetragene Uhr steht auf HTTP. Eine Uhr, die du vor dieser Fassung eingerichtet hast, bleibt auf MQTT — ein stiller Wechsel nähme ihr das Mitlesen. Umstellen kannst du jederzeit, der Wechsel wirkt sofort."),
    ]

    /// Die zweite Achse neben der Betriebsart: was fuer ein Geraet
    /// antwortet. Gilt fuer beide Oberflaechen — es ist eine Aussage ueber die
    /// Uhr, nicht ueber ein Fenster.
    ///
    /// Vier Absaetze und keiner mehr: was gewaehlt wird und wer es feststellt,
    /// was auf einer AWTRIX besser ist, was dort wegfaellt, und was gar nicht
    /// geht. Alles Weitere steht in der Geraetereferenz.
    public static let geraeteart: [Hilfebaustein] = [
        .ueberschrift("Geräteart: Ulanzi TC002 oder AWTRIX NG"),
        .absatz("Neben der Betriebsart hat jede Uhr eine zweite Wahl: welche Firmware auf ihr läuft. „Abfragen“ stellt das selbst fest und trägt es ein. Von Hand zu wählen ist es nur dort, wo das nicht gelingt — eine AWTRIX kann ihre Schnittstelle hinter eine Anmeldung stellen, und dann antwortet sie auf keine Frage."),
        .absatz("Der Unterschied ist einer im Grundsatz: Die Werksfirmware bekommt von dieser App **fertige Pixel**, eine AWTRIX NG bekommt den **Text** und setzt ihn mit ihrer eigenen Schrift. Alles Weitere folgt daraus."),
        .abbildung(.geraetegroessen),
        .untertitel("Was auf einer AWTRIX NG besser ist"),
        .absatz("Ihre Schrift kann Umlaute, Akzente, das Eurozeichen und Kyrillisch von Haus aus, und ein Zeichen, das sie nicht hat, wird zum Fragezeichen statt spurlos zu verschwinden. Langer Text läuft von selbst, ohne Größengrenze. Und sie antwortet auf jede Sendung — eine abgewiesene meldet sie als abgewiesen, was über MQTT sonst nie vorkommt."),
        .untertitel("Was dort wegfällt"),
        .absatz("Schriftart, Größe, Fett, Rand und Zeichenabstand steuern, wie **diese App** den Text in Pixel umsetzt. Setzt die Uhr ihn selbst, gibt es daran nichts zu drehen. Senkrecht ausrichten geht ebenfalls nicht, ihre Grundlinie liegt fest, und rechtsbündig kennt sie nicht. Die Regler stehen deshalb gesperrt da und sagen beim Antippen, warum."),
        .untertitel("Was dort nicht geht"),
        .absatz("Ein gemaltes Bild und ein Bild aus der Sammlung: Gemalt wird auf 52 × 16 Pixel, die AWTRIX hat 32 × 8. Ebenso ein 16 × 16-Icon — auf acht Zeilen hat es keinen Platz. Beides lehnt sie ab, statt es stillschweigend zu verschlucken."),
        .absatz("Die fünf Blöcke unter der Vorschau zeigen bei einer AWTRIX dasselbe wie die Vorschau: eine Näherung auf ihren 32 × 8, in einer Ersatzschrift. Die Uhr setzt den Text mit ihrer eigenen Schrift, und die kennt diese App nicht — der Block sagt dir also, was auf dem Platz liegt, nicht, wie es dort aussieht. Ob ein Platz belegt ist, weiß er dafür genauer als bei der Werksfirmware: Die AWTRIX nennt zu jeder Anzeige, wer sie abgelegt hat."),
    ]

    /// Fuer wen der Brokerabschnitt ueberhaupt gilt. Ein Satz, weil der
    /// Abschnitt sichtbar und benutzbar bleibt und nur eingeordnet gehoert.
    public static let brokerNurFuerMqtt: [Hilfebaustein] = [
        .absatz("Diese Angaben gelten dem MQTT-Broker und damit den Uhren, die über MQTT beschickt werden. Steht gerade keine Uhr darauf, bleiben die Felder ungenutzt — ausgegraut oder versteckt sind sie trotzdem nicht: Du trägst den Broker ein, bevor du eine Uhr auf MQTT stellst, und in dieser Reihenfolge müssen sie benutzbar sein."),
    ]

    /// Wie die Einstellungen gegliedert sind (`Einstellungsthema`). Das Erste,
    /// was man wissen will — und auf beiden Oberflaechen dieselben fuenf
    /// Bereiche in derselben Reihenfolge. Nur ihre Darstellung unterscheidet
    /// sich, und das steht im Absatz selbst.
    ///
    /// Keine Ueberschrift ueber der Aufzaehlung: „Fuenf Themen" nannte die
    /// Anzahl statt der Sache. Die Namen stehen in der Aufzaehlung, und der
    /// Abschnitt heisst ohnehin „Einstellungen".
    public static let themen: [Hilfebaustein] = [
        .absatz("Die Einstellungen sind in fünf Bereiche geteilt. Am Mac und auf dem iPad wählst du den Bereich über dem Inhalt, auf dem Telefon führt jeder Eintrag der Liste auf eine eigene Seite."),
        .punkte([
            "**Uhren** — deine eingetragenen Uhren, je eine Zeile, die auf ihre Seite führt.",
            "**Broker** — Adresse, Port, Benutzer und Kennwort des MQTT-Brokers, dazu die Prüfung der Verbindung.",
            "**Aufzeichnung** — Verlauf und Protokoll.",
            "**iCloud** — Synchronisation deiner Geräte.",
            "**Erweitert** — die virtuelle Uhr, mit der du die App ohne ein Gerät ausprobieren kannst.",
        ]),
        .ueberschrift("Konfigurieren der Pixel Uhr"),
        .absatz("Tippst du unter „Uhren“ eine Zeile an, öffnet sich die Seite dieser Uhr. Dort steht alles, was zu ihr gehört: Name, Adresse, Geräteart, Betriebsart, „Auf der Uhr“ (nur bei einer Ulanzi mit Werksfirmware), „Abfragen“ und „Konfigurieren“ — und am Fuß, rot, „Entfernen“. Jeder Wert dort gilt dieser einen Uhr, nicht der gerade angesehenen."),
        .absatz("In der Liste selbst steht je Uhr nur ihr Name, darunter Adresse, Themen-Präfix und Geräteart, und rechts das Zeichen, ob sie beim MQTT-Broker angemeldet ist."),
    ]

    /// Womit die App beginnt, solange nichts eingerichtet ist
    /// (`AppZustand.eingerichtet`). Der Satz gilt fuer beide Oberflaechen: Am
    /// Mac und auf dem iPad steht der Bereich „Einstellungen" vorn, auf dem
    /// Telefon geht sein Blatt von selbst auf. Beide Male ist es derselbe
    /// Grund und dieselbe Auskunft — deshalb ein Absatz und nicht zwei.
    public static let startOhneEinrichtung: [Hilfebaustein] = [
        .absatz("Solange keine Uhr eingetragen ist, beginnt die App bei den Einstellungen statt bei „Senden“, und zwar beim Thema „Uhren“, wo die erste Uhr eingetragen wird — bei „Senden“ gäbe es ohne Uhr weder eine Vorschau noch ein Ziel. Dasselbe gilt, solange eine Uhr auf MQTT steht und die Adresse des MQTT-Brokers fehlt; steht jede Uhr auf HTTP, fragt die App nach keinem Broker. Gesperrt ist dabei nichts: Wer will, geht sofort weiter. Sobald steht, was gebraucht wird, startet sie wieder bei „Senden“."),
    ]

    /// Wie eine Uhr angelegt wird (`Uhrenliste`). Auf beiden Oberflaechen
    /// dieselbe Zeile am Fuss der Liste und dasselbe Blatt dahinter.
    public static let uhrHinzufuegen: [Hilfebaustein] = [
        .ueberschrift("Uhr hinzufügen"),
        .absatz("Unter „Einstellungen“ → „Uhren“ steht am Fuß der Liste die Zeile „Uhr hinzufügen …“. Sie öffnet ein Blatt mit Adresse und Name. Den Namen kannst du weglassen — dann heißt die Uhr „Uhr 1“, „Uhr 2“ und so fort, und du kannst sie später umbenennen. Alles Übrige — Themen-Präfix und Geräteart — stellt die App selbst fest."),
    ]

    /// Die zwei Wege, eine Uhr loszuwerden, und dass beide nachfragen
    /// (`Uhrentfernen`). Auf beiden Oberflaechen dieselben zwei.
    public static let uhrEntfernen: [Hilfebaustein] = [
        .ueberschrift("Entfernen"),
        .absatz("Eine Uhr wird auf zwei Wegen entfernt: mit der roten Zeile „Entfernen“ am Fuß ihrer Seite oder mit einem Wischen nach links in der Liste. Beide fragen dasselbe nach. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),
    ]

    /// Die beiden Werte, die nicht der Meldung, sondern dem Geraet gehoeren
    /// (`Uhreinstellungen`). Sie stehen auf der Seite der Uhr, fuer die sie
    /// gelten — auf beiden Oberflaechen, seit sich beide dieselben Bausteine
    /// teilen.
    public static let aufDerUhr: [Hilfebaustein] = [
        .ueberschrift("Auf der Uhr"),
        .absatz("„Auf der Uhr“ — Seitenwechsel und Scrolltempo — steht auf der Seite der Uhr, für die beides gilt: Beides sind Einstellungen des Geräts, sie überdauern jede Meldung und werden beim Verstellen sofort geschrieben. Bei einer AWTRIX NG fehlt der Abschnitt: Ihre Firmware kennt `/getConfig` nicht, sie führt beides selbst. Der Seitenwechsel ist der Takt, in dem die Uhr durch alles blättert, was auf ihr steht; das Scrolltempo gilt nur ihren eigenen Anzeigen (Gerätereferenz, §4.3). Wie lange eine einzelne Meldung steht und wie schnell sie läuft, entscheidet dagegen das Format unter „Senden“."),
    ]

    /// Das Themen-Praefix und woher es kommt. Beide Oberflaechen haben denselben
    /// Knopf, dieselben zwei Symbole und dieselbe Regel: Das Praefix wird
    /// ermittelt, nie eingetippt (`AppZustand.abfragen`).
    public static let uhrAbfragen: [Hilfebaustein] = [
        .ueberschrift("Abfragen"),
        .absatz("„Abfragen“ fragt die Uhr selbst nach zwei Angaben: ihrem **Themen-Präfix** und ihrer MAC-Adresse. Das Themen-Präfix ist der Name, unter dem die Uhr am MQTT-Broker auf Nachrichten hört; steht er falsch, schickt die App ins Leere. Danach steht er in der Zeile, in einer Schreibmaschinenschrift — so lassen sich ähnliche Zeichen auseinanderhalten."),
        .absatz("Daneben sagt ein Häkchen oder ein Warndreieck, ob die Uhr gerade beim MQTT-Broker angemeldet ist. Das ist aber nur die Anmeldung und keine Aussage darüber, ob die App auf das richtige Thema schreiben darf — mehr dazu unter „Wenn nichts erscheint“."),
        .absatz("Beides gehört zum MQTT-Betrieb. Steht die Uhr auf HTTP, braucht es kein Präfix, das Zeichen bleibt weg, und „Abfragen“ sagt dort nur eines: dass die Uhr antwortet. Geholt wird in beiden Fällen auch, welche Anzeigen gerade auf ihr stehen."),
        .absatz("Von Hand eintragen lässt sich das Präfix absichtlich nicht. Es ist nämlich nicht dasselbe wie das in Ulanzi Studio eingestellte: Die Firmware hängt die letzten vier Stellen der MAC-Adresse an. „Abfragen“ ermittelt deshalb selbst, welches Präfix wirklich gilt. Hat die Uhr gar keines eingestellt, sagt „Abfragen“ das — statt ein Thema zu bilden, auf das sie nie hört."),
        .absatz("Bei einer AWTRIX NG ist das Präfix dagegen genau das, was auf ihr eingestellt ist, ohne jeden Anhang. Ein Leerzeichen am Rand zeigt die Zeile als ␣ an: Es gehört zum Thema, ist sonst aber nicht zu sehen — und die Uhr hört dann auf ein anderes Thema als das, das du liest."),
        .absatz("Zwei Uhren dürfen dasselbe Präfix führen, und das ist brauchbar: Über MQTT **ist** das Präfix die Adresse, ein gemeinsames macht aus mehreren Uhren eine Gruppe. Was an sie geht, zeigen alle — ohne dass die App etwas mehrfach schicken müsste. Der Preis ist, dass sie von da an nicht mehr auseinanderhält, welche der beiden gerade etwas meldet: Belegte Plätze, mitgelesene Inhalte und das Anmeldezeichen gelten dann für die Gruppe, nicht für ein Gerät. Wer sie einzeln ansprechen will, gibt jeder ein eigenes Präfix — die Firmware kennt nur eines je Gerät, kein Gruppen- und Gerätepräfix nebeneinander wie WLED."),
        .absatz("Das Zeichen neben dem Präfix sagt, ob die Uhr gerade beim Broker angemeldet ist. Ein Warndreieck heißt: ist sie nicht. Eine AWTRIX NG nennt dann auch den Grund — „badCredentials“ etwa heißt, dass Benutzer und Kennwort, die **in der Uhr** eingetragen sind, der Broker nicht annimmt; die Angaben dieser App sind davon unberührt."),

        .absatz("Antwortet eine Uhr auf die letzte Abfrage gar nicht, steht ein rotes Zeichen neben ihrem Namen — in der Uhrenliste und in der Uhrenwahl. Ein Fenster kommt dafür nicht: Eine stumme Uhr ist kein Fehler, den jemand wegklicken müsste. Sie ist aus, sie steht woanders, das WLAN schläft."),

        .ueberschrift("Die Web-Oberfläche der Uhr"),
        .absatz("„Konfigurieren“ öffnet die Web-Oberfläche der Uhr im Browser. Dort steht alles, was diese App nicht einstellt: WLAN, Helligkeit, die eingebauten Anzeigen — und bei einer AWTRIX NG der MQTT-Broker samt Präfix."),
    ]

    /// Womit die vier Brokerfelder beginnen: mit nichts. Gilt fuer beide
    /// Oberflaechen — dieselben vier Felder, dieselben Beispiele darin.
    public static let brokerFelderLeer: [Hilfebaustein] = [
        .absatz("Alle vier Felder beginnen leer; was grau darin steht, ist ein Beispiel und kein Wert. Der Port ist die Ausnahme: 1883 ist der Standardport von MQTT und steht von Anfang an da."),
    ]

    /// Wo das Kennwort liegt — im Schluesselbund, nicht in den App-Einstellungen
    /// (`Einstellungen.kennwort`) — und dass unter dem Feld steht, ob eines da
    /// ist (`Brokerabschnitt.kennwortstand`): Ein leeres Feld sieht sonst aus,
    /// als waere keines gesetzt.
    public static let brokerKennwort: [Hilfebaustein] = [
        .absatz("Das Kennwort liegt im Schlüsselbund und nicht, wie die übrigen Felder, in den App-Einstellungen. Unter dem Feld steht, ob im Schlüsselbund eines liegt — das Feld selbst zeigt es nie an."),
    ]

    /// Wann die vier Brokerfelder gesichert werden. Seit beide Oberflaechen
    /// denselben Baustein tragen (`Brokerabschnitt`), gilt der Satz wortgleich
    /// fuer beide.
    public static let brokerSichern: [Hilfebaustein] = [
        .absatz("Adresse, Port und Benutzer sichern sich beim Tippen — es gibt nichts zu bestätigen. Das Kennwort wird gesichert, sobald man das Feld verlässt, die Eingabetaste drückt, das Thema wechselt oder die App beendet — nicht bei jedem Tastendruck."),
    ]

    /// Was die Brokerpruefung tut und was ihr Ergebnis nicht bedeutet. Beide
    /// Oberflaechen rufen dieselbe `AppZustand.brokerSichernUndPruefen`.
    public static let brokerPruefen: [Hilfebaustein] = [
        .absatz("„Verbindung prüfen“ fragt den MQTT-Broker, ob er die Anmeldung annimmt — das dauert bis zu acht Sekunden und läuft unter einer eigenen Client-Kennung, damit dabei keine laufende Sendung hinausfliegt. Zu sichern gibt es dabei nichts: Adresse, Port und Benutzer stehen schon beim Tippen fest, das Kennwort spätestens beim Verlassen des Feldes."),
        .absatz("Eine angenommene Anmeldung heißt aber nur: Benutzername und Kennwort stimmen. Ob die Uhr die Nachricht am Ende auch zeigt, hängt zusätzlich vom richtigen Präfix und davon ab, ob das Konto auf das Thema schreiben darf — beides meldet MQTT 3.1.1 nicht zurück (siehe „Wenn nichts erscheint“). Das Ergebnis der Prüfung steht auch im Protokoll unter „Verlauf“."),
    ]

    /// Der iCloud-Abgleich. Gehoert hierher und nicht in die Oberflaeche:
    /// Dort stehen ein Schalter und eine Zeile, die sagt, was gilt — warum es
    /// so gilt, steht hier. Jeder Satz ist auf beiden Geraeten wahr, der
    /// Abschnitt sieht auf Mac und Telefon gleich aus (`Wolkenabschnitt`).
    /// Ausprobieren ohne Geraet: Steht in `HilfeInhalt` und nicht in einer
    /// der beiden Hilfen, weil den Schalter es auf allen drei Oberflaechen
    /// gibt und was er tut ueberall dasselbe ist.
    public static let virtuelleUhr: [Hilfebaustein] = [
        .ueberschrift("Virtuelle Uhr"),
        .absatz("Ohne Gerät lässt sich die App trotzdem ausprobieren: Der Schalter „Virtuelle Uhr“ unter „Einstellungen“ → „Erweitert“ startet eine Uhr, die es nicht gibt. Sie hört auf 127.0.0.1:8752 zu, nimmt Anzeigen entgegen wie eine Ulanzi mit Werksfirmware und zeigt sie in einem eigenen Fenster — mit Geräterahmen, den fünf Plätzen und dem Blättern im eingestellten Takt."),
        .absatz("„Als Uhr eintragen“ legt sie in der Uhrenliste an; von da an ist alles wie bei einem Gerät: Abfragen, Senden, Löschen, der Verlauf. Was das Fenster zeigt, ist nicht die Vorschau, sondern das, was wirklich angekommen ist — die Nutzlast wird dafür zurück in Pixel zerlegt, auf demselben Weg wie beim Mitlesen über MQTT."),
        .absatz("Sie spricht HTTP, kein MQTT: Ein MQTT-Broker ist ein fremdes Programm und kann hier nicht mitkommen. Und sie hört nur auf dem eigenen Rechner zu — im Hausnetz ist sie nicht zu sehen."),
    ]

    public static let wolkenabgleich: [Hilfebaustein] = [
        .ueberschrift("Über iCloud abgleichen"),
        .absatz("Ist der Schalter an, liegen die eigenen Icons (8×8 und 16×16), die gemalten Bilder, die Einstellungen und das Gedächtnis der fünf Plätze nicht mehr auf diesem Gerät, sondern in iCloud — und damit auf jedem Gerät, auf dem die App mit demselben Konto läuft."),
        .absatz("Der letzte Punkt ist der eigentliche Gewinn: Weil auch das Gedächtnis der fünf Plätze mitwandert, zeigt das Telefon, was der Mac zuletzt an die Uhr geschickt hat, ohne dass es dafür am MQTT-Broker mithören müsste."),
        .absatz("**Zwei Dinge gehen nicht mit.** Das Brokerkennwort bleibt im Schlüsselbund und wird auf jedem Gerät einmal eingetragen; ein abgeglichener Schlüsselbund wäre ein eigener Mechanismus mit eigener Rückfrage. Und der Text, an dem man gerade unter „Senden“ schreibt, bleibt ebenfalls hier — zwei Geräte, die einander den halben Satz aus dem Feld ziehen, wären keine Verbesserung."),
        .absatz("Steht dort „Auf diesem Gerät steht der Abgleich nicht bereit“, fehlt die Berechtigung oder das iCloud-Konto. Dann bleibt alles örtlich liegen und die App arbeitet genau wie zuvor — es ist kein halber Zustand und kein Fehler."),
        .ueberschrift("Ein- und wieder ausschalten"),
        .absatz("Einschalten **kopiert** den vorhandenen Bestand hinauf und lässt ihn liegen, wo er war. Was in iCloud schon steht, bleibt unangetastet — dort kann der Bestand des anderen Geräts liegen, und den zu überschreiben wäre das Gegenteil eines Abgleichs."),
        .absatz("Ausschalten kopiert zurück. Man behält dabei alles, auch das, was erst seit dem Einschalten dazugekommen ist. Der Preis dafür, dass nie etwas verlorengeht: Eine Datei, die in iCloud gelöscht wurde, liegt hier noch und taucht beim Ausschalten wieder auf."),
        .ueberschrift("Wenn zwei Geräte dasselbe ändern"),
        .absatz("Bei Dateien gewinnt, wer zuletzt geschrieben hat; iCloud hebt die unterlegene Fassung als Konfliktversion auf, die App zeigt sie nicht an. Bei den Einstellungen wird **je Uhr** zusammengeführt statt am Stück: Wer hier eine Uhr einträgt, während dort eine umgestellt wird, verliert keine der beiden Änderungen. Nur wenn beide Geräte dieselbe Uhr ändern, gewinnt die zuletzt eingetroffene Fassung — eine Konfliktkopie wäre eine zweite Uhr mit derselben Adresse."),
    ]

    /// Die fuenf festen Plaetze und die drei Blockzustaende. Was ein Block zeigt,
    /// rechnet `AppZustand.slotzustand` fuer alle Oberflaechen gleich, und
    /// `Slotblock` (TC002Ansichten) zeichnet es fuer alle gleich — der Absatz
    /// gehoert deshalb dorthin, wo auch der Block herkommt.
    public static let fuenfPlaetze: [Hilfebaustein] = [
        .absatz("„Senden“ setzt aus Text, Farbe und wahlweise einem Icon eine Anzeige zusammen und schickt sie an die Uhr. In der Mitte stehen fünf Blöcke, je einer für einen der fünf festen Plätze der Uhr — die Ziffer unter dem Block sagt, welcher es ist, auf dem Gerät heißen sie `meldung1` bis `meldung5`. Ein Antippen wählt den Platz, unter dem die Anzeige danach bei „Verlauf“ auftaucht."),
        .absatz("Jeder Block zeigt einen von drei Zuständen, an der Form erkennbar, nicht nur an der Farbe:"),
        .punkte([
            "**Frei** — ein gestrichelter, leerer Rahmen. Auf diesem Platz liegt nichts.",
            "**Belegt, Inhalt bekannt** — die Pixel, verkleinert. Sie stammen aus einer mitgelesenen Sendung oder aus dem, was sich diese App für den Platz gemerkt hat; im zweiten Fall ist es eine Erinnerung und kann überholt sein.",
            "**Belegt, Inhalt unbekannt** — ein grauer Block mit einem Fragezeichen, ohne Pixel.",
        ]),
        .absatz("Ein Fragezeichen auf einem Block heißt: Dort liegt etwas, das nicht von hier kam. Die Uhr nennt ihre Anzeigen beim Namen, verrät aber nicht, was darin steht — der Platz ist belegt, der Inhalt bleibt unbekannt."),
        .absatz("Auf denselben Platz senden ersetzt, was dort steht; ein anderer Platz tritt daneben, und die Uhr blättert zwischen den belegten Plätzen. Das gilt für jede Zieluhr: ein Platz zählt schon als belegt, wenn ihn nur eine davon kennt — die Blöcke zeigen dabei immer den Stand der gerade aktiven Uhr."),
    ]

    /// Woher die Blöcke ihr Wissen haben: mitgelesen oder gemerkt. Gilt auf
    /// beiden Geraeten, weil Mitlesen (`AppZustand.gemeldet`) und Slotgedaechtnis
    /// derselbe Kern sind. Der zweite Absatz haelt fest, warum ein frisch
    /// gestarteter Mitleser zunaechst schweigt — eine Eigenschaft von MQTT 3.1.1,
    /// keine der Oberflaeche.
    public static let blockwissenAnfang: [Hilfebaustein] = [
        .ueberschrift("Woher die Blöcke wissen, was belegt ist"),
        .abbildung(.slotzustaende),
        .absatz("Die Uhr selbst verrät über ihre Anzeigenliste nur Namen, nie den Inhalt eines Platzes (Gerätereferenz, §3.5) — belegt oder frei ist damit gesichert, der Inhalt nicht. Den gewinnt die App stattdessen daraus, dass sie beim MQTT-Broker jede Sendung an die Uhr mitliest, gleich von wem sie kommt: von dieser App, vom Kommandozeilenwerkzeug, von einem Kurzbefehl oder von einem zweiten Programm."),
        .absatz("**Das gilt nur im MQTT-Betrieb.** Steht die Uhr auf HTTP, gibt es kein Mitlesen — dann zeigt ein Block allein, was diese Installation selbst auf den Platz geschickt und sich dazu gemerkt hat. Jede fremde Sendung bleibt dort „belegt, Inhalt unbekannt“, und zwar dauerhaft und nicht bloß bis zur nächsten Nachricht. Die Belegung selbst ist davon unberührt: Welche Plätze belegt sind, sagt die Uhr auf Nachfrage, und im HTTP-Betrieb obendrein nach jeder eigenen Sendung — sie quittiert sie."),
        .absatz("Mitlesen heißt aber: nur, was gesendet wird, solange die App verbunden ist. Ohne aufbewahrte (RETAIN-)Nachrichten liefert MQTT einem frisch verbundenen Abonnenten keinen Rückstand — das ist kein Fehler dieser App, sondern die normale Stille von MQTT 3.1.1 (siehe auch „Wenn nichts erscheint“). Was diese Installation unter „Senden“ selbst geschickt hat, zeigt der Block nach einem Neustart trotzdem: Dafür merkt sie sich je Platz die Regler und rechnet das Bild daraus neu."),
    ]

    /// Die drei gewoehnlichen Ursachen fuer einen Block ohne Inhalt, und warum
    /// eigene Sendungen anders behandelt werden. Steht zwischen den beiden
    /// Haelften ein geraetespezifischer Absatz (am Mac der ueber Gemaltes),
    /// deshalb zwei Konstanten statt einer.
    public static let blockwissenSchluss: [Hilfebaustein] = [
        .absatz("Ohne Inhalt bleiben deshalb die Plätze, zu denen es hier nichts zu merken gab — sie zeigen „belegt“, bis dort das nächste Mal etwas mitgelesen oder etwas Merkbares gesendet wird."),
        .absatz("„Belegt, Inhalt unbekannt“ ist einer von drei gewöhnlichen, harmlosen Fällen: Die Anzeige stammt von einem anderen Gerät oder einer anderen Installation dieser App — dann wurde sie hier weder mitgelesen noch gemerkt. Oder sie ist eine Laufschrift oder ein von der Uhr selbst gesetzter Text eines fremden Absenders: Aus so einer Nutzlast lässt sich kein Standbild zurückrechnen. Oder sie wurde über die HTTP-Schnittstelle der Uhr angelegt und ist am Broker vorbeigegangen (Gerätereferenz, §3.5) — steht die Uhr selbst auf HTTP, ist das kein Sonderfall mehr, sondern gilt für alles Fremde."),
        .absatz("Für die eigenen Sendungen gilt das nicht: Dort rechnet die App das Bild aus dem gemerkten Stand, nicht aus der Nutzlast. Eine selbst geschickte Laufschrift zeigt der Block deshalb stehend, mit ihren ersten 52 Pixeln. Der Block sagt in diesem Fall, was auf dem Platz liegt — nicht, wie es auf der Uhr aussieht."),
        .absatz("Auch ein Block mit bekanntem Inhalt stellt beim Antippen nicht immer die Regler wieder her: Das gelingt nur, wenn diese Installation die Sendung selbst mitgelesen hat und der Platz seither nicht von anderer Stelle überschrieben wurde — sonst wählt das Antippen nur den Platz, ohne die Regler zu verändern."),
    ]

    /// Wann ein Text steht und wann er laeuft — `Meldungsbau.passt` entscheidet
    /// das auf beiden Geraeten gleich, ohne dass jemand danach gefragt wird.
    ///
    /// Die Wahl „Senden als: als Pixel / als Text" im Inspektor und im
    /// Formatblatt ist ersatzlos weg; dieser Abschnitt sagt, was die App statt
    /// dessen tut. Warum, steht bei `SendeWeg` im Kern.
    public static let wegeRegel: [Hilfebaustein] = [
        .absatz("Ob der Text stehenbleibt oder durchläuft, entscheidet die App selbst — es gibt dafür keinen Schalter."),
        .abbildung(.stehtOderLaeuft),
        .absatz("Sie rechnet die Breite des gesetzten Textes ohnehin aus, und daran hängt die Regel: Passt er in die verfügbare Breite (52 Pixel, mit Icon 42), geht er als starres Pixelbild an die Uhr und bleibt stehen — klein, schnell, exakt. Passt er nicht, rastert die App den Lauf selbst und schickt ihn als animiertes GIF, das die Uhr abspielt (Gerätereferenz, §4.2a): Der Text läuft durch, mit Umlauten und in der gewählten Schriftart."),
        .absatz("Gerastert wird dabei immer von dieser App, auch bei langem Text. Die Uhr kann Text zwar auch selbst setzen, und bis zum 18.09.2026 gab es dafür die Wahl „als Text“ — sie kostete Schriftart, Größe und Fett, verlor Umlaute und ließ langen Text nicht einmal durchlaufen, sondern schnitt ihn ab (ein Mangel der Werksfirmware, am 11.09.2026 mit drei Fassungen geprüft). Übrig blieb eine kleinere Nutzlast, und die ist den Preis nicht wert."),
        .absatz("Bei einer TC001 unter AWTRIX NG stellt sich die Frage ohnehin nicht: Dorthin gehen nie Pixel, sondern immer der Text samt Reglern — die Uhr setzt ihn selbst. Die Vorschau ist dann nur eine Näherung, und das (?) neben der Punktreihe unter ihr sagt, warum."),
    ]

    /// Warum eine stehende Anzeige alles andere blockiert — eine Eigenschaft der
    /// Uhr, nicht der Oberflaeche.
    public static let blockierendeAnzeige: [Hilfebaustein] = [
        .absatz("Egal wie viele Plätze belegt sind: Eine gerade angezeigte, stehende Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder ersetzt wird — deshalb ist „auf denselben Platz senden“ oft das, was man eigentlich will."),
    ]

    /// Wie ein einzelner Platz geraeumt wird: ueber das Menue des Blocks
    /// (`View.slotmenue`), auf beiden Oberflaechen dieselbe Geste. Das ⊗ am
    /// Zeiger ist der eine begruendete Unterschied und deshalb als solcher
    /// benannt.
    public static let blockLoeschen: [Hilfebaustein] = [
        .absatz("Ein langer Druck auf einen belegten Block — mit der Maus ein Rechtsklick — öffnet sein Menü: „Zeigen“ schaltet die Uhr auf diese Meldung um, „Löschen“ räumt den Platz auf den gewählten Uhren. Ein freier Platz hat weder etwas zu zeigen noch zu löschen und bekommt deshalb kein Menü."),
        .absatz("Am Zeiger erscheint zusätzlich ein rotes ⊗ in der Ecke des Blocks, solange der Zeiger darüber steht — so wie Safari das Schließzeichen seiner Tabs zeigt. Am Finger gibt es kein Überfahren, und ein Zeichen, das immer dasteht, sähe aus wie der Wackelmodus des Home-Bildschirms."),
    ]

    /// Die eigene Standzeit einer Anzeige. Das Feld heisst am Mac „Dauer (Sek.)“
    /// und am iPhone „Dauer … s“ — die Sache dahinter ist dieselbe (`duration`
    /// im Rahmen).
    public static let dauer: [Hilfebaustein] = [
        .absatz("Der Unterschied zwischen „Dauer“ und „Seitenwechsel“ ist die Reichweite. Die Uhr blättert durch alles, was auf ihr steht — Uhrzeit, Temperatur, die fünf Meldungen. Wie schnell sie das tut, sagt der Seitenwechsel, und er gilt für alle. Die Dauer reist dagegen mit einer einzelnen Meldung mit und gibt ihr eine eigene Standzeit; leer oder 0 heißt keine Angabe, dann bleibt es beim Seitenwechsel."),
        .absatz("Wie beides zusammenwirkt, ist nicht geklärt — ob die Dauer den Seitenwechsel für diese Anzeige überschreibt oder der kleinere Wert gewinnt, sagt die Herstellerdokumentation nicht (Gerätereferenz, §4.4)."),
    ]

    /// Umlaute und Sonderzeichen. Dass die Geraeteschrift sie nicht kennt, ist
    /// eine Eigenschaft der Uhr; ob die App davor warnt, ist es nicht — der
    /// Warnsatz bleibt deshalb bei der Oberflaeche, die wirklich warnt.
    public static let zeichen: [Hilfebaustein] = [
        .ueberschrift("Zeichen: Umlaute und Sonderzeichen"),
        .absatz("An die Ulanzi-Werksfirmware wird der Text nicht als Zeichenkette verschickt, sondern von der App selbst in Pixel gerastert — deshalb gehen dort auch „ä“, „ö“, „ü“ und „ß“, und die Vorschau zeigt genau das, was gesendet wird: stehend, wenn der Text steht, laufend, wenn er läuft."),
        .absatz("Setzt die Uhr selbst — bei AWTRIX NG immer, bei der Werksfirmware nur, wenn das Kommandozeilenwerkzeug mit `--geraeteschrift` schickt —, gilt ihre eingebaute Schrift, und die kennt weder Umlaute noch die meisten Satzzeichen (Gerätereferenz, §1)."),
    ]

    /// Die Schriftauswahl und die drei mitgelieferten Pixelschriften. Beide
    /// Oberflaechen bieten dieselben acht Namen an (`Schriften.auswahl` im
    /// Kern), und warum es drei eigene Pixelschriften gibt, haengt an der Uhr,
    /// nicht am Geraet in der Hand.
    public static let schriftart: [Hilfebaustein] = [
        .ueberschrift("Schriftart"),
        .absatz("Bei „Schriftart“ stehen nicht alle installierten Schriften zur Wahl, sondern eine kurze, geprüfte Auswahl — bei 16 Pixeln Displayhöhe fällt kaum eine Schrift sauber aufs Raster, die meisten proportionalen Schriften wirken bei dieser Größe eher wie ein Brei aus Pixeln."),
        .absatz("Vorgabe ist „Silkscreen“, eine mitgelieferte, eigens fürs 8-Pixel-Raster gezeichnete Schrift — anders als die eingebaute Gerätschrift kann sie Umlaute und „ß“; dasselbe gilt für „Micro 5“ und „Tiny5“, zwei weitere mitgelieferte Pixelschriften. Die drei unterscheiden sich in der Wirkung:"),
        .punkte([
            "„Micro 5“ ist die schmalste und bringt am meisten Text stehend aufs Display, ohne zu laufen.",
            "„Silkscreen“ ist die klassische Pixeloptik, gut lesbar.",
            "„Tiny5“ wirkt bei großer Größe kräftig und plakativ.",
        ]),
    ]

    /// Die Groessenwahl. Seit die durchgesehene Schriftprobe je Schrift eine
    /// eigene Liste ergibt (`Pixelgroessen.abgesegnet`), gilt dieselbe Regel auf
    /// beiden Oberflaechen — deshalb hier und nicht zweimal.
    public static let groesse: [Hilfebaustein] = [
        .ueberschrift("Größe"),
        .absatz("„Größe“ bietet nicht jede Zahl an, sondern je Schrift eine eigene Liste:"),
        .punkte([
            "**Micro 5** — 10, 14 und 16 Pixel.",
            "**Silkscreen** und **Tiny5** — 7, 8, 9, 10, 12, 14 und 16 Pixel.",
            "**Alle anderen Schriften** — der volle Bereich von 6 bis 16 Pixel.",
        ]),
        .absatz("Die Lücken in den ersten drei Listen sind kein Versehen. Eine Pixelschrift ist für eine bestimmte Größe gezeichnet; dazwischen franst sie ohne Kantenglättung aus, und welche Größen das trifft, folgt keiner Regel. Angeboten wird deshalb, was beim Durchsehen der Schriftprobe bestanden hat — mit den Augen entschieden, nicht gerechnet."),
        .absatz("Wechselst du die Schrift und die eingestellte Größe steht nicht auf ihrer Liste, springt sie auf die nächstgelegene: 15 wird bei Silkscreen zu 14, nicht zu 7. Eine Größe, die auf keiner Liste steht, bleibt eingestellt, bis du selbst eine andere wählst."),
    ]

    /// Micro 5 bei mittleren Groessen — eine Eigenschaft der Schrift.
    public static let microFuenf: [Hilfebaustein] = [
        .absatz("Micro 5 füllt die sechzehn Zeilen des Displays erst bei 16 Pixeln; bei 10 und 14 bleibt oben und unten Platz. Die Größen dazwischen stehen nicht zur Wahl — dort zeigt das Zeichenbild Lücken."),
    ]

    /// Fett und Grossbuchstaben. Beide Oberflaechen rechnen mit denselben zwei
    /// Pruefungen (`Textraster.kannFett`, `Textraster.kannKleinbuchstaben`) und
    /// sperren dieselben Knoepfe.
    public static let fettUndGross: [Hilfebaustein] = [
        .ueberschrift("Fett und Großbuchstaben"),
        .absatz("„Fett“ kann ausgegraut sein, und zwar je nach Schrift: Die App rastert beim Wechsel einmal mit und einmal ohne fetten Schnitt und vergleicht — ändert sich nichts, hat die Schrift bei dieser Größe keinen, und ein Knopf ohne Wirkung ist schlimmer als keiner. Von den angebotenen Schriften trifft das auf die meisten zu; nur Menlo und PT Mono haben einen echten fetten Schnitt."),
        .absatz("Nach demselben Verfahren ist „Großbuchstaben“ bei Silkscreen gesperrt: Sie kennt überhaupt nur Versalien, der Schalter bliebe folgenlos."),
        .absatz("„Großbuchstaben“ lässt das Eingabefeld selbst unangetastet — umgewandelt wird erst beim Senden bzw. für die Vorschau. Aus „ß“ wird dabei „SS“; „Ä“, „Ö“ und „Ü“ bleiben Umlaute. Setzt die Uhr den Text selbst, ist der Schalter mit Vorsicht zu genießen: Belegt ist bisher nur, dass die Gerätschrift Kleinbuchstaben und Ziffern kennt — ob sie auch Versalien zeigt, hat noch niemand nachgesehen (Gerätereferenz, §1)."),
    ]

    /// Rand und Abstand. Beide gibt es auf beiden Geraeten mit demselben
    /// Wertebereich und derselben Vorgabe; gerechnet wird in `Meldungsbau`.
    public static let randUndAbstand: [Hilfebaustein] = [
        .ueberschrift("Rand"),
        .absatz("„Rand“, 0 bis 3, Vorgabe 1: die Zahl Zeilen, die bei „oben“ und „unten“ frei bleiben — bei „mittig“ ist er gesperrt, dort hat er keinen Sinn."),
        .absatz("Ihn braucht es, weil bündig je nach Schrift verschieden aussieht: Manche bringen über der Großbuchstabenhöhe Platz mit, andere nicht, und dieselbe Ausrichtung wirkt dann bei der einen luftig und bei der anderen gequetscht. Der Rand macht den Eindruck davon unabhängig und ist auf den vorhandenen Platz gedeckelt — ein Text, der schon fast die volle Höhe füllt, wird nicht beschnitten."),
        .ueberschrift("Abstand"),
        .absatz("Ganz rechts liegt „Abstand“, 0 bis 3, Vorgabe 1 — wirksam dort, wo die App selbst rastert."),
        .absatz("„Abstand“ ist wörtlich die Zahl leerer Spalten zwischen zwei Zeichen — 0 heißt Tinte an Tinte, 1 die Vorgabe, 2 und 3 sind luftiger —, und weil sie sich aus der Tinte ergibt statt aus der Schrift, wird derselbe Text bei gleicher Schrift und Größe meist schmaler als früher, es passt also mehr aufs Display."),
        .absatz("Hier rastert die App nämlich jedes Zeichen einzeln und setzt es nach seiner Tinte ans vorige, statt nach der Vorschubbreite der Schrift: Die ist für gedruckte Größen gemacht und fällt auf sechzehn Pixeln mal zu eng, mal zu weit aus, ein fester Zuschlag verschiebt das Problem nur."),
        .absatz("Setzt die Uhr den Text selbst, bleibt „Abstand“ ohne Wirkung: Sie bringt ihren eigenen, festen Zeichenabstand als `charSpacing` mit (Gerätereferenz, §4.3), unabhängig von dieser Einstellung."),
    ]

    /// Die verfuegbare Breite und was die Ausrichtung darin tut.
    public static let breiteUndAusrichtung: [Hilfebaustein] = [
        .ueberschrift("Breite und Ausrichtung"),
        .absatz("Ohne Icon ist die verfügbare Breite die vollen 52 Pixel des Displays, mit einem 8×8-Icon 42, weil es die ersten zehn Spalten belegt — daran hängt auch die Entscheidung, ob der Text steht oder läuft, und der fette Schnitt zählt dabei mit. Steht er, richten die waagrechten Ausrichtungsknöpfe ihn innerhalb dieser Breite aus, die senkrechten innerhalb der 16 Zeilen, gerechnet über die tatsächlich gesetzte Höhe, nicht die Schriftgröße."),
        .abbildung(.ausrichtung),
    ]

    /// Der Unterschied zwischen einem Icon und einer ganzen Anzeige.
    ///
    /// Gehoert hierher, seit das Telefon beide im selben Blatt zeigt: Dort
    /// stehen sie als zwei Gruppen nebeneinander, und wer den Unterschied
    /// nicht kennt, waehlt eine Anzeige als Icon. Am Schreibtisch ist er
    /// ebenso wahr — die Uebersicht gruppiert genauso.
    public static let iconOderAnzeige: [Hilfebaustein] = [
        .absatz("Ein Icon und eine Anzeige sind zweierlei. Ein Icon steht **neben** dem Text und ist 8 × 8 oder 16 × 16 Pixel groß; eine 52 × 16-Anzeige **ist** das ganze Display und ersetzt Text und Icon. Deshalb wird ein Icon gewählt und eine Anzeige geschickt."),
    ]

    /// Wie das Icon in der Vorschau und in der Laufschrift behandelt wird.
    /// Beide Vorschauen spielen animierte Icons ab (`VorschauView`,
    /// `VorschauiOS`), und das Mitscrollen gibt es auf beiden.
    public static let iconImLauf: [Hilfebaustein] = [
        .absatz("Die Vorschau darunter zeigt ein gewähltes Icon an derselben Stelle mit, an der die Uhr es zeigt — so sieht man vor dem Senden, ob Icon und Text zusammenpassen. Ist das Icon animiert, spielt die Vorschau es probeweise in Schleife ab, so wie auch die Uhr animierte Icons abspielt (am Gerät bestätigt, Gerätereferenz, §4.2)."),
        .absatz("Läuft der Text beim Weg „als Pixel“, wird das Icon in die Laufschrift hineingerechnet, statt als zweites Bild danebenzustehen — ob die Uhr zwei Bilder in einem Rahmen nebeneinander zeichnet, hat niemand geprüft, und so stellt sich die Frage nicht. Es steht dann fest links, der Text läuft rechts daneben durch, und seine Spalten bleiben schwarz, damit der Text nicht hinter ihm durchblitzt."),
        .absatz("Wer es lieber mitwandern lässt, schaltet „Icon mitscrollen“ ein: Dann steht es am Anfang des Textes und läuft mit hinaus, und der Text nutzt die vollen 52 Spalten. Ein animiertes Icon spielt in beiden Fällen weiter ab. Setzt die Uhr den Text selbst, gibt es dieses Mitscrollen nicht: Das Icon steht dort immer fest links, gleich ob und wie schnell sie den Text daneben laufen lässt."),
    ]

    /// Woher die Anzeigenliste kommt und warum der Unterschied zaehlt. Gemeldet
    /// schlaegt gemerkt — `AppZustand.anzeigenDerAktivenMitQuelle` fuer beide.
    public static let verlaufHerkunft: [Hilfebaustein] = [
        .ueberschrift("Auf der Uhr und zuletzt geschickt"),
        .absatz("Unter den fünf Blöcken steht eine Liste, die zweierlei vereint: die eigenen Sendungen und das, was sonst noch auf der angesehenen Uhr liegt. Eine eigene Zeile steht in der Reihenfolge der Auskunft — vorn das Icon als Bild, daneben der Text in der Farbe, in der er geschickt wurde, darunter die Empfänger, rechts Zeit und Platz. Hat eine Sendung keinen Text, steht dort der Name ihres Icons. Die Empfänger bleiben weg, solange nur eine Uhr eingerichtet ist: Ihr Name wäre in jeder Zeile dasselbe Wort. Eine Meldung, die gerade auf der Uhr steht, trägt rechts ein Bildschirmzeichen."),
        .absatz("Von fremden Anzeigen weiß die App nur den Namen: Die Uhr nennt ihre Anzeigen, verrät aber nicht, was darin steht. Solche Zeilen haben deshalb dieselbe Form, nur bleiben die Felder leer, zu denen es keine Auskunft gibt."),
        .absatz("Ein Druck auf eine eigene Sendung stellt sie wieder her — Text, Schrift, Farbe, Ausrichtung, Tempo und Icon. Ein Wischen nach links löscht: bei einer eigenen Zeile den Eintrag, bei einer Anzeige auf der Uhr die Anzeige. Ein Wischen von der anderen Seite schaltet die Uhr auf diese Anzeige um. Je Uhr getrennt: Die Liste wechselt mit, wenn man eine andere Uhr ansieht."),
    ]

    /// Wie die Liste zustande kommt: die Uhr veroeffentlicht, die App hoert mit —
    /// und fragt zusaetzlich selbst nach. Beides ist dieselbe Auskunft derselben
    /// Quelle; der Inhalt eines Platzes gehoert ausdruecklich nicht dazu.
    public static let verlaufEntstehung: [Hilfebaustein] = [
        .ueberschrift("Wie die Liste entsteht"),
        .absatz("Die App fragt die Uhr unmittelbar über HTTP, welche Anzeigen auf ihr stehen (`GET /api/customList`, Gerätereferenz §5.7) — beim Start, beim Zurückkommen aus dem Hintergrund und bei jedem „Abfragen“ unter „Einstellungen“. Das gilt in beiden Betriebsarten: Dafür braucht es keinen MQTT-Broker, und die Auskunft ist sofort da, statt auf eine Meldung zu warten, die vielleicht nie kommt."),
        .absatz("Im MQTT-Betrieb kommt ein zweiter Weg dazu, und er führt zur selben Quelle: Die Uhr veröffentlicht ihre Anzeigenliste von sich aus über das Thema `<präfix>/customList`, und die App hört dort dauerhaft mit, sobald die Uhr ein Präfix hat (Gerätereferenz, §3.5). Im HTTP-Betrieb gibt es das nicht — die Uhr reicht ihre HTTP-Vorgänge nicht über MQTT weiter."),
        .absatz("Dafür gibt es dort ein Drittes, und es ist die verlässlichste Auskunft von allen: Jede eigene Sendung und jede eigene Löschung quittiert die Uhr. Ein so gebuchter Name ist keine Vermutung, sondern von der Uhr bestätigt."),
        .absatz("Gefragt wird dabei immer nur, **welche** Anzeigen es gibt. Was auf einem Platz steht, verrät die Uhr auf keinem dieser Wege; belegt oder frei ist damit Tatsache, der Inhalt bleibt geraten."),
        .absatz("Steht über der Liste „von dieser App angelegt“, hat keiner der Wege etwas ergeben: die Uhr aus oder nicht erreichbar, und nichts mitgehört. Dann zeigt die Liste die eigene Buchführung und sagt es — was die Uhr selbst gesagt hat, wird nicht mit dem Alter zur Tatsache."),
        .absatz("Ob die Uhr gerade am Broker hängt, meldet sie über `<präfix>/status` (Gerätereferenz, §3.4). Das lässt sich nicht abfragen — es kommt, wenn die Uhr es schickt, und nur im MQTT-Betrieb."),
    ]

    /// Was ein Loeschen erreicht und was nicht — dieselbe leere Nutzlast, dieselbe
    /// Blockade durch eine stehende Anzeige.
    public static let verlaufLoeschen: [Hilfebaustein] = [
        .absatz("Ging dieselbe Anzeige über die Zielauswahl auch an andere Uhren, steht sie dort weiter und muss bei jeder einzeln gelöscht werden. Eine stehende, gerade gezeigte Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder unter demselben Namen ersetzt wird — das ist der häufigste Grund, warum eine frisch gesendete Anzeige nicht auftaucht."),
    ]

    /// Das Protokoll und was darin aufgezeichnet wird. `AppZustand.log` schreibt
    /// es fuer beide Oberflaechen. Was nur eine von beiden ueberhaupt ausloesen
    /// kann — am Mac die Aenderung des Seitenwechsels —, steht dort und nicht
    /// hier; deshalb zwei Konstanten mit einem Platz dazwischen.
    public static let protokollListe: [Hilfebaustein] = [
        .ueberschrift("Protokoll"),
        .absatz("Darunter steht das Protokoll — mit Uhrzeit, älteste Zeile oben, neueste unten. Aufgezeichnet wird:"),
        .punkte([
            "jede Abfrage einer Uhr",
            "jedes Umschalten und Löschen einer Anzeige",
            "jede Prüfung des MQTT-Brokers",
            "jede Meldung, die von einer Uhr hereinkommt",
        ]),
    ]

    /// Was „Leeren“ tut, und warum Fehler zusaetzlich im Protokoll stehen.
    public static let protokollLeeren: [Hilfebaustein] = [
        .absatz("„Leeren“ macht die Liste leer. Fehler erscheinen zusätzlich zur Meldung auch hier, damit sie nach dem Wegklicken nicht verloren sind."),
    ]

    /// Die Stille von MQTT 3.1.1: Eine abgelehnte Veroeffentlichung meldet das
    /// Protokoll nicht zurueck. Gilt ueberall, wo dieselben Bytes hinausgehen.
    public static let fehlerStille: [Hilfebaustein] = [
        .ueberschrift("Was die App meldet — und was nicht"),
        .absatz("**Das hängt an der Betriebsart der Uhr, und der Unterschied ist groß.**"),
        .absatz("Im HTTP-Betrieb antwortet die Uhr auf jede Sendung, jede Löschung und jedes Umschalten. Bleibt die Meldung aus, hat sie angenommen; weist sie etwas ab — etwa ein Umschalten auf eine Anzeige, die es nicht gibt —, steht der Grund in der Meldung, mit dem Namen der Uhr davor. Und antwortet sie gar nicht, steht auch das da, statt dass die Sendung stumm verschwindet."),
        .absatz("Im MQTT-Betrieb gibt es das nicht: MQTT in der hier verwendeten Version 3.1.1 meldet eine abgelehnte Veröffentlichung nicht zurück. Egal ob das Konto keine Schreibrechte auf das Thema hat oder niemand darauf lauscht — die App bekommt kein Fehlersignal, keine Warnung, nichts unterscheidet das von einer erfolgreichen Sendung. Erscheint nichts auf der Uhr, ist das also kein Rätsel dieser App, sondern die normale Stille von MQTT 3.1.1."),
        .absatz("Alles bis zur Anmeldung am MQTT-Broker meldet die App dagegen sehr wohl: falsches Kennwort, unerreichbarer Broker, Zeitüberschreitung, fehlende Zugangsdaten."),
    ]

    /// Broker-Fehler oder Uhr-Fehler: Die Meldung selbst sagt, welche Suche
    /// gemeint ist (`AppZustand.zusammengefasst`).
    public static let fehlerWelche: [Hilfebaustein] = [
        .ueberschrift("Welche Meldung ist gemeint?"),
        .absatz("Das sind zwei verschiedene Suchen, und die Meldung sagt, welche gemeint ist. Nennt sie den MQTT-Broker mit Adresse und Port („Der Broker 192.0.2.10:1883 antwortet nicht.“), ist die App gar nicht bis dorthin gekommen — dann hilft nur „Einstellungen“ → „Broker“ → „Verbindung prüfen“, und keine Uhr ist daran schuld; diese Meldung erscheint deshalb auch nur einmal, selbst wenn an fünf Uhren gesendet wurde. Beginnt die Meldung dagegen mit dem Namen einer Uhr, betrifft sie genau diese und die übrigen wurden beliefert."),
    ]

    /// Die vier Punkte der Reihe nach. Alle vier gibt es auf beiden Geraeten.
    public static let fehlerReihe: [Hilfebaustein] = [
        .ueberschrift("Der Reihe nach prüfen"),
        .absatz("Die ersten drei Punkte betreffen den MQTT-Betrieb. Im HTTP-Betrieb erübrigen sie sich: Dort gibt es kein Präfix, keine Anmeldung und keine Schreibrechte auf ein Thema — was schiefgeht, sagt die Meldung selbst. Bleibt der vierte."),
        .punkte([
            "Erstens das Präfix — unter „Einstellungen“ „Abfragen“ noch einmal ausführen und mit dem tatsächlichen Präfix vergleichen; es ist nicht das in Ulanzi Studio eingetragene.",
            "Zweitens, ob die Uhr überhaupt beim MQTT-Broker angemeldet ist — das Häkchen- oder Warndreieck-Symbol in derselben Zeile.",
            "Drittens, ob das Broker-Konto auf dieses Thema schreiben darf. Das steht in der Rechtedatei des Brokers, nicht in dieser App, und lässt sich nur am Broker-Protokoll ablesen.",
            "Viertens, ob unter „Verlauf“ noch eine alte, stehende Anzeige blockiert — die zuerst löschen oder unter demselben Namen ersetzen.",
        ]),
    ]
}
