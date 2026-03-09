# Directories
MSPGCC_ROOT_DIR = C:/Users/User/Downloads/msp430-gcc
MSPGCC_BIN_DIR = $(MSPGCC_ROOT_DIR)/bin
MSPGCC_INCLUDE_DIR = $(MSPGCC_ROOT_DIR)/include
CCS_INCLUDE_GCC_DIR = D:/ti/ccs2041/ccs/ccs_base/msp430/include_gcc

BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin

LIB_DIRS = $(MSPGCC_INCLUDE_DIR) $(CCS_INCLUDE_GCC_DIR)
INCLUDE_DIRS = $(MSPGCC_INCLUDE_DIR) \
			   $(CCS_INCLUDE_GCC_DIR) \
			   ./src \
			   ./external/ \
			   ./external/printf

# Toolchain
CC = $(MSPGCC_BIN_DIR)/msp430-elf-gcc.exe
OBJCOPY = $(MSPGCC_BIN_DIR)/msp430-elf-objcopy.exe
DSLite = D:/ti/ccs2041/ccs/ccs_base/DebugServer/bin/DSLite.exe
RM = rm
CPPCHECK = cppcheck
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
$(TARGET): $(OBJECTS)
	@echo $(OBJECTS)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) $^ -o $@

## ELF to HEX
$(TARGET).hex: $(TARGET)
	$(OBJCOPY) -O ihex $(TARGET) $(TARGET).hex

## Compiling
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $^

# Phonies
.PHONY: all clean flash cppcheck

all: $(TARGET).hex

clean:
	$(RM) -r $(BUILD_DIR)

flash: $(TARGET).hex
	@echo "Flashing $(TARGET).hex to MSP430G2553..."
	$(DSLite) load -c MSP430G2553.ccxml $(TARGET).hex

cppcheck:
	@$(CPPCHECK) $(CPPCHECK_FLAGS) $(SOURCES)