start:
    ldx #$00     
loop:
    txa
    sta $0400, x  
    cpx #$FF
    beq end 
    inx     
    jmp loop
end:          
    jmp end  ; this is a hack to keep the window open indefinitely
    