  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring


;;;;;;;;;;;;;;;

  .rsset $0000
buttonsP1      .rs 1
buttonsP2      .rs 1
ballup         .rs 1  ; 1 = ball moving up
balldown       .rs 1  ; 1 = ball moving down
ballleft       .rs 1  ; 1 = ball moving left
ballright      .rs 1  ; 1 = ball moving right
ballY          .rs 1
ballx          .rs 1
rtPaddleTop    .rs 1
rtPaddleBottom .rs 1
rtPaddlePtr    .rs 1
rtPaddlePtrHi  .rs 1
lfPaddleTop    .rs 1
lfPaddleBottom .rs 1
lfPaddlePtr    .rs 1
lfPaddlePtrHi  .rs 1
paddleSpace    .rs 1
paddleSpeed    .rs 1
paddleHeight   .rs 1
ballspeedx     .rs 1
ballspeedy     .rs 1

RTPADDLE       = $F0
LFPADDLE       = $08
RIGHTWALL      = $F4  ; when ball reaches one of these, do something
TOPWALL        = $20
BOTTOMWALL     = $E0
LEFTWALL       = $04

;;;;;;;;;;;;;;;

  .bank 0
  .org $C000
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$80              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

  ; init ball position
  LDA #$50
  STA ballY

  LDA #$80
  STA ballx

  LDA #$04
  STA ballspeedx
  STA ballspeedy

  LDA #$04
  STA paddleSpeed

  LDA #$00
  STA balldown
  STA ballright
  LDA #$01
  STA ballup
  STA ballleft

  LDA #$3C  ; number of paddle segments times #$0A
  STA paddleHeight

  LDA #$02
  STA rtPaddlePtrHi
  LDA #$04
  STA rtPaddlePtr

  LDA #$02
  STA lfPaddlePtrHi
  LDA #$1C
  STA lfPaddlePtr

  LDA #$80
  STA rtPaddleTop
  STA lfPaddleTop
  CLC
  ADC paddleHeight
  STA rtPaddleBottom


Forever:
  JMP Forever     ;jump back to Forever, infinite loop



NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


;;;;;;;;;;;;;;;;;;;
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A
  ROL buttonsP1
  DEX
  BNE ReadController1Loop

ReadController2:
  LDA #$01
  STA $4017
  LDA #$00
  STA $4017
  LDX #$08
ReadController2Loop:
  LDA $4017
  LSR A
  ROL buttonsP2
  DEX
  BNE ReadController2Loop
;;;;;;;;;;;;;;;;;;;;;

MoveRightPaddle:
MoveRightPaddleUp:
  LDA buttonsP2
  AND #%00001010
  BEQ MoveRightPaddleUpDone

  LDA rtPaddleTop
  CMP #TOPWALL
  BCC MoveRightPaddleUpDone

  LDA rtPaddleTop
  SEC
  SBC paddleSpeed
  STA rtPaddleTop
MoveRightPaddleUpDone:
MoveRightPaddleDown:
  LDA buttonsP2
  AND #%00000101
  BEQ MoveRightPaddleDownDone

  LDA rtPaddleBottom
  CMP #BOTTOMWALL
  BCS MoveRightPaddleDownDone

  LDA rtPaddleTop
  CLC
  ADC paddleSpeed
  STA rtPaddleTop
MoveRightPaddleDownDone:

MoveLeftPaddle:
MoveLeftPaddleUp:
  LDA buttonsP1
  AND #%00001010
  BEQ MoveLeftPaddleUpDone

  LDA lfPaddleTop
  CMP #TOPWALL
  BCC MoveLeftPaddleUpDone

  LDA lfPaddleTop
  SEC
  SBC paddleSpeed
  STA lfPaddleTop
MoveLeftPaddleUpDone:
MoveLeftPaddleDown:
  LDA buttonsP1
  AND #%00000101
  BEQ MoveLeftPaddleDownDone

  LDA lfPaddleBottom
  CMP #BOTTOMWALL
  BCS MoveLeftPaddleDownDone

  LDA lfPaddleTop
  CLC
  ADC paddleSpeed
  STA lfPaddleTop
MoveLeftPaddleDownDone:
;;;;;;;;;;;;;;;;;;;;

MoveBallDown:
  LDA balldown
  BEQ MoveBallDownDone

  LDA ballY
  CLC
  ADC ballspeedy
  STA ballY

  LDA ballY
  CMP #BOTTOMWALL
  BCC MoveBallDownDone
  LDA #$00
  STA balldown
  LDA #$01
  STA ballup
MoveBallDownDone:

MoveBallUp:
  LDA ballup
  BEQ MoveBallUpDone

  LDA ballY
  SEC
  SBC ballspeedy
  STA ballY

  LDA ballY
  CMP #TOPWALL
  BCS MoveBallUpDone
  LDA #$01
  STA balldown
  LDA #$00
  STA ballup
MoveBallUpDone:

MoveBallLeft:
  LDA ballleft
  BEQ MoveBallLeftDone

  LDA ballx
  SEC
  SBC ballspeedx
  STA ballx

  LDA ballx
  CMP #LFPADDLE
  BCS MoveBallLeftDone
  JSR CollideBallLeftPaddle
MoveBallLeftDone:

MoveBallRight:
  LDA ballright
  BEQ MoveBallRightDone

  LDA ballx
  CLC
  ADC ballspeedx
  STA ballx

  LDA ballx
  CMP #RTPADDLE
  BCC MoveBallRightDone
  JSR CollideBallRightPaddle
MoveBallRightDone:

  JSR UpdateSprites

  RTI
;;;;;;;;;;;;;;

CollideBallRightPaddle:
CheckRightPaddleCollision:
  LDA ballY
  CMP rtPaddleTop
  BMI CollideRDone  ; if ballY < rtPaddleTop, done
  CLC
  CMP rtPaddleBottom  ; if ballY > rtPaddleBottom, done
  BPL CollideRDone

  LDA #$01
  STA ballleft
  LDA #$00
  STA ballright
CollideRDone:
  RTS

CollideBallLeftPaddle:
CheckLeftPaddleCollision:
  LDA ballY
  CMP lfPaddleTop
  BMI CollideLDone
  CLC
  CMP lfPaddleBottom
  BPL CollideLDone

  LDA #$00
  STA ballleft
  LDA #$01
  STA ballright
CollideLDone:
  RTS

UpdateSprites:
  LDA ballY
  STA $0200

  LDA #$30
  STA $0201

  LDA #$00
  STA $0202

  LDA ballx
  STA $0203

  JSR UpdatePaddle

  RTS


UpdatePaddle:
  LDY #$00
  LDA #$00
  STA paddleSpace
UpdatePaddleLoop:
  LDA rtPaddleTop
  CLC
  ADC paddleSpace
  STA [rtPaddlePtr], y
  LDA lfPaddleTop
  CLC
  ADC paddleSpace
  STA [lfPaddlePtr], y

  TYA
  CLC
  ADC #$04
  TAY

  LDA paddleSpace
  CLC
  ADC #$0A
  STA paddleSpace

  CPY #$18  ; number of paddle segments times #$04
  BNE UpdatePaddleLoop
UpdatePaddleLoopDone:
  ; keep paddle bottom in sync with where the paddle is
  LDA rtPaddleTop
  CLC
  ADC paddleHeight
  STA rtPaddleBottom

  LDA lfPaddleTop
  CLC
  ADC paddleHeight
  STA lfPaddleBottom

  RTS



  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

sprites:
     ;vert tile attr horiz
  .db $80, $32, $00, $80   ;ball, 0200
  .db $80, $32, $00, $F0 ;rt paddle top, 0204
  .db $87, $32, $00, $F0 ;rt paddle next, 0208
  .db $8E, $32, $00, $F0 ;rt paddle next, 020C
  .db $95, $32, $00, $F0 ;rt paddle next, 0210
  .db $9C, $32, $00, $F0 ;rt paddle next, 0214
  .db $A3, $32, $00, $F0 ;rt paddle next, 0218
  .db $80, $32, $00, $08 ;lf paddle top,  021C
  .db $87, $32, $00, $08 ;lf paddle next, 0220
  .db $8E, $32, $00, $08 ;lf paddle next, 0224
  .db $95, $32, $00, $08 ;lf paddle next, 0228
  .db $9C, $32, $00, $08 ;lf paddle next, 022C
  .db $A3, $32, $00, $08 ;lf paddle next, 0230

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0


;;;;;;;;;;;;;;


  .bank 2
  .org $0000
  .incbin "mario.chr"
