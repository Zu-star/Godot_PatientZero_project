FIRST ROOM — PATIENT ZERO (Godot 4)

OPENING / MENU
- Uses the splash-screen artwork and cinematic main-menu background from MT2404_Patient_Zero8.
- Splash displays for 2.5 seconds.
- Main menu fills the screen and contains BEGIN SURVIVAL and HOW TO PLAY; there is no QUIT button.
- HOW TO PLAY is a text-only aged-paper instruction panel.
- BEGIN SURVIVAL starts this FIRST ROOM gameplay.

GAMEPLAY
- Room title: INITIAL TASK.
- Click the computer to open the multiple-choice task. The task has a close button and its own visible timer/attempts display.
- A separate MENU button is available during gameplay and while the computer task is open. Press Escape to open/close the pause menu.
- Pause menu options: RESUME, START AGAIN, GO TO MAIN MENU.
- Correct answer: C (28). Click OK to collect the key, then drag the transparent PNG key onto the door.
- When the door opens, the attached purple archive/storage room artwork is visible through the doorway.
- MOVE TO THE NEXT ROOM opens that room as the next full-screen area.
- If time reaches zero or all 3 attempts are used, the Game Over screen appears.

SOUND
- Includes the three supplied sounds (ambient.wav, click.wav, release.wav) and sound effects from MT2404_Patient_Zero8.
- Ambient audio loops; UI clicks, computer beep, correct answer, key pickup, door opening, timer ticks, and zombie attack have sound effects.

RUN
1. Extract this ZIP.
2. Open FIRST ROOM/project.godot in Godot 4.2 or newer.
3. Press F6/F5 or Run Project.

This is the Godot source project, not a standalone executable. Runtime validation requires Godot.

LATEST REQUESTED FIXES
- Splash screen now uses the exact splash background and serif title treatment from MT2404_Patient_Zero8, fading in/out over about 3 seconds.
- Main menu panel height reduced to remove the unused blank area below its two buttons.
- Initial Task HUD menu button moved to the far upper-right; timer and attempts were reflowed to avoid overlap.
- MOVE TO THE NEXT ROOM button has no scene-transition action.

VERIFIED REQUESTED CHANGES (STATIC CHECK)
- Splash uses the exact splash_icon_art.png asset from MT2404_Patient_Zero8.zip and matching source title/shading/fade behavior.
- Main menu panel compacted and the gap between the two buttons reduced.
- Initial Task Menu button uses top-right viewport anchors with 12 px top and 14 px right margins.
- MOVE TO THE NEXT ROOM has no pressed signal; the unused room-transition function was removed.
- Runtime verification requires Godot; this environment does not have the Godot executable installed.

TIMER UPDATE
- The gameplay timer is set to 35 seconds and resets to 00:35 when the room is restarted.

DOOR OPEN DISPLAY UPDATE
- Successful key use plays the door sound and switches to the open-door background showing the next room behind it.
- Removed the 'THE DOOR OPENED' overlay and the 'MOVE TO THE NEXT ROOM' button. No room navigation occurs.
