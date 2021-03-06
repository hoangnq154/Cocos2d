all:

DEFINES += -DEMSCRIPTEN -DCC_KEYBOARD_SUPPORT -DGL_ES=1

THIS_MAKEFILE := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
ifndef COCOS_ROOT
COCOS_ROOT ?= $(realpath $(dir $(THIS_MAKEFILE))/../..)
else
RPATH_REL = ../..
endif
COCOS_SRC = $(COCOS_ROOT)/cocos2dx
OBJ_DIR ?= obj

EMSCRIPTEN_ROOT ?= $(realpath $(COCOS_ROOT)/external/emscripten)
PACKAGER := $(EMSCRIPTEN_ROOT)/tools/file_packager.py

AR  := $(EMSCRIPTEN_ROOT)/emar
CC  := $(EMSCRIPTEN_ROOT)/emcc
CXX := $(EMSCRIPTEN_ROOT)/em++
ARFLAGS = cr

# XXX: Not entirely sure why main, malloc and free need to be explicitly listed
# here, but after adding a --js-library library, these symbols seem to get
# stripped unless enumerated here.
EXPORTED_FLAGS := -s EXPORTED_FUNCTIONS="['_CCTextureCacheEmscripten_addImageAsyncCallBack','_CCTextureCacheEmscripten_preMultiplyImageRegion','_malloc','_free','_main']"
JSLIBS := --js-library $(COCOS_SRC)/platform/emscripten/CCTextureCacheEmscripten.js

CCFLAGS  += -MMD -Wall -fPIC -Wno-overloaded-virtual -s USE_ZLIB=1 -s USE_LIBPNG=1 -s VERBOSE=1 -U__native_client__ -Wno-deprecated-declarations $(EXPORTED_FLAGS) $(JSLIBS)
CXXFLAGS += -MMD -Wall -fPIC -Wno-overloaded-virtual -s USE_ZLIB=1 -s USE_LIBPNG=1 -s VERBOSE=1 -U__native_client__ -Wno-deprecated-declarations $(EXPORTED_FLAGS) $(JSLIBS) -std=c++11

LIB_DIR = $(COCOS_ROOT)/lib/emscripten
BIN_DIR = bin

INCLUDES +=  \
    -I$(COCOS_SRC) \
    -I$(COCOS_SRC)/cocoa \
    -I$(COCOS_SRC)/include \
    -I$(COCOS_SRC)/kazmath/include \
    -I$(COCOS_SRC)/platform/emscripten \
    -I$(COCOS_SRC)/platform/third_party/emscripten/libtiff/include \
    -I$(COCOS_SRC)/platform/third_party/emscripten/libjpeg \
    -I$(COCOS_SRC)/platform/third_party/emscripten/libwebp

LBITS := $(shell getconf LONG_BIT)
INCLUDES += -I$(COCOS_SRC)/platform/third_party/linux

ifeq ($(DEBUG), 1)
CCFLAGS  += -O1 -s STB_IMAGE=1 -s GL_ASSERTIONS=1 -s ASSERTIONS=2 -s GL_UNSAFE_OPTS=0 -s INVOKE_RUN=0 -s WARN_ON_UNDEFINED_SYMBOLS=1 -s SAFE_HEAP=0 -s DEMANGLE_SUPPORT=1 -s UNALIGNED_MEMORY=0 -s ASM_JS=1 -s SAFE_HEAP_LOG=0
CXXFLAGS += -O1 -s STB_IMAGE=1 -s GL_ASSERTIONS=1 -s ASSERTIONS=2 -s GL_UNSAFE_OPTS=0 -s INVOKE_RUN=0 -s WARN_ON_UNDEFINED_SYMBOLS=1 -s SAFE_HEAP=0 -s DEMANGLE_SUPPORT=1 -s UNALIGNED_MEMORY=0 -s ASM_JS=1 -s SAFE_HEAP_LOG=0
DEFINES += -D_DEBUG -DCOCOS2D_DEBUG=1 -DCP_USE_DOUBLES=0
OBJ_DIR := $(OBJ_DIR)/debug
LIB_DIR := $(LIB_DIR)/debug
BIN_DIR := $(BIN_DIR)/debug
else
CCFLAGS  += -O3 -s STB_IMAGE=1 -s INVOKE_RUN=0 -s NO_EXIT_RUNTIME=1
CXXFLAGS += -O3 -s STB_IMAGE=1 -s INVOKE_RUN=0 -s NO_EXIT_RUNTIME=1
DEFINES += -DNDEBUG -DCP_USE_DOUBLES=0
OBJ_DIR := $(OBJ_DIR)/release
LIB_DIR := $(LIB_DIR)/release
BIN_DIR := $(BIN_DIR)/release
endif

ifndef V
LOG_CC = @echo " CC $@";
LOG_CXX = @echo " CXX $@";
LOG_AR = @echo " AR $@";
LOG_LINK = @echo " LINK $@";
endif

OBJECTS := $(SOURCES:.cpp=.o)
OBJECTS := $(OBJECTS:.c=.o)
OBJECTS := $(subst ../,,$(OBJECTS))
OBJECTS := $(subst $(COCOS_ROOT)/,,$(OBJECTS))
OBJECTS := $(addprefix $(OBJ_DIR)/, $(OBJECTS))
DEPS = $(OBJECTS:.o=.d)
CORE_MAKEFILE_LIST := $(MAKEFILE_LIST)
-include $(DEPS)

STATICLIBS_DIR = $(COCOS_SRC)/platform/third_party/emscripten/libraries
STATICLIBS = \
    $(STATICLIBS_DIR)/libtiff.a \
    $(STATICLIBS_DIR)/libjpeg.a \
    $(STATICLIBS_DIR)/libwebp.a

STATICLIBS =

SHAREDLIBS += -L$(LIB_DIR) -Wl,-rpath,$(RPATH_REL)/$(LIB_DIR)
LIBS = -lrt -lz

HTMLTPL_DIR = $(COCOS_ROOT)/tools/emscripten-templates/basic
HTMLTPL_FILE = index.html

clean:
	rm -rf $(OBJ_DIR)
	rm -rf $(TARGET).js $(TARGET).data $(TARGET).data.js $(BIN_DIR) core

.PHONY: all clean

# If the parent Makefile defines $(EXECUTABLE) then define this as the target
# and create a 'make run' rule to run the app.
ifdef EXECUTABLE
TARGET := $(BIN_DIR)/$(EXECUTABLE)

all: $(TARGET).js $(TARGET).data $(BIN_DIR)/$(HTMLTPL_FILE)

run: $(TARGET)
	cd $(dir $^) && ./$(notdir $^)

.PHONY: run
endif
