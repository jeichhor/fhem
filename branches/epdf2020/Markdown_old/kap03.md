
# Grundbausteine einer Steuerung - Zeitschaltuhren und Überwachung
Du hast jetzt also die ersten eigenen Geräte in FHEM integriert und kannst z.B. deinen Verstärkter ein- und ausschalten oder die Lautstärke regulieren.  
Damit ist FHEM schon mal sowas wie eine "erweiterte Fernbedienung" für deine IoT-fähigen Geräte.  
  
Um daraus jetzt "eine Heimautomatisierung" mit der Betonung auf "Automatisierung" zu machen, solltest du ein paar Grund-"Bauteile" kennen lernen, die in vielerlei Variationen sowas die die DNA jeder Automatisierungslösung darstellen. Bei der DNA kennt man 4 Buchstaben, bei der Steuerung haben wir auch 4 Grundelemente, aus denen praktisch alles aufgebaut wird, wobei die beiden letzten streng genommen schon Erweiterungen bzw. einfache Kombinationen der ersten beiden sind:  
  
## Schalten nach Uhrzeit: at
Xxx text und etwas info

## Ereignisse auswerten: notify
Xxx text und etwas info

## Wichtige Erweiterungen dieser Grundformen

### Zweipunktregler (z.B. THRESHOLD)
Xxx text und etwas info

### Ausfallerkennung (watchdog)
Xxx text und etwas info
  
### Steuerung über Änderungsgeschwindigkeit (PID20)
Xxx text und etwas info

  
  
---
  
In FHEM gibt es nicht nur Module, die diesen 4 Grundelementen entsprechen, sondern auch eine ganze Anzahl von alternativen Modulen.
Neben Modulen, die ganz spezielle Zielrichtungen kennen (wie z.B. die Module aus der Residents-Familie, die wir beim Rundgang durch die Demo-Konfiguration kennengelernt haben, oder AutoShuttersControl, das zur Rollladensteuerung eingesetzt werden kann), seien an der Stelle folgende Module kurz erwähnt:  

- [WeekdayTimer] - bildet eine Wochenzeitschaltuhr nach und kann universell verwendet werden. Ein spezieller Anwendungsbereich ist die Steuerung von Heizkörpertherostaten, für die das Modul ursprünglich entwickelt wurde. Es steuert in der Regel genau ein anderes Gerät wie eine Lampe oder ein Thermostat.  
- [Timer] - kann mehrere einzelne Timer verwalten, die beliebig kombiniert werden können. Hat eine grafische Konfigurationsmöglichkeit.  
- [DOIF] und [MSwitch] sind beide jeweils sehr universelle Module, die Zeit- und Ereignissteuerungen sowie Kombinationen von beidem ermöglichen. Aufgrund der universellen Verwendbarkeit ist die Konfiguration dieser Module teils sehr komplex, wenn schwierigere Aufgaben zu lösen sind.  
- [YAAHM] - Dient ebenfalls vorrangig der Verwaltung von Timern, die sich an typischen Tagesabläufen orientieren, kann das aber für das gesamte Haus übernehmen unter Berücksichtigung weiterer Bedingungen wie z.B. Jahreszeiten usw..  
- RandomTimer - bildet eine Zeitschaltuhr mit Zufallselementen nach und wird häufig in der Anwesenheitssimulation verwendet; steuert in der Regel genau ein anderes Gerät, z.B. eine Leuchte.  
- alarmclock - kann diverse Wecker-Automationen in FHEM abbilden.

  
***Meine Empfehlungen zur Modulauswahl:***  
*Bevor du dich in spezielle Module einarbeitest, solltest du wenigstens ein paar einfache at und notify erfolgreich konfiguriert haben. Scheue auch nicht davor zurück, die Perl-Syntax wenigstens in den Grundzügen zu erlernen! Ich habe auch zuerst einen großen Bogen um die direkte Verwendung dieser Programmiersprache gemacht, aber selbst einige Modulautoren beliebter Universal-Module empfehlen Perl-Code-Teile einzusetzen, wenn es um die Lösung komplexer Probleme geht. Es ist zwar so, dass praktisch alle Module irgendwie dazu dienen, dem User die meiste Programmierarbeit abzunehmen und den "lästigen Umweg" über Perl abzukürzen. Aber gerade was universelle Module zur Kombination von Zeit- und Ereignissteuerung angeht, habe ich im Ergebnis viel Zeit mit dem mehr oder weniger erfolglosen Versuch verbraucht, die Syntax eines dieser Module zu verstehen, nur um am Ende dann doch Perl zu lernen und die schlichte Eleganz von devspec, FILTER und regex zu erkennen.*  
  
*Als Anfang genügen ein paar `if (...) { } elsif (...) { } else {}` "Einzeiler", vielleicht verbunden mit einfachen eigenen myUtils-Funktionen, über die auf Reading- und/oder Attributwerte zugegriffen wird (ReadingsVal() und ReadingsNum()), das war es schon...*  
  
*Zur Erinnerung: die "DNA" aller Module ist aus "at" (in fhem.pl: `InternalTimer()`) und "notify" (in fhem.pl: `notifyfn()`) aufgebaut - funktioniert also irgendwas nicht, wie es soll, ist entweder deine Anweisung an das Modul nicht so, wie das das haben will, oder es liegt wirklich ein bug vor. Letzteres ist aber die Ausnahme, nicht die Regel... Du solltest also versuchen zu verstehen, wie diese beiden DNA-Bausteinchen in den Konfigurationsmöglichkeiten eines Moduls wiederzufinden sind, dann solltest du in der Lage sein, jedes Modul zu konfigurieren und kannst auch die "list"-Ausgaben zu den Devices besser verstehen.*  
