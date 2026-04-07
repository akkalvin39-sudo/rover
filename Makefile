# Toolchain root for the MSP430 build.
ifdef TOOL_PATH
TOOLS_PATH ?= $(TOOL_PATH)
endif
TOOLS_PATH ?= C:/Users/User/dev/tools

# Check arguments
ifeq ($(HW),LAUNCHPAD)
    TARGET_HW = launchpad
else ifeq ($(HW),NSUMO)
    TARGET_HW = nsumo
else ifeq ($(MAKECMDGOALS),clean)
else ifeq ($(MAKECMDGOALS),cppcheck)
else ifeq ($(MAKECMDGOALS),format)
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

TI_CCS_DIR = $(TOOLS_DIR)/ccs2041/ccs
CCS_INCLUDE_GCC_DIR = $(TI_CCS_DIR)/ccs_base/msp430/include_gcc

# Detect .exe
ifneq ($(wildcard $(MSPGCC_BIN_DIR)/msp430-elf-gcc.exe),)
EXT = .exe
else
EXT =
endif

ifeq ($(EXT),)
CCS_INCLUDE_GCC_DIR = $(MSPGCC_ROOT_DIR)/include
endif

# ✅ INCLUDE (fixed order)
INCLUDE_DIRS = $(MSPGCC_INCLUDE_DIR) \
               $(CCS_INCLUDE_GCC_DIR) \
               ./ \
               ./src \
               ./external

LIB_DIRS = $(MSPGCC_INCLUDE_DIR) $(CCS_INCLUDE_GCC_DIR)

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
	src/common/trace.c \
	src/drivers/uart.c \
	external/printf/printf.c

ifndef TEST
SOURCES = src/main.c $(SOURCES_WITH_HEADERS)
else
SOURCES = src/test/test.c $(SOURCES_WITH_HEADERS)
$(shell rm -f $(OBJ_DIR)/src/test/test.o)
endif

HEADERS = $(shell find src -name "*.h") \
          $(shell find external -name "*.h")

FORMAT_HEADERS = $(shell find src -name "*.h")

OBJECT_NAMES = $(SOURCES:.c=.o)
OBJECTS = $(patsubst %,$(OBJ_DIR)/%,$(OBJECT_NAMES))

# Defines (clean)
HW_DEFINE = $(addprefix -D,$(HW))
TEST_DEFINE = $(addprefix -DTEST=,$(TEST))

DEFINES = \
	$(HW_DEFINE) \
	$(TEST_DEFINE) \
	-DPRINTF_INCLUDE_CONFIG_H

# CPPCHECK 
CPPCHECK_INCLUDES = ./ ./src ./external

IGNORE_FILES_FORMAT = \
	external/printf/printf.h \
	external/printf/printf.c

SOURCES_FORMAT_CPPCHECK = $(filter-out $(IGNORE_FILES_FORMAT),$(SOURCES))
HEADERS_FORMAT = $(filter-out $(IGNORE_FILES_FORMAT),$(HEADERS))

CPPCHECK_FLAGS = \
	--quiet --enable=all --error-exitcode=1 \
	--inline-suppr \
	--suppress=missingIncludeSystem \
	--suppress=unmatchedSuppression \
	--suppress=unusedFunction \
	--suppress=staticFunction \
	$(addprefix -I,$(CPPCHECK_INCLUDES))

# Flags
MCU = msp430g2553
WFLAGS = -Wall -Wextra -Werror -Wshadow

CFLAGS = -mmcu=$(MCU) \
	$(WFLAGS) \
	-fshort-enums \
	$(addprefix -I,$(INCLUDE_DIRS)) \
	$(DEFINES) \
	-Og -g

LDFLAGS = -mmcu=$(MCU) \
	$(DEFINES) \
	$(addprefix -L,$(LIB_DIRS))

# Build
$(TARGET): $(OBJECTS) $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@

$(TARGET).hex: $(TARGET)
	$(OBJCOPY) -O ihex $(TARGET) $(TARGET).hex

$(OBJ_DIR)/%.o: %.c $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

# Phonies
.PHONY: all clean flash cppcheck format

all: $(TARGET).hex

clean:
	$(RM) -rf $(BUILD_BASE)

flash: $(TARGET).hex
	$(DSLite) load -c MSP430G2553.ccxml $(TARGET).hex

cppcheck:
	@$(CPPCHECK) $(CPPCHECK_FLAGS) $(SOURCES_FORMAT_CPPCHECK)

format:
	@$(FORMAT) -i $(SOURCES_FORMAT_CPPCHECK) $(HEADERS_FORMAT)

size: $(TARGET)
	@$(SIZE) $(TARGET)

symbols: $(TARGET)
	@$(READELF) -s $(TARGET) | sort -n -k3