#!/usr/bin/make -f
# Makefile for DPF #
# ---------------- #
# Created by falkTX
#

AR  ?= ar
CC  ?= gcc
CXX ?= g++

# ---------------------------------------------------------------------------------------------------------------------
# Protect against multiple inclusion

ifneq ($(DPF_MAKEFILE_BASE_INCLUDED),true)

DPF_MAKEFILE_BASE_INCLUDED = true

# ---------------------------------------------------------------------------------------------------------------------
# Auto-detect OS if not defined

TARGET_MACHINE := $(shell $(CC) -dumpmachine)

ifneq ($(BSD),true)
ifneq ($(HAIKU),true)
ifneq ($(HURD),true)
ifneq ($(LINUX),true)
ifneq ($(MACOS),true)
ifneq ($(WASM),true)
ifneq ($(WINDOWS),true)

ifneq (,$(findstring bsd,$(TARGET_MACHINE)))
BSD = true
else ifneq (,$(findstring haiku,$(TARGET_MACHINE)))
HAIKU = true
else ifneq (,$(findstring linux,$(TARGET_MACHINE)))
LINUX = true
else ifneq (,$(findstring gnu,$(TARGET_MACHINE)))
HURD = true
else ifneq (,$(findstring apple,$(TARGET_MACHINE)))
MACOS = true
else ifneq (,$(findstring mingw,$(TARGET_MACHINE)))
WINDOWS = true
else ifneq (,$(findstring msys,$(TARGET_MACHINE)))
WINDOWS = true
else ifneq (,$(findstring wasm,$(TARGET_MACHINE)))
WASM = true
else ifneq (,$(findstring windows,$(TARGET_MACHINE)))
WINDOWS = true
endif

endif # WINDOWS
endif # WASM
endif # MACOS
endif # LINUX
endif # HURD
endif # HAIKU
endif # BSD

# ---------------------------------------------------------------------------------------------------------------------
# Auto-detect the processor

TARGET_PROCESSOR := $(firstword $(subst -, ,$(TARGET_MACHINE)))

ifneq (,$(filter i%86,$(TARGET_PROCESSOR)))
CPU_I386 = true
CPU_I386_OR_X86_64 = true
endif
ifneq (,$(filter wasm32,$(TARGET_PROCESSOR)))
CPU_I386 = true
CPU_I386_OR_X86_64 = true
endif
ifneq (,$(filter x86_64,$(TARGET_PROCESSOR)))
CPU_X86_64 = true
CPU_I386_OR_X86_64 = true
endif
ifneq (,$(filter arm%,$(TARGET_PROCESSOR)))
CPU_ARM = true
CPU_ARM_OR_AARCH64 = true
endif
ifneq (,$(filter arm64%,$(TARGET_PROCESSOR)))
CPU_ARM64 = true
CPU_ARM_OR_AARCH64 = true
endif
ifneq (,$(filter aarch64%,$(TARGET_PROCESSOR)))
CPU_AARCH64 = true
CPU_ARM_OR_AARCH64 = true
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set PKG_CONFIG (can be overridden by environment variable)

ifeq ($(WINDOWS),true)
# Build statically on Windows by default
PKG_CONFIG ?= pkg-config --static
else
PKG_CONFIG ?= pkg-config
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set LINUX_OR_MACOS

ifeq ($(LINUX),true)
LINUX_OR_MACOS = true
endif

ifeq ($(MACOS),true)
LINUX_OR_MACOS = true
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set MACOS_OR_WINDOWS, MACOS_OR_WASM_OR_WINDOWS, HAIKU_OR_MACOS_OR_WINDOWS and HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS

ifeq ($(HAIKU),true)
HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS = true
HAIKU_OR_MACOS_OR_WINDOWS = true
endif

ifeq ($(MACOS),true)
HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS = true
HAIKU_OR_MACOS_OR_WINDOWS = true
MACOS_OR_WASM_OR_WINDOWS = true
MACOS_OR_WINDOWS = true
endif

ifeq ($(WASM),true)
HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS = true
MACOS_OR_WASM_OR_WINDOWS = true
endif

ifeq ($(WINDOWS),true)
HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS = true
HAIKU_OR_MACOS_OR_WINDOWS = true
MACOS_OR_WASM_OR_WINDOWS = true
MACOS_OR_WINDOWS = true
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set UNIX

ifeq ($(BSD),true)
UNIX = true
endif

ifeq ($(HURD),true)
UNIX = true
endif

ifeq ($(LINUX),true)
UNIX = true
endif

ifeq ($(MACOS),true)
UNIX = true
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set build and link flags

BASE_FLAGS = -Wall -Wextra -pipe -MD -MP
BASE_OPTS  = -O3 -ffast-math -fdata-sections -ffunction-sections

ifeq ($(CPU_I386_OR_X86_64),true)
BASE_OPTS += -mtune=generic
ifeq ($(WASM),true)
# BASE_OPTS += -msse -msse2 -msse3 -msimd128
else
BASE_OPTS += -msse -msse2 -mfpmath=sse
endif
endif

ifeq ($(CPU_ARM),true)
ifneq ($(CPU_ARM64),true)
BASE_OPTS += -mfpu=neon-vfpv4 -mfloat-abi=hard
endif
endif

ifeq ($(MACOS),true)

# MacOS linker flags
LINK_OPTS  = -fdata-sections -ffunction-sections -Wl,-dead_strip,-dead_strip_dylibs
ifneq ($(SKIP_STRIPPING),true)
LINK_OPTS += -Wl,-x
endif

else

# Common linker flags
LINK_OPTS  = -fdata-sections -ffunction-sections -Wl,-O1,--gc-sections
ifneq ($(WASM),true)
LINK_OPTS += -Wl,--as-needed
ifneq ($(SKIP_STRIPPING),true)
LINK_OPTS += -Wl,--strip-all
endif
endif

endif

ifeq ($(SKIP_STRIPPING),true)
BASE_FLAGS += -g
endif

ifeq ($(NOOPT),true)
# Non-CPU-specific optimization flags
BASE_OPTS  = -O2 -ffast-math -fdata-sections -ffunction-sections
endif

ifneq ($(MACOS_OR_WASM_OR_WINDOWS),true)
ifneq ($(BSD),true)
BASE_FLAGS += -fno-gnu-unique
endif
endif

ifeq ($(WINDOWS),true)
# Assume we want posix
BASE_FLAGS += -posix -D__STDC_FORMAT_MACROS=1 -D__USE_MINGW_ANSI_STDIO=1
# Needed for windows, see https://github.com/falkTX/Carla/issues/855
BASE_FLAGS += -mstackrealign
else
# Not needed for Windows
BASE_FLAGS += -fPIC -DPIC
endif

ifeq ($(DEBUG),true)
BASE_FLAGS += -DDEBUG -O0 -g
LINK_OPTS   =
ifeq ($(WASM),true)
LINK_OPTS  += -sASSERTIONS=1
endif
else
BASE_FLAGS += -DNDEBUG $(BASE_OPTS) -fvisibility=hidden
CXXFLAGS   += -fvisibility-inlines-hidden
endif

ifeq ($(STATIC_BUILD),true)
BASE_FLAGS += -DSTATIC_BUILD
# LINK_OPTS  += -static
endif

ifeq ($(WITH_LTO),true)
BASE_FLAGS += -fno-strict-aliasing -flto
LINK_OPTS  += -fno-strict-aliasing -flto -Werror=odr -Werror=lto-type-mismatch
endif

BUILD_C_FLAGS   = $(BASE_FLAGS) -std=gnu99 $(CFLAGS)
BUILD_CXX_FLAGS = $(BASE_FLAGS) -std=gnu++11 $(CXXFLAGS)
LINK_FLAGS      = $(LINK_OPTS) $(LDFLAGS)

ifeq ($(WASM),true)
# Special flag for emscripten
LINK_FLAGS += -sLLD_REPORT_UNDEFINED
else ifneq ($(MACOS),true)
# Not available on MacOS
LINK_FLAGS += -Wl,--no-undefined
endif

ifeq ($(MACOS_OLD),true)
BUILD_CXX_FLAGS = $(BASE_FLAGS) $(CXXFLAGS) -DHAVE_CPP11_SUPPORT=0
endif

ifeq ($(WINDOWS),true)
# Always build statically on windows
LINK_FLAGS     += -static -static-libgcc -static-libstdc++
endif

# ---------------------------------------------------------------------------------------------------------------------
# Strict test build

ifeq ($(TESTBUILD),true)
BASE_FLAGS += -Werror -Wcast-qual -Wconversion -Wformat -Wformat-security -Wredundant-decls -Wshadow -Wstrict-overflow -fstrict-overflow -Wundef -Wwrite-strings
BASE_FLAGS += -Wpointer-arith -Wabi=98 -Winit-self -Wuninitialized -Wstrict-overflow=5
# BASE_FLAGS += -Wfloat-equal
ifeq ($(CC),clang)
BASE_FLAGS += -Wdocumentation -Wdocumentation-unknown-command
BASE_FLAGS += -Weverything -Wno-c++98-compat -Wno-c++98-compat-pedantic -Wno-padded -Wno-exit-time-destructors -Wno-float-equal
else
BASE_FLAGS += -Wcast-align -Wunsafe-loop-optimizations
endif
ifneq ($(MACOS),true)
BASE_FLAGS += -Wmissing-declarations -Wsign-conversion
ifneq ($(CC),clang)
BASE_FLAGS += -Wlogical-op
endif
endif
CFLAGS     += -Wold-style-definition -Wmissing-declarations -Wmissing-prototypes -Wstrict-prototypes
CXXFLAGS   += -Weffc++ -Wnon-virtual-dtor -Woverloaded-virtual
endif

# ---------------------------------------------------------------------------------------------------------------------
# Check for required libraries

HAVE_CAIRO  = $(shell $(PKG_CONFIG) --exists cairo && echo true)

ifeq ($(MACOS_OR_WASM_OR_WINDOWS),true)
HAVE_OPENGL = true
else
HAVE_OPENGL  = $(shell $(PKG_CONFIG) --exists gl && echo true)
HAVE_DBUS    = $(shell $(PKG_CONFIG) --exists dbus-1 && echo true)
HAVE_X11     = $(shell $(PKG_CONFIG) --exists x11 && echo true)
HAVE_XCURSOR = $(shell $(PKG_CONFIG) --exists xcursor && echo true)
HAVE_XEXT    = $(shell $(PKG_CONFIG) --exists xext && echo true)
HAVE_XRANDR  = $(shell $(PKG_CONFIG) --exists xrandr && echo true)
endif

# Vulkan is not supported yet
# HAVE_VULKAN = $(shell $(PKG_CONFIG) --exists vulkan && echo true)

# ---------------------------------------------------------------------------------------------------------------------
# Check for optional libraries

HAVE_LIBLO = $(shell $(PKG_CONFIG) --exists liblo && echo true)

ifeq ($(SKIP_RTAUDIO_FALLBACK),true)
CXXFLAGS += -DDPF_JACK_STANDALONE_SKIP_RTAUDIO_FALLBACK
else
ifeq ($(MACOS),true)
HAVE_RTAUDIO    = true
else ifeq ($(WINDOWS),true)
HAVE_RTAUDIO    = true
else
HAVE_ALSA       = $(shell $(PKG_CONFIG) --exists alsa && echo true)
HAVE_PULSEAUDIO = $(shell $(PKG_CONFIG) --exists libpulse-simple && echo true)
ifeq ($(HAVE_ALSA),true)
HAVE_RTAUDIO    = true
else ifeq ($(HAVE_PULSEAUDIO),true)
HAVE_RTAUDIO    = true
endif
endif
endif

# backwards compat, always available/enabled
HAVE_JACK = true

# ---------------------------------------------------------------------------------------------------------------------
# Set Generic DGL stuff

ifeq ($(HAIKU),true)
DGL_SYSTEM_LIBS += -lbe
else ifeq ($(MACOS),true)
DGL_SYSTEM_LIBS += -framework Cocoa -framework CoreVideo
else ifeq ($(WASM),true)
else ifeq ($(WINDOWS),true)
DGL_SYSTEM_LIBS += -lgdi32 -lcomdlg32
# -lole32
else
ifeq ($(HAVE_DBUS),true)
DGL_FLAGS       += $(shell $(PKG_CONFIG) --cflags dbus-1) -DHAVE_DBUS
DGL_SYSTEM_LIBS += $(shell $(PKG_CONFIG) --libs dbus-1)
endif
ifeq ($(HAVE_X11),true)
DGL_FLAGS       += $(shell $(PKG_CONFIG) --cflags x11) -DHAVE_X11
DGL_SYSTEM_LIBS += $(shell $(PKG_CONFIG) --libs x11)
ifeq ($(HAVE_XCURSOR),true)
DGL_FLAGS       += $(shell $(PKG_CONFIG) --cflags xcursor) -DHAVE_XCURSOR
DGL_SYSTEM_LIBS += $(shell $(PKG_CONFIG) --libs xcursor)
endif
ifeq ($(HAVE_XEXT),true)
DGL_FLAGS       += $(shell $(PKG_CONFIG) --cflags xext) -DHAVE_XEXT -DHAVE_XSYNC
DGL_SYSTEM_LIBS += $(shell $(PKG_CONFIG) --libs xext)
endif
ifeq ($(HAVE_XRANDR),true)
DGL_FLAGS       += $(shell $(PKG_CONFIG) --cflags xrandr) -DHAVE_XRANDR
DGL_SYSTEM_LIBS += $(shell $(PKG_CONFIG) --libs xrandr)
endif
endif
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set Cairo specific stuff

ifeq ($(HAVE_CAIRO),true)

DGL_FLAGS   += -DHAVE_CAIRO

CAIRO_FLAGS  = $(shell $(PKG_CONFIG) --cflags cairo)
CAIRO_LIBS   = $(shell $(PKG_CONFIG) --libs cairo)

HAVE_CAIRO_OR_OPENGL = true

endif

# ---------------------------------------------------------------------------------------------------------------------
# Set OpenGL specific stuff

ifeq ($(HAVE_OPENGL),true)

DGL_FLAGS   += -DHAVE_OPENGL

ifeq ($(HAIKU),true)
OPENGL_FLAGS = $(shell $(PKG_CONFIG) --cflags gl)
OPENGL_LIBS  = $(shell $(PKG_CONFIG) --libs gl)
else ifeq ($(MACOS),true)
OPENGL_FLAGS = -DGL_SILENCE_DEPRECATION=1 -Wno-deprecated-declarations
OPENGL_LIBS  = -framework OpenGL
else ifeq ($(WASM),true)
ifneq ($(USE_GLES2),true)
ifneq ($(USE_GLES3),true)
OPENGL_LIBS  =  -sLEGACY_GL_EMULATION -sGL_UNSAFE_OPTS=0
endif
endif
else ifeq ($(WINDOWS),true)
OPENGL_LIBS  = -lopengl32
else
OPENGL_FLAGS = $(shell $(PKG_CONFIG) --cflags gl x11)
OPENGL_LIBS  = $(shell $(PKG_CONFIG) --libs gl x11)
endif

HAVE_CAIRO_OR_OPENGL = true

endif

# ---------------------------------------------------------------------------------------------------------------------
# Set Stub specific stuff

ifeq ($(MACOS_OR_WASM_OR_WINDOWS),true)
HAVE_STUB = true
else
HAVE_STUB = $(HAVE_X11)
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set Vulkan specific stuff

ifeq ($(HAVE_VULKAN),true)

DGL_FLAGS   += -DHAVE_VULKAN

VULKAN_FLAGS  = $(shell $(PKG_CONFIG) --cflags vulkan)
VULKAN_LIBS   = $(shell $(PKG_CONFIG) --libs vulkan)

ifneq ($(WINDOWS),true)
VULKAN_LIBS  += -ldl
endif

endif

# ---------------------------------------------------------------------------------------------------------------------
# Set optional libraries specific stuff

ifeq ($(HAVE_ALSA),true)
ALSA_FLAGS = $(shell $(PKG_CONFIG) --cflags alsa)
ALSA_LIBS  = $(shell $(PKG_CONFIG) --libs alsa)
endif

ifeq ($(HAVE_LIBLO),true)
LIBLO_FLAGS = $(shell $(PKG_CONFIG) --cflags liblo)
LIBLO_LIBS  = $(shell $(PKG_CONFIG) --libs liblo)
endif

ifeq ($(HAVE_PULSEAUDIO),true)
PULSEAUDIO_FLAGS = $(shell $(PKG_CONFIG) --cflags libpulse-simple)
PULSEAUDIO_LIBS  = $(shell $(PKG_CONFIG) --libs libpulse-simple)
endif

ifeq ($(HAVE_JACK),true)
ifeq ($(STATIC_BUILD),true)
JACK_FLAGS = $(shell $(PKG_CONFIG) --cflags jack)
JACK_LIBS  = $(shell $(PKG_CONFIG) --libs jack)
endif
endif

ifneq ($(HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS),true)
SHARED_MEMORY_LIBS = -lrt
endif

# ---------------------------------------------------------------------------------------------------------------------
# Backwards-compatible HAVE_DGL

ifeq ($(MACOS_OR_WINDOWS),true)
HAVE_DGL = true
else ifeq ($(HAVE_OPENGL),true)
HAVE_DGL = $(HAVE_X11)
endif

# ---------------------------------------------------------------------------------------------------------------------
# Namespace flags

ifneq ($(DISTRHO_NAMESPACE),)
BUILD_CXX_FLAGS += -DDISTRHO_NAMESPACE=$(DISTRHO_NAMESPACE)
endif

ifneq ($(DGL_NAMESPACE),)
BUILD_CXX_FLAGS += -DDGL_NAMESPACE=$(DGL_NAMESPACE)
endif

# ---------------------------------------------------------------------------------------------------------------------
# Optional flags

ifeq ($(NVG_DISABLE_SKIPPING_WHITESPACE),true)
BUILD_CXX_FLAGS += -DNVG_DISABLE_SKIPPING_WHITESPACE
endif

ifneq ($(NVG_FONT_TEXTURE_FLAGS),)
BUILD_CXX_FLAGS += -DNVG_FONT_TEXTURE_FLAGS=$(NVG_FONT_TEXTURE_FLAGS)
endif

ifeq ($(FILE_BROWSER_DISABLED),true)
BUILD_CXX_FLAGS += -DDGL_FILE_BROWSER_DISABLED
endif

ifneq ($(WINDOWS_ICON_ID),)
BUILD_CXX_FLAGS += -DDGL_WINDOWS_ICON_ID=$(WINDOWS_ICON_ID)
endif

ifeq ($(USE_GLES2),true)
BUILD_CXX_FLAGS += -DDGL_USE_GLES -DDGL_USE_GLES2
endif

ifeq ($(USE_GLES3),true)
BUILD_CXX_FLAGS += -DDGL_USE_GLES -DDGL_USE_GLES3
endif

ifeq ($(USE_OPENGL3),true)
BUILD_CXX_FLAGS += -DDGL_USE_OPENGL3
endif

ifeq ($(USE_NANOVG_FBO),true)
BUILD_CXX_FLAGS += -DDGL_USE_NANOVG_FBO
endif

ifeq ($(USE_NANOVG_FREETYPE),true)
BUILD_CXX_FLAGS += -DFONS_USE_FREETYPE $(shell $(PKG_CONFIG) --cflags freetype2)
endif

ifeq ($(USE_RGBA),true)
BUILD_CXX_FLAGS += -DDGL_USE_RGBA
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set app extension

ifeq ($(WASM),true)
APP_EXT = .html
else ifeq ($(WINDOWS),true)
APP_EXT = .exe
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set shared lib extension

ifeq ($(MACOS),true)
LIB_EXT = .dylib
else ifeq ($(WASM),true)
LIB_EXT = .wasm
else ifeq ($(WINDOWS),true)
LIB_EXT = .dll
else
LIB_EXT = .so
endif

# ---------------------------------------------------------------------------------------------------------------------
# Set shared library CLI arg

ifeq ($(MACOS),true)
SHARED = -dynamiclib
else ifeq ($(WASM),true)
SHARED = -sSIDE_MODULE=2
else
SHARED = -shared
endif

# ---------------------------------------------------------------------------------------------------------------------
# Handle the verbosity switch

SILENT =

ifeq ($(VERBOSE),1)
else ifeq ($(VERBOSE),y)
else ifeq ($(VERBOSE),yes)
else ifeq ($(VERBOSE),true)
else
SILENT = @
endif

# ---------------------------------------------------------------------------------------------------------------------
# all needs to be first

all:

# ---------------------------------------------------------------------------------------------------------------------
# helper to print what is available/possible to build

print_available = @echo $(1): $(shell echo $($(1)) | grep -q true && echo Yes || echo No)

features:
	@echo === Detected CPU
	$(call print_available,CPU_AARCH64)
	$(call print_available,CPU_ARM)
	$(call print_available,CPU_ARM64)
	$(call print_available,CPU_ARM_OR_AARCH64)
	$(call print_available,CPU_I386)
	$(call print_available,CPU_I386_OR_X86_64)
	@echo === Detected OS
	$(call print_available,BSD)
	$(call print_available,HAIKU)
	$(call print_available,HURD)
	$(call print_available,LINUX)
	$(call print_available,MACOS)
	$(call print_available,WASM)
	$(call print_available,WINDOWS)
	$(call print_available,HAIKU_OR_MACOS_OR_WASM_OR_WINDOWS)
	$(call print_available,HAIKU_OR_MACOS_OR_WINDOWS)
	$(call print_available,LINUX_OR_MACOS)
	$(call print_available,MACOS_OR_WASM_OR_WINDOWS)
	$(call print_available,MACOS_OR_WINDOWS)
	$(call print_available,UNIX)
	@echo === Detected features
	$(call print_available,HAVE_ALSA)
	$(call print_available,HAVE_DBUS)
	$(call print_available,HAVE_CAIRO)
	$(call print_available,HAVE_DGL)
	$(call print_available,HAVE_LIBLO)
	$(call print_available,HAVE_OPENGL)
	$(call print_available,HAVE_PULSEAUDIO)
	$(call print_available,HAVE_RTAUDIO)
	$(call print_available,HAVE_STUB)
	$(call print_available,HAVE_VULKAN)
	$(call print_available,HAVE_X11)
	$(call print_available,HAVE_XCURSOR)
	$(call print_available,HAVE_XEXT)
	$(call print_available,HAVE_XRANDR)

# ---------------------------------------------------------------------------------------------------------------------
# Protect against multiple inclusion

endif # DPF_MAKEFILE_BASE_INCLUDED

# ---------------------------------------------------------------------------------------------------------------------
