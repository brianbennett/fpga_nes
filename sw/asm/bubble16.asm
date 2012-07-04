; bubble16.asm
;
; Bubble sort of an array of 16-bit integers.  Code taken from:
;
;     http://www.6502.org/source/sorting/bubble16.htm
;

.word $8000
.org  $8000

  ldx #$FF
  txs

;THIS SUBROUTINE ARRANGES THE 16-BIT ELEMENTS OF A LIST IN
;ASCENDING ORDER.  THE STARTING ADDRESS OF THE LIST IS IN LOCATIONS
;$30 AND $31.  THE LENGTH OF THE LIST IS IN THE FIRST BYTE OF THE LIST.
;LOCATION $32 IS USED TO HOLD AN EXCHANGE FLAG.

SORT16:  LDY #$00     ;TURN EXCHANGE FLAG OFF (= 0)
         STY $32
         LDA ($30),Y  ;FETCH ELEMENT COUNT
         TAY          ;  AND USE IT TO INDEX LAST ELEMENT
NXTEL:   LDA ($30),Y  ;FETCH MSBY
         PHA          ;  AND PUSH IT ONTO STACK
         DEY
         LDA ($30),Y  ;FETCH LSBY
         SEC
         DEY
         DEY
         SBC ($30),Y  ; AND SUBTRACT LSBY OF PRECEDING ELEMENT
         PLA
         INY
         SBC ($30),Y  ; AND SUBTRACT MSBY OF PRECEDING ELEMENT
         BCC SWAP     ;ARE THESE ELEMENTS OUT OF ORDER?
         CPY #$02     ;NO. LOOP UNTIL ALL ELEMENTS COMPARED
         BNE NXTEL
         BIT $32      ;EXCHANGE FLAG STILL OFF?
         BMI SORT16   ;NO. GO THROUGH LIST AGAIN
         .byte $02    ; HLT

;THIS ROUTINE BELOW EXCHANGES TWO 16-BIT ELEMENTS IN MEMORY

SWAP:    LDA ($30),Y  ;SAVE MSBY1 ON STACK
         PHA
         DEY
         LDA ($30),Y  ;SAVE LSBY1 ON STACK
         PHA
         INY
         INY
         INY
         LDA ($30),Y  ;SAVE MSBY2 ON STACK
         PHA
         DEY
         LDA ($30),Y  ;LOAD LSBY2 INTO ACCUMULATOR
         DEY
         DEY
         STA ($30),Y  ; AND STORE IT AT LSBY1 POSITION
         LDX #$03
SLOOP:   INY          ;STORE THE OTHER THREE BYTES
         PLA
         STA ($30),Y
         DEX
         BNE SLOOP    ;LOOP UNTIL THREE BYTE STORED
         LDA #$FF     ;TURN EXCHANGE FLAG ON (= -1)
         STA $32
         CPY #04      ;WAS EXCHANGE DONE AT START OF LIST?
         BEQ SORT16   ;YES. GO THROUGH LIST AGAIN.
         DEY          ;NO. COMPARE NEXT ELEMENT PAIR
         DEY
         JMP NXTEL

