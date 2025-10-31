#-*- mode: makefile; -*-

MODULE = Config::Resolver

PERL_MODULES = \
    lib/Config/Resolver.pm \
    lib/Config/Resolver/Plugin/SSM.pm \
    lib/Config/Resolver/Utils.pm

VERSION := $(shell cat VERSION)

TARBALL = Config-Parser-$(VERSION).tar.gz

all: $(TARBALL)

%.pm: %.pm.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' $< > $@

$(TARBALL): buildspec.yml $(PERL_MODULES) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: $(PERL_MODULES)
	pod2markdown $< > $@

include version.mk

clean:
	rm -f *.tar.gz
