; ///////////////////////////////////////////////////////////////
;          ____________  __    ______    ____  ____       __++++++__
;        /     |   __  \|  |  /  /   \  /    |/_   |     |  @       |
;       /  /|  |  |  \  \  | /  /     \/     |  |  |     |  ------  |
;      /  /_|  |  |   |  | |/  /|  |\    /|  |  |  |     | |      | |
;     /  ___   |  |   |  |    / |  | \  / |  |  |  |     | |      | |
;    /  /   |  |  |__/  /    /  |  |  \/  |  |__|  |__   |  ------  |
;   /__/    |__|_______/|___/   |__|      |__|________|  | _+_ o o  |
;        Audio Driver for (dreamcast) VMu (Variant 1)    |  +   O O |
;                                     jvsTSX  /  2024     --______--
; ///////////////////////////////////////////////////////////////
;	
;	- Special thanks to Tildearrow for the duty formula
;	- And the dreamcast community for incentivating this project
;	- This sound driver is derivate from ADPM, but heavily cut down to
;	suit the ultra slow nature of the VMU Quartz mode, forcing me to 
;	trade off complexity for faster playback rates, ADVM2 will instead
;	focus on general complexity like ADPM as 1MHz mode is far more flexible

;	>>> Features <<<
;	- F-0 trough C-5 frequency range, thanks to Timer 1 Mode 3 clock double mode
;	- PWM and SPM parameters, SPM being exclusive to Timer 1 Mode 3
;	- up to 255 phrases, each phrase being variable length with effectively no limit
;	- per-phrase transposition for effective data reusage
;	- Nothing else really... all Block B automations had to be stripped off
;	- But you still get a SFX Sub-driver

;	>>> Resource Usage <<<
;	RAM usage: 
;		Music - 18 bytes
;		SFX   - 6  bytes
;	Size in Flash:
;		Music - 291 bytes (driver) + 41 bytes (setup)
;		SFX   - 83 bytes
;	Cycle Timing (Worst Case):
;		Music - 
;		SFX   - 
;	Cycle Timing (Common Case):
;		Music - 
;		SFX   - 

;    /////////////////////////////////////////////////////////////
;   ///                     SETUP PROGRAM                     ///
;  /////////////////////////////////////////////////////////////

; dw time line position
; dw phrase index list position

_ADVM1_SETUP:
		xor ACC
		st A1R_TmlPos
		st A1R_CurrNote
		st A1R_PWM
		st A1R_SPM
		st A1R_TspOld
		ldc
		st A1RH_TmlBaseL
		mov #1, ACC
		st A1R_RowsWait
		ldc
		st A1RH_TmlBaseH
		mov #2, ACC
		ldc
		st A1RH_PhrIndxL
		mov #3, ACC
		ldc
		st A1RH_PhrIndxH
		mov #$FF, A1R_SFXReq
	jmpf A1L_StepTmLine



;    /////////////////////////////////////////////////////////////
;   ///                     SFX PLAY BLOCK                    ///
;  /////////////////////////////////////////////////////////////
_ADVM1_SFX:
; ESPNWWWW (WW) (NN) (PP) (SS)
; SFX are organized like groove table on ADVM2, across a single 256-byte table

		ld A1R_SFXReq
	be #$FF, .SfxExit        ; if off exit
	be #$FE, .SfxPlaying
		st A1R_SFXPos        ; or else setup new SFX
		mov #1, A1R_SFXWait
.SfxPlaying:
		dec A1R_SFXWait
		ld A1R_SFXWait
	bnz .SfxExit
		ld A1RH_SFXListL
		st TRL
		ld A1RH_SFXListH
		st TRH
		ld A1R_SFXPos
		ldc
		st B            ; SFX header
		and #%00001111  ; wait value (in frames)
	bnz .NormalWait
		inc A1R_SFXPos
		ld A1R_SFXPos
		ldc
.NormalWait:
		st A1R_SFXWait
		
	bn B, 4, .NoFreq
		inc A1R_SFXPos
		ld A1R_SFXPos
		ldc
		st T1LR
.NoFreq:
		
	bn B, 5, .NoPWM
		inc A1R_SFXPos
		ld A1R_SFXPos
		ldc
		st T1LC
.NoPWM:
		
	bn B, 6, .NoSPM
		inc A1R_SFXPos
		ld A1R_SFXPos
		ldc
		st T1HC
.NoSPM:
		
	bn B, 7, .SfxDone
		mov #$FF, A1R_SFXReq ; or else if set, disable SFXReq and exit
	ret
.SfxDone:
		inc A1R_SFXPos
.SfxExit
	ret



;    /////////////////////////////////////////////////////////////
;   ///                   MUSIC PLAY BLOCK                    ///
;  /////////////////////////////////////////////////////////////
; E0SPNWWW (WW) (NN) (WW) (SS) (00)

; too slow for Gmacro and any Block abstractions sadly, this should be available in ADVM2 instead

_ADVM1_RUN_MUSIC:
		dec A1R_RowsWait
		ld A1R_RowsWait
	bz .RunSong
	jmp A1L_RegisterGen
.RunSong:

		ld A1R_PhrPosL
		st TRL
		ld A1R_PhrPosH
		st TRH

		xor ACC
		st C
		ldc  ; get header
		st B

		and #%00000111
	bnz .NormalWait
		inc C
		ld C
		ldc
.NormalWait:
		st A1R_RowsWait
		
	bn B, 3, .NoNote
		inc C
		ld C
		ldc
		st A1R_CurrNote
		ld A1R_TspNew
		st A1R_TspOld
		set1 A1R_Flags, 0
.NoNote:
		
	bn B, 4, .NoPWM
		inc C
		ld C
		ldc
		st A1R_PWM
		set1 A1R_Flags, 0
.NoPWM:
		
	bn B, 5, .NoSPM
		inc C
		ld C
		ldc
		st A1R_SPM
		set1 A1R_Flags, 0
.NoSPM:

	bn B, 6, .NoTimer
		inc C
		ld C
		ldc
		st A1R_Tempo
		set1 A1R_Flags, 1 ; signal a tempo update
.NoTimer:

	bn B, 7, A1L_StepPhrase
A1L_StepTmLine: ; or else step timeline pos
		ld A1RH_TmlBaseL
		st TRL
		ld A1RH_TmlBaseH
		st TRH
		ld A1R_TmlPos
		add ACC
	bn PSW, 7, .NoCarry
		inc TRH
.NoCarry:
		st C
		ldc
	bne #$FF, .TmNotEndedYet
		ld A1RH_TmlBaseH ; reset TRH
		st TRH
		inc C ; get offset
		ld C
		ldc
		st A1R_TmlPos
		add ACC
	bn PSW, 7, .NoCarry2
		inc TRH
.NoCarry2:
		st C
		ldc ; get new phrase
.TmNotEndedYet:
		st B             ; save phrase index for later
		inc C
		ld C
		ldc
		st A1R_TspNew    ; get transpose value
		
		ld A1RH_PhrIndxL ; get index list
		st TRL
		ld A1RH_PhrIndxH
		st TRH
		
		ld B
		add ACC
	bn PSW, 7, .NoCarry3
		inc TRH
.NoCarry3:
		st B
		ldc              ; get two bytes from list location
		st A1R_PhrPosL
		inc B
		ld B
		ldc
		st A1R_PhrPosH
		
		; step timeline forwards
		inc A1R_TmlPos
		
	br A1L_RegisterGen ; done

A1L_StepPhrase:
		inc C ; +1 to offset into the next event
		ld C
		add TRL
		st A1R_PhrPosL
		xor ACC
		addc TRH
		st A1R_PhrPosH

;    /////////////////////////////////////////////////////////////
;   ///                     REGISTER GEN                      ///
;  /////////////////////////////////////////////////////////////

A1L_RegisterGen:
		ld A1R_SFXReq
	bne #$FF, .Exit
	bpc A1R_Flags, 0, .Continue
	ret
.Continue:
		ld A1R_CurrNote
	bne #$FF, .NotMuteNote
		mov #0, T1CNT
	ret
.NotMuteNote:
		mov #<ADVM_NoteTable, TRL
		mov #>ADVM_NoteTable, TRH
		add A1R_TspOld

	be #$12, .here ; if below this range, use non-doubled setting (11)
.here:
	bn PSW, 7, .ClockDoubleOn ; carry is set if #value is below ACC
;		set1 T1CNT, 7 ; off (11)
		mov #%11110000, T1CNT
	br .FreqDone
.ClockDoubleOn:
		mov #%01110000, T1CNT
;		clr1 T1CNT, 7 ; on (01)
.FreqDone:

		ldc
		st T1LR
		xor #$FF
		st C

		ld A1R_PWM
		st B
		xor ACC
		mul
		xor #$FF
		st T1LC
		
		ld A1R_SPM
		st T1HC
		
		ld T1CNT ; retrigger to apply changes
		mov #0, T1CNT
		st T1CNT
.Exit:
	ret

; worst case (step) = ~99 cycles
; worse case (tmrs) = ~194 cycles

;    /////////////////////////////////////////////////////////////
;   ///                     LIBRARY SPACE                     ///
;  /////////////////////////////////////////////////////////////
ADVM_NoteTable:
	.byte $06 ; F-0   00
	.byte $14 ; F#0   01
	.byte $21 ; G-0   02
	.byte $2E ; G#0   03
	.byte $39 ; A-0   04
	.byte $45 ; A#0   05
	.byte $4F ; B-0   06

	.byte $59 ; C-1   07
	.byte $62 ; C#1   08
	.byte $6B ; D-1   09
	.byte $73 ; D#1   0A
	.byte $7C ; E-1   0B ; last using 11
	.byte $06 ; F-1   0C
	.byte $14 ; F#1   0D
	.byte $21 ; G-1   0E
	.byte $2E ; G#1   0F
	.byte $39 ; A-1   10
	.byte $45 ; A#1   11
	.byte $4F ; B-1   12

	.byte $59 ; C-2   13
	.byte $62 ; C#2   14
	.byte $6B ; D-2   15
	.byte $73 ; D#2   16
	.byte $7C ; E-2   17
	.byte $83 ; F-2   18
	.byte $8A ; F#2   19
	.byte $90 ; G-2   1A
	.byte $97 ; G#2   1B
	.byte $9D ; A-2   1C
	.byte $A2 ; A#2   1D
	.byte $A8 ; B-2   1E

	.byte $AC ; C-3   1F
	.byte $B1 ; C#3   20
	.byte $B6 ; D-3   21
	.byte $BA ; D#3   22
	.byte $BE ; E-3   23
	.byte $C1 ; F-3   24
	.byte $C5 ; F#3   25
	.byte $C8 ; G-3   26
	.byte $CB ; G#3   27
	.byte $CE ; A-3   28
	.byte $D1 ; A#3   29
	.byte $D4 ; B-3   2A

	.byte $D6 ; C-4   2B
	.byte $D9 ; C#4   2C
	.byte $DB ; D-4   2D
	.byte $DD ; D#4   2E
	.byte $DF ; E-4   2F
	.byte $E1 ; F-4   30
	.byte $E2 ; F#4   31
	.byte $E4 ; G-4   32
	.byte $E6 ; G#4   33
	.byte $E7 ; A-4   34
	.byte $E8 ; A#4   35
	.byte $EA ; B-4   36

	.byte $EB ; C-5   37
	.byte $EC ; C#5   38

	.byte $FC
	.byte $FE
	.byte $FF ; off $3B


;    /////////////////////////////////////////////////////////////
;   ///                    RAM DEFINITIONS                    ///
;  /////////////////////////////////////////////////////////////

A1RH_TmlBaseL = $10
A1RH_TmlBaseH = $11
A1RH_PhrIndxL = $12
A1RH_PhrIndxH = $13

A1R_RowsWait = $14
A1R_PhrPosL  = $15
A1R_PhrPosH  = $16
A1R_TmlPos   = $17
A1R_CurrNote = $18
A1R_SPM      = $19
A1R_PWM      = $1A
A1R_TspNew   = $1B
A1R_TspOld   = $1C
A1R_Flags    = $1D
A1R_Tempo    = $1E

A1RH_SFXListL = $1F
A1RH_SFXListH = $20
A1R_SFXReq    = $21
A1R_SFXWait   = $22
A1R_SFXPos    = $23

; 18 bytes RAM total, 13 for music, 5 for SFX