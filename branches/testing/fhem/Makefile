#####
# Distribution
VERS=5.2
DATE=2011-12-31
DIST=fhem-$(VERS)

#####
# Default paths where Fhem will be installed 
# Change it wisely!
ETCDIR = /etc
BINDIR = /usr/bin
DOCDIR = /usr/share/doc/fhem
MODDIR = /usr/share/fhem
MANDIR = /usr/share/man/man1
VARDIR = /var/log/fhem
WWWDIR = $(MODDIR)/www

#####
# Used for .deb package creation
RETCDIR = $(ROOT)$(ETCDIR)
RBINDIR = $(ROOT)$(BINDIR)
RDOCDIR = $(ROOT)$(DOCDIR)
RMODDIR = $(ROOT)$(MODDIR)
RMANDIR = $(ROOT)$(MANDIR)
RVARDIR = $(ROOT)$(VARDIR)
RWWWDIR = $(ROOT)$(WWWDIR)

#####
# Destination directories for base files
BASEDEST  = $(RETCDIR)
BASEDEST += $(RBINDIR)
BASEDEST += $(RDOCDIR)
BASEDEST += $(RMODDIR)
BASEDEST += $(RMANDIR)
BASEDEST += $(RVARDIR)
# Destination directories for pgm2 (FHEMWEB)
PGM2DEST  = $(RWWWDIR)/docs
PGM2DEST += $(RWWWDIR)/gplot
PGM2DEST += $(RWWWDIR)/images
PGM2DEST += $(RWWWDIR)/images/dark
PGM2DEST += $(RWWWDIR)/images/default
PGM2DEST += $(RWWWDIR)/images/default/weather
PGM2DEST += $(RWWWDIR)/images/smallscreen
PGM2DEST += $(RWWWDIR)/pgm2

all:
	@echo "fhem $(VERS) - $(DATE)"
	@echo
	@echo "Use 'make <target>', where <target> is"
	@echo "    install       - to install base files for fhem with webgui pgm2 (FHEMWEB)"
	@echo "    dist          - to create a compressed archivfile of fhem"
	@echo "    deb           - to create a .deb file of fhem"
	@echo "    fb7390        - to create an imagefile for AVM Fritz!Box 7390"
	@echo "    fb7270        - to create an imagefile for AVM Fritz!Box 7270"
	@echo "    backup        - to backup current installation of fhem"
	@echo "    uninstall     - to uninstall an existing fhem installation (with backup)"
	@echo
	@echo "Examples:"
	@echo "    make install"
	@echo "    make deb"
	@echo
	@echo "Check Makefile for default installation paths!"
	@echo

prepare:
	@echo "==> Preparing installation for fhem..."
	@echo "- create directories"
	@-$(foreach DIR,$(BASEDEST), if [ ! -e $(DIR) ]; then mkdir -p $(DIR); fi; )
	@echo "- fix permissions"
	@find ./FHEM -type f -print | xargs chmod 644
	@find ./docs -type f -print | xargs chmod 644
	@find ./examples -type f -print | xargs chmod 644
	@echo "- modify examples"
	@rm -rf examples_changed
	@cp -r examples examples_changed
	@perl -pi -e 's,modpath \.,modpath $(MODDIR),' examples_changed/[a-z]*
	@perl -pi -e 's,([^h]) /tmp,$$1 $(VARDIR),' examples_changed/[a-z]*
	@-if [ -e $(RETCDIR)/fhem.cfg ]; then \
		echo "- move existing configuration to fhem.cfg.`date "+%Y-%m-%d_%H:%M:%S"`"; \
		mv $(RETCDIR)/fhem.cfg $(RETCDIR)/fhem.cfg.`date "+%Y-%m-%d_%H:%M:%S"`; fi;
	@echo

install: prepare install-base install-pgm2 install-note

install-base:
	@echo "==> Install base files of fhem..."
	cp examples_changed/sample_fhem $(RETCDIR)/fhem.cfg
	cp fhem.pl $(RBINDIR)
	cp -r FHEM $(RMODDIR)
	cp -rp contrib $(RMODDIR)
	cp -rp docs/* $(RDOCDIR)
	cp docs/fhem.man $(RMANDIR)/fhem.pl.1
	gzip -f -9 $(RMANDIR)/fhem.pl.1

install-pgm2:
	@echo
	@echo "==> Install files of pgm2 (FHEMWEB) webgui..."
	@echo "- create directories"
	@-$(foreach DIR,$(PGM2DEST), if [ ! -e $(DIR) ]; then mkdir -p $(DIR); fi; )
	@echo "- fix permissions"
	@find ./www/* -type f -print | xargs chmod 644
	cp -r www/* $(RWWWDIR)/
	cp docs/commandref.html docs/faq.html docs/HOWTO.html $(RWWWDIR)/docs
	cp docs/*.png docs/*.jpg $(RWWWDIR)/docs
	cp examples_changed/sample_pgm2 $(RETCDIR)/fhem.cfg

install-note:
	@echo
	@echo "==> Housekeeping..."
	@rm -rf examples_changed
	@echo "- remove .svn stuff"
	find $(RMODDIR) -name .svn -print | xargs rm -rf
	find $(RDOCDIR) -name .svn -print | xargs rm -rf
	find $(RWWWDIR) -name .svn -print | xargs rm -rf
	@echo
	@echo "Installation of fhem completed!"
	@echo
	@echo "To start fhem use"
	@echo "<perl $(BINDIR)/fhem.pl $(ETCDIR)/fhem.cfg>"
	@echo

backup:
	@echo
	@echo "==> Backup current installation of fhem to .backup directory.."
	@-if [ ! -e .backup ]; then mkdir .backup; fi;
	@tar czf .backup/fhem-backup_`date +%y%m%d%H%M`.tar.gz \
		$(RETCDIR)/fhem* $(RBINDIR)/fhem* $(RDOCDIR) $(RMODDIR) $(RMANDIR)/fhem* $(RVARDIR)

uninstall: backup
	@echo
	@echo "==> Remove fhem installation..."
	rm -rf $(RETCDIR)/fhem.cfg
	rm -rf $(RBINDIR)/fhem.pl
	rm -rf $(RDOCDIR)
	rm -rf $(RMODDIR)
	rm -rf $(RMANDIR)/fhem.pl.*
	rm -rf $(RVARDIR)
	@echo done
	@echo

dist:
	@echo "fhem $(VERS) - $(DATE)"
	@echo
	@echo "==> Make distribution..."
	@echo "- copy files"
	@mkdir .f
	@cp -r CHANGED FHEM HISTORY Makefile README.SVN\
                TODO contrib docs examples fhem.pl webfrontend www .f
	@echo
	@echo "==> Housekeeping..."
	@echo "- remove misc developing stuff"
	@find .f -name .svn -print | xargs rm -rf
	@find .f -name \*.orig -print | xargs rm -f
	@find .f -name .#\* -print | xargs rm -f
	@find .f -type f -print | grep -v Makefile |\
		xargs perl -pi -e 's/=VERS=/$(VERS)/g;s/=DATE=/$(DATE)/g'
	@mv .f $(DIST)
	@echo
	@echo "==> Distribution..."
	@echo "- create archiv"
	@tar cf - $(DIST) | gzip > $(DIST).tar.gz
	@echo "- copy main documentation files"
	@mv $(DIST)/docs/*.html .
	@echo "- Housekeeping"
	@rm -rf $(DIST)
	@echo
	@echo "Done. Provided files: $(DIST).tar.gz *.html"
	@echo

dist-clean:
	@echo
	@echo "==> Housekeeping..."
	@echo "- remove distribution files"
	@rm -rf *.html $(DIST).tar.gz
	@echo done
	@echo

deb:
	@echo "==> Make debian package..."
	@rm -rf .f
	make ROOT=`pwd`/.f build-deb
	@echo
	@echo "==> Build package..."
	@dpkg-deb --build $(DIST)
	@echo
	@echo "==> Housekeeping..."
	@echo "- remove temporarily directories"
	@rm -rf $(DIST)
	@rm -rf examples_changed
	@echo
	@echo "Done. Provided file: $(DIST).deb"
	@echo

build-deb: prepare install-base install-pgm2
	@echo
	@echo "- copy files"
	@cp -r contrib/DEBIAN .f
	@echo "- housekeeping"
	@rm -rf .f/$(MODDIR)/contrib/FB7*/var
	@rm -rf .f/$(MODDIR)/contrib/FB7*/*.image
	@rm -rf .f/$(MODDIR)/contrib/FB7*/*.zip
	@find .f -name .svn -print | xargs rm -rf
	@find .f -name \*.orig -print | xargs rm -f
	@find .f -name .#\* -print | xargs rm -f
	@echo "- modify fhem version and date"
	@find .f -type f -print | grep -v Makefile |\
		xargs perl -pi -e 's/=VERS=/$(VERS)/g;s/=DATE=/$(DATE)/g'
	@echo "- fix permissions"
	@find .f -type f | xargs chmod 644
	@find .f -type d | xargs chmod 755
	@chmod 755 `cat contrib/executables`
	@gzip -9 .f/$(DOCDIR)/changelog
	@echo "- fix ownership"
	@chown -R root:root .f
	@echo "- housekeeping"
	@mv .f $(DIST)

fb7390:
	@echo "==> Build $(DIST) image for Fritz!Box 7390..."
	cd contrib/FB7390 && ./makeimage $(DIST)
	@cd ../..
	@-if [ ! -e contrib/FB7390/$(DIST)-fb7390.image ]; then \
		echo "Something went wrong! Check manualy"; \
	else \
		echo "Done. Provided file: contrib/FB7390/$(DIST)-fb7390.image"; \
	fi

fb7270:
	@echo "==> Build $(DIST) image for Fritz!Box 7270..."
	cd contrib/FB7270 && ./makeimage $(DIST)
	@cd ../..
	@-if [ ! -e contrib/FB7270/$(DIST)-fb7270.zip ]; then \
		echo "Something went wrong! Check manualy"; \
	else \
		echo "Done. Provided file: contrib/FB7270/$(DIST)-fb7270.zip"; \
	fi

$(DIST):
	@echo
