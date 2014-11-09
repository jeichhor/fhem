package Geo::IP::Record;

use Geo::IP;    #

use vars qw/$pp/;


  use strict;

# here are the missing functions if the C API is used
  sub latitude {
    my $gir = shift;
    return sprintf( "%.4f", $gir->_latitude );
  }

  sub longitude {
    my $gir = shift;
    return sprintf( "%.4f", $gir->_longitude );
  }

BEGIN {
 $pp = !defined(&Geo::IP::Record::city)
  || $Geo::IP::GEOIP_PP_ONLY;
}

eval <<'__PP__' if $pp;

for ( qw: country_code    country_code3  country_name
          region          region_name    city
          postal_code     dma_code       area_code 
          continent_code  metro_code                      : ) {

  no strict   qw/ refs /;
  no warnings qw/ redefine /;
  my $m = $_; # looks bogus, but it is not! it is a copy not a alias
  *$_ = sub { $_[0]->{$m} };
}

# for the case warnings are globaly enabled with perl -w and the CAPI is absent
no warnings qw/ redefine /;

sub longitude {sprintf('%.4f', $_[0]->{longitude})}
sub latitude  {sprintf('%.4f', $_[0]->{latitude})}

{
  my $TIME_ZONE;

  local $_ = <DATA>;    # skip first line
  while (<DATA>) {
    chomp;
    next if /^\s*$/;
    my ( $country, $region, $timezone ) = split /\t/;
    $TIME_ZONE->{$country}->{ $region || '' } = $timezone;
  }

  # called from Geo::IP
  sub _time_zone {
    my ( undef, $country, $region  ) = @_;
    return undef unless $country;
    return undef unless defined $TIME_ZONE->{$country};
    $region ||= '';
    return
      defined $TIME_ZONE->{$country}->{$region}
      ? $TIME_ZONE->{$country}->{$region}
      : $TIME_ZONE->{$country}->{''};
  }
  sub time_zone {
    my ( $self ) = @_;
    my ( $country, $region ) = ( $self->country_code, $self->region );
    return $self->_time_zone( $country, $region );
  }
}

__PP__
1;
__DATA__
country	region	timezone
US	AL	America/Chicago
US	AK	America/Anchorage
US	AZ	America/Phoenix
US	AR	America/Chicago
US	CA	America/Los_Angeles
US	CO	America/Denver
US	CT	America/New_York
US	DE	America/New_York
US	DC	America/New_York
US	FL	America/New_York
US	GA	America/New_York
US	HI	Pacific/Honolulu
US	ID	America/Denver
US	IL	America/Chicago
US	IN	America/Indianapolis
US	IA	America/Chicago
US	KS	America/Chicago
US	KY	America/New_York
US	LA	America/Chicago
US	ME	America/New_York
US	MD	America/New_York
US	MA	America/New_York
US	MI	America/New_York
US	MN	America/Chicago
US	MS	America/Chicago
US	MO	America/Chicago
US	MT	America/Denver
US	NE	America/Chicago
US	NV	America/Los_Angeles
US	NH	America/New_York
US	NJ	America/New_York
US	NM	America/Denver
US	NY	America/New_York
US	NC	America/New_York
US	ND	America/Chicago
US	OH	America/New_York
US	OK	America/Chicago
US	OR	America/Los_Angeles
US	PA	America/New_York
US	RI	America/New_York
US	SC	America/New_York
US	SD	America/Chicago
US	TN	America/Chicago
US	TX	America/Chicago
US	UT	America/Denver
US	VT	America/New_York
US	VA	America/New_York
US	WA	America/Los_Angeles
US	WV	America/New_York
US	WI	America/Chicago
US	WY	America/Denver
CA	AB	America/Edmonton
CA	BC	America/Vancouver
CA	MB	America/Winnipeg
CA	NB	America/Halifax
CA	NL	America/St_Johns
CA	NT	America/Yellowknife
CA	NS	America/Halifax
CA	NU	America/Rankin_Inlet
CA	ON	America/Rainy_River
CA	PE	America/Halifax
CA	QC	America/Montreal
CA	SK	America/Regina
CA	YT	America/Whitehorse
AU	01	Australia/Canberra
AU	02	Australia/NSW
AU	03	Australia/North
AU	04	Australia/Queensland
AU	05	Australia/South
AU	06	Australia/Tasmania
AU	07	Australia/Victoria
AU	08	Australia/West
AS		US/Samoa
CI		Africa/Abidjan
GH		Africa/Accra
DZ		Africa/Algiers
ER		Africa/Asmera
ML		Africa/Bamako
CF		Africa/Bangui
GM		Africa/Banjul
GW		Africa/Bissau
CG		Africa/Brazzaville
BI		Africa/Bujumbura
EG		Africa/Cairo
MA		Africa/Casablanca
GN		Africa/Conakry
SN		Africa/Dakar
DJ		Africa/Djibouti
SL		Africa/Freetown
BW		Africa/Gaborone
ZW		Africa/Harare
ZA		Africa/Johannesburg
UG		Africa/Kampala
SD		Africa/Khartoum
RW		Africa/Kigali
NG		Africa/Lagos
GA		Africa/Libreville
TG		Africa/Lome
AO		Africa/Luanda
ZM		Africa/Lusaka
GQ		Africa/Malabo
MZ		Africa/Maputo
LS		Africa/Maseru
SZ		Africa/Mbabane
SO		Africa/Mogadishu
LR		Africa/Monrovia
KE		Africa/Nairobi
TD		Africa/Ndjamena
NE		Africa/Niamey
MR		Africa/Nouakchott
BF		Africa/Ouagadougou
ST		Africa/Sao_Tome
LY		Africa/Tripoli
TN		Africa/Tunis
AI		America/Anguilla
AG		America/Antigua
AW		America/Aruba
BB		America/Barbados
BZ		America/Belize
CO		America/Bogota
VE		America/Caracas
KY		America/Cayman
CR		America/Costa_Rica
DM		America/Dominica
SV		America/El_Salvador
GD		America/Grenada
FR		Europe/Paris
GP		America/Guadeloupe
GT		America/Guatemala
GY		America/Guyana
CU		America/Havana
JM		America/Jamaica
BO		America/La_Paz
PE		America/Lima
NI		America/Managua
MQ		America/Martinique
UY		America/Montevideo
MS		America/Montserrat
BS		America/Nassau
PA		America/Panama
SR		America/Paramaribo
PR		America/Puerto_Rico
KN		America/St_Kitts
LC		America/St_Lucia
VC		America/St_Vincent
HN		America/Tegucigalpa
YE		Asia/Aden
JO		Asia/Amman
TM		Asia/Ashgabat
IQ		Asia/Baghdad
BH		Asia/Bahrain
AZ		Asia/Baku
TH		Asia/Bangkok
LB		Asia/Beirut
KG		Asia/Bishkek
BN		Asia/Brunei
IN		Asia/Calcutta
MN		Asia/Choibalsan
LK		Asia/Colombo
BD		Asia/Dhaka
AE		Asia/Dubai
TJ		Asia/Dushanbe
HK		Asia/Hong_Kong
TR		Asia/Istanbul
IL		Asia/Jerusalem
AF		Asia/Kabul
PK		Asia/Karachi
NP		Asia/Katmandu
KW		Asia/Kuwait
MO		Asia/Macao
PH		Asia/Manila
OM		Asia/Muscat
CY		Asia/Nicosia
KP		Asia/Pyongyang
QA		Asia/Qatar
MM		Asia/Rangoon
SA		Asia/Riyadh
KR		Asia/Seoul
SG		Asia/Singapore
TW		Asia/Taipei
GE		Asia/Tbilisi
BT		Asia/Thimphu
JP		Asia/Tokyo
LA		Asia/Vientiane
AM		Asia/Yerevan
BM		Atlantic/Bermuda
CV		Atlantic/Cape_Verde
FO		Atlantic/Faeroe
IS		Atlantic/Reykjavik
GS		Atlantic/South_Georgia
SH		Atlantic/St_Helena
CL		Chile/Continental
NL		Europe/Amsterdam
AD		Europe/Andorra
GR		Europe/Athens
YU		Europe/Belgrade
DE		Europe/Berlin
SK		Europe/Bratislava
BE		Europe/Brussels
RO		Europe/Bucharest
HU		Europe/Budapest
DK		Europe/Copenhagen
IE		Europe/Dublin
GI		Europe/Gibraltar
FI		Europe/Helsinki
SI		Europe/Ljubljana
GB		Europe/London
LU		Europe/Luxembourg
MT		Europe/Malta
BY		Europe/Minsk
MC		Europe/Monaco
NO		Europe/Oslo
CZ		Europe/Prague
LV		Europe/Riga
IT		Europe/Rome
SM		Europe/San_Marino
BA		Europe/Sarajevo
MK		Europe/Skopje
BG		Europe/Sofia
SE		Europe/Stockholm
EE		Europe/Tallinn
AL		Europe/Tirane
LI		Europe/Vaduz
VA		Europe/Vatican
AT		Europe/Vienna
LT		Europe/Vilnius
PL		Europe/Warsaw
HR		Europe/Zagreb
IR		Asia/Tehran
MG		Indian/Antananarivo
CX		Indian/Christmas
CC		Indian/Cocos
KM		Indian/Comoro
MV		Indian/Maldives
MU		Indian/Mauritius
YT		Indian/Mayotte
RE		Indian/Reunion
FJ		Pacific/Fiji
TV		Pacific/Funafuti
GU		Pacific/Guam
NR		Pacific/Nauru
NU		Pacific/Niue
NF		Pacific/Norfolk
PW		Pacific/Palau
PN		Pacific/Pitcairn
CK		Pacific/Rarotonga
WS		Pacific/Samoa
KI		Pacific/Tarawa
TO		Pacific/Tongatapu
WF		Pacific/Wallis
TZ		Africa/Dar_es_Salaam
VN		Asia/Phnom_Penh
KH		Asia/Phnom_Penh
CM		Africa/Lagos
DO		America/Santo_Domingo
ET		Africa/Addis_Ababa
FX		Europe/Paris
HT		America/Port-au-Prince
CH		Europe/Zurich
AN		America/Curacao
BJ		Africa/Porto-Novo
EH		Africa/El_Aaiun
FK		Atlantic/Stanley
GF		America/Cayenne
IO		Indian/Chagos
MD		Europe/Chisinau
MP		Pacific/Saipan
MW		Africa/Blantyre
NA		Africa/Windhoek
NC		Pacific/Noumea
PG		Pacific/Port_Moresby
PM		America/Miquelon
PS		Asia/Gaza
PY		America/Asuncion
SB		Pacific/Guadalcanal
SC		Indian/Mahe
SJ		Arctic/Longyearbyen
SY		Asia/Damascus
TC		America/Grand_Turk
TF		Indian/Kerguelen
TK		Pacific/Fakaofo
TT		America/Port_of_Spain
VG		America/Tortola
VI		America/St_Thomas
VU		Pacific/Efate
RS		Europe/Belgrade
ME		Europe/Podgorica
AX		Europe/Mariehamn
GG		Europe/Guernsey
IM		Europe/Isle_of_Man
JE		Europe/Jersey
BL		America/St_Barthelemy
MF		America/Marigot
AR	01	America/Argentina/Buenos_Aires
AR	02	America/Argentina/Catamarca
AR	03	America/Argentina/Tucuman
AR	04	America/Argentina/Rio_Gallegos
AR	05	America/Argentina/Cordoba
AR	06	America/Argentina/Tucuman
AR	07	America/Argentina/Buenos_Aires
AR	08	America/Argentina/Buenos_Aires
AR	09	America/Argentina/Tucuman
AR	10	America/Argentina/Jujuy
AR	11	America/Argentina/San_Luis
AR	12	America/Argentina/La_Rioja
AR	13	America/Argentina/Mendoza
AR	14	America/Argentina/Buenos_Aires
AR	15	America/Argentina/San_Luis
AR	16	America/Argentina/Buenos_Aires
AR	17	America/Argentina/Salta
AR	18	America/Argentina/San_Juan
AR	19	America/Argentina/San_Luis
AR	20	America/Argentina/Rio_Gallegos
AR	21	America/Argentina/Buenos_Aires
AR	22	America/Argentina/Catamarca
AR	23	America/Argentina/Ushuaia
AR	24	America/Argentina/Tucuman
BR	01	America/Rio_Branco
BR	02	America/Maceio
BR	03	America/Sao_Paulo
BR	04	America/Manaus
BR	05	America/Bahia
BR	06	America/Fortaleza
BR	07	America/Sao_Paulo
BR	08	America/Sao_Paulo
BR	11	America/Campo_Grande
BR	13	America/Belem
BR	14	America/Cuiaba
BR	15	America/Sao_Paulo
BR	16	America/Belem
BR	17	America/Recife
BR	18	America/Sao_Paulo
BR	20	America/Fortaleza
BR	21	America/Sao_Paulo
BR	22	America/Recife
BR	23	America/Sao_Paulo
BR	24	America/Porto_Velho
BR	25	America/Boa_Vista
BR	26	America/Sao_Paulo
BR	27	America/Sao_Paulo
BR	28	America/Maceio
BR	29	America/Sao_Paulo
BR	30	America/Recife
BR	31	America/Araguaina
CD	02	Africa/Kinshasa
CD	05	Africa/Lubumbashi
CD	06	Africa/Kinshasa
CD	08	Africa/Kinshasa
CD	10	Africa/Lubumbashi
CD	11	Africa/Lubumbashi
CD	12	Africa/Lubumbashi
CN	01	Asia/Shanghai
CN	02	Asia/Shanghai
CN	03	Asia/Shanghai
CN	04	Asia/Shanghai
CN	05	Asia/Harbin
CN	06	Asia/Chongqing
CN	07	Asia/Shanghai
CN	08	Asia/Harbin
CN	09	Asia/Shanghai
CN	10	Asia/Shanghai
CN	11	Asia/Chongqing
CN	12	Asia/Shanghai
CN	13	Asia/Urumqi
CN	14	Asia/Chongqing
CN	15	Asia/Chongqing
CN	16	Asia/Chongqing
CN	18	Asia/Chongqing
CN	19	Asia/Harbin
CN	20	Asia/Harbin
CN	21	Asia/Chongqing
CN	22	Asia/Harbin
CN	23	Asia/Shanghai
CN	24	Asia/Chongqing
CN	25	Asia/Shanghai
CN	26	Asia/Chongqing
CN	28	Asia/Shanghai
CN	29	Asia/Chongqing
CN	30	Asia/Chongqing
CN	31	Asia/Chongqing
CN	32	Asia/Chongqing
CN	33	Asia/Chongqing
EC	01	Pacific/Galapagos
EC	02	America/Guayaquil
EC	03	America/Guayaquil
EC	04	America/Guayaquil
EC	05	America/Guayaquil
EC	06	America/Guayaquil
EC	07	America/Guayaquil
EC	08	America/Guayaquil
EC	09	America/Guayaquil
EC	10	America/Guayaquil
EC	11	America/Guayaquil
EC	12	America/Guayaquil
EC	13	America/Guayaquil
EC	14	America/Guayaquil
EC	15	America/Guayaquil
EC	17	America/Guayaquil
EC	18	America/Guayaquil
EC	19	America/Guayaquil
EC	20	America/Guayaquil
EC	22	America/Guayaquil
ES	07	Europe/Madrid
ES	27	Europe/Madrid
ES	29	Europe/Madrid
ES	31	Europe/Madrid
ES	32	Europe/Madrid
ES	34	Europe/Madrid
ES	39	Europe/Madrid
ES	51	Africa/Ceuta
ES	52	Europe/Madrid
ES	53	Atlantic/Canary
ES	54	Europe/Madrid
ES	55	Europe/Madrid
ES	56	Europe/Madrid
ES	57	Europe/Madrid
ES	58	Europe/Madrid
ES	59	Europe/Madrid
ES	60	Europe/Madrid
GL	01	America/Thule
GL	02	America/Godthab
GL	03	America/Godthab
ID	01	Asia/Pontianak
ID	02	Asia/Makassar
ID	03	Asia/Jakarta
ID	04	Asia/Jakarta
ID	05	Asia/Jakarta
ID	06	Asia/Jakarta
ID	07	Asia/Jakarta
ID	08	Asia/Jakarta
ID	09	Asia/Jayapura
ID	10	Asia/Jakarta
ID	11	Asia/Pontianak
ID	12	Asia/Makassar
ID	13	Asia/Makassar
ID	14	Asia/Makassar
ID	15	Asia/Jakarta
ID	16	Asia/Makassar
ID	17	Asia/Makassar
ID	18	Asia/Makassar
ID	19	Asia/Pontianak
ID	20	Asia/Makassar
ID	21	Asia/Makassar
ID	22	Asia/Makassar
ID	23	Asia/Makassar
ID	24	Asia/Jakarta
ID	25	Asia/Pontianak
ID	26	Asia/Pontianak
ID	30	Asia/Jakarta
ID	31	Asia/Makassar
ID	33	Asia/Jakarta
KZ	01	Asia/Almaty
KZ	02	Asia/Almaty
KZ	03	Asia/Qyzylorda
KZ	04	Asia/Aqtobe
KZ	05	Asia/Qyzylorda
KZ	06	Asia/Aqtau
KZ	07	Asia/Oral
KZ	08	Asia/Qyzylorda
KZ	09	Asia/Aqtau
KZ	10	Asia/Qyzylorda
KZ	11	Asia/Almaty
KZ	12	Asia/Qyzylorda
KZ	13	Asia/Aqtobe
KZ	14	Asia/Qyzylorda
KZ	15	Asia/Almaty
KZ	16	Asia/Aqtobe
KZ	17	Asia/Almaty
MX	01	America/Mexico_City
MX	02	America/Tijuana
MX	03	America/Hermosillo
MX	04	America/Merida
MX	05	America/Mexico_City
MX	06	America/Chihuahua
MX	07	America/Monterrey
MX	08	America/Mexico_City
MX	09	America/Mexico_City
MX	10	America/Mazatlan
MX	11	America/Mexico_City
MX	12	America/Mexico_City
MX	13	America/Mexico_City
MX	14	America/Mazatlan
MX	15	America/Chihuahua
MX	16	America/Mexico_City
MX	17	America/Mexico_City
MX	18	America/Mazatlan
MX	19	America/Monterrey
MX	20	America/Mexico_City
MX	21	America/Mexico_City
MX	22	America/Mexico_City
MX	23	America/Cancun
MX	24	America/Mexico_City
MX	25	America/Mazatlan
MX	26	America/Hermosillo
MX	27	America/Merida
MX	28	America/Monterrey
MX	29	America/Mexico_City
MX	30	America/Mexico_City
MX	31	America/Merida
MX	32	America/Monterrey
MY	01	Asia/Kuala_Lumpur
MY	02	Asia/Kuala_Lumpur
MY	03	Asia/Kuala_Lumpur
MY	04	Asia/Kuala_Lumpur
MY	05	Asia/Kuala_Lumpur
MY	06	Asia/Kuala_Lumpur
MY	07	Asia/Kuala_Lumpur
MY	08	Asia/Kuala_Lumpur
MY	09	Asia/Kuala_Lumpur
MY	11	Asia/Kuching
MY	12	Asia/Kuala_Lumpur
MY	13	Asia/Kuala_Lumpur
MY	14	Asia/Kuala_Lumpur
MY	15	Asia/Kuching
MY	16	Asia/Kuching
NZ	85	Pacific/Auckland
NZ	E7	Pacific/Auckland
NZ	E8	Pacific/Auckland
NZ	E9	Pacific/Auckland
NZ	F1	Pacific/Auckland
NZ	F2	Pacific/Auckland
NZ	F3	Pacific/Auckland
NZ	F4	Pacific/Auckland
NZ	F5	Pacific/Auckland
NZ	F7	Pacific/Chatham
NZ	F8	Pacific/Auckland
NZ	F9	Pacific/Auckland
NZ	G1	Pacific/Auckland
NZ	G2	Pacific/Auckland
NZ	G3	Pacific/Auckland
PT	02	Europe/Lisbon
PT	03	Europe/Lisbon
PT	04	Europe/Lisbon
PT	05	Europe/Lisbon
PT	06	Europe/Lisbon
PT	07	Europe/Lisbon
PT	08	Europe/Lisbon
PT	09	Europe/Lisbon
PT	10	Atlantic/Madeira
PT	11	Europe/Lisbon
PT	13	Europe/Lisbon
PT	14	Europe/Lisbon
PT	16	Europe/Lisbon
PT	17	Europe/Lisbon
PT	18	Europe/Lisbon
PT	19	Europe/Lisbon
PT	20	Europe/Lisbon
PT	21	Europe/Lisbon
PT	22	Europe/Lisbon
RU	01	Europe/Volgograd
RU	02	Asia/Irkutsk
RU	03	Asia/Novokuznetsk
RU	04	Asia/Novosibirsk
RU	05	Asia/Vladivostok
RU	06	Europe/Moscow
RU	07	Europe/Volgograd
RU	08	Europe/Samara
RU	09	Europe/Moscow
RU	10	Europe/Moscow
RU	11	Asia/Irkutsk
RU	13	Asia/Yekaterinburg
RU	14	Asia/Irkutsk
RU	15	Asia/Anadyr
RU	16	Europe/Samara
RU	17	Europe/Volgograd
RU	18	Asia/Krasnoyarsk
RU	20	Asia/Irkutsk
RU	21	Europe/Moscow
RU	22	Europe/Volgograd
RU	23	Europe/Kaliningrad
RU	24	Europe/Volgograd
RU	25	Europe/Moscow
RU	26	Asia/Kamchatka
RU	27	Europe/Volgograd
RU	28	Europe/Moscow
RU	29	Asia/Novokuznetsk
RU	30	Asia/Vladivostok
RU	31	Asia/Krasnoyarsk
RU	32	Asia/Omsk
RU	33	Asia/Yekaterinburg
RU	34	Asia/Yekaterinburg
RU	35	Asia/Yekaterinburg
RU	36	Asia/Anadyr
RU	37	Europe/Moscow
RU	38	Europe/Volgograd
RU	39	Asia/Krasnoyarsk
RU	40	Asia/Yekaterinburg
RU	41	Europe/Moscow
RU	42	Europe/Moscow
RU	43	Europe/Moscow
RU	44	Asia/Magadan
RU	45	Europe/Samara
RU	46	Europe/Samara
RU	47	Europe/Moscow
RU	48	Europe/Moscow
RU	49	Europe/Moscow
RU	50	Asia/Yekaterinburg
RU	51	Europe/Moscow
RU	52	Europe/Moscow
RU	53	Asia/Novosibirsk
RU	54	Asia/Omsk
RU	55	Europe/Samara
RU	56	Europe/Moscow
RU	57	Europe/Samara
RU	58	Asia/Yekaterinburg
RU	59	Asia/Vladivostok
RU	60	Europe/Kaliningrad
RU	61	Europe/Volgograd
RU	62	Europe/Moscow
RU	63	Asia/Yakutsk
RU	64	Asia/Sakhalin
RU	65	Europe/Samara
RU	66	Europe/Moscow
RU	67	Europe/Samara
RU	68	Europe/Volgograd
RU	69	Europe/Moscow
RU	70	Europe/Volgograd
RU	71	Asia/Yekaterinburg
RU	72	Europe/Moscow
RU	73	Europe/Samara
RU	74	Asia/Krasnoyarsk
RU	75	Asia/Novosibirsk
RU	76	Europe/Moscow
RU	77	Europe/Moscow
RU	78	Asia/Yekaterinburg
RU	79	Asia/Irkutsk
RU	80	Asia/Yekaterinburg
RU	81	Europe/Samara
RU	82	Asia/Irkutsk
RU	83	Europe/Moscow
RU	84	Europe/Volgograd
RU	85	Europe/Moscow
RU	86	Europe/Moscow
RU	87	Asia/Novosibirsk
RU	88	Europe/Moscow
RU	89	Asia/Vladivostok
UA	01	Europe/Kiev
UA	02	Europe/Kiev
UA	03	Europe/Uzhgorod
UA	04	Europe/Zaporozhye
UA	05	Europe/Zaporozhye
UA	06	Europe/Uzhgorod
UA	07	Europe/Zaporozhye
UA	08	Europe/Simferopol
UA	09	Europe/Kiev
UA	10	Europe/Zaporozhye
UA	11	Europe/Simferopol
UA	13	Europe/Kiev
UA	14	Europe/Zaporozhye
UA	15	Europe/Uzhgorod
UA	16	Europe/Zaporozhye
UA	17	Europe/Simferopol
UA	18	Europe/Zaporozhye
UA	19	Europe/Kiev
UA	20	Europe/Simferopol
UA	21	Europe/Kiev
UA	22	Europe/Uzhgorod
UA	23	Europe/Kiev
UA	24	Europe/Uzhgorod
UA	25	Europe/Uzhgorod
UA	26	Europe/Zaporozhye
UA	27	Europe/Kiev
UZ	01	Asia/Tashkent
UZ	02	Asia/Samarkand
UZ	03	Asia/Tashkent
UZ	06	Asia/Tashkent
UZ	07	Asia/Samarkand
UZ	08	Asia/Samarkand
UZ	09	Asia/Samarkand
UZ	10	Asia/Samarkand
UZ	12	Asia/Samarkand
UZ	13	Asia/Tashkent
UZ	14	Asia/Tashkent
TL		Asia/Dili
PF		Pacific/Marquesas
