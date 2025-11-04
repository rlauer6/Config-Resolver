#-*- mode: makefile; -*-
SHELL := /bin/bash

.SHELLFLAGS := -ec

MODULE = Config::Resolver

PERL_MODULES = \
    lib/Config/Resolver.pm \
    lib/Config/Resolver/Utils.pm

BIN_SCRIPTS = \
    bin/config-resolver.pl

VERSION := $(shell cat VERSION)

TARBALL = Config-Resolver-$(VERSION).tar.gz

all: $(TARBALL)

%.pl: %.pl.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' $< > $@
	chmod +x $@

%.pm: %.pm.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' $< > $@

$(TARBALL): buildspec.yml $(PERL_MODULES) $(BIN_SCRIPTS) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: $(PERL_MODULES)
	pod2markdown $< > $@

include version.mk

clean:
	rm -f *.tar.gz
	find . -name '*.p[ml]' -exec rm {} \;
