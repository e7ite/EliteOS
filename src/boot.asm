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
; This jmp ptr16:16 call will cause CS and IP to be updated. Also pad with
; some no-ops to prevent weird instruction output.
set_csip:
    jmp 0h:start
    nop
    nop
    nop
    nop

div_by_zero:
    mov si, div_by_zero_str
    call print
    hlt

nmi:
    mov si, nmi_str
    call print
    hlt

invalid_opcode:
    mov si, invalid_opcode_str
    call print
    hlt

double_fault:
    mov si, double_fault_str
    call print
    hlt

general_protection_fault:
    mov si, general_protection_fault_str
    call print
    hlt

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

    ; Setup the interrupt vector table
    mov word [0], div_by_zero ; Divide by zero offset
    mov word [2], 0           ; 
    mov word [8], nmi           ; Nonmaskable
    mov word [0Ah], 0
    mov word [1Ah], invalid_opcode ; Invalid Opcode
    mov word [1Ch], 0
    mov word [24h], double_fault ; Double fault
    mov word [26h], 0
    mov word [3Ah], general_protection_fault ; General protection fault
    mov word [3Ch], 0

    mov si, about_test_int
    call print

    ; Use cpuid to check if our processor supports long mode.
    ; NOTE: Assuming cpuid exists on this PC. This could be a potential bug.
    mov eax, 80000000h ; Check if we have any extended fxns
    cpuid
    cmp eax, 80000000h ; If no extended fxns (eax <= 0x80000000), no long mode
    jbe long_mode_not_available
    mov eax, 80000001h ; Use extended fxn 80000001h to verify long mode
    cpuid
    bt edx, 29         ; Copy long mode bit into carry flag and check if set
    jnc long_mode_not_available
    mov si, long_mode_available_str
    call print

    ; We should have long mode verified at this point, so read the data for
    ; the GDT from the GDT descriptor we have created. Use explicit ds segment
    ; to avoid NASM cs since it is a label
    lgdt [ds:gdt_32_descriptor]

    ; We can now set the CR0 control register PE bit. AMD64 manual sets these 
    ; protected-mode enable bit (bit 0) and the monitor coprocessor (bit 1) with this.
    ; PE bit is obvious why. Setting MP bit causes the WAIT/FWAIT instructions to work
    ; properly.
    mov eax, 000000011h
    mov cr0, eax

    ; Segment registers are now segment selectors, which are indexes to the GDT.
    ; The processor multiplies it by the size of a segment descriptor (8), then
    ; adds that as a base address.
    ; Segment selector looks like
    ; Bits 0-1: Requested Privledge level
    ; Bit 2: Table Indicator (0 for GDT, 1 for LDT)
    ; Bits 3-15: Table index
    jmp (((gdt_cs_descriptor - global_descriptor_table) / 8) << 3):startprot32

long_mode_not_available:
    mov si, long_mode_not_available_str
    call print
    jmp $

    ; Enables interrupts again by setting the interrupt flags
    ; TODO: Remember to tell BIOS what mode we plan to boot in with int 15h
done:
    sti

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

; We need to make sure the GDT is on a quadword boundary.
align 8

; Here is the global descriptor table (GDT), where we contain information about the
; memory segments in that can be selected using the segment registers. Stored
; here as the AMD64 manual says this should be aligned on a quadword boundary.
; segment registers are now known as segment selectors, which are indexes into
; either this or the local descriptor table (LDT), which is identified in the 
; value stored in the segement selector.
;
; Each entry is 8 bytes, and describes information about it such as permissions,
; usage information, and type.
global_descriptor_table:
; First entry should be a null segment descriptor. In protected mode this is
; used to raise a general protection fault when null selector is used. 
    dq 0 ; Null selector should have all zeros for its 8-bytes

; Describes the code segment for this bootloader code that the CS register 
; should reference when jumping to here.
gdt_cs_descriptor:
    dw 0FFFFh ; Limit or highest accessable virtual address by this segment (Bits 0-15)
    dw 0      ; Bits 15-0 of this segment's virtual base address.  
    db 0      ; Bits 23-16 of this segment's virtual base address. This code won't need that
    db 09Ah   ; Bitfield describing this segment
              ; P DPL S T C R A
              ; 1 0 0 1 1 0 1 0
              ; P: Present, as in this segment is loaded in memory. 1 since it is present
              ; DPL: descriptor privilege level: 0 so highest privileged
              ; S: Descriptor type. 1 for user
              ; T: 1 for code type. Simply an addition for discerning from system descriptors
              ; C: 0 for Non conforming. Can't be accessed without having same PL as DPL
              ; R: Readable. Leaving it being readable just to avoid problems.
              ; A: Accessed. Processor sets when descriptor is copied to CS reg. Software should leave at 0
    db 0DFh   ; Bitfield with more information about segment
              ; G D R A SegLim
              ; 1 1 0 1 1 1 1
              ; SegLim: Bits 16-19 of 20-bit segment limit
              ; A: Available to software. We'll keep it to 1 for now
              ; R: Reserved. SHould be cleared adhereing to AMD SystemProg manual
              ; D: Default operand size. Needs to be 1 for 32-bit protected mode
              ; G: Granularity bit. Scales the limit by multiplying by 4096.
              ;    0xFFFFF seg limit * 4096 == 4GB (max 32-bit addr)
    db 0      ; Bits 31-24 of the base address of this segment

; Data segment that the DS, SS, ES, FS, GS registers will reference. Permissions
; will basically be the same as the code segment for small differences such as
; interpretation of certain bits for code/data segment descriptors. Intel and 
; AMD manuals both say this should be able to be used as a stack, so we got to
; make sure the SP points to the end, and everything else to the start
gdt_ds_descriptor:
    dw 0FFFFh ; Limit or highest accessable virtual address by this segment (Bits 0-15)
    dw 0      ; Bits 15-0 of this segment's virtual base address.
    db 0      ; Bits 23-16 of this segment's virtual base address 
    db 92h    ; Bitfield describing this segment
              ; P DPL S T E W A
              ; 1 0 0 1 0 0 1 0
              ; P: Present, as in this segment is loaded in memory. 1 since it is present
              ; DPL: descriptor privilege level: 0 so highest privileged
              ; S: Descriptor type. 1 for user
              ; T: 0 for data type. Simply an addition for discerning from system descriptors
              ; E: Expand-down: represents if the segment grows downward such as a stack.
              ;    this will make the limit be lower-segment boundary and base is upper-segment boundary.
              ;    As you may have guessed this is good for stacks. we'll ignore for now.
              ; R: Writable. Leaving it be writable just to avoid problems. Conforming bit.
              ;    will prevent underprivileged programs from writing here.
              ; A: Accessed. Processor sets when descriptor is copied to CS reg. Software should leave at 0
    db 0DFh   ; Bitfield with more information about segment
              ; G D R A SegLim
              ; 1 1 0 1 1 1 1
              ; SegLim: Bits 16-19 of 20-bit segment limit
              ; A: Available to software. We'll keep it to 1 for now
              ; R: Reserved. SHould be cleared adhereing to AMD SystemProg manual
              ; D: Default operand size. Needs to be 1 for 32-bit protected mode
              ; G: Granularity bit. Scales the limit by multiplying by 4096.
              ;    0xFFFFF seg limit * 4096 == 4GB (max 32-bit addr)
    db 0      ; Bits 31-24 of the base address of this segment
global_descriptor_table_end:

; This contains information about the GDT such as its size and its location
; This will to be loaded into the GDTR register respective to 32-bit protected mode. 
gdt_32_descriptor:
    ; Size or limit of GDT in bytes. Used by adding to the base address and checking if requested address is within
    dw global_descriptor_table_end - global_descriptor_table - 1
    ; Base address of the GDT
    dd global_descriptor_table

div_by_zero_str db "DivbyZero!", 0Dh, 0Ah, 0
nmi_str db "NMI!", 0Dh, 0Ah, 0
about_test_int db "About to test !", 0Dh, 0Ah, 0
invalid_opcode_str db "Invalid opcode!", 0Dh, 0Ah, 0
double_fault_str db "Double fault!", 0Dh, 0Ah, 0
general_protection_fault_str db "General protection fault!", 0Dh, 0Ah, 0
about_to_switch_str db "About to turn on PE bit!", 0Dh, 0Ah, 0
long_mode_available_str db "Long mode exists!", 0Dh, 0Ah, 0
long_mode_not_available_str db "Long mode does not exist :(", 0Dh, 0Ah, 0

; Here starts the 32-bit code for when we successfully switched to 
; protected mode.
bits 32
startprot32:
    jmp $


; Pads the rest of the sector up to the 510th byte with 0s
; $: current address of program after adding everything above.
; $$: Address for start of current segment. 0 in this case
; Pads 510 - (%eip - 0) zero bytes for rest of sector
times 1FEh - ($ - $$) db 0

; Setup the boot signature at end of this 512-byte sector so the BIOS detects
; we are a bootloader. Word at 0x511 should be 0x55AA (this CPU is little endian, 
; so should be 0xAA55)
dw 0AA55h