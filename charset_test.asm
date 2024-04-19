*=$0000
start:
    ldx #$00       ; Initialize X register to 0    
    ldy #$20       ; blank character


loop:
    txa
    sta $0400, x   ; Store the screen code in the screen RAM
    cpx #$FF       ; Compare with the last screen code (0xFF)
    beq end        ; If we've reached the last screen code, end the loop
    inx            ; Increment X register
    jmp loop       ; Jump back to the loop
    
end:
    brk            ; Return from subroutine, effectively ending the program