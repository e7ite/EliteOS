; Create this as a raw binary output since processor has no concept of executable 
; files, file formats, etc.
; nasm -f bin boot.asm -o boot.bin
; -f bin: Format as binary file
; -o boot.bin: output file names as boot.bin
; To run QEMU to execute this, run it as 
; qemu-system-x86_64 -hda boot.bin
; -hda boot.bin: Treat boot.bin as hard disk

; BIOS Video subroutine Int 10
; Displays character in AL to screen, advances cursor, and scrolls screen if needed
; AX:
;    AH: 0Eh (teletype output)
;    AL: character to write
; BX:
;   BH: Page number
;   BL: foreground color (graphics mode)


; Tell NASM that we expect to be loaded at offset 0 in RAM. In actuality, we 
; will be loaded in 0x7C00 in RAM by the BIOS. But every data access will be
; offset by 0x7C0 * 0x10 due to the segmentation since we setup the registers up
; We don't want NASM to add another base offset
org 0

; We start in real mode which is 16-bit addressing only
bits 16

; Here is where the BIOS parameter block information goes, that is part
; of each sector. Most BIOS expect this data to be in the first sector of the
; storage medium.
bpb_start:
    ; Jump over the BIOS parameter block information
    jmp short _start
    nop
    ; Fill the rest of the BIOS parameter block with 0s for now
    times 024h - ($ - $$) db 0

; Make sure we jump to the start label. We explicitly set the code segment here
; This jmp ptr16:16 call will cause CS and IP to be updated
_start:
    jmp 7C0h:start

; Entry point
start:
    ; Disable interrupts by clearing interrupt flag to change segment registers.
    ; We don't want to be interrupted during this, or our bootloader will not
    ; be setup correctly
    cli
    ; Setup the segment registers. We have to use a register to set their values
    ; We do this because we don't want to rely on the BIOS to set them up for us
    ; and potentially get the wrong address of labels. It could set our segment
    ; registers to 0, and origin to 0x7C00, or vice versa since all computers
    ; are different.
    mov ax, 7C0h
    mov ds, ax     ; Data segment
    mov es, ax     ; Extra segment
    mov ax, 0h 
    mov ss, ax     ; Stack segment
    mov sp, 07C00h ; Stack pointer, will grow downwards
    ; Enables interrupts again by setting the interrupt flags
    sti 

    ; Load the address of greeting string to si register
    mov si, greeting

    ; Call our subroutine to print the string
    call print

    mov si, sup
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
greeting db "Hello world!", 0Dh, 0Ah, 0 0
sup db "Hey man prod man  how u doin tonight!", 0Dh, 0Ah, 0

; Pads the rest of the sector up to the 510th byte with 0s
; $: current address of program after adding everything above.
; $$: Address for start of current segment. 0 in this case
; Pads 510 - (%eip - 0) zero bytes for rest of sector
times 1FEh - ($ - $$) db 0

; Setup the boot signature at end of this 512-byte sector so the BIOS detects
; we are a bootloader. Word at 0x511 should be 0x55AA (this CPU is little endian, 
; so should be 0xAA55)
dw 0AA55h