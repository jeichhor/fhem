package Geo::IP;

use strict;
use base qw(Exporter);
use vars qw($VERSION @EXPORT  $GEOIP_PP_ONLY @ISA $XS_VERSION);

BEGIN { $GEOIP_PP_ONLY = 0 unless defined($GEOIP_PP_ONLY); }

BEGIN {
  $VERSION = '1.40';
  eval {

    # PERL_DL_NONLAZY must be false, or any errors in loading will just
    # cause the perl code to be tested
    local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};

    require DynaLoader;
    local @ISA = qw(DynaLoader);
    bootstrap Geo::IP $VERSION;
  } unless $GEOIP_PP_ONLY;
}

require Geo::IP::Record;

sub GEOIP_STANDARD()     { 0; }    # PP
sub GEOIP_MEMORY_CACHE() { 1; }    # PP
sub GEOIP_CHECK_CACHE()  { 2; }
sub GEOIP_INDEX_CACHE()  { 4; }
sub GEOIP_MMAP_CACHE()   { 8; }    # PP

sub GEOIP_UNKNOWN_SPEED()   { 0; } #PP
sub GEOIP_DIALUP_SPEED()    { 1; } #PP
sub GEOIP_CABLEDSL_SPEED()  { 2; } #PP
sub GEOIP_CORPORATE_SPEED() { 3; } #PP

BEGIN {

  #my $pp = !( defined &_XScompiled && &_XScompiled && !$TESTING_PERL_ONLY );
  my $pp = !defined &open;

  sub GEOIP_COUNTRY_EDITION()        { 1; }
  sub GEOIP_CITY_EDITION_REV1()      { 2; }
  sub GEOIP_REGION_EDITION_REV1()    { 3; }
  sub GEOIP_ISP_EDITION()            { 4; }
  sub GEOIP_ORG_EDITION()            { 5; }
  sub GEOIP_CITY_EDITION_REV0()      { 6; }
  sub GEOIP_REGION_EDITION_REV0()    { 7; }
  sub GEOIP_PROXY_EDITION()          { 8; }
  sub GEOIP_ASNUM_EDITION()          { 9; }
  sub GEOIP_NETSPEED_EDITION()       { 10; }
  sub GEOIP_DOMAIN_EDITION()         { 11; }
  sub GEOIP_COUNTRY_EDITION_V6()     { 12; }
  sub GEOIP_LOCATIONA_EDITION()      { 13; }
  sub GEOIP_ACCURACYRADIUS_EDITION() { 14; }
  sub GEOIP_CITYCONFIDENCE_EDITION() { 15; }
  sub GEOIP_NETSPEED_EDITION_REV1() {32;}

  sub GEOIP_CHARSET_ISO_8859_1() { 0; }
  sub GEOIP_CHARSET_UTF8()       { 1; }

  #
  sub api {
    defined &Geo::IP::Record::_XScompiled ? 'CAPI' : 'PurePerl';
  }

  # cheat --- try to load Sys::Mmap PurePerl only
  if ($pp) {
    eval {

      # wrap into eval again, as workaround for centos / mod_perl issue
      # seems they use $@ without eval somewhere
      eval "require Sys::Mmap"
        ? Sys::Mmap->import
        : do {
        for (qw/ PROT_READ MAP_PRIVATE MAP_SHARED /) {
          no strict 'refs';
          my $unused_stub = $_;    # we must use a copy
          *$unused_stub = sub { die 'Sys::Mmap required for mmap support' };
        }    # for
        };    # do
      1;
    };    # eval
  }    # pp
  else {
    eval << '__CAPI_GLUE__';
  # threads should not clone or DESTROY the GeoIP object.
  sub CLONE_SKIP {1}

  *name_by_name = *isp_by_name = *org_by_name;
  *name_by_addr = *isp_by_addr = *org_by_addr;

  *org_by_name_v6 = *name_by_name_v6;
  *org_by_addr_v6 = *name_by_addr_v6;
__CAPI_GLUE__
  }
}

eval << '__PP_CODE__' unless defined &open;

use strict;
use FileHandle;
use File::Spec;

require bytes;

BEGIN {
  if ( $] >= 5.008 ) {
    require Encode;
	Encode->import(qw/ decode /);
  }
  else {
    *decode = sub {
      local $_ = $_[1];
      use bytes;
       s/([\x80-\xff])/my $c = ord($1);
	       my $p = $c >= 192 ? 1 : 0; 
	       pack ( 'CC' => 0xc2 + $p , $c & ~0x40 ); /ge;
	   return $_;
    };
  }
};

use vars qw/$PP_OPEN_TYPE_PATH/;

use constant FULL_RECORD_LENGTH        => 50;
use constant GEOIP_COUNTRY_BEGIN       => 16776960;
use constant RECORD_LENGTH             => 3;
use constant GEOIP_STATE_BEGIN_REV0    => 16700000;
use constant GEOIP_STATE_BEGIN_REV1    => 16000000;
use constant STRUCTURE_INFO_MAX_SIZE   => 20;
use constant DATABASE_INFO_MAX_SIZE    => 100;

use constant SEGMENT_RECORD_LENGTH     => 3;
use constant STANDARD_RECORD_LENGTH    => 3;
use constant ORG_RECORD_LENGTH         => 4;
use constant MAX_RECORD_LENGTH         => 4;
use constant MAX_ORG_RECORD_LENGTH     => 300;
use constant US_OFFSET                 => 1;
use constant CANADA_OFFSET             => 677;
use constant WORLD_OFFSET              => 1353;
use constant FIPS_RANGE                => 360;

my @continents = qw/
--
AS EU EU AS AS NA NA EU AS NA 
AF AN SA OC EU OC NA AS EU NA 
AS EU AF EU AS AF AF NA AS SA 
SA NA AS AN AF EU NA NA AS AF 
AF AF EU AF OC SA AF AS SA NA 
NA AF AS AS EU EU AF EU NA NA 
AF SA EU AF AF AF EU AF EU OC 
SA OC EU EU EU AF EU NA AS SA 
AF EU NA AF AF NA AF EU AN NA 
OC AF SA AS AN NA EU NA EU AS 
EU AS AS AS AS AS EU EU NA AS 
AS AF AS AS OC AF NA AS AS AS 
NA AS AS AS NA EU AS AF AF EU 
EU EU AF AF EU EU AF OC EU AF 
AS AS AS OC NA AF NA EU AF AS 
AF NA AS AF AF OC AF OC AF NA 
EU EU AS OC OC OC AS NA SA OC 
OC AS AS EU NA OC NA AS EU OC 
SA AS AF EU EU AF AS OC AF AF 
EU AS AF EU EU EU AF EU AF AF 
SA AF NA AS AF NA AF AN AF AS 
AS OC AS AF OC AS EU NA OC AS 
AF EU AF OC NA SA AS EU NA SA 
NA NA AS OC OC OC AS AF EU AF 
AF EU AF -- -- -- EU EU EU EU 
NA NA 
/;

my @countries = (
  undef, qw/
 AP EU AD AE AF AG AI 
 AL AM AN AO AQ AR AS AT 
 AU AW AZ BA BB BD BE BF 
 BG BH BI BJ BM BN BO BR 
 BS BT BV BW BY BZ CA CC 
 CD CF CG CH CI CK CL CM 
 CN CO CR CU CV CX CY CZ 
 DE DJ DK DM DO DZ EC EE 
 EG EH ER ES ET FI FJ FK 
 FM FO FR FX GA GB GD GE 
 GF GH GI GL GM GN GP GQ 
 GR GS GT GU GW GY HK HM 
 HN HR HT HU ID IE IL IN 
 IO IQ IR IS IT JM JO JP 
 KE KG KH KI KM KN KP KR 
 KW KY KZ LA LB LC LI LK 
 LR LS LT LU LV LY MA MC 
 MD MG MH MK ML MM MN MO 
 MP MQ MR MS MT MU MV MW 
 MX MY MZ NA NC NE NF NG 
 NI NL NO NP NR NU NZ OM 
 PA PE PF PG PH PK PL PM 
 PN PR PS PT PW PY QA RE 
 RO RU RW SA SB SC SD SE 
 SG SH SI SJ SK SL SM SN 
 SO SR ST SV SY SZ TC TD 
 TF TG TH TJ TK TM TN TO 
 TL TR TT TV TW TZ UA UG 
 UM US UY UZ VA VC VE VG 
 VI VN VU WF WS YE YT RS 
 ZA ZM ME ZW A1 A2 O1 AX 
 GG IM JE BL MF/
);


my %_id_by_code;
for ( 1 .. $#countries ) {
  $_id_by_code{ $countries[$_] } = $_;
}

my @code3s = ( undef, qw/
                   AP  EU  AND ARE AFG ATG AIA
               ALB ARM ANT AGO ATA ARG ASM AUT
               AUS ABW AZE BIH BRB BGD BEL BFA
               BGR BHR BDI BEN BMU BRN BOL BRA
               BHS BTN BVT BWA BLR BLZ CAN CCK
               COD CAF COG CHE CIV COK CHL CMR
               CHN COL CRI CUB CPV CXR CYP CZE
               DEU DJI DNK DMA DOM DZA ECU EST
               EGY ESH ERI ESP ETH FIN FJI FLK
               FSM FRO FRA FX  GAB GBR GRD GEO
               GUF GHA GIB GRL GMB GIN GLP GNQ
               GRC SGS GTM GUM GNB GUY HKG HMD
               HND HRV HTI HUN IDN IRL ISR IND
               IOT IRQ IRN ISL ITA JAM JOR JPN
               KEN KGZ KHM KIR COM KNA PRK KOR
               KWT CYM KAZ LAO LBN LCA LIE LKA
               LBR LSO LTU LUX LVA LBY MAR MCO
               MDA MDG MHL MKD MLI MMR MNG MAC
               MNP MTQ MRT MSR MLT MUS MDV MWI
               MEX MYS MOZ NAM NCL NER NFK NGA
               NIC NLD NOR NPL NRU NIU NZL OMN
               PAN PER PYF PNG PHL PAK POL SPM
               PCN PRI PSE PRT PLW PRY QAT REU
               ROU RUS RWA SAU SLB SYC SDN SWE
               SGP SHN SVN SJM SVK SLE SMR SEN
               SOM SUR STP SLV SYR SWZ TCA TCD
               ATF TGO THA TJK TKL TKM TUN TON
               TLS TUR TTO TUV TWN TZA UKR UGA
               UMI USA URY UZB VAT VCT VEN VGB
               VIR VNM VUT WLF WSM YEM MYT SRB
               ZAF ZMB MNE ZWE A1  A2  O1  ALA
			   GGY IMN JEY BLM MAF         /
);
my @names = (
              undef,
              "Asia/Pacific Region",
              "Europe",
              "Andorra",
              "United Arab Emirates",
              "Afghanistan",
              "Antigua and Barbuda",
              "Anguilla",
              "Albania",
              "Armenia",
              "Netherlands Antilles",
              "Angola",
              "Antarctica",
              "Argentina",
              "American Samoa",
              "Austria",
              "Australia",
              "Aruba",
              "Azerbaijan",
              "Bosnia and Herzegovina",
              "Barbados",
              "Bangladesh",
              "Belgium",
              "Burkina Faso",
              "Bulgaria",
              "Bahrain",
              "Burundi",
              "Benin",
              "Bermuda",
              "Brunei Darussalam",
              "Bolivia",
              "Brazil",
              "Bahamas",
              "Bhutan",
              "Bouvet Island",
              "Botswana",
              "Belarus",
              "Belize",
              "Canada",
              "Cocos (Keeling) Islands",
              "Congo, The Democratic Republic of the",
              "Central African Republic",
              "Congo",
              "Switzerland",
              "Cote D'Ivoire",
              "Cook Islands",
              "Chile",
              "Cameroon",
              "China",
              "Colombia",
              "Costa Rica",
              "Cuba",
              "Cape Verde",
              "Christmas Island",
              "Cyprus",
              "Czech Republic",
              "Germany",
              "Djibouti",
              "Denmark",
              "Dominica",
              "Dominican Republic",
              "Algeria",
              "Ecuador",
              "Estonia",
              "Egypt",
              "Western Sahara",
              "Eritrea",
              "Spain",
              "Ethiopia",
              "Finland",
              "Fiji",
              "Falkland Islands (Malvinas)",
              "Micronesia, Federated States of",
              "Faroe Islands",
              "France",
              "France, Metropolitan",
              "Gabon",
              "United Kingdom",
              "Grenada",
              "Georgia",
              "French Guiana",
              "Ghana",
              "Gibraltar",
              "Greenland",
              "Gambia",
              "Guinea",
              "Guadeloupe",
              "Equatorial Guinea",
              "Greece",
              "South Georgia and the South Sandwich Islands",
              "Guatemala",
              "Guam",
              "Guinea-Bissau",
              "Guyana",
              "Hong Kong",
              "Heard Island and McDonald Islands",
              "Honduras",
              "Croatia",
              "Haiti",
              "Hungary",
              "Indonesia",
              "Ireland",
              "Israel",
              "India",
              "British Indian Ocean Territory",
              "Iraq",
              "Iran, Islamic Republic of",
              "Iceland",
              "Italy",
              "Jamaica",
              "Jordan",
              "Japan",
              "Kenya",
              "Kyrgyzstan",
              "Cambodia",
              "Kiribati",
              "Comoros",
              "Saint Kitts and Nevis",
              "Korea, Democratic People's Republic of",
              "Korea, Republic of",
              "Kuwait",
              "Cayman Islands",
              "Kazakhstan",
              "Lao People's Democratic Republic",
              "Lebanon",
              "Saint Lucia",
              "Liechtenstein",
              "Sri Lanka",
              "Liberia",
              "Lesotho",
              "Lithuania",
              "Luxembourg",
              "Latvia",
              "Libyan Arab Jamahiriya",
              "Morocco",
              "Monaco",
              "Moldova, Republic of",
              "Madagascar",
              "Marshall Islands",
              "Macedonia",
              "Mali",
              "Myanmar",
              "Mongolia",
              "Macau",
              "Northern Mariana Islands",
              "Martinique",
              "Mauritania",
              "Montserrat",
              "Malta",
              "Mauritius",
              "Maldives",
              "Malawi",
              "Mexico",
              "Malaysia",
              "Mozambique",
              "Namibia",
              "New Caledonia",
              "Niger",
              "Norfolk Island",
              "Nigeria",
              "Nicaragua",
              "Netherlands",
              "Norway",
              "Nepal",
              "Nauru",
              "Niue",
              "New Zealand",
              "Oman",
              "Panama",
              "Peru",
              "French Polynesia",
              "Papua New Guinea",
              "Philippines",
              "Pakistan",
              "Poland",
              "Saint Pierre and Miquelon",
              "Pitcairn Islands",
              "Puerto Rico",
              "Palestinian Territory",
              "Portugal",
              "Palau",
              "Paraguay",
              "Qatar",
              "Reunion",
              "Romania",
              "Russian Federation",
              "Rwanda",
              "Saudi Arabia",
              "Solomon Islands",
              "Seychelles",
              "Sudan",
              "Sweden",
              "Singapore",
              "Saint Helena",
              "Slovenia",
              "Svalbard and Jan Mayen",
              "Slovakia",
              "Sierra Leone",
              "San Marino",
              "Senegal",
              "Somalia",
              "Suriname",
              "Sao Tome and Principe",
              "El Salvador",
              "Syrian Arab Republic",
              "Swaziland",
              "Turks and Caicos Islands",
              "Chad",
              "French Southern Territories",
              "Togo",
              "Thailand",
              "Tajikistan",
              "Tokelau",
              "Turkmenistan",
              "Tunisia",
              "Tonga",
              "Timor-Leste",
              "Turkey",
              "Trinidad and Tobago",
              "Tuvalu",
              "Taiwan",
              "Tanzania, United Republic of",
              "Ukraine",
              "Uganda",
              "United States Minor Outlying Islands",
              "United States",
              "Uruguay",
              "Uzbekistan",
              "Holy See (Vatican City State)",
              "Saint Vincent and the Grenadines",
              "Venezuela",
              "Virgin Islands, British",
              "Virgin Islands, U.S.",
              "Vietnam",
              "Vanuatu",
              "Wallis and Futuna",
              "Samoa",
              "Yemen",
              "Mayotte",
              "Serbia",
              "South Africa",
              "Zambia",
              "Montenegro",
              "Zimbabwe",
              "Anonymous Proxy",
              "Satellite Provider",
              "Other",
			  "Aland Islands",
              "Guernsey",
              "Isle of Man",
              "Jersey",
			  "Saint Barthelemy",
			  "Saint Martin"
);

## created with:
# perl -Ilib -e 'use MM::GeoIP::Reloaded::Country_Region_Names q{%country_region_names}; use Data::Dumper; $Data::Dumper::Sortkeys++; print Dumper(\%country_region_names)' >/tmp/crn.pl
#
my %country_region_names = (
  'AD' => {
            '02' => 'Canillo',
            '03' => 'Encamp',
            '04' => 'La Massana',
            '05' => 'Ordino',
            '06' => 'Sant Julia de Loria',
            '07' => 'Andorra la Vella',
            '08' => 'Escaldes-Engordany'
  },
  'AE' => {
            '01' => 'Abu Dhabi',
            '02' => 'Ajman',
            '03' => 'Dubai',
            '04' => 'Fujairah',
            '05' => 'Ras Al Khaimah',
            '06' => 'Sharjah',
            '07' => 'Umm Al Quwain'
  },
  'AF' => {
            '01' => 'Badakhshan',
            '02' => 'Badghis',
            '03' => 'Baghlan',
            '05' => 'Bamian',
            '06' => 'Farah',
            '07' => 'Faryab',
            '08' => 'Ghazni',
            '09' => 'Ghowr',
            '10' => 'Helmand',
            '11' => 'Herat',
            '13' => 'Kabol',
            '14' => 'Kapisa',
            '17' => 'Lowgar',
            '18' => 'Nangarhar',
            '19' => 'Nimruz',
            '23' => 'Kandahar',
            '24' => 'Kondoz',
            '26' => 'Takhar',
            '27' => 'Vardak',
            '28' => 'Zabol',
            '29' => 'Paktika',
            '30' => 'Balkh',
            '31' => 'Jowzjan',
            '32' => 'Samangan',
            '33' => 'Sar-e Pol',
            '34' => 'Konar',
            '35' => 'Laghman',
            '36' => 'Paktia',
            '37' => 'Khowst',
            '38' => 'Nurestan',
            '39' => 'Oruzgan',
            '40' => 'Parvan',
            '41' => 'Daykondi',
            '42' => 'Panjshir'
  },
  'AG' => {
            '01' => 'Barbuda',
            '03' => 'Saint George',
            '04' => 'Saint John',
            '05' => 'Saint Mary',
            '06' => 'Saint Paul',
            '07' => 'Saint Peter',
            '08' => 'Saint Philip',
            '09' => 'Redonda'
  },
  'AL' => {
            '40' => 'Berat',
            '41' => 'Diber',
            '42' => 'Durres',
            '43' => 'Elbasan',
            '44' => 'Fier',
            '45' => 'Gjirokaster',
            '46' => 'Korce',
            '47' => 'Kukes',
            '48' => 'Lezhe',
            '49' => 'Shkoder',
            '50' => 'Tirane',
            '51' => 'Vlore'
  },
  'AM' => {
            '01' => 'Aragatsotn',
            '02' => 'Ararat',
            '03' => 'Armavir',
            '04' => 'Geghark\'unik\'',
            '05' => 'Kotayk\'',
            '06' => 'Lorri',
            '07' => 'Shirak',
            '08' => 'Syunik\'',
            '09' => 'Tavush',
            '10' => 'Vayots\' Dzor',
            '11' => 'Yerevan'
  },
  'AO' => {
            '01' => 'Benguela',
            '02' => 'Bie',
            '03' => 'Cabinda',
            '04' => 'Cuando Cubango',
            '05' => 'Cuanza Norte',
            '06' => 'Cuanza Sul',
            '07' => 'Cunene',
            '08' => 'Huambo',
            '09' => 'Huila',
            '12' => 'Malanje',
            '13' => 'Namibe',
            '14' => 'Moxico',
            '15' => 'Uige',
            '16' => 'Zaire',
            '17' => 'Lunda Norte',
            '18' => 'Lunda Sul',
            '19' => 'Bengo',
            '20' => 'Luanda'
  },
  'AR' => {
            '01' => 'Buenos Aires',
            '02' => 'Catamarca',
            '03' => 'Chaco',
            '04' => 'Chubut',
            '05' => 'Cordoba',
            '06' => 'Corrientes',
            '07' => 'Distrito Federal',
            '08' => 'Entre Rios',
            '09' => 'Formosa',
            '10' => 'Jujuy',
            '11' => 'La Pampa',
            '12' => 'La Rioja',
            '13' => 'Mendoza',
            '14' => 'Misiones',
            '15' => 'Neuquen',
            '16' => 'Rio Negro',
            '17' => 'Salta',
            '18' => 'San Juan',
            '19' => 'San Luis',
            '20' => 'Santa Cruz',
            '21' => 'Santa Fe',
            '22' => 'Santiago del Estero',
            '23' => 'Tierra del Fuego',
            '24' => 'Tucuman'
  },
  'AT' => {
            '01' => 'Burgenland',
            '02' => 'Karnten',
            '03' => 'Niederosterreich',
            '04' => 'Oberosterreich',
            '05' => 'Salzburg',
            '06' => 'Steiermark',
            '07' => 'Tirol',
            '08' => 'Vorarlberg',
            '09' => 'Wien'
  },
  'AU' => {
            '01' => 'Australian Capital Territory',
            '02' => 'New South Wales',
            '03' => 'Northern Territory',
            '04' => 'Queensland',
            '05' => 'South Australia',
            '06' => 'Tasmania',
            '07' => 'Victoria',
            '08' => 'Western Australia'
  },
  'AZ' => {
            '01' => 'Abseron',
            '02' => 'Agcabadi',
            '03' => 'Agdam',
            '04' => 'Agdas',
            '05' => 'Agstafa',
            '06' => 'Agsu',
            '07' => 'Ali Bayramli',
            '08' => 'Astara',
            '09' => 'Baki',
            '10' => 'Balakan',
            '11' => 'Barda',
            '12' => 'Beylaqan',
            '13' => 'Bilasuvar',
            '14' => 'Cabrayil',
            '15' => 'Calilabad',
            '16' => 'Daskasan',
            '17' => 'Davaci',
            '18' => 'Fuzuli',
            '19' => 'Gadabay',
            '20' => 'Ganca',
            '21' => 'Goranboy',
            '22' => 'Goycay',
            '23' => 'Haciqabul',
            '24' => 'Imisli',
            '25' => 'Ismayilli',
            '26' => 'Kalbacar',
            '27' => 'Kurdamir',
            '28' => 'Lacin',
            '29' => 'Lankaran',
            '30' => 'Lankaran',
            '31' => 'Lerik',
            '32' => 'Masalli',
            '33' => 'Mingacevir',
            '34' => 'Naftalan',
            '35' => 'Naxcivan',
            '36' => 'Neftcala',
            '37' => 'Oguz',
            '38' => 'Qabala',
            '39' => 'Qax',
            '40' => 'Qazax',
            '41' => 'Qobustan',
            '42' => 'Quba',
            '43' => 'Qubadli',
            '44' => 'Qusar',
            '45' => 'Saatli',
            '46' => 'Sabirabad',
            '47' => 'Saki',
            '48' => 'Saki',
            '49' => 'Salyan',
            '50' => 'Samaxi',
            '51' => 'Samkir',
            '52' => 'Samux',
            '53' => 'Siyazan',
            '54' => 'Sumqayit',
            '55' => 'Susa',
            '56' => 'Susa',
            '57' => 'Tartar',
            '58' => 'Tovuz',
            '59' => 'Ucar',
            '60' => 'Xacmaz',
            '61' => 'Xankandi',
            '62' => 'Xanlar',
            '63' => 'Xizi',
            '64' => 'Xocali',
            '65' => 'Xocavand',
            '66' => 'Yardimli',
            '67' => 'Yevlax',
            '68' => 'Yevlax',
            '69' => 'Zangilan',
            '70' => 'Zaqatala',
            '71' => 'Zardab'
  },
  'BA' => {
            '01' => 'Federation of Bosnia and Herzegovina',
            '02' => 'Republika Srpska'
  },
  'BB' => {
            '01' => 'Christ Church',
            '02' => 'Saint Andrew',
            '03' => 'Saint George',
            '04' => 'Saint James',
            '05' => 'Saint John',
            '06' => 'Saint Joseph',
            '07' => 'Saint Lucy',
            '08' => 'Saint Michael',
            '09' => 'Saint Peter',
            '10' => 'Saint Philip',
            '11' => 'Saint Thomas'
  },
  'BD' => {
            '81' => 'Dhaka',
            '82' => 'Khulna',
            '83' => 'Rajshahi',
            '84' => 'Chittagong',
            '85' => 'Barisal',
            '86' => 'Sylhet'
  },
  'BE' => {
            '01' => 'Antwerpen',
            '03' => 'Hainaut',
            '04' => 'Liege',
            '05' => 'Limburg',
            '06' => 'Luxembourg',
            '07' => 'Namur',
            '08' => 'Oost-Vlaanderen',
            '09' => 'West-Vlaanderen',
            '10' => 'Brabant Wallon',
            '11' => 'Brussels Hoofdstedelijk Gewest',
            '12' => 'Vlaams-Brabant'
  },
  'BF' => {
            '15' => 'Bam',
            '19' => 'Boulkiemde',
            '20' => 'Ganzourgou',
            '21' => 'Gnagna',
            '28' => 'Kouritenga',
            '33' => 'Oudalan',
            '34' => 'Passore',
            '36' => 'Sanguie',
            '40' => 'Soum',
            '42' => 'Tapoa',
            '44' => 'Zoundweogo',
            '45' => 'Bale',
            '46' => 'Banwa',
            '47' => 'Bazega',
            '48' => 'Bougouriba',
            '49' => 'Boulgou',
            '50' => 'Gourma',
            '51' => 'Houet',
            '52' => 'Ioba',
            '53' => 'Kadiogo',
            '54' => 'Kenedougou',
            '55' => 'Komoe',
            '56' => 'Komondjari',
            '57' => 'Kompienga',
            '58' => 'Kossi',
            '59' => 'Koulpelogo',
            '60' => 'Kourweogo',
            '61' => 'Leraba',
            '62' => 'Loroum',
            '63' => 'Mouhoun',
            '64' => 'Namentenga',
            '65' => 'Naouri',
            '66' => 'Nayala',
            '67' => 'Noumbiel',
            '68' => 'Oubritenga',
            '69' => 'Poni',
            '70' => 'Sanmatenga',
            '71' => 'Seno',
            '72' => 'Sissili',
            '73' => 'Sourou',
            '74' => 'Tuy',
            '75' => 'Yagha',
            '76' => 'Yatenga',
            '77' => 'Ziro',
            '78' => 'Zondoma'
  },
  'BG' => {
            '33' => 'Mikhaylovgrad',
            '38' => 'Blagoevgrad',
            '39' => 'Burgas',
            '40' => 'Dobrich',
            '41' => 'Gabrovo',
            '42' => 'Grad Sofiya',
            '43' => 'Khaskovo',
            '44' => 'Kurdzhali',
            '45' => 'Kyustendil',
            '46' => 'Lovech',
            '47' => 'Montana',
            '48' => 'Pazardzhik',
            '49' => 'Pernik',
            '50' => 'Pleven',
            '51' => 'Plovdiv',
            '52' => 'Razgrad',
            '53' => 'Ruse',
            '54' => 'Shumen',
            '55' => 'Silistra',
            '56' => 'Sliven',
            '57' => 'Smolyan',
            '58' => 'Sofiya',
            '59' => 'Stara Zagora',
            '60' => 'Turgovishte',
            '61' => 'Varna',
            '62' => 'Veliko Turnovo',
            '63' => 'Vidin',
            '64' => 'Vratsa',
            '65' => 'Yambol'
  },
  'BH' => {
            '01' => 'Al Hadd',
            '02' => 'Al Manamah',
            '05' => 'Jidd Hafs',
            '06' => 'Sitrah',
            '08' => 'Al Mintaqah al Gharbiyah',
            '09' => 'Mintaqat Juzur Hawar',
            '10' => 'Al Mintaqah ash Shamaliyah',
            '11' => 'Al Mintaqah al Wusta',
            '12' => 'Madinat',
            '13' => 'Ar Rifa',
            '14' => 'Madinat Hamad',
            '15' => 'Al Muharraq',
            '16' => 'Al Asimah',
            '17' => 'Al Janubiyah',
            '18' => 'Ash Shamaliyah',
            '19' => 'Al Wusta'
  },
  'BI' => {
            '02' => 'Bujumbura',
            '09' => 'Bubanza',
            '10' => 'Bururi',
            '11' => 'Cankuzo',
            '12' => 'Cibitoke',
            '13' => 'Gitega',
            '14' => 'Karuzi',
            '15' => 'Kayanza',
            '16' => 'Kirundo',
            '17' => 'Makamba',
            '18' => 'Muyinga',
            '19' => 'Ngozi',
            '20' => 'Rutana',
            '21' => 'Ruyigi',
            '22' => 'Muramvya',
            '23' => 'Mwaro'
  },
  'BJ' => {
            '07' => 'Alibori',
            '08' => 'Atakora',
            '09' => 'Atlanyique',
            '10' => 'Borgou',
            '11' => 'Collines',
            '12' => 'Kouffo',
            '13' => 'Donga',
            '14' => 'Littoral',
            '15' => 'Mono',
            '16' => 'Oueme',
            '17' => 'Plateau',
            '18' => 'Zou'
  },
  'BM' => {
            '01' => 'Devonshire',
            '02' => 'Hamilton',
            '03' => 'Hamilton',
            '04' => 'Paget',
            '05' => 'Pembroke',
            '06' => 'Saint George',
            '07' => 'Saint George\'s',
            '08' => 'Sandys',
            '09' => 'Smiths',
            '10' => 'Southampton',
            '11' => 'Warwick'
  },
  'BN' => {
            '07' => 'Alibori',
            '08' => 'Belait',
            '09' => 'Brunei and Muara',
            '10' => 'Temburong',
            '11' => 'Collines',
            '12' => 'Kouffo',
            '13' => 'Donga',
            '14' => 'Littoral',
            '15' => 'Tutong',
            '16' => 'Oueme',
            '17' => 'Plateau',
            '18' => 'Zou'
  },
  'BO' => {
            '01' => 'Chuquisaca',
            '02' => 'Cochabamba',
            '03' => 'El Beni',
            '04' => 'La Paz',
            '05' => 'Oruro',
            '06' => 'Pando',
            '07' => 'Potosi',
            '08' => 'Santa Cruz',
            '09' => 'Tarija'
  },
  'BR' => {
            '01' => 'Acre',
            '02' => 'Alagoas',
            '03' => 'Amapa',
            '04' => 'Amazonas',
            '05' => 'Bahia',
            '06' => 'Ceara',
            '07' => 'Distrito Federal',
            '08' => 'Espirito Santo',
            '11' => 'Mato Grosso do Sul',
            '13' => 'Maranhao',
            '14' => 'Mato Grosso',
            '15' => 'Minas Gerais',
            '16' => 'Para',
            '17' => 'Paraiba',
            '18' => 'Parana',
            '20' => 'Piaui',
            '21' => 'Rio de Janeiro',
            '22' => 'Rio Grande do Norte',
            '23' => 'Rio Grande do Sul',
            '24' => 'Rondonia',
            '25' => 'Roraima',
            '26' => 'Santa Catarina',
            '27' => 'Sao Paulo',
            '28' => 'Sergipe',
            '29' => 'Goias',
            '30' => 'Pernambuco',
            '31' => 'Tocantins'
  },
  'BS' => {
            '05' => 'Bimini',
            '06' => 'Cat Island',
            '10' => 'Exuma',
            '13' => 'Inagua',
            '15' => 'Long Island',
            '16' => 'Mayaguana',
            '18' => 'Ragged Island',
            '22' => 'Harbour Island',
            '23' => 'New Providence',
            '24' => 'Acklins and Crooked Islands',
            '25' => 'Freeport',
            '26' => 'Fresh Creek',
            '27' => 'Governor\'s Harbour',
            '28' => 'Green Turtle Cay',
            '29' => 'High Rock',
            '30' => 'Kemps Bay',
            '31' => 'Marsh Harbour',
            '32' => 'Nichollstown and Berry Islands',
            '33' => 'Rock Sound',
            '34' => 'Sandy Point',
            '35' => 'San Salvador and Rum Cay'
  },
  'BT' => {
            '05' => 'Bumthang',
            '06' => 'Chhukha',
            '07' => 'Chirang',
            '08' => 'Daga',
            '09' => 'Geylegphug',
            '10' => 'Ha',
            '11' => 'Lhuntshi',
            '12' => 'Mongar',
            '13' => 'Paro',
            '14' => 'Pemagatsel',
            '15' => 'Punakha',
            '16' => 'Samchi',
            '17' => 'Samdrup',
            '18' => 'Shemgang',
            '19' => 'Tashigang',
            '20' => 'Thimphu',
            '21' => 'Tongsa',
            '22' => 'Wangdi Phodrang'
  },
  'BW' => {
            '01' => 'Central',
            '03' => 'Ghanzi',
            '04' => 'Kgalagadi',
            '05' => 'Kgatleng',
            '06' => 'Kweneng',
            '08' => 'North-East',
            '09' => 'South-East',
            '10' => 'Southern',
            '11' => 'North-West'
  },
  'BY' => {
            '01' => 'Brestskaya Voblasts\'',
            '02' => 'Homyel\'skaya Voblasts\'',
            '03' => 'Hrodzyenskaya Voblasts\'',
            '04' => 'Minsk',
            '05' => 'Minskaya Voblasts\'',
            '06' => 'Mahilyowskaya Voblasts\'',
            '07' => 'Vitsyebskaya Voblasts\''
  },
  'BZ' => {
            '01' => 'Belize',
            '02' => 'Cayo',
            '03' => 'Corozal',
            '04' => 'Orange Walk',
            '05' => 'Stann Creek',
            '06' => 'Toledo'
  },
  'CA' => {
            'AB' => 'Alberta',
            'BC' => 'British Columbia',
            'MB' => 'Manitoba',
            'NB' => 'New Brunswick',
            'NL' => 'Newfoundland',
            'NS' => 'Nova Scotia',
            'NT' => 'Northwest Territories',
            'NU' => 'Nunavut',
            'ON' => 'Ontario',
            'PE' => 'Prince Edward Island',
            'QC' => 'Quebec',
            'SK' => 'Saskatchewan',
            'YT' => 'Yukon Territory'
  },
  'CD' => {
            '01' => 'Bandundu',
            '02' => 'Equateur',
            '04' => 'Kasai-Oriental',
            '05' => 'Katanga',
            '06' => 'Kinshasa',
            '08' => 'Bas-Congo',
            '09' => 'Orientale',
            '10' => 'Maniema',
            '11' => 'Nord-Kivu',
            '12' => 'Sud-Kivu'
  },
  'CF' => {
            '01' => 'Bamingui-Bangoran',
            '02' => 'Basse-Kotto',
            '03' => 'Haute-Kotto',
            '04' => 'Mambere-Kadei',
            '05' => 'Haut-Mbomou',
            '06' => 'Kemo',
            '07' => 'Lobaye',
            '08' => 'Mbomou',
            '09' => 'Nana-Mambere',
            '11' => 'Ouaka',
            '12' => 'Ouham',
            '13' => 'Ouham-Pende',
            '14' => 'Cuvette-Ouest',
            '15' => 'Nana-Grebizi',
            '16' => 'Sangha-Mbaere',
            '17' => 'Ombella-Mpoko',
            '18' => 'Bangui'
  },
  'CG' => {
            '01' => 'Bouenza',
            '04' => 'Kouilou',
            '05' => 'Lekoumou',
            '06' => 'Likouala',
            '07' => 'Niari',
            '08' => 'Plateaux',
            '10' => 'Sangha',
            '11' => 'Pool',
            '12' => 'Brazzaville',
            '13' => 'Cuvette',
            '14' => 'Cuvette-Ouest'
  },
  'CH' => {
            '01' => 'Aargau',
            '02' => 'Ausser-Rhoden',
            '03' => 'Basel-Landschaft',
            '04' => 'Basel-Stadt',
            '05' => 'Bern',
            '06' => 'Fribourg',
            '07' => 'Geneve',
            '08' => 'Glarus',
            '09' => 'Graubunden',
            '10' => 'Inner-Rhoden',
            '11' => 'Luzern',
            '12' => 'Neuchatel',
            '13' => 'Nidwalden',
            '14' => 'Obwalden',
            '15' => 'Sankt Gallen',
            '16' => 'Schaffhausen',
            '17' => 'Schwyz',
            '18' => 'Solothurn',
            '19' => 'Thurgau',
            '20' => 'Ticino',
            '21' => 'Uri',
            '22' => 'Valais',
            '23' => 'Vaud',
            '24' => 'Zug',
            '25' => 'Zurich',
            '26' => 'Jura'
  },
  'CI' => {
            '74' => 'Agneby',
            '75' => 'Bafing',
            '76' => 'Bas-Sassandra',
            '77' => 'Denguele',
            '78' => 'Dix-Huit Montagnes',
            '79' => 'Fromager',
            '80' => 'Haut-Sassandra',
            '81' => 'Lacs',
            '82' => 'Lagunes',
            '83' => 'Marahoue',
            '84' => 'Moyen-Cavally',
            '85' => 'Moyen-Comoe',
            '86' => 'N\'zi-Comoe',
            '87' => 'Savanes',
            '88' => 'Sud-Bandama',
            '89' => 'Sud-Comoe',
            '90' => 'Vallee du Bandama',
            '91' => 'Worodougou',
            '92' => 'Zanzan'
  },
  'CL' => {
            '01' => 'Valparaiso',
            '02' => 'Aisen del General Carlos Ibanez del Campo',
            '03' => 'Antofagasta',
            '04' => 'Araucania',
            '05' => 'Atacama',
            '06' => 'Bio-Bio',
            '07' => 'Coquimbo',
            '08' => 'Libertador General Bernardo O\'Higgins',
            '09' => 'Los Lagos',
            '10' => 'Magallanes y de la Antartica Chilena',
            '11' => 'Maule',
            '12' => 'Region Metropolitana',
            '13' => 'Tarapaca',
            '14' => 'Los Lagos',
            '15' => 'Tarapaca',
            '16' => 'Arica y Parinacota',
            '17' => 'Los Rios'
  },
  'CM' => {
            '04' => 'Est',
            '05' => 'Littoral',
            '07' => 'Nord-Ouest',
            '08' => 'Ouest',
            '09' => 'Sud-Ouest',
            '10' => 'Adamaoua',
            '11' => 'Centre',
            '12' => 'Extreme-Nord',
            '13' => 'Nord',
            '14' => 'Sud'
  },
  'CN' => {
            '01' => 'Anhui',
            '02' => 'Zhejiang',
            '03' => 'Jiangxi',
            '04' => 'Jiangsu',
            '05' => 'Jilin',
            '06' => 'Qinghai',
            '07' => 'Fujian',
            '08' => 'Heilongjiang',
            '09' => 'Henan',
            '10' => 'Hebei',
            '11' => 'Hunan',
            '12' => 'Hubei',
            '13' => 'Xinjiang',
            '14' => 'Xizang',
            '15' => 'Gansu',
            '16' => 'Guangxi',
            '18' => 'Guizhou',
            '19' => 'Liaoning',
            '20' => 'Nei Mongol',
            '21' => 'Ningxia',
            '22' => 'Beijing',
            '23' => 'Shanghai',
            '24' => 'Shanxi',
            '25' => 'Shandong',
            '26' => 'Shaanxi',
            '28' => 'Tianjin',
            '29' => 'Yunnan',
            '30' => 'Guangdong',
            '31' => 'Hainan',
            '32' => 'Sichuan',
            '33' => 'Chongqing'
  },
  'CO' => {
            '01' => 'Amazonas',
            '02' => 'Antioquia',
            '03' => 'Arauca',
            '04' => 'Atlantico',
            '05' => 'Bolivar Department',
            '06' => 'Boyaca Department',
            '07' => 'Caldas Department',
            '08' => 'Caqueta',
            '09' => 'Cauca',
            '10' => 'Cesar',
            '11' => 'Choco',
            '12' => 'Cordoba',
            '14' => 'Guaviare',
            '15' => 'Guainia',
            '16' => 'Huila',
            '17' => 'La Guajira',
            '18' => 'Magdalena Department',
            '19' => 'Meta',
            '20' => 'Narino',
            '21' => 'Norte de Santander',
            '22' => 'Putumayo',
            '23' => 'Quindio',
            '24' => 'Risaralda',
            '25' => 'San Andres y Providencia',
            '26' => 'Santander',
            '27' => 'Sucre',
            '28' => 'Tolima',
            '29' => 'Valle del Cauca',
            '30' => 'Vaupes',
            '31' => 'Vichada',
            '32' => 'Casanare',
            '33' => 'Cundinamarca',
            '34' => 'Distrito Especial',
            '35' => 'Bolivar',
            '36' => 'Boyaca',
            '37' => 'Caldas',
            '38' => 'Magdalena'
  },
  'CR' => {
            '01' => 'Alajuela',
            '02' => 'Cartago',
            '03' => 'Guanacaste',
            '04' => 'Heredia',
            '06' => 'Limon',
            '07' => 'Puntarenas',
            '08' => 'San Jose'
  },
  'CU' => {
            '01' => 'Pinar del Rio',
            '02' => 'Ciudad de la Habana',
            '03' => 'Matanzas',
            '04' => 'Isla de la Juventud',
            '05' => 'Camaguey',
            '07' => 'Ciego de Avila',
            '08' => 'Cienfuegos',
            '09' => 'Granma',
            '10' => 'Guantanamo',
            '11' => 'La Habana',
            '12' => 'Holguin',
            '13' => 'Las Tunas',
            '14' => 'Sancti Spiritus',
            '15' => 'Santiago de Cuba',
            '16' => 'Villa Clara'
  },
  'CV' => {
            '01' => 'Boa Vista',
            '02' => 'Brava',
            '04' => 'Maio',
            '05' => 'Paul',
            '07' => 'Ribeira Grande',
            '08' => 'Sal',
            '10' => 'Sao Nicolau',
            '11' => 'Sao Vicente',
            '13' => 'Mosteiros',
            '14' => 'Praia',
            '15' => 'Santa Catarina',
            '16' => 'Santa Cruz',
            '17' => 'Sao Domingos',
            '18' => 'Sao Filipe',
            '19' => 'Sao Miguel',
            '20' => 'Tarrafal'
  },
  'CY' => {
            '01' => 'Famagusta',
            '02' => 'Kyrenia',
            '03' => 'Larnaca',
            '04' => 'Nicosia',
            '05' => 'Limassol',
            '06' => 'Paphos'
  },
  'CZ' => {
            '52' => 'Hlavni mesto Praha',
            '78' => 'Jihomoravsky kraj',
            '79' => 'Jihocesky kraj',
            '80' => 'Vysocina',
            '81' => 'Karlovarsky kraj',
            '82' => 'Kralovehradecky kraj',
            '83' => 'Liberecky kraj',
            '84' => 'Olomoucky kraj',
            '85' => 'Moravskoslezsky kraj',
            '86' => 'Pardubicky kraj',
            '87' => 'Plzensky kraj',
            '88' => 'Stredocesky kraj',
            '89' => 'Ustecky kraj',
            '90' => 'Zlinsky kraj'
  },
  'DE' => {
            '01' => 'Baden-Wurttemberg',
            '02' => 'Bayern',
            '03' => 'Bremen',
            '04' => 'Hamburg',
            '05' => 'Hessen',
            '06' => 'Niedersachsen',
            '07' => 'Nordrhein-Westfalen',
            '08' => 'Rheinland-Pfalz',
            '09' => 'Saarland',
            '10' => 'Schleswig-Holstein',
            '11' => 'Brandenburg',
            '12' => 'Mecklenburg-Vorpommern',
            '13' => 'Sachsen',
            '14' => 'Sachsen-Anhalt',
            '15' => 'Thuringen',
            '16' => 'Berlin'
  },
  'DJ' => {
            '01' => 'Ali Sabieh',
            '04' => 'Obock',
            '05' => 'Tadjoura',
            '06' => 'Dikhil',
            '07' => 'Djibouti',
            '08' => 'Arta'
  },
  'DK' => {
            '17' => 'Hovedstaden',
            '18' => 'Midtjylland',
            '19' => 'Nordjylland',
            '20' => 'Sjelland',
            '21' => 'Syddanmark'
  },
  'DM' => {
            '02' => 'Saint Andrew',
            '03' => 'Saint David',
            '04' => 'Saint George',
            '05' => 'Saint John',
            '06' => 'Saint Joseph',
            '07' => 'Saint Luke',
            '08' => 'Saint Mark',
            '09' => 'Saint Patrick',
            '10' => 'Saint Paul',
            '11' => 'Saint Peter'
  },
  'DO' => {
            '01' => 'Azua',
            '02' => 'Baoruco',
            '03' => 'Barahona',
            '04' => 'Dajabon',
            '05' => 'Distrito Nacional',
            '06' => 'Duarte',
            '08' => 'Espaillat',
            '09' => 'Independencia',
            '10' => 'La Altagracia',
            '11' => 'Elias Pina',
            '12' => 'La Romana',
            '14' => 'Maria Trinidad Sanchez',
            '15' => 'Monte Cristi',
            '16' => 'Pedernales',
            '17' => 'Peravia',
            '18' => 'Puerto Plata',
            '19' => 'Salcedo',
            '20' => 'Samana',
            '21' => 'Sanchez Ramirez',
            '23' => 'San Juan',
            '24' => 'San Pedro De Macoris',
            '25' => 'Santiago',
            '26' => 'Santiago Rodriguez',
            '27' => 'Valverde',
            '28' => 'El Seibo',
            '29' => 'Hato Mayor',
            '30' => 'La Vega',
            '31' => 'Monsenor Nouel',
            '32' => 'Monte Plata',
            '33' => 'San Cristobal',
            '34' => 'Distrito Nacional',
            '35' => 'Peravia',
            '36' => 'San Jose de Ocoa',
            '37' => 'Santo Domingo'
  },
  'DZ' => {
            '01' => 'Alger',
            '03' => 'Batna',
            '04' => 'Constantine',
            '06' => 'Medea',
            '07' => 'Mostaganem',
            '09' => 'Oran',
            '10' => 'Saida',
            '12' => 'Setif',
            '13' => 'Tiaret',
            '14' => 'Tizi Ouzou',
            '15' => 'Tlemcen',
            '18' => 'Bejaia',
            '19' => 'Biskra',
            '20' => 'Blida',
            '21' => 'Bouira',
            '22' => 'Djelfa',
            '23' => 'Guelma',
            '24' => 'Jijel',
            '25' => 'Laghouat',
            '26' => 'Mascara',
            '27' => 'M\'sila',
            '29' => 'Oum el Bouaghi',
            '30' => 'Sidi Bel Abbes',
            '31' => 'Skikda',
            '33' => 'Tebessa',
            '34' => 'Adrar',
            '35' => 'Ain Defla',
            '36' => 'Ain Temouchent',
            '37' => 'Annaba',
            '38' => 'Bechar',
            '39' => 'Bordj Bou Arreridj',
            '40' => 'Boumerdes',
            '41' => 'Chlef',
            '42' => 'El Bayadh',
            '43' => 'El Oued',
            '44' => 'El Tarf',
            '45' => 'Ghardaia',
            '46' => 'Illizi',
            '47' => 'Khenchela',
            '48' => 'Mila',
            '49' => 'Naama',
            '50' => 'Ouargla',
            '51' => 'Relizane',
            '52' => 'Souk Ahras',
            '53' => 'Tamanghasset',
            '54' => 'Tindouf',
            '55' => 'Tipaza',
            '56' => 'Tissemsilt'
  },
  'EC' => {
            '01' => 'Galapagos',
            '02' => 'Azuay',
            '03' => 'Bolivar',
            '04' => 'Canar',
            '05' => 'Carchi',
            '06' => 'Chimborazo',
            '07' => 'Cotopaxi',
            '08' => 'El Oro',
            '09' => 'Esmeraldas',
            '10' => 'Guayas',
            '11' => 'Imbabura',
            '12' => 'Loja',
            '13' => 'Los Rios',
            '14' => 'Manabi',
            '15' => 'Morona-Santiago',
            '17' => 'Pastaza',
            '18' => 'Pichincha',
            '19' => 'Tungurahua',
            '20' => 'Zamora-Chinchipe',
            '22' => 'Sucumbios',
            '23' => 'Napo',
            '24' => 'Orellana'
  },
  'EE' => {
            '01' => 'Harjumaa',
            '02' => 'Hiiumaa',
            '03' => 'Ida-Virumaa',
            '04' => 'Jarvamaa',
            '05' => 'Jogevamaa',
            '06' => 'Kohtla-Jarve',
            '07' => 'Laanemaa',
            '08' => 'Laane-Virumaa',
            '09' => 'Narva',
            '10' => 'Parnu',
            '11' => 'Parnumaa',
            '12' => 'Polvamaa',
            '13' => 'Raplamaa',
            '14' => 'Saaremaa',
            '15' => 'Sillamae',
            '16' => 'Tallinn',
            '17' => 'Tartu',
            '18' => 'Tartumaa',
            '19' => 'Valgamaa',
            '20' => 'Viljandimaa',
            '21' => 'Vorumaa'
  },
  'EG' => {
            '01' => 'Ad Daqahliyah',
            '02' => 'Al Bahr al Ahmar',
            '03' => 'Al Buhayrah',
            '04' => 'Al Fayyum',
            '05' => 'Al Gharbiyah',
            '06' => 'Al Iskandariyah',
            '07' => 'Al Isma\'iliyah',
            '08' => 'Al Jizah',
            '09' => 'Al Minufiyah',
            '10' => 'Al Minya',
            '11' => 'Al Qahirah',
            '12' => 'Al Qalyubiyah',
            '13' => 'Al Wadi al Jadid',
            '14' => 'Ash Sharqiyah',
            '15' => 'As Suways',
            '16' => 'Aswan',
            '17' => 'Asyut',
            '18' => 'Bani Suwayf',
            '19' => 'Bur Sa\'id',
            '20' => 'Dumyat',
            '21' => 'Kafr ash Shaykh',
            '22' => 'Matruh',
            '23' => 'Qina',
            '24' => 'Suhaj',
            '26' => 'Janub Sina\'',
            '27' => 'Shamal Sina\''
  },
  'ER' => {
            '01' => 'Anseba',
            '02' => 'Debub',
            '03' => 'Debubawi K\'eyih Bahri',
            '04' => 'Gash Barka',
            '05' => 'Ma\'akel',
            '06' => 'Semenawi K\'eyih Bahri'
  },
  'ES' => {
            '07' => 'Islas Baleares',
            '27' => 'La Rioja',
            '29' => 'Madrid',
            '31' => 'Murcia',
            '32' => 'Navarra',
            '34' => 'Asturias',
            '39' => 'Cantabria',
            '51' => 'Andalucia',
            '52' => 'Aragon',
            '53' => 'Canarias',
            '54' => 'Castilla-La Mancha',
            '55' => 'Castilla y Leon',
            '56' => 'Catalonia',
            '57' => 'Extremadura',
            '58' => 'Galicia',
            '59' => 'Pais Vasco',
            '60' => 'Comunidad Valenciana'
  },
  'ET' => {
            '44' => 'Adis Abeba',
            '45' => 'Afar',
            '46' => 'Amara',
            '47' => 'Binshangul Gumuz',
            '48' => 'Dire Dawa',
            '49' => 'Gambela Hizboch',
            '50' => 'Hareri Hizb',
            '51' => 'Oromiya',
            '52' => 'Sumale',
            '53' => 'Tigray',
            '54' => 'YeDebub Biheroch Bihereseboch na Hizboch'
  },
  'FI' => {
            '01' => 'Aland',
            '06' => 'Lapland',
            '08' => 'Oulu',
            '13' => 'Southern Finland',
            '14' => 'Eastern Finland',
            '15' => 'Western Finland'
  },
  'FJ' => {
            '01' => 'Central',
            '02' => 'Eastern',
            '03' => 'Northern',
            '04' => 'Rotuma',
            '05' => 'Western'
  },
  'FM' => {
            '01' => 'Kosrae',
            '02' => 'Pohnpei',
            '03' => 'Chuuk',
            '04' => 'Yap'
  },
  'FR' => {
            '97' => 'Aquitaine',
            '98' => 'Auvergne',
            '99' => 'Basse-Normandie',
            'A1' => 'Bourgogne',
            'A2' => 'Bretagne',
            'A3' => 'Centre',
            'A4' => 'Champagne-Ardenne',
            'A5' => 'Corse',
            'A6' => 'Franche-Comte',
            'A7' => 'Haute-Normandie',
            'A8' => 'Ile-de-France',
            'A9' => 'Languedoc-Roussillon',
            'B1' => 'Limousin',
            'B2' => 'Lorraine',
            'B3' => 'Midi-Pyrenees',
            'B4' => 'Nord-Pas-de-Calais',
            'B5' => 'Pays de la Loire',
            'B6' => 'Picardie',
            'B7' => 'Poitou-Charentes',
            'B8' => 'Provence-Alpes-Cote d\'Azur',
            'B9' => 'Rhone-Alpes',
            'C1' => 'Alsace'
  },
  'GA' => {
            '01' => 'Estuaire',
            '02' => 'Haut-Ogooue',
            '03' => 'Moyen-Ogooue',
            '04' => 'Ngounie',
            '05' => 'Nyanga',
            '06' => 'Ogooue-Ivindo',
            '07' => 'Ogooue-Lolo',
            '08' => 'Ogooue-Maritime',
            '09' => 'Woleu-Ntem'
  },
  'GB' => {
            'A1' => 'Barking and Dagenham',
            'A2' => 'Barnet',
            'A3' => 'Barnsley',
            'A4' => 'Bath and North East Somerset',
            'A5' => 'Bedfordshire',
            'A6' => 'Bexley',
            'A7' => 'Birmingham',
            'A8' => 'Blackburn with Darwen',
            'A9' => 'Blackpool',
            'B1' => 'Bolton',
            'B2' => 'Bournemouth',
            'B3' => 'Bracknell Forest',
            'B4' => 'Bradford',
            'B5' => 'Brent',
            'B6' => 'Brighton and Hove',
            'B7' => 'Bristol, City of',
            'B8' => 'Bromley',
            'B9' => 'Buckinghamshire',
            'C1' => 'Bury',
            'C2' => 'Calderdale',
            'C3' => 'Cambridgeshire',
            'C4' => 'Camden',
            'C5' => 'Cheshire',
            'C6' => 'Cornwall',
            'C7' => 'Coventry',
            'C8' => 'Croydon',
            'C9' => 'Cumbria',
            'D1' => 'Darlington',
            'D2' => 'Derby',
            'D3' => 'Derbyshire',
            'D4' => 'Devon',
            'D5' => 'Doncaster',
            'D6' => 'Dorset',
            'D7' => 'Dudley',
            'D8' => 'Durham',
            'D9' => 'Ealing',
            'E1' => 'East Riding of Yorkshire',
            'E2' => 'East Sussex',
            'E3' => 'Enfield',
            'E4' => 'Essex',
            'E5' => 'Gateshead',
            'E6' => 'Gloucestershire',
            'E7' => 'Greenwich',
            'E8' => 'Hackney',
            'E9' => 'Halton',
            'F1' => 'Hammersmith and Fulham',
            'F2' => 'Hampshire',
            'F3' => 'Haringey',
            'F4' => 'Harrow',
            'F5' => 'Hartlepool',
            'F6' => 'Havering',
            'F7' => 'Herefordshire',
            'F8' => 'Hertford',
            'F9' => 'Hillingdon',
            'G1' => 'Hounslow',
            'G2' => 'Isle of Wight',
            'G3' => 'Islington',
            'G4' => 'Kensington and Chelsea',
            'G5' => 'Kent',
            'G6' => 'Kingston upon Hull, City of',
            'G7' => 'Kingston upon Thames',
            'G8' => 'Kirklees',
            'G9' => 'Knowsley',
            'H1' => 'Lambeth',
            'H2' => 'Lancashire',
            'H3' => 'Leeds',
            'H4' => 'Leicester',
            'H5' => 'Leicestershire',
            'H6' => 'Lewisham',
            'H7' => 'Lincolnshire',
            'H8' => 'Liverpool',
            'H9' => 'London, City of',
            'I1' => 'Luton',
            'I2' => 'Manchester',
            'I3' => 'Medway',
            'I4' => 'Merton',
            'I5' => 'Middlesbrough',
            'I6' => 'Milton Keynes',
            'I7' => 'Newcastle upon Tyne',
            'I8' => 'Newham',
            'I9' => 'Norfolk',
            'J1' => 'Northamptonshire',
            'J2' => 'North East Lincolnshire',
            'J3' => 'North Lincolnshire',
            'J4' => 'North Somerset',
            'J5' => 'North Tyneside',
            'J6' => 'Northumberland',
            'J7' => 'North Yorkshire',
            'J8' => 'Nottingham',
            'J9' => 'Nottinghamshire',
            'K1' => 'Oldham',
            'K2' => 'Oxfordshire',
            'K3' => 'Peterborough',
            'K4' => 'Plymouth',
            'K5' => 'Poole',
            'K6' => 'Portsmouth',
            'K7' => 'Reading',
            'K8' => 'Redbridge',
            'K9' => 'Redcar and Cleveland',
            'L1' => 'Richmond upon Thames',
            'L2' => 'Rochdale',
            'L3' => 'Rotherham',
            'L4' => 'Rutland',
            'L5' => 'Salford',
            'L6' => 'Shropshire',
            'L7' => 'Sandwell',
            'L8' => 'Sefton',
            'L9' => 'Sheffield',
            'M1' => 'Slough',
            'M2' => 'Solihull',
            'M3' => 'Somerset',
            'M4' => 'Southampton',
            'M5' => 'Southend-on-Sea',
            'M6' => 'South Gloucestershire',
            'M7' => 'South Tyneside',
            'M8' => 'Southwark',
            'M9' => 'Staffordshire',
            'N1' => 'St. Helens',
            'N2' => 'Stockport',
            'N3' => 'Stockton-on-Tees',
            'N4' => 'Stoke-on-Trent',
            'N5' => 'Suffolk',
            'N6' => 'Sunderland',
            'N7' => 'Surrey',
            'N8' => 'Sutton',
            'N9' => 'Swindon',
            'O1' => 'Tameside',
            'O2' => 'Telford and Wrekin',
            'O3' => 'Thurrock',
            'O4' => 'Torbay',
            'O5' => 'Tower Hamlets',
            'O6' => 'Trafford',
            'O7' => 'Wakefield',
            'O8' => 'Walsall',
            'O9' => 'Waltham Forest',
            'P1' => 'Wandsworth',
            'P2' => 'Warrington',
            'P3' => 'Warwickshire',
            'P4' => 'West Berkshire',
            'P5' => 'Westminster',
            'P6' => 'West Sussex',
            'P7' => 'Wigan',
            'P8' => 'Wiltshire',
            'P9' => 'Windsor and Maidenhead',
            'Q1' => 'Wirral',
            'Q2' => 'Wokingham',
            'Q3' => 'Wolverhampton',
            'Q4' => 'Worcestershire',
            'Q5' => 'York',
            'Q6' => 'Antrim',
            'Q7' => 'Ards',
            'Q8' => 'Armagh',
            'Q9' => 'Ballymena',
            'R1' => 'Ballymoney',
            'R2' => 'Banbridge',
            'R3' => 'Belfast',
            'R4' => 'Carrickfergus',
            'R5' => 'Castlereagh',
            'R6' => 'Coleraine',
            'R7' => 'Cookstown',
            'R8' => 'Craigavon',
            'R9' => 'Down',
            'S1' => 'Dungannon',
            'S2' => 'Fermanagh',
            'S3' => 'Larne',
            'S4' => 'Limavady',
            'S5' => 'Lisburn',
            'S6' => 'Derry',
            'S7' => 'Magherafelt',
            'S8' => 'Moyle',
            'S9' => 'Newry and Mourne',
            'T1' => 'Newtownabbey',
            'T2' => 'North Down',
            'T3' => 'Omagh',
            'T4' => 'Strabane',
            'T5' => 'Aberdeen City',
            'T6' => 'Aberdeenshire',
            'T7' => 'Angus',
            'T8' => 'Argyll and Bute',
            'T9' => 'Scottish Borders, The',
            'U1' => 'Clackmannanshire',
            'U2' => 'Dumfries and Galloway',
            'U3' => 'Dundee City',
            'U4' => 'East Ayrshire',
            'U5' => 'East Dunbartonshire',
            'U6' => 'East Lothian',
            'U7' => 'East Renfrewshire',
            'U8' => 'Edinburgh, City of',
            'U9' => 'Falkirk',
            'V1' => 'Fife',
            'V2' => 'Glasgow City',
            'V3' => 'Highland',
            'V4' => 'Inverclyde',
            'V5' => 'Midlothian',
            'V6' => 'Moray',
            'V7' => 'North Ayrshire',
            'V8' => 'North Lanarkshire',
            'V9' => 'Orkney',
            'W1' => 'Perth and Kinross',
            'W2' => 'Renfrewshire',
            'W3' => 'Shetland Islands',
            'W4' => 'South Ayrshire',
            'W5' => 'South Lanarkshire',
            'W6' => 'Stirling',
            'W7' => 'West Dunbartonshire',
            'W8' => 'Eilean Siar',
            'W9' => 'West Lothian',
            'X1' => 'Isle of Anglesey',
            'X2' => 'Blaenau Gwent',
            'X3' => 'Bridgend',
            'X4' => 'Caerphilly',
            'X5' => 'Cardiff',
            'X6' => 'Ceredigion',
            'X7' => 'Carmarthenshire',
            'X8' => 'Conwy',
            'X9' => 'Denbighshire',
            'Y1' => 'Flintshire',
            'Y2' => 'Gwynedd',
            'Y3' => 'Merthyr Tydfil',
            'Y4' => 'Monmouthshire',
            'Y5' => 'Neath Port Talbot',
            'Y6' => 'Newport',
            'Y7' => 'Pembrokeshire',
            'Y8' => 'Powys',
            'Y9' => 'Rhondda Cynon Taff',
            'Z1' => 'Swansea',
            'Z2' => 'Torfaen',
            'Z3' => 'Vale of Glamorgan, The',
            'Z4' => 'Wrexham'
  },
  'GD' => {
            '01' => 'Saint Andrew',
            '02' => 'Saint David',
            '03' => 'Saint George',
            '04' => 'Saint John',
            '05' => 'Saint Mark',
            '06' => 'Saint Patrick'
  },
  'GE' => {
            '01' => 'Abashis Raioni',
            '02' => 'Abkhazia',
            '03' => 'Adigenis Raioni',
            '04' => 'Ajaria',
            '05' => 'Akhalgoris Raioni',
            '06' => 'Akhalk\'alak\'is Raioni',
            '07' => 'Akhalts\'ikhis Raioni',
            '08' => 'Akhmetis Raioni',
            '09' => 'Ambrolauris Raioni',
            '10' => 'Aspindzis Raioni',
            '11' => 'Baghdat\'is Raioni',
            '12' => 'Bolnisis Raioni',
            '13' => 'Borjomis Raioni',
            '14' => 'Chiat\'ura',
            '15' => 'Ch\'khorotsqus Raioni',
            '16' => 'Ch\'okhatauris Raioni',
            '17' => 'Dedop\'listsqaros Raioni',
            '18' => 'Dmanisis Raioni',
            '19' => 'Dushet\'is Raioni',
            '20' => 'Gardabanis Raioni',
            '21' => 'Gori',
            '22' => 'Goris Raioni',
            '23' => 'Gurjaanis Raioni',
            '24' => 'Javis Raioni',
            '25' => 'K\'arelis Raioni',
            '26' => 'Kaspis Raioni',
            '27' => 'Kharagaulis Raioni',
            '28' => 'Khashuris Raioni',
            '29' => 'Khobis Raioni',
            '30' => 'Khonis Raioni',
            '31' => 'K\'ut\'aisi',
            '32' => 'Lagodekhis Raioni',
            '33' => 'Lanch\'khut\'is Raioni',
            '34' => 'Lentekhis Raioni',
            '35' => 'Marneulis Raioni',
            '36' => 'Martvilis Raioni',
            '37' => 'Mestiis Raioni',
            '38' => 'Mts\'khet\'is Raioni',
            '39' => 'Ninotsmindis Raioni',
            '40' => 'Onis Raioni',
            '41' => 'Ozurget\'is Raioni',
            '42' => 'P\'ot\'i',
            '43' => 'Qazbegis Raioni',
            '44' => 'Qvarlis Raioni',
            '45' => 'Rust\'avi',
            '46' => 'Sach\'kheris Raioni',
            '47' => 'Sagarejos Raioni',
            '48' => 'Samtrediis Raioni',
            '49' => 'Senakis Raioni',
            '50' => 'Sighnaghis Raioni',
            '51' => 'T\'bilisi',
            '52' => 'T\'elavis Raioni',
            '53' => 'T\'erjolis Raioni',
            '54' => 'T\'et\'ritsqaros Raioni',
            '55' => 'T\'ianet\'is Raioni',
            '56' => 'Tqibuli',
            '57' => 'Ts\'ageris Raioni',
            '58' => 'Tsalenjikhis Raioni',
            '59' => 'Tsalkis Raioni',
            '60' => 'Tsqaltubo',
            '61' => 'Vanis Raioni',
            '62' => 'Zestap\'onis Raioni',
            '63' => 'Zugdidi',
            '64' => 'Zugdidis Raioni'
  },
  'GH' => {
            '01' => 'Greater Accra',
            '02' => 'Ashanti',
            '03' => 'Brong-Ahafo',
            '04' => 'Central',
            '05' => 'Eastern',
            '06' => 'Northern',
            '08' => 'Volta',
            '09' => 'Western',
            '10' => 'Upper East',
            '11' => 'Upper West'
  },
  'GL' => {
            '01' => 'Nordgronland',
            '02' => 'Ostgronland',
            '03' => 'Vestgronland'
  },
  'GM' => {
            '01' => 'Banjul',
            '02' => 'Lower River',
            '03' => 'Central River',
            '04' => 'Upper River',
            '05' => 'Western',
            '07' => 'North Bank'
  },
  'GN' => {
            '01' => 'Beyla',
            '02' => 'Boffa',
            '03' => 'Boke',
            '04' => 'Conakry',
            '05' => 'Dabola',
            '06' => 'Dalaba',
            '07' => 'Dinguiraye',
            '09' => 'Faranah',
            '10' => 'Forecariah',
            '11' => 'Fria',
            '12' => 'Gaoual',
            '13' => 'Gueckedou',
            '15' => 'Kerouane',
            '16' => 'Kindia',
            '17' => 'Kissidougou',
            '18' => 'Koundara',
            '19' => 'Kouroussa',
            '21' => 'Macenta',
            '22' => 'Mali',
            '23' => 'Mamou',
            '25' => 'Pita',
            '27' => 'Telimele',
            '28' => 'Tougue',
            '29' => 'Yomou',
            '30' => 'Coyah',
            '31' => 'Dubreka',
            '32' => 'Kankan',
            '33' => 'Koubia',
            '34' => 'Labe',
            '35' => 'Lelouma',
            '36' => 'Lola',
            '37' => 'Mandiana',
            '38' => 'Nzerekore',
            '39' => 'Siguiri'
  },
  'GQ' => {
            '03' => 'Annobon',
            '04' => 'Bioko Norte',
            '05' => 'Bioko Sur',
            '06' => 'Centro Sur',
            '07' => 'Kie-Ntem',
            '08' => 'Litoral',
            '09' => 'Wele-Nzas'
  },
  'GR' => {
            '01' => 'Evros',
            '02' => 'Rodhopi',
            '03' => 'Xanthi',
            '04' => 'Drama',
            '05' => 'Serrai',
            '06' => 'Kilkis',
            '07' => 'Pella',
            '08' => 'Florina',
            '09' => 'Kastoria',
            '10' => 'Grevena',
            '11' => 'Kozani',
            '12' => 'Imathia',
            '13' => 'Thessaloniki',
            '14' => 'Kavala',
            '15' => 'Khalkidhiki',
            '16' => 'Pieria',
            '17' => 'Ioannina',
            '18' => 'Thesprotia',
            '19' => 'Preveza',
            '20' => 'Arta',
            '21' => 'Larisa',
            '22' => 'Trikala',
            '23' => 'Kardhitsa',
            '24' => 'Magnisia',
            '25' => 'Kerkira',
            '26' => 'Levkas',
            '27' => 'Kefallinia',
            '28' => 'Zakinthos',
            '29' => 'Fthiotis',
            '30' => 'Evritania',
            '31' => 'Aitolia kai Akarnania',
            '32' => 'Fokis',
            '33' => 'Voiotia',
            '34' => 'Evvoia',
            '35' => 'Attiki',
            '36' => 'Argolis',
            '37' => 'Korinthia',
            '38' => 'Akhaia',
            '39' => 'Ilia',
            '40' => 'Messinia',
            '41' => 'Arkadhia',
            '42' => 'Lakonia',
            '43' => 'Khania',
            '44' => 'Rethimni',
            '45' => 'Iraklion',
            '46' => 'Lasithi',
            '47' => 'Dhodhekanisos',
            '48' => 'Samos',
            '49' => 'Kikladhes',
            '50' => 'Khios',
            '51' => 'Lesvos'
  },
  'GT' => {
            '01' => 'Alta Verapaz',
            '02' => 'Baja Verapaz',
            '03' => 'Chimaltenango',
            '04' => 'Chiquimula',
            '05' => 'El Progreso',
            '06' => 'Escuintla',
            '07' => 'Guatemala',
            '08' => 'Huehuetenango',
            '09' => 'Izabal',
            '10' => 'Jalapa',
            '11' => 'Jutiapa',
            '12' => 'Peten',
            '13' => 'Quetzaltenango',
            '14' => 'Quiche',
            '15' => 'Retalhuleu',
            '16' => 'Sacatepequez',
            '17' => 'San Marcos',
            '18' => 'Santa Rosa',
            '19' => 'Solola',
            '20' => 'Suchitepequez',
            '21' => 'Totonicapan',
            '22' => 'Zacapa'
  },
  'GW' => {
            '01' => 'Bafata',
            '02' => 'Quinara',
            '04' => 'Oio',
            '05' => 'Bolama',
            '06' => 'Cacheu',
            '07' => 'Tombali',
            '10' => 'Gabu',
            '11' => 'Bissau',
            '12' => 'Biombo'
  },
  'GY' => {
            '10' => 'Barima-Waini',
            '11' => 'Cuyuni-Mazaruni',
            '12' => 'Demerara-Mahaica',
            '13' => 'East Berbice-Corentyne',
            '14' => 'Essequibo Islands-West Demerara',
            '15' => 'Mahaica-Berbice',
            '16' => 'Pomeroon-Supenaam',
            '17' => 'Potaro-Siparuni',
            '18' => 'Upper Demerara-Berbice',
            '19' => 'Upper Takutu-Upper Essequibo'
  },
  'HN' => {
            '01' => 'Atlantida',
            '02' => 'Choluteca',
            '03' => 'Colon',
            '04' => 'Comayagua',
            '05' => 'Copan',
            '06' => 'Cortes',
            '07' => 'El Paraiso',
            '08' => 'Francisco Morazan',
            '09' => 'Gracias a Dios',
            '10' => 'Intibuca',
            '11' => 'Islas de la Bahia',
            '12' => 'La Paz',
            '13' => 'Lempira',
            '14' => 'Ocotepeque',
            '15' => 'Olancho',
            '16' => 'Santa Barbara',
            '17' => 'Valle',
            '18' => 'Yoro'
  },
  'HR' => {
            '01' => 'Bjelovarsko-Bilogorska',
            '02' => 'Brodsko-Posavska',
            '03' => 'Dubrovacko-Neretvanska',
            '04' => 'Istarska',
            '05' => 'Karlovacka',
            '06' => 'Koprivnicko-Krizevacka',
            '07' => 'Krapinsko-Zagorska',
            '08' => 'Licko-Senjska',
            '09' => 'Medimurska',
            '10' => 'Osjecko-Baranjska',
            '11' => 'Pozesko-Slavonska',
            '12' => 'Primorsko-Goranska',
            '13' => 'Sibensko-Kninska',
            '14' => 'Sisacko-Moslavacka',
            '15' => 'Splitsko-Dalmatinska',
            '16' => 'Varazdinska',
            '17' => 'Viroviticko-Podravska',
            '18' => 'Vukovarsko-Srijemska',
            '19' => 'Zadarska',
            '20' => 'Zagrebacka',
            '21' => 'Grad Zagreb'
  },
  'HT' => {
            '03' => 'Nord-Ouest',
            '06' => 'Artibonite',
            '07' => 'Centre',
            '09' => 'Nord',
            '10' => 'Nord-Est',
            '11' => 'Ouest',
            '12' => 'Sud',
            '13' => 'Sud-Est',
            '14' => 'Grand\' Anse',
            '15' => 'Nippes'
  },
  'HU' => {
            '01' => 'Bacs-Kiskun',
            '02' => 'Baranya',
            '03' => 'Bekes',
            '04' => 'Borsod-Abauj-Zemplen',
            '05' => 'Budapest',
            '06' => 'Csongrad',
            '07' => 'Debrecen',
            '08' => 'Fejer',
            '09' => 'Gyor-Moson-Sopron',
            '10' => 'Hajdu-Bihar',
            '11' => 'Heves',
            '12' => 'Komarom-Esztergom',
            '13' => 'Miskolc',
            '14' => 'Nograd',
            '15' => 'Pecs',
            '16' => 'Pest',
            '17' => 'Somogy',
            '18' => 'Szabolcs-Szatmar-Bereg',
            '19' => 'Szeged',
            '20' => 'Jasz-Nagykun-Szolnok',
            '21' => 'Tolna',
            '22' => 'Vas',
            '23' => 'Veszprem',
            '24' => 'Zala',
            '25' => 'Gyor',
            '26' => 'Bekescsaba',
            '27' => 'Dunaujvaros',
            '28' => 'Eger',
            '29' => 'Hodmezovasarhely',
            '30' => 'Kaposvar',
            '31' => 'Kecskemet',
            '32' => 'Nagykanizsa',
            '33' => 'Nyiregyhaza',
            '34' => 'Sopron',
            '35' => 'Szekesfehervar',
            '36' => 'Szolnok',
            '37' => 'Szombathely',
            '38' => 'Tatabanya',
            '39' => 'Veszprem',
            '40' => 'Zalaegerszeg',
            '41' => 'Salgotarjan',
            '42' => 'Szekszard',
            '43' => 'Erd'
  },
  'ID' => {
            '01' => 'Aceh',
            '02' => 'Bali',
            '03' => 'Bengkulu',
            '04' => 'Jakarta Raya',
            '05' => 'Jambi',
            '06' => 'Jawa Barat',
            '07' => 'Jawa Tengah',
            '08' => 'Jawa Timur',
            '09' => 'Papua',
            '10' => 'Yogyakarta',
            '11' => 'Kalimantan Barat',
            '12' => 'Kalimantan Selatan',
            '13' => 'Kalimantan Tengah',
            '14' => 'Kalimantan Timur',
            '15' => 'Lampung',
            '16' => 'Maluku',
            '17' => 'Nusa Tenggara Barat',
            '18' => 'Nusa Tenggara Timur',
            '19' => 'Riau',
            '20' => 'Sulawesi Selatan',
            '21' => 'Sulawesi Tengah',
            '22' => 'Sulawesi Tenggara',
            '23' => 'Sulawesi Utara',
            '24' => 'Sumatera Barat',
            '25' => 'Sumatera Selatan',
            '26' => 'Sumatera Utara',
            '28' => 'Maluku',
            '29' => 'Maluku Utara',
            '30' => 'Jawa Barat',
            '31' => 'Sulawesi Utara',
            '32' => 'Sumatera Selatan',
            '33' => 'Banten',
            '34' => 'Gorontalo',
            '35' => 'Kepulauan Bangka Belitung',
            '36' => 'Papua',
            '37' => 'Riau',
            '38' => 'Sulawesi Selatan',
            '39' => 'Irian Jaya Barat',
            '40' => 'Kepulauan Riau',
            '41' => 'Sulawesi Barat'
  },
  'IE' => {
            '01' => 'Carlow',
            '02' => 'Cavan',
            '03' => 'Clare',
            '04' => 'Cork',
            '06' => 'Donegal',
            '07' => 'Dublin',
            '10' => 'Galway',
            '11' => 'Kerry',
            '12' => 'Kildare',
            '13' => 'Kilkenny',
            '14' => 'Leitrim',
            '15' => 'Laois',
            '16' => 'Limerick',
            '18' => 'Longford',
            '19' => 'Louth',
            '20' => 'Mayo',
            '21' => 'Meath',
            '22' => 'Monaghan',
            '23' => 'Offaly',
            '24' => 'Roscommon',
            '25' => 'Sligo',
            '26' => 'Tipperary',
            '27' => 'Waterford',
            '29' => 'Westmeath',
            '30' => 'Wexford',
            '31' => 'Wicklow'
  },
  'IL' => {
            '01' => 'HaDarom',
            '02' => 'HaMerkaz',
            '03' => 'HaZafon',
            '04' => 'Hefa',
            '05' => 'Tel Aviv',
            '06' => 'Yerushalayim'
  },
  'IN' => {
            '01' => 'Andaman and Nicobar Islands',
            '02' => 'Andhra Pradesh',
            '03' => 'Assam',
            '05' => 'Chandigarh',
            '06' => 'Dadra and Nagar Haveli',
            '07' => 'Delhi',
            '09' => 'Gujarat',
            '10' => 'Haryana',
            '11' => 'Himachal Pradesh',
            '12' => 'Jammu and Kashmir',
            '13' => 'Kerala',
            '14' => 'Lakshadweep',
            '16' => 'Maharashtra',
            '17' => 'Manipur',
            '18' => 'Meghalaya',
            '19' => 'Karnataka',
            '20' => 'Nagaland',
            '21' => 'Orissa',
            '22' => 'Puducherry',
            '23' => 'Punjab',
            '24' => 'Rajasthan',
            '25' => 'Tamil Nadu',
            '26' => 'Tripura',
            '28' => 'West Bengal',
            '29' => 'Sikkim',
            '30' => 'Arunachal Pradesh',
            '31' => 'Mizoram',
            '32' => 'Daman and Diu',
            '33' => 'Goa',
            '34' => 'Bihar',
            '35' => 'Madhya Pradesh',
            '36' => 'Uttar Pradesh',
            '37' => 'Chhattisgarh',
            '38' => 'Jharkhand',
            '39' => 'Uttarakhand'
  },
  'IQ' => {
            '01' => 'Al Anbar',
            '02' => 'Al Basrah',
            '03' => 'Al Muthanna',
            '04' => 'Al Qadisiyah',
            '05' => 'As Sulaymaniyah',
            '06' => 'Babil',
            '07' => 'Baghdad',
            '08' => 'Dahuk',
            '09' => 'Dhi Qar',
            '10' => 'Diyala',
            '11' => 'Arbil',
            '12' => 'Karbala\'',
            '13' => 'At Ta\'mim',
            '14' => 'Maysan',
            '15' => 'Ninawa',
            '16' => 'Wasit',
            '17' => 'An Najaf',
            '18' => 'Salah ad Din'
  },
  'IR' => {
            '01' => 'Azarbayjan-e Bakhtari',
            '03' => 'Chahar Mahall va Bakhtiari',
            '04' => 'Sistan va Baluchestan',
            '05' => 'Kohkiluyeh va Buyer Ahmadi',
            '07' => 'Fars',
            '08' => 'Gilan',
            '09' => 'Hamadan',
            '10' => 'Ilam',
            '11' => 'Hormozgan',
            '12' => 'Kerman',
            '13' => 'Bakhtaran',
            '15' => 'Khuzestan',
            '16' => 'Kordestan',
            '17' => 'Mazandaran',
            '18' => 'Semnan Province',
            '19' => 'Markazi',
            '21' => 'Zanjan',
            '22' => 'Bushehr',
            '23' => 'Lorestan',
            '24' => 'Markazi',
            '25' => 'Semnan',
            '26' => 'Tehran',
            '27' => 'Zanjan',
            '28' => 'Esfahan',
            '29' => 'Kerman',
            '30' => 'Khorasan',
            '31' => 'Yazd',
            '32' => 'Ardabil',
            '33' => 'East Azarbaijan',
            '34' => 'Markazi',
            '35' => 'Mazandaran',
            '36' => 'Zanjan',
            '37' => 'Golestan',
            '38' => 'Qazvin',
            '39' => 'Qom',
            '40' => 'Yazd',
            '41' => 'Khorasan-e Janubi',
            '42' => 'Khorasan-e Razavi',
            '43' => 'Khorasan-e Shemali'
  },
  'IS' => {
            '03' => 'Arnessysla',
            '05' => 'Austur-Hunavatnssysla',
            '06' => 'Austur-Skaftafellssysla',
            '07' => 'Borgarfjardarsysla',
            '09' => 'Eyjafjardarsysla',
            '10' => 'Gullbringusysla',
            '15' => 'Kjosarsysla',
            '17' => 'Myrasysla',
            '20' => 'Nordur-Mulasysla',
            '21' => 'Nordur-Tingeyjarsysla',
            '23' => 'Rangarvallasysla',
            '28' => 'Skagafjardarsysla',
            '29' => 'Snafellsnes- og Hnappadalssysla',
            '30' => 'Strandasysla',
            '31' => 'Sudur-Mulasysla',
            '32' => 'Sudur-Tingeyjarsysla',
            '34' => 'Vestur-Bardastrandarsysla',
            '35' => 'Vestur-Hunavatnssysla',
            '36' => 'Vestur-Isafjardarsysla',
            '37' => 'Vestur-Skaftafellssysla',
            '40' => 'Norourland Eystra',
            '41' => 'Norourland Vestra',
            '42' => 'Suourland',
            '43' => 'Suournes',
            '44' => 'Vestfiroir',
            '45' => 'Vesturland'
  },
  'IT' => {
            '01' => 'Abruzzi',
            '02' => 'Basilicata',
            '03' => 'Calabria',
            '04' => 'Campania',
            '05' => 'Emilia-Romagna',
            '06' => 'Friuli-Venezia Giulia',
            '07' => 'Lazio',
            '08' => 'Liguria',
            '09' => 'Lombardia',
            '10' => 'Marche',
            '11' => 'Molise',
            '12' => 'Piemonte',
            '13' => 'Puglia',
            '14' => 'Sardegna',
            '15' => 'Sicilia',
            '16' => 'Toscana',
            '17' => 'Trentino-Alto Adige',
            '18' => 'Umbria',
            '19' => 'Valle d\'Aosta',
            '20' => 'Veneto'
  },
  'JM' => {
            '01' => 'Clarendon',
            '02' => 'Hanover',
            '04' => 'Manchester',
            '07' => 'Portland',
            '08' => 'Saint Andrew',
            '09' => 'Saint Ann',
            '10' => 'Saint Catherine',
            '11' => 'Saint Elizabeth',
            '12' => 'Saint James',
            '13' => 'Saint Mary',
            '14' => 'Saint Thomas',
            '15' => 'Trelawny',
            '16' => 'Westmoreland',
            '17' => 'Kingston'
  },
  'JO' => {
            '02' => 'Al Balqa\'',
            '07' => 'Ma',
            '09' => 'Al Karak',
            '10' => 'Al Mafraq',
            '11' => 'Amman Governorate',
            '12' => 'At Tafilah',
            '13' => 'Az Zarqa',
            '14' => 'Irbid',
            '16' => 'Amman'
  },
  'JP' => {
            '01' => 'Aichi',
            '02' => 'Akita',
            '03' => 'Aomori',
            '04' => 'Chiba',
            '05' => 'Ehime',
            '06' => 'Fukui',
            '07' => 'Fukuoka',
            '08' => 'Fukushima',
            '09' => 'Gifu',
            '10' => 'Gumma',
            '11' => 'Hiroshima',
            '12' => 'Hokkaido',
            '13' => 'Hyogo',
            '14' => 'Ibaraki',
            '15' => 'Ishikawa',
            '16' => 'Iwate',
            '17' => 'Kagawa',
            '18' => 'Kagoshima',
            '19' => 'Kanagawa',
            '20' => 'Kochi',
            '21' => 'Kumamoto',
            '22' => 'Kyoto',
            '23' => 'Mie',
            '24' => 'Miyagi',
            '25' => 'Miyazaki',
            '26' => 'Nagano',
            '27' => 'Nagasaki',
            '28' => 'Nara',
            '29' => 'Niigata',
            '30' => 'Oita',
            '31' => 'Okayama',
            '32' => 'Osaka',
            '33' => 'Saga',
            '34' => 'Saitama',
            '35' => 'Shiga',
            '36' => 'Shimane',
            '37' => 'Shizuoka',
            '38' => 'Tochigi',
            '39' => 'Tokushima',
            '40' => 'Tokyo',
            '41' => 'Tottori',
            '42' => 'Toyama',
            '43' => 'Wakayama',
            '44' => 'Yamagata',
            '45' => 'Yamaguchi',
            '46' => 'Yamanashi',
            '47' => 'Okinawa'
  },
  'KE' => {
            '01' => 'Central',
            '02' => 'Coast',
            '03' => 'Eastern',
            '05' => 'Nairobi Area',
            '06' => 'North-Eastern',
            '07' => 'Nyanza',
            '08' => 'Rift Valley',
            '09' => 'Western'
  },
  'KG' => {
            '01' => 'Bishkek',
            '02' => 'Chuy',
            '03' => 'Jalal-Abad',
            '04' => 'Naryn',
            '05' => 'Osh',
            '06' => 'Talas',
            '07' => 'Ysyk-Kol',
            '08' => 'Osh',
            '09' => 'Batken'
  },
  'KH' => {
            '01' => 'Batdambang',
            '02' => 'Kampong Cham',
            '03' => 'Kampong Chhnang',
            '04' => 'Kampong Speu',
            '05' => 'Kampong Thum',
            '06' => 'Kampot',
            '07' => 'Kandal',
            '08' => 'Koh Kong',
            '09' => 'Kracheh',
            '10' => 'Mondulkiri',
            '11' => 'Phnum Penh',
            '12' => 'Pursat',
            '13' => 'Preah Vihear',
            '14' => 'Prey Veng',
            '15' => 'Ratanakiri Kiri',
            '16' => 'Siem Reap',
            '17' => 'Stung Treng',
            '18' => 'Svay Rieng',
            '19' => 'Takeo',
            '25' => 'Banteay Meanchey',
            '29' => 'Batdambang',
            '30' => 'Pailin'
  },
  'KI' => {
            '01' => 'Gilbert Islands',
            '02' => 'Line Islands',
            '03' => 'Phoenix Islands'
  },
  'KM' => {
            '01' => 'Anjouan',
            '02' => 'Grande Comore',
            '03' => 'Moheli'
  },
  'KN' => {
            '01' => 'Christ Church Nichola Town',
            '02' => 'Saint Anne Sandy Point',
            '03' => 'Saint George Basseterre',
            '04' => 'Saint George Gingerland',
            '05' => 'Saint James Windward',
            '06' => 'Saint John Capisterre',
            '07' => 'Saint John Figtree',
            '08' => 'Saint Mary Cayon',
            '09' => 'Saint Paul Capisterre',
            '10' => 'Saint Paul Charlestown',
            '11' => 'Saint Peter Basseterre',
            '12' => 'Saint Thomas Lowland',
            '13' => 'Saint Thomas Middle Island',
            '15' => 'Trinity Palmetto Point'
  },
  'KP' => {
            '01' => 'Chagang-do',
            '03' => 'Hamgyong-namdo',
            '06' => 'Hwanghae-namdo',
            '07' => 'Hwanghae-bukto',
            '08' => 'Kaesong-si',
            '09' => 'Kangwon-do',
            '11' => 'P\'yongan-bukto',
            '12' => 'P\'yongyang-si',
            '13' => 'Yanggang-do',
            '14' => 'Namp\'o-si',
            '15' => 'P\'yongan-namdo',
            '17' => 'Hamgyong-bukto',
            '18' => 'Najin Sonbong-si'
  },
  'KR' => {
            '01' => 'Cheju-do',
            '03' => 'Cholla-bukto',
            '05' => 'Ch\'ungch\'ong-bukto',
            '06' => 'Kangwon-do',
            '10' => 'Pusan-jikhalsi',
            '11' => 'Seoul-t\'ukpyolsi',
            '12' => 'Inch\'on-jikhalsi',
            '13' => 'Kyonggi-do',
            '14' => 'Kyongsang-bukto',
            '15' => 'Taegu-jikhalsi',
            '16' => 'Cholla-namdo',
            '17' => 'Ch\'ungch\'ong-namdo',
            '18' => 'Kwangju-jikhalsi',
            '19' => 'Taejon-jikhalsi',
            '20' => 'Kyongsang-namdo',
            '21' => 'Ulsan-gwangyoksi'
  },
  'KW' => {
            '01' => 'Al Ahmadi',
            '02' => 'Al Kuwayt',
            '05' => 'Al Jahra',
            '07' => 'Al Farwaniyah',
            '08' => 'Hawalli',
            '09' => 'Mubarak al Kabir'
  },
  'KY' => {
            '01' => 'Creek',
            '02' => 'Eastern',
            '03' => 'Midland',
            '04' => 'South Town',
            '05' => 'Spot Bay',
            '06' => 'Stake Bay',
            '07' => 'West End',
            '08' => 'Western'
  },
  'KZ' => {
            '01' => 'Almaty',
            '02' => 'Almaty City',
            '03' => 'Aqmola',
            '04' => 'Aqtobe',
            '05' => 'Astana',
            '06' => 'Atyrau',
            '07' => 'West Kazakhstan',
            '08' => 'Bayqonyr',
            '09' => 'Mangghystau',
            '10' => 'South Kazakhstan',
            '11' => 'Pavlodar',
            '12' => 'Qaraghandy',
            '13' => 'Qostanay',
            '14' => 'Qyzylorda',
            '15' => 'East Kazakhstan',
            '16' => 'North Kazakhstan',
            '17' => 'Zhambyl'
  },
  'LA' => {
            '01' => 'Attapu',
            '02' => 'Champasak',
            '03' => 'Houaphan',
            '04' => 'Khammouan',
            '05' => 'Louang Namtha',
            '07' => 'Oudomxai',
            '08' => 'Phongsali',
            '09' => 'Saravan',
            '10' => 'Savannakhet',
            '11' => 'Vientiane',
            '13' => 'Xaignabouri',
            '14' => 'Xiangkhoang',
            '17' => 'Louangphrabang'
  },
  'LB' => {
            '01' => 'Beqaa',
            '02' => 'Al Janub',
            '03' => 'Liban-Nord',
            '04' => 'Beyrouth',
            '05' => 'Mont-Liban',
            '06' => 'Liban-Sud',
            '07' => 'Nabatiye',
            '08' => 'Beqaa',
            '09' => 'Liban-Nord',
            '10' => 'Aakk,r',
            '11' => 'Baalbek-Hermel'
  },
  'LC' => {
            '01' => 'Anse-la-Raye',
            '02' => 'Dauphin',
            '03' => 'Castries',
            '04' => 'Choiseul',
            '05' => 'Dennery',
            '06' => 'Gros-Islet',
            '07' => 'Laborie',
            '08' => 'Micoud',
            '09' => 'Soufriere',
            '10' => 'Vieux-Fort',
            '11' => 'Praslin'
  },
  'LI' => {
            '01' => 'Balzers',
            '02' => 'Eschen',
            '03' => 'Gamprin',
            '04' => 'Mauren',
            '05' => 'Planken',
            '06' => 'Ruggell',
            '07' => 'Schaan',
            '08' => 'Schellenberg',
            '09' => 'Triesen',
            '10' => 'Triesenberg',
            '11' => 'Vaduz',
            '21' => 'Gbarpolu',
            '22' => 'River Gee'
  },
  'LK' => {
            '01' => 'Amparai',
            '02' => 'Anuradhapura',
            '03' => 'Badulla',
            '04' => 'Batticaloa',
            '06' => 'Galle',
            '07' => 'Hambantota',
            '09' => 'Kalutara',
            '10' => 'Kandy',
            '11' => 'Kegalla',
            '12' => 'Kurunegala',
            '14' => 'Matale',
            '15' => 'Matara',
            '16' => 'Moneragala',
            '17' => 'Nuwara Eliya',
            '18' => 'Polonnaruwa',
            '19' => 'Puttalam',
            '20' => 'Ratnapura',
            '21' => 'Trincomalee',
            '23' => 'Colombo',
            '24' => 'Gampaha',
            '25' => 'Jaffna',
            '26' => 'Mannar',
            '27' => 'Mullaittivu',
            '28' => 'Vavuniya',
            '29' => 'Central',
            '30' => 'North Central',
            '31' => 'Northern',
            '32' => 'North Western',
            '33' => 'Sabaragamuwa',
            '34' => 'Southern',
            '35' => 'Uva',
            '36' => 'Western'
  },
  'LR' => {
            '01' => 'Bong',
            '04' => 'Grand Cape Mount',
            '05' => 'Lofa',
            '06' => 'Maryland',
            '07' => 'Monrovia',
            '09' => 'Nimba',
            '10' => 'Sino',
            '11' => 'Grand Bassa',
            '12' => 'Grand Cape Mount',
            '13' => 'Maryland',
            '14' => 'Montserrado',
            '17' => 'Margibi',
            '18' => 'River Cess',
            '19' => 'Grand Gedeh',
            '20' => 'Lofa',
            '21' => 'Gbarpolu',
            '22' => 'River Gee'
  },
  'LS' => {
            '10' => 'Berea',
            '11' => 'Butha-Buthe',
            '12' => 'Leribe',
            '13' => 'Mafeteng',
            '14' => 'Maseru',
            '15' => 'Mohales Hoek',
            '16' => 'Mokhotlong',
            '17' => 'Qachas Nek',
            '18' => 'Quthing',
            '19' => 'Thaba-Tseka'
  },
  'LT' => {
            '56' => 'Alytaus Apskritis',
            '57' => 'Kauno Apskritis',
            '58' => 'Klaipedos Apskritis',
            '59' => 'Marijampoles Apskritis',
            '60' => 'Panevezio Apskritis',
            '61' => 'Siauliu Apskritis',
            '62' => 'Taurages Apskritis',
            '63' => 'Telsiu Apskritis',
            '64' => 'Utenos Apskritis',
            '65' => 'Vilniaus Apskritis'
  },
  'LU' => {
            '01' => 'Diekirch',
            '02' => 'Grevenmacher',
            '03' => 'Luxembourg'
  },
  'LV' => {
            '01' => 'Aizkraukles',
            '02' => 'Aluksnes',
            '03' => 'Balvu',
            '04' => 'Bauskas',
            '05' => 'Cesu',
            '06' => 'Daugavpils',
            '07' => 'Daugavpils',
            '08' => 'Dobeles',
            '09' => 'Gulbenes',
            '10' => 'Jekabpils',
            '11' => 'Jelgava',
            '12' => 'Jelgavas',
            '13' => 'Jurmala',
            '14' => 'Kraslavas',
            '15' => 'Kuldigas',
            '16' => 'Liepaja',
            '17' => 'Liepajas',
            '18' => 'Limbazu',
            '19' => 'Ludzas',
            '20' => 'Madonas',
            '21' => 'Ogres',
            '22' => 'Preilu',
            '23' => 'Rezekne',
            '24' => 'Rezeknes',
            '25' => 'Riga',
            '26' => 'Rigas',
            '27' => 'Saldus',
            '28' => 'Talsu',
            '29' => 'Tukuma',
            '30' => 'Valkas',
            '31' => 'Valmieras',
            '32' => 'Ventspils',
            '33' => 'Ventspils'
  },
  'LY' => {
            '03' => 'Al Aziziyah',
            '05' => 'Al Jufrah',
            '08' => 'Al Kufrah',
            '13' => 'Ash Shati\'',
            '30' => 'Murzuq',
            '34' => 'Sabha',
            '41' => 'Tarhunah',
            '42' => 'Tubruq',
            '45' => 'Zlitan',
            '47' => 'Ajdabiya',
            '48' => 'Al Fatih',
            '49' => 'Al Jabal al Akhdar',
            '50' => 'Al Khums',
            '51' => 'An Nuqat al Khams',
            '52' => 'Awbari',
            '53' => 'Az Zawiyah',
            '54' => 'Banghazi',
            '55' => 'Darnah',
            '56' => 'Ghadamis',
            '57' => 'Gharyan',
            '58' => 'Misratah',
            '59' => 'Sawfajjin',
            '60' => 'Surt',
            '61' => 'Tarabulus',
            '62' => 'Yafran'
  },
  'MA' => {
            '45' => 'Grand Casablanca',
            '46' => 'Fes-Boulemane',
            '47' => 'Marrakech-Tensift-Al Haouz',
            '48' => 'Meknes-Tafilalet',
            '49' => 'Rabat-Sale-Zemmour-Zaer',
            '50' => 'Chaouia-Ouardigha',
            '51' => 'Doukkala-Abda',
            '52' => 'Gharb-Chrarda-Beni Hssen',
            '53' => 'Guelmim-Es Smara',
            '54' => 'Oriental',
            '55' => 'Souss-Massa-Dr,a',
            '56' => 'Tadla-Azilal',
            '57' => 'Tanger-Tetouan',
            '58' => 'Taza-Al Hoceima-Taounate',
            '59' => 'La,youne-Boujdour-Sakia El Hamra'
  },
  'MC' => {
            '01' => 'La Condamine',
            '02' => 'Monaco',
            '03' => 'Monte-Carlo'
  },
  'MD' => {
            '51' => 'Gagauzia',
            '57' => 'Chisinau',
            '58' => 'Stinga Nistrului',
            '59' => 'Anenii Noi',
            '60' => 'Balti',
            '61' => 'Basarabeasca',
            '62' => 'Bender',
            '63' => 'Briceni',
            '64' => 'Cahul',
            '65' => 'Cantemir',
            '66' => 'Calarasi',
            '67' => 'Causeni',
            '68' => 'Cimislia',
            '69' => 'Criuleni',
            '70' => 'Donduseni',
            '71' => 'Drochia',
            '72' => 'Dubasari',
            '73' => 'Edinet',
            '74' => 'Falesti',
            '75' => 'Floresti',
            '76' => 'Glodeni',
            '77' => 'Hincesti',
            '78' => 'Ialoveni',
            '79' => 'Leova',
            '80' => 'Nisporeni',
            '81' => 'Ocnita',
            '83' => 'Rezina',
            '84' => 'Riscani',
            '85' => 'Singerei',
            '86' => 'Soldanesti',
            '87' => 'Soroca',
            '88' => 'Stefan-Voda',
            '89' => 'Straseni',
            '90' => 'Taraclia',
            '91' => 'Telenesti',
            '92' => 'Ungheni'
  },
  'MG' => {
            '01' => 'Antsiranana',
            '02' => 'Fianarantsoa',
            '03' => 'Mahajanga',
            '04' => 'Toamasina',
            '05' => 'Antananarivo',
            '06' => 'Toliara'
  },
  'MK' => {
            '01' => 'Aracinovo',
            '02' => 'Bac',
            '03' => 'Belcista',
            '04' => 'Berovo',
            '05' => 'Bistrica',
            '06' => 'Bitola',
            '07' => 'Blatec',
            '08' => 'Bogdanci',
            '09' => 'Bogomila',
            '10' => 'Bogovinje',
            '11' => 'Bosilovo',
            '12' => 'Brvenica',
            '13' => 'Cair',
            '14' => 'Capari',
            '15' => 'Caska',
            '16' => 'Cegrane',
            '17' => 'Centar',
            '18' => 'Centar Zupa',
            '19' => 'Cesinovo',
            '20' => 'Cucer-Sandevo',
            '21' => 'Debar',
            '22' => 'Delcevo',
            '23' => 'Delogozdi',
            '24' => 'Demir Hisar',
            '25' => 'Demir Kapija',
            '26' => 'Dobrusevo',
            '27' => 'Dolna Banjica',
            '28' => 'Dolneni',
            '29' => 'Dorce Petrov',
            '30' => 'Drugovo',
            '31' => 'Dzepciste',
            '32' => 'Gazi Baba',
            '33' => 'Gevgelija',
            '34' => 'Gostivar',
            '35' => 'Gradsko',
            '36' => 'Ilinden',
            '37' => 'Izvor',
            '38' => 'Jegunovce',
            '39' => 'Kamenjane',
            '40' => 'Karbinci',
            '41' => 'Karpos',
            '42' => 'Kavadarci',
            '43' => 'Kicevo',
            '44' => 'Kisela Voda',
            '45' => 'Klecevce',
            '46' => 'Kocani',
            '47' => 'Konce',
            '48' => 'Kondovo',
            '49' => 'Konopiste',
            '50' => 'Kosel',
            '51' => 'Kratovo',
            '52' => 'Kriva Palanka',
            '53' => 'Krivogastani',
            '54' => 'Krusevo',
            '55' => 'Kuklis',
            '56' => 'Kukurecani',
            '57' => 'Kumanovo',
            '58' => 'Labunista',
            '59' => 'Lipkovo',
            '60' => 'Lozovo',
            '61' => 'Lukovo',
            '62' => 'Makedonska Kamenica',
            '63' => 'Makedonski Brod',
            '64' => 'Mavrovi Anovi',
            '65' => 'Meseista',
            '66' => 'Miravci',
            '67' => 'Mogila',
            '68' => 'Murtino',
            '69' => 'Negotino',
            '70' => 'Negotino-Polosko',
            '71' => 'Novaci',
            '72' => 'Novo Selo',
            '73' => 'Oblesevo',
            '74' => 'Ohrid',
            '75' => 'Orasac',
            '76' => 'Orizari',
            '77' => 'Oslomej',
            '78' => 'Pehcevo',
            '79' => 'Petrovec',
            '80' => 'Plasnica',
            '81' => 'Podares',
            '82' => 'Prilep',
            '83' => 'Probistip',
            '84' => 'Radovis',
            '85' => 'Rankovce',
            '86' => 'Resen',
            '87' => 'Rosoman',
            '88' => 'Rostusa',
            '89' => 'Samokov',
            '90' => 'Saraj',
            '91' => 'Sipkovica',
            '92' => 'Sopiste',
            '93' => 'Sopotnica',
            '94' => 'Srbinovo',
            '95' => 'Staravina',
            '96' => 'Star Dojran',
            '97' => 'Staro Nagoricane',
            '98' => 'Stip',
            '99' => 'Struga',
            'A1' => 'Strumica',
            'A2' => 'Studenicani',
            'A3' => 'Suto Orizari',
            'A4' => 'Sveti Nikole',
            'A5' => 'Tearce',
            'A6' => 'Tetovo',
            'A7' => 'Topolcani',
            'A8' => 'Valandovo',
            'A9' => 'Vasilevo',
            'B1' => 'Veles',
            'B2' => 'Velesta',
            'B3' => 'Vevcani',
            'B4' => 'Vinica',
            'B5' => 'Vitoliste',
            'B6' => 'Vranestica',
            'B7' => 'Vrapciste',
            'B8' => 'Vratnica',
            'B9' => 'Vrutok',
            'C1' => 'Zajas',
            'C2' => 'Zelenikovo',
            'C3' => 'Zelino',
            'C4' => 'Zitose',
            'C5' => 'Zletovo',
            'C6' => 'Zrnovci'
  },
  'ML' => {
            '01' => 'Bamako',
            '03' => 'Kayes',
            '04' => 'Mopti',
            '05' => 'Segou',
            '06' => 'Sikasso',
            '07' => 'Koulikoro',
            '08' => 'Tombouctou',
            '09' => 'Gao',
            '10' => 'Kidal'
  },
  'MM' => {
            '01' => 'Rakhine State',
            '02' => 'Chin State',
            '03' => 'Irrawaddy',
            '04' => 'Kachin State',
            '05' => 'Karan State',
            '06' => 'Kayah State',
            '07' => 'Magwe',
            '08' => 'Mandalay',
            '09' => 'Pegu',
            '10' => 'Sagaing',
            '11' => 'Shan State',
            '12' => 'Tenasserim',
            '13' => 'Mon State',
            '14' => 'Rangoon',
            '17' => 'Yangon'
  },
  'MN' => {
            '01' => 'Arhangay',
            '02' => 'Bayanhongor',
            '03' => 'Bayan-Olgiy',
            '05' => 'Darhan',
            '06' => 'Dornod',
            '07' => 'Dornogovi',
            '08' => 'Dundgovi',
            '09' => 'Dzavhan',
            '10' => 'Govi-Altay',
            '11' => 'Hentiy',
            '12' => 'Hovd',
            '13' => 'Hovsgol',
            '14' => 'Omnogovi',
            '15' => 'Ovorhangay',
            '16' => 'Selenge',
            '17' => 'Suhbaatar',
            '18' => 'Tov',
            '19' => 'Uvs',
            '20' => 'Ulaanbaatar',
            '21' => 'Bulgan',
            '22' => 'Erdenet',
            '23' => 'Darhan-Uul',
            '24' => 'Govisumber',
            '25' => 'Orhon'
  },
  'MO' => {
            '01' => 'Ilhas',
            '02' => 'Macau'
  },
  'MR' => {
            '01' => 'Hodh Ech Chargui',
            '02' => 'Hodh El Gharbi',
            '03' => 'Assaba',
            '04' => 'Gorgol',
            '05' => 'Brakna',
            '06' => 'Trarza',
            '07' => 'Adrar',
            '08' => 'Dakhlet Nouadhibou',
            '09' => 'Tagant',
            '10' => 'Guidimaka',
            '11' => 'Tiris Zemmour',
            '12' => 'Inchiri'
  },
  'MS' => {
            '01' => 'Saint Anthony',
            '02' => 'Saint Georges',
            '03' => 'Saint Peter'
  },
  'MU' => {
            '12' => 'Black River',
            '13' => 'Flacq',
            '14' => 'Grand Port',
            '15' => 'Moka',
            '16' => 'Pamplemousses',
            '17' => 'Plaines Wilhems',
            '18' => 'Port Louis',
            '19' => 'Riviere du Rempart',
            '20' => 'Savanne',
            '21' => 'Agalega Islands',
            '22' => 'Cargados Carajos',
            '23' => 'Rodrigues'
  },
  'MV' => {
            '01' => 'Seenu',
            '05' => 'Laamu',
            '30' => 'Alifu',
            '31' => 'Baa',
            '32' => 'Dhaalu',
            '33' => 'Faafu ',
            '34' => 'Gaafu Alifu',
            '35' => 'Gaafu Dhaalu',
            '36' => 'Haa Alifu',
            '37' => 'Haa Dhaalu',
            '38' => 'Kaafu',
            '39' => 'Lhaviyani',
            '40' => 'Maale',
            '41' => 'Meemu',
            '42' => 'Gnaviyani',
            '43' => 'Noonu',
            '44' => 'Raa',
            '45' => 'Shaviyani',
            '46' => 'Thaa',
            '47' => 'Vaavu'
  },
  'MW' => {
            '02' => 'Chikwawa',
            '03' => 'Chiradzulu',
            '04' => 'Chitipa',
            '05' => 'Thyolo',
            '06' => 'Dedza',
            '07' => 'Dowa',
            '08' => 'Karonga',
            '09' => 'Kasungu',
            '11' => 'Lilongwe',
            '12' => 'Mangochi',
            '13' => 'Mchinji',
            '15' => 'Mzimba',
            '16' => 'Ntcheu',
            '17' => 'Nkhata Bay',
            '18' => 'Nkhotakota',
            '19' => 'Nsanje',
            '20' => 'Ntchisi',
            '21' => 'Rumphi',
            '22' => 'Salima',
            '23' => 'Zomba',
            '24' => 'Blantyre',
            '25' => 'Mwanza',
            '26' => 'Balaka',
            '27' => 'Likoma',
            '28' => 'Machinga',
            '29' => 'Mulanje',
            '30' => 'Phalombe'
  },
  'MX' => {
            '01' => 'Aguascalientes',
            '02' => 'Baja California',
            '03' => 'Baja California Sur',
            '04' => 'Campeche',
            '05' => 'Chiapas',
            '06' => 'Chihuahua',
            '07' => 'Coahuila de Zaragoza',
            '08' => 'Colima',
            '09' => 'Distrito Federal',
            '10' => 'Durango',
            '11' => 'Guanajuato',
            '12' => 'Guerrero',
            '13' => 'Hidalgo',
            '14' => 'Jalisco',
            '15' => 'Mexico',
            '16' => 'Michoacan de Ocampo',
            '17' => 'Morelos',
            '18' => 'Nayarit',
            '19' => 'Nuevo Leon',
            '20' => 'Oaxaca',
            '21' => 'Puebla',
            '22' => 'Queretaro de Arteaga',
            '23' => 'Quintana Roo',
            '24' => 'San Luis Potosi',
            '25' => 'Sinaloa',
            '26' => 'Sonora',
            '27' => 'Tabasco',
            '28' => 'Tamaulipas',
            '29' => 'Tlaxcala',
            '30' => 'Veracruz-Llave',
            '31' => 'Yucatan',
            '32' => 'Zacatecas'
  },
  'MY' => {
            '01' => 'Johor',
            '02' => 'Kedah',
            '03' => 'Kelantan',
            '04' => 'Melaka',
            '05' => 'Negeri Sembilan',
            '06' => 'Pahang',
            '07' => 'Perak',
            '08' => 'Perlis',
            '09' => 'Pulau Pinang',
            '11' => 'Sarawak',
            '12' => 'Selangor',
            '13' => 'Terengganu',
            '14' => 'Kuala Lumpur',
            '15' => 'Labuan',
            '16' => 'Sabah',
            '17' => 'Putrajaya'
  },
  'MZ' => {
            '01' => 'Cabo Delgado',
            '02' => 'Gaza',
            '03' => 'Inhambane',
            '04' => 'Maputo',
            '05' => 'Sofala',
            '06' => 'Nampula',
            '07' => 'Niassa',
            '08' => 'Tete',
            '09' => 'Zambezia',
            '10' => 'Manica',
            '11' => 'Maputo'
  },
  'NA' => {
            '01' => 'Bethanien',
            '02' => 'Caprivi Oos',
            '03' => 'Boesmanland',
            '04' => 'Gobabis',
            '05' => 'Grootfontein',
            '06' => 'Kaokoland',
            '07' => 'Karibib',
            '08' => 'Keetmanshoop',
            '09' => 'Luderitz',
            '10' => 'Maltahohe',
            '11' => 'Okahandja',
            '12' => 'Omaruru',
            '13' => 'Otjiwarongo',
            '14' => 'Outjo',
            '15' => 'Owambo',
            '16' => 'Rehoboth',
            '17' => 'Swakopmund',
            '18' => 'Tsumeb',
            '20' => 'Karasburg',
            '21' => 'Windhoek',
            '22' => 'Damaraland',
            '23' => 'Hereroland Oos',
            '24' => 'Hereroland Wes',
            '25' => 'Kavango',
            '26' => 'Mariental',
            '27' => 'Namaland',
            '28' => 'Caprivi',
            '29' => 'Erongo',
            '30' => 'Hardap',
            '31' => 'Karas',
            '32' => 'Kunene',
            '33' => 'Ohangwena',
            '34' => 'Okavango',
            '35' => 'Omaheke',
            '36' => 'Omusati',
            '37' => 'Oshana',
            '38' => 'Oshikoto',
            '39' => 'Otjozondjupa'
  },
  'NE' => {
            '01' => 'Agadez',
            '02' => 'Diffa',
            '03' => 'Dosso',
            '04' => 'Maradi',
            '05' => 'Niamey',
            '06' => 'Tahoua',
            '07' => 'Zinder',
            '08' => 'Niamey'
  },
  'NG' => {
            '05' => 'Lagos',
            '11' => 'Federal Capital Territory',
            '16' => 'Ogun',
            '21' => 'Akwa Ibom',
            '22' => 'Cross River',
            '23' => 'Kaduna',
            '24' => 'Katsina',
            '25' => 'Anambra',
            '26' => 'Benue',
            '27' => 'Borno',
            '28' => 'Imo',
            '29' => 'Kano',
            '30' => 'Kwara',
            '31' => 'Niger',
            '32' => 'Oyo',
            '35' => 'Adamawa',
            '36' => 'Delta',
            '37' => 'Edo',
            '39' => 'Jigawa',
            '40' => 'Kebbi',
            '41' => 'Kogi',
            '42' => 'Osun',
            '43' => 'Taraba',
            '44' => 'Yobe',
            '45' => 'Abia',
            '46' => 'Bauchi',
            '47' => 'Enugu',
            '48' => 'Ondo',
            '49' => 'Plateau',
            '50' => 'Rivers',
            '51' => 'Sokoto',
            '52' => 'Bayelsa',
            '53' => 'Ebonyi',
            '54' => 'Ekiti',
            '55' => 'Gombe',
            '56' => 'Nassarawa',
            '57' => 'Zamfara'
  },
  'NI' => {
            '01' => 'Boaco',
            '02' => 'Carazo',
            '03' => 'Chinandega',
            '04' => 'Chontales',
            '05' => 'Esteli',
            '06' => 'Granada',
            '07' => 'Jinotega',
            '08' => 'Leon',
            '09' => 'Madriz',
            '10' => 'Managua',
            '11' => 'Masaya',
            '12' => 'Matagalpa',
            '13' => 'Nueva Segovia',
            '14' => 'Rio San Juan',
            '15' => 'Rivas',
            '16' => 'Zelaya',
            '17' => 'Autonoma Atlantico Norte',
            '18' => 'Region Autonoma Atlantico Sur'
  },
  'NL' => {
            '01' => 'Drenthe',
            '02' => 'Friesland',
            '03' => 'Gelderland',
            '04' => 'Groningen',
            '05' => 'Limburg',
            '06' => 'Noord-Brabant',
            '07' => 'Noord-Holland',
            '08' => 'Overijssel',
            '09' => 'Utrecht',
            '10' => 'Zeeland',
            '11' => 'Zuid-Holland',
            '15' => 'Overijssel',
            '16' => 'Flevoland'
  },
  'NO' => {
            '01' => 'Akershus',
            '02' => 'Aust-Agder',
            '04' => 'Buskerud',
            '05' => 'Finnmark',
            '06' => 'Hedmark',
            '07' => 'Hordaland',
            '08' => 'More og Romsdal',
            '09' => 'Nordland',
            '10' => 'Nord-Trondelag',
            '11' => 'Oppland',
            '12' => 'Oslo',
            '13' => 'Ostfold',
            '14' => 'Rogaland',
            '15' => 'Sogn og Fjordane',
            '16' => 'Sor-Trondelag',
            '17' => 'Telemark',
            '18' => 'Troms',
            '19' => 'Vest-Agder',
            '20' => 'Vestfold'
  },
  'NP' => {
            '01' => 'Bagmati',
            '02' => 'Bheri',
            '03' => 'Dhawalagiri',
            '04' => 'Gandaki',
            '05' => 'Janakpur',
            '06' => 'Karnali',
            '07' => 'Kosi',
            '08' => 'Lumbini',
            '09' => 'Mahakali',
            '10' => 'Mechi',
            '11' => 'Narayani',
            '12' => 'Rapti',
            '13' => 'Sagarmatha',
            '14' => 'Seti'
  },
  'NR' => {
            '01' => 'Aiwo',
            '02' => 'Anabar',
            '03' => 'Anetan',
            '04' => 'Anibare',
            '05' => 'Baiti',
            '06' => 'Boe',
            '07' => 'Buada',
            '08' => 'Denigomodu',
            '09' => 'Ewa',
            '10' => 'Ijuw',
            '11' => 'Meneng',
            '12' => 'Nibok',
            '13' => 'Uaboe',
            '14' => 'Yaren'
  },
  'NZ' => {
            '10' => 'Chatham Islands',
            'E7' => 'Auckland',
            'E8' => 'Bay of Plenty',
            'E9' => 'Canterbury',
            'F1' => 'Gisborne',
            'F2' => 'Hawke\'s Bay',
            'F3' => 'Manawatu-Wanganui',
            'F4' => 'Marlborough',
            'F5' => 'Nelson',
            'F6' => 'Northland',
            'F7' => 'Otago',
            'F8' => 'Southland',
            'F9' => 'Taranaki',
            'G1' => 'Waikato',
            'G2' => 'Wellington',
            'G3' => 'West Coast'
  },
  'OM' => {
            '01' => 'Ad Dakhiliyah',
            '02' => 'Al Batinah',
            '03' => 'Al Wusta',
            '04' => 'Ash Sharqiyah',
            '05' => 'Az Zahirah',
            '06' => 'Masqat',
            '07' => 'Musandam',
            '08' => 'Zufar'
  },
  'PA' => {
            '01' => 'Bocas del Toro',
            '02' => 'Chiriqui',
            '03' => 'Cocle',
            '04' => 'Colon',
            '05' => 'Darien',
            '06' => 'Herrera',
            '07' => 'Los Santos',
            '08' => 'Panama',
            '09' => 'San Blas',
            '10' => 'Veraguas'
  },
  'PE' => {
            '01' => 'Amazonas',
            '02' => 'Ancash',
            '03' => 'Apurimac',
            '04' => 'Arequipa',
            '05' => 'Ayacucho',
            '06' => 'Cajamarca',
            '07' => 'Callao',
            '08' => 'Cusco',
            '09' => 'Huancavelica',
            '10' => 'Huanuco',
            '11' => 'Ica',
            '12' => 'Junin',
            '13' => 'La Libertad',
            '14' => 'Lambayeque',
            '15' => 'Lima',
            '16' => 'Loreto',
            '17' => 'Madre de Dios',
            '18' => 'Moquegua',
            '19' => 'Pasco',
            '20' => 'Piura',
            '21' => 'Puno',
            '22' => 'San Martin',
            '23' => 'Tacna',
            '24' => 'Tumbes',
            '25' => 'Ucayali'
  },
  'PG' => {
            '01' => 'Central',
            '02' => 'Gulf',
            '03' => 'Milne Bay',
            '04' => 'Northern',
            '05' => 'Southern Highlands',
            '06' => 'Western',
            '07' => 'North Solomons',
            '08' => 'Chimbu',
            '09' => 'Eastern Highlands',
            '10' => 'East New Britain',
            '11' => 'East Sepik',
            '12' => 'Madang',
            '13' => 'Manus',
            '14' => 'Morobe',
            '15' => 'New Ireland',
            '16' => 'Western Highlands',
            '17' => 'West New Britain',
            '18' => 'Sandaun',
            '19' => 'Enga',
            '20' => 'National Capital'
  },
  'PH' => {
            '01' => 'Abra',
            '02' => 'Agusan del Norte',
            '03' => 'Agusan del Sur',
            '04' => 'Aklan',
            '05' => 'Albay',
            '06' => 'Antique',
            '07' => 'Bataan',
            '08' => 'Batanes',
            '09' => 'Batangas',
            '10' => 'Benguet',
            '11' => 'Bohol',
            '12' => 'Bukidnon',
            '13' => 'Bulacan',
            '14' => 'Cagayan',
            '15' => 'Camarines Norte',
            '16' => 'Camarines Sur',
            '17' => 'Camiguin',
            '18' => 'Capiz',
            '19' => 'Catanduanes',
            '20' => 'Cavite',
            '21' => 'Cebu',
            '22' => 'Basilan',
            '23' => 'Eastern Samar',
            '24' => 'Davao',
            '25' => 'Davao del Sur',
            '26' => 'Davao Oriental',
            '27' => 'Ifugao',
            '28' => 'Ilocos Norte',
            '29' => 'Ilocos Sur',
            '30' => 'Iloilo',
            '31' => 'Isabela',
            '32' => 'Kalinga-Apayao',
            '33' => 'Laguna',
            '34' => 'Lanao del Norte',
            '35' => 'Lanao del Sur',
            '36' => 'La Union',
            '37' => 'Leyte',
            '38' => 'Marinduque',
            '39' => 'Masbate',
            '40' => 'Mindoro Occidental',
            '41' => 'Mindoro Oriental',
            '42' => 'Misamis Occidental',
            '43' => 'Misamis Oriental',
            '44' => 'Mountain',
            '45' => 'Negros Occidental',
            '46' => 'Negros Oriental',
            '47' => 'Nueva Ecija',
            '48' => 'Nueva Vizcaya',
            '49' => 'Palawan',
            '50' => 'Pampanga',
            '51' => 'Pangasinan',
            '53' => 'Rizal',
            '54' => 'Romblon',
            '55' => 'Samar',
            '56' => 'Maguindanao',
            '57' => 'North Cotabato',
            '58' => 'Sorsogon',
            '59' => 'Southern Leyte',
            '60' => 'Sulu',
            '61' => 'Surigao del Norte',
            '62' => 'Surigao del Sur',
            '63' => 'Tarlac',
            '64' => 'Zambales',
            '65' => 'Zamboanga del Norte',
            '66' => 'Zamboanga del Sur',
            '67' => 'Northern Samar',
            '68' => 'Quirino',
            '69' => 'Siquijor',
            '70' => 'South Cotabato',
            '71' => 'Sultan Kudarat',
            '72' => 'Tawitawi',
            'A1' => 'Angeles',
            'A2' => 'Bacolod',
            'A3' => 'Bago',
            'A4' => 'Baguio',
            'A5' => 'Bais',
            'A6' => 'Basilan City',
            'A7' => 'Batangas City',
            'A8' => 'Butuan',
            'A9' => 'Cabanatuan',
            'B1' => 'Cadiz',
            'B2' => 'Cagayan de Oro',
            'B3' => 'Calbayog',
            'B4' => 'Caloocan',
            'B5' => 'Canlaon',
            'B6' => 'Cavite City',
            'B7' => 'Cebu City',
            'B8' => 'Cotabato',
            'B9' => 'Dagupan',
            'C1' => 'Danao',
            'C2' => 'Dapitan',
            'C3' => 'Davao City',
            'C4' => 'Dipolog',
            'C5' => 'Dumaguete',
            'C6' => 'General Santos',
            'C7' => 'Gingoog',
            'C8' => 'Iligan',
            'C9' => 'Iloilo City',
            'D1' => 'Iriga',
            'D2' => 'La Carlota',
            'D3' => 'Laoag',
            'D4' => 'Lapu-Lapu',
            'D5' => 'Legaspi',
            'D6' => 'Lipa',
            'D7' => 'Lucena',
            'D8' => 'Mandaue',
            'D9' => 'Manila',
            'E1' => 'Marawi',
            'E2' => 'Naga',
            'E3' => 'Olongapo',
            'E4' => 'Ormoc',
            'E5' => 'Oroquieta',
            'E6' => 'Ozamis',
            'E7' => 'Pagadian',
            'E8' => 'Palayan',
            'E9' => 'Pasay',
            'F1' => 'Puerto Princesa',
            'F2' => 'Quezon City',
            'F3' => 'Roxas',
            'F4' => 'San Carlos',
            'F5' => 'San Carlos',
            'F6' => 'San Jose',
            'F7' => 'San Pablo',
            'F8' => 'Silay',
            'F9' => 'Surigao',
            'G1' => 'Tacloban',
            'G2' => 'Tagaytay',
            'G3' => 'Tagbilaran',
            'G4' => 'Tangub',
            'G5' => 'Toledo',
            'G6' => 'Trece Martires',
            'G7' => 'Zamboanga',
            'G8' => 'Aurora',
            'H2' => 'Quezon',
            'H3' => 'Negros Occidental'
  },
  'PK' => {
            '01' => 'Federally Administered Tribal Areas',
            '02' => 'Balochistan',
            '03' => 'North-West Frontier',
            '04' => 'Punjab',
            '05' => 'Sindh',
            '06' => 'Azad Kashmir',
            '07' => 'Northern Areas',
            '08' => 'Islamabad'
  },
  'PL' => {
            '72' => 'Dolnoslaskie',
            '73' => 'Kujawsko-Pomorskie',
            '74' => 'Lodzkie',
            '75' => 'Lubelskie',
            '76' => 'Lubuskie',
            '77' => 'Malopolskie',
            '78' => 'Mazowieckie',
            '79' => 'Opolskie',
            '80' => 'Podkarpackie',
            '81' => 'Podlaskie',
            '82' => 'Pomorskie',
            '83' => 'Slaskie',
            '84' => 'Swietokrzyskie',
            '85' => 'Warminsko-Mazurskie',
            '86' => 'Wielkopolskie',
            '87' => 'Zachodniopomorskie'
  },
  'PS' => {
            'GZ' => 'Gaza',
            'WE' => 'West Bank'
  },
  'PT' => {
            '02' => 'Aveiro',
            '03' => 'Beja',
            '04' => 'Braga',
            '05' => 'Braganca',
            '06' => 'Castelo Branco',
            '07' => 'Coimbra',
            '08' => 'Evora',
            '09' => 'Faro',
            '10' => 'Madeira',
            '11' => 'Guarda',
            '13' => 'Leiria',
            '14' => 'Lisboa',
            '16' => 'Portalegre',
            '17' => 'Porto',
            '18' => 'Santarem',
            '19' => 'Setubal',
            '20' => 'Viana do Castelo',
            '21' => 'Vila Real',
            '22' => 'Viseu',
            '23' => 'Azores'
  },
  'PY' => {
            '01' => 'Alto Parana',
            '02' => 'Amambay',
            '03' => 'Boqueron',
            '04' => 'Caaguazu',
            '05' => 'Caazapa',
            '06' => 'Central',
            '07' => 'Concepcion',
            '08' => 'Cordillera',
            '10' => 'Guaira',
            '11' => 'Itapua',
            '12' => 'Misiones',
            '13' => 'Neembucu',
            '15' => 'Paraguari',
            '16' => 'Presidente Hayes',
            '17' => 'San Pedro',
            '19' => 'Canindeyu',
            '20' => 'Chaco',
            '21' => 'Nueva Asuncion',
            '23' => 'Alto Paraguay'
  },
  'QA' => {
            '01' => 'Ad Dawhah',
            '02' => 'Al Ghuwariyah',
            '03' => 'Al Jumaliyah',
            '04' => 'Al Khawr',
            '05' => 'Al Wakrah Municipality',
            '06' => 'Ar Rayyan',
            '08' => 'Madinat ach Shamal',
            '09' => 'Umm Salal',
            '10' => 'Al Wakrah',
            '11' => 'Jariyan al Batnah',
            '12' => 'Umm Sa\'id'
  },
  'RO' => {
            '01' => 'Alba',
            '02' => 'Arad',
            '03' => 'Arges',
            '04' => 'Bacau',
            '05' => 'Bihor',
            '06' => 'Bistrita-Nasaud',
            '07' => 'Botosani',
            '08' => 'Braila',
            '09' => 'Brasov',
            '10' => 'Bucuresti',
            '11' => 'Buzau',
            '12' => 'Caras-Severin',
            '13' => 'Cluj',
            '14' => 'Constanta',
            '15' => 'Covasna',
            '16' => 'Dambovita',
            '17' => 'Dolj',
            '18' => 'Galati',
            '19' => 'Gorj',
            '20' => 'Harghita',
            '21' => 'Hunedoara',
            '22' => 'Ialomita',
            '23' => 'Iasi',
            '25' => 'Maramures',
            '26' => 'Mehedinti',
            '27' => 'Mures',
            '28' => 'Neamt',
            '29' => 'Olt',
            '30' => 'Prahova',
            '31' => 'Salaj',
            '32' => 'Satu Mare',
            '33' => 'Sibiu',
            '34' => 'Suceava',
            '35' => 'Teleorman',
            '36' => 'Timis',
            '37' => 'Tulcea',
            '38' => 'Vaslui',
            '39' => 'Valcea',
            '40' => 'Vrancea',
            '41' => 'Calarasi',
            '42' => 'Giurgiu',
            '43' => 'Ilfov'
  },
  'RS' => {
            '01' => 'Kosovo',
            '02' => 'Vojvodina'
  },
  'RU' => {
            '01' => 'Adygeya, Republic of',
            '02' => 'Aginsky Buryatsky AO',
            '03' => 'Gorno-Altay',
            '04' => 'Altaisky krai',
            '05' => 'Amur',
            '06' => 'Arkhangel\'sk',
            '07' => 'Astrakhan\'',
            '08' => 'Bashkortostan',
            '09' => 'Belgorod',
            '10' => 'Bryansk',
            '11' => 'Buryat',
            '12' => 'Chechnya',
            '13' => 'Chelyabinsk',
            '14' => 'Chita',
            '15' => 'Chukot',
            '16' => 'Chuvashia',
            '17' => 'Dagestan',
            '18' => 'Evenk',
            '19' => 'Ingush',
            '20' => 'Irkutsk',
            '21' => 'Ivanovo',
            '22' => 'Kabardin-Balkar',
            '23' => 'Kaliningrad',
            '24' => 'Kalmyk',
            '25' => 'Kaluga',
            '26' => 'Kamchatka',
            '27' => 'Karachay-Cherkess',
            '28' => 'Karelia',
            '29' => 'Kemerovo',
            '30' => 'Khabarovsk',
            '31' => 'Khakass',
            '32' => 'Khanty-Mansiy',
            '33' => 'Kirov',
            '34' => 'Komi',
            '35' => 'Komi-Permyak',
            '36' => 'Koryak',
            '37' => 'Kostroma',
            '38' => 'Krasnodar',
            '39' => 'Krasnoyarsk',
            '40' => 'Kurgan',
            '41' => 'Kursk',
            '42' => 'Leningrad',
            '43' => 'Lipetsk',
            '44' => 'Magadan',
            '45' => 'Mariy-El',
            '46' => 'Mordovia',
            '47' => 'Moskva',
            '48' => 'Moscow City',
            '49' => 'Murmansk',
            '50' => 'Nenets',
            '51' => 'Nizhegorod',
            '52' => 'Novgorod',
            '53' => 'Novosibirsk',
            '54' => 'Omsk',
            '55' => 'Orenburg',
            '56' => 'Orel',
            '57' => 'Penza',
            '58' => 'Perm\'',
            '59' => 'Primor\'ye',
            '60' => 'Pskov',
            '61' => 'Rostov',
            '62' => 'Ryazan\'',
            '63' => 'Sakha',
            '64' => 'Sakhalin',
            '65' => 'Samara',
            '66' => 'Saint Petersburg City',
            '67' => 'Saratov',
            '68' => 'North Ossetia',
            '69' => 'Smolensk',
            '70' => 'Stavropol\'',
            '71' => 'Sverdlovsk',
            '72' => 'Tambovskaya oblast',
            '73' => 'Tatarstan',
            '74' => 'Taymyr',
            '75' => 'Tomsk',
            '76' => 'Tula',
            '77' => 'Tver\'',
            '78' => 'Tyumen\'',
            '79' => 'Tuva',
            '80' => 'Udmurt',
            '81' => 'Ul\'yanovsk',
            '82' => 'Ust-Orda Buryat',
            '83' => 'Vladimir',
            '84' => 'Volgograd',
            '85' => 'Vologda',
            '86' => 'Voronezh',
            '87' => 'Yamal-Nenets',
            '88' => 'Yaroslavl\'',
            '89' => 'Yevrey',
            '90' => 'Permskiy Kray',
            '91' => 'Krasnoyarskiy Kray',
            'CI' => 'Chechnya Republic'
  },
  'RW' => {
            '01' => 'Butare',
            '06' => 'Gitarama',
            '07' => 'Kibungo',
            '09' => 'Kigali',
            '11' => 'Est',
            '12' => 'Kigali',
            '13' => 'Nord',
            '14' => 'Ouest',
            '15' => 'Sud'
  },
  'SA' => {
            '02' => 'Al Bahah',
            '03' => 'Al Jawf',
            '05' => 'Al Madinah',
            '06' => 'Ash Sharqiyah',
            '08' => 'Al Qasim',
            '09' => 'Al Qurayyat',
            '10' => 'Ar Riyad',
            '13' => 'Ha\'il',
            '14' => 'Makkah',
            '15' => 'Al Hudud ash Shamaliyah',
            '16' => 'Najran',
            '17' => 'Jizan',
            '19' => 'Tabuk',
            '20' => 'Al Jawf'
  },
  'SB' => {
            '03' => 'Malaita',
            '06' => 'Guadalcanal',
            '07' => 'Isabel',
            '08' => 'Makira',
            '09' => 'Temotu',
            '10' => 'Central',
            '11' => 'Western',
            '12' => 'Choiseul',
            '13' => 'Rennell and Bellona'
  },
  'SC' => {
            '01' => 'Anse aux Pins',
            '02' => 'Anse Boileau',
            '03' => 'Anse Etoile',
            '04' => 'Anse Louis',
            '05' => 'Anse Royale',
            '06' => 'Baie Lazare',
            '07' => 'Baie Sainte Anne',
            '08' => 'Beau Vallon',
            '09' => 'Bel Air',
            '10' => 'Bel Ombre',
            '11' => 'Cascade',
            '12' => 'Glacis',
            '13' => 'Grand\' Anse',
            '14' => 'Grand\' Anse',
            '15' => 'La Digue',
            '16' => 'La Riviere Anglaise',
            '17' => 'Mont Buxton',
            '18' => 'Mont Fleuri',
            '19' => 'Plaisance',
            '20' => 'Pointe La Rue',
            '21' => 'Port Glaud',
            '22' => 'Saint Louis',
            '23' => 'Takamaka'
  },
  'SD' => {
            '27' => 'Al Wusta',
            '28' => 'Al Istiwa\'iyah',
            '29' => 'Al Khartum',
            '30' => 'Ash Shamaliyah',
            '31' => 'Ash Sharqiyah',
            '32' => 'Bahr al Ghazal',
            '33' => 'Darfur',
            '34' => 'Kurdufan',
            '35' => 'Upper Nile',
            '40' => 'Al Wahadah State',
            '44' => 'Central Equatoria State'
  },
  'SE' => {
            '02' => 'Blekinge Lan',
            '03' => 'Gavleborgs Lan',
            '05' => 'Gotlands Lan',
            '06' => 'Hallands Lan',
            '07' => 'Jamtlands Lan',
            '08' => 'Jonkopings Lan',
            '09' => 'Kalmar Lan',
            '10' => 'Dalarnas Lan',
            '12' => 'Kronobergs Lan',
            '14' => 'Norrbottens Lan',
            '15' => 'Orebro Lan',
            '16' => 'Ostergotlands Lan',
            '18' => 'Sodermanlands Lan',
            '21' => 'Uppsala Lan',
            '22' => 'Varmlands Lan',
            '23' => 'Vasterbottens Lan',
            '24' => 'Vasternorrlands Lan',
            '25' => 'Vastmanlands Lan',
            '26' => 'Stockholms Lan',
            '27' => 'Skane Lan',
            '28' => 'Vastra Gotaland'
  },
  'SH' => {
            '01' => 'Ascension',
            '02' => 'Saint Helena',
            '03' => 'Tristan da Cunha'
  },
  'SI' => {
            '01' => 'Ajdovscina',
            '02' => 'Beltinci',
            '03' => 'Bled',
            '04' => 'Bohinj',
            '05' => 'Borovnica',
            '06' => 'Bovec',
            '07' => 'Brda',
            '08' => 'Brezice',
            '09' => 'Brezovica',
            '11' => 'Celje',
            '12' => 'Cerklje na Gorenjskem',
            '13' => 'Cerknica',
            '14' => 'Cerkno',
            '15' => 'Crensovci',
            '16' => 'Crna na Koroskem',
            '17' => 'Crnomelj',
            '19' => 'Divaca',
            '20' => 'Dobrepolje',
            '22' => 'Dol pri Ljubljani',
            '24' => 'Dornava',
            '25' => 'Dravograd',
            '26' => 'Duplek',
            '27' => 'Gorenja Vas-Poljane',
            '28' => 'Gorisnica',
            '29' => 'Gornja Radgona',
            '30' => 'Gornji Grad',
            '31' => 'Gornji Petrovci',
            '32' => 'Grosuplje',
            '34' => 'Hrastnik',
            '35' => 'Hrpelje-Kozina',
            '36' => 'Idrija',
            '37' => 'Ig',
            '38' => 'Ilirska Bistrica',
            '39' => 'Ivancna Gorica',
            '40' => 'Izola-Isola',
            '42' => 'Jursinci',
            '44' => 'Kanal',
            '45' => 'Kidricevo',
            '46' => 'Kobarid',
            '47' => 'Kobilje',
            '49' => 'Komen',
            '50' => 'Koper-Capodistria',
            '51' => 'Kozje',
            '52' => 'Kranj',
            '53' => 'Kranjska Gora',
            '54' => 'Krsko',
            '55' => 'Kungota',
            '57' => 'Lasko',
            '61' => 'Ljubljana',
            '62' => 'Ljubno',
            '64' => 'Logatec',
            '66' => 'Loski Potok',
            '68' => 'Lukovica',
            '71' => 'Medvode',
            '72' => 'Menges',
            '73' => 'Metlika',
            '74' => 'Mezica',
            '76' => 'Mislinja',
            '77' => 'Moravce',
            '78' => 'Moravske Toplice',
            '79' => 'Mozirje',
            '80' => 'Murska Sobota',
            '81' => 'Muta',
            '82' => 'Naklo',
            '83' => 'Nazarje',
            '84' => 'Nova Gorica',
            '86' => 'Odranci',
            '87' => 'Ormoz',
            '88' => 'Osilnica',
            '89' => 'Pesnica',
            '91' => 'Pivka',
            '92' => 'Podcetrtek',
            '94' => 'Postojna',
            '97' => 'Puconci',
            '98' => 'Racam',
            '99' => 'Radece',
            'A1' => 'Radenci',
            'A2' => 'Radlje ob Dravi',
            'A3' => 'Radovljica',
            'A6' => 'Rogasovci',
            'A7' => 'Rogaska Slatina',
            'A8' => 'Rogatec',
            'B1' => 'Semic',
            'B2' => 'Sencur',
            'B3' => 'Sentilj',
            'B4' => 'Sentjernej',
            'B6' => 'Sevnica',
            'B7' => 'Sezana',
            'B8' => 'Skocjan',
            'B9' => 'Skofja Loka',
            'C1' => 'Skofljica',
            'C2' => 'Slovenj Gradec',
            'C4' => 'Slovenske Konjice',
            'C5' => 'Smarje pri Jelsah',
            'C6' => 'Smartno ob Paki',
            'C7' => 'Sostanj',
            'C8' => 'Starse',
            'C9' => 'Store',
            'D1' => 'Sveti Jurij',
            'D2' => 'Tolmin',
            'D3' => 'Trbovlje',
            'D4' => 'Trebnje',
            'D5' => 'Trzic',
            'D6' => 'Turnisce',
            'D7' => 'Velenje',
            'D8' => 'Velike Lasce',
            'E1' => 'Vipava',
            'E2' => 'Vitanje',
            'E3' => 'Vodice',
            'E5' => 'Vrhnika',
            'E6' => 'Vuzenica',
            'E7' => 'Zagorje ob Savi',
            'E9' => 'Zavrc',
            'F1' => 'Zelezniki',
            'F2' => 'Ziri',
            'F3' => 'Zrece',
            'G4' => 'Dobrova-Horjul-Polhov Gradec',
            'G7' => 'Domzale',
            'H4' => 'Jesenice',
            'H6' => 'Kamnik',
            'H7' => 'Kocevje',
            'I2' => 'Kuzma',
            'I3' => 'Lenart',
            'I5' => 'Litija',
            'I6' => 'Ljutomer',
            'I7' => 'Loska Dolina',
            'I9' => 'Luce',
            'J1' => 'Majsperk',
            'J2' => 'Maribor',
            'J5' => 'Miren-Kostanjevica',
            'J7' => 'Novo Mesto',
            'J9' => 'Piran',
            'K5' => 'Preddvor',
            'K7' => 'Ptuj',
            'L1' => 'Ribnica',
            'L3' => 'Ruse',
            'L7' => 'Sentjur pri Celju',
            'L8' => 'Slovenska Bistrica',
            'N2' => 'Videm',
            'N3' => 'Vojnik',
            'N5' => 'Zalec'
  },
  'SK' => {
            '01' => 'Banska Bystrica',
            '02' => 'Bratislava',
            '03' => 'Kosice',
            '04' => 'Nitra',
            '05' => 'Presov',
            '06' => 'Trencin',
            '07' => 'Trnava',
            '08' => 'Zilina'
  },
  'SL' => {
            '01' => 'Eastern',
            '02' => 'Northern',
            '03' => 'Southern',
            '04' => 'Western Area'
  },
  'SM' => {
            '01' => 'Acquaviva',
            '02' => 'Chiesanuova',
            '03' => 'Domagnano',
            '04' => 'Faetano',
            '05' => 'Fiorentino',
            '06' => 'Borgo Maggiore',
            '07' => 'San Marino',
            '08' => 'Monte Giardino',
            '09' => 'Serravalle'
  },
  'SN' => {
            '01' => 'Dakar',
            '03' => 'Diourbel',
            '05' => 'Tambacounda',
            '07' => 'Thies',
            '09' => 'Fatick',
            '10' => 'Kaolack',
            '11' => 'Kolda',
            '12' => 'Ziguinchor',
            '13' => 'Louga',
            '14' => 'Saint-Louis',
            '15' => 'Matam'
  },
  'SO' => {
            '01' => 'Bakool',
            '02' => 'Banaadir',
            '03' => 'Bari',
            '04' => 'Bay',
            '05' => 'Galguduud',
            '06' => 'Gedo',
            '07' => 'Hiiraan',
            '08' => 'Jubbada Dhexe',
            '09' => 'Jubbada Hoose',
            '10' => 'Mudug',
            '11' => 'Nugaal',
            '12' => 'Sanaag',
            '13' => 'Shabeellaha Dhexe',
            '14' => 'Shabeellaha Hoose',
            '16' => 'Woqooyi Galbeed',
            '18' => 'Nugaal',
            '19' => 'Togdheer',
            '20' => 'Woqooyi Galbeed',
            '21' => 'Awdal',
            '22' => 'Sool'
  },
  'SR' => {
            '10' => 'Brokopondo',
            '11' => 'Commewijne',
            '12' => 'Coronie',
            '13' => 'Marowijne',
            '14' => 'Nickerie',
            '15' => 'Para',
            '16' => 'Paramaribo',
            '17' => 'Saramacca',
            '18' => 'Sipaliwini',
            '19' => 'Wanica'
  },
  'ST' => {
            '01' => 'Principe',
            '02' => 'Sao Tome'
  },
  'SV' => {
            '01' => 'Ahuachapan',
            '02' => 'Cabanas',
            '03' => 'Chalatenango',
            '04' => 'Cuscatlan',
            '05' => 'La Libertad',
            '06' => 'La Paz',
            '07' => 'La Union',
            '08' => 'Morazan',
            '09' => 'San Miguel',
            '10' => 'San Salvador',
            '11' => 'Santa Ana',
            '12' => 'San Vicente',
            '13' => 'Sonsonate',
            '14' => 'Usulutan'
  },
  'SY' => {
            '01' => 'Al Hasakah',
            '02' => 'Al Ladhiqiyah',
            '03' => 'Al Qunaytirah',
            '04' => 'Ar Raqqah',
            '05' => 'As Suwayda\'',
            '06' => 'Dar',
            '07' => 'Dayr az Zawr',
            '08' => 'Rif Dimashq',
            '09' => 'Halab',
            '10' => 'Hamah',
            '11' => 'Hims',
            '12' => 'Idlib',
            '13' => 'Dimashq',
            '14' => 'Tartus'
  },
  'SZ' => {
            '01' => 'Hhohho',
            '02' => 'Lubombo',
            '03' => 'Manzini',
            '04' => 'Shiselweni',
            '05' => 'Praslin'
  },
  'TD' => {
            '01' => 'Batha',
            '02' => 'Biltine',
            '03' => 'Borkou-Ennedi-Tibesti',
            '04' => 'Chari-Baguirmi',
            '05' => 'Guera',
            '06' => 'Kanem',
            '07' => 'Lac',
            '08' => 'Logone Occidental',
            '09' => 'Logone Oriental',
            '10' => 'Mayo-Kebbi',
            '11' => 'Moyen-Chari',
            '12' => 'Ouaddai',
            '13' => 'Salamat',
            '14' => 'Tandjile'
  },
  'TG' => {
            '22' => 'Centrale',
            '23' => 'Kara',
            '24' => 'Maritime',
            '25' => 'Plateaux',
            '26' => 'Savanes'
  },
  'TH' => {
            '01' => 'Mae Hong Son',
            '02' => 'Chiang Mai',
            '03' => 'Chiang Rai',
            '04' => 'Nan',
            '05' => 'Lamphun',
            '06' => 'Lampang',
            '07' => 'Phrae',
            '08' => 'Tak',
            '09' => 'Sukhothai',
            '10' => 'Uttaradit',
            '11' => 'Kamphaeng Phet',
            '12' => 'Phitsanulok',
            '13' => 'Phichit',
            '14' => 'Phetchabun',
            '15' => 'Uthai Thani',
            '16' => 'Nakhon Sawan',
            '17' => 'Nong Khai',
            '18' => 'Loei',
            '20' => 'Sakon Nakhon',
            '21' => 'Nakhon Phanom',
            '22' => 'Khon Kaen',
            '23' => 'Kalasin',
            '24' => 'Maha Sarakham',
            '25' => 'Roi Et',
            '26' => 'Chaiyaphum',
            '27' => 'Nakhon Ratchasima',
            '28' => 'Buriram',
            '29' => 'Surin',
            '30' => 'Sisaket',
            '31' => 'Narathiwat',
            '32' => 'Chai Nat',
            '33' => 'Sing Buri',
            '34' => 'Lop Buri',
            '35' => 'Ang Thong',
            '36' => 'Phra Nakhon Si Ayutthaya',
            '37' => 'Saraburi',
            '38' => 'Nonthaburi',
            '39' => 'Pathum Thani',
            '40' => 'Krung Thep',
            '41' => 'Phayao',
            '42' => 'Samut Prakan',
            '43' => 'Nakhon Nayok',
            '44' => 'Chachoengsao',
            '45' => 'Prachin Buri',
            '46' => 'Chon Buri',
            '47' => 'Rayong',
            '48' => 'Chanthaburi',
            '49' => 'Trat',
            '50' => 'Kanchanaburi',
            '51' => 'Suphan Buri',
            '52' => 'Ratchaburi',
            '53' => 'Nakhon Pathom',
            '54' => 'Samut Songkhram',
            '55' => 'Samut Sakhon',
            '56' => 'Phetchaburi',
            '57' => 'Prachuap Khiri Khan',
            '58' => 'Chumphon',
            '59' => 'Ranong',
            '60' => 'Surat Thani',
            '61' => 'Phangnga',
            '62' => 'Phuket',
            '63' => 'Krabi',
            '64' => 'Nakhon Si Thammarat',
            '65' => 'Trang',
            '66' => 'Phatthalung',
            '67' => 'Satun',
            '68' => 'Songkhla',
            '69' => 'Pattani',
            '70' => 'Yala',
            '71' => 'Ubon Ratchathani',
            '72' => 'Yasothon',
            '73' => 'Nakhon Phanom',
            '75' => 'Ubon Ratchathani',
            '76' => 'Udon Thani',
            '77' => 'Amnat Charoen',
            '78' => 'Mukdahan',
            '79' => 'Nong Bua Lamphu',
            '80' => 'Sa Kaeo'
  },
  'TJ' => {
            '01' => 'Kuhistoni Badakhshon',
            '02' => 'Khatlon',
            '03' => 'Sughd'
  },
  'TM' => {
            '01' => 'Ahal',
            '02' => 'Balkan',
            '03' => 'Dashoguz',
            '04' => 'Lebap',
            '05' => 'Mary'
  },
  'TN' => {
            '02' => 'Kasserine',
            '03' => 'Kairouan',
            '06' => 'Jendouba',
            '10' => 'Qafsah',
            '14' => 'El Kef',
            '15' => 'Al Mahdia',
            '16' => 'Al Munastir',
            '17' => 'Bajah',
            '18' => 'Bizerte',
            '19' => 'Nabeul',
            '22' => 'Siliana',
            '23' => 'Sousse',
            '27' => 'Ben Arous',
            '28' => 'Madanin',
            '29' => 'Gabes',
            '31' => 'Kebili',
            '32' => 'Sfax',
            '33' => 'Sidi Bou Zid',
            '34' => 'Tataouine',
            '35' => 'Tozeur',
            '36' => 'Tunis',
            '37' => 'Zaghouan',
            '38' => 'Aiana',
            '39' => 'Manouba'
  },
  'TO' => {
            '01' => 'Ha',
            '02' => 'Tongatapu',
            '03' => 'Vava'
  },
  'TR' => {
            '02' => 'Adiyaman',
            '03' => 'Afyonkarahisar',
            '04' => 'Agri',
            '05' => 'Amasya',
            '07' => 'Antalya',
            '08' => 'Artvin',
            '09' => 'Aydin',
            '10' => 'Balikesir',
            '11' => 'Bilecik',
            '12' => 'Bingol',
            '13' => 'Bitlis',
            '14' => 'Bolu',
            '15' => 'Burdur',
            '16' => 'Bursa',
            '17' => 'Canakkale',
            '19' => 'Corum',
            '20' => 'Denizli',
            '21' => 'Diyarbakir',
            '22' => 'Edirne',
            '23' => 'Elazig',
            '24' => 'Erzincan',
            '25' => 'Erzurum',
            '26' => 'Eskisehir',
            '28' => 'Giresun',
            '31' => 'Hatay',
            '32' => 'Mersin',
            '33' => 'Isparta',
            '34' => 'Istanbul',
            '35' => 'Izmir',
            '37' => 'Kastamonu',
            '38' => 'Kayseri',
            '39' => 'Kirklareli',
            '40' => 'Kirsehir',
            '41' => 'Kocaeli',
            '43' => 'Kutahya',
            '44' => 'Malatya',
            '45' => 'Manisa',
            '46' => 'Kahramanmaras',
            '48' => 'Mugla',
            '49' => 'Mus',
            '50' => 'Nevsehir',
            '52' => 'Ordu',
            '53' => 'Rize',
            '54' => 'Sakarya',
            '55' => 'Samsun',
            '57' => 'Sinop',
            '58' => 'Sivas',
            '59' => 'Tekirdag',
            '60' => 'Tokat',
            '61' => 'Trabzon',
            '62' => 'Tunceli',
            '63' => 'Sanliurfa',
            '64' => 'Usak',
            '65' => 'Van',
            '66' => 'Yozgat',
            '68' => 'Ankara',
            '69' => 'Gumushane',
            '70' => 'Hakkari',
            '71' => 'Konya',
            '72' => 'Mardin',
            '73' => 'Nigde',
            '74' => 'Siirt',
            '75' => 'Aksaray',
            '76' => 'Batman',
            '77' => 'Bayburt',
            '78' => 'Karaman',
            '79' => 'Kirikkale',
            '80' => 'Sirnak',
            '81' => 'Adana',
            '82' => 'Cankiri',
            '83' => 'Gaziantep',
            '84' => 'Kars',
            '85' => 'Zonguldak',
            '86' => 'Ardahan',
            '87' => 'Bartin',
            '88' => 'Igdir',
            '89' => 'Karabuk',
            '90' => 'Kilis',
            '91' => 'Osmaniye',
            '92' => 'Yalova',
            '93' => 'Duzce'
  },
  'TT' => {
            '01' => 'Arima',
            '02' => 'Caroni',
            '03' => 'Mayaro',
            '04' => 'Nariva',
            '05' => 'Port-of-Spain',
            '06' => 'Saint Andrew',
            '07' => 'Saint David',
            '08' => 'Saint George',
            '09' => 'Saint Patrick',
            '10' => 'San Fernando',
            '11' => 'Tobago',
            '12' => 'Victoria'
  },
  'TW' => {
            '01' => 'Fu-chien',
            '02' => 'Kao-hsiung',
            '03' => 'T\'ai-pei',
            '04' => 'T\'ai-wan'
  },
  'TZ' => {
            '02' => 'Pwani',
            '03' => 'Dodoma',
            '04' => 'Iringa',
            '05' => 'Kigoma',
            '06' => 'Kilimanjaro',
            '07' => 'Lindi',
            '08' => 'Mara',
            '09' => 'Mbeya',
            '10' => 'Morogoro',
            '11' => 'Mtwara',
            '12' => 'Mwanza',
            '13' => 'Pemba North',
            '14' => 'Ruvuma',
            '15' => 'Shinyanga',
            '16' => 'Singida',
            '17' => 'Tabora',
            '18' => 'Tanga',
            '19' => 'Kagera',
            '20' => 'Pemba South',
            '21' => 'Zanzibar Central',
            '22' => 'Zanzibar North',
            '23' => 'Dar es Salaam',
            '24' => 'Rukwa',
            '25' => 'Zanzibar Urban',
            '26' => 'Arusha',
            '27' => 'Manyara'
  },
  'UA' => {
            '01' => 'Cherkas\'ka Oblast\'',
            '02' => 'Chernihivs\'ka Oblast\'',
            '03' => 'Chernivets\'ka Oblast\'',
            '04' => 'Dnipropetrovs\'ka Oblast\'',
            '05' => 'Donets\'ka Oblast\'',
            '06' => 'Ivano-Frankivs\'ka Oblast\'',
            '07' => 'Kharkivs\'ka Oblast\'',
            '08' => 'Khersons\'ka Oblast\'',
            '09' => 'Khmel\'nyts\'ka Oblast\'',
            '10' => 'Kirovohrads\'ka Oblast\'',
            '11' => 'Krym',
            '12' => 'Kyyiv',
            '13' => 'Kyyivs\'ka Oblast\'',
            '14' => 'Luhans\'ka Oblast\'',
            '15' => 'L\'vivs\'ka Oblast\'',
            '16' => 'Mykolayivs\'ka Oblast\'',
            '17' => 'Odes\'ka Oblast\'',
            '18' => 'Poltavs\'ka Oblast\'',
            '19' => 'Rivnens\'ka Oblast\'',
            '20' => 'Sevastopol\'',
            '21' => 'Sums\'ka Oblast\'',
            '22' => 'Ternopil\'s\'ka Oblast\'',
            '23' => 'Vinnyts\'ka Oblast\'',
            '24' => 'Volyns\'ka Oblast\'',
            '25' => 'Zakarpats\'ka Oblast\'',
            '26' => 'Zaporiz\'ka Oblast\'',
            '27' => 'Zhytomyrs\'ka Oblast\''
  },
  'UG' => {
            '26' => 'Apac',
            '28' => 'Bundibugyo',
            '29' => 'Bushenyi',
            '30' => 'Gulu',
            '31' => 'Hoima',
            '33' => 'Jinja',
            '36' => 'Kalangala',
            '37' => 'Kampala',
            '38' => 'Kamuli',
            '39' => 'Kapchorwa',
            '40' => 'Kasese',
            '41' => 'Kibale',
            '42' => 'Kiboga',
            '43' => 'Kisoro',
            '45' => 'Kotido',
            '46' => 'Kumi',
            '47' => 'Lira',
            '50' => 'Masindi',
            '52' => 'Mbarara',
            '56' => 'Mubende',
            '58' => 'Nebbi',
            '59' => 'Ntungamo',
            '60' => 'Pallisa',
            '61' => 'Rakai',
            '65' => 'Adjumani',
            '66' => 'Bugiri',
            '67' => 'Busia',
            '69' => 'Katakwi',
            '70' => 'Luwero',
            '71' => 'Masaka',
            '72' => 'Moyo',
            '73' => 'Nakasongola',
            '74' => 'Sembabule',
            '76' => 'Tororo',
            '77' => 'Arua',
            '78' => 'Iganga',
            '79' => 'Kabarole',
            '80' => 'Kaberamaido',
            '81' => 'Kamwenge',
            '82' => 'Kanungu',
            '83' => 'Kayunga',
            '84' => 'Kitgum',
            '85' => 'Kyenjojo',
            '86' => 'Mayuge',
            '87' => 'Mbale',
            '88' => 'Moroto',
            '89' => 'Mpigi',
            '90' => 'Mukono',
            '91' => 'Nakapiripirit',
            '92' => 'Pader',
            '93' => 'Rukungiri',
            '94' => 'Sironko',
            '95' => 'Soroti',
            '96' => 'Wakiso',
            '97' => 'Yumbe'
  },
  'US' => {
            'AA' => 'Armed Forces Americas',
            'AE' => 'Armed Forces Europe, Middle East, & Canada',
            'AK' => 'Alaska',
            'AL' => 'Alabama',
            'AP' => 'Armed Forces Pacific',
            'AR' => 'Arkansas',
            'AS' => 'American Samoa',
            'AZ' => 'Arizona',
            'CA' => 'California',
            'CO' => 'Colorado',
            'CT' => 'Connecticut',
            'DC' => 'District of Columbia',
            'DE' => 'Delaware',
            'FL' => 'Florida',
            'FM' => 'Federated States of Micronesia',
            'GA' => 'Georgia',
            'GU' => 'Guam',
            'HI' => 'Hawaii',
            'IA' => 'Iowa',
            'ID' => 'Idaho',
            'IL' => 'Illinois',
            'IN' => 'Indiana',
            'KS' => 'Kansas',
            'KY' => 'Kentucky',
            'LA' => 'Louisiana',
            'MA' => 'Massachusetts',
            'MD' => 'Maryland',
            'ME' => 'Maine',
            'MH' => 'Marshall Islands',
            'MI' => 'Michigan',
            'MN' => 'Minnesota',
            'MO' => 'Missouri',
            'MP' => 'Northern Mariana Islands',
            'MS' => 'Mississippi',
            'MT' => 'Montana',
            'NC' => 'North Carolina',
            'ND' => 'North Dakota',
            'NE' => 'Nebraska',
            'NH' => 'New Hampshire',
            'NJ' => 'New Jersey',
            'NM' => 'New Mexico',
            'NV' => 'Nevada',
            'NY' => 'New York',
            'OH' => 'Ohio',
            'OK' => 'Oklahoma',
            'OR' => 'Oregon',
            'PA' => 'Pennsylvania',
            'PR' => 'Puerto Rico',
            'PW' => 'Palau',
            'RI' => 'Rhode Island',
            'SC' => 'South Carolina',
            'SD' => 'South Dakota',
            'TN' => 'Tennessee',
            'TX' => 'Texas',
            'UT' => 'Utah',
            'VA' => 'Virginia',
            'VI' => 'Virgin Islands',
            'VT' => 'Vermont',
            'WA' => 'Washington',
            'WI' => 'Wisconsin',
            'WV' => 'West Virginia',
            'WY' => 'Wyoming'
  },
  'UY' => {
            '01' => 'Artigas',
            '02' => 'Canelones',
            '03' => 'Cerro Largo',
            '04' => 'Colonia',
            '05' => 'Durazno',
            '06' => 'Flores',
            '07' => 'Florida',
            '08' => 'Lavalleja',
            '09' => 'Maldonado',
            '10' => 'Montevideo',
            '11' => 'Paysandu',
            '12' => 'Rio Negro',
            '13' => 'Rivera',
            '14' => 'Rocha',
            '15' => 'Salto',
            '16' => 'San Jose',
            '17' => 'Soriano',
            '18' => 'Tacuarembo',
            '19' => 'Treinta y Tres'
  },
  'UZ' => {
            '01' => 'Andijon',
            '02' => 'Bukhoro',
            '03' => 'Farghona',
            '04' => 'Jizzakh',
            '05' => 'Khorazm',
            '06' => 'Namangan',
            '07' => 'Nawoiy',
            '08' => 'Qashqadaryo',
            '09' => 'Qoraqalpoghiston',
            '10' => 'Samarqand',
            '11' => 'Sirdaryo',
            '12' => 'Surkhondaryo',
            '13' => 'Toshkent',
            '14' => 'Toshkent'
  },
  'VC' => {
            '01' => 'Charlotte',
            '02' => 'Saint Andrew',
            '03' => 'Saint David',
            '04' => 'Saint George',
            '05' => 'Saint Patrick',
            '06' => 'Grenadines'
  },
  'VE' => {
            '01' => 'Amazonas',
            '02' => 'Anzoategui',
            '03' => 'Apure',
            '04' => 'Aragua',
            '05' => 'Barinas',
            '06' => 'Bolivar',
            '07' => 'Carabobo',
            '08' => 'Cojedes',
            '09' => 'Delta Amacuro',
            '11' => 'Falcon',
            '12' => 'Guarico',
            '13' => 'Lara',
            '14' => 'Merida',
            '15' => 'Miranda',
            '16' => 'Monagas',
            '17' => 'Nueva Esparta',
            '18' => 'Portuguesa',
            '19' => 'Sucre',
            '20' => 'Tachira',
            '21' => 'Trujillo',
            '22' => 'Yaracuy',
            '23' => 'Zulia',
            '24' => 'Dependencias Federales',
            '25' => 'Distrito Federal',
            '26' => 'Vargas'
  },
  'VN' => {
            '01' => 'An Giang',
            '03' => 'Ben Tre',
            '05' => 'Cao Bang',
            '09' => 'Dong Thap',
            '13' => 'Hai Phong',
            '20' => 'Ho Chi Minh',
            '21' => 'Kien Giang',
            '23' => 'Lam Dong',
            '24' => 'Long An',
            '30' => 'Quang Ninh',
            '32' => 'Son La',
            '33' => 'Tay Ninh',
            '34' => 'Thanh Hoa',
            '35' => 'Thai Binh',
            '37' => 'Tien Giang',
            '39' => 'Lang Son',
            '43' => 'An Giang',
            '44' => 'Dac Lac',
            '45' => 'Dong Nai',
            '46' => 'Dong Thap',
            '47' => 'Kien Giang',
            '49' => 'Song Be',
            '50' => 'Vinh Phu',
            '51' => 'Ha Noi',
            '52' => 'Ho Chi Minh',
            '53' => 'Ba Ria-Vung Tau',
            '54' => 'Binh Dinh',
            '55' => 'Binh Thuan',
            '58' => 'Ha Giang',
            '59' => 'Ha Tay',
            '60' => 'Ha Tinh',
            '61' => 'Hoa Binh',
            '62' => 'Khanh Hoa',
            '63' => 'Kon Tum',
            '64' => 'Quang Tri',
            '65' => 'Nam Ha',
            '66' => 'Nghe An',
            '67' => 'Ninh Binh',
            '68' => 'Ninh Thuan',
            '69' => 'Phu Yen',
            '70' => 'Quang Binh',
            '71' => 'Quang Ngai',
            '72' => 'Quang Tri',
            '73' => 'Soc Trang',
            '74' => 'Thua Thien',
            '75' => 'Tra Vinh',
            '76' => 'Tuyen Quang',
            '77' => 'Vinh Long',
            '78' => 'Da Nang',
            '79' => 'Hai Duong',
            '80' => 'Ha Nam',
            '81' => 'Hung Yen',
            '82' => 'Nam Dinh',
            '83' => 'Phu Tho',
            '84' => 'Quang Nam',
            '85' => 'Thai Nguyen',
            '86' => 'Vinh Puc Province',
            '87' => 'Can Tho',
            '88' => 'Dak Lak',
            '89' => 'Lai Chau',
            '90' => 'Lao Cai',
            '91' => 'Dak Nong',
            '92' => 'Dien Bien',
            '93' => 'Hau Giang'
  },
  'VU' => {
            '05' => 'Ambrym',
            '06' => 'Aoba',
            '07' => 'Torba',
            '08' => 'Efate',
            '09' => 'Epi',
            '10' => 'Malakula',
            '11' => 'Paama',
            '12' => 'Pentecote',
            '13' => 'Sanma',
            '14' => 'Shepherd',
            '15' => 'Tafea',
            '16' => 'Malampa',
            '17' => 'Penama',
            '18' => 'Shefa'
  },
  'WS' => {
            '02' => 'Aiga-i-le-Tai',
            '03' => 'Atua',
            '04' => 'Fa',
            '05' => 'Gaga',
            '06' => 'Va',
            '07' => 'Gagaifomauga',
            '08' => 'Palauli',
            '09' => 'Satupa',
            '10' => 'Tuamasaga',
            '11' => 'Vaisigano'
  },
  'YE' => {
            '01' => 'Abyan',
            '02' => 'Adan',
            '03' => 'Al Mahrah',
            '04' => 'Hadramawt',
            '05' => 'Shabwah',
            '06' => 'Al Ghaydah',
            '08' => 'Al Hudaydah',
            '10' => 'Al Mahwit',
            '11' => 'Dhamar',
            '14' => 'Ma\'rib',
            '15' => 'Sa',
            '16' => 'San',
            '20' => 'Al Bayda\'',
            '21' => 'Al Jawf',
            '22' => 'Hajjah',
            '23' => 'Ibb',
            '24' => 'Lahij',
            '25' => 'Ta'
  },
  'ZA' => {
            '01' => 'North-Western Province',
            '02' => 'KwaZulu-Natal',
            '03' => 'Free State',
            '05' => 'Eastern Cape',
            '06' => 'Gauteng',
            '07' => 'Mpumalanga',
            '08' => 'Northern Cape',
            '09' => 'Limpopo',
            '10' => 'North-West',
            '11' => 'Western Cape'
  },
  'ZM' => {
            '01' => 'Western',
            '02' => 'Central',
            '03' => 'Eastern',
            '04' => 'Luapula',
            '05' => 'Northern',
            '06' => 'North-Western',
            '07' => 'Southern',
            '08' => 'Copperbelt',
            '09' => 'Lusaka'
  },
  'ZW' => {
            '01' => 'Manicaland',
            '02' => 'Midlands',
            '03' => 'Mashonaland Central',
            '04' => 'Mashonaland East',
            '05' => 'Mashonaland West',
            '06' => 'Matabeleland North',
            '07' => 'Matabeleland South',
            '08' => 'Masvingo',
            '09' => 'Bulawayo',
            '10' => 'Harare'
    }
);

sub continent_code_by_country_code { 
    my $id = $_id_by_code{ $_[1] } || 0;
    return $continents[$id];
}
sub time_zone { Geo::IP::Record->_time_zone( $_[1], $_[2] ) }

sub _get_region_name {
  my ( $ccode, $region ) = @_;
  return unless $region;
  return if $region eq '00';

  return $country_region_names{$ccode}->{$region}
    if exists $country_region_names{$ccode};
}

# --- unfortunately we do not know the path so we assume the 
# default path /usr/local/share/GeoIP
# if thats not true, you can set $Geo::IP::PP_OPEN_TYPE_PATH
#
sub open_type {
  my ( $class, $type, $flags ) = @_;
  my %type_dat_name_mapper = (
    GEOIP_COUNTRY_EDITION()     => 'GeoIP',
    GEOIP_REGION_EDITION_REV0() => 'GeoIPRegion',
    GEOIP_REGION_EDITION_REV1() => 'GeoIPRegion',
    GEOIP_CITY_EDITION_REV0()   => 'GeoIPCity',
    GEOIP_CITY_EDITION_REV1()   => 'GeoIPCity',
    GEOIP_ISP_EDITION()         => 'GeoIPISP',
    GEOIP_ORG_EDITION()         => 'GeoIPOrg',
    GEOIP_PROXY_EDITION()       => 'GeoIPProxy',
    GEOIP_ASNUM_EDITION()       => 'GeoIPASNum',
    GEOIP_NETSPEED_EDITION()    => 'GeoIPNetSpeed',
    GEOIP_NETSPEED_EDITION_REV1() => 'GeoIPNetSpeed',
    GEOIP_DOMAIN_EDITION()      => 'GeoIPDomain',
  );

  # backward compatibility for 2003 databases.
  $type -= 105 if $type >= 106;
  
  my $name = $type_dat_name_mapper{$type};
  die("Invalid database type $type\n") unless $name;

  my $mkpath = sub { File::Spec->catfile( File::Spec->rootdir, @_ ) };

  my $path =
    defined $Geo::IP::PP_OPEN_TYPE_PATH
    ? $Geo::IP::PP_OPEN_TYPE_PATH
    : do {
    $^O eq 'NetWare'
      ? $mkpath->(qw/ etc GeoIP /)
      : do {
	    $^O eq 'MSWin32'
        ? $mkpath->(qw/ GeoIP /)
        : $mkpath->(qw/ usr local share GeoIP /);
      }
    };

  my $filename = File::Spec->catfile( $path, $name . '.dat' );
  return $class->open( $filename, $flags );
}

sub open {
  die "Geo::IP::open() requires a path name"
    unless ( @_ > 1 and $_[1] );
  my ( $class, $db_file, $flags ) = @_;
  my $fh = FileHandle->new;
  my $gi;
  CORE::open $fh, "$db_file" or die "Error opening $db_file";
  binmode($fh);
  if ( $flags && ( $flags & ( GEOIP_MEMORY_CACHE | GEOIP_MMAP_CACHE ) ) ) {
    my %self;
 		if ( $flags & GEOIP_MMAP_CACHE ) {
		  die "Sys::Mmap required for MMAP support"
		    unless defined $Sys::Mmap::VERSION;
		  mmap( $self{buf} = undef, 0, PROT_READ, MAP_PRIVATE, $fh )
		    or die "mmap: $!";
		}
    else {
		  local $/ = undef;
		  $self{buf} = <$fh>;
		}   
		$self{fh}  = $fh;
    $gi = bless \%self, $class;
  }
	else {
	  $gi = bless { fh => $fh }, $class;
	}
	$gi->_setup_segments();
	return $gi;
}

sub new {
  my ( $class, $db_file, $flags ) = @_;

  # this will be less messy once deprecated new( $path, [$flags] )
  # is no longer supported (that's what open() is for)
  my $def_db_file = '/usr/local/share/GeoIP/GeoIP.dat';
  if ($^O eq 'NetWare') {
    $def_db_file = 'sys:/etc/GeoIP/GeoIP.dat';
  } elsif ($^O eq 'MSWin32') {
    $def_db_file = 'c:/GeoIP/GeoIP.dat';
  }
  if ( !defined $db_file ) {

    # called as new()
    $db_file = $def_db_file;
  }
  elsif ( $db_file =~ /^\d+$/	) {
    # called as new( $flags )
    $flags   = $db_file;
    $db_file = $def_db_file;
  }    # else called as new( $database_filename, [$flags] );

  $class->open( $db_file, $flags );
}

#this function setups the database segments
sub _setup_segments {
  my ($gi) = @_;
  my $a    = 0;
  my $i    = 0;
  my $j    = 0;
  my $delim;
  my $buf;

  $gi->{_charset} = GEOIP_CHARSET_ISO_8859_1; 
  $gi->{"databaseType"}  = GEOIP_COUNTRY_EDITION;
  $gi->{"record_length"} = STANDARD_RECORD_LENGTH;

  my $filepos = tell( $gi->{fh} );
  seek( $gi->{fh}, -3, 2 );
  for ( $i = 0; $i < STRUCTURE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $delim, 3 );

    #find the delim
    if ( $delim eq ( chr(255) . chr(255) . chr(255) ) ) {
      read( $gi->{fh}, $a, 1 );

      #read the databasetype
      my $database_type = ord($a);

      # backward compatibility for 2003 databases.
      $database_type -= 105 if $database_type >= 106;
      $gi->{"databaseType"} = $database_type;

#chose the database segment for the database type
#if database Type is GEOIP_REGION_EDITION then use database segment GEOIP_STATE_BEGIN
      if ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV0 ) {
        $gi->{"databaseSegments"} = GEOIP_STATE_BEGIN_REV0;
      }
      elsif ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV1 ) {
        $gi->{"databaseSegments"} = GEOIP_STATE_BEGIN_REV1;
      }

#if database Type is GEOIP_CITY_EDITION, GEOIP_ISP_EDITION or GEOIP_ORG_EDITION then
#read in the database segment
      elsif (    ( $gi->{"databaseType"} == GEOIP_CITY_EDITION_REV0 )
              || ( $gi->{"databaseType"} == GEOIP_CITY_EDITION_REV1 )
              || ( $gi->{"databaseType"} == GEOIP_ORG_EDITION )
              || ( $gi->{"databaseType"} == GEOIP_DOMAIN_EDITION )
              || ( $gi->{"databaseType"} == GEOIP_ASNUM_EDITION )
              || ( $gi->{"databaseType"} == GEOIP_NETSPEED_EDITION_REV1 )
              || ( $gi->{"databaseType"} == GEOIP_ISP_EDITION ) ) {
        $gi->{"databaseSegments"} = 0;

        #read in the database segment for the database type
        read( $gi->{fh}, $buf, SEGMENT_RECORD_LENGTH );
        for ( $j = 0; $j < SEGMENT_RECORD_LENGTH; $j++ ) {
          $gi->{"databaseSegments"} +=
            ( ord( substr( $buf, $j, 1 ) ) << ( $j * 8 ) );
        }

#record length is four for ISP databases and ORG databases
#record length is three for country databases, region database and city databases
        if (    $gi->{"databaseType"} == GEOIP_ORG_EDITION 
             || $gi->{"databaseType"} == GEOIP_ISP_EDITION
             || $gi->{"databaseType"} == GEOIP_DOMAIN_EDITION ){
          $gi->{"record_length"} = ORG_RECORD_LENGTH;
        }
      }
      last;
    }
    else {
      seek( $gi->{fh}, -4, 1 );
    }
  }

#if database Type is GEOIP_COUNTY_EDITION then use database segment GEOIP_COUNTRY_BEGIN
  if (    $gi->{"databaseType"} == GEOIP_COUNTRY_EDITION
       || $gi->{"databaseType"} == GEOIP_NETSPEED_EDITION ) {
    $gi->{"databaseSegments"} = GEOIP_COUNTRY_BEGIN;
  }
  seek( $gi->{fh}, $filepos, 0 );
  return $gi;
}

sub _seek_country {
  my ( $gi, $ipnum ) = @_;

  my $fh     = $gi->{fh};
  my $offset = 0;

  my ( $x0, $x1 );

  my $reclen = $gi->{record_length};

  for ( my $depth = 31; $depth >= 0; $depth-- ) {
    unless ( exists $gi->{buf} ) {
      seek $fh, $offset * 2 * $reclen, 0;
      read $fh, $x0, $reclen;
      read $fh, $x1, $reclen;
    }
    else {
      $x0 = substr( $gi->{buf}, $offset * 2 * $reclen, $reclen );
      $x1 = substr( $gi->{buf}, $offset * 2 * $reclen + $reclen, $reclen );
    }

    $x0 = unpack( "V1", $x0 . "\0" );
    $x1 = unpack( "V1", $x1 . "\0" );

    if ( $ipnum & ( 1 << $depth ) ) {
      if ( $x1 >= $gi->{"databaseSegments"} ) {
	    $gi->{last_netmask} = 32 - $depth;
        return $x1;
      }
      $offset = $x1;
    }
    else {
      if ( $x0 >= $gi->{"databaseSegments"} ) {
	    $gi->{last_netmask} = 32 - $depth;
        return $x0;
      }
      $offset = $x0;
    }
  }

  print STDERR
"Error Traversing Database for ipnum = $ipnum - Perhaps database is corrupt?";
}

sub charset {
  return $_[0]->{_charset};
}

sub set_charset{
  my ($gi, $charset) = @_;
  my $old_charset = $gi->{_charset};
  $gi->{_charset} = $charset;
  return $old_charset;
}

#this function returns the country code of ip address
sub country_code_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^(?:\d{1,3}\.){3}\d{1,3}$!;
  return $countries[ $gi->id_by_addr($ip_address) ];
}

#this function returns the country code3 of ip address
sub country_code3_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $code3s[ $gi->id_by_addr($ip_address) ];
}

#this function returns the name of ip address
sub country_name_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $names[ $gi->id_by_addr($ip_address) ];
}

sub id_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_COUNTRY_BEGIN;
}

#this function returns the country code of domain name
sub country_code_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $countries[$country_id];
}

#this function returns the country code3 of domain name
sub country_code3_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $code3s[$country_id];
}

#this function returns the country name of domain name
sub country_name_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $names[$country_id];
}

sub id_by_name {
  my ( $gi, $host ) = @_;
  my $ip_address;
  if ( $host =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {
    $ip_address = $host;
  }
  else {
    $ip_address = join( '.', unpack( 'C4', ( gethostbyname($host) )[4] ) );
  }
  return unless $ip_address;
  return $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_COUNTRY_BEGIN;
}

#this function returns the city record as a array
sub get_city_record {
  my ( $gi, $host ) = @_;
  my $ip_address = $gi->get_ip_address($host);
  return unless $ip_address;
  my $record_buf;
  my $record_buf_pos;
  my $char;
  my $metroarea_combo;
  my $record_country_code  = "";
  my $record_country_code3 = "";
  my $record_country_name  = "";
  my $record_region        = undef;
  my $record_city          = '';
  my $record_postal_code   = undef;
  my $record_latitude      = "";
  my $record_longitude     = "";
  my $record_metro_code    = 0;
  my $record_area_code     = 0;
  my $record_continent_code = '';
  my $record_region_name = undef;
  my $str_length           = 0;
  my $i;
  my $j;

  #lookup the city
  my $seek_country = $gi->_seek_country( addr_to_num($ip_address) );
  if ( $seek_country == $gi->{"databaseSegments"} ) {
    return;
  }

  #set the record pointer to location of the city record
  my $record_pointer = $seek_country +
    ( 2 * $gi->{"record_length"} - 1 ) * $gi->{"databaseSegments"};

  unless ( exists $gi->{buf} ) {
    seek( $gi->{"fh"}, $record_pointer, 0 );
    read( $gi->{"fh"}, $record_buf, FULL_RECORD_LENGTH );
    $record_buf_pos = 0;
  }
	else {
	  $record_buf = substr($gi->{buf}, $record_pointer, FULL_RECORD_LENGTH);
    $record_buf_pos = 0;
  }

  #get the country
  $char = ord( substr( $record_buf, $record_buf_pos, 1 ) );
  $record_country_code = $countries[$char];    #get the country code
  $record_country_code3 = $code3s[$char];   #get the country code with 3 letters
  $record_country_name  = $names[$char];    #get the country name
  $record_buf_pos++;

  # get the continent code
  $record_continent_code = $continents[$char];

  #get the region
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_region = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;

  #get the city
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_city = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;

  #get the postal code
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_postal_code = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;
  my $latitude  = 0;
  my $longitude = 0;

  #get the latitude
  for ( $j = 0; $j < 3; ++$j ) {
    $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
    $latitude += ( $char << ( $j * 8 ) );
  }
  $record_latitude = ( $latitude / 10000 ) - 180;

  #get the longitude
  for ( $j = 0; $j < 3; ++$j ) {
    $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
    $longitude += ( $char << ( $j * 8 ) );
  }
  $record_longitude = ( $longitude / 10000 ) - 180;

  #get the metro code and the area code
  if ( GEOIP_CITY_EDITION_REV1 == $gi->{"databaseType"} ) {
    $metroarea_combo = 0;
    if ( $record_country_code eq "US" ) {

      #if the country is US then read the dma/metro area combo
      for ( $j = 0; $j < 3; ++$j ) {
        $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
        $metroarea_combo += ( $char << ( $j * 8 ) );
      }

      #split the dma/metro area combo into the metro code and the area code
      $record_metro_code  = int( $metroarea_combo / 1000 );
      $record_area_code = $metroarea_combo % 1000;
    }
  }
  $record_region_name = _get_region_name($record_country_code, $record_region);


 # the pureperl API must convert the string by themself to UTF8
 # using Encode for perl >= 5.008 otherwise use it's own iso-8859-1 to utf8 converter
 $record_city = decode( 'iso-8859-1' => $record_city ) 
   if $gi->charset == GEOIP_CHARSET_UTF8; 

  return (
           $record_country_code, $record_country_code3, $record_country_name,
           $record_region,       $record_city,          $record_postal_code,
           $record_latitude,     $record_longitude,     $record_metro_code,
           $record_area_code,    $record_continent_code, $record_region_name,
           $record_metro_code );
}

#this function returns the city record as a hash ref
sub get_city_record_as_hash {
  my ( $gi, $host ) = @_;
  my %gir;

  @gir{qw/ country_code   country_code3   country_name   region     city 
           postal_code    latitude        longitude      dma_code   area_code 
           continent_code region_name     metro_code / } =
    $gi->get_city_record($host);
  
  return defined($gir{latitude}) ? bless( \%gir, 'Geo::IP::Record' ) : undef;
}

*record_by_addr = \&get_city_record_as_hash;
*record_by_name = \&get_city_record_as_hash;

sub org_by_name{
  my ( $gi, $host ) = @_;
  return $gi->org_by_addr($gi->get_ip_address($host));
}

#this function returns isp or org of the domain name
sub org_by_addr {
  my ( $gi, $ip_address ) = @_;
  my $seek_org   = $gi->_seek_country( addr_to_num($ip_address) );
  my $char;
  my $org_buf;
  my $record_pointer;

  if ( $seek_org == $gi->{"databaseSegments"} ) {
    return undef;
  }

  $record_pointer =
    $seek_org + ( 2 * $gi->{"record_length"} - 1 ) * $gi->{"databaseSegments"};
  
  unless ( exists $gi->{buf} ) {
    seek( $gi->{"fh"}, $record_pointer, 0 );
    read( $gi->{"fh"}, $org_buf, MAX_ORG_RECORD_LENGTH );
  }
	else {
    $org_buf = substr($gi->{buf}, $record_pointer, MAX_ORG_RECORD_LENGTH );
	}
	
  $org_buf = unpack 'Z*' => $org_buf;

  $org_buf = decode( 'iso-8859-1' => $org_buf ) 
   if $gi->charset == GEOIP_CHARSET_UTF8; 

  return $org_buf;
}

#this function returns isp or org of the domain name
*isp_by_name = \*org_by_name;
*isp_by_addr = \*org_by_addr;
*name_by_addr = \*org_by_addr;
*name_by_name = \*org_by_name;

#this function returns the region
sub region_by_name {
  my ( $gi, $host ) = @_;
  my $ip_address = $gi->get_ip_address($host);
  return unless $ip_address;
  if ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV0 ) {
    my $seek_region =
      $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_STATE_BEGIN_REV0;
    if ( $seek_region >= 1000 ) {
      return (
               "US",
               chr( ( $seek_region - 1000 ) / 26 + 65 )
                 . chr( ( $seek_region - 1000 ) % 26 + 65 )
      );
    }
    else {
      return ( $countries[$seek_region], "" );
    }
  }
  elsif ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV1 ) {
    my $seek_region =
      $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_STATE_BEGIN_REV1;
    if ( $seek_region < US_OFFSET ) {
      return ( "", "" );
    }
    elsif ( $seek_region < CANADA_OFFSET ) {

      # return a us state
      return (
               "US",
               chr( ( $seek_region - US_OFFSET ) / 26 + 65 )
                 . chr( ( $seek_region - US_OFFSET ) % 26 + 65 )
      );
    }
    elsif ( $seek_region < WORLD_OFFSET ) {

      # return a canada province
      return (
               "CA",
               chr( ( $seek_region - CANADA_OFFSET ) / 26 + 65 )
                 . chr( ( $seek_region - CANADA_OFFSET ) % 26 + 65 )
      );
    }
    else {

      # return a country of the world
      my $c = $countries[ ( $seek_region - WORLD_OFFSET ) / FIPS_RANGE ];
      my $a2 = ( $seek_region - WORLD_OFFSET ) % FIPS_RANGE;

##      my $r =
##          chr( ( $a2 / 100 ) + 48 )
##        . chr( ( ( $a2 / 10 ) % 10 ) + 48 )
##        . chr( ( $a2 % 10 ) + 48 );
      return ( $c, $a2 ? sprintf('%03d', $a2 ) : '00' ) ;
    }
  }
}

*region_by_addr = \&region_by_name;

sub get_ip_address {
  my ( $gi, $host ) = @_;
  my $ip_address;

  #check if host is ip address
  if ( $host =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {

    #host is ip address
    $ip_address = $host;
  }
  else {

    #host is domain name do a dns lookup
    $ip_address = join( '.', unpack( 'C4', ( gethostbyname($host) )[4] ) );
  }
  return $ip_address;
}

sub addr_to_num { unpack( N => pack( C4 => split( /\./, $_[0] ) ) ) }
sub num_to_addr { join q{.}, unpack( C4 => pack( N => $_[0] ) ) }

#sub addr_to_num {
#  my @a = split( '\.', $_[0] );
#  return $a[0] * 16777216 + $a[1] * 65536 + $a[2] * 256 + $a[3];
#}

sub database_edition {
  $_[0]->{databaseType};
}

sub database_info {
  my $gi = shift;
  my $i  = 0;
  my $buf;
  my $retval;
  my $hasStructureInfo;
  seek( $gi->{fh}, -3, 2 );
  for ( my $i = 0; $i < STRUCTURE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $buf, 3 );
    if ( $buf eq ( chr(255) . chr(255) . chr(255) ) ) {
      $hasStructureInfo = 1;
      last;
    }
    seek( $gi->{fh}, -4, 1 );
  }
  if ( $hasStructureInfo == 1 ) {
    seek( $gi->{fh}, -6, 1 );
  }
  else {

    # no structure info, must be pre Sep 2002 database, go back to
    seek( $gi->{fh}, -3, 2 );
  }
  for ( my $i = 0; $i < DATABASE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $buf, 3 );
    if ( $buf eq ( chr(0) . chr(0) . chr(0) ) ) {
      read( $gi->{fh}, $retval, $i );
      return $retval;
    }
    seek( $gi->{fh}, -4, 1 );
  }
  return '';
}

sub range_by_ip {
  my $gi = shift;
  my $ipnum          = addr_to_num( shift );
  my $c              = $gi->_seek_country( $ipnum );
  my $nm             = $gi->last_netmask;
  my $m              = 0xffffffff << 32 - $nm;
  my $left_seek_num  = $ipnum & $m;
  my $right_seek_num = $left_seek_num + ( 0xffffffff & ~$m );

  while ( $left_seek_num != 0
          and $c == $gi->_seek_country(  $left_seek_num - 1) ) {
    my $lm = 0xffffffff << 32 - $gi->last_netmask;
    $left_seek_num = ( $left_seek_num - 1 ) & $lm;
  }
  while ( $right_seek_num != 0xffffffff
          and $c == $gi->_seek_country( $right_seek_num + 1 ) ) {
    my $rm = 0xffffffff << 32 - $gi->last_netmask;
    $right_seek_num = ( $right_seek_num + 1 ) & $rm;
    $right_seek_num += ( 0xffffffff & ~$rm );
  }
  return ( num_to_addr($left_seek_num), num_to_addr($right_seek_num) );
}


sub netmask { $_[0]->{last_netmask} = $_[1] }

sub last_netmask {
  return $_[0]->{last_netmask};
}

sub DESTROY {
  my $gi = shift;
 
  if ( exists $gi->{buf} && $gi->{flags} && ( $gi->{flags} & GEOIP_MMAP_CACHE ) ) {
    munmap( $gi->{buf} ) or die "munmap: $!";
	  delete $gi->{buf};
  }
}

#sub _XS
__PP_CODE__

print STDERR $@ if $@;

@EXPORT = qw(
  GEOIP_STANDARD              GEOIP_MEMORY_CACHE
  GEOIP_CHECK_CACHE           GEOIP_INDEX_CACHE
  GEOIP_UNKNOWN_SPEED         GEOIP_DIALUP_SPEED
  GEOIP_CABLEDSL_SPEED        GEOIP_CORPORATE_SPEED
  GEOIP_COUNTRY_EDITION       GEOIP_REGION_EDITION_REV0
  GEOIP_CITY_EDITION_REV0     GEOIP_ORG_EDITION
  GEOIP_ISP_EDITION           GEOIP_CITY_EDITION_REV1
  GEOIP_REGION_EDITION_REV1   GEOIP_PROXY_EDITION
  GEOIP_ASNUM_EDITION         GEOIP_NETSPEED_EDITION
  GEOIP_CHARSET_ISO_8859_1    GEOIP_CHARSET_UTF8
  GEOIP_MMAP_CACHE            GEOIP_CITYCONFIDENCE_EDITION
  GEOIP_LOCATIONA_EDITION     GEOIP_ACCURACYRADIUS_EDITION
  GEOIP_COUNTRY_EDITION_V6    GEOIP_DOMAIN_EDITION
  GEOIP_NETSPEED_EDITION_REV1
);

1;
__END__

=head1 NAME

Geo::IP - Look up location and network information by IP Address

=head1 SYNOPSIS

  use Geo::IP;
  my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
  # look up IP address '24.24.24.24'
  # returns undef if country is unallocated, or not defined in our database
  my $country = $gi->country_code_by_addr('24.24.24.24');
  $country = $gi->country_code_by_name('yahoo.com');
  # $country is equal to "US"
  

  use Geo::IP;
  my $gi = Geo::IP->open("/usr/local/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD);
  my $record = $gi->record_by_addr('24.24.24.24');
  print $record->country_code,
        $record->country_code3,
        $record->country_name,
        $record->region,
        $record->region_name,
        $record->city,
        $record->postal_code,
        $record->latitude,
        $record->longitude,
        $record->time_zone,
        $record->area_code,
        $record->continent_code,
        $record->metro_code;


  # the IPv6 support is currently only avail if you use the CAPI which is much
  # faster anyway. ie: print Geo::IP->api equals to 'CAPI'
  use Socket;
  use Socket6;
  use Geo::IP;
  my $g = Geo::IP->open('/usr/local/share/GeoIP/GeoIPv6.dat') or die;
  print $g->country_code_by_ipnum_v6(inet_pton AF_INET6, '::24.24.24.24');
  print $g->country_code_by_addr_v6('2a02:e88::');

=head1 DESCRIPTION

This module uses a file based database.  This database simply contains
IP blocks as keys, and countries as values. 
This database should be more
complete and accurate than reverse DNS lookups.

This module can be used to automatically select the geographically closest mirror,
to analyze your web server logs
to determine the countries of your visitors, for credit card fraud
detection, and for software export controls.

=head1 IP ADDRESS TO COUNTRY DATABASES

Free monthly updates to the database are available from 

  http://www.maxmind.com/download/geoip/database/

This free database is similar to the database contained in IP::Country, as 
well as many paid databases. It uses ARIN, RIPE, APNIC, and LACNIC whois to 
obtain the IP->Country mappings.

If you require greater accuracy, MaxMind offers a database on a paid 
subscription basis.  Also included with this is a service that updates your
database automatically each month, by running a program called geoipupdate
included with the C API from a cronjob.  For more details on the differences
between the free and paid databases, see:
http://www.maxmind.com/app/geoip_country

Do not miss the city database, described in Geo::IP::Record

Make sure to use the F<geolite-mirror-simple.pl> script from the example directory to
stay current with the databases.

=head1 BENCHMARK the lookups are fast. This is my laptop ( examples/benchmark.pl ):

  Benchmark: running city_mem, city_std, country_mem, country_std, country_v6_mem, country_v6_std, isp_mem, isp_std for at least 10 CPU seconds...
    city_mem: 10.3121 wallclock secs (10.30 usr +  0.01 sys = 10.31 CPU) @ 387271.48/s (n=3992769)
    city_std: 10.0658 wallclock secs ( 2.86 usr +  7.17 sys = 10.03 CPU) @ 54392.62/s (n=545558)
  country_mem: 10.1772 wallclock secs (10.16 usr +  0.00 sys = 10.16 CPU) @ 1077507.97/s (n=10947481)
  country_std: 10.1432 wallclock secs ( 2.30 usr +  7.85 sys = 10.15 CPU) @ 83629.56/s (n=848840)
  country_v6_mem: 10.2579 wallclock secs (10.25 usr + -0.00 sys = 10.25 CPU) @ 365997.37/s (n=3751473)
  country_v6_std: 10.8541 wallclock secs ( 1.77 usr +  9.07 sys = 10.84 CPU) @ 10110.42/s (n=109597)
     isp_mem: 10.147 wallclock secs (10.13 usr +  0.01 sys = 10.14 CPU) @ 590109.66/s (n=5983712)
     isp_std: 10.0484 wallclock secs ( 2.71 usr +  7.33 sys = 10.04 CPU) @ 73186.35/s (n=734791)


=head1 CLASS METHODS

=over 4

=item $gi = Geo::IP->new( $flags );

Constructs a new Geo::IP object with the default database located inside your system's
I<datadir>, typically I</usr/local/share/GeoIP/GeoIP.dat>.

Flags can be set to either GEOIP_STANDARD, or for faster performance
(at a cost of using more memory), GEOIP_MEMORY_CACHE.  When using memory
cache you can force a reload if the file is updated by setting GEOIP_CHECK_CACHE.
GEOIP_INDEX_CACHE caches
the most frequently accessed index portion of the database, resulting
in faster lookups than GEOIP_STANDARD, but less memory usage than
GEOIP_MEMORY_CACHE - useful for larger databases such as
GeoIP Organization and GeoIP City.  Note, for GeoIP Country, Region
and Netspeed databases, GEOIP_INDEX_CACHE is equivalent to GEOIP_MEMORY_CACHE

To combine flags, use the bitwise OR operator, |.  For example, to cache the database
in memory, but check for an updated GeoIP.dat file, use:
Geo::IP->new( GEOIP_MEMORY_CACHE | GEOIP_CHECK_CACHE. );

=item $gi = Geo::IP->open( $database_filename, $flags );

Constructs a new Geo::IP object with the database located at C<$database_filename>.

=item $gi = Geo::IP->open_type( $database_type, $flags );

Constructs a new Geo::IP object with the $database_type database located in the standard
location.  For example

  $gi = Geo::IP->open_type( GEOIP_CITY_EDITION_REV1 , GEOIP_STANDARD );

opens the database file in the standard location for GeoIP City, typically
I</usr/local/share/GeoIP/GeoIPCity.dat>.

=back

=head1 OBJECT METHODS

=over 4

=item $code = $gi->country_code_by_addr( $ipaddr );

Returns the ISO 3166 country code for an IP address.

=item $code = $gi->country_code_by_name( $hostname );

Returns the ISO 3166 country code for a hostname.

=item $code = $gi->country_code3_by_addr( $ipaddr );

Returns the 3 letter country code for an IP address.

=item $code = $gi->country_code3_by_name( $hostname );

Returns the 3 letter country code for a hostname.

=item $name = $gi->country_name_by_addr( $ipaddr );

Returns the full country name for an IP address.

=item $name = $gi->country_name_by_name( $hostname );

Returns the full country name for a hostname.

=item $r = $gi->record_by_addr( $ipaddr );

Returns a Geo::IP::Record object containing city location for an IP address.

=item $r = $gi->record_by_name( $hostname );

Returns a Geo::IP::Record object containing city location for a hostname.

=item $org = $gi->org_by_addr( $ipaddr ); B<depreciated> use C<name_by_addr> instead.

Returns the Organization, ISP name or Domain Name for an IP address.

=item $org = $gi->org_by_name( $hostname );  B<depreciated> use C<name_by_name> instead.

Returns the Organization, ISP name or Domain Name for a hostname.

=item $info = $gi->database_info;

Returns database string, includes version, date, build number and copyright notice.

=item $old_charset = $gi->set_charset( $charset );

Set the charset for the city name - defaults to GEOIP_CHARSET_ISO_8859_1.  To
set UTF8, pass GEOIP_CHARSET_UTF8 to set_charset.
For perl >= 5.008 the utf8 flag is honored.

=item $charset = $gi->charset;

Gets the currently used charset.

=item ( $country, $region ) = $gi->region_by_addr('24.24.24.24');

Returns a list containing country and region. If region and/or country is
unknown, undef is returned. Sure this works only for region databases.

=item ( $country, $region ) = $gi->region_by_name('www.xyz.com');

Returns a list containing country and region. If region and/or country is
unknown, undef is returned. Sure this works only for region databases.

=item $netmask = $gi->last_netmask;

Gets netmask of network block from last lookup.

=item $gi->netmask(12);

Sets netmask for the last lookup

=item my ( $from, $to ) = $gi->range_by_ip('24.24.24.24');

Returns the start and end of the current network block. The method tries to join several continous netblocks.

=item $api = $gi->api or $api = Geo::IP->api

Returns the currently used API.

  # prints either CAPI or PurePerl
  print Geo::IP->api;

=item $continent = $gi->continent_code_by_country_code('US');

Returns the continentcode by country code.

=item $dbe = $gi->database_edition

Returns the database_edition of the currently opened database.

  if ( $gi->database_edition == GEOIP_COUNTRY_EDITION ){
    ...
  }

=item $isp = $gi->isp_by_addr('24.24.24.24');

Returns the isp for 24.24.24.24

=item $isp = $gi->isp_by_name('www.maxmind.com');

Returns the isp for www.something.de

=item my $time_zone = $gi->time_zone('US', 'AZ');

Returns the time zone for country/region.

  # undef
  print  $gi->time_zone('US', '');

  # America/Phoenix
  print  $gi->time_zone('US', 'AZ');

  # Europe/Berlin
  print  $gi->time_zone('DE', '00');

  # Europe/Berlin
  print  $gi->time_zone('DE', '');

=item $id = $gi->id_by_addr('24.24.24.24');

Returns the country_id for 24.24.24.24. The country_id might be useful as array
index. 0 is unknown.

=item $id = $gi->id_by_name('www.maxmind.com');

Returns the country_id for www.maxmind.com. The country_id might be useful as array
index. 0 is unknown.

=item $cc = $gi->country_code3_by_addr_v6('::24.24.24.24');

=item $cc = $gi->country_code3_by_name_v6('ipv6.google.com');

=item $cc = $gi->country_code_by_addr_v6('2a02:ea0::');

=item $cc = $gi->country_code_by_ipnum_v6($ipnum);

  use Socket;
  use Socket6;
  use Geo::IP;
  my $g = Geo::IP->open('/usr/local/share/GeoIP/GeoIPv6.dat') or die;
  print $g->country_code_by_ipnum_v6(inet_pton AF_INET6, '::24.24.24.24');

=item $cc = $gi->country_code_by_name_v6('ipv6.google.com');

=item name_by_addr

Returns the Organization, ISP name or Domain Name for a IP address.

=item name_by_addr_v6

Returns the Organization, ISP name or Domain Name for an IPv6 address.

=item name_by_ipnum_v6

Returns the Organization, ISP name or Domain Name for an ipnum.

=item name_by_name

Returns the Organization, ISP name or Domain Name for a hostname.

=item name_by_name_v6

Returns the Organization, ISP name or Domain Name for a hostname.

=item org_by_addr_v6 B<depreciated> use C<name_by_addr_v6>

Returns the Organization, ISP name or Domain Name for an IPv6 address.

=item org_by_name_v6  B<depreciated> use C<name_by_name_v6>

Returns the Organization, ISP name or Domain Name for a hostname.

=item teredo

Returns the current setting for teredo.

=item enable_teredo

Enable / disable teredo

  $gi->enable_teredo(1); # enable
  $gi->enable_teredo(0); # disable

=item lib_version

  if ( $gi->api eq 'CAPI' ){
      print $gi->lib_version;
  }

=back

=head1 MAILING LISTS AND CVS

Are available from SourceForge, see
http://sourceforge.net/projects/geoip/

The direct link to the mailing list is
http://lists.sourceforge.net/lists/listinfo/geoip-perl

=head1 VERSION

1.39

=head1 SEE ALSO

Geo::IP::Record


=head1 AUTHOR

Copyright (c) 2011, MaxMind, Inc

All rights reserved.  This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut


