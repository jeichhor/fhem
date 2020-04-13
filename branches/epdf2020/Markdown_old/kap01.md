# Hardware – Teil 1

## Wo anfangen? Eine Bestandsaufnahme 

Viele neuen User interessieren sich zunächst mal dafür, was sie anschaffen sollen, um überhaupt erst mal einen Einstieg zu haben. Mein Vorschlag: Wir schauen erst mal, was du schon hast - das nehmen wir dann einfach als "erstes Testgerät". Da es ohne Server nicht geht, kommen nach einigen Hilfestellungen zur Festegung bzw. Beschaffung dieses "Erstgeräts" zunächst ein paar Hinweise zur Serverauswahl, dann werden wir mit dem Erstgerät einige FHEM-Grundlagen erarbeiten. Ein paar Handreichungen zu Auswahl des „passenden“ Hausautomatisierungssystems finden sich dann weiter hinten.  
  
Vor allem zum ersten Kennenlernen von FHEM kannst du dir erst mal die Frage stellen, was du eigentlich schon direkt verwenden könntest. Denn ein großer Teil der elektronischen Dinge, die du in den letzten 10 Jahren gekauft hast, steht unter dem dringenden Verdacht, dass das "irgendwie" – meistens sogar ohne weiteres – in FHEM integrierbar ist.
Erster Schritt sollte daher eine Bestandsaufnahme all dessen sein, für das du irgendeine App auf dem Handy installiert hast, z.B.:  

- einen Multimediareceiver o.ä., verbreitete Marken wie Yamaha, Onkyo und Samsung kommen hier ebenso in Frage wie "Sonos"-Systeme oder manche WLAN-Küchenradios vom örtlichen Lebensmitteldiscounter;  
- ZigBee-Bridges, z.B. Philips HUE oder ein Tradfri-Gateway von IKEA, eventuell hast du auch eine phoscon-App?  
- Direkt über WLAN schaltbare Leuchtmittel oder Steckdoseneinsätze, etwa einen Shelly-Plug;  
- Bluetooth-Sensoren oder fernsteuerbare Heizkörperthermostate...  
  
Daneben gibt es eventuell manches, für das du zwar keine App hast, das aber trotzdem eventuell zumindest als Datenquelle genutzt werden kann oder sogar steuerbar sein könnte. In diese Kategorie fallen z.B.:  

- alte 433MHz-Geräte aus dem Baumarkt, die mit einer Fernbedienung zu bedienen sind;  
- über Funk steuerbare Rollläden, insbesondere der Marke Somfy;  
- Dunstabzugshauben mit Fernbedienung;  
- Temperatursensoren, vor allem solche, die ihre Messwerte an eine Basisstation senden;  
- Zentralheizungsgeräte, vor allem neuerer Baureihen;  
- AV-Geräte mit einer Infrarot-Fernbedienung  
- ....  
  
FHEM kann meist alle diese Dinge ebenfalls mit auswerten und steuern.
Nur: der Weg dahin kann sehr unterschiedlich sein. Wenn du noch keine oder wenig Erfahrung hast, empfehle ich für den Start und das erste Kennenlernen der Steuerung realer Geräte mit FHEM etwas, für das du eine App hast. Die Basis-Funktionalität in FHEM entspricht – bei richtiger Konfiguration – nämlich häufig ziemlich genau dem, was auch die App bietet. Für die Wahl des „Erstgeräts“ ist es optimal, wenn einige wenige Funktionen gegeben sind, aber nicht gleich viele reale Geräte gesteuert werden können. In meinem Haushalt habe ich z.B. einen netzwerkfähigen HiFi-Receiver der Marke Yamaha, der sich u.a. mit der App "multicast" steuern lässt. Dieser wäre ideal, denn er hat zwei getrennt schaltbare Zonen, man kann unterschiedliche Quellen für die Zonen wählen und unterschiedliche Lautstärken einstellen. Gut geeignet wäre auch ein smartes TV-Gerät, bei dem man auch unterschiedliche Programme und Lautstärken kann.  
Ebenfalls geeignet, aber für einen Einstieg deutlich unübersichtlicher wäre eine HUE- oder Tradfri-Bridge, vor allem, wenn daran bereits viele Geräte daran angelernt sind.  
Nach dem ersten Überblick über FHEM werden wir meinen Yamaha-Receiver als Beispielgerät verwenden, du musst dann eben die Kommandos für dein "Einsteigergerät" anpassen.  
Wenn du gar kein Gerät hast und etwas Einfaches suchst, würde ich zu einem oder zwei Steckdoseneinsätzen mit Messfunktion aus der "Shelly" Produktlinie raten. Hast du bereits etwas Ähnliches, das schon mit einer firmware ausgestattet ist, die ein Protokoll namens "MQTT" nutzen kann, ist auch das ok. Allerdings hat auch dieser Rat einen Pferdefuß, auf den wir später nochmal zurückkommen werden: Diese Geräte werden über das WLAN gesteuert...  
  
Hinweis: Jetzt kann es sein, dass du feststellst, dass es für das Gerät, das du eben als Testgerät ausgewählt hast, mehrere Varianten gibt, wie es in FHEM eingebunden werden kann! Wenn das der Fall ist, hast du was Wichtiges gelernt: Es gibt selten nur einen Weg, etwas umzusetzen, und häufig gibt es nicht "den besten"...! Dies schon alleine deshalb, weil es für die Entscheidung der Frage, was "das beste" ist, darauf ankommt, wie das konkrete Umfeld aussieht. Du wirst also ziemlich oft die "Qual der Wahl" haben, wir werden noch ein paar Mal darauf zurückkommen.  
  
## Die Qual der Wahl 1 - Server!
Die erste Wahl, vor die du gestellt bist, ist die, welche Art Server du eigentlich einsetzen willst. Dazu muß man verstehen, dass FHEM in Perl geschrieben ist, und Perl-Interpreter für praktisch alle verbreiteten Betriebssysteme verfügbar sind. FHEM selbst ist nur ein Perl-Script mit ein paar Plugins, die wir Module nennen. Das sind ein paar Dateien, die man im Prinzip irgendwohin speichern kann und dann mit dem Perl-Interpreter startet. Du kannst also ohne weiteres eine aktuelle Perl-Umgebung für Windows herunterladen (link zur Anleitung mit 32bit-Strawberry-Perl), FHEM als zip holen, das in ein beliebiges Verzeichnis entpacken und zum Testen loslegen. Wenn du nur mal reinschnuppern willst und gar kein Geld ausgeben, wäre das eine empfehlenswerte Variante.  
Einfacher geht es, wenn du z.B. einen PC oder ein Laptop mit einem Linux-Betriebssystem besitzt - da ist der Perl-Interpreter in der Regel schon installiert. Es kann dann nur sein, dass einige wenige Perl-Module nachinstalliert werden müssen, Details dazu findest du in den Installationsanleitungen. Wenn du also einen Linux-Rechner hast und nur mal Testen willst: zip-Datei entpacken und wir können loslegen.  
  
Für das Folgende ist eine Windows-Umgebung oder ein beliebiger Linux-Rechner bereits ausreichend.  
  
Willst du nicht nur mal kurz antesten, sondern FHEM etwas intensiver kennenlernen, brauchst du eine Plattform, die rund um die Uhr läuft. Wenn du bereits einen (Linux-)-Server betreibst, könntest du den verwenden, und FHEM z.B. in der ["docker"-Variante](https://forum.fhem.de/index.php/topic,89745.0.html) installieren.  
  
Wenn dir das alles nichts oder wenig sagt, gibt es eine einfache Empfehlung: Besorge dir einen Raspberry Pi.  
ABER: Das ist eine "Empfehlung mit Pferdefuß"! Genauer: Die hat gleich mehrere große Haken und ist eigentlich eher eine Notlösung, eine Art "kleinster gemeinsamer Nenner"...  

- Zum einen mußt du dich in das Betriebssystem dafür einarbeiten: Linux. Wir werden später darauf zurückkommen...  

- Zum anderen ist auch die Hardware an sich nur bedingt tauglich.
Insbesondere ungünstig ist es, dass die Daten und das Betriebssystem auf einer SD-Karte gespeichert werden. Das ist alles andere als optimal: es gibt im FHEM-Forum alle paar Wochen User, die über unerklärliche Fehler berichten, die letztlich auf eine kaputte SD-Karte zurückzuführen sind. Man kann zwar auch über USB eine SSD-Festplatte anschließen. Das verringert den "wear-out" durch häufige Schreibzugriffe auf denselben Bereich des Flash-Speichers, aber zum einen ist die Konfiguration eines solchen setups nicht trivial, und zum anderen Linux reagiert auf Störungen im Zugriff auf Systemlaufwerke sehr empfindlich. Da aber ausgerechnet die Stromversorgung der USB-Schnittstellen am Pi ebenfalls nicht optimal ist, lohnt der Aufwand für Einsteiger nicht (es sei betont: das ist meine Meinung!).  
  
Du merkst dir zum Thema Raspberry Pi aber bitte an der Stelle drei Dinge:  

1. Ziehe niemals den Stecker des Pi, wenn er nicht sauber heruntergefahren wurde. Das führt häufig zu defekten SD-Karten!  
1. Wenn du FHEM im produktiven Einsatz hast und es nicht mehr missen willst, brauchst du unbedingt Backups, die nicht auf der SD-Karte liegen und mußt jederzeit in der Lage sein, eine andere Karte in den Pi zu stecken und mit der - mehr oder weniger 1:1 - weiterzumachen...  
1. Finger weg von den PI-GPIO!
  
Den letzten Punkt verstehst du vermutlich nicht gleich: Der Pi ist ein "Bastelrechner", an den man "alles mögliche" an Hardware auch direkt anschließen kann, man muss nur manchmal ein paar Kleinigkeiten am Betriebssystem umkonfigurieren, und schon läuft das. Das führt aber dazu, dass man die Steuerungslogik (FHEM) sehr eng an ein bestimmtes Hardwaresystem bindet (Raspberry Pi). Viele FHEM-Nutzer stellen aber irgendwann fest, dass sie doch lieber eine andere Hardwareplattform einsetzen wollen. Dann wird es kompliziert, beide Teile wieder zu trennen. Außerdem können sich die Methoden ändern, wie die GPIO angesprochen werden, wenn eine neue Hardwarerevision erscheint oder eine grundlegende Versionsänderung des Betriebssystems stattgefunden hat.  
Kurz: Mittelfristig wird es Probleme machen, also lass‘ es besser!  
  
***Tipp:***  
*Die einzige Hardware-Erweiterung für GPIO am Pi, die ich empfehlen würde, ist eine [RTC](https://wiki.fhem.de/wiki/Raspberry_Pi#Echtzeituhr)! Die brauchst du aber auch nur deswegen, weil die schlicht von den Machern des Pi "vergessen" wurde; bei den meisten anderen Alternativen gibt es eine RTC...*  

\footnotesize
***Für später 1:***  
*Will man (meist günstige) Sensorik einsetzen, die man mit Pi-GPIO's auslesen könnte, ist für diese Sensoren in der Regel auch eine "library" für "Arduino" verfügbar. Dann kann und sollte man einen Microcontroller programmieren, der diese Sensoren ausliest und das Ergebnis an FHEM übermittelt. Das mag für dich als Anfänger zunächst befremdlich klingen, ist aber im Ergebnis meist nicht besonders schwer zu erlernen und umzusetzen, häufig gibt es dafür fertige Bauvorschläge!*  

*Ein paar Links dazu: [MySensors](https://www.mysensors.org/build): Einfache Bauanleitungen für typische Sensorik, auch für [Tasmota](https://tasmota.github.io/docs/#/Home) oder [ESPEasy](https://www.letscontrolit.com/wiki/index.php?title=ESPEasy) zu gebrauchen. Typische Pi-GPIO-Anwendungen lassen sich insbesondere sehr einfach auch über [ArduCounter](https://fhem.de/commandref_modular.html#ArduCounter) (Auswerten von S0-Zählimpulsen) und [Firmata](https://wiki.fhem.de/wiki/Arduino_Firmata) (direkte Auswertung der PINs externer Microcontroller mittels Perl) verwirklichen.*  


***Für später 2:***  
*Es gibt eine ganze Anzahl von stromsparenden Alternativen zum Raspberry Pi. Neben diversen anderen [SBC's](https://de.wikipedia.org/wiki/Einplatinencomputer) auf ARM-Basis gibt es einige x86-Systeme. Bei der Auswahl solltest du dann allerdings darauf achten, dass die gewählte Plattform vollständig Linux-kompatibel ist, was v.a. bei neu erscheinenden Intel NUC-Systemen nicht immer gleich bei Erscheinen der Fall ist. Es ist in der Regel empfehlenswert (und auch ausreichend), eine Version zu wählen, die bereits einige Zeit am Markt verfügbar ist, und deren "Mucken" bereits bekannt bzw. ausgemerzt sind.*  
\normalsize    


## Linux - nimm's lite!

Linux mag für dich - wie für viele Einsteiger in die Welt der Hausautomatisierung - völliges Neuland sein, um das du gerne "rumkommen" würdest. Du kannst FHEM - im Unterschied zu vielen anderen HA-Lösungen - auch auf einem Windows-Rechner laufen lassen. Das hat aber zumindest einen großen Nachteil: die meisten anderen User tun genau das nicht. Die verwenden zu >95% ein Debian-basiertes Linux. Bei manchen Fragen kann dann von diesen 95% keiner helfen...  
Daher: Nimm' ein Linux und erarbeite dir nach und nach das notwendige Wissen, um deinen Server zu administrieren!   Nimm' auch nicht irgendeines, sondern entweder raspbian - und zwar genauer: in der lite-Version, also ohne GUI! - oder ein Debian oder Ubuntu, falls du eine x86-basierte Hardware gefunden hast. Auch in letzterem Fall gilt: ohne GUI!  
  
\footnotesize 
***Für später:***  
*Solltest du ein „richtiges“ x86-System einsetzen wollen, findest du im Wiki unter *[Thin Client Hardware](https://wiki.fhem.de/wiki/Thin_Client_Hardware)* eine Anleitung, die zwar bereits 2017 erschienen ist, aber im Kern immer noch für alle x86-basierten Systeme gültig und aktuell ist.*  
\normalsize  
  
***Hintergrund:***  
*Dein Server wird im Hintergrund laufen, wie z.B. auch dein Router (z.B. FritzBox). Hast du an den schon mal einen Bildschirm angeschlossen?!? Siehst du - das ist für ein Serversystem nicht nötig! Man aktiviert eine Zugriffsmöglichkeit aus dem Netzwerk namens **ssh** und administriert das ganze Betriebssystem dann über die Kommandozeile. Programme wie FHEM kann man dann über den Browser einrichten - ganz genauso wie du das von deinem Router her kennst!*  
  
*Sofern du jetzt denkst: "Okay, habe ich gehört, aber eine GUI zu haben, kann ja nicht schaden...!": Doch, tut sie! Das sind Programmpakete, die du installierst, und auch diese können Fehler und Angriffsflächen für potentielle Eindringlinge enthalten! Sie sind daher ein Sicherheitsrisiko. Das mag übertrieben klingen, ist aber eine Tatsache. Mache es dir ganz allgemein zum Grundsatz, nur Dinge zu installieren, die du für deine Vorhaben UNBEDINGT benötigst! Nicht mehr, nur das!*  

Als **absolutes Grundlagenwissen** zu Linux sind folgende deutschsprachigen Artikel bei [Ubuntuusers](https://wiki.ubuntuusers.de/) zu empfehlen:

- [Benutzer und Gruppen](https://wiki.ubuntuusers.de/Benutzer_und_Gruppen/)  
- [sudo](https:/wiki.ubuntuusers.de/sudo/)  
- [manpages](https://wiki.ubuntuusers.de/man/)  
  
Die Informationen von Ubuntuusers.de sind fast immer ohne weiteres auch auf andere Debian-Derivate (also v.a. auch auf raspbian) übertragbar, dies sollte also deine erste Anlaufstelle sein, wenn du Informationen zu deinem Server-Betriebssystem suchst.  
  
Ein wichtiger **Merksatz** aus der Linux-Welt hat mir immer wieder geholfen: ***Alles ist eine Datei!*** Das bedeutet nicht mehr, aber auch nicht weniger, dass jede in einem Linux-System verfügbare Information "*irgendwo unter /*" zu finden ist und damit auch "*irgendwem*" gehört und z.B. außer diesem bestimmten "*user*" nur "*Mitglieder*" bestimmter "*Gruppen*" auf diese Information zugreifen dürfen. Dies verstanden zu haben bedeutet, etwa 70% der Probleme nicht zu haben, über die Linux-Einsteiger gerne stolpern. Also falls du nicht weiterkommst, könntest du zuerst über "alles ist eine Datei" nachdenken.  
  
Eine kleine Auswahl an Programmen, die dir das Leben mit einem Linux-Server erleichtern können, sind im Anhang unter [Nützliches](#nützliches-tools-und-fundstücke) zu finden. Dort findet sich auch eine kurzes Howto zu [ssh](#ssh)-Verbindungen von Windows, über die du künftig hin und wieder Administrationsaufgaben an dem Server selbst erledigen wirst.  
  
Hast du einen Rechner besorgt, und den mit einem Debian-basierten Linux aufgesetzt, installierst du jetzt FHEM, am einfachsten über den ***easy way***, wie er unter [debian.fhem.de](https://debian.fhem.de) beschrieben ist - falls du kein Englisch sprichst: nicht verzagen, nach dem Klick auf *easy way* erscheinen nur ein paar Kommandos, die du einfach abschreiben kannst, aber mit den richtigen Rechten ausführen mußt: *sudo* kennst du ja bereits. Dabei solltest du dir merken, unter welcher IP-Adresse bzw. unter welchem Namen dein FHEM-Server im lokalen Netzwerk zu erreichen ist. Wenn du einen Pi nutzt, solltest du (neben Selbsverständlichkeiten wie dem Passwort und eventuell dem Usernamen pi!) den "*hostname*" anpassen, normale Linux-Distributionen fragen ausdrücklich danach. Im Folgenden gehe ich davon aus, dass der Server als "*fhem\_server*" angesprochen werden kann.  
*Ok, fassen wir zusammen:*  
Wir haben jetzt (vorläufig) einen Server, (wenn es kein "Spielsystem" ist: ohne GUI), und FHEM kannst du entweder manuell als Perl-Script aus dem entpackten Verzeichnis starten, oder es wurde durch die Installation des Debian-Pakets automatisch in die Startmechanismen des Servers eingebunden (heute in der Regel in den [systemd](https://wiki.ubuntuusers.de/systemd)-Dienst). 


