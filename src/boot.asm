; Create this as a raw binary output since processor has no concept of executable 
; files, file formats, etc.
; nasm -f bin boot.asm -o boot.bin
; -f bin: Format as binary file
; -o boot.bin: output file names as boot.bin
; To run QEMU to execute this, run it as 
; qemu-system-x86_64 -hda boot.bin
; -hda boot.bin: Treat boot.bin as hard disk

; Physical RAM Layout:
; 0x00-0x400: Interrupt vector table (256 entries of 4 bytes)
; 0x7C00: Our bootloader

; Tell NASM that we expect to be loaded at offset 0x7C00 in RAM. Every label
; should be offset by 0x7C00 now.
org 07C00h

; We start in real mode which is 16-bit addressing only
bits 16

; Here is where the BIOS parameter block information goes, that is part
; of each sector. Most BIOS expect this data to be in the first sector of the
; storage medium.
bpb_start:
    ; Jump over the BIOS parameter block information
    jmp short set_csip
    nop
    ; Fill the rest of the BIOS parameter block with 0s for now
    times 024h - ($ - $$) db 0

; Make sure we jump to the start label. We explicitly set the code segment here
; This jmp ptr16:16 call will cause CS and IP to be updated
set_csip:
    jmp 0h:start

; Entry point
start:
    ; Disable interrupts by clearing interrupt flag to change segment registers.
    ; We don't want to be interrupted during this, or our bootloader will not
    ; be setup correctly
    cli
    ; Setup the segment registers. We have to use a register to set their values
    ; We do this because we don't want to rely on the BIOS to set them up for us
    ; and potentially get the wrong address of labels. It could set our segment
    ; registers to 0, and origin to 0x7C00, or vice versa since some BIOSes are different.
    mov ax, 0
    mov ds, ax     ; Data segment
    mov es, ax     ; Extra segment
    mov ss, ax     ; Stack segment
    mov sp, 07C00h ; Stack pointer currently will point to data in RAM before this bootloader

    ; Use cpuid to check if our processor supports long mode. Will assume that
    ; NOTE: Assuming cpuid exists on this PC. This could be a potential bug.
    mov eax, 80000000h ; Check if we have any extended fxns
    cpuid
    cmp eax, 80000000h ; If no extended fxns (eax <= 0x80000000), no long mode
    jbe long_mode_not_found
    mov eax, 80000001h ; Use extended fxn 80000001h to verify long mode
    cpuid
    bt edx, 29 ; Copy long mode bit into carry flag and check if set
    jnc long_mode_not_found
    ; We should have long mode verified at this point
    mov si, long_mode_found_str
    call print
    jmp done

long_mode_not_found:
    mov si, long_mode_not_found_str
    call print
    jmp done

    ; Enables interrupts again by setting the interrupt flags
    ; TODO: Remember to tell BIOS what mode we plan to boot in with int 15h
done:
    sti

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
; @param dl: the character to print.
;
; Uses BIOS Video subroutine Int 10h teletype output mode
; AX:
;    AH: 0Eh (teletype output) Displays character in AL to screen, advances cursor,
;            and scrolls screen if needed
;    AL: character to write
; BX:
;   BH: Page number
;   BL: foreground color (graphics mode)
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

; Global descriptor table. It contains its size (4 bytes) and its location
; (4 bytes). This is only for a 32-bit memory model. We will use the 
; paging memory model so we can leave
; these as default. 
global_descriptor_table:
; Here is the global descriptor table, which tells the processor about memory
; segments. Used for 32-bit mode, but we will not really use this
gdt_prot_code_segment:
    dw 0FFFFh ; Limit or highest accessable address by this segment (Bits 0-15)
    dw 0      ; Base address or start of the segment  
    db 0      ; 

long_mode_found_str db "Long mode exists!", 0Dh, 0Ah, 0
long_mode_not_found_str db "Long mode does not exist :(", 0Dh, 0Ah, 0

; Pads the rest of the sector up to the 510th byte with 0s
; $: current address of program after adding everything above.
; $$: Address for start of current segment. 0 in this case
; Pads 510 - (%eip - 0) zero bytes for rest of sector
times 1FEh - ($ - $$) db 0

; Setup the boot signature at end of this 512-byte sector so the BIOS detects
; we are a bootloader. Word at 0x511 should be 0x55AA (this CPU is little endian, 
; so should be 0xAA55)
dw 0AA55h