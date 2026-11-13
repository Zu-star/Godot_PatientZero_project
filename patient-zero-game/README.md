# MT2404 Patient Zero

Godot 4.7.2 mobile horror puzzle prototype.

## Run
1. Open `project.godot` in Godot 4.7.2.
2. Press F5 to run from the splash screen.

## Room flow
- Room 1 is the playable timed puzzle room.
- The Room 2 / Isolation Ward screen is a styled transition/checkpoint screen with **NEXT ROOM** and **MAIN MENU** actions.
- As this prototype currently has only one playable room, **NEXT ROOM** loops to Room 1 for replay/testing. Replace `NEXT_PLAYABLE_SCENE` in `scripts/room_2.gd` once a dedicated Room 2 gameplay scene is added.

## Audio
The project includes menu/lab ambience, normalized looping zombie ambience, computer beep, timer tick, correct-answer, key pickup, door opening, UI click, and zombie attack/lose audio.
