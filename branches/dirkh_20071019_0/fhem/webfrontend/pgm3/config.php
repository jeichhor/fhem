<?php

##################################################################################
#### pgm3 -- a PHP-webfrontend for fhz1000.pl 


###### required settings
	$fhz1000="localhost"; #only php5 ! On which machine is fhem runnning??
					# if it is not localhost then the fhem.cfg must
					# run global: "port <nr> global"
	$fhz1000port="7072";		# port of fhem.pl
	$logpath="/var/tmp";		# where are your logs?
	$fhz1000_pl="/home/FHZ/fhem/fhem.pl"; #only required if you are using PHP4

##################################################################################
###### nice to have


###### showgnuplot 
	# Gnuplot will automatically show the pictures.
	# There is no reason any more to deactivate Gnuplot. Values: 0/1
	$showgnuplot=1;
	$gnuplot='/usr/bin/gnuplot';		# location of gnuplot
	$pictype='png';  	

#####	logrotate of hms, ks300, fht
	# this is only possible, if the webserver (e.g.wwwrun) has the rights ro write the
	# files from fh1000.pl. If you want that then run fhz1000.pl as wwwrun too.
	# if 'yes' then only the needed lines are in the logfiles, the rest will be deleted.
	$logrotate='yes';	# yes/no default='no'


## Kioskmode. Only show but don't switch anything. Values: on/off
	$kioskmode='off';




##############################################################################################
## FHZ-DEVICES
	$show_general=1; 		#field to type FHZ1000-orders 0/1 Default:1
	$show_fs20pulldown=1; 		#Pull-Down for the FS20 Devices 0/1 Default:1
	$show_fhtpulldown=1; 		#Pull-Down for the FHT-Devices 0/1 Default:1




##############################################################################################
## FS20-Device, adjust it if you have e.g. long titles
	$imgmaxxfs20=85;  		#Size of the pictures, default=85
        $imgmaxyfs20=85; 		# default=85 
	$fs20fontsizetitel=10;  	# default=10 
	$fs20maxiconperline=9; 	# default=9

					#room. Write e.g. "attr rolowz room wzo" 
					#into your fhz1000.cfg and restart fhz1000.pl
					# this will be marked on the FS20-Button. 
	$txtroom=""; 			# default=""; example: $txtroom="room: ";
					# room hidden will not be shown

##############################################################################################
## ROOMS adjust it if you have e.g. long titles
	$showroombuttons=1; 		#default 1  Values 0/1
	$imgmaxxroom=$imgmaxxfs20;  	#Size of the pictures, default=$imgmaxxfs20
        $imgmaxyroom=30; 		# default=30 
	$roomfontsizetitel=10;  	# default=10
	$roommaxiconperline=$fs20maxiconperline; # default=$fs20maxiconperline

##############################################################################################

## FHT-Devices
        $imgmaxxfht=725;  			#Size of the pictures Default: 725
        $imgmaxyfht=52;
        $show_desiredtemp=1;                    # show the desired_temp as a graphic (0/1)
        $desR='255'; $desG='255'; $desB='255';  # Color of desired-temp-line Red/Green/Blue (Default: 255/255/255) 
        $show_actuator=1;                       # show the actuator-value as a graphic (0/1)
        $actR='255'; $actG='247'; $actB='200';  # Color of Actuator-line Red/Green/Blue (Default: 255/247/200)
        $FHTyrange='15:31';                     # Temperature in gnuplot. Default 15 to 31 (Celsius)
        $FHTy2range='0:70';                     # Actuator in gnuplot. Default 0 to 70 (Percent)
        $maxcount='510';                        # Maximum count of pixel (from right to left) (Default:460)
        $XcorrectDate=380;                      # Text of e.g. Date from the right side (Default:380)
        $XcorrectMainText=32;                   # Text of main text from the right side (Default: 32)
        $logrotateFHTlines=4800;                # automatic Logrotate; $logrotate must be 'yes'.
                                                # Default:4800
                                                # read docs/logrotate if you want adjust it manually!
                                                # otherwise the system will slow down
                                                # pgm3 (user www-data) needs the rights to write the logs
                                                # from fhz1000.pl (user = ???)




##############################################################################################
## HMS-Devices
        $imgmaxxhms=725;  #Size of the pictures. Default:  725
        $imgmaxyhms=52;
        $maxcountHMS='575';                     # Maximum count of pixel (from right to left) (Default:575)
        $XcorrectMainTextHMS=25;                # Text of main text from the right side (Default:)
        $logrotateHMSlines=1200;                # automatic Logrotate; $logrotate must be 'yes'.
                                                # Default:1200
                                                # read docs/logrotate if you want adjust it manually!
                                                # otherwise the system will slow down
                                                # pgm3 (user www-data) needs the rights to write the logs
                                                # from fhz1000.pl (user = ???)

##############################################################################################
## KS300-Device
        $imgmaxxks=725;                 #Size of the pictures  Default: 725

        $imgmaxyks=52;
        $showbft=1;                     # Display values additionaly in Beafort. Values: 0 /1 Default:1
        $maxcountKS='575';              # Maximum count of pixel (from right to left) (Default:575)
        $XcorrectMainTextKS=45;         # Text of main text from the right side (Default: 35)

        $logrotateKS300lines=2100;      # automatic Logrotate; $logrotate must be 'yes'.
                                        # Default:2100
                                        # read docs/logrotate if you want adjust it manually
                                        # otherwise the system will slow down
                                        # pgm3 (user www-data) needs the rights to write the logs
                                        # from fhz1000.pl (user = ???)

##############################################################################################
## USERDEF
#
# Create your own graphics! If you have separate Programs (e.g. wired devices) then create your own 
# logfile and tell pgm3  to use it.
# We only need a data/time-field in the form <date>_<time>, e.g. 2007-10-13_13:45:14
# and a field with a numeric value e.g. 0.0

#Example: 
####################################################
# 2007-10-13_13:45:14 solarI Is: 0.0 Vs: 4.5 T: 22
####################################################
# Field1: 2007-10-13_13:45:14
# Field2: solarI
# Field3: Is:
# Field4: 0.0
#...
# Field1 must be the date/time-field. Then tell pgm3 with $userdef[x]['valuefield'] (see below)
# the field with the needed value. It is possible to create several graphics with on logfile.


# Do you want user defined graphics? 1/0 Default: 0	
$UserDefs=0;

#####################
## Userdef: 0

# No blanks or other special signs!!
$userdef[0]['name']='SolarV';	

#In which field are the values?? See the example above
$userdef[0]['valuefield']=4;	

#Type of Device [temperature | piri | fs20] pgm3 will try to generate a gnuplot picture
$userdef[0]['gnuplottype']='temperature';	

# example, path to the logfile with the entrys like above
$userdef[0]['logpath']=$logpath.'/lse_solarV.log';   

$userdef[0]['room']='user';

# Semantic eg. Voltage
$userdef[0]['semlong']='Voltage'; 	

# Semantic short e.g. V
$userdef[0]['semshort']='V';

#Size of the pictures. Default:  725
$userdef[0]['imagemax']=725;
$userdef[0]['imagemay']=52;

# Maximum count of pixel (from right to left) (Default:575)
$userdef[0]['maxcount']=575;

 # Text of main text from the right side (Default:)
$userdef[0]['XcorrectMainText']=25;               

# automatic Logrotate; $logrotate must be 'yes'.
# Default:2200
# read docs/logrotate if you want adjust it manually!
# otherwise the system will slow down
# pgm3 (user www-data) needs the rights to write the logs
# from fhz1000.pl (user = ???)
$userdef[0]['logrotatelines']=2200;  


#################
## Userdef: 1
# 
#$userdef[1]['name']='';	
#$userdef[1]['valuefield']=;	
#$userdef[1]['gnuplottype']='temperature';	
#$userdef[1]['logpath']='/var/tmp/log.log';   
#$userdef[1]['room']='';
#$userdef[1]['semlong']=''; 	
#$userdef[1]['semshort']='';
#$userdef[1]['imagemax']=725;
#$userdef[1]['imagemay']=52;
#$userdef[1]['maxcount']=575;
#$userdef[1]['XcorrectMainText']=25;               
#$userdef[1]['logrotatelines']=2200;  

########################
# example: 
# define piriulog FileLog /var/tmp/piriu.log piriu:.*
#$userdef[1]['name']='PiriU';	
#$userdef[1]['valuefield']=3;	
#$userdef[1]['gnuplottype']='piri';	
#$userdef[1]['logpath']='/mnt/fhz/piriu.log';   
#$userdef[1]['room']='wgu';
#$userdef[1]['semlong']='Bewegungsmelder'; 	
#$userdef[1]['semshort']='';
#$userdef[1]['imagemax']=725;
#$userdef[1]['imagemay']=52;
#$userdef[1]['maxcount']=575;
#$userdef[1]['XcorrectMainText']=25;               
#$userdef[1]['logrotatelines']=2200;  

########################
# example: 
# define piriolog FileLog /var/tmp/pirio.log pirio:.*
#$userdef[2]['name']='PiriO';	
#$userdef[2]['valuefield']=3;	
#$userdef[2]['gnuplottype']='piri';	
#$userdef[2]['logpath']='/mnt/fhz/pirio.log';   
#$userdef[2]['room']='wgo';
#$userdef[2]['semlong']='Bewegungsmelder'; 	
#$userdef[2]['semshort']='';
#$userdef[2]['imagemax']=725;
#$userdef[2]['imagemay']=52;
#$userdef[2]['maxcount']=575;
#$userdef[2]['XcorrectMainText']=25;               
#$userdef[2]['logrotatelines']=2200;  
#

########################
# example: 
#define solarpumpe.log FileLog /var/tmp/solarpumpe.log solarpumpe:.*(on|off).*
#$userdef[3]['name']='SolarPumpe';	
#$userdef[3]['valuefield']=3;	
#$userdef[3]['gnuplottype']='fs20';	
#$userdef[3]['logpath']='/mnt/fhz/solarpumpe.log';   
#$userdef[3]['room']='cellar';
#$userdef[3]['semlong']='Solarpumpe'; 	
#$userdef[3]['semshort']='';
#$userdef[3]['imagemax']=725;
#$userdef[3]['imagemay']=52;
#$userdef[3]['maxcount']=575;
#$userdef[3]['XcorrectMainText']=25;               
#$userdef[3]['logrotatelines']=50;  
#

##########################
# example: 
#define rolu1.log FileLog /var/tmp/rolu1.log rolu1:.*(on|off|dimup|dimdown).*
#$userdef[4]['name']='Rolu1';	
#$userdef[4]['valuefield']=3;	
#$userdef[4]['gnuplottype']='fs20';	
#$userdef[4]['logpath']='/mnt/fhz/rolu1.log';   
#$userdef[4]['room']='wgu';
#$userdef[4]['semlong']='Rolladen'; 	
#$userdef[4]['semshort']='';
#$userdef[4]['imagemax']=725;
#$userdef[4]['imagemay']=52;
#$userdef[4]['maxcount']=575;
#$userdef[4]['XcorrectMainText']=25;               
#$userdef[4]['logrotatelines']=30;  
#
#################
## Userdef: x
#
#$userdef[x]['name']='';	
#........ 



########################








##############################################################################################
## misc
	$taillog=1; 			#make shure to have the correct rights. Values: 0/1
	$tailcount=20; 			#make shure to have the correct rights. Values: 0/1
	$taillogorder="/usr/bin/tail -$tailcount $logpath/fhem.log ";



## show Information at startup. 
	$showLOGS='no';			#show the LOGS at startup. Default: no Values: yes/no
	$showAT='no';			#show the AT_JOBS at startup. Default: yes Values: yes/no
	$showNOTI='no';		 	#show the NOTIFICATIONS at startup. Default: no Values: yes/no
	$showHIST='yes';		 	#show the HISTORY (if taillog=1) at startup. Default: yes Values: yes/no



	$urlreload=90;			# Automatic reloading page [sec]. Default fast: 60 slow:90
	$titel="PHP-Webmachine for fhem :-)"; #feel free to create an own title
	$timeformat="Y-m-d H:i:s";
	$winsize=800;			# width of the pgm3
	$bodybg="bgcolor='#F5F5F5'"; 
	$bg1="bgcolor='#6E94B7'";
	$bg2="bgcolor='#AFC6DB'";
	$bg3="bgcolor='#F8F8F8'";
	$bg4="bgcolor='#6394BD'";
	$fontcolor1="color='#FFFFFF'";
	
	$fontcolor3="color='143554'";
	$fontcol_grap_R=20;
	$fontcol_grap_G=53;
	$fontcol_grap_B=84;
	$fontttf="Vera";
	$fontttfb="VeraBd"; 		##copyright of the fonts: docs/copyright_font
	   ## if there is now graphic try the following:
	    #	$fontttf="Vera.ttf";
	    #	$fontttfb="VeraBd.ttf";
	    # or absolut:
	    #	$fontttf="/srv/www/htdocs/fhz/include/Vera.ttf";
	    #	$fontttfb="/srv/www/htdocs/fhz/include/VeraBd.ttf";

###############################   end of settings
	putenv('GDFONTPATH=' . realpath('.')); 

?>
