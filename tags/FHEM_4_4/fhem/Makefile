BINDIR=/usr/local/bin
MODDIR=/usr/local/lib
VARDIR=/var/log/fhem

VERS=4.4
DATE=2008-08-04

all:
	@echo Nothing to do for all.
	@echo To install, check the Makefile, and then \'make install\'
	@echo or \'make install-pgm2\' to install a web frontend too.

install:install-base
	cp examples/sample_fhem $(VARDIR)/fhem.cfg
	@echo
	@echo
	@echo Edit $(VARDIR)/fhem.cfg then type perl $(BINDIR)/fhem.pl $(VARDIR)/fhem.cfg

install-pgm2:install-base
	cp webfrontend/pgm2/* $(MODDIR)/FHEM
	cp docs/commandref.html docs/faq.html docs/HOWTO.html $(MODDIR)/FHEM
	cp examples/sample_pgm2 $(VARDIR)/fhem.cfg
	cd examples; for i in *; do cp $$i $(MODDIR)/FHEM/example.$$i; done
	@echo
	@echo
	@echo Edit $(VARDIR)/fhem.cfg then start perl $(BINDIR)/fhem.pl $(VARDIR)/fhem.cfg

install-base:
	cp fhem.pl $(BINDIR)
	cp -r FHEM $(MODDIR)
	mkdir -p $(VARDIR)
	perl -pi -e 's,modpath \.,modpath $(MODDIR),' examples/*
	perl -pi -e 's,/tmp,$(VARDIR),' examples/*

dist:
	@echo Version is $(VERS), Date is $(DATE)
	mkdir .f
	cp -r CHANGED FHEM HISTORY Makefile README.CVS em1010pc\
                TODO contrib docs examples fhem.pl test webfrontend .f
	find .f -name CVS -print | xargs rm -rf
	find .f -name \*.orig -print | xargs rm -f
	find .f -name .#\* -print | xargs rm -f
	find .f -type f -print |\
		xargs perl -pi -e 's/=VERS=/$(VERS)/g;s/=DATE=/$(DATE)/g'
	mv .f fhem-$(VERS)
	tar cf - fhem-$(VERS) | gzip > fhem-$(VERS).tar.gz
	mv fhem-$(VERS)/docs/*.html .
	rm -rf fhem-$(VERS)
