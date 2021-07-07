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

; Here is where the BIOS parameter block information goes, that is the first 
; part of this sector. Most BIOS expect this data to be in the first sector of the
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
    iret 

nmi:
    iret

invalid_opcode:
    iret

double_fault:
    iret

general_protection_fault:
    iret

; Entry point
start:
    ; Disable interrupts by clearing interrupt flag to change segment registers.
    ; Only maskable interrupts will be ignored during this, or our bootloader 
    ; will not be setup correctly
    cli
    ; Setup the interrupt descriptor table which is located at absolute address 0x0.
    ; Each entry is 4 bytes where bits 0-15 are the offset, and bits 16-31 are the segment.
    ; We have to setup the DS segment to point to zero so we do 0 * 16 + offset == IDT location
    mov ax, 0
    mov ds, ax     
    mov word [0], div_by_zero                 ; Divide by zero
    mov word [2], 0                           ; Divide by zero
    mov dword [8], nmi                        ; Nonmaskable
    mov dword [1Ah], invalid_opcode           ; Invalid opcode
    mov dword [24h], double_fault             ; Double fault
    mov dword [3Ah], general_protection_fault ; General protection fault

    ; Begin the process to switch to 32-bit protected mode by read the data 
    ; from the GDT descriptor we have created so the CPU knows about the GDT.
    ; Also, tell the CPU about the IDT using the IDT descriptor
    ; Use explicit ds segment to avoid NASM cs since it is a label
    lgdt [ds:gdt32_descriptor]
    lidt [ds:idt32_descriptor]

    ; We can now set the CR0 control register PE bit which will enable (not turn on)
    ; protected mode. We are still in 16-bit protected mode until we perform the
    ; a far jump which sets the CS register to recognize and run 32-bit code 
    ; due to the code segment descriptor
    mov cr0, eax
    or eax, 1
    mov cr0, eax

    ; Segment registers are now segment selectors, which are indexes to the GDT.
    ; The processor multiplies it by the size of a segment descriptor (8), then
    ; adds that as a base address. protected Jump to the 32-bit code to 
    ; clear the instruction queue of 16-bit code. I can simply use the byte offset 
    ; from the beginning to the code in bytes from the base address of the GDT, 
    ; then shift to get place the bits in the table index position.
    ; Segment selector looks like
    ; Bits 0-1: Requested Privledge level
    ; Bit 2: Table Indicator (0 for GDT, 1 for LDT)
    ; Bits 3-15: Table index
    jmp (((gdt_cs_descriptor - global_descriptor_table) / 8) << 3):startprot32

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
; NOTE: We can't call this function as soon as we enter BIOS mode.
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

; Here starts the 32-bit code for when we successfully switched to 32-bit
; protected mode.
[bits 32]
startprot32:
    ; The processor needs to have a stack to save the state before jumping to
    ; an interrupt. We will set the all the rest of the segment selectors to
    ; point to the entire 4GB address space. 
    mov ax, (((gdt_ds_descriptor - global_descriptor_table) / 8) << 3)
    mov es, ax
    mov ds, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 000200000h
    mov ebp, esp

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

    ; Here we will begin to attempt to turn on long mode.
    ; TODO: Remember to tell BIOS what mode we plan to boot in with int 15h
    jmp $

; Here we should jump to the kernel here and avoid attempt to setup long mode
; TODO: Remember to renable maskable interrupts once we get the IDT setup 
; correctly 
long_mode_not_available:
    jmp $

; We need to make sure the GDT is on a quadword boundary.
align 8

; Here is the global descriptor table (GDT), where we contain information about the
; memory segments for use in 32-bit protected mode. These can be selected using the
; segment selectors, which are the segment registers CS, DS and so on. The AMD64
; manual says this should be aligned on a quadword boundary.
; segment registers are now known as segment selectors, which are indexes into
; either this or the local descriptor table (LDT). Which one is specified in the bitfield
; in the instruction bitfield
;
; Each entry is 8 bytes, and describes information about it such as permissions,
; usage information, and type.
global_descriptor_table:
; First entry should be a null segment descriptor. In protected mode this is
; used to raise a general protection fault when null selector is used. 
    dq 0 ; Null selector should have all zeros for its 8-bytes

; Describes the code segment for this bootloader code that the CS register 
; should reference. We will need a seperate entry for the 32/64 bit code descriptor
; for when we switch to long mode.
;  
gdt_cs_descriptor:
    dw 0FFFFh ; Limit or highest accessable linear address by this segment (Bits 0-15)
    dw 0      ; Bits 15-0 of this segment's linear base address.  
    db 0      ; Bits 23-16 of this segment's linear base address. This code won't need that
    db 09Ah   ; Bitfield describing this segment
              ; P DPL S T C R AX
              ; 1 0 0 1 1 0 1 0
              ; P: Present, as in this segment isz loaded in memory. 1 since it is present
              ; DPL: descriptor privilege level: 0 so highest privileged
              ; S: Descriptor type. 1 for user
              ; T: 1 for code type. Simply an addition for discerning from system descriptors
              ; C: 0 for Non conforming. Can't be accessed without having same PL as DPL
              ; R: Readable. Leaving it being readable just to avoid problems.
              ; A: Accessed. Processor sets when descriptor is copied to CS reg. Software should leave at 0
    db 0DFh   ; Bitfield with more information about segment
              ; G D R A SegLim
              ; 1 1 0 1 1 1 1 1
              ; SegLim: Bits 19-16 of 20-bit segment limit
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
    dw 0FFFFh ; Limit or highest accessable linear address by this segment (Bits 0-15)
    dw 0      ; Bits 15-0 of this segment's linear base address (location of byte 0 of this segment).
    db 0      ; Bits 23-16 of this segment's linear base address 
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
              ; 1 1 0 1 1 1 1 1
              ; SegLim: Bits 19-16 of 20-bit segment limit
              ; A: Available to software. We'll keep it to 1 for now
              ; R: Reserved. SHould be cleared adhereing to AMD SystemProg manual
              ; D: Default operand size. Needs to be 1 for 32-bit protected mode
              ; G: Granularity bit. Scales the limit by multiplying by 4096.
              ;    0xFFFFF seg limit * 4096 == 4GB (max 32-bit addr)
    db 0      ; Bits 31-24 of the base address of this segment
global_descriptor_table_end:

; This contains information about the GDT such as its size and its location
; This will be loaded into the GDTR register and is for legacy mode. Its required
; to load 32-bit protected mode. 
gdt32_descriptor:
    ; Size or limit of GDT in bytes. Used by adding to the base address and checking if requested address is within
    dw global_descriptor_table_end - global_descriptor_table - 1
    ; Base address of the GDT
    dd global_descriptor_table

; This contains information about the interrupt descriptor. This should handle
; all 256 entries for the IDT later.
idt32_descriptor:
    ; Size or limit of IDT. Used same as GDT limit. For now will set it to the
    ; maximum, but I still need to make sure to actually define all 256 interrupts.
    dw 100h
    ; Base address of IDT which should be absolute address 0 in RAM.
    ; This IDT will be used for all submodes in legacy mode 
    dd 0

; Pads the rest of the sector up to the 510th byte with 0s
; $: current address of program after adding everything above.
; $$: Address for start of current segment. 0 in this case
; Pads 510 - (%eip - 0) zero bytes for rest of sector
times 1FEh - ($ - $$) db 0

; Setup the boot signature at end of this 512-byte sector so the BIOS detects
; we are a bootloader. Word at 0x511 should be 0x55AA (this CPU is little endian, 
; so should be 0xAA55)
dw 0AA55h