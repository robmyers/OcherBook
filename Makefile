.PHONY: clean test dist dist-src doc help

# TODO:
# conditionalize freetype, etc
# header dependencies
# move all objs to build/
# obj-$(CONFIG_FOO) += foo.o
# auto-detect platform
# create config.h


#################### Tuneables

DL_DIR=dl
BUILD_DIR=build

include ocher.config


#################### Platforms

AR=ar
CC=gcc
CXX=g++
STRIP=strip
ifeq ($(OCHER_TARGET),kobo)
	AR=$(PWD)/arm-2010q1/bin/arm-linux-ar
	CC=$(PWD)/arm-2010q1/bin/arm-linux-gcc
	CXX=$(PWD)/arm-2010q1/bin/arm-linux-g++
endif
QUIET=@
MSG=@echo
ifeq ($(VERBOSE),1)
	QUIET=
	MSG=@true
endif
ifeq ($(OCHER_VERBOSE),1)
	QUIET=
	MSG=@true
endif


#################### CFLAGS

# Common CFLAGS applied everywhere
CFLAGS?=
ifeq ($(OCHER_DEBUG),1)
	CFLAGS+=-O0 -g -DDEBUG
else
	CFLAGS+=-Os -DNDEBUG
endif
ifeq ($(OCHER_TARGET),kobo)
	CFLAGS+=-Wno-psabi  # suppress "mangling of va_list has changed"
endif
MINIZIP_CFLAGS=-Wno-unused
ifeq ($(OCHER_TARGET),freebsd)
	MINIZIP_CFLAGS+=-DUSE_FILE32API
endif
ifeq ($(OCHER_TARGET),cygwin)
	MINIZIP_CFLAGS+=-DUSE_FILE32API
	INCS+=-I/usr/include/ncurses
endif
ifeq ($(OCHER_TARGET),haiku)
	MINIZIP_CFLAGS+=-DUSE_FILE32API
endif
CFLAGS+=-I. -Ibuild -DSINGLE_THREADED
CFLAGS_COMMON:=$(CFLAGS)
ifneq ($(OCHER_TARGET),haiku)
	CFLAGS+=-std=c99
endif

# Additional CFLAGS for ocher
OCHER_CFLAGS=-Wall -W -Wformat=2 -Wno-write-strings -Wshadow
ifeq ($(OCHER_DEV),1)
	OCHER_CFLAGS+=-Werror
endif
OCHER_CFLAGS+=-DOCHER_MAJOR=$(OCHER_MAJOR) -DOCHER_MINOR=$(OCHER_MINOR) -DOCHER_PATCH=$(OCHER_PATCH)

default: ocher


#################### Fonts

FREEFONT_VER=20120503
FREEFONT_FILE=freefont-otf-$(FREEFONT_VER).tar.gz
FREEFONT_URL=http://ftp.gnu.org/gnu/freefont/$(FREEFONT_FILE)
FREEFONT_TGZ=$(DL_DIR)/$(FREEFONT_FILE)

fonts:
	@[ -e $(FREEFONT_TGZ) ] || (echo -e "Please download $(FREEFONT_URL) to $(DL_DIR)" ; exit 1)
	@mkdir -p $(BUILD_DIR)
	tar -zxf $(FREEFONT_TGZ) -C $(BUILD_DIR)


#################### FreeType

FREETYPE_VER=2.4.8
FREETYPE_TGZ=$(DL_DIR)/freetype-$(FREETYPE_VER).tar.gz
FREETYPE_DIR=$(BUILD_DIR)/freetype-$(FREETYPE_VER)
FREETYPE_DEFS=-I$(FREETYPE_DIR)/include
FREETYPE_LIB=$(FREETYPE_DIR)/objs/.libs/libfreetype.a

$(FREETYPE_LIB):
	@mkdir -p $(BUILD_DIR)
	tar -zxf $(FREETYPE_TGZ) -C $(BUILD_DIR)
	cd $(FREETYPE_DIR) && GNUMAKE=$(MAKE) CFLAGS="$(CFLAGS_COMMON) -O3" CC=$(CC) ./configure --without-bzip2 --disable-shared --host i686-linux
	cd $(FREETYPE_DIR) && $(MAKE)

freetype_clean:
	cd $(FREETYPE_DIR) && $(MAKE) clean || true
	rm -f $(FREETYPE_LIB)

#################### Zlib

ZLIB_VER=1.2.5
ZLIB_TGZ=$(DL_DIR)/zlib-$(ZLIB_VER).tar.gz
ZLIB_DIR=$(BUILD_DIR)/zlib-$(ZLIB_VER)
ZLIB_LIB=$(ZLIB_DIR)/libz.a

$(ZLIB_LIB):
	@mkdir -p $(BUILD_DIR)
	tar -zxf $(ZLIB_TGZ) -C $(BUILD_DIR)
	cd $(ZLIB_DIR) && CFLAGS="$(CFLAGS_COMMON) -O3" CC=$(CC) ./configure --static
	cd $(ZLIB_DIR) && $(MAKE)

INCS+=-I$(ZLIB_DIR) -I$(ZLIB_DIR)/contrib/minizip
ZLIB_OBJS = \
	$(ZLIB_DIR)/contrib/minizip/unzip.o \
	$(ZLIB_DIR)/contrib/minizip/ioapi.o

zlib_clean:
	rm -f $(ZLIB_OBJS) $(ZLIB_LIB)


#################### miniXML

MXML_VER=2.7
MXML_TGZ=$(DL_DIR)/mxml-$(MXML_VER).tar.gz
MXML_DIR=$(BUILD_DIR)/mxml-$(MXML_VER)
MXML_LIB=$(MXML_DIR)/libmxml.a

$(MXML_LIB):
	@mkdir -p $(BUILD_DIR)
	tar -zxf $(MXML_TGZ) -C $(BUILD_DIR)
	cd $(MXML_DIR) && CFLAGS="$(CFLAGS_COMMON -O3)" CC=$(CC) ./configure --host i686-linux
	cd $(MXML_DIR) && $(MAKE) libmxml.a

INCS+=-I$(MXML_DIR)

mxml_clean:
	cd $(MXML_DIR) && $(MAKE) clean || true


#################### UnitTest++

UNITTESTCPP_ROOT = test/unittest-cpp/UnitTest++/
UNITTESTCPP_LIB = $(BUILD_DIR)/libUnitTest++.a
UNITTESTCPP_OBJS = \
	$(UNITTESTCPP_ROOT)/src/AssertException.o \
	$(UNITTESTCPP_ROOT)/src/Test.o \
	$(UNITTESTCPP_ROOT)/src/Checks.o \
	$(UNITTESTCPP_ROOT)/src/TestRunner.o \
	$(UNITTESTCPP_ROOT)/src/TestResults.o \
	$(UNITTESTCPP_ROOT)/src/TestReporter.o \
	$(UNITTESTCPP_ROOT)/src/TestReporterStdout.o \
	$(UNITTESTCPP_ROOT)/src/ReportAssert.o \
	$(UNITTESTCPP_ROOT)/src/TestList.o \
	$(UNITTESTCPP_ROOT)/src/TimeConstraint.o \
	$(UNITTESTCPP_ROOT)/src/TestDetails.o \
	$(UNITTESTCPP_ROOT)/src/MemoryOutStream.o \
	$(UNITTESTCPP_ROOT)/src/DeferredTestReporter.o \
	$(UNITTESTCPP_ROOT)/src/DeferredTestResult.o \
	$(UNITTESTCPP_ROOT)/src/XmlTestReporter.o \
	$(UNITTESTCPP_ROOT)/src/CurrentTest.o
ifeq ($(TARGET), MINGW32)
	UNITTESTCPP_OBJS += \
		$(UNITTESTCPP_ROOT)/src/Win32/TimeHelpers.o
else
	UNITTESTCPP_OBJS += \
		$(UNITTESTCPP_ROOT)/src/Posix/SignalTranslator.o \
		$(UNITTESTCPP_ROOT)/src/Posix/TimeHelpers.o
endif

$(UNITTESTCPP_LIB): $(UNITTESTCPP_OBJS)
	$(MSG) "LINK	$@"
	$(QUIET)$(AR) rs $(UNITTESTCPP_LIB) $(UNITTESTCPP_OBJS)

unittestpp_clean:
	rm -f $(UNITTESTCPP_OBJS)


#################### OcherBook

OCHER_CFLAGS+=$(INCS) $(FREETYPE_DEFS)
ifeq ($(OCHER_DEBUG),1)
	OCHER_CFLAGS+=-DCLC_LOG_LEVEL=5
else
	OCHER_CFLAGS+=-DCLC_LOG_LEVEL=2
endif
OCHER_CXXFLAGS:=$(OCHER_CFLAGS) -fno-rtti
ifneq ($(OCHER_TARGET),haiku)
	LD_FLAGS+=-lrt
endif
LD_FLAGS+=$(OCHER_LIBS)

CLC_OBJS = \
	clc/algorithm/Random.o \
	clc/crypto/MurmurHash2.o \
	clc/data/Buffer.o \
	clc/data/Hashtable.o \
	clc/data/List.o \
	clc/data/Set.o \
	clc/data/StrUtil.o \
	clc/os/Clock.o \
	clc/os/Lock.o \
	clc/os/Monitor.o \
	clc/os/Thread.o \
	clc/storage/DirIter.o \
	clc/storage/File.o \
	clc/storage/Path.o \
	clc/support/Debug.o \
	clc/support/Logger.o \

OCHER_OBJS = \
	$(CLC_OBJS) \
	ocher/device/Device.o \
	ocher/device/Filesystem.o \
	ocher/fmt/Format.o \
	ocher/fmt/Layout.o \
	ocher/shelf/Meta.o \
	ocher/ocher.o \
	ocher/settings/Settings.o \
	ocher/ux/Browse.o \
	ocher/ux/Controller.o \
	ocher/ux/Event.o \
	ocher/ux/Factory.o \
	ocher/ux/Pagination.o \
	ocher/ux/Renderer.o

ifeq ($(OCHER_TARGET),kobo)
OCHER_OBJS += \
	ocher/device/kobo/KoboEvents.o
endif

ifeq ($(OCHER_AIRBAG_FD),1)
OCHER_OBJS += \
	airbag_fd/airbag_fd.o
OCHER_LIBS += -ldl
endif

ifeq ($(OCHER_EPUB),1)
OCHER_OBJS += \
	ocher/fmt/epub/Epub.o \
	ocher/fmt/epub/UnzipCache.o \
	ocher/fmt/epub/LayoutEpub.o \
	$(ZLIB_OBJS)
OCHER_CFLAGS+=$(MINIZIP_CFLAGS)  #TODO limit to just minizip
endif

ifeq ($(OCHER_TEXT),1)
OCHER_OBJS += \
	ocher/fmt/text/Text.o \
	ocher/fmt/text/LayoutText.o
endif

OCHER_UI_FB=$(shell [ "$(OCHER_UI_SDL)" = "1" ] || [ "$(OCHER_UI_MX50)" = "1" ] && echo 1 )
ifeq ($(OCHER_UI_FB), 1)
OCHER_OBJS += \
	ocher/ux/fb/BrowseFb.o \
	ocher/ux/fb/FactoryFb.o \
	ocher/ux/fb/FrameBuffer.o \
	ocher/ux/fb/FreeType.o \
	ocher/ux/fb/RenderFb.o \
	ocher/ux/fb/Widgets.o
endif

ifeq ($(OCHER_UI_SDL),1)
	OCHER_OBJS += \
		ocher/ux/fb/sdl/SdlLoop.o \
		ocher/ux/fb/sdl/FactoryFbSdl.o \
		ocher/ux/fb/sdl/FbSdl.o
	OCHER_LIBS += -lSDL
endif

ifeq ($(OCHER_UI_MX50),1)
	OCHER_OBJS += \
		ocher/ux/fb/mx50/fb.o \
		ocher/ux/fb/mx50/FactoryFbMx50.o
endif

ifeq ($(OCHER_UI_FD),1)
	OCHER_OBJS += \
		ocher/ux/fd/BrowseFd.o \
		ocher/ux/fd/RenderFd.o \
		ocher/ux/fd/FactoryFd.o
endif

ifeq ($(OCHER_UI_NCURSES),1)
	OCHER_OBJS += \
		ocher/ux/ncurses/Browse.o \
		ocher/ux/ncurses/RenderCurses.o \
		ocher/ux/ncurses/FactoryNC.o
	OCHER_LIBS += -lcdk
endif

CONFIG_BOOL=OCHER_DEV OCHER_DEBUG OCHER_AIRBAG_FD OCHER_EPUB OCHER_TEXT OCHER_HTML OCHER_UI_FD OCHER_UI_NCURSES OCHER_UI_SDL OCHER_UI_MX50
lc = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$1))))))))))))))))))))))))))
uc = $(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$1))))))))))))))))))))))))))
OCHER_%:
	@([ "$(OCHER_$*)" = "1" ] && echo "#define OCHER_$* 1" || echo "/* OCHER_$* */") >> $(BUILD_DIR)/ocher_config.h
ocher_config_clean:
	@rm -f $(BUILD_DIR)/ocher_config.h
$(BUILD_DIR)/ocher_config.h: Makefile ocher.config | ocher_config_clean $(CONFIG_BOOL)
	@echo "CONFIG	ocher_config.h"
	@mkdir -p $(BUILD_DIR)
	@echo "#define OCHER_TARGET_$(call uc,$(OCHER_TARGET))" >> $(BUILD_DIR)/ocher_config.h
config: $(BUILD_DIR)/ocher_config.h
$(OCHER_OBJS): Makefile ocher.config | $(BUILD_DIR)/ocher_config.h

#ODIR=obj
#OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))

.c.o:
	$(MSG) "CC	$*.c"
	$(QUIET)$(CC) -c $(CFLAGS_COMMON) $(OCHER_CFLAGS) $*.c -o $@

.cpp.o:
	$(MSG) "CXX	$*.cpp"
	$(QUIET)$(CXX) -c $(CFLAGS_COMMON) $(OCHER_CXXFLAGS) $*.cpp -o $@

ocher: $(BUILD_DIR)/ocher
$(BUILD_DIR)/ocher: $(ZLIB_LIB) $(FREETYPE_LIB) $(MXML_LIB) $(OCHER_OBJS)
	$(MSG) "LINK	$@"
	$(QUIET)$(CXX) $(LD_FLAGS) $(CFLAGS_COMMON) $(OCHER_CXXFLAGS) -o $@ $(OCHER_OBJS) $(ZLIB_LIB) $(FREETYPE_LIB) $(MXML_LIB)


#################### test

clctest: $(CLC_OBJS) $(UNITTESTCPP_LIB)
	$(MSG) "LINK	$@"
	$(QUIET)$(CXX) $(CFLAGS_COMMON) clc/test/clcTestMain.cpp -I. -I$(UNITTESTCPP_ROOT)/src $^ -o $(BUILD_DIR)/$@ -L$(BUILD_DIR) -lrt -lpthread

ochertest:
	# TODO

test: clctest ochertest


####################

clean: zlib_clean freetype_clean mxml_clean ocher_config_clean unittestpp_clean
	rm -f $(OCHER_OBJS) $(BUILD_DIR)/ocher

dist: ocher
	tar -C $(BUILD_DIR) -Jcf ocher-`uname -s`-$(OCHER_MAJOR).$(OCHER_MINOR).$(OCHER_PATCH).tar.xz ocher

dist-src: clean
	git status clc dl doc ocher
	tar -Jcf ocher-src-$(OCHER_MAJOR).$(OCHER_MINOR).$(OCHER_PATCH).tar.xz Makefile README clc dl doc ocher

doc:
	cd ocher && doxygen ../doc/Doxyfile

help:
	@echo "Edit ocher.config with your desired settings, then 'make'."
	@echo ""
	@echo "Targets:"
	@echo "	clean		Clean"
	@echo "	fonts		Download GPL fonts"
	@echo "*	ocher		Build the e-reader software"
	@echo "	test		Build and run the unit tests"
	@echo "	doc		Run Doxygen"
	@echo "	dist		Build distribution packages"

