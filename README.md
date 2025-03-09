# BitFlood
A brand new game for the Dreamcast VMU, initially meant to be an entry for DreamDisc 24 but oops... The main gameplay mechanic involves carry-bitshifts, the carry itself being represented by your cursor. But be quick! The stack automatically rises periodically, don't let a non-zero row reach the top otherwise, game over.

## Assembling
Make sure you clone this entire repository and then run the waterbear assemble command on it, no additional requirements so far. You can get Waterbear here - https://github.com/wtetzner/waterbear
- `waterbear assemble bitflood.asm -o bitflood.vms`

## Game Controls
- **Dpad Left/Right**: Shifts the current bit row pointed by the cursor
- **Dpad Up/Down**: Moves the cursor around the stack
- **B Button**: When held, lets the cursor move around the stack quicker
- **A Button**: Forces a new row to rise in, in case the selected game speed is too slow
- **Mode Button**: Either returns to the BIOS immediately (when pressed within the title screen and main menu) or brings you to the pause menu (when pressed in-game), to exit the pause menu, tap the button again. If you wish to leave the app, move the menu cursor over to EXIT and press the A button
- **Sleep Button**: Suspends the system untill pressed again, regardless of what mode you're in

## Specifics
- **Size**: 10 Blocks (of 512 bytes each)
- **Current Version**: Dev 1

## Emulation Support
VM2 and Elysian VMU won't output the music correctly due to emulation issues with the Timer 1 Mode 3, but the game should work just fine, as it was developed and tested with EVMU.
