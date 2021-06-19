; Create this as a raw binary output since processor has no concept of executable 
; files, file formats, etc.
; nasm -f bin boot.asm -o boot.bin
; -f bin: Format as binary file
; -o boot.bin: output file names as boot.bin
; To run QEMU to execute this, run it as 
; qemu-system-x86_64 -hda boot.bin
; -hda boot.bin: Treat boot.bin as hard disk

; BIOS loads us into address 0x7C00
org 0x7C00

; We start in real mode which is 16bit addressing only
bits 16

; BIOS Video subroutine Int 10
; Displays character in AL to screen, advances cursor, and scrolls screen if needed
; AX:
;    AH: 0Eh (teletype output)
;    AL: character to write
; BX:
;   BH: Page number
;   BL: foreground color (graphics mode)

; Entry point
start:
    ; Load the address of greeting string to si register
    mov si, greeting

    ; Call our subroutine to print the string
    call print

    ; Jump to itself so we don't try to execute anything afterwards
    jmp $

; print: Prints a nullterminated string 
; @param si: the string to print
print:
    mov bx, 0
    ; Iterate while until we hit at a null terminator
    ; C:
    ; for (uint8_t i = 0; si[i] != '\0'; i++)
    ;   printChar(si[i])
repeat:
    ; Get the current character and check if it is the 
    mov dl, byte [si + bx]
    cmp dl, 0
    je end
    ; Call the printChar function and preserve the index
    push bx
    call printChar
    pop bx
    ; Increment the counter and repeat code above
    inc bx
    jmp repeat
end:
    ret

; print: Prints a single character using the BIOS video subroutine
; @param dl: the character to print
printChar:
    ; Set to teletype output mode
    mov ah, 0Eh
    ; Set the character to print in 
    mov al, dl
    ; We can ignore page number and color
    mov bx, 0
    ; Calling BIOS video routine, which will display character in al to teletype output
    int 10h
    ret

; Greeting null-terminated string. 
greeting db "Hello world!", 0

; Pads the rest of the sector up to the 510th byte with 0s
; $: current value for instruction pointer
; $$: Address for start of current segment. 0 in this case
; Pads 510 - (%eip - 0) zero bytes for rest of sector
times 510 - ($ - $$) db 0

; Setup the boot signature at end of this 512-byte sector so the BIOS detects
; we are a bootloader. Word at 0x511 should be 0x55AA (this CPU is little endian, 
; so should be 0xAA55)
dw 0AA55h