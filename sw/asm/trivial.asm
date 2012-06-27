; trivial.asm
;
; Trivial 6502 asm test - loads AC with 0xBB.
;

.word $8000
.org  $8000

  lda data
  brk

data:
  .byte $BB

