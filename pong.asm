  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring


;;;;;;;;;;;;;;;

  .rsset $0000
buttons        .rs 1
ballup         .rs 1  ; 1 = ball moving up
balldown       .rs 1  ; 1 = ball moving down
ballleft       .rs 1  ; 1 = ball moving left
ballright      .rs 1  ; 1 = ball moving right
bally          .rs 1
ballx          .rs 1
rtpaddley      .rs 1
rtpaddlebottom .rs 1
rtPaddlePtr    .rs 1
rtPaddlePtrHi  .rs 1
paddleSpace    .rs 1
paddleSpeed    .rs 1
paddleHeight   .rs 1
ballspeedx     .rs 1
ballspeedy     .rs 1

RTPADDLE       = $F0
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
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

  ; init ball position
  LDA #$50
  STA bally

  LDA #$80
  STA ballx

  LDA #$02
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

  LDA #$40
  STA paddleHeight

  LDA #$02
  STA rtPaddlePtrHi
  LDA #$04
  STA rtPaddlePtr


Forever:
  JMP Forever     ;jump back to Forever, infinite loop



NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


ReadController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadControllerLoop:
  LDA $4016
  LSR A           ; bit0 -> Carry
  ROL buttons     ; bit0 <- Carry
  DEX
  BNE ReadControllerLoop


MoveRightPaddle:
MoveRightPaddleUp:
  LDA buttons
  AND #%00001000
  BEQ MoveRightPaddleUpDone

  LDA rtpaddley
  SEC
  SBC paddleSpeed
  STA rtpaddley
  CLC
  ADC paddleHeight
  STA rtpaddlebottom
MoveRightPaddleUpDone:
MoveRightPaddleDown:
  LDA buttons
  AND #%00000100
  BEQ MoveRightPaddleDownDone

  LDA rtpaddley
  CLC
  ADC paddleSpeed
  STA rtpaddley
  ADC paddleHeight
  STA rtpaddlebottom
MoveRightPaddleDownDone:


MoveBallDown:
  LDA balldown
  BEQ MoveBallDownDone

  LDA bally
  CLC
  ADC ballspeedy
  STA bally

  LDA bally
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

  LDA bally
  SEC
  SBC ballspeedy
  STA bally

  LDA bally
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
  CMP #LEFTWALL
  BCS MoveBallLeftDone
  LDA #$00
  STA ballleft
  LDA #$01
  STA ballright
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
  JMP CheckBallPaddleCollide

CheckBallPaddleCollide:
  JSR CollideBallPaddle

MoveBallRightDone:

  JSR UpdateSprites

  RTI             ; return from interrupt

;;;;;;;;;;;;;;

CollideBallPaddle:
  LDA bally
  CMP rtpaddley
  BMI CollideDone
  CLC
  CMP rtpaddlebottom
  BPL CollideDone

  LDA #$01
  STA ballleft
  LDA #$00
  STA ballright
CollideDone:
  RTS

UpdateSprites:
  LDA bally  ; update all ball sprite info
  STA $0200

  LDA #$30
  STA $0201

  LDA #$00
  STA $0202

  LDA ballx
  STA $0203

  JSR UpdateRtPaddle

  RTS


UpdateRtPaddle:
  LDY #$00
  LDA #$00
  STA paddleSpace
UpdateRtPaddleLoop:
  LDA rtpaddley
  CLC
  ADC paddleSpace
  STA [rtPaddlePtr], y

  TYA
  CLC
  ADC #$04
  TAY

  LDA paddleSpace
  CLC
  ADC #$0A
  STA paddleSpace

  CPY #$10
  BNE UpdateRtPaddleLoop
UpdateRtPaddleLoopDone:

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

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


;;;;;;;;;;;;;;


  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1
