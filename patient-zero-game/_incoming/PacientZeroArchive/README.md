# Pacient Zero — Archive Room

A playable single-level Godot project based on the approved room, shelf and desk artwork. Built and tested in **Godot 4.4.1**, using GDScript and the Compatibility renderer. Intended for a landscape mobile game; mouse input also works. This is source, not an APK or an iOS build.

## Open and play

1. Extract the complete ZIP to a folder on your computer.
2. Open Godot 4.4 or later. Choose **Import**, select `project.godot`, then **Import & Edit**.
3. Allow Godot to import textures. Press **F6** with `archive_room/scenes/ArchiveLevel.tscn` open, or **F5** to run the project.
4. Tap/click the left shelves, desk, or quarantine door. On desktop, Escape closes documents or returns to the room.

Menu → Show hotspots makes interactive areas visible. Hint gives progressive help. Progress saves automatically. Menu → Restart requires confirmation and resets only this level's progress.

## Included interactions

- Room overview with approved wooden floor, purple-grey palette and woman's framed photograph.
- Shelf close-up with four independent label textures and native text; tap two labels to swap. Swaps animate.
- Rolled note tucked beside the first box, opening a readable filing-rules overlay.
- Correctly labelled Transfers box reveals the personnel folder and chained access kit together.
- Three browsable agent profiles: two women and one man. The correct woman's face is cropped directly from the approved desk image.
- Four-digit lock with touch keypad, clear button, incomplete/wrong-code feedback, and no attempt limit.
- Layered lockbox: body, lid, chain links, padlock, card. Unlocking removes the chains and animates the lid.
- Access card must be collected and selected in inventory before using the reader.
- Quarantine door unlocks; a second tap enters the next level or shows the standalone completion screen.
- Desk portrait inspection; laptop message **“It’s broken.”**; atmospheric responses for papers and slide case.
- Quiet synthesised electrical ambience and interaction sounds; sound toggle in Menu.

The background room's small archive labels are decorative. The zoom scene's label text reflects the current puzzle state. The other rooms, title menu, vaccine and Patient Zero encounter are intentionally outside this level.

## Files and editing

| Path | Purpose |
| --- | --- |
| `archive_room/scenes/ArchiveLevel.tscn` | Main reusable level; select its root to set Next Level Scene |
| `archive_room/scripts/archive_level.gd` | Views, hotspots, document panels, keypad, sound and touch input |
| `archive_room/scripts/session.gd` | Puzzle state, code, progression guards and JSON save/load |
| `archive_room/assets/room.png`, `desk.png` | Approved overview and table artwork |
| `archive_room/assets/shelf_base.png` | Clean shelf layer without embedded label text |
| `archive_room/assets/label_0.png` … `label_3.png` | Separate cropped plates; words are native Godot text |
| `archive_room/assets/rolled_note.png` | Cropped note with transparent polygon mask |
| `archive_room/assets/agent_elena.png` | Correct portrait cropped from the table artwork |
| `archive_room/assets/box_*.svg`, `padlock.svg`, `card.svg` | Editable independent vector props |
| `tests/` | Reproducible playthrough/input tests and rendered screenshots |

The scene builds named Control nodes at runtime. In the editor they are not all visible before running; use the **Remote** tree while playing to inspect `View`, `HUD`, `Modal`, `ArchiveLabel0`, `ChainedBox`, and other named nodes. Interaction regions are Rect2 values in `build_room`, `build_desk`, and `build_shelves`; change those functions when moving objects. Visuals that never move stay on background layers; label plates, note, lockbox layers, documents, and inventory are independent.

To change names, IDs or assignments, edit `AGENTS` in `archive_level.gd`. Change `BOX_CODE` in `session.gd` at the same time. Change `INITIAL` / `SOLUTION` and `show_rules()` together if revising the shelf puzzle. All readable clues and interface text are native Labels rather than baked image text.

## Connect to the team's existing Godot project

1. Copy the entire **`archive_room`** directory into the existing project's root, preserving that folder name.
2. Project → Project Settings → Globals/Autoload: add `res://archive_room/scripts/session.gd` as **ArchiveSession**. Enable it.
3. Open `archive_room/scenes/ArchiveLevel.tscn`. Select root `ArchiveLevel`, and set **Next Level Scene** in the Inspector to the teammate's quarantine `.tscn`.
4. Configure base viewport **1280 × 720**, stretch mode **canvas_items**, aspect **keep**, orientation **landscape**. The standalone project already has these settings.
5. Set **Input Devices → Pointing → Emulate Mouse From Touch = Off**. This scene explicitly bridges the first finger's touch events to GUI mouse events; OS emulation would cause duplicate taps. Leave Emulate Touch From Mouse off as well.
6. Enter this level with `get_tree().change_scene_to_file("res://archive_room/scenes/ArchiveLevel.tscn")`.

Alternatively, leave Next Level Scene empty and connect the root's `quarantine_entered` signal to your level manager. Avoid using both transition mechanisms simultaneously. The completion signal emits once; loaded completed saves still permit entering the configured next scene.

Progress is stored in `user://archive_save.json` with validation. Export the root or integrate with your team's own save system through `ArchiveSession`. No network services or plugins are required.

## Mobile export and device check

Godot's Android/iOS export templates and platform SDKs must be installed on your own computer. Android additionally needs JDK/Android SDK configuration; iOS export needs macOS and Xcode. This ZIP intentionally contains no signing credentials, APK, IPA or fabricated device-test result.

Base layout is 1280 × 720 with aspect-preserving scaling and letterboxing, including on wider phones. Main tap areas are 60+ logical pixels; labels are larger and tapped rather than dragged. Only one finger is used. Run a device pass for your smallest supported phone, cutouts, physical Back behavior, audio interruptions, and suspend/resume before shipping. Escape is supported in the desktop build; physical Android Back is not specially mapped.

Official export guides: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html and https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html

## Verification

From the project folder, using your Godot executable:

```sh
godot --headless --editor --import --quit
godot --headless res://tests/Playthrough.tscn
godot --headless res://tests/InputSmoke.tscn
```

The playthrough checks puzzle gates, label swapping, browsing records, incorrect and correct codes, single card pickup, inventory selection, door transition, one-time completion signal, save/load and reset. The input smoke test dispatches actual GUI pointer events and a first-finger touch press/release. Rendered screenshots were captured in Godot's Compatibility renderer using a virtual display. These tests do not replace physical Android/iOS testing.

To refresh screenshots on a computer with a display:

```sh
godot --path . res://tests/Playthrough.tscn -- --capture
```

See `SPOILERS.md` for the exact solution and `ASSET_NOTES.md` for asset provenance and limitations.
