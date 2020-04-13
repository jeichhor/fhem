
# Nützliches, Tools und Fundstücke

## Arbeiten mit einem headless Linux-Server

### ssh
Eine sogenannte *secure shell* ist eine gesicherte Verbindung, die du vor allem brauchst, um über die Linux-Konsole des Servers z.B. das Betriebssystem zu installieren (oder FHEM, benötigte Perl-Module usw.). Derartige Verbindungen setzen auf dem Zielrechner eine entsprechende Serverkomponente voraus, die bei Raspbian bereits installiert, aber seit einiger Zeit nicht aktiviert ist. Sofern die Anleitung, der du gefolgt bist hierzu keine Informationen enthalten hat, mußt du die jeweils aktuelle Aktivierungsanleitung suchen. 
Ist der Serverdienst dann aktiv, kannst du dich von einem Linux aus von einer beliebige Konsole aus anmelden, ebenso von jedem aktuellen Windows aus, indem du ein Shell-Fenster öffnest: Dazu die *Windows-Taste* drücken, `cmd`eingeben und schon hast du ein hübsches scharzes Kommandozeilen-Tool, in das du `ssh pi@fhem_server` eingeben kannst (*pi* wäre durch den geänderten Benutzernamen zu ersetzen, statt `fhem_server`kannst du gerne auch die IP-Adresse eingeben).

![ssh in der Windows-Kommandozeile][ssh_at_win_cmd]  

Danach gibt es ggf. ein kleines Authentifizierungsverfahren und der Austausch von Hashes, um bei weiteren Anmeldungen möglichst manipulationssicher feststellen zu können, dass die Anfrage wirklich vom selben Rechner kommt wie die erste Anfrage.
Das war es auch schon - du kannst den Server jetzt von überall her konfigurieren, sofern du überhaupt eine Netzwerkverbindung zu ihm herstellen kannst. Auß dem Internet heraus geht das nicht ohne weiteres, da dies die firewall-Funktion deines Routers verhindert.  

### Midnight Commander
Der [Midnight-Commander], kurz *mc*, enthält zwei für mich sehr wichtige Programme: Den eigentlichen Dateimanager (Aufruf an der Linux-Konsole mit `mc`), der auch von einem entfernten Rechner aus bedient werden kann, und mit dem man fast alle notwendigen Dateioperationen im FHEM-Umfeld erledigen kann, und den Editor *mcedit*.  
  
Installation an der Linux-Konsole: `sudo apt-get install mc`  
  
### Notepad++
Noch ein [Editor][notepad++], aber einer für Windows. Schreibt Linux-konforme Textfiles und beherrscht Syntax-Highlighting für *Perl* und FHEM-Konfigurationen. Details hierzu und weitere Editor-Programme findest du im [Wiki][Syntax_Highlighting].  

### Winscp
Ebenfalls ein [Dateimanager][winscp],
allerdings für Windows. Damit kann man sich von einem Windows-Rechner aus mit *ssh* zum FHEM-Server verbinden, und – je nach Berechtigung des ssh-Nutzers – Dateioperationen ausführen und auch auf den Windows-Rechner kopieren. Dies erübrigt die Einrichtung eines *samba*-Diensts auf dem FHEM-Server.  
  
## Perl, regex und Co.

### Perl

#### Literaturtipps zu Perl
([Thread][Perl-Tips-Thread]).  

#### Paketverwaltung: cpan
Wie in ... erläutert, mußt du dich auf mehreren Ebenen um Software-updates kümmern und gelegentlich auch weitere Perl-Pakete installieren. Perl kennt eine eigene Paketverwaltung namens cpan. Meistens benötigt man diese nicht, die Module bzw. updates, die die jeweilige Linux-Distribution für Perl-Pakete bereitstellt, sind in der Regel ausreichend. Gelegentlich kann es allerdings vorkommen, dass einzelne FHEM-Module weitere Perl-Pakete benötigen, für die es auch keine apt-Quellen gibt. Dann muß man diese mittels cpan nachladen. Ich persönlich finde es unschön, irgendwelche Teilsoftware "quer" zur allgemeinen Paketverwaltung zu installieren und "debianisiere" daher erforderlichenfalls cpan-Pakete mit dem Tools aus dem Paket *dh-make-perl*: Das erzeugt .deb-Pakete, die man dann auch mit apt-Mitteln "sauber" (de-) installieren kann, und ermöglicht es vor allem auch festzustellen, in welchem bereitgestellten debian-Paket ggf. einzelne Perl-Bibliotheken enthalten sind. 
Details entnimmst du bitte der betreffenden manpage.  

#### Perlbrew
Eher für Entwickler interessant:
(perlbrew is a program to automate the building and installation of perl in an easy way. It provides multiple isolated perl environments).

#### perlcritic
*perlcritic* ist ein script, um Perl-Programmcode auf Einhaltung der *Perl Best Practices* zu überprüfen. Manches ist nicht unumstritten, und wer weiß, was er tut, kann die dortigen Hinweise auch ignorieren. Für "Gelegenheitsprogrammierer" jedoch ein einfacher Weg, typische Fehler zu erkennen und zu vermeiden. 

### Online regex-Tester
Auf den Seiten [regexr.com](https://regexr.com/) und [regex101.com](https://regex101.com/) kannst du eigene regex-Ausdrücke testen und einiges über die Syntax erfahren.  
  
## Zur Serverwahl: Alles Pi oder was?

### Meinungsbilder
...zum Stand 2018 samt einigen evtl. nützlichen weiteren Infos wäre z.B. in diesem [Thread](https://forum.fhem.de/index.php/topic,88191.msg806024.html#msg806024) zu finden, etwas aktueller, aber ansonsten ähnlichen Inhalts mit Stand 2020 siehe diese [Diskussion](https://forum.fhem.de/index.php/topic,100024.0.html).
  
### Armbian
Auf den Seiten von [armbian.com](https://www.armbian.com/) findest du einige alternative Single-Board-Computer-Plattformen, auf denen man FHEM ebenfalls betreiben kann. Hardware, die dort unter den unterstützten Plattformen zu finden ist, ist in der Regel ebenfalls für den längerfristigen Einsatz geeignet; fast alle diese Systeme bieten neben SD-Karten-Slots noch weitere Anbindungen für Massenspeicher an: entweder über eMMC oder es gibt mindestens einen SATA-Anschluss; beides ist nicht nur schneller, sondern hat auch andere technische Vorteile, angefangen vom „wear-leveling“ des flash-Speichers.  
  
### Headless - mit Bildschirm?
Auch wenn du unbedingt einen Bildschirm anschließen willst, um FHEM direkt "am Pi" bedienen können willst, benötigst du nicht zwingend eine vollständige GUI-Installation. Als Ausgangsbasis ein paar Stichworte und Links:  

- FRAMEBUFFER - Modul  

- Einfachstbrowser ohne vollst. GUI - Beispiel midori und chromium-Browser  

 - [raspberry pi: browser nach systemstart im fullscreen starten](http://www.itbasic.de/raspberry-pi-browser-nach-systemstart-im-fullscreen-starten/)  
 
 - [chromium on raspberry pi without desktop](https://www.ketzler.de/2017/12/installing-chromium-on-raspberry-pi-without-desktop/)  

- [TOUCHSCREEN-Modul](https://forum.fhem.de/index.php/topic,32549.0.html)  

  
## Nettes und Nachdenkliches am Rande

### Wozu braucht man FHEM?  

Antworten [anno 2012](https://forum.fhem.de/index.php/topic,9267.0.html) 
und [anno 2019](https://forum.fhem.de/index.php/topic,98685.msg920305.html#msg920305).
  
### Software-Entwicklungskonzepte  

Oder: [Die Kathedrale und der Basar](https://de.wikipedia.org/wiki/Die_Kathedrale_und_der_Basar)  
  
### Nach mir die Sintflut?!?  

[Gedanken zum SmartHome, dem Leben und dem Ende desselben](https://forum.fhem.de/index.php/topic,82839.msg749691.html#msg749691)  


