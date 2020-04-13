  
# FHEM-Grundlagen

## Installation
Die Installation hatten wir ja eigentlich vorher schon gemacht: Es gibt entweder irgendwo einen Perl-Interpreter auf deinem Windows-PC, oder du hast ein Linux-System, auf dem die entpackten FHEM-Dateien liegen, oder einen Debian-basierten Server (ohne GUI!), auf den du mit *ssh* zugreifen kannst, und auf dem du entsprechend des *easy way* nach [https://debian.fhem.de] FHEM installiert hast.  

## Systemüberblick
Schauen wir uns also FHEM mal gemeinsam an. Da es in einer leeren Installation wenig zu sehen gibt, nehmen wir dafür zunächst einmal die Demoversion.  
Um diese zu starten, muss - sofern du FHEM mit dem Debian-Paket installiert hast - FHEM zunächst einmal beendet werden. Dazu tippst du auf der Linux-Konsole `sudo service fhem stop` ein und gibst das Kommando frei, falls du nach einem Passwort gefragt wirst.  
  
Dann wechselst du in das Verzeichnis, in dem die Datei *fhem.pl* liegt. Nach einer Debian-Installation ist das */opt/fhem*, mit `cd /opt/fhem` kommst du auf der Linux-Konsole direkt dort hin. Dann startest du FHEM mit `perl fhem.pl fhem.cfg.demo`.  
  
Auf einem Windows-PC, bei dem FHEM im Verzeichnis `E:\fhem` liegt und der Perl-Interpreter in einem Unterverzeichnis `E:\fhem\perl\perl\bin\`, kann man - wieder aus dem FHEM-Verzeichnis `E:\fhem` heraus - FHEM so starten: `perl\perl\bin\perl fhem.pl fhem.cfg.demo`  

![FHEM-Start von der Windows-Kommandozeile][demostart_win]  

Auf der Windows-Shell bzw. Linux-Konsole solltest du jetzt einige der oben abgebildeten Textausgaben erhalten, darunter so etwas wie *Server startet with ... defined entities*.  
  
Da du Perl vermutlich nicht kennst, eine kurze Erklärung dieser Aufrufe:  

- `perl` bzw. `perl\perl\bin\perl` ruft den Perl-Interpreter auf. Wie bereits erläutert, ist FHEM eigentlich nur ein "Script", das auf verschiedensten Systemen gestartet werden kann, solange es Perl versteht, also ein entsprechender Interpreter installiert ist (wie hier bei der Linux-Variante) bzw. ein solcher vorhanden ist (wie beim Muster-Aufruf unter Windows mit einer portable-Version von Strawberry-Perl).  

- `fhem.pl` ist das eigentliche Perl-Script, unser FHEM-"Programm". Du kannst dir die Datei gerne mal mit einem Editor ansehen. Es handelt sich um lesbaren Text, der allerdings für Neulinge etwas seltsam aussieht. Dieser "Text" wird durch den Perl-Interpreter in Anweisungen an den Prozessor "übersetzt".  

- `fhem.cfg.demo` ist die Beispiel-Konfiguration, mit der wir `fhem.pl` aufrufen. Auch das ist lesbarer Text, und der sieht schon nicht mehr ganz so "seltsam" aus wie das FHEM-Script `fhem.pl`.  


## Die FHEM Benutzer-Oberfläche (Teil 1)
Die heutige Haupt-Benutzerschnittstelle für FHEM ist allerdings nicht die Konsole, sondern - ähnlich wie bei deinem Router - ein Web-Interface, das über einen beliebigen Browser aufgerufen werden kann.  
  
Wir starten also einen Browser und nehmen über die Adresszeile Kontakt mit FHEM auf. Dazu müssen wir die Adresse des Rechners kennen. Wenn du den hostnamen *fhem_server* vergeben hast, erreichst du FHEM über die Adresse "*fhem_server:8083*", für das Windows-Testsystem ginge "*localhost:8083*".  
 
![FHEM - Start mit Demo-Webseite][Firstlook_demo]  

Es sollte die oben abgebildete Webseite zu sehen sein.
  
  
### Das erste eigene Gerät
Auf der linken Seite haben wir ein paar Einträge. Wollen wir jetzt als erstes versuchen, den Yamaha-Receiver (oder eben das, was du so passendes Einstiegsgerät gefunden hast) "nach FHEM" und dann nach "Cinema" zu bringen?  
  
Einen Knopf für "Hilfe", "Help" oder ein Fragezeichen ist nirgends zu sehen, also sehen wir uns den Punkt an, der am ehesten weitere Informationen enthalten könnte: „Commandref“. Ein Klick darauf öffnet eine weitere Web-Seite, die ziemlich viel Text enthält – das scheint erst mal nicht so hilfreich zu sein... Na ja, dann schauen wir halt mal, ob da was zu „yamaha“ zu finden ist, Strg+f und unser Suchbegriff – da taucht zumindest schon mal was auf:
  
![commandref - alle Yamaha-Module][commandref_yamaha_all]  

Hmm, das ist jetzt nicht sehr aufschlußreich, aber immerhin finden wir was. Um näheres zu erfahren, fangen wir halt einfach mal mit dem ersten Eintrag an, klicken auf „YAMAHA_AVR“ und kommen in etwa hier heraus:    

![commandref zu YAMAHA_AVR][commandref_yamaha_avr]  

… auch auf den ersten Blick nicht ganz einfach, aber immerhin - das scheint einer gewissen Logik zu folgen, und unten gibt es auch ein „Example“: `define AV_Receiver YAMAHA_AVR 192.168.0.10`…  
  
Wir stellen fest:  
***Dinge, die in der Form _`<...>`_ stehen, müssen durch andere, eigene Angaben ersetzt werden, was in _`[...]`_ steht, kann man auch weglassen, das ist optional.***  
Also machen wir einen Test und geben oben neben dem grünen „Plus“ mal was ein (damit ich dir meine IP‘s nicht verraten muß, nehme ich den hostname, du muß jetzt erst mal nachsehen, was die passende IP-Adresse ist) `define Yamaha_Receiver YAMAHA_AVR Wohnzimmer` gefolgt von der Eingabetaste.  
  
Ok, das sieht schon besser aus:  
  
![Brand-New][Yamaha_Brandnew]  

Da gibt es was für die Lautstärke und Einträge wie „on“ und „off“.
Nachdem wir kurz gewartet haben, geht uns sogar „ein Licht auf“ (jedenfalls, falls wir gerade im Wohnzimmer sitzen und z.B. Musik hören): Die drei *???* werden zu einer (leuchtenden) Glühbirne, und auch der Lautstärkeregler zeigt vielleicht was anderes an.  
  
Jetzt aktualisiere bitte das Browserfenster (F5). Dann sollten noch viel mehr Einträge zu sehen sein, die dann auch immer mal wieder aktualisiert werden – zu erkennen an der geröteten Zeit:  
  
![Detail-Ansicht][Yamaha_main_details_all]  

Falls du jetzt keinen zu diesem Modul passenden Receiver hast, funktioniert das ganze – zumindest im Prinzip – ganz genauso mit anderen netzwerkfähigen Receiver – vorausgesetzt, du findest das dazu passende Modul. Für die, die "nur" den empfohlenen Shelly haben: Mit dem Modul *Shelly* geht das fast genauso – nur dass vielleicht das "model" nicht automatisch bestimmt werden kann und ähnliche Kleinigkeiten.  
Teste ruhig mal etwas aus, wie dein Gerät reagiert, wenn du auf die grünen *on* bzw. *off*-Links klickst oder auf die Glühbirne, die statt der *???* erschienen ist. Um die Lautstärke zu ändern, genügt es nicht, nur den Schieberegler zu verstellen, du musst zusätzlich noch auf das grüne *set* vorne in der betreffenden klicken. Das ist noch etwas umständlich, aber darum kümmern wir uns später. Erst soll der Receiver aus diesem "Unsorted" nach "Cinema".  
  
Dazu klickst du auf das leere Feld neben "room" - ganz unten bei "Attribute", aktivierst in dem Dialogfeld dann "Cinema", clickst *OK* und zuletzt vorne in dieser Zeile auf *attr*.  

![Raum-Vergabe][yamaha_room_dialogue] ![Raum-Vergabe][yamaha_attr_room_attr]  

Wenn du genau hinsiehst, ist links im Menü jetzt nicht mehr "Unsorted" grün hinterlegt, sondern "Cinema".  

![Raum-Vergabe][yamaha_room_cinema]    
  
Wir haben also nicht nur was am Device geändert, sondern gleich noch den Raum gewechselt. Ähm, sorry, Device ist ja fachchinesisch, wird wohl Zeit, ein paar Vokabeln zu lernen...   
  
### Vokabeln 1: Device, Attribut, Reading, Internal & Co  
  
#### Device  
  
Dass ein ***Device*** sowas ähnliches ist wie die Entsprechung irgendeines Stücks Hardware in FHEM, ahnst du vermutlich schon. Es ist aber etwas komplizierter:  
Ein Device ist zunächst mal alles, für das es in der Konfiguration (zu der kommen wir noch) ein „define“ gibt – und das können für ein Stück Hardware auch schon mal mehrere sein: Hast du einen Yamaha-Receiver mit einer zweiten Zone, kannst du für den ein weiteres Device anlegen, dafür gab es die optionale Angabe `<zone>`.  
`define Yamaha_Receiver_2 YAMAHA_AVR Wohnzimmer zone2` würde mir also ein weiteres Device anlegen (in der Tat habe ich das für das Esszimmer so eingerichtet). Häufig wird statt „Device“ auch von „Gerät“ gesprochen, meistens (leider nicht immer) ist damit das FHEM-Define gemeint, seltener die Hardware.  
Immer mal wieder kommt es vor, dass eine „define“-Angabe durch dich nicht nur ein Device anlegt, sondern gleich mehrere. Das passiert vor allem dann, wenn es Hardware ist, die voneinander abgekoppelte Funktionalität bereitstellt, also z.B. zwei Lichter unabhängig voneinander an- und ausschalten kann. Wir nennen sowas dann häufig ein *mehrkanaliges* Device.  

#### Attribut  
  
Ein *Attribut* hatten wir bereits kennengelernt: *room*. Attribute sind eigentlich dazu gedacht, dem User (also z.B. dir) einen Weg zur Verfügung zu stellen, FHEM etwas mitzuteilen, und zwar Dinge, die eher unveränderlich sind: Wo soll das Device zu finden sein, wie soll das Gerät aussehen, welche Kommandos willst du angezeigt bekommen. Solche Dinge eben. Wir haben daher einen "Merksatz": *Attribute gehören dem User!*  
Du ahnst es: Es gibt Durchbrechungen dieser Regel… Das fängt schon damit an, dass "unser" Receiver automatisch ein *model*-Attribut erhalten hat.
Wenn du einen Shelly als Testgerät verwendest, solltest du übrigens jetzt mal das *model*-Attribut setzen, dann bekommst du nämlich auch die Daten der Energiemessfunktion angezeigt. Damit teilst du FHEM (bzw. dem Shelly-Modul-Code) mit, dass es diese Daten von dem Shelly holen kann und soll.  
  
#### Reading  
  
Die meisten Daten, die das YAMAHA_AVR-Device anzeigt, stehen im Abschnitt Readings (siehe screenshot oben). Readings kommen daher sehr häufig von der Hardware her – drehst du die Lautstärke am Verstärker direkt mit der Fernbedienung oder dem Drehknopt hoch, ändert sich – ggf. nach einer gewissen Zeit – auch der Readingwert in unserem Device (sorry, ich werde den Begriff Device bzw. Gerät jetzt ständig verwenden, aber du weißt jetzt ja, was gemeint ist).  
Ein Reading ist an sich aber nur ein Datenfeld mit einem Namen, es gibt auch Fälle, in denen der User den Readingwert festlegt. Das passiert z.B., wenn du den set-Befehl für die Lautstärke betätigst. Dann legst du den Readingwert fest, dieser Wert wird – wenn alles klappt – an die Hardware übertragen, und – wenn es ein „gutes“ Device ist (sorry, damit ist jetzt ausnahmsweise die Hardware gemeint…) – also wenn es für Hausautomatisierungszwecke optimal programmierte Hardware ist, dann meldet die auch den „Vollzug“ zurück. Das ist gemeint, wenn irgendwo hier von "bidirektionaler Kommunikation" die Rede ist.  
  
\footnotesize 
***Für später:***  
*Der beschriebene Weg der Informationsverarbeitung kann dann dazu führen, dass man ein kurzes Flackern der Schieberegler sehen kann, kurzfristig andere Symbole, wenn Dinge angeschaltet werden oder der Rückgabewert nicht ganz exakt dem Vorgabewert entspricht (z.B. weil ein paar Rundungen dazwischen stattfinden).*  
\normalsize

#### Internal  

Der oberste Abschnitt der Geräteansicht unseres Testgeräts ist mit *Internals* überschrieben. Auch das sind Datenfelder, allerdings sind die in der Regel nicht dazu gedacht, dass der User sie verändert. Ok, mit einem Klick auf "DEF" bekommt man sogar ein Eingabefeld, aber das ist die Ausnahme.  
Der wesentliche Unterschied zu Attributen und Readings ist aber der: Internals werden „zur Laufzeit“ ermittelt, sie entstehen während des Betriebs. Attribute und Reading-Werte können dagegen gespeichert werden:
Attribute zusammen mit der jeweiligen „define“-Anweisung in der Konfigurations-Datei, mit der FHEM gestartet wurde (bis hierher war das
die fhem.cfg.demo), die Readings in einer anderen Datei, die „statefile“ genannt wird.  
  
\footnotesize    
***Für später:***  
*Die Frage der Zuordnung einzelner Daten zu Internal, Reading und Attribut ist nicht immer eindeutig vorgegeben und manche - vor allem früher entstandene - Module halten z.B. Einstellungen in Attributen vor, die neuere eher über Readings abbilden. Was wohin kommt, entscheidet letztlich jeder Modulautor (auch) nach seinen Präferenzen; in der Regel folgt es gewissen Zweckmäßigkeitserwägungen.*  
  
***Hintergrund-Infos:***  
*Die Module benötigen in der Regel für interne Zwecke noch weitere Informationen und Datenstrukturen. Einen Teil dieser Daten macht das „list“-Kommando sichtbar, auf das wir später nochmal zurückkommen werden.*
\normalsize  

### Detailansicht und DeviceOverview  

Bis jetzt hatten wir dein Testgerät immer im "detail" gesehen – so steht es oben in der Adresszeile des Browsers. Diese Detail- oder *Geräteansicht* enthält oben noch einen Abschnitt, der mit "DeviceOverview" betitelt ist.  
Dieser Abschnitt (ohne die Zeilen, die mit *set* und *get* beginnen), stellt dar, wie das Device in der sogenannten Raumansicht dargestellt ist. In diese wechseln wir gleich.  
  
Vorher sollten wir aber noch ein paar Attribute setzen:
Zum einen das Attribut „group“. Das wählst du jetzt in dem dropdown-Auswahlfeld aus, ein Klick auf das Textfeld bringt dann wieder ein Auswahldialogfeld, wie wir das von *room* her kennen. Auch hier kommen zuerst die *group*-Einträge, die das FHEM schon kennt, und unten ein Freitextfeld, in das man was neues eintragen könnte. Wir wollen den Receiver aber in der Gruppe „AV“ haben, markern daher diese Auswahl an und bestätigen mit OK, und klicken zuletzt noch vorne auf *attr*.  
Dann sollte der Eintrag unten in der Attributliste erscheinen:  
  
![Attribute][yamaha_attr_all]  

Zu guter Letzt vergeben wir noch ein Attribut, dieses Mal setzen wir es jedoch über das Eingabefeld zum direkten Ausführen von FHEM-Befehlen. Das ist das Texteingabefeld rechts neben dem grünen „Plus“ - wir nennen das „Kommandozeile“. Dort geben wir `attr Yamaha_Receiver alias Verstärker (Hauptzone)` ein und beenden mit der Eingabetaste.  
  
![Alias-Vergabe][yamaha_attr_alias_commandfield]  

Wir landen dann wieder auf der Seite, die ganz am Anfang zu sehen war.
Um jetzt anzusehen, was diese Befehle bewirkt haben, klickst du im Menü links auf „Cinema“. Wir kommen auf die entsprechende „Raumansicht“ und finden den Receiver direkt als letzten Eintrag in der obersten Gruppe „AV“. Auch die Knöpfe für „on“ und „off“ sind da -was fehlt, wäre ein Schieberegler für die Lautstärke, oder?  
Also rüsten wir den noch kurz nach: Ein Klick auf den grünen Schriftzug „Verstärker...“ bringt uns zurück auf die Detailansicht. Dort vergeben wir ein weiteres Attribut – „webCmd“ – mit dem Inhalt „volume“ (du kennst ja schon zwei Wege, das zu vergeben, erwarte also keine weiteren Erläuterungen dazu. Nur soviel noch: das „volume“ muss ohne die Anführungszeichen eingegeben werden).  
Schon haben wir oben im DeviceOverview unseren Slider, dafür aber kein „on“ und „off“ mehr, aber das brauchen wir auch nicht, wir können ja über die „Glühbirne“ in der Mitte ein- und ausschalten.  
  
\footnotesize 
***Für später 1:***  
*Das Attribut „room“ hat neben dem Effekt, dass neue Räume auch weitere Einträge im Menü links erzeugen noch mindestens eine weitere Auswirkung: Da dies der wesentliche Mechanismus ist, mit dem Devices in FHEM strukturiert werden, verwenden den auch manche Softwarelösungen zur Strukturierung der Geräte, mit denen man FHEM von außen steuern kann, z.B. die Android-App andFHEM.*  
  
***Für später 2:***  
*"webCmd" ist nur eines von vielen Attributen, mit denen sich das Aussehen und Verhalten von Geräten in FHEMWEB ändern lässt. Eine kleine strukturierte Einführung hierzu ist im Wiki unter [DeviceOverview anpassen] zu finden, sämtliche verfügbaren grafischen Steuerungselemente in [FHEMWEB-widgets].*  
  
***Für später 3:***  
*Was wir mit dem „alias“ gemacht haben, wäre als Name ein absolutes „no go“ gewesen: Sonderzeichen sollte man dort – wie auch in Namen für Readings – vermeiden, Leerzeichen und Klammern gehen gar nicht.*  
*Ein Tipp: auch Punkte und andere Zeichen, die in Perl und/oder regex „spezielle Funktionen“ haben, solltest du meiden, selbst wenn sie zulässig sein sollten.*  
\normalsize  
  
## "set" und andere *basics*  

### set  

DAS "Kommando" in FHEM kennst du damit ja eigentlich bereits: ***set*** - wir hatten damit oben den Receiver ein- und ausgeschaltet oder die Lautstärke verändert. Nur hatten wir das vor allem über "Klicks" im Web-Interface erledigt, aber das geht selbstredend genauso über die Kommandozeile, über die du das `define` und die Attribute eingegeben hattest. Genauer gesagt: wenn du nicht nur eine Fernbedienung haben willst, sondern eine ***Automatisierung***, verwendest du später in 99,9% der Fälle (indirekt) die Form, die als Kommandozeilen-Eingabe gültig ist (oder noch direktere Formen). 

Du solltest daher mit dem Receiver (oder dem Shelly) noch ein wenig "üben". Du gibst also `set Yamaha_Receiver off`, `set Yamaha_Receiver on` (bzw. dasselbe für den shelly mit dem passenden Namen) oder sowas wie `set Yamaha_Receiver volume 35`, `set Yamaha_Receiver source tuner`, ... ein, immer gefolgt von der Eingabetaste. Falls du nicht nur einfach copy/paste vorgegangen bist, ist dir bestimmt aufgefallen, dass manche dieser Kommandos nur 3, andere aber 4 *Argumente* haben: Manche wirken auf das Gerät selbst, sind also eine Art "Hauptschalter", andere betreffen nur einen "Nebenaspekt" und nennen den daher im Kommando selbst auch ausdrücklich.  
Du kannst auch die "Langform" für den "Hauptschalter" verwenden: `set Yamaha_Receiver state off`. In der Regel tut man das nicht, es genügt an der Stelle, wenn du eine erste Idee hast, dass  
- die kurze Form "speziell" ist und 
- es einen engen Zusammenhang zwischen ***state*** (dem *Reading*) und ***STATE*** (dem *Internal*) gibt.  
Wir werden später nochmal darauf zurückkommen, aber erst brauchen wir noch ein paar weitere Grundlagen. Daher geht's jetzt erst mal wieder mit ein paar gemeinsame „Vokabeln“ weiter:  

### Vokabeln 2 - Sensor, Aktor, Kanal  

- Von einem ***Sensor*** sprechen wir, wenn wir es mit einem Stück Hardware zu tun haben, das irgendwelche Informationen, v.a. Messwerte an FHEM übermitteln soll. Klassisches Beispiel wäre ein Temperaturfühler.  
- Ein ***Aktor*** ist dagegen ein Stück Hardware, der wir von FHEM aus Anweisungen schicken, etwas zu tun. Ein einfaches Beispiel wäre ein fernsteuerbares LED-Leuchtmittel oder eben unser Receiver - den kann man von FHEM aus ein- oder ausschalten oder im Tuner den Sender wechseln (was mit dem Shelly nur teilweise geht).  
  
Die Unterscheidung ist meistens nicht ganz trennscharf, denn beide *Aktor*-Beispelgeräte kennen nicht nur Readings, die man von FHEM aus setzen kann, sondern liefern auch Werte, die man nicht mit FHEM so einfach ändern kann wie die Lautstärke - z.B. das *presence*-Reading, den *inputName* oder (beim Shelly) die IP-Adresse oder firmware-Versionen. In solchen Fällen sprechen wir dann von *Aktor-Kanälen* oder *Sensorkanälen*, je nachdem, ob der entsprechende Wert typischerweise von FHEM aus veränderlich ist, oder (fast) nur vom Gerät aus.
  

Du hast nun einen ersten Eindruck, wie aus einem Stück Hardware ein oder mehrere FHEM-Devices werden – jetzt haben wir nur das Problem, dass das, was du hart erarbeitet hast „im falschen FHEM“ ist… OK, kein Problem, wir können jetzt einfach alle obigen Befehle zur *Konfiguration* nochmal aus dem Text zusammensuchen und nochmal eingeben bzw. zusammenklicken. Es geht aber auch einfacher:  
  
### Kommandozeile(n) und RAW Definition  

Die einfache Kommandozeile kennst du schon von eben, jetzt klickst du bitte mal auf das „grüne Plus“ links daneben. Es erscheint ein größeres Eingabefeld – in das könnten wir jetzt nacheinander sämtliche Befehle von oben eingeben, und dann mit einem Klick auf „Execute“ „auf einen Rutsch“ ausführen.  
  
Um das sinnvoll zu tun, brauchen wir jetzt zwei Dinge: Die notwendigen Kommandos und das „richtige“ FHEM – wir sind ja noch im Demo-System…  
  
Also drücken wir ohne weitere Eingabe auf „Close“ und scrollen ganz nach unten. Dort gibt es noch eine Art Menü. In dem wählen wir „Raw definition“ und bekommen ein ganz ähnliches mehrzeiliges Texteingabefeld, nur dass es dieses Mal nicht leer ist, sondern zum einen (fast) die Zeilen enthält, die wir als *define* und *Attribute* zu unserem Testgerät eingegeben hatten, zum anderen einige Zeilen mehr, die mit „setstate“ beginnen:  
  
![RAW-Definition][yamaha_raw]  

Du kopierst jetzt die ersten 6 Zeilen und überträgst sie in einen beliebigen Editor – am besten einer, der Linux-konforme Zeilenumbrüche kennt, wie z.B. [notepad++].  
  
Die mit setstate beginnenden Zeilen brauchen wir nicht, aber das sind die Zeilen, die in der oben bereits erwähnten „statefile“ gespeichert werden, das hier in der „defmod“-Schreibweise auftauchende „define“ sowie die Attribute werden in der Konfigurationsfile (zuerst meistens *fhem.cfg*) gespeichert.  
  
Apropos speichern:  
- Bitte speichere die geänderte Demo-Konfiguration *NICHT* ab – wir werden die Demo-Konfiguration später nochmal etwas intensiver ansehen, und da ist es besser, wir haben dieselbe Ausgangslage.  
- Die statefile mit den Readingwerten wird nur sehr selten gespeichert, nämlich nur bei einer ausdrücklichen Anweisung, z.B. einem Klick auf „Save config“ (nein, immer noch nicht!) und beim ordnungsgemäßen Beenden von FHEM – dazu kommen wir noch.  
  
Um jetzt zusätzlich „das richtige FHEM“ starten zu können, greifen wir jetzt etwas in die Trickkiste: Wir ändern den „Port“, auf dem das Demo-System zu erreichen ist. Zur Erinnerung: Um auf die Webschnittstelle von FHEM zu kommen, hattest du `fhem_server:8083` in die Adresszeile des Browsers eingegeben, das Demosystem belegt also bereits Port 8083, was verhindert, dass ein „neues FHEM“ ebenfalls mit Port 8083 starten kann. Das ist aber die Standardeinstellung einer neuen fhem.cfg.  
Wir gehen daher in den Raum „Everything“ und scrollen zur Gruppe „FHEMWEB“:  
  
![FHEM-Demo-Webseite][FHEMWEB_demo]  
  
Du siehst mehrere Einträge – wie viele, hängt von der Zahl der geöffneten Browserfenster ab – und wählst den obersten; der ist das eigentlich maßgebliche Device, die anderen sind lediglich temporäre „Instanzen“, die auch wieder verschwinden, wenn die Verbindung beendet wird, wenn z.B. das Browserfenster geschlossen wird.  

\footnotesize 
***Für später:***  
*Auch bei anderen Serverdiensten, die FHEM anbietet – insbesondere telnet und MQTT2_SERVER – erscheinen für jede offene Verbindung neue, temporäre Devices.*  
\normalsize  

Wir klicken daher auf den „WEB“-Link. Um später die beiden Instanzen besser auseinanderhalten zu können, ändern wir die Beschreibung der Reiter im Browser mit `attr WEB title Demo-System` - du kannst wieder wählen, wie du FHEM das beibringen willst.  

![Titel-Änderung][title_demo]  

Jetzt geht es an's Eingemachte: Wir ändern über den Link „DEF“ im „Internals“-Abschnitt den Port auf 8093, ein Klick auf „modify WEB“ unter dem Eingabefeld, und du kannst über `fhem_server:8093` auf das Demo-System gelangen, `fhem_server:8083` kann evtl. noch kurz funktionieren, schlägt dann
aber ziemlich schnell fehl.  

![Port-Einstellung][defmod_FHEMWEB_port]  

Wenn du kein Freund von „klicken“ bist, kannst du das wieder über die Kommandozeile machen: Versuche es erst mit `define WEB 8093 global`, und danach mit `defmod WEB 8093 global` – dann kennst du auch gleich den wesentlichen Unterschied zwischen `define` und `defmod`.  

### update  

Damit wir dann gleich mit einem aktuellen FHEM starten können, führen wir als nächstes gleich noch ein *update* durch. Gib also erst mal `update check`in die Kommandozeile ein, damit du sehen kannst, was sich alles seit Erscheinen des Debian-Pakets getan hat. Das ist einiges - in der Regel kommt da eine recht lange Liste. Da dir das im Moment vermutlich noch nicht allzuviel sagt, führen wir jetzt eben einfach das update durch - wenig überraschend durch ein einfaches `update`in die Kommandozeile. Wenn du das zukünftig machst, solltest du dir vor allem ansehen, was als Änderungen in der *CHANGED*-File vermerkt ist - da schreiben die Developer nämlich rein, was sie für "erwähnenswert" halten. Wir werden darauf später nochmal eingehen.  Ach so: dass beide Kommandos in die FHEM-Kommandozeile gehören, war klar? Gut, denn das werde ich ab jetzt auch nicht mehr gesondert erwähnen... 
Das update selbst geht meist recht schnell, was je nach System etwas länger dauert, ist das Zusammenbauen der *commandref*. Danach bekommst du den Hinweis, dass FHEM neu gestartet werden soll, was wir noch nicht machen.  

\footnotesize 
***Für später 1:***  
*Falls du dich fragen solltest, was es bringt, ein Testsystem zu aktualisieren, und das auch noch unmittelbar, nachdem das aktuelle Debian-Paket installiert wurde:  FHEM wird nicht über die Paketverwaltung (bei Debian: "apt"-irgendwas) aktualisiert, sondern über einen eigenen Mechanismus. Das hat damit zu tun, dass FHEM in Perl geschrieben ist, somit auf vielen anderen Betriebssystemen laufen kann und auch dort updates zur Verfügung stehen sollen. Zum anderen bestehen recht geringe Abhängigkeiten von bestimmten Versionen anderer Pakete - dies ist bei "echten" Linux-Paketen jedoch häufig der Fall, so dass man dort diese Abhängigkeiten in der Regel über die Paketverwaltung auflöst. Aus diesem Grund wird auch der Pfad zum FHEM-Server durch das Debian-Installationspaket aus der Linux-Paketverwaltung selbst direkt wieder im Rahmen der Installation gelöscht und sollte auch gelöscht bleiben.  
(Fast) alle erforderlichen Dateien liegen in der Verzeichnisstruktur unterhalb `/opt/fhem`. Es ist daher völlig gleichgültig, wie sie dahin gelangen, wichtig ist nur, dass sie zum einen für den user *fhem* lesbar sind und zum anderen nach einer Aktualisierung auch wieder neu *geladen* werden - deswegen fordert einen der update-Prozess am Ende auch auf, FHEM neu zu starten. *  

***Für später 2:***  
*Für die von FHEM intern genutzte Perl-Software gibt es darüber hinaus eine eigene Paketverwaltung namens *cpan*, Details findest du weiter hinten.*
\normalsize  

### save  
  
Da auch das `save`-Kommando ein paar Optionen kennt, rufen wir wieder vorab die Hilfe auf: `help save` und erfahren dort, dass wir auch die Möglichkeit haben, einen Speicherort anzugeben, um die aktuelle Konfiguration zu speichern. Aha! Genau diese Variante brauchen wir jetzt nämlich: `save fhemdemo.cfg` - damit haben wir gleich die Möglichkeit, sowohl unser "Echtsysstem" wie auch das geänderte Demosystem parallel zu verwenden...!  

## FHEM starten und weitere *basics*  

Jetzt kann es also richtig losgehen, du startest jetzt endlich dein „richtiges FHEM“. Dazu ziehst du bitte zuerst alle nicht erforderlichen USB-Geräte – vor allem Interfaces!) aus dem Pi (auf anderen Systemen ist das nicht erforderlich), wechselst wieder auf die Linux-Kommandozeile – da du mit ssh verbunden ist und die aktuell laufende Sitzung mit dem Demo-System beschäftigt ist, öffnest du einfach eine weitere ssh-Sitzung und erweckst aus der heraus FHEM mit `sudo service FHEM start` zum
Leben.  

Weil wir gerade auf der Linux-Konsole sind, starten wir auch gleich das Demo-System wieder - dieses Mal eben parallel - mit `perl fhem.pl fhemdemo.cfg` und schauen uns mit `ps -ax | grep fhem` noch kurz an was im Moment so an Prozessen aktiv ist und was mit fhem zu tun hat:  

![Mehrere Perl][ps_ax_mehrere_perl]  

Bei dir wird das etwas anders aussehen. Neben dem grep-Filter sollten zwei FHEM-Instanzen, zu sehen sein, eine mit `fhem.cfg`, eine mit `fhemdemo.cfg`.

\footnotesize 
***Für später:***  
*Warum sehen wir auf der Abbildung drei Instanzen? "fhemdemo.cfg" ist das Demo-System, das aber mit einer modifizierten Kopie der "fhem.cfg.demo" gestartet wurde, und das Hauptsystem, für das als Konfiguration configDB angegeben ist. Das ist eine alternative Möglichkeit, die Konfiguration zu speichern. Der zweite FHEM-Prozess mit configDB läuft noch nicht sehr lange, nur etwas mehr wie eine Minute; das dürfte eine länger laufende, „geforkte“ Instanz sein, die automatisch gestartet wurde, um den Hauptprozess zu entlasten.*  
\normalsize  
  
Wechsle jetzt in dein „richtiges“ FHEM, indem du im Browser wieder den Port 8083 aufrufst: `fhem_server:8083`  
Dieses FHEM sieht jetzt allerdings etwas weniger "nett" aus als das Demo-System und "begrüßt" dich mit einem Hinweis darauf, dass du mit deiner FHEMWEB-Instanz eine nicht besonders gut abgesicherte Serverschnittstelle hast; wir werden später darauf zurückkommen.  
  
Nun können wir mir einem Klick auf das grüne „Plus“ neben der Kommandozeile eine mehrzeilige Variante der *Kommandozeile* erhalten - im Unterschied zu dem, was wir bei RAW Definition kennen gelernt haben, ist dieses Dialogfeld aber leer. Funktional sind alle Varianten der Kommandozeile jedoch gleichwertig und beiten vor allem auch eine Syntax-Prüfung des eingegebenen Codes bei der Ausführung an - so lassen sich Tippfehler o.ä. meist gleich bei der Ausführung aus den Dialogfeldern heraus erkennen. 
Zurück zum Yamaha (oder deinem TV): Du kannst jetzt die weggespeicherte RAW-Definition in das Dialogfeld kopieren und mit "Execute" direkt zur laufenden Konfiguration hinzufügen. Danach beendest du das Dialogfeld und kannst den Yamaha dann direkt steuern - er ist auch hier wiederzufinden, wenn du links auf den Raum *Cinema* klickst. 

### Etwas Ordnung: Das Menü und *room*  

Falls *Cinema* nicht der Raumname sein soll, unter dem er zukünftig zu finden sein soll, kannst du auch wieder die Detailansicht aufrufen, dort das *room*-Attribut bearbeiten und einen anderen Raum in das Freitextfeld eingeben. Du darfst gerne jetzt ein wenig damit herumspielen und auch mal den Eintrag *Cinema* deaktivieren. Nach jedem Klick auf *attr* bitte dann auch einen Browser-Refresh durchführen, sonst sind evtl. neue Räume nicht bzw. bereits gelöschte Räume noch sichtbar.  
Ist alles so, wie du dir das erst mal vorstellst, kannst du `save` ausführen, jetzt gerne auch mit einem Klick auf "Save config". 
Falls du als Testgerät/e einen Shelly oder ein mit *Tasmota* geflashtes Gerät hast, solltest du noch einen Moment warten, wir kommen später auf die Schritte zurück, die erforderlich sind, um derartige Geräte mit MQTT einzubinden - es spricht aber nichts dagegen, wenn du (ggf. nur testweise) das obige beim Shelly mit der Original-Firmware mit dem (FHEM-) Shelly-Modul entsprechend umsetzt.  



### Rundgang: Weitere Grundelemente in FHEMWEB  

tbd.

### FHEM-Server neu starten – shutdown restart  


### Event-Monitor  


### Detailansicht eines Geräts und Bearbeiten von Geräten über das Webfrontend  


### Das besondere Gerät „global“  


## Basics zu fhem.pl  

### allg. Funktionsweise der Hauptschleife  

### Hänger und wie man sie vermeidet  



## Basics zu Modulen (oder: die Freiheiten der Programmierer...)  

(-- \$name, \$NAME und \$DEVICE...?)

## autocreate: Sensoren und Aktoren in FHEM einbinden  

## Informationen aufzeichnen (Teil 1)  

### Logdateien und DBLog  

### Hinweise zum Datenschutz  


