
BIN_DIR = bin/
OBJS_DIR = obj/

AS 		= mips64r5900el-ps2-elf-as
OBJCOPY = mips64r5900el-ps2-elf-objcopy

HOST_FILE = TonyHawkProSkater4-Lan-Host-NTSC
PARK_FILE = TonyHawkProSkater4-Lan-Park-NTSC

all: | host park

clean:
	rm -r -f $(OBJS_DIR) $(BIN_DIR)
	
park:
	@mkdir -p $(OBJS_DIR)
	@mkdir -p $(BIN_DIR)
	
	$(AS) $(PARK_FILE).s -o $(OBJS_DIR)$(PARK_FILE).elf
	$(OBJCOPY) -j .text $(OBJS_DIR)$(PARK_FILE).elf -O binary $(BIN_DIR)$(PARK_FILE).bin
	
host:
	@mkdir -p $(OBJS_DIR)
	@mkdir -p $(BIN_DIR)
	
	$(AS) $(HOST_FILE).s -o $(OBJS_DIR)$(HOST_FILE).elf
	$(OBJCOPY) -j .text $(OBJS_DIR)$(HOST_FILE).elf -O binary $(BIN_DIR)$(HOST_FILE).bin