# BitFlood
<br><p align="left"><img src="https://github.com/jvsTSX/BitFlood/blob/main/repo_images/game_logo_high_res.png?" alt="A high resolution drawing of the game's icon that appears on the BIOS' save manager" width="256" height="256"/>

A brand new game for the Dreamcast VMU, initially meant to be an entry for DreamDisc 24 but oops... The main gameplay mechanic involves carry-bitshifts, the carry itself being represented by your cursor. But be quick! The stack automatically rises periodically, don't let a non-zero row reach the top otherwise, game over.

<br><p align="left"><img src="https://github.com/jvsTSX/BitFlood/blob/main/repo_images/game_ui_annotated.png?" alt="The game's user interface with annotations" width="824" height="448"/>

## Assembling
Make sure you clone this entire repository and then run the waterbear assemble command on it, no additional requirements so far. You can get Waterbear here - https://github.com/wtetzner/waterbear
- `waterbear assemble bitflood.asm -o bitflood.vms`

## Game Controls
### Across the entire application
- **Mode Button**: Opens the pause menu, pressing it again will close the pause menu and return to wherever you were in the application. To exit the game just navigate to "Exit" and press A.
- **Sleep Button**: Suspends the system untill pressed again.

### Main and pause menues
- **D-pad Left/Right**: Edits the selected option if it holds a value.
- **D-pad Up/Down**: Selects the option.
- **B Button**: When held, it edits the upper digit of the option selected.
- **A Button**: Starts the game for the main menu. For the pause menu it acts as a confirming press when you select "Exit" or "Menu".

### In-game
- **D-pad Left/Right**: Shifts the current bit row pointed by the cursor.
- **D-pad Up/Down**: Moves the cursor around the stack.
- **B Button**: When held, it lets the cursor move around the stack quicker.
- **A Button**: Forces a new row to rise in, in case the selected game speed is too slow, also clearing the current rise count.

## Specifics
This game exclusively uses the 5KHz quartz clock across the entire application. It also contains in-game music which is uncommon if not present at all in licensed programs.
- **Size**: 9 Blocks (of 512 bytes each), or 4608 bytes
- **Current Version**: 1.0

## Emulation Support
- VM2 will play the music and SFX but most notes will be down by one octave due to the partial Timer 1 Mode 3 emulation.
- Elysian VMU won't output sound at all currently.