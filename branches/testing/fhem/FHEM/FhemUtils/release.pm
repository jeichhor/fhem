################################################################
# $Id:$
package main;
use strict;
use warnings;

use vars qw($DISTRIB_ID);
use vars qw($DISTRIB_RELEASE);
use vars qw($DISTRIB_BRANCH);
use vars qw($DISTRIB_DESCRIPTION);
use vars qw(%UPDATE);

$DISTRIB_ID="Fhem";
$DISTRIB_RELEASE="5.2";
$DISTRIB_BRANCH="EXPERIMENTAL";
$DISTRIB_DESCRIPTION="$DISTRIB_ID $DISTRIB_RELEASE ($DISTRIB_BRANCH)";

$UPDATE{server}   = "http://fhem.de";
$UPDATE{path}     = "fhemupdate3";
$UPDATE{packages} = "FHEM PGM2";

1;
