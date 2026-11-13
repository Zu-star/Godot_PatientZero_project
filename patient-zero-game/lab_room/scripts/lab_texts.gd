extends RefCounted

# All Laboratory texts, hints and the vault code in one place.
# lab_room.gd reads them as T.NAME. Change the strings here, not in lab_room.gd.

const VAULT_CODE := "417"

# HUD
const TITLE := "PATIENT ZERO  /  LABORATORY"
const TAP_TO_INSPECT := "Tap an object to inspect"
const BACK := "‹  Back"
const HINT := "Hint"
const MENU := "Menu"
const INVENTORY_EMPTY := "INVENTORY  —  EMPTY"

# Hotspot captions (tooltips)
const CAPTION_COAT := "Inspect the lab coat"
const CAPTION_DESK := "Inspect the desk"
const CAPTION_WHITEBOARD := "Read the whiteboard"
const CAPTION_VAULT := "Inspect the cold vault"
const CAPTION_NOTEBOOK := "Read the notebook"
const CAPTION_POCKET := "Check the chest pocket"
const CAPTION_READER := "Card reader"
const CAPTION_KEYPAD := "Keypad"
const CAPTION_VAULT_DOOR := "Vault door"
const CAPTION_VIAL := "Take the vaccine"

# Desk: research notes window
const NOTES_TITLE := "RESEARCH NOTES"
const NOTES_TEXT := "The vaccine is locked in the cold vault. To open it you need two things:\n\n1. My keycard. It is in the pocket of my lab coat.\n\n2. A 3-digit code. Read the numbers on the whiteboard in this order: RED, BLUE, GREEN."

# Coat and keycard
const FOUND_KEYCARD := "You found a keycard."
const POCKET_EMPTY := "The pocket is empty."
const KEYCARD := "Keycard"
const KEYCARD_SELECTED := "✓ Keycard selected"
const KEYCARD_USED := "Keycard ✓"
const KEYCARD_SELECTED_MESSAGE := "Keycard selected."
const KEYCARD_DESELECTED_MESSAGE := "Keycard deselected."
const KEYCARD_ALREADY_USED := "The keycard has already been used."

# Cold vault: card reader and door
const READER_NO_CARD := "The vault needs a keycard."
const READER_NOT_SELECTED := "Select the keycard in your inventory first."
const READER_ACCEPTED := "Keycard accepted. The keypad is now active."
const READER_ALREADY_ACTIVE := "The keypad is already active."
const DOOR_LOCKED := "The vault is locked. Use the card reader and the keypad."

# Cold vault: keypad window
const KEYPAD_LOCKED := "The keypad is locked. Use the keycard first."
const KEYPAD_TITLE := "COLD VAULT / KEYPAD"
const KEYPAD_SUBTITLE := "Enter the 3-digit vault code"
const KEYPAD_PROMPT := "Enter three digits"
const KEYPAD_TOO_SHORT := "Three digits are required."
const KEYPAD_WRONG := "Incorrect code. Check the notes: red, blue, green."
const KEYPAD_CLEAR := "Clear"
const KEYPAD_ENTER := "Enter"
const VAULT_OPENS := "The vault opens. The vaccine is inside."

# Vaccine
const VACCINE_TITLE := "VACCINE OBTAINED"
const CONTINUE := "Continue"

# Ending screen
const ENDING_TITLE := "CONGRATULATIONS"
const ENDING_SUBTITLE := "GAME COMPLETE"
const ENDING_TEXT := "You found the vaccine and escaped the laboratory. The outbreak can finally be stopped. Thank you for playing PATIENT ZERO."
const MAIN_MENU := "Main Menu"
const PLAY_AGAIN := "Play again"

# Menu
const MENU_TITLE := "LABORATORY"
const RESUME := "Resume"
const SHOW_HOTSPOTS := "Show hotspots"
const HIDE_HOTSPOTS := "Hide hotspots"
const SOUND_ON := "Sound: on"
const SOUND_OFF := "Sound: off"
const RESTART_LEVEL := "Restart level…"
const RESTART_QUESTION := "Restart this level?"
const CANCEL := "Cancel"
const RESTART := "Restart"
const HOTSPOTS_ON_MESSAGE := "Hotspot outlines ON"
const HOTSPOTS_OFF_MESSAGE := "Hotspot outlines OFF"

# Objective line under the title. FIND_BOTH takes the number of found items (0–2).
const OBJ_START := "Search the laboratory — start with the desk."
const OBJ_FIND_BOTH := "Find the keycard and the code (%d/2)."
const OBJ_READER := "Use the keycard on the cold vault."
const OBJ_KEYPAD := "Enter the vault code."
const OBJ_VACCINE := "Take the vaccine."
const OBJ_DONE := "Game complete"

# Hint window. Levels go in order and restart when the stage changes.
const HINT_TITLE := "LABORATORY HINT"
const MORE_HELP := "More help"
const CLOSE := "Close"
const HINTS := {
	"start": [
		"Look at the desk.",
		"The notebook on the desk explains what to do.",
		"Tap the desk, then tap the open notebook and read it.",
	],
	"card": [
		"The notebook mentions a lab coat.",
		"The keycard is in the coat pocket.",
		"Tap the coat on the left, then tap its chest pocket.",
	],
	"code": [
		"The notebook mentions a whiteboard.",
		"The code is written on the whiteboard cards.",
		"Tap the whiteboard and read the numbers: red, blue, green.",
	],
	"reader": [
		"The vault has a card reader.",
		"Tap the vault, then tap the card reader on the right.",
		"Your keycard is already selected. Tap the card reader.",
	],
	"keypad": [
		"The keypad is below the card reader.",
		"The code is the three numbers on the whiteboard: red, blue, green.",
		"Enter %s and press Enter.", # %s becomes the digits of VAULT_CODE: "4, 1, 7"
	],
	"vaccine": [
		"The vault is open.",
		"Tap the glowing vial.",
		"Tap the vial in the middle of the vault.",
	],
}
# Replaces the last "reader" hint when the keycard is not selected.
const HINT_READER_NOT_SELECTED := "Tap the Keycard button in your inventory to select it, then tap the card reader."
