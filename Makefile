# Check arguments
ifeq ($(HW),LAUNCHPAD)
TARGET_HW=launchpad
else ifeq ($(HW),NSUMO)
TARGET_HW=nsumo
else ifeq ($(MAKECMDGOALS),clean)
else ifeq ($(MAKECMDGOALS),cppcheck)
else ifeq ($(MAKECMDGOALS),format)
else
$(error "Must pass HW=LAUNCHPAD or HW=NSUMO")
endif
TARGET_NAME=$(TARGET_HW)

ifneq ($(TEST),)
ifeq ($(findstring test_,$(TEST)),)
$(error "TEST=$(TEST) is invalid (test function must start with test_)")
else
TARGET_NAME=$(TEST)
endif
endif

# =========================
# Directories (FIXED for CI)
# =========================
ifeq ($(TOOLS_PATH),)
    TOOLS_PATH = C:/Users/User/dev/tools
endif

BUILD_BASE = build
BUILD_DIR = $(BUILD_BASE)
OBJ_DIR = $(BUILD_DIR)/obj

MSPGCC_ROOT_DIR = $(TOOLS_PATH)/msp430-gcc
MSPGCC_BIN_DIR = $(MSPGCC_ROOT_DIR)/bin
MSPGCC_INCLUDE_DIR = $(MSPGCC_ROOT_DIR)/include

# CCS path (CHANGE if different)
TI_CCS_DIR = C:/Users/User/dev/tools/ccs2041/ccs
DEBUG_BIN_DIR = $(TI_CCS_DIR)/ccs_base/DebugServer/bin

# =========================
# Detect .exe (FIXED)
# =========================
ifneq ($(wildcard $(MSPGCC_BIN_DIR)/msp430-elf-gcc.exe),)
EXT = .exe
else
EXT =
endif

# =========================
# Includes (FIXED)
# =========================
LIB_DIRS = $(MSPGCC_INCLUDE_DIR)
INCLUDE_DIRS = $(MSPGCC_INCLUDE_DIR) \
               $(TI_CCS_DIR)/ccs_base/msp430/include_gcc \
               $(CURDIR) \
               $(CURDIR)/src \
               $(CURDIR)/external

# =========================
# Toolchain
# =========================
CC = $(MSPGCC_BIN_DIR)/msp430-elf-gcc$(EXT)
OBJCOPY = $(MSPGCC_BIN_DIR)/msp430-elf-objcopy$(EXT)
RM = rm
DSLite = $(DEBUG_BIN_DIR)/DSLite$(EXT)
CPPCHECK = cppcheck
FORMAT = clang-format
SIZE = $(MSPGCC_BIN_DIR)/msp430-elf-size
READELF = $(MSPGCC_BIN_DIR)/msp430-elf-readelf
ADDR2LINE = $(MSPGCC_BIN_DIR)/msp430-elf-addr2line

# =========================
# Files
# =========================
TARGET = $(BUILD_DIR)/bin/$(TARGET_HW)/$(TARGET_NAME)

SOURCES_WITH_HEADERS = \
		src/common/assert_handler.c \
		src/common/ring_buffer.c \
		src/common/trace.c \
		src/drivers/mcu_init.c \
		src/drivers/io.c \
		src/drivers/led.c \
		src/drivers/uart.c \
		src/drivers/ir_remote.c \
		src/drivers/pwm.c \
		src/drivers/tb6612fng.c \
		src/drivers/adc.c \
		src/drivers/qre1113.c \
		src/app/drive.c \
		src/app/enemy.c \
		src/app/line.c \
		external/printf/printf.c

ifndef TEST
SOURCES = \
		src/main.c \
		$(SOURCES_WITH_HEADERS)
else
SOURCES = \
		src/test/test.c \
		$(SOURCES_WITH_HEADERS)
$(shell rm -f $(BUILD_DIR)/obj/src/test/test.o)
endif

HEADERS = \
		$(SOURCES_WITH_HEADERS:.c=.h) \
		src/common/defines.h

OBJECT_NAMES = $(SOURCES:.c=.o)
OBJECTS = $(patsubst %,$(OBJ_DIR)/%,$(OBJECT_NAMES))

# =========================
# Defines
# =========================
HW_DEFINE = $(addprefix -D,$(HW))
TEST_DEFINE = $(addprefix -DTEST=,$(TEST))

DEFINES = \
	$(HW_DEFINE) \
	$(TEST_DEFINE) \
	-DPRINTF_INCLUDE_CONFIG_H

# =========================
# Static Analysis
# =========================
CPPCHECK_INCLUDES = ./src ./

IGNORE_FILES_FORMAT_CPPCHECK = \
	external/printf/printf.h \
	external/printf/printf.c

SOURCES_FORMAT_CPPCHECK = $(filter-out $(IGNORE_FILES_FORMAT_CPPCHECK),$(SOURCES))
HEADERS_FORMAT = $(filter-out $(IGNORE_FILES_FORMAT_CPPCHECK),$(HEADERS))

CPPCHECK_FLAGS = \
	--quiet --enable=all --error-exitcode=1 \
	--inline-suppr \
	--suppress=missingIncludeSystem \
	--suppress=unmatchedSuppression \
	--suppress=unusedFunction \
	--suppress=staticFunction \
	--suppress=normalCheckLevelMaxBranches \
	--suppress=checkersReport \
	$(addprefix -I,$(CPPCHECK_INCLUDES))

# =========================
# Flags
# =========================
MCU = msp430g2553
WFLAGS = -Wall -Wextra -Werror -Wshadow

CFLAGS = -mmcu=$(MCU) $(WFLAGS) -fshort-enums \
         $(addprefix -I,$(INCLUDE_DIRS)) \
         $(DEFINES) -Og -g

LDFLAGS = -mmcu=$(MCU) $(DEFINES) \
          $(addprefix -L,$(LIB_DIRS))

# =========================
# Build
# =========================

## Linking
$(TARGET): $(OBJECTS) $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) $^ -o $@

## Generate HEX (FIXED)
$(TARGET).hex: $(TARGET)
	$(OBJCOPY) -O ihex $(TARGET) $(TARGET).hex

## Compiling (FIXED)
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

# =========================
# Phonies
# =========================
.PHONY: all clean flash cppcheck format

all: $(TARGET).hex

clean:
	@$(RM) -rf $(BUILD_BASE)

## Flash (FIXED)
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

addr2line: $(TARGET)
	@$(ADDR2LINE) -e $(TARGET) $(ADDR)