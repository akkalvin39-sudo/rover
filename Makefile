# Directories
TOOLS_DIR = ${TOOLS_PATH}
MSPGCC_ROOT_DIR = $(TOOLS_DIR)/msp430-gcc
MSPGCC_BIN_DIR = $(MSPGCC_ROOT_DIR)/bin
MSPGCC_INCLUDE_DIR = $(MSPGCC_ROOT_DIR)/include

BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin

TI_CCS_DIR = $(TOOLS_DIR)/ccs2041/ccs
CCS_INCLUDE_GCC_DIR = $(TI_CCS_DIR)/ccs_base/msp430/include_gcc

ifeq ($(OS),Windows_NT)
    EXT = .exe
else
    EXT = 
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

# Files
TARGET = $(BIN_DIR)/nsumo

DRIVERS_SRC = $(addprefix src/drivers/,\
				uart.c \
				i2c.c \
				)
APP_SRC = $(addprefix src/app/,\
			drive.c \
	  	  	enemy.c \
			)
TEST_SRC = $(addprefix src/test/,\
		     test.c \
			 )
SOURCES = src/main.c \
		  $(DRIVERS_SRC) \
		  $(APP_SRC) \
		  $(TEST_SRC)

HEADERS = $(shell find src -name "*.h") \
		  $(shell find external -name "*.h")

OBJECT_NAMES = $(SOURCES:.c=.o)
OBJECTS = $(patsubst %,$(OBJ_DIR)/%,$(OBJECT_NAMES))

# Static Analysis
CPPCHECK_INCLUDES = $(MSPGCC_INCLUDE_DIR) $(CCS_INCLUDE_GCC_DIR) ./src ./external/ ./external/printf
CPPCHECK_IGNORE = external/printf
CPPCHECK_FLAGS = \
	--quiet --enable=all --error-exitcode=1 \
	--inline-suppr \
	--suppress=missingIncludeSystem \
	--suppress=unmatchedSuppression \
	--suppress=unusedFunction \
	--suppress=staticFunction \
	--suppress=checkersReport \
	$(addprefix -I,$(CPPCHECK_INCLUDES)) \
	$(addprefix -i,$(CPPCHECK_IGNORE))

# Flags
MCU = msp430g2553
WFLAGS = -Wall -Wextra -Werror -Wshadow
CFLAGS = -mmcu=$(MCU) $(WFLAGS) $(addprefix -I,$(INCLUDE_DIRS)) -Og -g
LDFLAGS = -mmcu=$(MCU) $(addprefix -L,$(LIB_DIRS))

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
	$(RM) -r $(BUILD_DIR)

flash: $(TARGET).hex
	@echo "Flashing $(TARGET).hex to MSP430G2553..."
	$(DSLite) load -c MSP430G2553.ccxml $(TARGET).hex

cppcheck:
	@$(CPPCHECK) $(CPPCHECK_FLAGS) $(SOURCES)

format:
	@$(FORMAT) -i $(SOURCES) $(HEADERS)