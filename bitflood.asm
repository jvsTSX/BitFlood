.include "sfr.i"

	.org 0   ; entry point
	jmpf Start
	.org $03 ; External int. (INT0)                 - I01CR
	reti
	.org $0B ; External int. (INT1)                 - I01CR
	reti
	.org $13 ; External int. (INT2) and Timer 0 low - I23CR and T0CON
	clr1 T0CON, 1
;	call CallSound
;	reti
	jmp INT_GameTimeAndSound

	.org $1B ; External int. (INT3) and base timer  - I23CR and BTCR		
	jmp int_BaseTimerFire
		
		


	.org $23 ; Timer 0 high                         - T0CON
		clr1 T0CON, 3 ; clear int bit
	reti
	.org $2B ; Timer 1 Low and High                 - T1CNT
	reti
	.org $33 ; Serial IO 1                          - SCON0
	reti
	.org $3B ; Serial IO 2                          - SCON1
	reti
	.org $43 ; Maplebus                             - $160 / $161
	reti
	.org $4B ; Port 3 interrupt                     - P3INT
		clr1 P3INT, 1
		mov #16, HaltCount
	reti


int_BaseTimerFire:
		clr1 BTCR, 3
		clr1 BTCR, 1
;	dbnz GameTime, .notyet
;		set1 GBeFlag, 3 ; time step flag
;		mov #10, GameTime
;.notyet:
	reti

INT_GameTimeAndSound:
; time step
		push PSW
		push ACC
		ld RsSpeedAcc
		add RsSpeedAdd
		st RsSpeedAcc
	bn PSW, 7, .No_Ov
		set1 GBeFlag, 3
.No_Ov:
	bp SoundEnable, 4, .CallADVM1
		pop ACC
		pop PSW
	reti

.CallADVM1:
		push TRL
		push TRH
		push B
		push C
;	call _ADVM1_SFX
	call _ADVM1_RUN_MUSIC
;		mov #%01010000, T1CNT
		pop C
		pop B
		pop TRH
		pop TRL
		pop ACC
		pop PSW
	reti



.org $1F0 ; exit
Exit_BIOS:
		not1 EXT, 0
	jmpf Exit_BIOS

.org $200
.string 16 "Bit Flood"
.string 32 "By https://github.com/jvsTSX"

.org $240
.include icon "bitflood_icon.gif"

;    /////////////////////////////////////////////////////////////
;   ///                  INITIALIZING STUFF                   ///
;  /////////////////////////////////////////////////////////////
Start:
		mov #0, T1CNT
		mov #%10000000, P1FCR
		mov #%10000000, P1DDR
		mov #0, P1
		mov #%10000000, VCCR
		mov #0, T0CON
		mov #$FC, T0PRR
		mov #$BB, T0LR
		mov #0, SleepStatus
		mov #0, P3INT

		mov #<GFX_AuthorLogo, TRL
		mov #>GFX_AuthorLogo, TRH
		mov #0, XBNK
		mov #$80, 2
		mov #0, C



.rtx_loop:
	mov #12, B
.rtx_inner:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .rtx_inner
		ld 2
		add #4
		st 2
	bn PSW, 7, .rtx_loop
	bp XBNK, 0, .rtxcopy_done
		inc XBNK
		set1 2, 7
	br .rtx_loop
.rtxcopy_done:

		mov #0, B
		mov #10, C
.showlogowait:
	dbnz B, .showlogowait
	dbnz C, .showlogowait



		; clear WRAM
		mov #252, C
		set1 VSEL, 4 ; autoinc on
		xor ACC
		st VRMAD2
		st VRMAD1
.clrloop1:
		st VTRBF
	dbnz C, .clrloop1

; those four untouched bytes holds the LFSR RNG state and a garbage-check pair (must be 0 then FF for it to be valid)
; these precise values are choosen because SRAM initial state is not exactly random, it's sort of a corrupted alternating pattern
; so unlikely to get all-zero followed by all-one, if not impossible
; pretty much why you shouldn't rely on initial RAM values for RNG seeding, some machines are actually deterministic (such as game boy color)

		mov #0, VRMAD2
		mov #$FC, VRMAD1
		ld VTRBF
	bnz .InitRNG
		ld VTRBF
		inc ACC
	bnz .InitRNG ; FF + 1 = 0, therefore if not zero then it's initial garbage
	br .NoInitRNG

.InitRNG:
		mov #$FC, VRMAD1
		xor ACC
		st VTRBF
		dec ACC  ; = $FF
		st VTRBF
		st VTRBF
		st VTRBF
.NoInitRNG:

		; initialize WRAM with the cursor icons
		mov #29+6, B
		mov #3, VRMAD1
		mov #0, VRMAD2
		mov #0, C
		mov #<GFX_Cursor, TRL
		mov #>GFX_Cursor, TRH
.wramloop:
		ld C
		inc C
		ldc
		st VTRBF
	dbnz B, .wramloop

		; default settings
		mov #10, GoalCnt
		mov #%00010000, SoundEnable

;    /////////////////////////////////////////////////////////////
;   ///                     TITLE SCREEN                      ///
;  /////////////////////////////////////////////////////////////
GameReset:
		mov #0, T1CNT
; title screen
		mov #0, T0CON
		mov #16, HaltCount
		mov #0, XBNK
	call ClearScreenHalf
		inc XBNK
	call ClearScreenHalf

		mov #$C0, 3
		mov #24, 0
	call DrawTextRow

		mov #<GFX_TitleLogo, TRL
		mov #>GFX_TitleLogo, TRH
		mov #0, C
		mov #$91, 2
		mov #0, XBNK
		mov #10, 0
		
; and the logo part
.xcpy:
		mov #4, B
.xloop1:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .xloop1

		inc 2
		inc 2
		mov #4, B
.xloop2:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .xloop2
		ld 2
		add #6
		st 2
	dbnz 0, .xcont
	br .xexit
.xcont:
	bn PSW, 7, .xcpy
		inc XBNK
		set1 2, 7
	br .xcpy

.xexit:

		mov #%00000101, P3INT
	call ProcessKeys ; to nullify any held keys
TitleLoop:
	call ProcessKeys
	bn KeysDiff, 6, .No_Exit
	jmpf Exit_BIOS
.No_Exit:
		set1 PCON, 0
	bn KeysDiff, 4, TitleLoop

;    /////////////////////////////////////////////////////////////
;   ///                        MAIN MENU                      ///
;  /////////////////////////////////////////////////////////////

		mov #0, XBNK
	call ClearScreenHalf
		inc XBNK
	call ClearScreenHalf

; draw the indication texts
		mov #<GFX_MainMenuText, TRL
		mov #>GFX_MainMenuText, TRH
	call SUB_DrawMenuImages
		mov #%00001111, GfxFlag
		mov #0, MenuCursor

	call ProcessKeys ; to nullify any held keys
MainMenuLoop:
	call ProcessKeys
	
	bn KeysDiff, 6, .No_Exit
	jmpf Exit_BIOS
.No_Exit:
	
	bn KeysDiff, 0, .NoUpKey
		set1 GfxFlag, 0
		ld MenuCursor
;	bz .NoUpKey
	bnz .IncCursor
		mov #2, MenuCursor
	br .NoUpKey
.IncCursor:
		dec MenuCursor
.NoUpKey:

	bn KeysDiff, 1, .NoDownKey
		set1 GfxFlag, 0
		ld MenuCursor
;	be #2, .NoDownKey
	bne #2, .DecCursor
		mov #0, MenuCursor
	br .NoDownKey
.DecCursor:
		inc MenuCursor
.NoDownKey:

		mov #0, B
	bn KeysDiff, 2, .NoLeftKey
		mov #00000010, B
.NoLeftKey:

	bn KeysDiff, 3, .NoRightKey
		mov #00000011, B
.NoRightKey:

; process setting based on current cursor position and pressed keys
	bn B, 1, .No_Edit
		ld MenuCursor
		and #%00000011
	bz .EditHeight
	be #1, .EditGoal
		; default: edit speed
		set1 GfxFlag, 3
		mov #RsSpeed, 1
		mov #9, C
	br .EditVal
		
.EditHeight:
		set1 GfxFlag, 1
		mov #StartHeight, 1
		mov #32, C
	br .EditVal

.EditGoal:
		set1 GfxFlag, 2	
		mov #GoalCnt, 1
		mov #99, C ; max value
		
.EditVal:
	bp B, 0, .IncVal
		ld @r1
	bz .No_Edit
		dec @r1
	br .No_Edit

.IncVal:
		ld @r1
	be C, .No_Edit
	bn PSW, 7, .No_Edit ; in case it's greater than
		inc @r1
.No_Edit:

	; draw any of the settings if the GFX flag is set (reused from main loop)
	; 3 - speed
	; 2 - goal
	; 1 - height
	; 0 - draw cursor

	bn GfxFlag, 0, .CursorDone
		clr1 GfxFlag, 0
	call SUB_DrawMenuCursor
.CursorDone:

	bn GfxFlag, 1, .DrawHeightDone
		mov #0, XBNK
		mov #$83, 2
		ld StartHeight
	call DrawBCDPair
		clr1 GfxFlag, 1
.DrawHeightDone:

	bn GfxFlag, 2, .DrawGoalDone
		mov #0, XBNK
		mov #$C3, 2
		ld GoalCnt
	call DrawBCDPair
		clr1 GfxFlag, 2
.DrawGoalDone:

	bn GfxFlag, 3, .DrawSpeedDone
		mov #1, XBNK
		mov #$84, 2
		ld RsSpeed
		and #%00001111
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH
	call DrawDispNumber
		clr1 GfxFlag, 3
.DrawSpeedDone:

	bp KeysDiff, 4, ign_Launch
	dbnz HaltCount, .NoHalt
		set1 PCON, 0
		mov #16, HaltCount
.NoHalt:
	jmp MainMenuLoop

ign_Launch:
		; clean the screen
		mov #0, XBNK
	call ClearScreenHalf
		inc XBNK
	call ClearScreenHalf

		; get RNG values from WRAM
		set1 VSEL, 4   ; autoinc on
		mov #0, VRMAD2
		mov #$FE, VRMAD1
		ld VTRBF
		st RNG_LFSR6
		ld VTRBF
		st RNG_LFSR7

		; clear WRAM's second half (to ensure the field is initialized)
		set1 VSEL, 4 ; autoinc on
		xor ACC
		st VRMAD1
		st B
		mov #1, VRMAD2
.clrloop:
		st VTRBF
	dbnz B, .clrloop

		mov #0, P3INT
		mov #%10100011, OCR
		mov #1, VRMAD2
		mov #0, VSEL ; b4 is INCE, keep it 0 to avoid increments
		mov #0, RsLevel
		mov #0, LineCnt

;		mov #10, GameTime ; TEMPORARY, FINAL SHOULD USE A VARIABLE
		mov #10, RsSpeedIncCnt

		; timer for sound tempo

		; init important variables
		mov #16, CursorPos ; cursor around the middle of the screen
		mov #%00101111, GfxFlag ; full refresh
		mov #%00000000, GBeFlag ; no behaviour
		mov #0, CarryBit

		; generate garbage according to height's level
		ld StartHeight
	bz .CleanStack
		clr1 VSEL, 4 ; no autoinc
		mov #32, ACC
		sub StartHeight
		st C
		ld StartHeight
		st B
.garbageloop:
		mov #1, VRMAD2
		ld C
		st VRMAD1
	call SUB_LRNGGenLine
		inc C
	dbnz B, .garbageloop
.CleanStack:

		mov #<BGM_Header, TRL
		mov #>BGM_Header, TRH
	call _ADVM1_SETUP

		mov #8, RsLevel
		ld RsSpeed
		inc ACC
		rol
		rol
		st RsSpeedAdd
		mov #%01000001, T0CON
		mov #$80, IE
		clr1 VSEL, 4

;    /////////////////////////////////////////////////////////////
;   ///                    IN-GAME LOOP                       ///
;  /////////////////////////////////////////////////////////////

ign_loop:
		mov #0, P3INT
	call ProcessKeys
ign_HandleInputs: ; ///////////////////////////////////////// handle key presses
	bn KeysDiff, 6, .No_Pause
	jmp PAUSE_Start
.No_Pause:

		mov #1, 0
	bn KeysCurr, 5, .NoB
		mov #8, 0
		set1 GfxFlag, 4
.NoB:

	bn KeysDiff, 0, .NoUp
		ld CursorPos
		sub 0
	bp PSW, 7, .ClipUp
		and #%00011111
		st CursorPos
		set1 GfxFlag, 0 ; update cursor
	br .NoUp
.ClipUp:
		mov #0, CursorPos
		set1 GfxFlag, 0
.NoUp:

	bn KeysDiff, 1, .NoDown
		ld CursorPos
		or #%11100000
		add 0
	bp PSW, 7, .ClipDown
		and #%00011111
		st CursorPos
		set1 GfxFlag, 0 ; update cursor
	br .NoDown
.ClipDown:
		mov #31, CursorPos
		set1 GfxFlag, 0
.NoDown:

	bn KeysDiff, 2, .NoLeft
		set1 GBeFlag, 0 ; update line
		set1 GBeFlag, 1 ; shift it left
		set1 GfxFlag, 0 ; update cursor
.NoLeft:

	bn KeysDiff, 3, .NoRight
		set1 GBeFlag, 0 ; update line
		clr1 GBeFlag, 1 ; shift it right
		set1 GfxFlag, 0 ; udpate cursor
.NoRight:

	bn KeysDiff, 4, .NoA
		set1 GBeFlag, 3
		set1 GBeFlag, 2 ; reset time and force new line
.NoA:



	bn GBeFlag, 0, ign_NoShiftLine ; //////////////////////// shift selected line
		mov #1, VRMAD2
		ld CursorPos
		st VRMAD1
		clr1 VSEL, 4


	bn GBeFlag, 1, .right
		ld CarryBit
		rorc
		ld VTRBF
		rolc
		st VTRBF
		xor ACC
		rolc
		st CarryBit
	br .done
.right:
		ld CarryBit
		rorc
		ld VTRBF
		rorc
		st VTRBF
		xor ACC
		rolc
		st CarryBit
.done:
		ld CursorPos
		rol
		rol
		rol
		rol
		st B
		ror
		set1 ACC, 7
		clr1 ACC, 3
	bn CursorPos, 0, .even
		add #6
.even:

		add #2
		st 2
		ld B
		and #%00000001
		st XBNK
		ld VTRBF
		st @r2
	bne #$FF, .shiftdone
		set1 GBeFlag, 4
.shiftdone:
		clr1 GBeFlag, 0
ign_NoShiftLine:



	bn GBeFlag, 4, ign_NoClearLine  ; //////////////////////// clear a line from the field
	dbnz RsSpeedIncCnt, .No_SpeedInc ; increase speed every 10 lines cleared
		mov #10, RsSpeedIncCnt
		ld RsSpeedAdd
	be #%00101000, .No_SpeedInc
		add #%00000100
		st RsSpeedAdd
.No_SpeedInc:

		; NOTE TO SELF: 0 IS TOP NOT BOTTOM
		ld CursorPos
		add #1
		st B	
		ld CursorPos
		sub #1
		st C
		clr1 VSEL, 4
		
.loop:
		ld C
		st VRMAD1
		sub #1
		st C
		ld VTRBF
		inc VRMAD1
		st VTRBF
	dbnz B, .loop
		
		mov #0, VTRBF
		inc LineCnt
		ld LineCnt
	be GoalCnt, .dummy
.dummy:
	bp PSW, 7, .continue_ingame
		mov #0, XBNK ; force a line count redraw
		mov #$A4, 2
		ld LineCnt
	call DrawBCDPair
		mov #0, B
		jmp ign_GameEnd
.continue_ingame:
		set1 GfxFlag, 2
		set1 GfxFlag, 1 ; update screen
		clr1 GBeFlag, 4
ign_NoClearLine:

; todo: 
; change rise time to accumulator-based
; increase time speed every 10 lines cleared
; add sleep routine - done
; add music

	bn GBeFlag, 3, .ign_NoTimeStep ; ////////////////////////// step time
		clr1 GBeFlag, 3
		set1 GfxFlag, 3
	bn GBeFlag, 2, .normal_step
		; resets Rs counter if A (button) is pressed
		clr1 GBeFlag, 2
		mov #0, RsSpeedAcc
	br .do_step
		
.normal_step:
	dbnz RsLevel, .ign_NoTimeStep
.do_step:
		mov #8, RsLevel
		set1 GBeFlag, 5
.ign_NoTimeStep:



	bn GBeFlag, 5, .stack_done ; //////////////////////////// rise stack
		clr1 GBeFlag, 5
		clr1 VSEL, 4 ; no increment
		mov #0, VRMAD1
		mov #1, VRMAD2

		; move stack
		mov #31, ACC
		st VRMAD1
		set1 GfxFlag, 1 ; refresh screen
		
		xor ACC
		mov #32, C
.checkhole:
	be VTRBF, .holefound
		dec VRMAD1
	dbnz C, .checkhole
.holefound:

		ld C
	bz .no_inc_cursor          ; is the cursor at exactly 0 (stack top)?, if so don't move
	be CursorPos, .rise_cursor ; is it at the rising line? if so yes, move the cursor
	bn PSW, 7, .no_inc_cursor  ; if not, is it above the rising line? BE sets carry to 1 if it's lesser than (strictly, not equal), if so don't move if it's cleared (greater/above line)
.rise_cursor:
		set1 GfxFlag, 0 ; update cursor graphics
		dec CursorPos
.no_inc_cursor:

		mov #32, ACC
		sub C
	bz .no_raise
	be #32, .govertest
		st C
		
		; rise cursor?
.raisestack:
		inc VRMAD1
		ld VTRBF
		dec VRMAD1
		st VTRBF
		inc VRMAD1
	dbnz C, .raisestack

	br .no_raise
.govertest:
	mov #1, B
	jmp ign_GameEnd
.no_raise:

	call SUB_LRNGGenLine

.stack_done:



	bn GfxFlag, 3, .skip_rsind ; //////////////////////// rise indicator
		mov #1, XBNK
		mov #$FF, B
		ld RsLevel
		st C
		mov #%10000001, ACC
		
		dbnz C, .rsind_7
		ld B
.rsind_7:
		st $1CB
		dbnz C, .rsind_6
		ld B
.rsind_6:
		st $1D5
		dbnz C, .rsind_5
		ld B
.rsind_5:
		st $1DB
		dbnz C, .rsind_4
		ld B
.rsind_4:
		st $1E5
		dbnz C, .rsind_3
		ld B
.rsind_3:
		st $1EB
		dbnz C, .rsind_2
		ld B
.rsind_2:
		st $1F5
		dbnz C, .rsind_1
		ld B
.rsind_1:
		st $1FB
		clr1 GfxFlag, 3
.skip_rsind:


	bn GfxFlag, 0, ign_NoCursorUpdate ; ////////////////////// draw cursor
	bn GfxFlag, 4, .noclear
		clr1 GfxFlag, 4
		mov #$81, 2
	call ClearCol
		mov #$83, 2
	call ClearCol
.noclear:

		; check which bit state is it
		ld CarryBit
		rorc
		xor ACC
		st VRMAD2
	bp PSW, 7, .emptycur
		add #20
.emptycur:
		st VRMAD1

		; offset the cursor, clipping it if underflows
		set1 VSEL, 4
		ld CursorPos
		clr1 ACC, 0
		sub #4
	bn PSW, 7, .nouf

		st B
		xor ACC
		st cursor_temp_xbnk
		sub B
		st cursor_temp_offset
		xor ACC
	br .cursor_clipped
.nouf:
		mov #0, cursor_temp_offset
		rol ; --BIIIS-
		rol ; -BIIIS--
		rol ; BIIIS---
		rol ; IIIS---B
		st cursor_temp_xbnk
		ror
.cursor_clipped:
		set1 ACC, 7
		st cursor_temp_scrpos

		inc ACC
		st 2
		mov #10, ACC
		sub cursor_temp_offset
		ror
		st C
		ld VRMAD1
		add cursor_temp_offset
		st VRMAD1

	bp CursorPos, 0, .noinc
		inc VRMAD1
.noinc:

	call DrawCursorRegion
		
		ld C
		rol
		add VRMAD1
		st VRMAD1

		ld cursor_temp_scrpos
		add #3
		st 2
		mov #10, ACC
		sub cursor_temp_offset
		ror
		st C
		ld VRMAD1
		add cursor_temp_offset
		st VRMAD1
	call DrawCursorRegion
		
		clr1 GfxFlag, 0
ign_NoCursorUpdate:



	bn GfxFlag, 1, ign_NoBitfieldUpdate ; //////////////////// draw bitfield
		mov #1, VRMAD2
		mov #0, VRMAD1
		clr1 VSEL, 4
		mov #0, XBNK
		mov #$82, 2
	call BlitColumn
		clr1 GfxFlag, 1
ign_NoBitfieldUpdate:



	bn GfxFlag, 2, .no_dispnumbers ; //////////////////// line clear number
		mov #0, XBNK
		mov #$A4, 2
		ld LineCnt
	call DrawBCDPair
		clr1 GfxFlag, 2
.no_dispnumbers:


	bn GfxFlag, 5, .No_IndElements
		clr1 GfxFlag, 5
		; draw the LCLR text
		mov #0, XBNK
		mov #%10000110, $184
		mov #%10000110, $185
		mov #%10001000, $18A
		mov #%10001000, $18B
		mov #%11100110, $194
		mov #%11101000, $195
		
		; draw the rise indicator text
		mov #1, XBNK
		mov #%11000000, $1DA
		mov #%10100110, $1E4
		mov #%11001100, $1EA
		mov #%10100010, $1F4
		mov #%10101110, $1FA
.No_IndElements:

	jmp ign_loop

;    /////////////////////////////////////////////////////////////
;   ///                   PAUSE MENU LOOP                     ///
;  /////////////////////////////////////////////////////////////
PAUSE_Start:
		push RsSpeedAdd ; disable the line timing but keep the timer on for the music
		mov #0, RsSpeedAdd
		mov #%00000101, P3INT
		mov #0, XBNK
	call ClearScreenHalf
		inc XBNK
	call ClearScreenHalf

; draw the indication texts
		mov #<GFX_PauseMenuText, TRL
		mov #>GFX_PauseMenuText, TRH
	call SUB_DrawMenuImages	

		mov #1, XBNK
		mov #%00011110, $199
		mov #%00011110, $1D9
		mov #%11110000, $19A
		mov #%11110000, $1DA
		
		mov #0, XBNK
		mov #$89, 2
	call SUB_InitOnOffSettingGFX
		mov #$C9, 2
	call SUB_InitOnOffSettingGFX
		
		mov #%00000111, GfxFlag
		mov #0, MenuCursor	
		
PAUSE_Main:
	call ProcessKeys


	bn KeysDiff, 0, .No_UpKey
		dec MenuCursor
		ld MenuCursor
		and #%00000011
		st MenuCursor
		set1 GfxFlag, 0
.No_UpKey:

	bn KeysDiff, 1, .No_DownKey
		inc MenuCursor
		ld MenuCursor
		and #%00000011
		st MenuCursor
		set1 GfxFlag, 0
.No_DownKey:

		mov #0, B
	bn KeysDiff, 2, .No_LeftKey
		set1 B, 0
.No_LeftKey:

	bn KeysDiff, 3, .No_RightKey
		set1 B, 0
.No_RightKey:

		
	bn B, 0, .No_Edit
	bp MenuCursor, 0, .EditIcon
		not1 SoundEnable, 4
		set1 GfxFlag, 1
	br .No_Edit
.EditIcon:
		mov #2, XBNK
		not1 $182, 4
		set1 GfxFlag, 2
.No_Edit:

	bn KeysDiff, 4, .No_AKey
	bn MenuCursor, 1, .No_AKey
	bp MenuCursor, 0, .ExitApp
	jmpf GameReset
.ExitApp:
	jmpf Exit_BIOS
.No_AKey:

	bn GfxFlag, 0, .NoCursor
		clr1 GfxFlag, 0
	call SUB_DrawMenuCursor
.NoCursor:

	bn GfxFlag, 1, .NoSound
		clr1 GfxFlag, 1
		ld SoundEnable
		mov #0, XBNK
		mov #$8A, 2
	call SUB_UpdateOnOffSetting
	bp SoundEnable, 4, .NoSound
		mov #0, T1CNT
.NoSound:

	bn GfxFlag, 2, .NoIcon
		clr1 GfxFlag, 2
		mov #2, XBNK
		ld $182
		mov #0, XBNK
		mov #$CA, 2
	call SUB_UpdateOnOffSetting
.NoIcon:

	bp KeysDiff, 6, PAUSE_ReturnInGame

	dbnz HaltCount, .NoHalt
		set1 PCON, 0
		mov #16, HaltCount
.NoHalt:
	jmp PAUSE_Main

PAUSE_ReturnInGame:
		mov #0, XBNK
	call ClearScreenHalf
		inc XBNK
	call ClearScreenHalf
		mov #%00101111, GfxFlag
		pop RsSpeedAdd
	jmp ign_loop



;    /////////////////////////////////////////////////////////////
;   ///                    GAME END LOOP                      ///
;  /////////////////////////////////////////////////////////////

ign_GameEnd:
		mov #0, T1CNT
		; clear the bottom half of the screen
		mov #0, T0CON
		mov #1, XBNK
	call ClearScreenHalf

		; game over or game win? (B 0 or 1 respectively)
	bn B, 0, .gamewin
		mov #12, 0
	br .gamelose
.gamewin:
		mov #0, 0
.gamelose:
		
		; print text data
		mov #$90, 3
	call DrawTextRow
		mov #$D0, 3
	call DrawTextRow
		
		mov #%00000101, P3INT
	call ProcessKeys
ign_GameEndWaitLoop: ; //////////////////////////////////////////////////////////
	call ProcessKeys
		; waits untill the player presses a key to go back to the title or to sleep the console
		ld KeysDiff
		set1 PCON, 0
	bz ign_GameEndWaitLoop
	jmpf GameReset



;    /////////////////////////////////////////////////////////////
;   ///                      SUBROUTINES                      ///
;  /////////////////////////////////////////////////////////////





ProcessKeys:
		ld KeysCurr ; handle buttons
		st KeysLast
		ld P3
		xor #$FF
		st KeysCurr

		xor KeysLast
		and KeysCurr
		st KeysDiff

	bp SleepStatus, 0, .SleepLoop
	bp KeysDiff, 7, .EnterSleep
	ret

.EnterSleep:
		push T0CON
		push T1CNT
		push P3INT
		mov #0, VCCR
		mov #0, T0CON
		mov #0, T1CNT
		mov #%00000101, P3INT
		set1 SleepStatus, 0
		set1 PCON, 0
	br ProcessKeys

.SleepLoop:
		set1 PCON, 0
	bn KeysDiff, 7, ProcessKeys
		clr1 SleepStatus, 0
		mov #%10000000, VCCR ; write-only register so no push/pop
		pop P3INT
		pop T1CNT
		pop T0CON
	ret

;  /////////////////////////////////////////////////////////////
BlitToXRAM:
		xor ACC
		st VRMAD1
		st VRMAD2
		st XBNK
		mov #$80, 2
.loop:
		mov #12, B
.inloop:
		ld VTRBF
		st @r2
		inc 2
	dbnz B, .inloop
		
		ld 2
		add #4
		st 2
	bnz .loop
		inc XBNK
	bp XBNK, 1, .exit
		set1 2, 7
	br .loop
.exit:
	ret

;  /////////////////////////////////////////////////////////////
BlitColumn:
.loop:
		ld VTRBF
		inc VRMAD1
		st @r2
		ld 2
		add #6
		st 2
		
		ld VTRBF
		inc VRMAD1
		st @r2
		ld 2
		add #10
		st 2
		
		ld VTRBF
		inc VRMAD1
		st @r2
		ld 2
		add #6
		st 2
		
		ld VTRBF
		inc VRMAD1
		st @r2
		ld 2
		add #10
		st 2
		
	bn PSW, 7, .loop
		inc XBNK
	bp XBNK, 1, .exit
		set1 2, 7
	br .loop
	
.exit:
	ret

;  /////////////////////////////////////////////////////////////
DrawCursorRegion:
		ld cursor_temp_xbnk
		and #%00000001
		st XBNK
.loop:
		ld VTRBF
		st @r2
		ld 2
		add #6
		st 2
		
		ld VTRBF
		st @r2
		ld 2
		add #10
	dbnz C, .noclip
	br .exit
.noclip:
		st 2
	bn PSW, 7, .loop
		inc XBNK
	bp XBNK, 1, .exit
		set1 2, 7
	br .loop

.exit:
	ret

;  /////////////////////////////////////////////////////////////
DrawBCDPair:
; this should be used three times

; with BCD
; inputs: ACC = pair of numbers to render (backed up into r1)
; r2 the position
; backed up into r3
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH

		st C
		xor ACC
		mov #10, B
		div
		ld B
		st 0

		xor ACC
		mov #10, B
		div
		ld B
		st 1

		ld 2
		st 3
		inc 3
		ld 1
	call DrawDispNumber
		
		ld 3
		st 2
		ld 0
	call DrawDispNumber
	ret

;  /////////////////////////////////////////////////////////////
DrawDispNumber:
		mov #6, B
		st C
		xor ACC
		mul
		mov #3, B
.loop:
		ld C
		ldc
		inc C
		
		st @r2
		ld 2
		add #6
		st 2
		
		ld C
		ldc
		inc C
		
		st @r2
		ld 2
		add #10
		st 2
	dbnz B, .loop
	ret

;  /////////////////////////////////////////////////////////////
ClearCol:
		mov #0, XBNK
		ld 2
.loop:
		mov #0, @r2
		add #6
		st 2
		mov #0, @r2
		add #10
		st 2
	bn PSW, 7, .loop
	bp XBNK, 0, .exit
		inc XBNK
		set1 2, 7
		ld 2
	br .loop
.exit:
	ret

;  /////////////////////////////////////////////////////////////
DrawTextRow:
		mov #6, 1
.loop:
		mov #<GFX_TextData, TRL
		mov #>GFX_TextData, TRH

		ld 3
		st 2
		
		ld 0
		inc 0
		ldc
	bz .skip
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH
	call DrawDispNumber
.skip:
		inc 3
	dbnz 1, .loop
	ret

;  ///////////////////////////////////////////////////////////////
ClearScreenHalf:
		mov #$80, 2
.xclr:
		mov #12, C
		xor ACC
.xloop:
		st @r2
		inc 2
	dbnz C, .xloop
		ld 2
		add #4
		st 2
	bn PSW, 7, .xclr
	ret

;  ///////////////////////////////////////////////////////////////
SUB_LRNGGenLine:
		; made into a sub because of the height launch parameter

		; generate garbage step 1: LFSR 7
		; s>>>>xy
		; 76543210
		ld RNG_LFSR7
		ror
		xor RNG_LFSR7
		ror
		rorc
		ld RNG_LFSR7
		rorc
		st RNG_LFSR7
		
		; generate garbage step 2: LFSR 6 (backwards)
		;   xy<<<s
		; 76543210
		ld RNG_LFSR6
		rol
		xor RNG_LFSR6
		rol
		rol
		rolc
		ld RNG_LFSR6
		rolc
		st RNG_LFSR6
		
		xor RNG_LFSR7
	bnz .notzero
		mov #$AA, ACC
.notzero:
	bne #$FF, .notff
		mov #$55, ACC
.notff:
		; add both and store
		; note: LFSRs generate weird odd step sizes so the loop period is pretty big
		st VTRBF

		mov #0, VRMAD2 ; save RNG in WRAM (where the BIOS won't clear it)
		mov #$FE, VRMAD1
		ld RNG_LFSR6
		st VTRBF
		inc VRMAD1
		ld RNG_LFSR7
		st VTRBF
	ret


;  ///////////////////////////////////////////////////////////////
SUB_DrawMenuImages:
		xor ACC
		st C
		st XBNK
		mov #$80, 2
.loop:
		mov #3, B
.innerloop1:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .innerloop1
		inc 2
		inc 2
		inc 2
		mov #3, B
.innerloop2:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .innerloop2

		ld 2
		add #7
		st 2
	bn PSW, 7, .loop
	bp XBNK, 0, .done
		inc XBNK
		set1 2, 7
	br .loop
.done:
	ret


;  ///////////////////////////////////////////////////////////////
SUB_DrawMenuCursor:
		mov #$85, 2
	call ClearCol
		
		ld MenuCursor
		ror
		st cursor_temp_xbnk
		
		set1 VSEL, 4 ; autoinc on
		mov #12, VRMAD1
		mov #0, VRMAD2
		
		ld MenuCursor
		and #%00000001
		ror
		ror
		set1 ACC, 7
		add #5
		st 2
		
		mov #5, C
	call DrawCursorRegion
	ret


;  ///////////////////////////////////////////////////////////////
SUB_UpdateOnOffSetting:
	bn ACC, 4, .off
.on:
		mov #%00100000, @r2
		ld 2
		add #10
		st 2
		mov #%10100000, @r2
		ld 2
		add #6
		st 2
		mov #%01100000, @r2
		ld 2
		add #10
		st 2
		mov #%00100000, @r2
		ld 2
		add #6
		st 2
		mov #%00100000, @r2
	ret

.off:
		mov #%10110000, @r2
		ld 2
		add #10
		st 2
		mov #%00100000, @r2
		ld 2
		add #6
		st 2
		mov #%10110000, @r2
		ld 2
		add #10
		st 2
		mov #%00100000, @r2
		ld 2
		add #6
		st 2
		mov #%00100000, @r2
	ret

;  ///////////////////////////////////////////////////////////////
SUB_InitOnOffSettingGFX:
		mov #%00001001, @r2
		ld 2
		add #10
		st 2
		mov #%00010101, @r2
		ld 2
		add #6
		st 2
		mov #%00010101, @r2
		ld 2
		add #10
		st 2
		mov #%00010101, @r2
		ld 2
		add #6
		st 2
		mov #%00001001, @r2
	ret

.include "ADVM1.asm"

BGM_Header:
.word BGM_TmLine
.word BGM_PhrLst

BGM_TmLine:
.byte $00, $00
.byte $01, $00
.byte $02, $00
.byte $03, $00

.byte $02, $00
.byte $04, $00
.byte $02, $00
.byte $03, $00

.byte $02, $00
.byte $04, $00
.byte $FF, $00

BGM_PhrLst:
.word .p0
.word .p1
.word .p2
.word .p3
.word .p4


;      E0SPNWWW
.p0:
.byte %00111100, $17, 167, $00 ; E-2



.byte %00001010, $0B ; E-1

.byte %00001010, $17 ; E-2

.byte %00001100, $0B ; E-1



.byte %00001010, $17 ; E-2

.byte %00001010, $0B ; E-1

.byte %00001100, $15 ; D-2



.byte %00001010, $09 ; D-1

.byte %00001010, $15 ; D-2

.byte %00001100, $09 ; D-1



.byte %00001010, $15 ; D-2

.byte %00001010, $09 ; D-1

.byte %00001100, $13 ; C-2



.byte %00001010, $07 ; C-1

.byte %00001010, $13 ; C-2

.byte %00001100, $07 ; C-1



.byte %00001010, $13 ; C-2

.byte %00001010, $07 ; C-1

.byte %00001100, $13 ; C-2



.byte %00001100, $07 ; C-1



.byte %00001100, $13 ; C-2



.byte %10001100, $07 ; C-1



;;;;;;;;;;;;;;;
.p1:
.byte %00001100, $15 ; D-2



.byte %00001010, $09 ; D-1

.byte %00001010, $15 ; D-2

.byte %00001100, $09 ; D-1



.byte %00001010, $15 ; D-2

.byte %00001010, $09 ; D-1

.byte %00001100, $15 ; D-2



.byte %00001100, $09 ; D-1



.byte %00001100, $15 ; D-2



.byte %10001100, $09 ; D-1



;;;;;;;;;;;;;;;
.p2:
.byte %00011000, $8, $17, 167 ; E-2 i0







.byte %00011100, $23, 202 ; E-3 i1



.byte %00011010, $17, 167 ; E-2 i0

.byte %00011100, $21, 202 ; D-3 i1



.byte %00011010, $17, 167 ; E-2 i0

.byte %00011100, $20, 202 ; C#3 i1



.byte %00001100, $1C ; A-2 i1



.byte %00001100, $1E ; B-2 i1



.byte %00001100, $1F ; C-3 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $1A, 202 ; G-2 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $1F, 202 ; C-3 i1



.byte %00001100, $21 ; D-3 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %00011100, $1C, 202 ; A-2 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %10011100, $21, 202 ; D-3 i1



;;;;;;;;;;;;;;;
.p3:
.byte %00011000, $8, $17, 167 ; E-2 i0







.byte %00011100, $23, 202 ; E-3 i1



.byte %00011010, $17, 167 ; E-2 i0

.byte %00011100, $21, 202 ; D-3 i1



.byte %00011010, $17, 167 ; E-2 i0

.byte %00011100, $23, 202 ; E-3 i1



.byte %00001100, $21 ; D-3 i1



.byte %00001100, $20 ; C#3 i1



.byte %00001100, $1F ; C-3 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $23, 202 ; E-3 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $26, 202 ; G-3 i1



.byte %00001100, $25 ; F#3 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %00011100, $21, 202 ; D-3 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %10011100, $25, 202 ; F#3 i1



;;;;;;;;;;;;;;;
.p4:
.byte %00011000, $8, $13, 167 ; C-2 i0







.byte %00011100, $1F, 202 ; C-3 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $1A, 202 ; G-2 i1



.byte %00011010, $13, 167 ; C-2 i0

.byte %00011100, $1F, 202 ; C-3 i1



.byte %00001100, $13 ; C-2 i1



.byte %00001100, $1F ; C-3 i1



.byte %00001100, $21 ; D-3 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %00011100, $1C, 202 ; A-2 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %00011100, $15, 202 ; D-2 i1



.byte %00001100, $21 ; D-3 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %00011100, $1C, 202 ; A-2 i1



.byte %00011010, $15, 167 ; D-2 i0

.byte %10011100, $21, 202 ; D-3 i1



;;;;;;;;;;;;;;;
GraphicsData:
GFX_Cursor:
.byte %00011000 ; carry cursor full
.byte %00011100
.byte %00011110
.byte %00011100
.byte %00011000
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte %00011000
.byte %00111000
.byte %01111000
.byte %00111000
.byte %00011000
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte %00011000 ; carry cursor empty
.byte %00000100
.byte %00000010
.byte %00000100
.byte %00011000
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte %00011000
.byte %00100000
.byte %01000000
.byte %00100000
.byte %00011000


GFX_Numbers:
	.byte %01111100 ; 0
	.byte %10001010
	.byte %10010010
	.byte %10010010
	.byte %10100010
	.byte %01111100
	.byte %00010000 ; 1
	.byte %00110000
	.byte %01010000
	.byte %00010000
	.byte %00010000
	.byte %11111110
	.byte %01111100 ; 2
	.byte %10000010
	.byte %00000010
	.byte %00011100
	.byte %01100000
	.byte %11111110
	.byte %01111100 ; 3
	.byte %10000010
	.byte %00011100
	.byte %00000010
	.byte %10000010
	.byte %01111100
	.byte %00100100 ; 4
	.byte %01000100
	.byte %10000100
	.byte %11111110
	.byte %00000100
	.byte %00000100
	.byte %11111110 ; 5
	.byte %10000000
	.byte %11111100
	.byte %00000010
	.byte %10000010
	.byte %01111100
	.byte %00111100 ; 6
	.byte %01000000
	.byte %10000000
	.byte %11111100
	.byte %10000010
	.byte %01111100
	.byte %11111110 ; 7
	.byte %00000010
	.byte %00000100
	.byte %00001000
	.byte %00010000
	.byte %00100000
	.byte %00111100 ; 8
	.byte %01000010
	.byte %00111100
	.byte %11000010
	.byte %10000010
	.byte %01111100
	.byte %01111100 ; 9
	.byte %10000010
	.byte %01111110
	.byte %00000010
	.byte %00000100
	.byte %01111000
	.byte %00000110 ; A
	.byte %00001010
	.byte %00010010
	.byte %00111110
	.byte %01000010
	.byte %10000010
	.byte %11111100 ; B
	.byte %10000010
	.byte %11111100
	.byte %10000010
	.byte %10000010
	.byte %11111100
	.byte %01111100 ; C
	.byte %10000010
	.byte %10000000
	.byte %10000000
	.byte %10000010
	.byte %01111100
	.byte %11111000 ; D
	.byte %10000110
	.byte %10000010
	.byte %10000010
	.byte %10000110
	.byte %11111000
	.byte %11111110 ; E
	.byte %10000000
	.byte %11111000
	.byte %10000000
	.byte %10000000
	.byte %11111110
	.byte %11111110 ; F
	.byte %10000000
	.byte %11111000
	.byte %10000000
	.byte %10000000
	.byte %10000000
	.byte %11111100 ; P 10
	.byte %10000010
	.byte %10000010
	.byte %11111100
	.byte %10000000
	.byte %10000000
	.byte %10000010 ; U 11
	.byte %10000010
	.byte %10000010
	.byte %10000010
	.byte %10000010
	.byte %01111100
	.byte %01111110 ; S 12
	.byte %10000000
	.byte %01111100
	.byte %00000010
	.byte %00000010
	.byte %11111100
	.byte %10000010 ; H 13
	.byte %10000010
	.byte %11111110
	.byte %10000010
	.byte %10000010
	.byte %10000010
	.byte %01111110 ; G 14
	.byte %10000000
	.byte %10000000
	.byte %10011110
	.byte %10000010
	.byte %01111110
	.byte %10000010 ; M 15
	.byte %11000110
	.byte %10101010
	.byte %10010010
	.byte %10000010
	.byte %10000010
	.byte %01111100 ; O 16
	.byte %10000010
	.byte %10000010
	.byte %10000010
	.byte %10000010
	.byte %01111100
	.byte %10000010 ; V 17
	.byte %10000100
	.byte %10001000
	.byte %10010000
	.byte %10100000
	.byte %11000000
	.byte %11111100 ; R 18
	.byte %10000010
	.byte %10000010
	.byte %11111100
	.byte %10011000
	.byte %10000110
	.byte %10000010 ; Y 19
	.byte %01000100
	.byte %00101000
	.byte %00010000
	.byte %00100000
	.byte %11000000
	.byte %10000010 ; W 1A
	.byte %10000010
	.byte %10010010
	.byte %10101010
	.byte %11000110
	.byte %10000010
	.byte %11111110 ; I 1B
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %11111110
	.byte %11000010 ; N 1C
	.byte %10100010
	.byte %10010010
	.byte %10001010
	.byte %10000110
	.byte %10000010

GFX_TextData:
.byte $00, $19, $16, $11, $00, $00 ; -YOU--
.byte $00, $00, $1A, $1B, $1C, $00 ; --WIN-
.byte $14, $0A, $15, $0E, $00, $00 ; GAME--
.byte $00, $00, $16, $17, $0E, $18 ; --OVER
.byte $10, $11, $12, $13, $00, $0A ; PUSH-A

GFX_TitleLogo:
.byte %00011110, %00000001, %11100011, %11000000
.byte %00010010, %00000001, %00100010, %01000000
.byte %00010010, %00000001, %00100010, %01000000
.byte %00010010, %00000111, %11101110, %01110000
.byte %00010010, %00000100, %00101000, %00010000
.byte %00010011, %11100100, %00101000, %00010000
.byte %00010000, %00010111, %00101110, %01110000
.byte %00010000, %00001001, %00100010, %01000000
.byte %00010011, %11001001, %00100010, %01000000
.byte %00010010, %01001001, %00100010, %01000000
.byte %00010011, %11001111, %00111110, %01111000
.byte %00010000, %00001000, %00000110, %00001000
.byte %00010000, %00011000, %00000111, %00001000
.byte %00011111, %11111111, %11111111, %11111000
.byte %00010000, %10111100, %00100001, %11101000
.byte %00010111, %10111101, %10101101, %11101000
.byte %00010000, %10111101, %10101101, %00001000
.byte %00010111, %10111101, %10101101, %01101000
.byte %00010111, %10000100, %00100001, %00001000
.byte %00011111, %11111111, %11111111, %11111000

GFX_AuthorLogo:
.include sprite "logo_j.png" header="no"

GFX_MainMenuText:
.byte %00000000, %00000000, %00000000
.byte %01010111, %01001101, %01011100
.byte %01010100, %01010001, %01001000
.byte %01110110, %01010101, %11001000
.byte %01010100, %01010101, %01001000
.byte %01010111, %01001101, %01001000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %11001000, %10010000
.byte %00000001, %00010101, %01010000
.byte %00000001, %01010101, %11010000
.byte %00000001, %01010101, %01010000
.byte %00000000, %11001001, %01011100
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00001101, %10011101, %11011000
.byte %00010001, %01010001, %00010100
.byte %00011101, %10011001, %10010100
.byte %00000101, %00010001, %00010100
.byte %00011001, %00011101, %11011000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000

GFX_PauseMenuText:
.byte %00000000, %00000000, %00000000
.byte %00011001, %00101010, %01011000
.byte %00100010, %10101011, %01010100
.byte %00111010, %10101010, %11010100
.byte %00001010, %10101010, %01010100
.byte %00110001, %00010010, %01011000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %01001100, %10011000
.byte %00000000, %01010001, %01010100
.byte %00000000, %01010001, %01010100
.byte %00000000, %01010001, %01010100
.byte %00000000, %01001100, %10010100
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00001000, %10111010, %01010100
.byte %00001101, %10100011, %01010100
.byte %00001010, %10110010, %11010100
.byte %00001000, %10100010, %01010100
.byte %00001000, %10111010, %01001000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %01110101, %01011100
.byte %00000000, %01000101, %01001000
.byte %00000000, %01100010, %01001000
.byte %00000000, %01000101, %01001000
.byte %00000000, %01110101, %01001000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000

.cnop 0, $200

; RAM defs
KeysCurr =  $30
KeysLast =  $31
KeysDiff =  $32
KeysRepc =  $33
CursorPos = $34
LineCnt =   $35
GoalCnt =   $36
RsSpeed =   $37
RsLevel =   $28
GameTime =  $39
CarryBit =  $3A

GfxFlag =   $3B ; graphics update flags
; 7 = 
; 6 = 
; 5 = redraw indication elements
; 4 = wipe cursor
; 3 = rs indicator
; 2 = numbers
; 1 = stack
; 0 = cursor

GBeFlag =   $3C ; game behaviour flags
; 7 = 
; 6 = 
; 5 = rise line
; 4 = clear line
; 3 = time step 
; 2 = skip time
; 1 = direction
; 0 = do shift

StartHeight = $3D

RNG_LFSR7 =   $3E
RNG_LFSR6 =   $3F

MenuCursor =    $40
SoundEnable =   $41 ; 0 = off
RsSpeedIncCnt = $42
RsSpeedAcc =    $43
RsSpeedAdd =    $44
SleepStatus =   $45
HaltCount =     $46

cursor_temp_offset = $47
cursor_temp_scrpos = $48
cursor_temp_xbnk   = $49