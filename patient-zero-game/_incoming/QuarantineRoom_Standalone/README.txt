PATIENT ZERO — QUARANTINE ROOM (STANDALONE GODOT LEVEL)
======================================================

ENGINE
------
Godot 4.4.x or later; GL Compatibility renderer; GDScript; 1280 × 720 landscape.
The project is a self-contained level and does not load the Archive Room or any other level.

OPENING THE PROJECT
-------------------
1. Extract QuarantineRoom_Standalone.zip to a normal folder.
2. Open Godot 4.4 or later.
3. In Project Manager, choose Import and select project.godot from this folder.
4. Open the imported project and press F6 or F5.
5. Allow Godot to import the JPG/WAV assets on first launch.

CONTROLS
--------
- Mouse click / touch: interact with objects and buttons.
- Back button: return to the previous view.
- Escape: close the current modal, return to the previous view, or open the menu.
- H: toggle visible hotspot outlines for debugging.
- Menu: Resume, toggle hotspot outlines, toggle sound, or restart the level.
- Inventory: select Emergency Fuse, then tap the fuse socket; select Access Card, then tap the Archive Door.
- Progress saves to user://quarantine_room_save.json. Use Menu > Restart level to reset it.

PUZZLE WALKTHROUGH
------------------
1. Tap the patient bed, then tap the bracelet. Read PATIENT ID: Q-17 / DATE: 14.05 / STATUS: QUARANTINE.
2. Tap the desk/table. Inspect the three interactive patient folders:
   - Folder A / Q-17: cabinet code 042, date 14.05 (correct match).
   - Folder B / Q-09: code 186, date 11.05.
   - Folder C / Q-31: code 275, date 19.05.
3. Tap the medical supplies cabinet, then the keypad. Enter 042 (leading zero is significant).
4. In the open cabinet, collect the emergency fuse. Tap the instruction sheet to read the switch order.
5. Open the fuse box. Select Emergency Fuse in the inventory and tap the circular fuse socket.
6. Activate switches in this exact order: POWER → COOLING → SYSTEM. A wrong switch resets the sequence, but the installed fuse stays in place.
7. Open the security terminal after power has been restored. Enter 14.05 using the on-screen keypad.
8. Open the now-unlocked access-card compartment and collect the card.
9. Select Access Card in the inventory and tap the Archive Door. Tap the unlocked door again to complete the chapter.

ASSET INVENTORY
---------------
Supplied image archive (all source images retained as supplied):
- assets/backgrounds/quarantine_room.jpg — main continuous room background (1024 × 572).
- assets/closeups/bed.jpg — patient bed close-up; bracelet is visible on the bed.
- assets/closeups/bracelet.jpg — bracelet detail with Q-17, 14.05 and quarantine status.
- assets/closeups/table.jpg — table/records close-up. Three patient folders are interactive; the yellow item is treated as loose paperwork, not a fourth patient record.
- assets/closeups/q17.jpg — Folder A / correct patient Q-17, code 042, date 14.05.
- assets/closeups/q09.jpg — Folder B / patient Q-09, code 186, date 11.05.
- assets/closeups/q31.jpg — Folder C / patient Q-31, code 275, date 19.05.
- assets/closeups/code.jpg — locked Medical Supplies cabinet and keypad.
- assets/closeups/instruction.jpg — open cabinet interior; fuse and instruction sheet.
- assets/closeups/fusebox.jpg — fuse socket and POWER / COOLING / SYSTEM switch panel.
- assets/closeups/terminal.jpg — security terminal.
- assets/closeups/card.jpg — close-up of the access-card compartment/card.

Reused from the supplied Archive Room project:
- assets/audio/ambient.wav — ambient loop.
- assets/audio/click.wav — UI click sound.
- assets/audio/release.wav — confirmation/release sound.
- UI helper conventions adapted from archive_room/scripts/archive_level.gd: dark modal scrim, reusable panels/labels/buttons, transparent hoverable hotspots, top HUD, bottom inventory strip, Escape/back navigation and menu.
The Archive Room level, its scene, and its save-state autoload are not included. The Quarantine Room owns its state and save file.

IMPLEMENTATION NOTES
--------------------
- Main room remains one continuous background image. Hotspots are transparent buttons layered above it; they are not separate room art tiles.
- Close-ups use the supplied images and remain separate views in the same scene. The back stack returns to the prior view.
- The modal scrim captures clicks while a keypad, instruction sheet, pause menu, or restart confirmation is open.
- Puzzle state is saved and guarded so collected items are not duplicated and dependent progression cannot be bypassed by normal UI interaction.
- The table artwork visually includes a yellow loose-paper/folder-shaped prop in addition to the three patient folders. It is not interactive as a patient folder; the three actual patient records are blue (Q-09), green (Q-17) and tan (Q-31).
- The Archive Door completion screen is the end of this standalone level. Continue is intentionally a placeholder because the actual Archive Room/next level must not be bundled.

TESTING / LIMITATIONS
---------------------
Godot was not installed in the build environment, so the project could not be launched or tested in the Godot runtime here. No claim of an engine runtime pass is made. Before delivery, static checks were performed on the archive structure, project entry point, required asset paths, image dimensions, and script references. Please perform a first-run test in Godot 4.4.x. If an engine parser/runtime error appears, capture the complete Debugger message and line number.


UPDATE — TERMINAL AND LEVEL EXIT
--------------------------------
The terminal date keypad buttons have been repositioned to prevent overlap. A correct 14.05 submission closes the keypad and unlocks the card compartment; open it and collect the access card. Use the selected access card on the Laboratory Door, then tap the door again and choose Continue to enter the Laboratory — Final Room transition screen.
