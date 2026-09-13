import TC002Core

/// Die Absätze der Hilfe, die auf beiden Geräten gelten.
///
/// Jeder Satz hier muss für **beide** Oberflächen wahr sein — was nur einen
/// Knopf einer bestimmten Oberfläche beschreibt, gehört in deren eigenes
/// Dokument (`HilfeView` am Mac, `HilfeiOS` am iPhone). Geteilt ist, was an
/// der Uhr, am Protokoll oder am gemeinsamen Kern hängt.
///
/// Warum als Konstanten und nicht zweimal geschrieben: Der deutsche Wortlaut
/// **ist** der Übersetzungsschlüssel. Ein zweiter Satz mit derselben Aussage
/// wäre ein zweiter Schlüssel und müsste ein zweites Mal übersetzt werden —
/// und könnte beim nächsten Mal nur an einer der beiden Stellen berichtigt
/// werden.
public enum HilfeInhalt {
    /// Was die App ueberhaupt tut und wo die Nachrichten langlaufen. Der Broker
    /// steht zwischen App und Uhr, gleich auf welchem Geraet die App laeuft.
    public static let wasEsTut: [Hilfebaustein] = [
        .absatz("MQTT-TC002 schickt Anzeigen an eine oder mehrere Ulanzi-TC002-Pixeluhren. Es tut das nicht direkt: alle Nachrichten laufen über den MQTT-Broker im Haus, an den auch die Uhren angeschlossen sind."),
    ]

    /// Womit die App beginnt, solange nichts eingerichtet ist
    /// (`AppZustand.eingerichtet`). Der Satz gilt fuer beide Oberflaechen: Am
    /// Mac und auf dem iPad steht der Bereich „Einstellungen" vorn, auf dem
    /// Telefon geht sein Blatt von selbst auf. Beide Male ist es derselbe
    /// Grund und dieselbe Auskunft — deshalb ein Absatz und nicht zwei.
    public static let startOhneEinrichtung: [Hilfebaustein] = [
        .absatz("Solange keine Uhr eingetragen ist oder keine Brokeradresse, beginnt die App bei den Einstellungen statt bei „Senden“ — dort gäbe es ohne beides weder eine Vorschau noch ein Ziel. Gesperrt ist dabei nichts: Wer will, geht sofort weiter. Sobald beides eingetragen ist, startet sie wieder bei „Senden“."),
    ]

    /// Das Themen-Praefix und woher es kommt. Beide Oberflaechen haben denselben
    /// Knopf, dieselben zwei Symbole und dieselbe Regel: Das Praefix wird
    /// ermittelt, nie eingetippt (`AppZustand.abfragen`).
    public static let uhrAbfragen: [Hilfebaustein] = [
        .ueberschrift("Abfragen"),
        .absatz("„Abfragen“ holt von der Uhr selbst das Themen-Präfix und die MAC-Adresse und zeigt das Präfix monospaced in der Zeile an. Das Häkchen- oder Warndreieck-Symbol daneben sagt, ob die Uhr gerade beim Broker angemeldet ist — das ist aber nur die Anmeldung, keine Aussage darüber, ob die App auf das richtige Thema schreiben darf (mehr dazu unter „Wenn nichts erscheint“)."),
        .absatz("Das Präfix lässt sich absichtlich nicht von Hand eintragen: es ist nicht dasselbe wie das in Ulanzi Studio eingestellte, die Firmware hängt die letzten vier Stellen der MAC-Adresse an. „Abfragen“ ermittelt das wirksame Präfix selbst. Hat die Uhr gar kein Präfix eingestellt, sagt „Abfragen“ das — statt ein Thema zu bilden, auf das sie nie hört."),
    ]

    /// Wo das Kennwort liegt — im Schluesselbund, nicht in den App-Einstellungen
    /// (`Einstellungen.kennwort`). Wann es gesichert wird, ist dagegen je
    /// Oberflaeche verschieden und steht dort.
    public static let brokerKennwort: [Hilfebaustein] = [
        .absatz("Das Kennwort liegt im Schlüsselbund und nicht, wie die übrigen Felder, in den App-Einstellungen."),
    ]

    /// Was die Brokerpruefung tut und was ihr Ergebnis nicht bedeutet. Beide
    /// Oberflaechen rufen dieselbe `AppZustand.brokerSichernUndPruefen`.
    public static let brokerPruefen: [Hilfebaustein] = [
        .absatz("„Sichern und prüfen“ schreibt Adresse, Port, Benutzer und Kennwort ausdrücklich fest und fragt danach den Broker, ob er die Anmeldung annimmt — das dauert bis zu acht Sekunden und läuft unter einer eigenen Client-Kennung, damit dabei keine laufende Sendung hinausfliegt."),
        .absatz("Eine angenommene Anmeldung heißt aber nur: Benutzername und Kennwort stimmen. Ob die Uhr die Nachricht am Ende auch zeigt, hängt zusätzlich vom richtigen Präfix und davon ab, ob das Konto auf das Thema schreiben darf — beides meldet MQTT 3.1.1 nicht zurück (siehe „Wenn nichts erscheint“). Das Ergebnis der Prüfung steht auch im Protokoll unter „Verlauf“."),
    ]

    /// Die fuenf festen Plaetze und die drei Blockzustaende. Was ein Block zeigt,
    /// rechnet `AppZustand.slotzustand` fuer alle Oberflaechen gleich, und
    /// `Slotblock` (TC002Ansichten) zeichnet es fuer alle gleich — der Absatz
    /// gehoert deshalb dorthin, wo auch der Block herkommt.
    public static let fuenfPlaetze: [Hilfebaustein] = [
        .absatz("„Senden“ setzt aus Text, Farbe und wahlweise einem Icon eine Anzeige zusammen und schickt sie an die Uhr. In der Mitte stehen fünf Blöcke, je einer für einen der fünf festen Plätze der Uhr — die Ziffer unter dem Block sagt, welcher es ist, auf dem Gerät heißen sie `meldung1` bis `meldung5`. Ein Antippen wählt den Platz, unter dem die Anzeige danach bei „Verlauf“ auftaucht."),
        .absatz("Jeder Block zeigt einen von drei Zuständen, an der Form erkennbar, nicht nur an der Farbe:"),
        .tabelle([
            ("frei", "gestrichelter, leerer Rahmen — kein Name auf diesem Platz."),
            ("belegt, Inhalt bekannt", "die Pixel, verkleinert. Sie stammen entweder aus einer mitgelesenen Sendung oder aus dem, was sich diese Installation für den Platz gemerkt hat — im zweiten Fall ist es eine Erinnerung und kann überholt sein."),
            ("belegt, Inhalt unbekannt", "grau gefüllter Block mit dem Wort „belegt“, ohne Pixel."),
        ]),
        .absatz("Auf denselben Platz senden ersetzt, was dort steht; ein anderer Platz tritt daneben, und die Uhr blättert zwischen den belegten Plätzen. Das gilt für jede Zieluhr: ein Platz zählt schon als belegt, wenn ihn nur eine davon kennt — die Blöcke zeigen dabei immer den Stand der gerade aktiven Uhr."),
    ]

    /// Woher die Blöcke ihr Wissen haben: mitgelesen oder gemerkt. Gilt auf
    /// beiden Geraeten, weil Mitlesen (`AppZustand.gemeldet`) und Slotgedaechtnis
    /// derselbe Kern sind. Der zweite Absatz haelt fest, warum ein frisch
    /// gestarteter Mitleser zunaechst schweigt — eine Eigenschaft von MQTT 3.1.1,
    /// keine der Oberflaeche.
    public static let blockwissenAnfang: [Hilfebaustein] = [
        .ueberschrift("Woher die Blöcke wissen, was belegt ist"),
        .absatz("Die Uhr selbst verrät über ihre Anzeigenliste nur Namen, nie den Inhalt eines Platzes (Gerätereferenz, §3.5) — belegt oder frei ist damit gesichert, der Inhalt nicht. Den gewinnt die App stattdessen daraus, dass sie beim Broker jede Sendung an die Uhr mitliest, gleich von wem sie kommt: von dieser App, vom Kommandozeilenwerkzeug, von einem Kurzbefehl oder von einem zweiten Programm."),
        .absatz("Mitlesen heißt aber: nur, was gesendet wird, solange die App verbunden ist. Ohne aufbewahrte (RETAIN-)Nachrichten liefert MQTT einem frisch verbundenen Abonnenten keinen Rückstand — das ist kein Fehler dieser App, sondern die normale Stille von MQTT 3.1.1 (siehe auch „Wenn nichts erscheint“). Was diese Installation unter „Senden“ selbst geschickt hat, zeigt der Block nach einem Neustart trotzdem: Dafür merkt sie sich je Platz die Regler und rechnet das Bild daraus neu."),
    ]

    /// Die drei gewoehnlichen Ursachen fuer einen Block ohne Inhalt, und warum
    /// eigene Sendungen anders behandelt werden. Steht zwischen den beiden
    /// Haelften ein geraetespezifischer Absatz (am Mac der ueber Gemaltes),
    /// deshalb zwei Konstanten statt einer.
    public static let blockwissenSchluss: [Hilfebaustein] = [
        .absatz("Ohne Inhalt bleiben deshalb die Plätze, zu denen es hier nichts zu merken gab — sie zeigen „belegt“, bis dort das nächste Mal etwas mitgelesen oder etwas Merkbares gesendet wird."),
        .absatz("„Belegt, Inhalt unbekannt“ ist einer von drei gewöhnlichen, harmlosen Fällen: Die Anzeige stammt von einem anderen Gerät oder einer anderen Installation dieser App — dann wurde sie hier weder mitgelesen noch gemerkt. Oder sie ist eine Laufschrift oder ein von der Uhr selbst gesetzter Text (Weg „als Text“) eines fremden Absenders: Aus so einer Nutzlast lässt sich kein Standbild zurückrechnen. Oder sie wurde über die HTTP-Schnittstelle der Uhr angelegt und ist am Broker vorbeigegangen (Gerätereferenz, §3.5)."),
        .absatz("Für die eigenen Sendungen gilt das nicht: Dort rechnet die App das Bild aus dem gemerkten Stand, nicht aus der Nutzlast. Eine selbst geschickte Laufschrift zeigt der Block deshalb stehend, mit ihren ersten 52 Pixeln, und beim Weg „als Text“ zeigt er sie in der Schrift dieser App, während die Uhr ihre eigene, eingebaute setzt. Der Block sagt in diesen Fällen, was auf dem Platz liegt — nicht, wie es auf der Uhr aussieht."),
        .absatz("Auch ein Block mit bekanntem Inhalt stellt beim Antippen nicht immer die Regler wieder her: Das gelingt nur, wenn diese Installation die Sendung selbst mitgelesen hat und der Platz seither nicht von anderer Stelle überschrieben wurde — sonst wählt das Antippen nur den Platz, ohne die Regler zu verändern."),
    ]

    /// Wann ein Text steht und wann er laeuft — `Meldungsbau.passt` entscheidet
    /// das auf beiden Geraeten gleich. Wo die Wahl sitzt, sagt jede Oberflaeche
    /// selbst: am Mac ueber dem Textfeld, am iPhone im Blatt „Format“.
    public static let wegeRegel: [Hilfebaustein] = [
        .absatz("Bei „als Pixel“ entscheidet die App selbst, ob der Text stehenbleibt oder durchläuft — es gibt dafür keinen eigenen Schalter."),
        .tabelle([
            ("als Pixel", "Umlaute und „ß“ gehen; die App entscheidet selbst — passt der Text, bleibt er stehen, sonst läuft er als GIF."),
            ("als Text", "nur `%`, `.`, `-` und `:` als Sonderzeichen; läuft von selbst durch, wenn nötig, ohne dass die App ein GIF bauen muss."),
        ]),
        .absatz("Sie rechnet die Breite des gesetzten Textes ohnehin aus, und daran hängt die Regel: Passt er in die verfügbare Breite (52 Pixel, mit Icon 42), geht er als starres Pixelbild an die Uhr und bleibt stehen — klein, schnell, exakt. Passt er nicht, rastert die App den Lauf selbst und schickt ihn als animiertes GIF, das die Uhr abspielt (Gerätereferenz, §4.2a): Der Text läuft durch, mit Umlauten und in der gewählten Schriftart."),
    ]

    /// Warum eine stehende Anzeige alles andere blockiert — eine Eigenschaft der
    /// Uhr, nicht der Oberflaeche.
    public static let blockierendeAnzeige: [Hilfebaustein] = [
        .absatz("Egal wie viele Plätze belegt sind: Eine gerade angezeigte, stehende Anzeige blockiert alle anderen Inhalte, bis sie gelöscht oder ersetzt wird — deshalb ist „auf denselben Platz senden“ oft das, was man eigentlich will."),
    ]

    /// Der Papierkorb neben den fuenf Bloecken. Steht auf beiden Geraeten an
    /// derselben Stelle und ist bei leerem Platz gesperrt.
    public static let papierkorb: [Hilfebaustein] = [
        .absatz("Der Papierkorb rechts neben der Platzwahl löscht den gewählten Platz auf den gewählten Uhren. Er ist gesperrt, solange der Platz leer ist."),
    ]

    /// Die eigene Standzeit einer Anzeige. Das Feld heisst am Mac „Dauer (Sek.)“
    /// und am iPhone „Dauer … s“ — die Sache dahinter ist dieselbe (`duration`
    /// im Rahmen).
    public static let dauer: [Hilfebaustein] = [
        .absatz("Die Dauer gibt der Uhr eine eigene Standzeit für diese eine Anzeige mit; leer oder 0 bedeutet keine Angabe, dann entscheidet allein der Seitenwechsel. Wie beides zusammenwirkt, ist nicht geklärt — ob die Dauer den Seitenwechsel für diese Anzeige überschreibt oder der kleinere Wert gewinnt, sagt die Herstellerdokumentation nicht (Gerätereferenz, §4.4)."),
    ]

    /// Umlaute und Sonderzeichen. Dass die Geraeteschrift sie nicht kennt, ist
    /// eine Eigenschaft der Uhr; ob die App davor warnt, ist es nicht — der
    /// Warnsatz bleibt deshalb bei der Oberflaeche, die wirklich warnt.
    public static let zeichen: [Hilfebaustein] = [
        .ueberschrift("Zeichen: Umlaute und Sonderzeichen"),
        .absatz("Beim Weg „als Pixel“ wird der Text nicht als Zeichenkette verschickt, sondern von der App selbst in Pixel gerastert — deshalb gehen dort auch „ä“, „ö“, „ü“ und „ß“, und die Vorschau zeigt genau das, was gesendet wird: stehend, wenn der Text steht, laufend, wenn er läuft."),
        .absatz("Beim Weg „als Text“ ist es umgekehrt: Die Uhr setzt den Text mit ihrer eigenen, eingebauten Schrift, und die kennt weder Umlaute noch die meisten Satzzeichen — nur `%`, `.`, `-` und `:` gehen (Gerätereferenz, §1)."),
    ]

    /// Die Schriftauswahl und die drei mitgelieferten Pixelschriften. Beide
    /// Oberflaechen bieten dieselben acht Namen an (`SendenView.geeigneteSchriften`,
    /// `SendeniOS.schriften`), und warum es drei eigene Pixelschriften gibt,
    /// haengt an der Uhr, nicht am Geraet in der Hand.
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
        .absatz("„Größe“ bietet nicht jede Zahl an, sondern je Schrift eine Liste:"),
        .tabelle([
            ("Micro 5", "10, 14 und 16 Pixel"),
            ("Silkscreen", "7, 8, 9, 10, 12, 14 und 16 Pixel"),
            ("Tiny5", "7, 8, 9, 12, 15 und 16 Pixel"),
            ("alle anderen Schriften", "der volle Bereich 6 bis 16 Pixel"),
        ]),
        .absatz("Die drei Listen haben Lücken, und das ist kein Versehen: Eine Pixelschrift franst zwischen ihrer Entwurfsgröße und deren Vielfachen ohne Kantenglättung willkürlich aus, und welche Größen das trifft, folgt keiner Schrittweite. Angeboten wird deshalb, was beim Durchsehen der Schriftprobe bestanden hat — mit den Augen entschieden, nicht gerechnet: Die Messung dort kann eine Größe ausschließen, nie eine empfehlen."),
        .absatz("Für die übrigen Schriften gibt es keine solche Durchsicht; dort bleibt es beim vollen Bereich. Beim Wechsel der Schrift springt eine Größe, die auf der neuen Liste fehlt, auf die nächstgelegene — 15 wird bei Silkscreen zu 14, nicht zu 7. Eine eingestellte Größe, die auf keiner Liste steht, bleibt wählbar, bis man selbst eine andere wählt."),
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
        .absatz("Beim Weg „als Text“ sind Schriftart und Fett gesperrt: Die Uhr hat nur eine eingebaute Schrift und keinen fetten Schnitt, beides bliebe dort ohne Wirkung. Größe, Ausrichtung und Farbe wirken dort trotzdem weiter — sie gehen dann nicht mehr in unser Raster, sondern direkt als `fontHeight`, `align`, `valign` und `color` in den Textblock, den die Uhr selbst setzt (Gerätereferenz, §4.3)."),
        .absatz("Auch beim Weg „als Pixel“ kann „Fett“ ausgegraut sein, und zwar je nach Schrift: Die App rastert beim Wechsel einmal mit und einmal ohne fetten Schnitt und vergleicht — ändert sich nichts, hat die Schrift bei dieser Größe keinen, und ein Knopf ohne Wirkung ist schlimmer als keiner. Von den angebotenen Schriften trifft das auf die meisten zu; nur Menlo und PT Mono haben einen echten fetten Schnitt."),
        .absatz("Nach demselben Verfahren ist „Großbuchstaben“ bei Silkscreen gesperrt: Sie kennt überhaupt nur Versalien, der Schalter bliebe folgenlos."),
        .absatz("„Großbuchstaben“ gilt anders als Schriftart und Fett auf beiden Wegen gleich und lässt das Eingabefeld selbst unangetastet — umgewandelt wird erst beim Senden bzw. für die Vorschau. Auf dem Weg „als Text“ ist der Schalter mit Vorsicht zu genießen: Belegt ist bisher nur, dass die Gerätschrift Kleinbuchstaben und Ziffern kennt — ob sie auch Versalien zeigt, hat noch niemand nachgesehen (Gerätereferenz, §1). Aus „ß“ wird dabei „SS“, „Ä“, „Ö“ und „Ü“ bleiben Umlaute und fehlen dort in jedem Fall."),
    ]

    /// Rand und Abstand. Beide gibt es auf beiden Geraeten mit demselben
    /// Wertebereich und derselben Vorgabe; gerechnet wird in `Meldungsbau`.
    public static let randUndAbstand: [Hilfebaustein] = [
        .ueberschrift("Rand"),
        .absatz("„Rand“, 0 bis 3, Vorgabe 1: die Zahl Zeilen, die bei „oben“ und „unten“ frei bleiben — bei „mittig“ ist er gesperrt, dort hat er keinen Sinn."),
        .absatz("Ihn braucht es, weil bündig je nach Schrift verschieden aussieht: Manche bringen über der Großbuchstabenhöhe Platz mit, andere nicht, und dieselbe Ausrichtung wirkt dann bei der einen luftig und bei der anderen gequetscht. Der Rand macht den Eindruck davon unabhängig und ist auf den vorhandenen Platz gedeckelt — ein Text, der schon fast die volle Höhe füllt, wird nicht beschnitten."),
        .ueberschrift("Abstand"),
        .absatz("Ganz rechts liegt „Abstand“, 0 bis 3, Vorgabe 1 — anders als Großbuchstaben nur beim Weg „als Pixel“ wirksam."),
        .absatz("„Abstand“ ist wörtlich die Zahl leerer Spalten zwischen zwei Zeichen — 0 heißt Tinte an Tinte, 1 die Vorgabe, 2 und 3 sind luftiger —, und weil sie sich aus der Tinte ergibt statt aus der Schrift, wird derselbe Text bei gleicher Schrift und Größe meist schmaler als früher, es passt also mehr aufs Display."),
        .absatz("Hier rastert die App nämlich jedes Zeichen einzeln und setzt es nach seiner Tinte ans vorige, statt nach der Vorschubbreite der Schrift: Die ist für gedruckte Größen gemacht und fällt auf sechzehn Pixeln mal zu eng, mal zu weit aus, ein fester Zuschlag verschiebt das Problem nur."),
        .absatz("Beim Weg „als Text“ bleibt „Abstand“ ohne Wirkung: Dort rastert die Uhr selbst und bringt ihren eigenen, festen Zeichenabstand als `charSpacing` mit (Gerätereferenz, §4.3), unabhängig von dieser Einstellung."),
    ]

    /// Die verfuegbare Breite und was die Ausrichtung darin tut.
    public static let breiteUndAusrichtung: [Hilfebaustein] = [
        .ueberschrift("Breite und Ausrichtung"),
        .absatz("Ohne Icon ist die verfügbare Breite die vollen 52 Pixel des Displays, mit Icon 42, weil das Icon die ersten zehn Spalten belegt — daran hängt auch die Entscheidung, ob der Text steht oder läuft, und der fette Schnitt zählt dabei mit. Steht er, richten die waagrechten Ausrichtungsknöpfe ihn innerhalb dieser Breite aus, die senkrechten innerhalb der 16 Zeilen, gerechnet über die tatsächlich gesetzte Höhe, nicht die Schriftgröße."),
    ]

    /// Wie das Icon in der Vorschau und in der Laufschrift behandelt wird.
    /// Beide Vorschauen spielen animierte Icons ab (`VorschauView`,
    /// `VorschauiOS`), und das Mitscrollen gibt es auf beiden.
    public static let iconImLauf: [Hilfebaustein] = [
        .absatz("Die Vorschau darunter zeigt ein gewähltes Icon an derselben Stelle mit, an der die Uhr es zeigt — so sieht man vor dem Senden, ob Icon und Text zusammenpassen. Ist das Icon animiert, spielt die Vorschau es probeweise in Schleife ab, so wie auch die Uhr animierte Icons abspielt (am Gerät bestätigt, Gerätereferenz, §4.2)."),
        .absatz("Läuft der Text beim Weg „als Pixel“, wird das Icon in die Laufschrift hineingerechnet, statt als zweites Bild danebenzustehen — ob die Uhr zwei Bilder in einem Rahmen nebeneinander zeichnet, hat niemand geprüft, und so stellt sich die Frage nicht. Es steht dann fest links, der Text läuft rechts daneben durch, und seine Spalten bleiben schwarz, damit der Text nicht hinter ihm durchblitzt."),
        .absatz("Wer es lieber mitwandern lässt, schaltet „Icon mitscrollen“ ein: Dann steht es am Anfang des Textes und läuft mit hinaus, und der Text nutzt die vollen 52 Spalten. Ein animiertes Icon spielt in beiden Fällen weiter ab. Beim Weg „als Text“ gibt es dieses Mitscrollen nicht: Das Icon steht dort immer fest links, gleich ob und wie schnell die Uhr den Text daneben laufen lässt."),
    ]

    /// Woher die Anzeigenliste kommt und warum der Unterschied zaehlt. Gemeldet
    /// schlaegt gemerkt — `AppZustand.anzeigenDerAktivenMitQuelle` fuer beide.
    public static let verlaufHerkunft: [Hilfebaustein] = [
        .ueberschrift("Herkunft der Liste"),
        .absatz("„Verlauf“ listet, was auf der aktiven Uhr steht. Über der Liste steht, woher sie kommt — und dieser Unterschied ist wichtig: „vom Gerät gemeldet“ heißt, die Uhr selbst hat sie veröffentlicht; dann steht dort alles, was wirklich auf ihr liegt, auch von einem anderen Werkzeug Angelegtes, und auch das lässt sich hier löschen."),
        .absatz("„von dieser App angelegt“ heißt dagegen, es ist nur die eigene Buchführung — das eine ist Tatsache, das andere Erinnerung."),
    ]

    /// Wie die Liste zustande kommt: die Uhr veroeffentlicht, die App hoert mit.
    /// Abfragen laesst sich das nicht.
    public static let verlaufEntstehung: [Hilfebaustein] = [
        .ueberschrift("Wie die Liste entsteht"),
        .absatz("Die Uhr veröffentlicht ihre Anzeigenliste von sich aus über das MQTT-Thema `<präfix>/customList`, und über `<präfix>/status`, ob sie gerade am Broker hängt (Gerätereferenz, §3.4 und §3.5). Abfragen lässt sich beides nicht — es kommt, wenn die Uhr es schickt."),
        .absatz("Die App hört deshalb dauerhaft beim Broker mit, sobald eine Uhr ein Präfix hat. Steht über der Liste „von dieser App angelegt“, ist noch nichts gemeldet worden: kein Broker erreichbar, die Uhr aus, oder unter „Einstellungen“ noch nicht abgefragt. Reißt die Verbindung ab, fällt die Liste auf die Buchführung zurück und sagt es."),
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
            "jede Broker-Prüfung",
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
        .absatz("MQTT in der hier verwendeten Version 3.1.1 meldet eine abgelehnte Veröffentlichung nicht zurück. Egal ob das Konto keine Schreibrechte auf das Thema hat oder niemand darauf lauscht: Die App bekommt kein Fehlersignal, keine Warnung — nichts unterscheidet das von einer erfolgreichen Sendung. Erscheint nichts auf der Uhr, ist das also kein Rätsel dieser App, sondern die normale Stille von MQTT 3.1.1."),
        .absatz("Alles bis zur Anmeldung am Broker meldet die App dagegen sehr wohl: falsches Kennwort, unerreichbarer Broker, Zeitüberschreitung, fehlende Zugangsdaten."),
    ]

    /// Broker-Fehler oder Uhr-Fehler: Die Meldung selbst sagt, welche Suche
    /// gemeint ist (`AppZustand.zusammengefasst`).
    public static let fehlerWelche: [Hilfebaustein] = [
        .ueberschrift("Welche Meldung ist gemeint?"),
        .absatz("Das sind zwei verschiedene Suchen, und die Meldung sagt, welche gemeint ist. Nennt sie den Broker mit Adresse und Port („Der Broker 192.168.1.10:1883 antwortet nicht.“), ist die App gar nicht bis dorthin gekommen — dann hilft nur „Einstellungen“ → „Sichern und prüfen“, und keine Uhr ist daran schuld; diese Meldung erscheint deshalb auch nur einmal, selbst wenn an fünf Uhren gesendet wurde. Beginnt die Meldung dagegen mit dem Namen einer Uhr, betrifft sie genau diese und die übrigen wurden beliefert."),
    ]

    /// Die vier Punkte der Reihe nach. Alle vier gibt es auf beiden Geraeten.
    public static let fehlerReihe: [Hilfebaustein] = [
        .ueberschrift("Der Reihe nach prüfen"),
        .punkte([
            "Erstens das Präfix — unter „Einstellungen“ „Abfragen“ noch einmal ausführen und mit dem tatsächlichen Präfix vergleichen; es ist nicht das in Ulanzi Studio eingetragene.",
            "Zweitens, ob die Uhr überhaupt beim Broker angemeldet ist — das Häkchen- oder Warndreieck-Symbol in derselben Zeile.",
            "Drittens, ob das Broker-Konto auf dieses Thema schreiben darf. Das steht in der Rechtedatei des Brokers, nicht in dieser App, und lässt sich nur am Broker-Protokoll ablesen.",
            "Viertens, ob unter „Verlauf“ noch eine alte, stehende Anzeige blockiert — die zuerst löschen oder unter demselben Namen ersetzen.",
        ]),
    ]
}
