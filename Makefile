# Toolchain root for the MSP430 build.
# CI may set either `TOOLS_PATH` (preferred) or a legacy `TOOL_PATH`.
ifdef TOOL_PATH
TOOLS_PATH ?= $(TOOL_PATH)
endif
TOOLS_PATH ?= C:/Users/User/dev/tools

# Check arguments: require HW= unless goal is clean, cppcheck, or format
ifeq ($(HW),LAUNCHPAD)
    TARGET_HW = launchpad
else ifeq ($(HW),NSUMO)
    TARGET_HW = nsumo
else ifeq ($(MAKECMDGOALS),clean)
    TARGET_NAME =
else ifeq ($(MAKECMDGOALS),cppcheck)
    TARGET_NAME =
else ifeq ($(MAKECMDGOALS),format)
    TARGET_NAME =
else
    $(error Must pass HW=LAUNCHPAD or HW=NSUMO)
endif

TARGET_NAME=$(TARGET_HW)

ifneq ($(TEST),)
ifeq ($(findstring test_,$(TEST)),)
$(error "TEST=$(TEST) is invalid (test function must start with test_)")
else
TARGET_NAME=$(TEST)
endif
endif

# Directories
TOOLS_DIR = ${TOOLS_PATH}
MSPGCC_ROOT_DIR = $(TOOLS_DIR)/msp430-gcc
MSPGCC_BIN_DIR = $(MSPGCC_ROOT_DIR)/bin
MSPGCC_INCLUDE_DIR = $(MSPGCC_ROOT_DIR)/include

BUILD_BASE = build
BUILD_DIR = $(BUILD_BASE)
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin

TI_CCS_DIR = $(TOOLS_DIR)/ccs2041/ccs
CCS_INCLUDE_GCC_DIR = $(TI_CCS_DIR)/ccs_base/msp430/include_gcc

# Determine executable extension based on what exists in the toolchain.
# This is more robust than relying on `$(OS)` being set correctly in CI.
ifneq ($(wildcard $(MSPGCC_BIN_DIR)/msp430-elf-gcc.exe),)
    EXT = .exe
else
    EXT =
endif

# On non-Windows toolchains, CCS headers live directly under the msp430-gcc root.
ifeq ($(EXT),)
    CCS_INCLUDE_GCC_DIR = $(MSPGCC_ROOT_DIR)/include
endif

LIB_DIRS = $(MSPGCC_INCLUDE_DIR) $(CCS_INCLUDE_GCC_DIR)
INCLUDE_DIRS = $(MSPGCC_INCLUDE_DIR) \
			   $(CCS_INCLUDE_GCC_DIR) \
			   ./src \
			   ./external/ \
			   ./external/printf

# Toolchain
CC = $(MSPGCC_BIN_DIR)/msp430-elf-gcc$(EXT)
OBJCOPY = $(MSPGCC_BIN_DIR)/msp430-elf-objcopy$(EXT)
DSLite = $(TI_CCS_DIR)/ccs_base/DebugServer/bin/DSLite$(EXT)
RM = rm
CPPCHECK = cppcheck
FORMAT = clang-format
SIZE = $(MSPGCC_BIN_DIR)/msp430-elf-size
READELF = $(MSPGCC_BIN_DIR)/msp430-elf-readelf

# Files
TARGET = $(BUILD_DIR)/bin/$(TARGET_HW)/$(TARGET_NAME)

DRIVERS_SRC = $(addprefix src/drivers/,\
				io.c \
				mcu_init.c \
				led.c \
				)
APP_SRC = $(addprefix src/app/,\
			drive.c \
	  	  	enemy.c \
			)
SOURCES_WITH_HEADERS = \
		  $(DRIVERS_SRC) \
		  $(APP_SRC) \
		  src/common/assert_handler.c \
		  src/common/ring_buffer.c \
		  src/drivers/uart.c

ifndef TEST
SOURCES = src/main.c \
		  $(SOURCES_WITH_HEADERS)
else
SOURCES = src/test/test.c \
		  $(SOURCES_WITH_HEADERS)
$(shell rm -f $(OBJ_DIR)/src/test/test.o)
endif

HEADERS = $(shell find src -name "*.h") \
		  $(shell find external -name "*.h")
FORMAT_HEADERS = $(shell find src -name "*.h")

size: $(TARGET)
	@$(SIZE) $(TARGET)

symbols: $(TARGET)
	# List symbols table sorted by size
	@$(READELF) -s $(TARGET) | sort -n -k3

OBJECT_NAMES = $(SOURCES:.c=.o)
OBJECTS = $(patsubst %,$(OBJ_DIR)/%,$(OBJECT_NAMES))

# Static Analysis
## Don't check the msp430 helper headers (they have a LOT of ifdefs)
CPPCHECK_INCLUDES = ./src
CPPCHECK_IGNORE = external/printf
CPPCHECK_FLAGS = \
	--quiet --enable=all --error-exitcode=1 \
	--inline-suppr \
	--suppress=missingIncludeSystem \
	--suppress=unmatchedSuppression \
	--suppress=unusedFunction \
	--suppress=staticFunction \
	--suppress=checkersReport \
	--suppress=toomanyconfigs \
	$(addprefix -I,$(CPPCHECK_INCLUDES)) \
	$(addprefix -i,$(CPPCHECK_IGNORE))

# Flags
MCU = msp430g2553
WFLAGS = -Wall -Wextra -Werror -Wshadow
HW_DEFINE = $(addprefix -D,$(HW))
TEST_DEFINE = $(addprefix -DTEST=,$(TEST))
DEFINES = $(HW_DEFINE) $(TEST_DEFINE)
CFLAGS = -mmcu=$(MCU) $(WFLAGS) -fshort-enums $(addprefix -I,$(INCLUDE_DIRS)) $(DEFINES) -Og -g
LDFLAGS = -mmcu=$(MCU) $(DEFINES) $(addprefix -L,$(LIB_DIRS))

# Build
## Linking
$(TARGET): $(OBJECTS) $(HEADERS)
	@echo $(OBJECTS)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@

## ELF to HEX
$(TARGET).hex: $(TARGET)
	$(OBJCOPY) -O ihex $(TARGET) $(TARGET).hex

## Compiling
$(OBJ_DIR)/%.o: %.c $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

# Phonies
.PHONY: all clean flash cppcheck format

all: $(TARGET).hex

clean:
	$(RM) -rf $(BUILD_BASE)

flash: $(TARGET).hex
	@echo "Flashing $(TARGET).hex to MSP430G2553..."
	$(DSLite) load -c MSP430G2553.ccxml $(TARGET).hex

cppcheck:
	@$(CPPCHECK) $(CPPCHECK_FLAGS) $(SOURCES)

format:
	@$(FORMAT) -i $(SOURCES) $(FORMAT_HEADERS)