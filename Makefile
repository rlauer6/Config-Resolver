#-*- mode: makefile; -*-
SHELL := /bin/bash

.SHELLFLAGS := -ec

MODULE = Config::Resolver

VERSION := $(shell cat VERSION)

TARBALL = Config-Resolver-$(VERSION).tar.gz

all: $(TARBALL)

PERL_MODULES = \
    lib/Config/Resolver.pm.in \
    lib/Config/Resolver/Utils.pm.in

GPERL_MODULES = $(PERL_MODULES:.pm.in=.pm)

BIN_SCRIPTS = \
    bin/config-resolver.pl.in

GBIN_SCRIPTS = $(BIN_SCRIPTS:.pl.in=.pl)

$(GBIN_SCRIPTS): $(BIN_SCRIPTS)

$(GPERL_MODULES): $(PERL_MODULES)


%.pl: %.pl.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' $< > $@
	chmod +x $@

%.pm: %.pm.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' $< > $@

$(TARBALL): buildspec.yml $(GPERL_MODULES) $(GBIN_SCRIPTS) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: $(GPERL_MODULES)
	pod2markdown $< > $@

include version.mk

clean:
	rm -f *.tar.gz $(GPERL_MODULES) $(GBIN_SCRIPTS)
