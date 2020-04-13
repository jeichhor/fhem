
# Eigene Logiken (Teil I) – mehrere Geräte schalten und "Einzeiler"

## Vorbemerkungen

### Reihenfolgen beachten
- erst Interfaces sauber konfigurieren, dann Clients anlegen lassen
- erst Geräte fertig konfigurieren, dann Event-Handler bauen
  
### Schaltfunktionen konzipieren: direkt oder indirekt (Teil 1)
Allgemeine Vorüberlegungen
  
## Mehrere Geräte auf einmal schalten und visualisieren

### devspec

### FILTER

### Strukturierungen auf Modul-Basis

#### structure

#### Bewohner & Co (RESIDENTS)

#### LightScene

## Weitere Bedingungen auswerten - "if" & Co.

### Gerätezustände zur Entscheidungsfindung auswerten

#### Value, ReadingsVal, ReadingsNum, ReadingsAge, ReadingsTimestamp

#### Spezielle Variablen und Operatoren, FILTER, set magic

### Zeitfragen - Nur nachts, am Wochenende & Co.

#### $we und IsWe()

#### Schalten an bestimmten Wochentagen

#### Verschachteltes at

#### Bedingungen über Attribute: disabledForIntervals, disableAfterTrigger & Co.

#### Tag und Nacht: Sunset, Sunrise und isday

#### Ferien und Urlaub: holiday, holiday2we

#### Calendar

## trigger und Makros

## Schau ins log!

## Eigene Daten in FHEM verfügbar machen

### userAttr, setreading, Dummy und getKeyValue

### deletereading

### setKeyValue

### %data
(https://wiki.fhem.de/wiki/DevelopmentModuleIntro#Wichtige_globale_Variablen_aus_fhem.pl)
