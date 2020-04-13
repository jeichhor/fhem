
# Planung deines Heimautomatisierungs-Systems

## Grundlegendes zur Wahl eines Hardwaresystems

Dann wollen wir jetzt kurz gemeinsam beleuchten, was bei der
Hardware-Auswahl alles zu beachten ist.

### Vokabeln 1 - Sensor, Aktor, Interface, Protokoll
  
***-> Muß evtl. nach vorne! (teilweise erledigt) <-***
  
Dazu brauchen wir zunächst ein paar gemeinsame „Vokabeln“:  

- Von einem Sensor sprechen wir, wenn wir es mit einem Stück Hardware zu tun haben, das irgendwelche Informationen, v.a. Messwerte an FHEM übermitteln soll. Klassisches Beispiel wäre ein Temperaturfühler.  

- Ein Aktor ist dagegen ein Stück Hardware, der wir von FHEM aus Anweisungen schicken, etwas zu tun. Ein einfaches Beispiel wäre ein fernsteuerbares LED-Leuchtmittel.  

- Nun kann man zwar die auf dem Motherboard des Servers vorhandene Temperatur-Sensoren direkt mit FHEM und etwas Perl auslesen, aber z.B. bei einem Außentemperatursensor, der seine Messwerte per Funk an die Basisstation auf deinem Schreibtisch übermittelt, ist das schon etwas anders. Für diesen brauchen wir eine Funkschnittstelle, um den Funkverkehr zu "hören" (1). Wir müssen die Daten von der Funkschnittstelle irgendwie interpretieren (2) - in der Regel macht dies ein Microcontroller, der z.B. in einem CUL oder SignalDuino (2) verbaut ist - und am Ende daraus dann die eigentliche Information (die Temperatur) ableiten (3) und an einer Stelle ablegen, an der wir sie reproduzierbar wiederfinden (4). In unserem Beispiel mit dem Außenfühler nennen wir sowohl die unter (1) und (2) genannte Hardware "Interface" oder auch "IO", wie auch die unter (3) genannte Software. Um die beiden "Interface"- und "IO" Begriffe auseinanderzuhalten, versuche ich nachfolgend von "Hardware-Interface" und "IO-Modul" zu sprechen. Aber auch das hat gewisse Haken: Es gibt Interfaces, bei denen auch ein großer Teil der Software nicht innerhalb von FHEM läuft (deCONZ oder HomeMatic-CCU wären hier stellvertretend zu nennen), und: es gibt Hardware, die direkt in Netzwerk eingebunden werden und gar keine speziellen physischen Schnittstellen benötigen, um mit FHEM Daten austauschen zu können, wie z.B. der o.g. Shelly-Plug.  
Häufig taucht auch der Begriff "Gateway" auf. Dies bezeichnet in der Regel ein "Hardware-Interface", das meistens mit einem TCP/IP-Protokoll mit dem FHEM-Server kommuniziert.  
  
Zurück zu unserem Beispiel mit dem Shelly-Plug: Dieser schaltet also auf Anweisung ein, ist demnach ein Aktor. Er sendet aber nicht nur seinen Status zurück, wenn er geschalten hat, sondern weitere Messdaten, z.B. den Energie-Verbrauch. Er ist also auch ein Sensor. Damit ist er ein typisches Beispiel für moderne Aktoren, die selten nur den Aktor als solchen beinhalten, sondern auch weitere Meßwerte und Informationen senden.  
Doch wie genau kommuniziert der Shelly mit FHEM? Er nutzt Funk, konkret muß man ihn in das eigene (W)LAN einbinden, damit man ihn in FHEM nutzen kann. Aber was genau das bedeutet, ist damit noch nicht gesagt, denn (W)LAN (bzw. TCP/IP) ist zunächst mal nur ein Transportverfahren, aber noch lange keine gemeinsame "Sprache". Diese gemeinsame Sprache, die zwei Geräte miteinander teilen, nennen wir "Protokoll". Im Fall des Shelly kann dass HTTP sein (das nutzt z.B. das Modul "Shelly") oder "MQTT". Das HTTP-Protokoll ist bei dem Shelly immer aktiv, MQTT muß erst aktiviert werden. Falls du also als Testhardware Shelly-Plugs besorgt hast, aktivierst du jetzt das MQTT-Protokoll entsprechend der Bedienungsanleitung des Herstellers. Als Serveradresse gibst du die IP des FHEM-Servers ein.  
Hast du als Testhardware z.B. einen CUL oder Signalduino und einen alten Funk-Temperatursensor, nutzen wir sogar auf zwei Ebenen ein "Protokoll" - zum einen das "serielle Protokoll" zwischen der USB-Schnittstelle und dem Server und irgendein "Funkprotokoll" zwischen der vom Microcontroller überwachten Funkschnittstelle und dem Sensor. Kannst du keine Meßwerte empfangen, mußt du prüfen, dass beide Protokolle jeweils vom "Interface" "gehört" und "verstanden" werden...  
  
Darauf aufbauend ein paar grundlegende Anmerkungen zur Hardware-Auswahl:
  
### Kabel, Kabel, Kabel!
Je weniger störanfällig die Kommunikation auf allen Ebenen ist, desto mehr Freude wirst du langfristig haben. Daher ist der wichtigste Grundsatz: Wann immer es möglich ist, nimm' ein Kabel!  
Ein einfaches Beispiel: Schaltest du eine Steckdose über eine 230V-Ader ein und aus und der Aktor befindet sich in einem zentralen Schaltschrank, kann das auch in 40 Jahren noch jeder nachvollziehen und "debuggen", der über elektrische Grundkenntnisse und einfache Meßmittel verfügt. Ist auch die Kommunikation zwischen dem Aktor und den FHEM-Server verkabelt und nutzt einfache Übertragungstechnik und ein "offenes" Protokoll (also eines, für das quelloffene Software verfügbar ist), kann man alle Elemente (Aktor, Hardware-Interface und Serversoftware) recht einfach tauschen, selbst dann, wenn die ursprünglich verbaute Technik gar nicht mehr am Markt verfügbar ist. Um ein solches System zu manipulieren, muss man sich als Eindringling physisch mit dem System verbinden, also irgendwo entsprechende Kabel anklemmen und dann wissen, wie das System funktioniert.  
Daraus folgt: Wen du einen Neubau planst, solltest du unbedingt (!) eine ausreichende Anzahl von Kabeln/Kabeladern verlegen und dabei im Auge behalten, dass ein Ethernet-Kabel zwar auch ein Kabel ist, aber nur bedingt geeignet zur (gemeinsamen) Übertragung von Informationen "konventioneller" Bussysteme. Hierfür solltest du daher zusätzliche Kabel einplanen.  
Bei der Planung derartiger Systeme ist es empfehlenswert, einen Fachmann hinzuzuziehen. Er kann dich dann auch beraten, was Einbindungsmöglichkeiten in HA-Systeme wie FHEM angeht, eine Übersicht zu unterstützter Hardware findest du auch im Wiki unter [Systemübersicht: Protokolle][Systemübersicht-Protokolle]. Falls du etwas suchst, mit dem du selbst zumindest einfache Sensorik (insbesondere: Temperaturen, Zähler) verkabelt ausführen kannst, lohnt ein Blick auf das [1-wire-System][1-wire-System]: Das erfordert keine vertieften Elektronik-Kenntnisse oder eigene Programmierungen, und nicht viel mehr wie ein (fast) beliebiges Kabel mit 2, besser 3 freien Adern! Für ambitionierte Bastler gibt es auch mehrere Lösungen auf Arduino-Basis, die sich zum Einstieg in die Welt der Microcontroller-Programmierung m.E. gut eignen (ich hätte auch nie gedacht, dass mich das mal interessieren könnte, also verlege vorsorglich einfach genug Kabel...).
  
### Funk - Nichts als Kompromisse?!?
Noch nicht überzeugt, denn für Kabel hattest du kein Budget vorgesehen?  
Man *kann* auch fast alles (nachträglich) mit Funk machen, aber das hat ein paar gravierende Nachteile:  
Funk ist nämlich störanfällig und auf mehrfache Weise begrenzt!  
Was "störanfällig" betrifft: Führe eine Internetrecherche nach *babbling idiot* und *Fernbedienung Schublade* durch. So ähnlich bei Autos schon vorgekommen: Legt ein Angreifer es darauf an, kann er gezielt gängige Bandbreiten abhören, den Verkehr ggf. dekodieren und sich einklinken. Wenig spaßig, wenn man damit den Türöffner aus der Hand gibt. Etwas weniger aufwändig, aber fast genauso wichtig: Mit Bauteilen für ein paar Euro kann man gängige Frequenzen in der Breite komplett stören und die gesamte Funk-Kommunikation damit effektiv unterbinden. Insbesondere "Alarmanlagen" auf Funkbasis funktionieren dann auch nicht mehr...  
  
Funk ist auch in mehrerlei Hinsicht sehr begrenzt:  
Zur Einarbeitung in die Thematik, die nicht nur auf 868MHz beschränkt ist, sei die ["1%-Regel"][1%-Regel] empfohlen.  
Es gibt nur wenige erlaubte Frequenz-Bereiche ("Bänder"), die teilweise für mehrere Übertragungsverfahren genutzt werden. So kann z.B. die ZigBee-Kommunikation durch WLAN gestört werden, entsprechendes gilt für Bluetooth, das ebenfalls das Band um 2.4GHz nutzt. Es kann trotz 1%-Regel zu Kollisionen zwischen verschiedenen Funktelegrammen kommen. Ist ein Band überlastet, weil z.B. auch einige Nachbarn dasselbe Band nutzen, kann sich der Effekt sogar verstärken, bis die gesamte Funklast wieder unter ein kritisches Maß reduziert wird, was in der Regel den Abbau eines Teils der Hardware bedeutet...  
Auch hinsichtlich der Reichweite ist Funk mehr oder weniger begrenzt:
Zwar sind hier "klassische" HA-Lösungen wie HomeMatic und Z-Wave etwas besser als ZigBee und Bluetooth (die in etwa nur ähnliche Reichweiten erreichen wie WLAN), aber häufig ist es bereits in Bauten neueren Datums schwierig, mehr als eine Stockwerksdecke zu durchdringen. Zwar bieten hier Technologien Vorteile, die *Mesh* kennen, dies führt andererseits aber wieder zu mehr Funktelegrammen, die ggf. das Funkbudget belasten oder zu Kollisionen führen.  
Es mag zwar Systeme geben, die den Umgang mit Kollisionen optimieren, aber dies führt zu mehr Software auf den Komponenten - ich habe den leisen Verdacht, dass das der Grund ist, warum ich hin und wieder manche ZigBee-Komponenten kurz stromlos machen muß, wenn sie über das Gateway nicht mehr erreichbar sind...  
  
Die Kurzfassung: Selbst das beste Funksystem ist also nichts weiter als ein schlechter Kompromiss... Denk' nochmal über Kabel nach, wenn irgend möglich ändere deine Prioritäten bei der Budgetierung!  
  
## Die Qual der Wahl 2 - Hardware-Systeme 2020
Ok, wir haben es vermasselt, die Hütte ist gebaut, und neue Schlitze machen Staub und Dreck. Also doch Funk...  
Im Folgenden daher ein paar Erfahrungswerte als Stichwortliste zu diversen Funk-Hardwaresystemen, die heute am Markt sind:  
  
### HomeMatic

Vorneweg: es gibt nicht ein HomeMatic-System, sondern "viele" HomeMatic-Varianten, die teilweise nicht viel miteinander gemein haben!

#### Classic/BidCoS:

+ Etabliert, gut dokumentiert, Eigenbauten möglich  

+ Insbesondere die Heizkörperthermostate HM-CC-RT-DN lassen nahezu keine Wünsche offen, wenn man autonom arbeitendes System mit Wochenprogramm-Steuerung sucht (HM-IP dürfte vergleichbar sein).  

- nur bedingt einbruchsicher, jeder kann mitlesen; spezielle Komponenten teils extrem teuer, manche Hardwarefehler tauchen immer wieder auf (C26, klebende Relays, vergessliche Fensterkontakte, abgebrochene IR-Dioden am RT-DN)  

- System ist abgekündigt  

#### HM-IP

+ kann mit Einschränkungen Mesh, voll verschlüsselte Kommunikation  

- Braucht ein eigenes Gateway (CCU, virtualisiert möglich)  

#### HM-Wired

#### HM-Wired-IP (recht neu)

Beides getrennte Systeme; scheint zu funktionieren.  
  
Alle 4 Systeme kennen direkte Kommunikation innerhalb des eigenen Sub-Systems, aber Subsystem-übergreifend geht nur mit "Handarbeit" und
bei Verfügbarkeit der Zentrale (CCU)  

+ HM insgesamt jeweils: relativ geringer Einarbeitungsaufwand  

+ Integration in gängige Schalterprogramme möglich  

- Schlechte Haptik von Tastern, Tasterkomponenten teil sehr klobig  
  
### Z-Wave

+ Mehrere Hersteller;  

+ Komponenten arbeiten in der Regel gut zusammen, direkte Verknüpfungen sind möglich  

+ USB/serielles-Dongle, sonst läuft Software direkt in FHEM  

+ Mesh-System  

- firmware-updates in der Regel nur über das jeweilige eigene Gateway des Herstellers  

- höherer Einarbeitungsaufwand  

- Informationen zu einzelen Komponenten sind in der Regel schwer zu bekommen, Verbreitung in D eher gering  
 
 - Störungen der Funkkommunkation scheinen bei steigender Zahl der Komponenten zuzunehmen -> Komponentendichte ist zu begrenzen?  
  
### EnOcean

+ USB/serielles-Dongle, sonst läuft Software direkt in FHEM  

+ Einziges System mit "Energie-harvesting" Komponenten (batterielos) (?)  

+ Mehrere Anbieter, Angebot richtet sich aber eher an den Fachhandel -> tendenziell etwas höhere Preise als HM/HM-IP oder ZWave;  

- höherer Einarbeitungsaufwand  

### ZigBee

+ große Zahl an Anbietern  

+ häufig günstige Komponenten verfügbar  

+ mehrere Gateways vorhanden, darunter mit deCONZ oder zigbee2mqtt zwei open-Source Lösungen  

+ teils firmwareupdates nicht an das jeweilige Herstellergateway gebunden  

- Kollissionen bekannt  

- teils hängende Komponenten bekannt  

- firmwares nicht immer frei verfügbar  

-  Direktverknüpfungen zwichen Komponenten teils möglich, aber Funktionsweise idR. schlecht nachvollziehbar  

- (noch) recht geringe Anzahl von Komponenten für europ. Unterputzdosen und Schalter  

+ :+1: große Anzahl an Komponenten für Beleuchtung

### WLAN (HTTP/MQTT)

+ [ ] unüberschaubare Zahl von Anbietern, in der Regel aus Fernost  

+ [x] Günstig  

- [ ] "dem Einsteiger bekannte" Übertragungstechnik  

- [ ] Black-Box: In der Regel ist unbekannt, was konkret verbaut ist. Es gibt insbesondere keine Garantie, dass die firmware getauscht werden kann, um den nächsten Punkt zu lösen:  

  * Datenschutz: Fehlanzeige - standardmäßig werden Cloudlösungen in Fernost verwendet  

  * teils recht hoher Eigenverbrauch der Komponenten  

  * WLAN:  
    * braucht idR. viele komplexe Komponenten auf dem Weg zwischen Aktor und FHEM (Minimum: (Aktor) <- WLAN -> (WLAN-AP/Router) <- LAN -> (FHEM-Server); hinzu kommen ggf. weitere Router)  
    * bricht die WLAN-Verbindung ab, buchen sich die Komponenten teils nicht mehr automatisch ein  
    * Speicherung der WLAN-Credentials teils unverschlüsselt -> Sicherheitsloch, v.a. dann, wenn die Komponenten frei zugänglich sind.  
    * Bei Änderung der WLAN-Zugangsdaten müssen die Daten auf allen Komponenten geändert werden  
    * Gängige Consumer-Router sind in der Regel ungeeignet, eine größere Anzahl dieser WLAN-Komponenten zu verwalten -> es sollte spezielle Infrastruktur eingeplant werden, die entsprechende Hardware muss auch konfiguriert werden -> höherer finanzieller und planerischer Aufwand!  
  
Was man spätestens im Jahr 2020 vermeiden sollte, sind Geräte ohne direkte Statusrückmeldung an FHEM, wie das z.B. bei den früher beliebten "Baumarktsteckdosen" der Fall war (433MHz-Geräte). Man kann solche System aber heute immer noch erwerben, z.B. Leuchtmittel, die das MiLight-Protokoll nutzen. Bevor du also was anschaffst, vergewissere dich, dass es *bidirektional* arbeitet! Sonst gilt: wer billig kauft, kauft doppelt...  

\footnotesize 
***Hintergrund-Infos***  
*Mein derzeitiges System (Altbau) sieht so aus: die meisten Komponenten sind HomeMatic-BidCoS, v.a. Heizkörperthermostate und Fensterkontakte (überwiegend mit Drehgriff-Erkennung), das ganze läuft mit einem an USB angeschlossenen HM-Mod-RPi-PCB, einem MapleCUN und einem CUL als Interfaces unter einer VCCU. Da HomeMatic-BidCoS ausläuft, werde ich alles an simpler Ein-/Aus-Aktorik nach Z-Wave umbauen, alles was dimmbare und farbige Beleuchtung angeht, ist bzw. wird noch ZigBee (deCONZ, installiert auch auf dem FHEM-Server). ZigBee wird auch die Alternative für große Teile der Batterie-Sensorik sein, wenn zukünftig HomeMatic-Hardware zu ersetzen sein wird. Dazu habe ich derzeit experimentell Bluetooth-Sensoren im Einsatz, vorwiegend zur Anwesenheitserkennung und für Raum-Temperatursensoren.*  
*Im Keller werkelt ein MySensors-Netzwerk auf RS485-Basis (=verkabelt!), v.a. mit Temperatursensoren für die Erfassung von Heizungs- und Umweltdaten.*  
*An WLAN-Geräten werkeln nur 2 Steckdoseneinsätze (Tasmota), mehrere OpenMQTTGatways (Empfang von Bluetooth- und Infrarot-Signalen) und ein MiLight-Hub, der aber immer weniger zu tun hat, weil die betreffenden Leuchtmittel nach und nach durch ZigBee-Varianten ersetzt werden.*  
\normalsize  


## Die Qual der Wahl 3 - Das passende Interface
So, jetzt hast du also die Wahl für ein oder mehrere Hardware-Systeme getroffen, oder wenigstens eine Vorauswahl?   
Dann mußt du jetzt entscheiden, welches Interface genutzt werden soll.
Manchmal ist es einfach: Erst mal nimmst du, was da ist! Es ist zum Einstieg in der Regel ziemlich gleichgültig, welche Variante man wählt, meistens - aber leider nicht immer - kann man auch später noch das Interface wechseln. Wichtig ist zunächst einmal, dass das jeweilige Gateway von FHEM unterstützt wird. Ist das nicht der Fall, mußt du entweder ein neues Modul beisteuern oder ein anderes, unterstütztes Interface suchen. Eine Anmerkung noch zu vorhandenen Interfaces: Du solltest nach der Einarbeitung nochmal überprüfen, ob das jeweilige Interface wirklich auch unter technischen Gesichtspunkten optimal ist. Wenn nein, solltest du es austauschen! Das kann aber unter Umständen bedeuten, dass in FHEM einiges geändert werden muß, z.B. weil Geräte des Typs MQTT2\_DEVICE in den Typ HUEDevice "umgewandelt" werden müssen, weil nicht mehr zigbee2mqtt als Interface (zusammen mit einem CC2530-USB-Dongle) verwendet werden soll, sondern eine separate HUE-Bridge oder ein ConBee II mit der Software deCONZ (oder umgekehrt!).  
  
Wie jetzt also das passende Interface wählen, wenn man keines hat:  

- Für Z-Wave nimmst du z.B. einfach eines der empfohlenen USB-Dongles.  

- Falls du HomeMatic einsetzen willst, wird mittelfristig kein Weg an HM-IP vorbei gehen. Das bedeutet, dass du eine CCU benötigst. Sofern du dich an eine virtualisierte Lösung traust, wäre hier piVCCU ein Stichwort, ansonsten nimmst du einen separaten Pi und einen der von eQ-3 angebotenen Bausätze und eine beliebige Software-Variante für eine Selbstbau-CCU; dann kommen die HMCCU-Module zum Einsatz. Bist du dir sicher, dass es bei HomeMatic-BidCoS bleiben wird, besorgst du ein HM-Mod-RPi-PCB und bindest das als HMUARTLGW in FHEM ein, alle HomeMatic-Sensoren und Aktoren sind dann vom Typ CUL_HM.  

- Für ZigBee hast du die Wahl zwischen deCONZ mit ConBee II (Ja, nimm die USB-Variante auch dann, wenn du mit einem Pi startest! Das Thema hatten wir schon...) oder zigbee2mqtt. Beides kann direkt auf dem FHEM-Server mit betrieben werden. Stand heute ist deCONZ eher für eine größere Anzahl von Geräten in der Installation zu empfehlen, diese ist bei zigbee2mqtt durch den verwendeten Microcontroller begrenzt, wobei ich eine Wette eingehen würde, dass diese Beschränkung in nicht allzu ferner Zukunft überholt sein wird, ebenso wie die heute noch fehlende Möglichkeit, über zigbee2mqtt firmware-updates auf die Geräte zu laden...  
  
Du siehst: Ich bevorzuge generell USB-Dongles direkt am Server. Das hat damit zu tun, dass ich zum einen keine große Lust habe, auf einer zu großen Anzahl von Computern das Betriebssystem aktuell zu halten und zum anderen möglichst wenig Infrastruktur auf dem Weg von der Hardware zum FHEM-Server benötigen will. Das kann man auch anders lösen, aber gerade am Anfang vermeidet es einige Fehlerquellen. Nachteile daraus hat man nur, wenn man später auf eine virtualisierte Serverumgebung umziehen will, weil da das "Durchreichen" von USB-Schnittstellen teilweise etwas Einarbeitung braucht - aber auch das geht...  
  
Hast du ein weitläufiges Gebäude, eine Funktechnik mit geringer Reichweite ohne Mesh und/oder sehr viel Stahl verbaut, kann es sein, dass du für eine Funktechnik nicht nur ein Interface brauchst, sondern mehrere. Sieh' also beizeiten auch Kabel vor, um diese entfernten Schnittstellen mit FHEM zu verbinden, denn eine gute Funkverbindung zwischen dem Sensor/Aktor und dem Interface macht nur dann Freude, wenn das Interface auch über eine stabile Verbindung mit FHEM verbunden ist und nicht bei WLAN-Wacklern dauerhaft unerreichbar wird...  

## Phase 2 – Konkretisieren und Zwischenschritte planen
Du hast jetzt also erst mal einen groben Überblick, was es alles zu bedenken gibt, wenn man das Thema Hausautomatisierung angeht. Dann kannst du jetzt eine erste Strukturierung vornehmen:  

- Was hast du alles, was davon soll zu welchem Zeitpunkt in deine Hausautomatisierung eingebunden werden?  

- Was fehlt noch? Was davon soll gleich umgesetzt werden, was kann auf später verschoben werden? Insbesondere: Wenn du erst mal zwar Kabel verlegen läßt, aber die Aktoren im Schaltschrank nicht mehr finanzieren willst, kannst du erst mal alles "ganz normal" bedienen, und dann später die Teile umbauen lassen, die wirklich sinnvoll sind.  

- Wohin muß welches Strom- und Datenkabel? Kannst du alles zentral zusammenführen und dort großzügig Platz vorsehen, so dass dann auch die "Vollversion" ausreichend Platz findet?  
  
Vielleicht steht jetzt schon einiges auf deiner Liste. Einen Tipp habe ich noch: Wenn du eine Zentralheizung hast und die bisher noch nicht auf der Liste steht, ergänze das! Das ist eine Sache "für später", aber es sollten mindesten zwei (!) Netzwerkkabel vom Server zur Heizungsanlage führen und noch ein weiteres, über das z.B. ein 1-wire oder RS485-Netzwerk angebunden werden könnte. Dafür reicht ein 8-adriges Kabel, wie es auch für analoge Telefone verwendet wird.  

\footnotesize   
***Persönliches und Hintergrund:***  
*Ich habe das beim Renovieren leider vergessen, und so ziemlich überallhin Netzwerkkabel gelegt, aber nicht in den Heizraum. Selbst wenn ich darüber nachgedacht hätte, hätte ich es mit einiger Sicherheit nicht für wichtig empfunden - der Gedanke, in die Heizungsanlage selbst direkt einzugreifen, hätte mich erschreckt! Heute weiß ich, dass bei der Auslegung der Heizungsanlagen in der Regel darauf geachtet wird, dass immer genügend Wärme zur Verfügung steht. Das bedeutet aber in der Regel, dass grundsätzlich zu viel Wärme bereitgestellt wird. Der effektivste Weg, um Kosten - ohne Komforteinbuße - zu sparen, ist daher, dieses "zu viel" zu minimieren, z.B. indem man die Heizungsanlage anwesenheitsbasiert & abnahme-orientiert steuert und dabei auch in die nähere Zukunft schaut - und genau das können Heizungsanlagen nicht; sie haben schlicht keine Daten dafür, mal abgesehen von Zeitschaltuhren, die meistens auf den äußersten Werten stehen...*  
  
*Es sei aber ausdrücklich angemerkt, dass man sich dann an die tatsächliche Steuerung erst dann heranwagen sollte, wenn man wirklich weiß, was man tut! Fehler in dem Bereich bedeuten meist großen Ärger mit den Mitmenschen, die es nicht lustig finden, wenn sie frieren, und der grade irgendwo anders ist, der es (vielleicht) richten könnte! Frieren ist in den meisten Fällen deutlich schlimmer, als zum falschen Zeitpunkt im Dunkeln zu sitzen.*  
\normalsize  
  
Insgesamt gilt die Empfehlung, zwar einen späteren "Vollausbau" gedanklich vorzubereiten, aber auf keinen Fall alles auf einmal umsetzen zu wollen. Fang' erst mal mit ein paar Basissachen an, lerne daran die Umsetzung mit FHEM oder einer anderen Lösung und baue das dann nach und nach aus. Setze dabei auf Lösungen, die man später erweitern kann bzw. auf weitere Teile des Hauses übertragen. Das minimiert den späteren Pflegeaufwand.  
  
Und nochmal: Mache alles, was irgend geht mit einem Kabel. Kabel haben nur einen einzigen Nachteil: sie sind grundsätzlich zu kurz, wenn man sie einmal abgeschnitten hat... (oder die, die verlegt sind, haben zu wenig Adern...)  
  
  
## Typische Problemlagen und Lösungsansätze

### Batterien

 [https://forum.fhem.de/index.php/topic,82637.msg747514.html#msg747514](https://forum.fhem.de/index.php/topic,82637.msg747514.html#msg747514)

### Verteilte Server, FHEM2FHEM, RFHEM und MQTT

Zweite Instanz auf selbem Server:
[https://forum.fhem.de/index.php/topic,96229.0.html](https://forum.fhem.de/index.php/topic,96229.0.html)  
  
Vor- und Nachteile verteilter Systeme:
[https://forum.fhem.de/index.php/topic,108473.0.html](https://forum.fhem.de/index.php/topic,108473.0.html)  
  
### Pairing: direkt oder indirekt (Teil 2)

#### Vor- und Nachteile (Vertiefung)

### Externe Steuerung, z.B. über CCUx und deCONZ
(allg. Hinweise)
