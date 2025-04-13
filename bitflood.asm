.include "sfr.i"

	.org 0   ; entry point
	jmpf Start
	.org $03 ; External int. (INT0)                 - I01CR
	reti
	.org $0B ; External int. (INT1)                 - I01CR
	reti
	.org $13 ; External int. (INT2) and Timer 0 low - I23CR and T0CON
	clr1 T0CON, 1
	jmp INT_GameTimeAndSound

	.org $1B ; External int. (INT3) and base timer  - I23CR and BTCR		
		clr1 BTCR, 3
		clr1 BTCR, 1
	jmp INT_BaseTimerFire

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

INT_BaseTimerFire: ; /////////////////////////////////////////////
		push IE ; disable interrupts during the process, specially since RAM banks are changed and stuff
		mov #%00000011, IE
		push PSW
		push ACC
		push B
	call TickRTC
		pop B
		pop ACC
		pop PSW
		pop IE
	reti

INT_GameTimeAndSound: ; //////////////////////////////////////////
		push PSW
		push ACC

		; first handle the game rise timer
		ld RsSpeedAcc
		add RsSpeedAdd
		st RsSpeedAcc
	bn PSW, 7, .No_Ov
		set1 GBeFlag, 3
.No_Ov:

		; then sound if enabled
	bp SoundEnable, 4, .Call_ADVM1
		pop ACC
		pop PSW
	reti

.Call_ADVM1:
		push TRL
		push TRH
		push B
		push C
	call _ADVM1_SFX
	call _ADVM1_RUN_MUSIC
;		mov #%01010000, T1CNT ; ONLY UNCOMMENT WHEN ASSEMBLING FOR EVMU TESTING
		pop C
		pop B
		pop TRH
		pop TRL
		pop ACC
		pop PSW
	reti

;    /////////////////////////////////////////////////////////////

.include "sound_bytecode.asm"

.org $1F0 ; exit
Exit_BIOS:
		not1 EXT, 0
	jmpf Exit_BIOS

.org $200
.string 16 "BitFlood"
.string 32 "By https://github.com/jvsTSX"

.org $240
.include icon "bitflood_icon.gif"

;    /////////////////////////////////////////////////////////////
;   ///                  INITIALIZING STUFF                   ///
;  /////////////////////////////////////////////////////////////
Start:
		mov #%00000011, IE   ; make sure that INT1 and 0 are not NMIs
		mov #%00000010, IP   ; only BTCR gets high priority to avoid fucking up anything
		mov #%10100011, OCR  ; quartz clock, /6, RC and CF stopped

		mov #0, T1CNT         ; shut up the T1 in case the BIOS didn't
		mov #%10000000, P1FCR ; configure sound output
		mov #%10000000, P1DDR
		mov #0, P1

		mov #%10000000, VCCR  ; make sure the XRAM is unlocked, usually it is but just in case

		mov #0, T0CON         ; stop and setup timer 0 values
		mov #$FC, T0PRR
		mov #$BB, T0LR

		mov #0, InputFlags    ; for the key handler, pretend no keys have been pressed last
		mov #0, P3INT         ; key interrupts off

		; setup SFX base address
		mov #<SFX_Data, A1RH_SFXListL
		mov #>SFX_Data, A1RH_SFXListH

		; show my logo when entering the app from the BIOS
		mov #<GFX_AuthorLogo, TRL
		mov #>GFX_AuthorLogo, TRH
		mov #0, XBNK
		mov #$80, 2
		mov #0, C

		; copy the logo to the XRAM
.Outter:
	mov #12, B
.Inner:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .Inner
		ld 2
		add #4
		st 2
	bn PSW, 7, .Outter
	bp XBNK, 0, .Done
		inc XBNK
		set1 2, 7
	br .Outter
.Done:

		; wait for a while
		mov #0, B
		mov #10, C
.Logo_Wait:
	dbnz B, .Logo_Wait
	dbnz C, .Logo_Wait

		; clear WRAM
		mov #252, C
		set1 VSEL, 4 ; autoinc on
		xor ACC
		st VRMAD2
		st VRMAD1
.Clear_Loop:
		st VTRBF
	dbnz C, .Clear_Loop

; those four untouched bytes holds the LFSR RNG state and a garbage-check pair (must be 0 then FF for it to be valid)
; these precise values are choosen because SRAM initial state is not exactly random, it's sort of a corrupted alternating pattern
; so unlikely to get all-zero followed by all-one, if not impossible
; pretty much why you shouldn't rely on initial RAM values for RNG seeding, some machines are actually deterministic (such as game boy color)

		mov #0, VRMAD2
		mov #$FC, VRMAD1
		ld VTRBF
	bnz .Init_RNG
		ld VTRBF
		inc ACC
	bnz .Init_RNG ; FF + 1 = 0, therefore if not zero then it's initial garbage
	br .No_Init_RNG

.Init_RNG:
		mov #$FC, VRMAD1
		xor ACC
		st VTRBF
		dec ACC  ; = $FF
		st VTRBF
		st VTRBF
		st VTRBF
.No_Init_RNG:

		; initialize WRAM with the cursor icons
		mov #29+6, B
		mov #3, VRMAD1
		mov #0, VRMAD2
		mov #0, C
		mov #<GFX_Cursor, TRL
		mov #>GFX_Cursor, TRH
.Blit_Cursor:
		ld C
		inc C
		ldc
		st VTRBF
	dbnz B, .Blit_Cursor

		; default settings
		mov #10, GoalCnt
		mov #%00010000, SoundEnable



;    /////////////////////////////////////////////////////////////
;   ///                     TITLE SCREEN                      ///
;  /////////////////////////////////////////////////////////////
GameReset:
		mov #0, T1CNT ; stop timers
		mov #0, T0CON
		mov #%10000011, IE ; interrupts on, no highest priority
		mov #32, HaltCount
		mov #1, GFXFlag ; request redraw
	call SUB_ClearScreen
	call SUB_ProcessKeys ; to nullify any held keys
TitleLoop:
	call SUB_ProcessKeys

	bn GFXFlag, 0, .No_Graphics_Update
		clr1 GFXFlag, 0

		mov #$C0, 3
		mov #24, 0
	call SUB_DrawTextRow

		mov #<GFX_TitleLogo, TRL ; and the logo part
		mov #>GFX_TitleLogo, TRH
		mov #0, C
		mov #$91, 2
		mov #0, XBNK
		mov #20, 0

.Outter:
		mov #4, B
.Inner:		
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .Inner
		
		ld 2
		add #2
	bn 0, 0, .Even_Line
		add #4
.Even_Line:
		st 2
	dbnz 0, .Keep_Going
	br .Done
.Keep_Going:
	bn PSW, 7, .Outter
		inc XBNK
		set1 2, 7
	br .Outter
.Done:

.No_Graphics_Update:
		mov #%00000101, P3INT
		set1 PCON, 0
		mov #0, P3INT
	bn KeysDiff, 4, TitleLoop



;    /////////////////////////////////////////////////////////////
;   ///                        MAIN MENU                      ///
;  /////////////////////////////////////////////////////////////
	call SUB_ClearScreen
		mov #%00101111, GFXFlag
		mov #0, MenuCursor

	call SUB_ProcessKeys ; to nullify any held keys
MainMenuLoop:
	call SUB_ProcessKeys
	bn KeysDiff, 0, .No_Up_Key
		set1 GFXFlag, 0
		ld MenuCursor
	bnz .Inc_Cursor
		mov #2, MenuCursor
	br .No_Up_Key
.Inc_Cursor:
		dec MenuCursor
.No_Up_Key:

	bn KeysDiff, 1, .No_Down_Key
		set1 GFXFlag, 0
		ld MenuCursor
	bne #2, .Dec_Cursor
		mov #0, MenuCursor
	br .No_Down_Key
.Dec_Cursor:
		inc MenuCursor
.No_Down_Key:

		mov #0, B
	bn KeysDiff, 2, .No_Left_Key
		mov #00000010, B
.No_Left_Key:

	bn KeysDiff, 3, .No_Right_Key
		mov #00000011, B
.No_Right_Key:

		mov #1, 0
		mov #12, VRMAD1
	bn KeysCurr, 5, .No_B_Key
		mov #10, 0
		mov #32, VRMAD1
.No_B_Key

		ld KeysCurr
		xor KeysLast
	bn ACC, 5, .No_Cursor_Change
		set1 GFXFlag, 0
.No_Cursor_Change:

		; process setting based on current cursor position and pressed keys
	bn B, 1, .No_Edit
		ld MenuCursor
		and #%00000011
	bz .Edit_Height
	be #1, .Edit_Goal
		; default: edit speed
		set1 GFXFlag, 3
		mov #RsSpeed, 1
		mov #9, C
	br .Edit_Val

.Edit_Height:
		set1 GFXFlag, 1
		mov #StartHeight, 1
		mov #32, C
	br .Edit_Val

.Edit_Goal:
		set1 GFXFlag, 2	
		mov #GoalCnt, 1
		mov #99, C ; max value

.Edit_Val:
	bp B, 0, .Inc_Val
		ld @r1
	bz .No_Edit
		sub 0
	bn PSW, 7, .No_UFlow
		xor ACC
.No_UFlow:
		st @r1
	br .No_Edit

.Inc_Val:
		ld @r1
	be C, .No_Edit
	bn PSW, 7, .No_Edit ; in case it's greater than
		add 0
	be C, .No_OFlow
	bp PSW, 7, .No_OFlow
		ld C
.No_OFlow:
		st @r1
.No_Edit:

	; draw any of the settings if the GFX flag is set (reused from main loop)
	; 5 - menu texts
	; 3 - speed
	; 2 - goal
	; 1 - height
	; 0 - draw cursor

	bn GFXFlag, 0, .Cursor_Done
		clr1 GFXFlag, 0

	call SUB_DrawMenuCursor
.Cursor_Done:

	bn GFXFlag, 1, .Draw_Height_Done ; draw height setting
		mov #0, XBNK
		mov #$83, 2
		ld StartHeight
	call SUB_DrawBCDPair
		clr1 GFXFlag, 1
.Draw_Height_Done:

	bn GFXFlag, 2, .Draw_Goal_Done ; draw goal setting
		mov #0, XBNK
		mov #$C3, 2
		ld GoalCnt
	call SUB_DrawBCDPair
		clr1 GFXFlag, 2
.Draw_Goal_Done:

	bn GFXFlag, 3, .Draw_Speed_Done ; draw speed setting
		mov #1, XBNK
		mov #$84, 2
		ld RsSpeed
		and #%00001111
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH
	call SUB_DrawDispNumber
		clr1 GFXFlag, 3
.Draw_Speed_Done:

	bn GFXFlag, 5, .No_Menu_Text_Redraw ; draw indication texts
		clr1 GFXFlag, 5
		mov #3, 3
		mov #<GFX_MainMenuText, TRL
		mov #>GFX_MainMenuText, TRH
	call SUB_DrawMenuImages
.No_Menu_Text_Redraw:

	bp KeysDiff, 4, IGN_Launch ; enter game once A is pressed
	dbnz HaltCount, .No_Halt   ; or else loop a few times and halt if nothing is pressed
		mov #%00000101, P3INT
		set1 PCON, 0
		mov #%0, P3INT
		mov #32, HaltCount
.No_Halt:
	jmp MainMenuLoop



;    /////////////////////////////////////////////////////////////
;   ///                   LAUNCH GAME LOOP                    ///
;  /////////////////////////////////////////////////////////////
IGN_Launch:
	call SUB_ClearScreen

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
.Clear_Loop:
		st VTRBF
	dbnz B, .Clear_Loop

		mov #1, VRMAD2
		clr1 VSEL, 4 ; autoinc off

		; init important variables
		mov #8, RsLevel
		mov #0, LineCnt
		mov #10, RsSpeedIncCnt
		mov #16, CursorPos ; cursor around the middle of the screen
		mov #%00101111, GFXFlag ; full refresh
		mov #%00000000, GBeFlag ; no behaviour
		mov #0, CarryBit

		; generate garbage according to height's level
		ld StartHeight
	bz .Clean_Stack
		clr1 VSEL, 4 ; no autoinc
		mov #32, ACC
		sub StartHeight
		st C
		ld StartHeight
		st B
.Garbage_Loop:
		mov #1, VRMAD2
		ld C
		st VRMAD1
	call SUB_LRNGGenLine
		inc C
	dbnz B, .Garbage_Loop
.Clean_Stack:

		mov #<BGM_Header, TRL ; setup background music
		mov #>BGM_Header, TRH
	call _ADVM1_SETUP

		ld RsSpeed ; in-game initial speed
		inc ACC
		rol
		rol
		st RsSpeedAdd
		mov #%01000001, T0CON ; start timer 0



;    /////////////////////////////////////////////////////////////
;   ///                    IN-GAME LOOP                       ///
;  /////////////////////////////////////////////////////////////
IGN_Loop:
	call SUB_ProcessKeys

IGN_HandleInputs: ; ///////////////////////////////////////// handle key presses
		mov #1, 0
	bn KeysCurr, 5, .No_B_Key
		mov #8, 0
		set1 GFXFlag, 4
.No_B_Key:

	bn KeysDiff, 0, .No_Up_Key
		ld CursorPos
		sub 0
	bp PSW, 7, .Clip_Up
		and #%00011111
		st CursorPos
		set1 GFXFlag, 0 ; update cursor
	br .No_Up_Key
.Clip_Up:
		mov #0, CursorPos
		set1 GFXFlag, 0
.No_Up_Key:

	bn KeysDiff, 1, .No_Down_Key
		ld CursorPos
		or #%11100000
		add 0
	bp PSW, 7, .Clip_Down
		and #%00011111
		st CursorPos
		set1 GFXFlag, 0 ; update cursor
	br .No_Down_Key
.Clip_Down:
		mov #31, CursorPos
		set1 GFXFlag, 0
.No_Down_Key:

	bn KeysDiff, 2, .No_Left_Key
		set1 GBeFlag, 0 ; update line
		set1 GBeFlag, 1 ; shift it left
		set1 GFXFlag, 0 ; update cursor
.No_Left_Key:

	bn KeysDiff, 3, .No_Right_Key
		set1 GBeFlag, 0 ; update line
		clr1 GBeFlag, 1 ; shift it right
		set1 GFXFlag, 0 ; udpate cursor
.No_Right_Key:

	bn KeysDiff, 4, .No_A_Key
		set1 GBeFlag, 3
		set1 GBeFlag, 2 ; reset time and force new line
.No_A_Key:

IGN_ShiftLine: ; //////////////////////////////////////////// shift selected line
	bn GBeFlag, 0, .No_Shift_Line
		mov #1, VRMAD2
		ld CursorPos
		st VRMAD1
		clr1 VSEL, 4 ; autoinc off

	bn GBeFlag, 1, .Right
		; or else left
		ld CarryBit
		rorc
		ld VTRBF
		rolc
		st VTRBF
		xor ACC
		rolc
		st CarryBit
	br .Done

.Right:
		ld CarryBit
		rorc
		ld VTRBF
		rorc
		st VTRBF
		xor ACC
		rolc
		st CarryBit
.Done:
		; update graphics on-screen to match the stack entry
		ld CursorPos
		rol
		rol
		rol
		rol
		st B ; get MSB to select bank
		ror
		set1 ACC, 7
		clr1 ACC, 3
	bn CursorPos, 0, .Even_Line
		add #6
.Even_Line:

		add #2
		st 2
		ld B
		and #%00000001
		st XBNK
		ld VTRBF
		st @r2
	bne #$FF, .Shift_Done
		set1 GBeFlag, 4
.Shift_Done:
		clr1 GBeFlag, 0
.No_Shift_Line:

IGN_ClearLine: ; //////////////////////////////////////////// clear a line from the field
	bn GBeFlag, 4, .No_Clear_Line
		mov #$00, A1R_SFXReq
	dbnz RsSpeedIncCnt, .No_Speed_Inc ; increase speed every 10 lines cleared
		mov #10, RsSpeedIncCnt
		ld RsSpeedAdd
	be #%00101000, .No_Speed_Inc
		add #%00000100
		st RsSpeedAdd
.No_Speed_Inc:

		; NOTE TO SELF: 0 IS TOP NOT BOTTOM
		ld CursorPos
		add #1
		st B	
		ld CursorPos
		sub #1
		st C
		clr1 VSEL, 4 ; autoinc off

.Loop:
		ld C
		st VRMAD1
		sub #1
		st C
		ld VTRBF
		inc VRMAD1
		st VTRBF
	dbnz B, .Loop

		mov #0, VTRBF ; check if the player cleared enough lines
		inc LineCnt
		ld LineCnt
	be GoalCnt, .Dummy
.Dummy:
	bp PSW, 7, .Continue_Ingame
		mov #0, GBeFlag
	jmp IGN_GameEnd

.Continue_Ingame:
		set1 GFXFlag, 2
		set1 GFXFlag, 1 ; update screen
		clr1 GBeFlag, 4
.No_Clear_Line:

IGN_StepTime: ; ///////////////////////////////////////////// step time
	bn GBeFlag, 3, .No_Time_Step
		clr1 GBeFlag, 3
		set1 GFXFlag, 3
	bn GBeFlag, 2, .Normal_Step
		; resets Rs counter if A (button) is pressed
		clr1 GBeFlag, 2
		mov #0, RsSpeedAcc
	br .Do_Step
		
.Normal_Step:
	dbnz RsLevel, .No_Time_Step
.Do_Step:
		mov #8, RsLevel
		set1 GBeFlag, 5
.No_Time_Step:

IGN_RiseStack: ; //////////////////////////////////////////// rise stack
	bn GBeFlag, 5, .Stack_Done
		clr1 GBeFlag, 5
		clr1 VSEL, 4 ; no increment
		mov #0, VRMAD1
		mov #1, VRMAD2

		mov #34, A1R_SFXReq

		; move stack
		mov #31, ACC
		st VRMAD1
		set1 GFXFlag, 1 ; refresh screen

		xor ACC
		mov #32, C
.Check_Hole:
	be VTRBF, .Hole_Found
		dec VRMAD1
	dbnz C, .Check_Hole
.Hole_Found:

		ld C
	bz .No_Inc_Cursor          ; is the cursor at exactly 0 (stack top)?, if so don't move
	be CursorPos, .Rise_Cursor ; is it at the rising line? if so yes, move the cursor
	bn PSW, 7, .No_Inc_Cursor  ; if not, is it above the rising line? BE sets carry to 1 if it's lesser than (strictly, not equal), if so don't move if it's cleared (greater/above line)
.Rise_Cursor:
		set1 GFXFlag, 0 ; update cursor graphics
		dec CursorPos
.No_Inc_Cursor:

		mov #32, ACC
		sub C
	bz .No_Raise
	be #32, .Game_Lose
		st C

		; rise cursor?
.Raise_Stack:
		inc VRMAD1
		ld VTRBF
		dec VRMAD1
		st VTRBF
		inc VRMAD1
	dbnz C, .Raise_Stack

	br .No_Raise
.Game_Lose:
	mov #1, GBeFlag
	jmp IGN_GameEnd
.No_Raise:
	call SUB_LRNGGenLine
.Stack_Done:

IGN_RiseIndicator: ; //////////////////////////////////////// rise indicator
	bn GFXFlag, 3, .Skip_Rs_Ind
		mov #1, XBNK
		mov #$FF, B
		ld RsLevel
		st C
		mov #%10000001, ACC

		dbnz C, .Rs_Ind_7
		ld B
.Rs_Ind_7:
		st $1CB
		dbnz C, .Rs_Ind_6
		ld B
.Rs_Ind_6:
		st $1D5
		dbnz C, .Rs_Ind_5
		ld B
.Rs_Ind_5:
		st $1DB
		dbnz C, .Rs_Ind_4
		ld B
.Rs_Ind_4:
		st $1E5
		dbnz C, .Rs_Ind_3
		ld B
.Rs_Ind_3:
		st $1EB
		dbnz C, .Rs_Ind_2
		ld B
.Rs_Ind_2:
		st $1F5
		dbnz C, .Rs_Ind_1
		ld B
.Rs_Ind_1:
		st $1FB
		clr1 GFXFlag, 3
.Skip_Rs_Ind:

IGN_DrawCursor: ; /////////////////////////////////////////// draw cursor
	bn GFXFlag, 0, .No_Cursor_Update
	bn GFXFlag, 4, .No_Clear
		clr1 GFXFlag, 4
		mov #$81, 2
	call SUB_ClearCol
		mov #$83, 2
	call SUB_ClearCol
.No_Clear:

		; check which bit state is it
		ld CarryBit
		rorc
		xor ACC
		st VRMAD2
	bp PSW, 7, .Empty_Cursor
		add #20
.Empty_Cursor:
		st VRMAD1

		; offset the cursor, clipping it if underflows
		set1 VSEL, 4
		ld CursorPos
		clr1 ACC, 0
		sub #4
	bn PSW, 7, .No_UFlow

		st B
		xor ACC
		st 0 ; XRAM bank value
		sub B
		st 1 ; start offset
		xor ACC
	br .Cursor_Clipped
.No_UFlow:
		mov #0, 1 ; start offset
		rol ; --BIIIS-
		rol ; -BIIIS--
		rol ; BIIIS---
		rol ; IIIS---B
		st 0 ; XRAM bank value
		ror
.Cursor_Clipped:
		set1 ACC, 7
		st 3 ; source position

		inc ACC
		st 2
		mov #10, ACC
		sub 1 ; start offset
		ror
		st C
		ld VRMAD1
		add 1 ; start offset
		st VRMAD1

	bp CursorPos, 0, .No_Inc
		inc VRMAD1
.No_Inc:

	call SUB_DrawCursorRegion
		
		ld C
		rol
		add VRMAD1
		st VRMAD1

		ld 3 ; source position
		add #3
		st 2
		mov #10, ACC
		sub 1 ; start offset
		ror
		st C
		ld VRMAD1
		add 1 ; start offset
		st VRMAD1
	call SUB_DrawCursorRegion
		
		clr1 GFXFlag, 0
.No_Cursor_Update:

IGN_DrawBitfield: ; ///////////////////////////////////////// draw bitfield
	bn GFXFlag, 1, .No_Bitfield_Update
		clr1 GFXFlag, 1
		mov #1, VRMAD2
		mov #0, VRMAD1
		set1 VSEL, 4
		mov #0, XBNK
		mov #$82, 2
.Loop:
		ld VTRBF
		st @r2
		ld 2
		add #6
		st 2

		ld VTRBF
		st @r2
		ld 2
		add #10
		st 2

		ld VTRBF
		st @r2
		ld 2
		add #6
		st 2

		ld VTRBF
		st @r2
		ld 2
		add #10
		st 2

	bn PSW, 7, .Loop
		inc XBNK
	bp XBNK, 1, .Exit
		set1 2, 7
	br .loop	
.Exit:
.No_Bitfield_Update:

	bn GFXFlag, 2, .No_Disp_Numbers ; /////////////////////// line clear number
		mov #0, XBNK
		mov #$A4, 2
		ld LineCnt
	call SUB_DrawBCDPair
		clr1 GFXFlag, 2
.No_Disp_Numbers:

	bn GFXFlag, 5, .No_Ind_Elements ; /////////////////////// fixed display elements (for re/init purposes)
		clr1 GFXFlag, 5
		; draw the LCLR text
		mov #0, XBNK
		mov #%10000110, $184
		mov #%10000110, $185
		mov #%10001000, $18A
		mov #%10001000, $18B
		mov #%11100110, $194
		mov #%11101000, $195
		
		; draw the rise indicator text
		inc XBNK
		mov #%11000000, $1DA
		mov #%10100110, $1E4
		mov #%11001100, $1EA
		mov #%10100010, $1F4
		mov #%10101110, $1FA
.No_Ind_Elements:

	jmp IGN_Loop ; to avoid any input latency, the CPU runs haltless in-game, hopefully not a big deal since it's always on the 5KHz clock



;    /////////////////////////////////////////////////////////////
;   ///                    GAME END LOOP                      ///
;  /////////////////////////////////////////////////////////////

IGN_GameEnd:
		mov #1, GFXFlag
		mov #0, RsSpeedAdd
	call SUB_ClearScreen

	call SUB_ProcessKeys
IGN_GameEndWaitLoop: ; //////////////////////////////////////////////////////////

	bn GFXFlag, 0, .No_Redraw
		clr1 GFXFlag, 0

		; draw the decoration lines
		mov #0, XBNK
		mov #$FF, ACC
		mov #$A6, 2
.Deco_Lines:
		mov #2, C
.Outter
		mov #6, B
.Inner:
		st @r2
		inc 2
	dbnz B, .Inner
		xch 2
		add #10
		xch 2
	dbnz C, .Outter
		inc XBNK
		mov #$C0, 2
	bp XBNK, 0, .Deco_Lines

		; game over or game win? (game flags 0 or 1 respectively)
	bn GBeFlag, 0, .Game_Win
		mov #12, 0
	br .Game_Lose
.Game_Win:
		mov #0, 0
		mov #12, A1R_SFXReq
	br .Continue
.Game_Lose:
		mov #26, A1R_SFXReq
.Continue:

		; print text data
		mov #0, XBNK
		mov #$C6, 3
	call SUB_DrawTextRow
		inc XBNK
		mov #$86, 3
	call SUB_DrawTextRow
.No_Redraw:

	call SUB_ProcessKeys

		; waits untill the player presses a key to go back to the title or to sleep the console
		mov #%00000101, P3INT
		set1 PCON, 0
		mov #0, P3INT
		ld KeysDiff
		and #%00111111 ; removes the menu and sleep keys because they're handled elsewhere
	bz ign_GameEndWaitLoop
	jmpf GameReset



;    /////////////////////////////////////////////////////////////
;   ///                      SUBROUTINES                      ///
;  /////////////////////////////////////////////////////////////
SUB_ProcessKeys:
		ld KeysCurr ; handle buttons
		st KeysLast
		ld P3
		xor #$FF
		st KeysCurr
		xor KeysLast
		and KeysCurr
		st KeysDiff

	bp InputFlags, 0, .Sleep_Loop
	bp KeysDiff, 7, .Enter_Sleep
	bp InputFlags, 1, .Pause_Menu_Loop
	bp KeysDiff, 6, .Pause_Menu_Begin
	ret

.Enter_Sleep:
		push T0CON
		push T1CNT
		push P3INT
		mov #0, VCCR ; shut down LCD first
		mov #0, MCR  ; then disable the refresh
		mov #0, T0CON
		mov #0, T1CNT
		mov #%00000101, P3INT
		set1 InputFlags, 0
		set1 PCON, 0
	br SUB_ProcessKeys

.Sleep_Loop:
		set1 PCON, 0
	bn KeysDiff, 7, SUB_ProcessKeys
		clr1 InputFlags, 0
		mov #%00001001, MCR  ; turn on refresh first (BIOS default = $09)
		mov #%10000000, VCCR ; then turn it back on  (BIOS default = $80)
		pop P3INT
		pop T1CNT
		pop T0CON
	br SUB_ProcessKeys

.Pause_Menu_Begin:
		set1 InputFlags, 1
		push P3INT
		mov #0, P3INT
		push RsSpeedAdd ; disable the next line rise counter but keep the timer on for the music
		mov #0, RsSpeedAdd
	call SUB_ClearScreen

		; draw the indication texts
		mov #4, 3
		mov #<GFX_PauseMenuText, TRL
		mov #>GFX_PauseMenuText, TRH
	call SUB_DrawMenuImages	

		; draw the dashes after the MENU and EXIT options
		mov #1, XBNK
		mov #%00011110, $199
		mov #%00011110, $1D9
		mov #%11110000, $19A
		mov #%11110000, $1DA

		; draw the first half of the on/off settings for the first two options
		mov #0, XBNK
		mov #$89, 2
	call SUB_InitOnOffSettingGFX
		mov #$C9, 2
	call SUB_InitOnOffSettingGFX

		mov #%00000111, GFXFlag
		mov #0, MenuCursor	
	jmp SUB_ProcessKeys

.Pause_Menu_Loop:
		; handle key presses
	bn KeysDiff, 0, .No_Up_Key
		dec MenuCursor
		ld MenuCursor
		and #%00000011
		st MenuCursor
		set1 GFXFlag, 0
.No_Up_Key:

	bn KeysDiff, 1, .No_Down_Key
		inc MenuCursor
		ld MenuCursor
		and #%00000011
		st MenuCursor
		set1 GFXFlag, 0
.No_Down_Key:

		ld KeysDiff
		and #%00001100 ; change setting if either or both keys are pressed
	bz .No_Edit
	bp MenuCursor, 0, .Edit_Icon
		not1 SoundEnable, 4
		set1 GFXFlag, 1
	br .No_Edit
.Edit_Icon:
		mov #2, XBNK
		not1 $182, 4
		set1 GFXFlag, 2
.No_Edit:

	bn KeysDiff, 4, .No_A_Key
	bn MenuCursor, 1, .No_A_Key
	bp MenuCursor, 0, .Exit_App
		clr1 InputFlags, 1
		mov #%00000011, IE
		pop RsSpeedAdd
		pop P3INT
		pop ACC ; remove return address
		pop ACC
	jmpf GameReset
.Exit_App:
	jmpf Exit_BIOS
.No_A_Key:

	; handle graphics updates
	bn GFXFlag, 0, .No_Cursor ; draw cursor
		clr1 GFXFlag, 0
		mov #12, VRMAD1
	call SUB_DrawMenuCursor
.No_Cursor:

	bn GFXFlag, 1, .No_Sound ; draw sound setting
		clr1 GFXFlag, 1
		ld SoundEnable
		mov #0, XBNK
		mov #$8A, 2
	call SUB_UpdateOnOffSetting
	bp SoundEnable, 4, .No_Sound
		mov #0, T1CNT
.No_Sound:

	bn GFXFlag, 2, .No_Icon ; draw icon setting
		clr1 GFXFlag, 2
		mov #2, XBNK
		ld $182
		mov #0, XBNK
		mov #$CA, 2
	call SUB_UpdateOnOffSetting
.No_Icon:

		; half CPU if nothing happens after a while
	dbnz HaltCount, .No_Halt
		mov #%00000101, P3INT
		set1 PCON, 0
		mov #0, P3INT
		mov #32, HaltCount
.No_Halt:

		; go back to the game if Mode is pressed again
	bp KeysDiff, 6, .Exit_Pause
	jmp SUB_ProcessKeys
.Exit_Pause:
		clr1 InputFlags, 1
		mov #%00101111, GFXFlag
		pop RsSpeedAdd
		pop P3INT
	call SUB_ClearScreen
	jmp SUB_ProcessKeys



;  /////////////////////////////////////////////////////////////
SUB_DrawCursorRegion:
		ld 0 ; XRAM bank value
		and #%00000001
		st XBNK
.Loop:
		ld VTRBF
		st @r2
		ld 2
		add #6
		st 2
		
		ld VTRBF
		st @r2
		ld 2
		add #10
	dbnz C, .No_Clip
	br .Exit
.No_Clip:
		st 2
	bn PSW, 7, .Loop
		inc XBNK
	bp XBNK, 1, .Exit
		set1 2, 7
	br .Loop

.Exit:
	ret



;  /////////////////////////////////////////////////////////////
SUB_DrawBCDPair:
; this should be used three times

; with BCD
; inputs: ACC = pair of numbers to render (backed up into r1)
; r2 the position
; backed up into r3
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH

		st C ; get decimal 1's position
		xor ACC
		mov #10, B
		div
		ld B
		st 0

		xor ACC ; get decimal 10's position
		mov #10, B
		div
		ld B
		st 1

		; ACC holds 100's position, but this game doesn't need it

		ld 2
		st 3
		inc 3
		ld 1
	call SUB_DrawDispNumber
		
		ld 3
		st 2
		ld 0
	call SUB_DrawDispNumber
	ret



;  /////////////////////////////////////////////////////////////
SUB_DrawDispNumber:
		mov #6, B
		st C
		xor ACC
		mul
		mov #6, B
.Loop:
		ld C
		inc C
		ldc
		st @r2
		ld 2
	bp 2, 3, .Odd
	bn 2, 2, .Even
	bn 2, 1, .Even
.Odd:
		add #4
.Even:
		add #6
		st 2
	dbnz B, .Loop
	ret



;  /////////////////////////////////////////////////////////////
SUB_ClearCol:
		mov #0, XBNK
		ld 2
.Loop:
		mov #0, @r2
		add #6
		st 2
		mov #0, @r2
		add #10
		st 2
		mov #0, @r2
		add #6
		st 2
		mov #0, @r2
		add #10
		st 2
	bn PSW, 7, .Loop
	bp XBNK, 0, .Exit
		inc XBNK
		set1 2, 7
		ld 2
	br .Loop
.Exit:
	ret



;  /////////////////////////////////////////////////////////////
SUB_DrawTextRow:
		mov #6, 1
.Loop:
		mov #<GFX_TextData, TRL
		mov #>GFX_TextData, TRH

		ld 3
		st 2
		
		ld 0
		inc 0
		ldc
	bz .Skip
		mov #<GFX_Numbers, TRL
		mov #>GFX_Numbers, TRH
	call SUB_DrawDispNumber
.Skip:
		inc 3
	dbnz 1, .Loop
	ret



;  ///////////////////////////////////////////////////////////////
SUB_ClearScreen:
		mov #0, XBNK
		mov #$80, 2
.Outter:
		mov #12, C
		xor ACC
.Inner:
		st @r2
		inc 2
	dbnz C, .Inner
		ld 2
		add #4
		st 2
	bn PSW, 7, .Outter
	bp XBNK, 0, .Done
		inc XBNK
		set1 2, 7
	br .Outter
.Done:
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
	bnz .Not_Zero
		mov #$AA, ACC
.Not_Zero:
	bne #$FF, .Not_All_Ones
		mov #$55, ACC
.Not_All_Ones:
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
		mov #$86, 2
		mov #3, B
.Outter:
		mov #5, 1
.Inner:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .Inner
		ld 2
	bn 1, 0, .Even_Line
		add #4
.Even_Line:
		add #3
		st 2
		mov #3, B
	dbnz 1, .Inner

		add #22
		st 2
	bn PSW, 7, .No_Carry
		set1 2, 7
		inc XBNK
.No_Carry:

	dbnz 3, .Outter
	ret



;  ///////////////////////////////////////////////////////////////
SUB_DrawMenuCursor:
		mov #$85, 2
	call SUB_ClearCol

		ld MenuCursor
		ror
		st 0         ; XRAM bank value
		set1 VSEL, 4 ; autoinc on
		mov #0, VRMAD2

		ld MenuCursor
		and #%00000001
		ror
		ror
		set1 ACC, 7
		add #5
		st 2

		mov #5, C
	call SUB_DrawCursorRegion
	ret



;  ///////////////////////////////////////////////////////////////
SUB_UpdateOnOffSetting:
	bn ACC, 4, .Off
; or else on
		mov #%00100000, @r2
		ld 2
		add #10
		st 2
		mov #%10100000, @r2
		add #6
		st 2
		mov #%01100000, @r2
		add #10
		st 2
		mov #%00100000, @r2
		add #6
		st 2
		mov #%00100000, @r2
	ret

.Off:
		mov #%10110000, @r2
		ld 2
		add #10
		st 2
		mov #%00100000, @r2
		add #6
		st 2
		mov #%10110000, @r2
		add #10
		st 2
		mov #%00100000, @r2
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
		add #6
		st 2
		mov #%00010101, @r2
		add #10
		st 2
		mov #%00010101, @r2
		add #6
		st 2
		mov #%00001001, @r2
	ret



;  ///////////////////////////////////////////////////////////////

; Free RTC! feel free to rip this right off if you don't want to use the BIOS stuff
; just increments the RTC, no other checks involved
; check the caller to see which SFRs you should push before calling it

BIOS_YEAR_MSB  = $17
BIOS_YEAR_LSB  = $18
BIOS_MONTH     = $19
BIOS_DAY       = $1A
BIOS_HOUR      = $1B
BIOS_MIN       = $1C
BIOS_SEC       = $1D
BIOS_HALFSEC   = $1E
BIOS_LEAP_YEAR = $1F

TickRTC:
		clr1 PSW, 1
		not1 BIOS_HALFSEC, 0
	bn BIOS_HALFSEC, 0, .Done

		; seconds
		inc BIOS_SEC
		ld BIOS_SEC
	bne #60, .Done
		mov #0, BIOS_SEC

		; minutes
		inc BIOS_MIN
		ld BIOS_MIN
	bne #60, .Done
		mov #0, BIOS_MIN

		; hours
		inc BIOS_HOUR
		ld BIOS_HOUR
	bne #24, .Done
		mov #0, BIOS_HOUR

		; days
		inc BIOS_DAY
		ld BIOS_MONTH
	be #2, .Month_Not_Feb
		mov #29, B
	bn BIOS_LEAP_YEAR, 0, .Next_Day ; check if feb has 29 days
		inc B
	br .Next_Day

.Month_Not_Feb:
		mov #31, B
	bn ACC, 3, .Month_No_Invert
		not1 ACC, 0
.Month_No_Invert:
	bn ACC, 0, .Month_30_Days
		inc B
.Month_30_Days:
.Next_Day:

		ld BIOS_DAY
	bne B, .Done
		mov #1, BIOS_DAY

		; months
		inc BIOS_MONTH
		ld BIOS_MONTH
	bne #13, .Done
		mov #1, BIOS_MONTH

		; years
		inc BIOS_YEAR_LSB
		ld BIOS_YEAR_LSB
	bnz .Calc_Leap
		inc BIOS_YEAR_MSB
	br .Calc_Leap

.Done:
	ret



.Calc_Leap:
		push C
		ld BIOS_YEAR_LSB
		and #%00000011
	bnz .Not_Leap

		set1 BIOS_LEAP_YEAR, 0
		ld BIOS_YEAR_LSB
		st C
		ld BIOS_YEAR_MSB
		mov #100, B
		div
		ld B
	bnz .Leap_Done

		ld C
		and #%00000011
	bz .Leap_Done
		; or else not leap year
.Not_Leap:
		mov #0, BIOS_LEAP_YEAR
.Leap_Done:
		pop C
	br .Done


.include "ADVM1.asm"
.include "misc_gfx.asm"

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

GFXFlag =   $3B ; graphics update flags
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
InputFlags =    $45
HaltCount =     $46
