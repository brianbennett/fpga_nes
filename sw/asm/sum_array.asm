; sum_array.asm
;
; Adds up an array of 8-bit integers:
;

; Test should load the array pointer at 0x0000, the array size at 0x002, and the result will be
; put at 0x0004.
.alias array_addr $0000
.alias array_size $0002
.alias total      $0004

.word $8000
.org  $8000

  lda #0
  sta total
  sta total+1

  ldy array_size

loop:
  dey
  lda (array_addr), y
  clc
  adc total
  sta total
  lda #0
  adc total+1
  sta total+1
  cpy #0
  bne loop
 
  .byte $02  ; HLT
