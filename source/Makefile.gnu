# GNU Makefile for Euphoria Unix systems
#
# NOTE: This is meant to be used with GNU make,
#       so on BSD, you should use gmake instead
#       of make
#
# Syntax:
#
#   You must run configure before building
#
#   Configure the make system :  ./configure
#
#   Clean up binary files     :  make clean
#   Clean up binary and       :  make distclean
#        translated files
#   Everything                :  make
#   Interpreter          (eui):  make interpreter
#   Translator           (euc):  make translator
#   Translator Library  (eu.a):  make library
#   Backend              (eub):  make backend
#   Run Unit Tests            :  make test
#   Run Unit Tests with eu.ex :  make testeu
#   Code Page Database        :  make code-page-db
#   Generate automatic        :  make depend
#   dependencies (requires
#   makedepend to be installed)
#
#   Html Documentation        :  make htmldoc 
#   PDF Documentation         :  make pdfdoc
#
#   Note that Html and PDF Documentation require eudoc and creolehtml
#   PDF docs also require htmldoc
#

CONFIG_FILE = config.gnu

ifndef CONFIG
CONFIG = $(CONFIG_FILE)
endif

PCRE_CC=$(CC)

include $(CONFIG)
include $(TRUNKDIR)/source/pcre/objects.mak

ifeq "$(RELEASE)" "1"
RELEASE_FLAG = -D EU_FULL_RELEASE
endif

ifdef ERUNTIME
RUNTIME_FLAGS = -DERUNTIME
endif

ifdef EBACKEND
BACKEND_FLAGS = -DBACKEND
endif

ifeq "$(EBSD)" "1"
  LDLFLAG=
  EBSDFLAG=-DEBSD -DEBSD62
  SEDFLAG=-Ei
  ifeq "$(EOSX)" "1"
    LDLFLAG=-lresolv
    EBSDFLAG=-DEBSD -DEBSD62 -DEOSX
  endif
  ifeq "$(ESUNOS)" "1"
    LDLFLAG=-lsocket -lresolv -lnsl
    EBSDFLAG=-DEBSD -DEBSD62 -DESUNOS
  endif
  ifeq "$(EOPENBSD)" "1"
    EBSDFLAG=-DEBSD -DEBSD62 -DEOPENBSD
  endif
  ifeq "$(ENETBSD)" "1"
    EBSDFLAG=-DEBSD -DEBSD62 -DENETBSD
  endif
else
  LDLFLAG=-ldl -lresolv -lnsl
  PREREGEX=$(FROMBSDREGEX)
  SEDFLAG=-ri
endif
ifeq "$(EMINGW)" "1"
	EPTHREAD=
	EOSTYPE=-DEWINDOWS
	EBSDFLAG=-DEMINGW
	LDLFLAG=-lws2_32
	SEDFLAG=-ri
	EOSFLAGS=-mno-cygwin -mwindows
	EOSFLAGSCONSOLE=-mno-cygwin
	EOSPCREFLAGS=-mno-cygwin
	EECUA=eu.a
	EECUDBGA=eudbg.a
	ifdef EDEBUG
		EOSMING=
		LIBRARY_NAME=eudbg.a
	else
		EOSMING=-ffast-math -O3 -Os
		LIBRARY_NAME=eu.a
	endif
	EBACKENDU=eubw.exe
	EUBW_RES=$(BUILDDIR)/eubw.res
	EBACKENDC=eub.exe
	EUB_RES=$(BUILDDIR)/eub.res
	EECU=euc.exe
	EUC_RES=$(BUILDDIR)/euc.res
	EEXU=eui.exe
	EUI_RES=$(BUILDDIR)/eui.res
	EEXUW=euiw.exe
	EUIW_RES=$(BUILDDIR)/euiw.res
	ifeq "$(MANAGED_MEM)" "1"
		ifeq "$(ALIGN4)" "1"
			MEM_FLAGS=-DEALIGN4
		else
			MEM_FLAGS=
		endif
	else
		ifeq "$(ALIGN4)" "1"
			MEM_FLAGS=-DEALIGN4 -DESIMPLE_MALLOC
		else
			MEM_FLAGS=-DESIMPLE_MALLOC
		endif
	endif
	PCRE_CC=gcc
else
	EPTHREAD=-pthread
	EOSTYPE=-DEUNIX
	EOSFLAGS=
	EOSFLAGSCONSOLE=
	EOSPCREFLAGS=
	EBACKENDU=eub
	EBACKENDC=eub
	EECU=euc
	EEXU=eui
	EECUA=eu.a
	EECUDBGA=eudbg.a
	ifdef EDEBUG
		LIBRARY_NAME=eudbg.a
	else
		LIBRARY_NAME=eu.a
	endif
	MEM_FLAGS=-DESIMPLE_MALLOC
endif

LDLFLAG+= $(EPTHREAD)

ifdef EDEBUG
DEBUG_FLAGS=-g3 -O0 -Wall
CALLC_DEBUG=-g3
EC_DEBUG=-D DEBUG
else
DEBUG_FLAGS=-fomit-frame-pointer $(EOSMING)
endif

ifdef EPROFILE
PROFILE_FLAGS=-pg -g
ifndef EDEBUG
DEBUG_FLAGS=$(EOSMING)
endif
endif

ifdef ENO_DBL_CACHE
MEM_FLAGS+=-DNO_DBL_CACHE
endif

ifdef COVERAGE
COVERAGEFLAG=-fprofile-arcs -ftest-coverage
DEBUG_FLAGS=-g3 -O0 -Wall
COVERAGELIB=-lgcov
endif

ifndef TESTFILE
COVERAGE_ERASE=-coverage-erase
endif

ifeq  "$(ELINUX)" "1"
EBSDFLAG=-DELINUX
endif

# backwards compatibility
# don't make Unix users reconfigure for a MinGW-only change
ifndef CYPTRUNKDIR
CYPTRUNKDIR=$(TRUNKDIR)
endif
ifndef CYPBUILDDIR
CYPBUILDDIR=$(BUILDDIR)
endif

ifeq  "$(EUBIN)" ""
EXE=$(EEXU)
else
EXE=$(EUBIN)/$(EEXU)
endif
INCDIR=-i $(TRUNKDIR)/include
CYPINCDIR=-i $(CYPTRUNKDIR)/include

ifdef PLAT
TARGETPLAT=-plat $(PLAT)
endif

ifeq "$(ARCH)" "ix86"
BE_CALLC = be_callc
MSIZE=-m32
else
BE_CALLC = be_callc_conly
MSIZE=
endif

ifndef ECHO
ECHO=/bin/echo
endif

ifeq "$(EUDOC)" ""
EUDOC=eudoc
endif

ifeq "$(CREOLEHTML)" ""
CREOLEHTML=creolehtml
endif

ifdef WKHTMLTOPDF
HTML2PDF=wkhtmltopdf --header-right "\e\4.0\rc1 [page]" $(CYPBUILDDIR)/pdf/euphoria-pdf.html $(CYPBUILDDIR)/euphoria-4.0.pdf
else
HTML2PDF=htmldoc -f $(CYPBUILDDIR)/euphoria-4.0.pdf --book $(CYPBUILDDIR)/pdf/euphoria-pdf.html
endif

ifeq "$(TRANSLATE)" "euc"
	TRANSLATE=$(EECU)
else
	TRANSLATE=$(EXE) $(CYPINCDIR) $(EC_DEBUG) $(CYPTRUNKDIR)/source/ec.ex
endif

ifeq "$(EUPHORIA)" "1"
REVGET=svn_rev
endif

ifeq "$(MANAGED_MEM)" "1"
FE_FLAGS =  $(COVERAGEFLAG) $(MSIZE) $(EPTRHEAD) -c -fsigned-char $(EOSMING) -ffast-math $(EOSFLAGS) $(DEBUG_FLAGS) -I../ -I../../include/ $(PROFILE_FLAGS) -DARCH=$(ARCH) $(EREL_TYPE) $(MEM_FLAGS)
else
FE_FLAGS =  $(COVERAGEFLAG) $(MSIZE) $(EPTRHEAD) -c -fsigned-char $(EOSMING) -ffast-math $(EOSFLAGS) $(DEBUG_FLAGS) -I../ -I../../include/ $(PROFILE_FLAGS) -DARCH=$(ARCH) $(EREL_TYPE)
endif
BE_FLAGS =  $(COVERAGEFLAG) $(MSIZE) $(EPTRHEAD) -c -Wall $(EOSTYPE) $(EBSDFLAG) $(RUNTIME_FLAGS) $(EOSFLAGS) $(BACKEND_FLAGS) -fsigned-char -ffast-math $(DEBUG_FLAGS) $(MEM_FLAGS) $(PROFILE_FLAGS) -DARCH=$(ARCH) $(EREL_TYPE)

EU_CORE_FILES = \
	block.e \
	common.e \
	coverage.e \
	emit.e \
	error.e \
	fwdref.e \
	inline.e \
	keylist.e \
	main.e \
	msgtext.e \
	mode.e \
	opnames.e \
	parser.e \
	pathopen.e \
	platform.e \
	preproc.e \
	reswords.e \
	scanner.e \
	scinot.e \
	shift.e \
	symtab.e 

EU_INTERPRETER_FILES = \
	backend.e \
	c_out.e \
	cominit.e \
	compress.e \
	global.e \
	intinit.e \
	int.ex

EU_TRANSLATOR_FILES = \
	buildsys.e \
	c_decl.e \
	c_out.e \
	cominit.e \
	compile.e \
	compress.e \
	global.e \
	traninit.e \
	ec.ex

EU_BACKEND_RUNNER_FILES = \
	backend.e \
	il.e \
	cominit.e \
	compress.e \
	error.e \
	intinit.e \
	mode.e \
	reswords.e \
	pathopen.e \
	common.e \
	backend.ex
	
PREFIXED_PCRE_OBJECTS = $(addprefix $(BUILDDIR)/pcre/,$(PCRE_OBJECTS))
	
EU_BACKEND_OBJECTS = \
	$(BUILDDIR)/$(OBJDIR)/back/be_decompress.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_execute.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_task.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_main.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_alloc.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_callc.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_inline.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_machine.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_pcre.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_rterror.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_syncolor.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_runtime.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_symtab.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_socket.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_w.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_rev.o \
	$(PREFIXED_PCRE_OBJECTS)

EU_LIB_OBJECTS = \
	$(BUILDDIR)/$(OBJDIR)/back/be_decompress.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_machine.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_w.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_alloc.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_inline.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_pcre.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_socket.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_runtime.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_task.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_callc.o \
	$(BUILDDIR)/$(OBJDIR)/back/be_rev.o \
	$(PREFIXED_PCRE_OBJECTS)
	

STDINCDIR = $(TRUNKDIR)/include/std

EU_STD_INC = \
	$(wildcard $(STDINCDIR)/*.e) \
	$(wildcard $(STDINCDIR)/unix/*.e) \
	$(wildcard $(STDINCDIR)/net/*.e) \
	$(wildcard $(STDINCDIR)/win32/*.e)

DOCDIR = $(TRUNKDIR)/docs
EU_DOC_SOURCE = \
	$(EU_STD_INC) \
	$(DOCDIR)/manual.af \
	$(wildcard $(DOCDIR)/*.txt)

EU_TRANSLATOR_OBJECTS = $(patsubst %.c,%.o,$(wildcard $(BUILDDIR)/transobj/*.c))
EU_BACKEND_RUNNER_OBJECTS = $(patsubst %.c,%.o,$(wildcard $(BUILDDIR)/backobj/*.c))
EU_INTERPRETER_OBJECTS = $(patsubst %.c,%.o,$(wildcard $(BUILDDIR)/intobj/*.c))

all : interpreter translator library debug-library backend
all : binder

BUILD_DIRS=\
	$(BUILDDIR)/intobj/back \
	$(BUILDDIR)/transobj/back \
	$(BUILDDIR)/libobj/back \
	$(BUILDDIR)/libobjdbg/back \
	$(BUILDDIR)/backobj/back \
	$(BUILDDIR)/intobj/ \
	$(BUILDDIR)/transobj/ \
	$(BUILDDIR)/libobj/ \
	$(BUILDDIR)/backobj/


clean : 	
	-rm -fr $(BUILDDIR)
	-rm -fr $(BUILDDIR)/backobj
	-rm -f be_rev.c

clobber distclean : clean
	-rm -f $(CONFIG)
	-rm -f Makefile
	-rm -fr $(BUILDDIR)

ifeq "$(MINGW)" "1"
	-rm -f $(BUILDDIR)/{$(EBACKENDC),$(EEXUW)}
endif
	$(MAKE) -C pcre CONFIG=../$(CONFIG) clean
	

.PHONY : clean distclean clobber all htmldoc manual

debug-library : builddirs
	$(MAKE) $(BUILDDIR)/$(EECUDBGA) OBJDIR=libobjdbg ERUNTIME=1 CONFIG=$(CONFIG) EDEBUG=1 EPROFILE=$(EPROFILE)

library : builddirs
	$(MAKE) $(BUILDDIR)/$(LIBRARY_NAME) OBJDIR=libobj ERUNTIME=1 CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)

$(BUILDDIR)/$(LIBRARY_NAME) : $(EU_LIB_OBJECTS)
	ar -rc $(BUILDDIR)/$(LIBRARY_NAME) $(EU_LIB_OBJECTS)
	$(ECHO) $(MAKEARGS)

builddirs : $(BUILD_DIRS)

$(BUILD_DIRS) :
	mkdir -p $(BUILD_DIRS) 

ifeq "$(ROOTDIR)" ""
ROOTDIR=$(TRUNKDIR)
endif

svn_rev : 
	echo svn_rev EUPHORIA=$(EUPHORIA) REVGET=$(REVGET)
	-$(EXE) -i ../include revget.ex -root $(ROOTDIR)

be_rev.c : $(REVGET)

code-page-db : $(BUILDDIR)/ecp.dat

$(BUILDDIR)/ecp.dat : $(TRUNKDIR)/source/codepage/*.ecp
	$(BUILDDIR)/$(EEXU) -i $(CYPTRUNKDIR)/include $(CYPTRUNKDIR)/bin/buildcpdb.ex -p$(CYPTRUNKDIR)/source/codepage -o$(CYPBUILDDIR)

interpreter : builddirs
ifeq "$(EUPHORIA)" "1"
	$(MAKE) euisource OBJDIR=intobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)
endif	
	$(MAKE) $(BUILDDIR)/$(EEXU) OBJDIR=intobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)

translator : builddirs
ifeq "$(EUPHORIA)" "1"
	$(MAKE) eucsource OBJDIR=transobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)
endif	
	$(MAKE) $(BUILDDIR)/$(EECU) OBJDIR=transobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)

EUBIND=eubind

binder : translator library $(BUILDDIR)/$(EUBIND)

.PHONY : library debug-library
.PHONY : builddirs
.PHONY : interpreter
.PHONY : translator
.PHONY : svn_rev
.PHONY : code-page-db
.PHONY : binder

euisource : $(BUILDDIR)/intobj/main-.c be_rev.c
euisource :  EU_TARGET = int.ex
euisource : $(BUILDDIR)/$(OBJDIR)/back/coverage.h
eucsource : $(BUILDDIR)/transobj/main-.c  be_rev.c
eucsource :  EU_TARGET = ec.ex
eucsource : $(BUILDDIR)/$(OBJDIR)/back/coverage.h 
backendsource : $(BUILDDIR)/backobj/main-.c  be_rev.c
backendsource :  EU_TARGET = backend.ex
backendsource : $(BUILDDIR)/$(OBJDIR)/back/coverage.h
source : builddirs
	$(MAKE) euisource OBJDIR=intobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)
	$(MAKE) eucsource OBJDIR=transobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)
	$(MAKE) backendsource OBJDIR=backobj EBSD=$(EBSD) CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)

SVN_REV=xxx
SOURCEDIR=euphoria-$(PLAT)-r$(SVN_REV)
source-tarball : source
	rm -rf $(BUILDDIR)/$(SOURCEDIR)/source
	mkdir -p $(BUILDDIR)/$(SOURCEDIR)/include
	mkdir -p $(BUILDDIR)/$(SOURCEDIR)/source/build/intobj
	mkdir -p $(BUILDDIR)/$(SOURCEDIR)/source/build/transobj
	mkdir -p $(BUILDDIR)/$(SOURCEDIR)/source/build/backobj
	mkdir -p $(BUILDDIR)/$(SOURCEDIR)/source/build/libobj
	cp -r $(BUILDDIR)/intobj   $(BUILDDIR)/$(SOURCEDIR)/source/build/
	cp -r $(BUILDDIR)/transobj $(BUILDDIR)/$(SOURCEDIR)/source/build/
	cp -r $(BUILDDIR)/backobj  $(BUILDDIR)/$(SOURCEDIR)/source/build/
	cp -r $(BUILDDIR)/libobj   $(BUILDDIR)/$(SOURCEDIR)/source/build/
	cp be_*.c       $(BUILDDIR)/$(SOURCEDIR)/source
	cp int.ex       $(BUILDDIR)/$(SOURCEDIR)/source
	cp ec.ex        $(BUILDDIR)/$(SOURCEDIR)/source
	cp backend.ex   $(BUILDDIR)/$(SOURCEDIR)/source
	cp *.e          $(BUILDDIR)/$(SOURCEDIR)/source
	cp Makefile.gnu    $(BUILDDIR)/$(SOURCEDIR)/source
	cp Makefile.wat    $(BUILDDIR)/$(SOURCEDIR)/source
	cp configure    $(BUILDDIR)/$(SOURCEDIR)/source
	cp ../include/euphoria.h $(BUILDDIR)/$(SOURCEDIR)/include
	cp *.h          $(BUILDDIR)/$(SOURCEDIR)/source
	cp -r pcre $(BUILDDIR)/$(SOURCEDIR)/source
	cd $(BUILDDIR) && tar -zcf $(SOURCEDIR).tar.gz $(SOURCEDIR)
	
.PHONY : euisource
.PHONY : eucsource
.PHONY : backendsource
.PHONY : source


$(BUILDDIR)/$(OBJDIR)/back/coverage.h : $(BUILDDIR)/$(OBJDIR)/main-.c
	$(EXE) -i $(CYPTRUNKDIR)/include coverage.ex $(CYPBUILDDIR)/$(OBJDIR)

$(BUILDDIR)/intobj/back/be_execute.o : $(BUILDDIR)/intobj/back/coverage.h
$(BUILDDIR)/transobj/back/be_execute.o : $(BUILDDIR)/transobj/back/coverage.h
$(BUILDDIR)/backobj/back/be_execute.o : $(BUILDDIR)/backobj/back/coverage.h

$(BUILDDIR)/intobj/back/be_runtime.o : $(BUILDDIR)/intobj/back/coverage.h
$(BUILDDIR)/transobj/back/be_runtime.o : $(BUILDDIR)/transobj/back/coverage.h
$(BUILDDIR)/backobj/back/be_runtime.o : $(BUILDDIR)/backobj/back/coverage.h

ifeq "$(EMINGW)" "1"
$(EUI_RES) : eui.rc version_info.rc
$(EUIW_RES) : euiw.rc version_info.rc
endif

$(BUILDDIR)/$(EEXU) :  EU_TARGET = int.ex
$(BUILDDIR)/$(EEXU) :  EU_MAIN = $(EU_CORE_FILES) $(EU_INTERPRETER_FILES) $(EU_STD_INC)
$(BUILDDIR)/$(EEXU) :  EU_OBJS = $(EU_INTERPRETER_OBJECTS) $(EU_BACKEND_OBJECTS)
$(BUILDDIR)/$(EEXU) :  $(EU_INTERPRETER_OBJECTS) $(EU_BACKEND_OBJECTS) $(EU_TRANSLATOR_FILES) $(EUI_RES) $(EUIW_RES)
	@$(ECHO) making $(EEXU)
	@echo $(OS)
ifeq "$(EMINGW)" "1"
	$(CC) $(EOSFLAGSCONSOLE) $(EUI_RES) $(EU_INTERPRETER_OBJECTS) $(EU_BACKEND_OBJECTS) -lm $(LDLFLAG) $(COVERAGELIB) -o $(BUILDDIR)/$(EEXU)
	$(CC) $(EOSFLAGS) $(EUIW_RES) $(EU_INTERPRETER_OBJECTS) $(EU_BACKEND_OBJECTS) -lm $(LDLFLAG) $(COVERAGELIB) -o $(BUILDDIR)/$(EEXUW)
else
	$(CC) $(EOSFLAGS) $(EU_INTERPRETER_OBJECTS) $(EU_BACKEND_OBJECTS) -lm $(LDLFLAG) $(COVERAGELIB) $(PROFILE_FLAGS) $(MSIZE) -o $(BUILDDIR)/$(EEXU)
endif

ifeq "$(EMINGW)" "1"
$(EUC_RES) : euc.rc version_info.rc
endif

$(BUILDDIR)/$(EECU) :  OBJDIR = transobj
$(BUILDDIR)/$(EECU) :  EU_TARGET = ec.ex
$(BUILDDIR)/$(EECU) :  EU_MAIN = $(EU_CORE_FILES) $(EU_TRANSLATOR_FILES) $(EU_STD_INC)
$(BUILDDIR)/$(EECU) :  EU_OBJS = $(EU_TRANSLATOR_OBJECTS) $(EU_BACKEND_OBJECTS)
$(BUILDDIR)/$(EECU) : $(EU_TRANSLATOR_OBJECTS) $(EU_BACKEND_OBJECTS) $(EUC_RES)
	@$(ECHO) making $(EECU)
	$(CC) $(EOSFLAGSCONSOLE) $(EUC_RES) $(EU_TRANSLATOR_OBJECTS) $(DEBUG_FLAGS) $(PROFILE_FLAGS) $(EU_BACKEND_OBJECTS) $(MSIZE) -lm $(LDLFLAG) $(COVERAGELIB) -o $(BUILDDIR)/$(EECU)
	
backend : builddirs
ifeq "$(EUPHORIA)" "1"
	$(MAKE) backendsource EBACKEND=1 OBJDIR=backobj CONFIG=$(CONFIG)  EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)
endif	
	$(MAKE) $(BUILDDIR)/$(EBACKENDU) EBACKEND=1 OBJDIR=backobj CONFIG=$(CONFIG) EDEBUG=$(EDEBUG) EPROFILE=$(EPROFILE)

ifeq "$(EMINGW)" "1"
$(EUB_RES) : eub.rc version_info.rc
$(EUBW_RES) : eubw.rc version_info.rc
endif

$(BUILDDIR)/$(EBACKENDU) : OBJDIR = backobj
$(BUILDDIR)/$(EBACKENDU) : EU_TARGET = backend.ex
$(BUILDDIR)/$(EBACKENDU) : EU_MAIN = $(EU_BACKEND_RUNNER_FILES)
$(BUILDDIR)/$(EBACKENDU) : EU_OBJS = $(EU_BACKEND_RUNNER_OBJECTS) $(EU_BACKEND_OBJECTS)
$(BUILDDIR)/$(EBACKENDU) : $(EU_BACKEND_RUNNER_OBJECTS) $(EU_BACKEND_OBJECTS) $(EUB_RES) $(EUBW_RES)
	@$(ECHO) making $(EBACKENDU) $(OBJDIR)
	$(CC) $(EOSFLAGS) $(EUBW_RES) $(EU_BACKEND_RUNNER_OBJECTS) $(EU_BACKEND_OBJECTS) -lm $(LDLFLAG) $(COVERAGELIB) $(DEBUG_FLAGS) $(MSIZE) $(PROFILE_FLAGS) -o $(BUILDDIR)/$(EBACKENDU)
ifeq "$(EMINGW)" "1"
	$(CC) $(EOSFLAGSCONSOLE) $(EUB_RES) $(EU_BACKEND_RUNNER_OBJECTS) $(EU_BACKEND_OBJECTS) -lm $(LDLFLAG) $(COVERAGELIB) -o $(BUILDDIR)/$(EBACKENDC)
endif

$(BUILDDIR)/euphoria.txt : $(EU_DOC_SOURCE)
	cd ../docs/ && $(EUDOC) --strip=2 --verbose -a manual.af -o $(CYPBUILDDIR)/euphoria.txt

$(BUILDDIR)/euphoria-pdf.txt : $(EU_DOC_SOURCE)
	cd ../docs/ && $(EUDOC) --single --strip=2 --verbose -a manual.af -o $(CYPBUILDDIR)/euphoria-pdf.txt
	
$(BUILDDIR)/docs/index.html : $(BUILDDIR)/euphoria.txt $(DOCDIR)/*.txt $(TRUNKDIR)/include/std/*.e
	-mkdir -p $(BUILDDIR)/docs/images
	-mkdir -p $(BUILDDIR)/docs/js
	$(CREOLEHTML) -A -d=$(CYPTRUNKDIR)/docs/ -t=template.html -o=$(CYPBUILDDIR)/docs $(CYPBUILDDIR)/euphoria.txt
	cp $(DOCDIR)/html/images/* $(BUILDDIR)/docs/images
	cp $(DOCDIR)/style.css $(BUILDDIR)/docs

manual : $(BUILDDIR)/docs/index.html

manual-upload : manual
	$(SCP) $(TRUNKDIR)/docs/style.css $(BUILDDIR)/docs/*.html $(oe_username)@openeuphoria.org:/home/euweb/docs

$(BUILDDIR)/html/index.html : $(BUILDDIR)/euphoria.txt $(DOCDIR)/offline-template.html
	-mkdir -p $(BUILDDIR)/html/images
	-mkdir -p $(BUILDDIR)/html/js
	 $(CREOLEHTML) -A -d=$(CYPTRUNKDIR)/docs/ -t=offline-template.html -o=$(CYPBUILDDIR)/html $(CYPBUILDDIR)/euphoria.txt
	cp $(DOCDIR)/*js $(BUILDDIR)/html/js
	cp $(DOCDIR)/html/images/* $(BUILDDIR)/html/images
	cp $(DOCDIR)/style.css $(BUILDDIR)/html

$(BUILDDIR)/html/js/scriptaculous.js: $(DOCDIR)/scriptaculous.js  $(BUILDDIR)/html/js
	copy $(DOCDIR)/scriptaculous.js $^@

$(BUILDDIR)/html/js/prototype.js: $(DOCDIR)/prototype.js  $(BUILDDIR)/html/js
	copy $(DOCDIR)/prototype.js $^@

htmldoc : $(BUILDDIR)/html/index.html

$(BUILDDIR)/pdf/euphoria-pdf.html : $(BUILDDIR)/euphoria-pdf.txt $(DOCDIR)/pdf-template.html
	-mkdir -p $(BUILDDIR)/pdf
	$(CREOLEHTML) -A -d=$(CYPTRUNKDIR)/docs/ -t=pdf-template.html -o=$(CYPBUILDDIR)/pdf --htmldoc $(CYPBUILDDIR)/euphoria-pdf.txt

$(BUILDDIR)/euphoria-4.0.pdf : $(BUILDDIR)/euphoria-pdf.txt $(BUILDDIR)/pdf/euphoria-pdf.html  $(DOCDIR)/pdf.css
	cp $(CYPTRUNKDIR)/docs/pdf.css $(CYPBUILDDIR)/pdf/
	$(HTML2PDF)

pdfdoc : $(BUILDDIR)/euphoria-4.0.pdf

test : EUDIR=$(TRUNKDIR)
test : EUCOMPILEDIR=$(TRUNKDIR)
test : EUCOMPILEDIR=$(TRUNKDIR)	
test : C_INCLUDE_PATH=$(TRUNKDIR):..:$(C_INCLUDE_PATH)
test : LIBRARY_PATH=$(%LIBRARY_PATH)
test : 
test :  
	cd ../tests && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) \
		$(EXE) -i ../include ../source/eutest.ex -i ../include -cc gcc $(VERBOSE_TESTS) \
		-exe "$(CYPBUILDDIR)/$(EEXU)" \
		-ec "$(CYPBUILDDIR)/$(EECU)" \
		-bind "$(CYPBUILDDIR)/$(EUBIND)" -eub $(CYPBUILDDIR)/$(EBACKENDC) \
		-lib "$(CYPBUILDDIR)/$(LIBRARY_NAME) $(COVERAGELIB)" \
		-verbose $(TESTFILE)
	cd ../tests && sh check_diffs.sh

testeu : 
	cd ../tests && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) $(EXE) ../source/eutest.ex -i ../include -cc gcc -exe "$(CYPBUILDDIR)/$(EEXU) -batch $(CYPTRUNKDIR)/source/eu.ex" $(TESTFILE)

test-311 :
	cd ../tests/311 && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) \
		$(EXE) -i ../include $(CYPTRUNKDIR)/source/eutest.ex -i $(CYPTRUNKDIR)/include -cc gcc $(VERBOSE_TESTS) \
		-exe "$(CYPBUILDDIR)/$(EEXU)" \
		-ec "$(CYPBUILDDIR)/$(EECU)" \
		-bind $(CYPTRUNKDIR)/source/bind.ex -eub $(CYPBUILDDIR)/$(EBACKENDC) \
		-lib "$(CYPBUILDDIR)/$(LIBRARY_NAME) $(COVERAGELIB)" \
		$(TESTFILE)
		
coverage-311 :
	cd ../tests/311 && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) \
		$(EXE) -i ../include $(CYPTRUNKDIR)/source/eutest.ex -i $(CYPTRUNKDIR)/include \
		-exe "$(CYPBUILDDIR)/$(EEXU)" $(COVERAGE_ERASE) \
		-coverage-db $(CYPBUILDDIR)/unit-test-311.edb -coverage $(CYPTRUNKDIR)/include \
		-coverage-exclude std -coverage-exclude euphoria \
		 -coverage-pp "$(EXE) -i $(CYPTRUNKDIR)/include $(CYPTRUNKDIR)/bin/eucoverage.ex" $(TESTFILE)

coverage : 
	cd ../tests && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) \
		$(EXE) -i ../include $(CYPTRUNKDIR)/source/eutest.ex -i $(CYPTRUNKDIR)/include \
		-exe "$(CYPBUILDDIR)/$(EEXU)" $(COVERAGE_ERASE) \
		-coverage-db $(CYPBUILDDIR)/unit-test.edb -coverage $(CYPTRUNKDIR)/include/std \
		 -coverage-pp "$(EXE) -i $(CYPTRUNKDIR)/include $(CYPTRUNKDIR)/bin/eucoverage.ex" $(TESTFILE)

coverage-front-end : 
	-rm $(CYPBUILDDIR)/front-end.edb
	cd ../tests && EUDIR=$(CYPTRUNKDIR) EUCOMPILEDIR=$(CYPTRUNKDIR) \
		$(EXE) -i ../include $(CYPTRUNKDIR)/source/eutest.ex -i $(CYPTRUNKDIR)/include \
		-exe "$(CYPBUILDDIR)/$(EEXU) -coverage-db $(CYPBUILDDIR)/front-end.edb -coverage $(CYPTRUNKDIR)/source $(CYPTRUNKDIR)/source/eu.ex" \
		-verbose $(TESTFILE)
	eucoverage $(CYPBUILDDIR)/front-end.edb

.PHONY : coverage

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif

install :
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/include/euphoria
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/include/std/win32
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/include/std/net
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/demo/langwar
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/demo/unix
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/demo/net
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/demo/win32
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/demo/bench
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/tutorial 
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/bin 
	mkdir -p $(DESTDIR)/etc/euphoria 
	mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/source 
	mkdir -p $(DESTDIR)$(PREFIX)/bin 
	mkdir -p $(DESTDIR)$(PREFIX)/lib
	mkdir -p $(DESTDIR)$(PREFIX)/include/euphoria
	install $(BUILDDIR)/$(EECUA) $(DESTDIR)$(PREFIX)/lib
	install $(BUILDDIR)/$(EECUDBGA) $(DESTDIR)$(PREFIX)/lib
	install $(BUILDDIR)/$(EEXU) $(DESTDIR)$(PREFIX)/bin
	install $(BUILDDIR)/$(EECU) $(DESTDIR)$(PREFIX)/bin
	install $(BUILDDIR)/$(EBACKENDU) $(DESTDIR)$(PREFIX)/bin
	install $(BUILDDIR)/$(EUBIND) $(DESTDIR)$(PREFIX)/bin
ifeq "$(EMINGW)" "1"
	install $(BUILDDIR)/$(EBACKENDC) $(DESTDIR)$(PREFIX)/bin
endif
	install ../include/*e  $(DESTDIR)$(PREFIX)/share/euphoria/include
	install ../include/std/*e  $(DESTDIR)$(PREFIX)/share/euphoria/include/std
	install ../include/std/net/*e  $(DESTDIR)$(PREFIX)/share/euphoria/include/std/net
	install ../include/std/win32/*e  $(DESTDIR)$(PREFIX)/share/euphoria/include/std/win32
	install ../include/euphoria/*  $(DESTDIR)$(PREFIX)/share/euphoria/include/euphoria
	install ../include/euphoria.h $(DESTDIR)$(PREFIX)/share/euphoria/include
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/demo ../demo/*
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/demo/bench ../demo/bench/*
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/demo/langwar ../demo/langwar/*
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/demo/unix ../demo/unix/*
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/tutorial ../tutorial/*
	-install -t $(DESTDIR)$(PREFIX)/share/euphoria/bin \
	           ../bin/ed.ex \
	           ../bin/bugreport.ex \
	           ../bin/buildcpdb.ex \
	           ../bin/ecp.dat \
	           ../bin/eucoverage.ex \
	           ../bin/euloc.ex
	install -t $(DESTDIR)$(PREFIX)/share/euphoria/source \
	           *.ex \
	           *.e \
	           be_*.c \
	           *.h
	# helper script for shrouding programs
	echo "#!/bin/sh" > $(DESTDIR)$(PREFIX)/bin/eushroud
	echo eubind -shroud_only $$\@ >> $(DESTDIR)$(PREFIX)/bin/eushroud
	chmod +x $(DESTDIR)$(PREFIX)/bin/eushroud

EUDIS=eudis
EUSHROUD=eushroud
EUTEST=eutest
EUCOVERAGE=eucoverage
EUDIST=eudist

ifeq "$(EMINGW)" "1"
	MINGW_FLAGS=-gcc
else
	MINGW_FLAGS=
endif

$(BUILDDIR)/eudist-build/main-.c : eudist.ex
	$(BUILDDIR)/$(EECU) -build-dir "$(BUILDDIR)/eudist-build" \
		-i $(TRUNKDIR)/include \
		-o "$(BUILDDIR)/$(EUDIST)" \
		-lib "$(BUILDDIR)/eu.a" \
		-makefile \
		$(MINGW_FLAGS) $(TRUNKDIR)/source/eudist.ex

$(BUILDDIR)/$(EUDIST) : $(TRUNKDIR)/source/eudist.ex translator library $(BUILDDIR)/eudist-build/main-.c
		$(MAKE) -C "$(BUILDDIR)/eudist-build" -f eudist.mak

 : 
$(BUILDDIR)/eudis-build/main-.c : $(TRUNKDIR)/source/dis.ex  $(TRUNKDIR)/source/dis.e $(TRUNKDIR)/source/dox.e
$(BUILDDIR)/eudis-build/main-.c : $(EU_CORE_FILES) 
$(BUILDDIR)/eudis-build/main-.c : $(EU_INTERPRETER_FILES) 
	$(BUILDDIR)/$(EECU) -build-dir "$(BUILDDIR)/eudis-build" \
		-i $(TRUNKDIR)/include \
		-o "$(BUILDDIR)/$(EUDIS)" \
		-lib "$(BUILDDIR)/eu.a" \
		-makefile \
		$(MINGW_FLAGS) $(TRUNKDIR)/source/dis.ex

$(BUILDDIR)/$(EUDIS) : translator library $(BUILDDIR)/eudis-build/main-.c
		$(MAKE) -C "$(BUILDDIR)/eudis-build" -f dis.mak

$(BUILDDIR)/bind-build/main-.c : $(TRUNKDIR)/source/bind.ex
	$(BUILDDIR)/$(EECU) -build-dir "$(BUILDDIR)/bind-build" \
		-i $(TRUNKDIR)/include \
		-o "$(BUILDDIR)/$(EUBIND)" \
		-lib "$(BUILDDIR)/eu.a" \
		-makefile \
		$(MINGW_FLAGS) $(TRUNKDIR)/source/bind.ex

$(BUILDDIR)/$(EUBIND) : $(BUILDDIR)/bind-build/main-.c
		$(MAKE) -C "$(BUILDDIR)/bind-build" -f bind.mak

$(BUILDDIR)/eutest-build/main-.c : $(TRUNKDIR)/source/eutest.ex
	$(BUILDDIR)/$(EECU) -build-dir "$(BUILDDIR)/eutest-build" \
		-i $(TRUNKDIR)/include \
		-o "$(BUILDDIR)/$(EUTEST)" \
		-lib "$(BUILDDIR)/eu.a" \
		-makefile \
		$(MINGW_FLAGS) $(TRUNKDIR)/source/eutest.ex

$(BUILDDIR)/$(EUTEST) : $(BUILDDIR)/eutest-build/main-.c
		$(MAKE) -C "$(BUILDDIR)/eutest-build" -f eutest.mak

$(BUILDDIR)/eucoverage-build/main-.c : $(TRUNKDIR)/bin/eucoverage.ex
	$(BUILDDIR)/$(EECU) -build-dir "$(BUILDDIR)/eucoverage-build" \
		-i $(TRUNKDIR)/include \
		-o "$(BUILDDIR)/$(EUCOVERAGE)" \
		-lib "$(BUILDDIR)/eu.a" \
		-makefile \
		$(MINGW_FLAGS) $(TRUNKDIR)/bin/eucoverage.ex

$(BUILDDIR)/$(EUCOVERAGE) : $(BUILDDIR)/eucoverage-build/main-.c
		$(MAKE) -C "$(BUILDDIR)/eucoverage-build" -f eucoverage.mak

EU_TOOLS= $(BUILDDIR)/$(EUDIST) \
	$(BUILDDIR)/$(EUDIS) \
	$(BUILDDIR)/$(EUTEST) \
	$(BUILDDIR)/$(EUCOVERAGE)

tools : $(EU_TOOLS)

clean-tools :
	-rm $(EU_TOOLS)

install-tools :
	install $(BUILDDIR)/$(EUDIST) $(DESTDIR)/$(PREFIX)/bin/
	install $(BUILDDIR)/$(EUDIS) $(DESTDIR)/$(PREFIX)/bin/
	install $(BUILDDIR)/$(EUTEST) $(DESTDIR)/$(PREFIX)/bin/
	install $(BUILDDIR)/$(EUCOVERAGE) $(DESTDIR)/$(PREFIX)/bin/
	
	

install-docs :
	# create dirs
	install -d $(DESTDIR)$(PREFIX)/share/doc/euphoria/html/js
	install -d $(DESTDIR)$(PREFIX)/share/doc/euphoria/html/images
	install $(BUILDDIR)/euphoria-4.0.pdf $(DESTDIR)$(PREFIX)/share/doc/euphoria/
	install -t $(DESTDIR)$(PREFIX)/share/doc/euphoria/html \
		$(BUILDDIR)/html/*html \
		$(BUILDDIR)/html/*css
	install -t $(DESTDIR)$(PREFIX)/share/doc/euphoria/html/images \
		$(BUILDDIR)/html/images/*
	install -t $(DESTDIR)$(PREFIX)/share/doc/euphoria/html/js \
		$(BUILDDIR)/html/js/*

# This doesn't seem right. What about eushroud ?
uninstall :
	-rm $(PREFIX)/bin/$(EEXU) $(PREFIX)/bin/$(EECU) $(PREFIX)/lib/$(EECUA) $(PREFIX)/lib/$(EECUDBGA) $(PREFIX)/bin/$(EBACKENDU)
ifeq "$(EMINGW)" "1"
	-rm $(PREFIX)/lib/$(EBACKENDC)
endif
	-rm -r $(PREFIX)/share/euphoria

uninstall-docs :
	-rm -rf $(PREFIX)/share/doc/euphoria

.PHONY : install install-docs install-tools
.PHONY : uninstall uninstall-docs

ifeq "$(EUPHORIA)" "1"
$(BUILDDIR)/intobj/main-.c : $(EU_CORE_FILES) $(EU_INTERPRETER_FILES) $(EU_TRANSLATOR_FILES) $(EU_STD_INC)
$(BUILDDIR)/transobj/main-.c : $(EU_CORE_FILES) $(EU_TRANSLATOR_FILES) $(EU_STD_INC)
$(BUILDDIR)/backobj/main-.c : $(EU_CORE_FILES) $(EU_BACKEND_RUNNER_FILES) $(EU_TRANSLATOR_FILES) $(EU_STD_INC)
endif

%obj :
	mkdir -p $@

%back : %
	mkdir -p $@

$(BUILDDIR)/%.res : %.rc
	windres $< -O coff -o $@
	
$(BUILDDIR)/$(OBJDIR)/%.o : $(BUILDDIR)/$(OBJDIR)/%.c
	$(CC) $(EBSDFLAG) $(FE_FLAGS) $(BUILDDIR)/$(OBJDIR)/$*.c -I/usr/share/euphoria -o$(BUILDDIR)/$(OBJDIR)/$*.o


ifeq "$(EUPHORIA)" "1"

$(BUILDDIR)/$(OBJDIR)/%.c : $(EU_MAIN)
	@$(ECHO) Translating $(EU_TARGET) to create $(EU_MAIN)
	rm -f $(BUILDDIR)/$(OBJDIR)/{*.c,*.o}
	(cd $(BUILDDIR)/$(OBJDIR);$(TRANSLATE) -nobuild $(CYPINCDIR) -$(XLTTARGETCC) $(RELEASE_FLAG) $(TARGETPLAT)  $(CYPTRUNKDIR)/source/$(EU_TARGET) )
	
endif

ifneq "$(OBJDIR)" ""
$(BUILDDIR)/$(OBJDIR)/back/%.o : %.c $(CONFIG_FILE)
	$(CC) $(BE_FLAGS) $(EBSDFLAG) -I $(BUILDDIR)/$(OBJDIR)/back $*.c -o$(BUILDDIR)/$(OBJDIR)/back/$*.o

$(BUILDDIR)/$(OBJDIR)/back/be_callc.o : ./$(BE_CALLC).c $(CONFIG_FILE)
	$(CC) -c -Wall $(EOSTYPE) $(EOSFLAGS) $(EBSDFLAG) $(MSIZE) -fsigned-char -Os -O3 -ffast-math -fno-defer-pop $(CALLC_DEBUG) $(BE_CALLC).c -o$(BUILDDIR)/$(OBJDIR)/back/be_callc.o
	$(CC) -S -Wall $(EOSTYPE) $(EOSFLAGS) $(EBSDFLAG) $(MSIZE) -fsigned-char -Os -O3 -ffast-math -fno-defer-pop $(CALLC_DEBUG) $(BE_CALLC).c -o$(BUILDDIR)/$(OBJDIR)/back/be_callc.s

$(BUILDDIR)/$(OBJDIR)/back/be_inline.o : ./be_inline.c $(CONFIG_FILE) 
	$(CC) -finline-functions $(BE_FLAGS) $(EBSDFLAG) $(RUNTIME_FLAGS) be_inline.c -o$(BUILDDIR)/$(OBJDIR)/back/be_inline.o
endif
ifdef PCRE_OBJECTS	
$(PREFIXED_PCRE_OBJECTS) : $(patsubst %.o,pcre/%.c,$(PCRE_OBJECTS)) pcre/config.h.unix pcre/pcre.h.unix
	$(MAKE) -C pcre all CC="$(PCRE_CC)" PCRE_CC="$(PCRE_CC)" EOSTYPE="$(EOSTYPE)" EOSFLAGS="$(EOSPCREFLAGS)" CONFIG=../$(CONFIG)
endif

depend :
	makedepend -fMakefile.gnu -Y. -I. *.c -p'$$(BUILDDIR)/intobj/back/'
	makedepend -fMakefile.gnu -Y. -I. *.c -p'$$(BUILDDIR)/transobj/back/' -a
	makedepend -fMakefile.gnu -Y. -I. *.c -p'$$(BUILDDIR)/backobj/back/' -a
	makedepend -fMakefile.gnu -Y. -I. *.c -p'$$(BUILDDIR)/libobj/back/' -a

# The dependencies below are automatically generated using the depend target above.
# DO NOT DELETE

$(BUILDDIR)/intobj/back/be_alloc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_alloc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/intobj/back/be_alloc.o: be_alloc.h
$(BUILDDIR)/intobj/back/be_callc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_callc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/intobj/back/be_callc.o: be_machine.h be_alloc.h
$(BUILDDIR)/intobj/back/be_callc_conly.o: alldefs.h global.h object.h
$(BUILDDIR)/intobj/back/be_callc_conly.o: symtab.h execute.h reswords.h
$(BUILDDIR)/intobj/back/be_callc_conly.o: be_runtime.h be_machine.h
$(BUILDDIR)/intobj/back/be_decompress.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_decompress.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_execute.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_execute.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_execute.o: be_runtime.h be_decompress.h
$(BUILDDIR)/intobj/back/be_execute.o: be_inline.h be_machine.h be_task.h
$(BUILDDIR)/intobj/back/be_execute.o: be_rterror.h be_symtab.h be_w.h
$(BUILDDIR)/intobj/back/be_execute.o: be_callc.h be_execute.h
$(BUILDDIR)/intobj/back/be_inline.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_inline.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_machine.o: global.h object.h symtab.h alldefs.h
$(BUILDDIR)/intobj/back/be_machine.o: execute.h reswords.h version.h
$(BUILDDIR)/intobj/back/be_machine.o: be_runtime.h be_rterror.h be_main.h
$(BUILDDIR)/intobj/back/be_machine.o: be_w.h be_symtab.h be_machine.h
$(BUILDDIR)/intobj/back/be_machine.o: be_pcre.h pcre/pcre.h be_task.h
$(BUILDDIR)/intobj/back/be_main.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_main.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/intobj/back/be_main.o: be_execute.h be_alloc.h be_rterror.h
$(BUILDDIR)/intobj/back/be_pcre.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_pcre.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_pcre.o: be_runtime.h be_pcre.h pcre/pcre.h
$(BUILDDIR)/intobj/back/be_rterror.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_rterror.o: execute.h reswords.h be_rterror.h
$(BUILDDIR)/intobj/back/be_rterror.o: be_runtime.h be_task.h be_w.h
$(BUILDDIR)/intobj/back/be_rterror.o: be_machine.h be_execute.h be_symtab.h
$(BUILDDIR)/intobj/back/be_rterror.o: be_alloc.h be_syncolor.h
$(BUILDDIR)/intobj/back/be_runtime.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_runtime.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_runtime.o: be_runtime.h be_machine.h be_inline.h
$(BUILDDIR)/intobj/back/be_runtime.o: be_w.h be_callc.h be_task.h
$(BUILDDIR)/intobj/back/be_runtime.o: be_rterror.h be_execute.h be_symtab.h
$(BUILDDIR)/intobj/back/be_socket.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_socket.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/intobj/back/be_socket.o: be_runtime.h be_socket.h
$(BUILDDIR)/intobj/back/be_symtab.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_symtab.o: execute.h reswords.h be_execute.h
$(BUILDDIR)/intobj/back/be_symtab.o: be_alloc.h be_machine.h be_runtime.h
$(BUILDDIR)/intobj/back/be_syncolor.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_syncolor.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/intobj/back/be_syncolor.o: be_w.h
$(BUILDDIR)/intobj/back/be_task.o: global.h object.h symtab.h execute.h
$(BUILDDIR)/intobj/back/be_task.o: reswords.h be_runtime.h be_task.h
$(BUILDDIR)/intobj/back/be_task.o: be_alloc.h be_machine.h be_execute.h
$(BUILDDIR)/intobj/back/be_task.o: be_symtab.h alldefs.h
$(BUILDDIR)/intobj/back/be_w.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/intobj/back/be_w.o: execute.h reswords.h be_w.h be_machine.h
$(BUILDDIR)/intobj/back/be_w.o: be_runtime.h be_rterror.h be_alloc.h
$(BUILDDIR)/intobj/back/rbt.o: rbt.h

$(BUILDDIR)/transobj/back/be_alloc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_alloc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/transobj/back/be_alloc.o: be_alloc.h
$(BUILDDIR)/transobj/back/be_callc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_callc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/transobj/back/be_callc.o: be_machine.h be_alloc.h
$(BUILDDIR)/transobj/back/be_callc_conly.o: alldefs.h global.h object.h
$(BUILDDIR)/transobj/back/be_callc_conly.o: symtab.h execute.h reswords.h
$(BUILDDIR)/transobj/back/be_callc_conly.o: be_runtime.h be_machine.h
$(BUILDDIR)/transobj/back/be_decompress.o: alldefs.h global.h object.h
$(BUILDDIR)/transobj/back/be_decompress.o: symtab.h execute.h reswords.h
$(BUILDDIR)/transobj/back/be_decompress.o: be_alloc.h
$(BUILDDIR)/transobj/back/be_execute.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_execute.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/transobj/back/be_execute.o: be_runtime.h be_decompress.h
$(BUILDDIR)/transobj/back/be_execute.o: be_inline.h be_machine.h be_task.h
$(BUILDDIR)/transobj/back/be_execute.o: be_rterror.h be_symtab.h be_w.h
$(BUILDDIR)/transobj/back/be_execute.o: be_callc.h be_execute.h
$(BUILDDIR)/transobj/back/be_inline.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_inline.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/transobj/back/be_machine.o: global.h object.h symtab.h alldefs.h
$(BUILDDIR)/transobj/back/be_machine.o: execute.h reswords.h version.h
$(BUILDDIR)/transobj/back/be_machine.o: be_runtime.h be_rterror.h be_main.h
$(BUILDDIR)/transobj/back/be_machine.o: be_w.h be_symtab.h be_machine.h
$(BUILDDIR)/transobj/back/be_machine.o: be_pcre.h pcre/pcre.h be_task.h
$(BUILDDIR)/transobj/back/be_main.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_main.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/transobj/back/be_main.o: be_execute.h be_alloc.h be_rterror.h
$(BUILDDIR)/transobj/back/be_pcre.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_pcre.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/transobj/back/be_pcre.o: be_runtime.h be_pcre.h pcre/pcre.h
$(BUILDDIR)/transobj/back/be_rterror.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_rterror.o: execute.h reswords.h be_rterror.h
$(BUILDDIR)/transobj/back/be_rterror.o: be_runtime.h be_task.h be_w.h
$(BUILDDIR)/transobj/back/be_rterror.o: be_machine.h be_execute.h be_symtab.h
$(BUILDDIR)/transobj/back/be_rterror.o: be_alloc.h be_syncolor.h
$(BUILDDIR)/transobj/back/be_runtime.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_runtime.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/transobj/back/be_runtime.o: be_runtime.h be_machine.h be_inline.h
$(BUILDDIR)/transobj/back/be_runtime.o: be_w.h be_callc.h be_task.h
$(BUILDDIR)/transobj/back/be_runtime.o: be_rterror.h be_execute.h be_symtab.h
$(BUILDDIR)/transobj/back/be_socket.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_socket.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/transobj/back/be_socket.o: be_runtime.h be_socket.h
$(BUILDDIR)/transobj/back/be_symtab.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_symtab.o: execute.h reswords.h be_execute.h
$(BUILDDIR)/transobj/back/be_symtab.o: be_alloc.h be_machine.h be_runtime.h
$(BUILDDIR)/transobj/back/be_syncolor.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_syncolor.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/transobj/back/be_syncolor.o: be_w.h
$(BUILDDIR)/transobj/back/be_task.o: global.h object.h symtab.h execute.h
$(BUILDDIR)/transobj/back/be_task.o: reswords.h be_runtime.h be_task.h
$(BUILDDIR)/transobj/back/be_task.o: be_alloc.h be_machine.h be_execute.h
$(BUILDDIR)/transobj/back/be_task.o: be_symtab.h alldefs.h
$(BUILDDIR)/transobj/back/be_w.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/transobj/back/be_w.o: execute.h reswords.h be_w.h be_machine.h
$(BUILDDIR)/transobj/back/be_w.o: be_runtime.h be_rterror.h be_alloc.h
$(BUILDDIR)/transobj/back/rbt.o: rbt.h

$(BUILDDIR)/backobj/back/be_alloc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_alloc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/backobj/back/be_alloc.o: be_alloc.h
$(BUILDDIR)/backobj/back/be_callc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_callc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/backobj/back/be_callc.o: be_machine.h be_alloc.h
$(BUILDDIR)/backobj/back/be_callc_conly.o: alldefs.h global.h object.h
$(BUILDDIR)/backobj/back/be_callc_conly.o: symtab.h execute.h reswords.h
$(BUILDDIR)/backobj/back/be_callc_conly.o: be_runtime.h be_machine.h
$(BUILDDIR)/backobj/back/be_decompress.o: alldefs.h global.h object.h
$(BUILDDIR)/backobj/back/be_decompress.o: symtab.h execute.h reswords.h
$(BUILDDIR)/backobj/back/be_decompress.o: be_alloc.h
$(BUILDDIR)/backobj/back/be_execute.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_execute.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/backobj/back/be_execute.o: be_runtime.h be_decompress.h
$(BUILDDIR)/backobj/back/be_execute.o: be_inline.h be_machine.h be_task.h
$(BUILDDIR)/backobj/back/be_execute.o: be_rterror.h be_symtab.h be_w.h
$(BUILDDIR)/backobj/back/be_execute.o: be_callc.h be_execute.h
$(BUILDDIR)/backobj/back/be_inline.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_inline.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/backobj/back/be_machine.o: global.h object.h symtab.h alldefs.h
$(BUILDDIR)/backobj/back/be_machine.o: execute.h reswords.h version.h
$(BUILDDIR)/backobj/back/be_machine.o: be_runtime.h be_rterror.h be_main.h
$(BUILDDIR)/backobj/back/be_machine.o: be_w.h be_symtab.h be_machine.h
$(BUILDDIR)/backobj/back/be_machine.o: be_pcre.h pcre/pcre.h be_task.h
$(BUILDDIR)/backobj/back/be_main.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_main.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/backobj/back/be_main.o: be_execute.h be_alloc.h be_rterror.h
$(BUILDDIR)/backobj/back/be_pcre.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_pcre.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/backobj/back/be_pcre.o: be_runtime.h be_pcre.h pcre/pcre.h
$(BUILDDIR)/backobj/back/be_rterror.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_rterror.o: execute.h reswords.h be_rterror.h
$(BUILDDIR)/backobj/back/be_rterror.o: be_runtime.h be_task.h be_w.h
$(BUILDDIR)/backobj/back/be_rterror.o: be_machine.h be_execute.h be_symtab.h
$(BUILDDIR)/backobj/back/be_rterror.o: be_alloc.h be_syncolor.h
$(BUILDDIR)/backobj/back/be_runtime.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_runtime.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/backobj/back/be_runtime.o: be_runtime.h be_machine.h be_inline.h
$(BUILDDIR)/backobj/back/be_runtime.o: be_w.h be_callc.h be_task.h
$(BUILDDIR)/backobj/back/be_runtime.o: be_rterror.h be_execute.h be_symtab.h
$(BUILDDIR)/backobj/back/be_socket.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_socket.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/backobj/back/be_socket.o: be_runtime.h be_socket.h
$(BUILDDIR)/backobj/back/be_symtab.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_symtab.o: execute.h reswords.h be_execute.h
$(BUILDDIR)/backobj/back/be_symtab.o: be_alloc.h be_machine.h be_runtime.h
$(BUILDDIR)/backobj/back/be_syncolor.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_syncolor.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/backobj/back/be_syncolor.o: be_w.h
$(BUILDDIR)/backobj/back/be_task.o: global.h object.h symtab.h execute.h
$(BUILDDIR)/backobj/back/be_task.o: reswords.h be_runtime.h be_task.h
$(BUILDDIR)/backobj/back/be_task.o: be_alloc.h be_machine.h be_execute.h
$(BUILDDIR)/backobj/back/be_task.o: be_symtab.h alldefs.h
$(BUILDDIR)/backobj/back/be_w.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/backobj/back/be_w.o: execute.h reswords.h be_w.h be_machine.h
$(BUILDDIR)/backobj/back/be_w.o: be_runtime.h be_rterror.h be_alloc.h
$(BUILDDIR)/backobj/back/rbt.o: rbt.h

$(BUILDDIR)/libobj/back/be_alloc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_alloc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/libobj/back/be_alloc.o: be_alloc.h
$(BUILDDIR)/libobj/back/be_callc.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_callc.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/libobj/back/be_callc.o: be_machine.h be_alloc.h
$(BUILDDIR)/libobj/back/be_callc_conly.o: alldefs.h global.h object.h
$(BUILDDIR)/libobj/back/be_callc_conly.o: symtab.h execute.h reswords.h
$(BUILDDIR)/libobj/back/be_callc_conly.o: be_runtime.h be_machine.h
$(BUILDDIR)/libobj/back/be_decompress.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_decompress.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_execute.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_execute.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_execute.o: be_runtime.h be_decompress.h
$(BUILDDIR)/libobj/back/be_execute.o: be_inline.h be_machine.h be_task.h
$(BUILDDIR)/libobj/back/be_execute.o: be_rterror.h be_symtab.h be_w.h
$(BUILDDIR)/libobj/back/be_execute.o: be_callc.h be_execute.h
$(BUILDDIR)/libobj/back/be_inline.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_inline.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_machine.o: global.h object.h symtab.h alldefs.h
$(BUILDDIR)/libobj/back/be_machine.o: execute.h reswords.h version.h
$(BUILDDIR)/libobj/back/be_machine.o: be_runtime.h be_rterror.h be_main.h
$(BUILDDIR)/libobj/back/be_machine.o: be_w.h be_symtab.h be_machine.h
$(BUILDDIR)/libobj/back/be_machine.o: be_pcre.h pcre/pcre.h be_task.h
$(BUILDDIR)/libobj/back/be_main.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_main.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/libobj/back/be_main.o: be_execute.h be_alloc.h be_rterror.h
$(BUILDDIR)/libobj/back/be_pcre.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_pcre.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_pcre.o: be_runtime.h be_pcre.h pcre/pcre.h
$(BUILDDIR)/libobj/back/be_rterror.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_rterror.o: execute.h reswords.h be_rterror.h
$(BUILDDIR)/libobj/back/be_rterror.o: be_runtime.h be_task.h be_w.h
$(BUILDDIR)/libobj/back/be_rterror.o: be_machine.h be_execute.h be_symtab.h
$(BUILDDIR)/libobj/back/be_rterror.o: be_alloc.h be_syncolor.h
$(BUILDDIR)/libobj/back/be_runtime.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_runtime.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_runtime.o: be_runtime.h be_machine.h be_inline.h
$(BUILDDIR)/libobj/back/be_runtime.o: be_w.h be_callc.h be_task.h
$(BUILDDIR)/libobj/back/be_runtime.o: be_rterror.h be_execute.h be_symtab.h
$(BUILDDIR)/libobj/back/be_socket.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_socket.o: execute.h reswords.h be_alloc.h
$(BUILDDIR)/libobj/back/be_socket.o: be_runtime.h be_socket.h
$(BUILDDIR)/libobj/back/be_symtab.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_symtab.o: execute.h reswords.h be_execute.h
$(BUILDDIR)/libobj/back/be_symtab.o: be_alloc.h be_machine.h be_runtime.h
$(BUILDDIR)/libobj/back/be_syncolor.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_syncolor.o: execute.h reswords.h be_runtime.h
$(BUILDDIR)/libobj/back/be_syncolor.o: be_w.h
$(BUILDDIR)/libobj/back/be_task.o: global.h object.h symtab.h execute.h
$(BUILDDIR)/libobj/back/be_task.o: reswords.h be_runtime.h be_task.h
$(BUILDDIR)/libobj/back/be_task.o: be_alloc.h be_machine.h be_execute.h
$(BUILDDIR)/libobj/back/be_task.o: be_symtab.h alldefs.h
$(BUILDDIR)/libobj/back/be_w.o: alldefs.h global.h object.h symtab.h
$(BUILDDIR)/libobj/back/be_w.o: execute.h reswords.h be_w.h be_machine.h
$(BUILDDIR)/libobj/back/be_w.o: be_runtime.h be_rterror.h be_alloc.h
$(BUILDDIR)/libobj/back/rbt.o: rbt.h
