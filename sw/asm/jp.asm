; jp.asm

.word $8000
.org  $8000

        LDX #$00

POLL:   JSR READ_JP

        ; Check for wrong button press.
        PHA
        LDA $0000,X
        EOR #$FF
        STA $0700
        PLA
        PHA
        AND $0700
        BNE FAIL
        PLA

        CMP $0000,X
        BNE POLL

        JSR WAIT_ZERO

        INX
        LDA $0000,X
        BNE POLL

        ; Test passed.
        LDA #$01
        .byte $02  ; HLT

FAIL:   JSR WAIT_ZERO
        LDA #$00
        .byte $02  ; HLT



READ_JP:
        STX $0702
        STY $0703

NOMATCH:
        LDX #$64
        STX $0704

REREAD:
        ; Strobe $4016 to 1/0 to get ready to read input.
        LDY #$01
        STY $4016
        DEY
        STY $4016

        LDX $0200

        ; Read Controller X.  8 reads for 8 buttons, forming a mask.
        LDA #$00
        LDY #$08
BUTTON: 
        ASL
        ORA $4016,X
        DEY
        BNE BUTTON

        ; "Debounce"  Make sure we read the same state 100 times in a row before returning.
        CMP $0701
        STA $0701
        BNE NOMATCH

        LDX $0704
        DEX
        STX $0704
        BNE REREAD

        LDY $0703
        LDX $0702
        RTS


WAIT_ZERO:
        JSR READ_JP
        CMP #$00
        BNE WAIT_ZERO
        RTS

