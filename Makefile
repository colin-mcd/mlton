export TARGET = self
export TARGET_ARCH = $(shell bin/host-arch)
export TARGET_OS = $(shell bin/host-os)
ROOT = $(shell pwd)
BUILD = $(ROOT)/build
SRC = $(ROOT)
BIN = $(BUILD)/bin
LIB = $(BUILD)/lib
COMP = $(SRC)/mlton
RUN = $(SRC)/runtime
MLTON = $(BIN)/mlton
AOUT = mlton-compile
MLBPATHMAP = $(LIB)/mlb-path-map
TARGETMAP = $(LIB)/target-map
SPEC = $(SRC)/doc/mlton.spec
LEX = mllex
PROF = mlprof
YACC = mlyacc
PATH = $(BIN):$(shell echo $$PATH)
CP = /bin/cp -fpR
GZIP = gzip --force --best

VERSION = $(shell date +%Y%m%d)
RELEASE = 1

.PHONY: all
all:
	$(MAKE) docs all-no-docs

.PHONY: all-no-docs
all-no-docs:
	$(MAKE) dirs runtime compiler world-no-check
# If we're compiling with another version of MLton, then we want to do
# another round of compilation so that we get a MLton built without
# stubs.  Remove $(AOUT) so that the $(MAKE) compiler below will
# remake MLton.
ifeq (other, $(shell if [ ! -x $(BIN)/mlton ]; then echo other; fi))
	rm -f $(COMP)/$(AOUT)
endif
	$(MAKE) script mlbpathmap targetmap constants compiler world libraries tools
	@echo 'Build of MLton succeeded.'

.PHONY: basis
basis:
	rm -rf $(LIB)/sml
	mkdir $(LIB)/sml
	$(CP) $(SRC)/basis-library $(LIB)/sml/basis
	find $(LIB)/sml -type f -name .cvsignore | xargs rm -rf

.PHONY: bootstrap-nj
bootstrap-nj:
	$(MAKE) nj-mlton
	$(MAKE) all

.PHONY: clean
clean:
	bin/clean

.PHONY: clean-cvs
clean-cvs:
	find . -type d | grep CVS | xargs rm -rf

.PHONY: cm
cm:
	$(MAKE) -C $(COMP) mlton-stubs_cm
	$(MAKE) -C $(LEX) mllex_cm
	$(MAKE) -C $(PROF) mlprof_cm
	$(MAKE) -C $(YACC) mlyacc_cm
	$(MAKE) -C benchmark benchmark_cm

.PHONY: compiler
compiler:
	$(MAKE) -C $(COMP)
	$(CP) $(COMP)/$(AOUT) $(LIB)/

.PHONY: constants
constants:
	@echo 'Creating constants file.'
	$(BIN)/mlton -build-constants true >tmp.c
	$(BIN)/mlton -output tmp tmp.c
	./tmp >$(LIB)/$(TARGET)/constants
	rm -f tmp tmp.c

DEBSRC = mlton-$(VERSION).orig
.PHONY: deb
deb:
	$(MAKE) clean clean-cvs version
	tar -cpf - . | \
		( cd .. && mkdir $(DEBSRC) && cd $(DEBSRC) && tar -xpf - )
	cd .. && tar -cpf - $(DEBSRC) | $(GZIP) >mlton_$(VERSION).orig.tar.gz
	cd .. && mv $(DEBSRC) mlton-$(VERSION)
	cd ../mlton-$(VERSION) && pdebuild --pbuilderroot ss

.PHONY: deb-binary
deb-binary:
	fakeroot debian/rules binary

.PHONY: deb-change
deb-change:
	(								\
		echo 'mlton ($(VERSION)-1) unstable; urgency=low';	\
		echo;							\
		echo '  * new upstream version';			\
		echo;							\
		echo ' -- Stephen Weeks <sweeks@sweeks.com>  '`date -R`;\
		echo;							\
		cat debian/changelog;					\
	) >/tmp/changelog
	mv /tmp/changelog debian/changelog

.PHONY: deb-lint
deb-lint:
	lintian ../mlton_$(VERSION)-1_i386.deb

.PHONY: deb-spell
deb-spell:
	ispell -g debian/control

.PHONY: dirs
dirs:
	mkdir -p $(BIN) $(LIB)/$(TARGET) $(LIB)/include

.PHONY: docs
docs: dirs
	$(MAKE) -C $(SRC)/doc/user-guide
	$(MAKE) -C $(LEX) docs
	$(MAKE) -C $(YACC) docs

BSDSRC = /tmp/mlton-$(VERSION)
.PHONY: freebsd
freebsd:
	$(MAKE) clean clean-cvs version
	rm -rf $(BSDSRC)
	mkdir -p $(BSDSRC)
	( cd $(SRC) && tar -cpf - . ) | ( cd $(BSDSRC) && tar -xpf - )
	cd /tmp && tar -cpf - mlton-$(VERSION) | \
		 $(GZIP) >/usr/ports/distfiles/mlton-$(VERSION)-1.freebsd.src.tgz
	cd $(BSDSRC)/freebsd && make build-package
#	rm -rf $(BSDSRC)

.PHONY: libraries
libraries:
	$(CP) $(SRC)/lib/mlyacc $(LIB)/sml/mlyacc-lib
	@echo 'Type checking mlyacc-lib library.'
	$(MLTON) -disable-ann deadCode \
		-stop tc \
		'$$(MLTON_ROOT)/mlyacc-lib/mlyacc-lib.mlb' \
		>/dev/null
	$(CP) $(SRC)/lib/cml $(LIB)/sml/cml
	@echo 'Type checking cml library.'
	$(MLTON) -disable-ann deadCode \
		-stop tc \
		'$$(MLTON_ROOT)/cml/cml.mlb' \
		>/dev/null

.PHONY: nj-mlton
nj-mlton:
	$(MAKE) dirs runtime 
	$(MAKE) -C $(COMP) nj-mlton
	$(MAKE) script basis mlbpathmap targetmap constants libraries
	@echo 'Build of MLton succeeded.'

.PHONY: nj-mlton-dual
nj-mlton-dual:
	$(MAKE) dirs runtime
	$(MAKE) -C $(COMP) nj-mlton-dual
	$(MAKE) script basis mlbpathmap targetmap constants libraries
	@echo 'Build of MLton succeeded.'

.PHONY: mlbpathmap
mlbpathmap:
	touch $(MLBPATHMAP)
	( echo 'MLTON_ROOT $$(LIB_MLTON_DIR)/sml' ) 	\
		>>$(MLBPATHMAP).tmp
	mv $(MLBPATHMAP).tmp $(MLBPATHMAP)

.PHONY: profiled
profiled:
	$(MAKE) -C $(COMP) AOUT=$(AOUT).alloc COMPILE_ARGS='-profile alloc'
	$(CP) $(COMP)/$(AOUT).alloc $(LIB)/
	$(MAKE) -C $(COMP) AOUT=$(AOUT).count COMPILE_ARGS='-profile count'
	$(CP) $(COMP)/$(AOUT).count $(LIB)/
	$(MAKE) -C $(COMP) AOUT=$(AOUT).time COMPILE_ARGS='-profile time'
	$(CP) $(COMP)/$(AOUT).time $(LIB)/
	$(LIB)/$(AOUT).alloc @MLton -- $(LIB)/world.alloc
	$(LIB)/$(AOUT).count @MLton -- $(LIB)/world.count
	$(LIB)/$(AOUT).time @MLton -- $(LIB)/world.time
	sed 's/mlton-compile/mlton-compile.alloc/' < $(MLTON) | sed 's/world.mlton/world.alloc.mlton/' > $(MLTON).alloc
	sed 's/mlton-compile/mlton-compile.count/' < $(MLTON) | sed 's/world.mlton/world.count.mlton/' > $(MLTON).count
	sed 's/mlton-compile/mlton-compile.time/' < $(MLTON) | sed 's/world.mlton/world.time.mlton/' > $(MLTON).time
	chmod a+x $(MLTON).alloc
	chmod a+x $(MLTON).count
	chmod a+x $(MLTON).time

TOPDIR = 'TOPDIR-unset'
SOURCEDIR = $(TOPDIR)/SOURCES/mlton-$(VERSION)
.PHONY: rpms
rpms:
	$(MAKE) clean clean-cvs version
	mkdir -p $(TOPDIR)
	cd $(TOPDIR) && mkdir -p BUILD RPMS/i386 SOURCES SPECS SRPMS
	rm -rf $(SOURCEDIR)
	mkdir -p $(SOURCEDIR)
	( cd $(SRC) && tar -cpf - . ) | ( cd $(SOURCEDIR) && tar -xpf - )
	$(CP) $(SOURCEDIR)/doc/mlton.spec $(TOPDIR)/SPECS/mlton.spec
	( cd $(TOPDIR)/SOURCES && tar -cpf - mlton-$(VERSION) )		\
		| $(GZIP) >$(SOURCEDIR).tgz
	rm -rf $(SOURCEDIR)
	rpm -ba --quiet --clean $(TOPDIR)/SPECS/mlton.spec

.PHONY: runtime
runtime:
	@echo 'Compiling MLton runtime system for $(TARGET).'
	$(MAKE) -C runtime
	$(CP) $(RUN)/*.a $(LIB)/$(TARGET)/
	$(CP) runtime/*.h include/*.h $(LIB)/include/
	mkdir -p $(LIB)/include/platform
	$(CP) runtime/platform/*.h $(LIB)/include/platform
	$(MAKE) -C bytecode
	bytecode/print-opcodes >$(LIB)/opcodes
	ar r $(LIB)/$(TARGET)/libmlton.a bytecode/interpret.o 

.PHONY: script
script:
	@echo 'Setting lib in mlton script.'
	sed "/^lib=/s;'.*';\"\`dirname \$$0\`/../lib\";" <bin/mlton >$(MLTON)
	chmod a+x $(MLTON)
	$(CP) $(SRC)/bin/platform $(LIB)

.PHONY: targetmap
targetmap:
	touch $(TARGETMAP)
	( sed '/$(TARGET)/d' <$(TARGETMAP); 			\
		echo '$(TARGET) $(TARGET_ARCH) $(TARGET_OS)' ) 	\
		>>$(TARGETMAP).tmp
	mv $(TARGETMAP).tmp $(TARGETMAP)

.PHONY: tools
tools:
	$(MAKE) -C $(LEX)
	$(MAKE) -C $(PROF)
	$(MAKE) -C $(YACC)
	$(CP) $(LEX)/$(LEX) $(PROF)/$(PROF) $(YACC)/$(YACC) $(BIN)/

.PHONY: version
version:
	@echo 'Instantiating version numbers.'
	for f in							\
		debian/changelog					\
		doc/mlton.spec						\
		doc/user-guide/macros.tex				\
		freebsd/Makefile					\
		mlton/control/control.sml; 				\
	do								\
		sed "s/\(.*\)MLTONVERSION\(.*\)/\1$(VERSION)\2/" <$$f >z && \
		mv z $$f;						\
	done
	sed <$(SPEC) >z "/^Release:/s;.*;Release: $(RELEASE);"
	mv z $(SPEC)

.PHONY: world
world: 
	$(MAKE) world-no-check
	@echo 'Type checking basis.'
	$(MLTON) -disable-ann deadCode \
		-stop tc \
		'$$(MLTON_ROOT)/basis/libs/all.mlb' \
		>/dev/null

.PHONY: world-no-check
world-no-check: 
	@echo 'Making world.'
	$(MAKE) basis
	$(LIB)/$(AOUT) @MLton -- $(LIB)/world

# The TBIN and TLIB are where the files are going to be after installing.
# The DESTDIR and is added onto them to indicate where the Makefile actually
# puts them.
DESTDIR = $(CURDIR)/install
PREFIX = /usr
ifeq ($(TARGET_OS), solaris)
PREFIX = /usr/local
endif
prefix = $(PREFIX)
MAN_PREFIX_EXTRA =
TBIN = $(DESTDIR)$(prefix)/bin
ULIB = lib/mlton
TLIB = $(DESTDIR)$(prefix)/$(ULIB)
TMAN = $(DESTDIR)$(prefix)$(MAN_PREFIX_EXTRA)/man/man1
TDOC = $(DESTDIR)$(prefix)/share/doc/mlton
ifeq ($(TARGET_OS), solaris)
TDOC = $(DESTDIR)$(prefix)/doc/mlton
endif
TEXM = $(TDOC)/examples

GZIP_MAN = true
ifeq ($(TARGET_OS), solaris)
GZIP_MAN = false
endif

.PHONY: install
install: install-docs install-no-docs

.PHONY: install-no-docs
install-no-docs:
	mkdir -p $(TLIB) $(TBIN) $(TMAN)
	$(CP) $(LIB)/. $(TLIB)/
	sed "/^lib=/s;'.*';'$(prefix)/$(ULIB)';" 			\
			<$(SRC)/bin/mlton >$(TBIN)/mlton
	chmod +x $(TBIN)/mlton
	$(CP) $(SRC)/bin/platform $(LIB)
	$(CP) $(BIN)/$(LEX) $(BIN)/$(PROF) $(BIN)/$(YACC) $(TBIN)/
	( cd $(SRC)/man && tar cf - mllex.1 mlprof.1 mlton.1 mlyacc.1 ) | \
		( cd $(TMAN)/ && tar xf - )
	if $(GZIP_MAN); then						\
		cd $(TMAN) && $(GZIP) mllex.1 mlprof.1 mlton.1		\
			mlyacc.1;					\
	fi
	if [ $(TARGET_OS) != solaris ]; then					\
	for f in $(TLIB)/$(AOUT) 						\
		$(TBIN)/$(LEX) $(TBIN)/$(PROF) $(TBIN)/$(YACC); do 		\
		strip --remove-section=.comment --remove-section=.note $$f; 	\
	done									\
	fi

.PHONY: install-docs
install-docs:
	mkdir -p $(TDOC)
	(									\
		cd $(SRC)/doc &&						\
		$(CP) changelog cm2mlb cmcat examples license README $(TDOC)/		\
	)
	rm -rf $(TDOC)/user-guide
	$(CP) $(SRC)/doc/user-guide/main $(TDOC)/user-guide
	$(GZIP) -c $(SRC)/doc/user-guide/main.ps >$(TDOC)/user-guide.ps.gz
	for f in callcc command-line hello-world same-fringe signals	\
			size taut thread1 thread2 thread-switch timeout \
		; do 							\
		$(CP) $(SRC)/regression/$$f.sml $(TEXM)/; 		\
	done
	$(GZIP) -c $(LEX)/$(LEX).ps >$(TDOC)/$(LEX).ps.gz
	$(GZIP) -c $(YACC)/$(YACC).ps >$(TDOC)/$(YACC).ps.gz
	find $(TDOC)/ -name CVS -type d | xargs rm -rf
	find $(TDOC)/ -name .cvsignore -type f | xargs rm -rf
	find $(TEXM)/ -name CVS -type d | xargs rm -rf
	find $(TEXM)/ -name .cvsignore -type f | xargs rm -rf

TDOCBASE = $(DESTDIR)$(prefix)/share/doc-base

.PHONY: post-install-debian
post-install-debian:	
	cd $(TDOC)/ && rm -rf license
	$(CP) $(SRC)/debian/copyright $(SRC)/debian/README.Debian $(TDOC)/
	$(CP) $(SRC)/debian/changelog $(TDOC)/changelog.Debian
	mkdir -p $(TDOCBASE)
	for f in mllex mlton mlyacc; do \
		$(CP) $(SRC)/debian/$$f.doc-base $(TDOCBASE)/$$f; \
	done
	cd $(TDOC)/ && $(GZIP) changelog changelog.Debian
