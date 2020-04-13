
# Einführung {.unnumbered}

## Willkommen zu dieser Einführung!{.unnumbered}  

Vielleicht interessiert dich vorab, wer hier schreibt und warum?  

Here you are:  

Hausautomatisierung und FHEM "mache" ich seit 2013. Damals war das "ganz einfach", mit FHEM zu beginnen: Alles wesentliche stand in einem Dokument namens "Heimautomatisierung mit FHEM", kurz "das pdf". Das druckte man sich aus, kaufte einen "CUL" und die für den jeweiligen Zweck passenden Geräte einer bestimmten Produktlinie eines einzigen Herstellers, installierte FHEM auf seiner FritzBox und hat dann mal angefangen, das ausgedruckte Dokument durchzuarbeiten und die Beispiele dort mehr oder weniger 1:1 zu kopieren.  
Für mich als Nicht-IT-Professional war das alles zunächst schwer zu verstehen, aber nach und nach ist meine Hausautomatisierung gewachsen, meine Kenntnisse ebenso, und heute darf ich als "Maintainer" sogar ein paar Teile zu dem Code beitragen, den du vielleicht demnächst nutzen willst. Wenn mir das jemand im Jahr 2016 geweissagt hätte, hätte ich ihn für verrückt erklärt! Aber so schnell ändern sich eben die Zeiten...  
Geändert hat sich noch einiges mehr: Das "*IoT*" für das *Internet of Things* steht, weiß heute fast jeder, und ein erheblicher Teil der heute verkauften "Gadgets" ist irgendwie vernetzt und nennt sich *"smart"*. Vor allem bei TV- und HiFi-Geräten (nennt man das noch so?) ist es Standard, dass man diese auch über das Handy fernsteuern kann, meist braucht man dazu "nur irgendeine App". Die Zahl der "Standards" ist  erheblich gewachsen, ebenso wie die Zahl der Hersteller und Handelsmarken. Woran es mangelt, ist eine sinnvolle Verbindung aller dieser Geräte miteinander und eine einheitliche Bedienung.  

Aber erst mal zurück in's Jahr 2013: Mein Ziel damals war eigentlich nur, elektrische Rollläden zu verbauen, ohne für jeden eine eigene Zeitschaltuhr kaufen zu müssen (und halbjährlich zwischen Sommer- und Winterzeit umzustellen usw.), und ein paar Lichtschalter an Stellen anzubringen, wo dummerweise kein Kabel lag, an das man einen Schalter hätte anschließen können. Dabei war es für mich am wichtigsten, folgende Fragen vorab zu klären:  


1. *"Kann ich das mit der Hausautomatisierung? Oder ist das für mich zu schwierig?!?"*  
2. *"Ist FHEM für mich die passende Lösung, oder soll ich lieber was Anderes nehmen?"*  

Ich hab's damals für mich entschieden, indem ich erst ausgiebig in "dem pdf" geblättert und gelesen habe. Danach hatte ich das noch unsichere Gefühl, dass das wohl irgendwie zu schaffen sein wird und habe dann einfach mal mit wenigen Geräten ausprobiert, wie das in der Praxis funktioniert.  
  
Die Welt ist aber nicht stehengeblieben und das betreffende pdf wurde zum meinem großen Bedauern seit 2014 nicht mehr aktualisiert.  

Mit diese Einführung ist nun der Versuch, dir zu helfen, diese beiden Fragen - jedenfalls zu einem gewissen Teil - für dich selbst auch im
Jahr 2020 beantworten zu können. Mir selbst hilft es sehr, wenn ich Dinge in einem größeren, systematischen Zusammenhang erklärt bekomme. Der Schwerpunkt liegt daher im Folgenden eher auf Grundzügen und der Verbindung zwischen den verschiedenen Teilen, damit du am Ende ein "Netz" hast, mit dem du "fischen gehen kannst", um ein Bild von Konfuzius zu zitieren:  
*"Gib einem Mann einen Fisch und du ernährst ihn für einen Tag. Lehre einen Mann zu fischen und du ernährst ihn für sein Leben."*  
(Zu Konfuzius' Zeiten waren die Männer für's Fischen zuständig – solltest du also kein Mann sein, nimm's nicht persönlich).  

Viele hier behandelte Aspekte sind eigentlich nicht FHEM-spezifisch, sondern gelten für jede Art der Hausautomatisierung. Deswegen war dann der zweite Teil der Frage 2 für mich von weniger entscheidender Bedeutung: letztlich wollte ich "nur" eine Lösung, die im Hintergrund bestimmte Probleme automatisch löst, ohne dass ich mehr als notwendig eingreifen muß. Es kann also durchaus sein, dass es andere Softwarelösungen gibt, die "moderner" aussehen wie die Standard-Webschnittstelle von FHEM und ebenfalls alle möglichen Dinge im Haus einheitlich bedienbar machen. Aber auch für eine schickere Web-Oberfläche bietet FHEM Alternativen und Schnittstellen...  

Wichtiger waren und sind mir andere Gesichtspunkte:  

- FHEM ist robust! Richtig eingerichtet, kann ein FHEM-Server problemlos mehrere Monate laufen, bis man eben "mal wieder ran muss", um z.B. das Betriebssystem zu aktualisieren.  
- FHEM ist leichtgewichtig. Es ist wenig anspruchsvoll, was die erforderlichen Ressourcen angeht.  
- FHEM läuft ohne Cloud, meine Daten bleiben im Haus!  
- FHEM ist open source.  
- Es gibt für fast jede Hardware irgendeine Möglichkeit, diese irgendwie in FHEM zu integrieren (oft genug nicht nur eine...), und es gibt eine klasse Community, die auf alle möglichen und unmöglichen Fragen mindestens eine Antwort kennt!  

Im Verlauf der Zeit habe ich einige Erfahrungen gesammelt, unter anderem auch zu den vielfältigen Möglichkeiten, ein bestimmtes Stück Hardware einzubinden oder ein Problemfeld zu lösen, wobei manche dieser Erfahrung durchaus unangenehm waren. Diese Einführung berücksichtigt daher in der Regel die meiner persönlichen Meinung nach jeweils einfachste Möglichkeit, etwas mit FHEM zu machen. Andere FHEM-User haben andere Erfahrungen gemacht oder empfinden vielleicht andere Lösungen als einfacher. Niemand weiß alles, daher mag die eine oder anderer Kritik an der sehr begrenzten Auswahl hier durchaus seine Berechtigung haben, das sei ausdrücklich betont!  
  
Aber wie sagte schon Konfuzius:  
*"Der Mensch hat dreierlei Wege, klug zu Handeln; erstens durch Nachdenken, das ist das Edelste, zweitens durch Nachahmen, das ist das Leichteste, und drittens durch Erfahrung, das ist das Bitterste."*  

Wenn du über einen Lösungsweg nachdenkst oder ihn nachahmen willst, berücksichtige daher möglichst das [KISS-Prinzip]! Das wird dir hoffentlich die langfristige Pflege deiner Automatisierungslösung erleichtern und manche bittere Erfahrung ersparen...  
  
Hoppla: Was meint langfristige Pflege?  
Dein Heim zum Teil des IoT zu machen, indem du FHEM oder eine andere Lösung oder bestimmte Hardwarekomponenten usw. wählst, ist jeweils eine Entscheidung mit Auswirkungen für Jahre oder sogar Jahrzehnte. FHEM und der Server, auf dem es läuft, bedarf wenigstens hin und wieder der laufenden Pflege und Absicherung, und je mehr Schnittstellen du von deinem Netz in das WWW hast, desto wichtiger ist diese Aufgabe. Und solltest du dein Heim irgendwann verkaufen wollen, ist die irgendwann getroffene Auswahl der Komponenten eventuell ein gewichtiges Argument für oder gegen dein Objekt!  
  
Nur wenn du auch bereit bist, die laufende Pflege deines Systems zu übernehmen, solltest du dich überhaupt für irgendeine Hausautomatisierungslösung entscheiden.  
  
In diesem Sinne eine erfolgreiche Einarbeitung, KISS und willkommen als neuer Beta-User!  
  
*Beta-User*  
  
PS: Wer bereits allgemein mit dem Thema Hausautomatisierung vertraut ist und/oder aktuelle Programmierkenntnisse hat, kann auch direkt mit dem
[Quick-Start] beginnen. Dieser bietet einen direkteren Einstieg in die FHEM-Spezifika. Diese Einführung hier ist vor allem für "normale" Menschen gedacht, die - wie ich selbst - keinen beruflichen IT-Hintergrund haben und daher vielleicht ähnliche Fragen haben wie ich damals...  
Beiden Leserkreisen sei ergänzend dazu die *commandref* in der "*modular*"-Variante ans Herz gelegt. Neben einer Übersicht, welche Module überhaupt offizieller Bestandteil von FHEM sind, erhält man mit dem Rahmendokument auch eine straffe Darstellung der in FHEM vorhandenen Kommandos, allgemeinen Attribute und ähnliche grundlegende
Informationen.   

Verbesserungsvorschläge nehme ich übrigens auch von "Professionals" gerne entgegen!  
  
## *Zum Verständnis dieses Dokuments*{.unnumbered}  

- Einige Stichworte und Überschriften tauchen mehrfach auf. In der Regel werden zunächst nur Grundzüge erläutert. Diese werden dann wieder aufgegriffen und vertieft, wenn dann auch die anderen erforderlichen Grundlagen genannt sind, die man braucht, um diese weiteren Details einordnen zu können.  
- Manchmal erschien es zweckmäßig, bereits früh auf weitere, vertiefende Stichworte hinzuweisen, welche aber zu weit führen würden und daher nicht mehr Bestandteil dieser Einführung sein werden. Diese als "Für später" gekennzeichneten Teile kannst du bei den ersten Durchgängen durch die Einführung getrost ignorieren und dann gerne später wieder aufgreifen, wenn du dich in die grundlegenden Dinge eingearbeitet hast und schon etwas sicherer bist. Sie dienen eher dem Wiederfinden der Stichworte und dem Versuch einer sinnvollen Einordnung in das Gesamtbild.  
- Ich habe die ersten Jahre mit FHEM "das pdf" immer mal wieder hervorgeholt und zumindest überflogen. Für mich war es wertvoll, weil ich immer wieder neue interessante Details entdeckt habe. Es wäre mir eine große Ehre, wenn andere Menschen das von dieser Einführung irgendwann auch mal schreiben würden. Da sie ebenfalls ständig zu aktualisieren sein wird, bedanke ich mich bereits jetzt im Namen der anderen künftigen Leser für deine Rückmeldung und eventuelle Vorschläge zur weiteren Verbesserung.  
- Ein Tipp noch zum Thema „klug handeln durch Nachahmen“: Vor allem, wenn du Lösungen aus dem Wiki oder dieser Einführung nachahmst, solltest du auch intensiv darüber nachdenken. Denn zum einen veraltet "leider" manche Anleitung schneller, als sie geschrieben wurde, z.B. weil es neueren, besseren Modul-Code gibt, eine firmware aktualisiert wurde oder fehleranfällige Hardware vom Hersteller durch bessere ersetzt wurde (tbc...), und zum anderen sind auch manche der im Wiki dargestellten Lösungen nicht intensiv auf Stringenz, Optimierung und Schreibfehler geprüft, sondern geben eben "nur" das Wissen wieder, das der Schreiber zum Zeitpunkt des Niederschreibens hatte und dankenswerterweise (!) z.B. ins Wiki übertragen hat.  
  
## *Outro*{.unnumbered}  

- Der Autor dieser Einleitung ist tatsächlich ein konkreter User. Der nachfolgende Text wurde jedoch zu großen Teilen auch von anderen Usern beigesteuert und verbessert, ebenso sind vielfache Anregungen betreffend Layout und Tools zum Erstellen des Dokuments an sich eingeflossen. Ein herzliches Dankeschön an dieser Stelle für Eure konstruktive Mitarbeit!  
-   Das Entwicklungsmodell von FHEM kann am ehesten als "Perpetual Beta" bezeichnet werden, die Software ist immer in der Entwicklung. Ein bestimmtes Release ist nur eine Art Schnappschuss zu einer bestimmten Zeit, über den bestenfalls einige Grundeinstellungen für einzelne Module ("defaults") anders gesetzt werden. Wer FHEM nutzt, hat daher nach meinem Verständnis eine "Beta-Version" im Einsatz, ist also ebenfalls "Beta-User". In der Open-Source-Welt ist allerdings typischerweise die Beta-Version die stabilste verfügbare Variante einer Software, weil die Entwickler an einem als "stable" bezeichneten Zweig in der Regel nur noch Bugfixes vornehmen. Diese bugfixes werden aber in der Regel zuerst über die aktuelle Entwicklerversion ausgetestet, der Fokus der Entwickler in der open-source-Welt liegt eindeutig auf der Verbesserung der jeweiligen Beta-Version...  
