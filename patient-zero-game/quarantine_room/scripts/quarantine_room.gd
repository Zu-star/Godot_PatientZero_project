extends Control

# Integration (GameFlow): emitted by "Continue" on the ending screen when a next room exists.
signal room_completed
## Standalone Patient Zero — Quarantine Room. One continuous room image with invisible hotspots.
## UI and state flow are adapted from the supplied Archive Room project's Control/button/modal conventions.

const BG_ROOM := "res://quarantine_room/assets/backgrounds/quarantine_room.jpg"
const INK := Color("241f2c")
const CREAM := Color("e4d9c3")
const MUTED := Color("b9acbd")
const PANEL := Color(0.055, 0.045, 0.075, 0.96)
const SAVE_PATH := "user://quarantine_room_save.json"
# Integration (GameFlow): shared pause menu, the same in every room.
const PZ_PAUSE_MENU := preload("res://game/ui/pz_pause_menu.gd")

const ART := {
    "bed": "res://quarantine_room/assets/closeups/bed.jpg",
    "bracelet": "res://quarantine_room/assets/closeups/bracelet.jpg",
    "table": "res://quarantine_room/assets/closeups/table.jpg",
    "folder_a": "res://quarantine_room/assets/closeups/q17.jpg",
    "folder_b": "res://quarantine_room/assets/closeups/q09.jpg",
    "folder_c": "res://quarantine_room/assets/closeups/q31.jpg",
    "cabinet": "res://quarantine_room/assets/closeups/code.jpg",
    "cabinet_inside": "res://quarantine_room/assets/closeups/instruction.jpg",
    "fusebox": "res://quarantine_room/assets/closeups/fusebox.jpg",
    "terminal": "res://quarantine_room/assets/closeups/terminal.jpg",
    "card_compartment": "res://quarantine_room/assets/closeups/card.jpg"
}

# Persistent puzzle state.
var correct_folder_inspected := false
var cabinet_unlocked := false
var fuse_collected := false
var instruction_read := false
var fuse_installed := false
var switch_sequence_progress := 0
var power_restored := false
var terminal_authenticated := false
var card_compartment_unlocked := false
var access_card_collected := false
var door_unlocked := false
var level_completed := false
var selected_item := ""
var known_clues: Array[String] = []

var current_view := "room"
var view_stack: Array[String] = []
var show_hotspots := false
var sound_enabled := true
var code_buffer := ""
var date_buffer := ""
var toast_label: Label
var view_layer: Control
var hud_layer: Control
var modal_layer: Control
var ambient_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var release_player: AudioStreamPlayer
var pause_menu: CanvasLayer  # Integration (GameFlow)

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _load_progress()
    _setup_audio()
    view_layer = Control.new()
    view_layer.name = "View"
    view_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    view_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(view_layer)
    hud_layer = Control.new()
    hud_layer.name = "HUD"
    hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hud_layer)
    toast_label = Label.new()
    toast_label.name = "InteractionFeedback"
    toast_label.position = Vector2(220, 558)
    toast_label.size = Vector2(840, 58)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 23)
    toast_label.add_theme_color_override("font_color", CREAM)
    toast_label.add_theme_stylebox_override("normal", _style(Color(0.06, 0.045, 0.08, 0.96), Color("8e7e98")))
    toast_label.visible = false
    add_child(toast_label)
    modal_layer = Control.new()
    modal_layer.name = "Modal"
    modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(modal_layer)
    show_view("room")
    # Integration (GameFlow): shared pause menu.
    pause_menu = PZ_PAUSE_MENU.new()
    add_child(pause_menu)
    pause_menu.setup({
        "get_hotspots": func(): return show_hotspots,
        "set_hotspots": func(on: bool): show_hotspots = on; _refresh_view(),
        "on_restart": _reset_progress,
    })

func _setup_audio() -> void:
    ambient_player = AudioStreamPlayer.new()
    ambient_player.name = "AmbientAudio"
    var hum := load("res://quarantine_room/assets/audio/ambient.wav") as AudioStreamWAV
    if hum:
        hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
        ambient_player.stream = hum
        ambient_player.volume_db = -20.0
        add_child(ambient_player)
        ambient_player.play()
    click_player = AudioStreamPlayer.new()
    click_player.name = "ClickAudio"
    click_player.stream = load("res://quarantine_room/assets/audio/click.wav")
    click_player.volume_db = -18.0
    add_child(click_player)
    release_player = AudioStreamPlayer.new()
    release_player.name = "ReleaseAudio"
    release_player.stream = load("res://quarantine_room/assets/audio/release.wav")
    release_player.volume_db = -14.0
    add_child(release_player)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if modal_layer.get_child_count() > 0:
                close_modal()
            elif current_view != "room":
                go_back()
            else:
                _open_pause_menu()  # Integration (GameFlow): was show_menu()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_H:
            show_hotspots = not show_hotspots
            _refresh_view()
            _toast("Hotspot outlines %s" % ("ON" if show_hotspots else "OFF"))
            get_viewport().set_input_as_handled()

func _style(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = fill
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    return s

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _panel(parent: Node, rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> Panel:
    var p := Panel.new()
    p.position = rect.position
    p.size = rect.size
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", _style(fill, border, radius))
    parent.add_child(p)
    return p

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = value
    l.position = rect.position
    l.size = rect.size
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l

func _picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
    var pic := TextureRect.new()
    pic.position = rect.position
    pic.size = rect.size
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_SCALE
    pic.texture = load(path) as Texture2D
    pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(pic)
    return pic

func _button(parent: Node, title: String, rect: Rect2, action: Callable, id: String = "", font_size: int = 21) -> Button:
    var b := Button.new()
    b.text = title
    b.position = rect.position
    b.size = rect.size
    if not id.is_empty():
        b.name = id
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", CREAM)
    b.add_theme_stylebox_override("normal", _style(Color("302a3b"), Color("8d7d98")))
    b.add_theme_stylebox_override("hover", _style(Color("494054"), Color("cab7c9")))
    b.add_theme_stylebox_override("pressed", _style(Color("66536d"), CREAM))
    b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("e2c8a1")))
    b.pressed.connect(func():
        if sound_enabled and is_instance_valid(click_player):
            click_player.play()
        action.call()
    )
    parent.add_child(b)
    return b

func _hotspot(parent: Node, rect: Rect2, action: Callable, id: String, caption: String) -> Button:
    var b := _button(parent, "", rect, action, id, 16)
    b.tooltip_text = caption
    var base_fill := Color(0.42, 0.34, 0.55, 0.12) if show_hotspots else Color(0, 0, 0, 0)
    var base_border := Color("b6a4bf") if show_hotspots else Color(0, 0, 0, 0)
    b.add_theme_stylebox_override("normal", _style(base_fill, base_border, 3))
    b.add_theme_stylebox_override("hover", _style(Color(0.58, 0.45, 0.72, 0.23), Color(0.82, 0.73, 0.9, 0.75), 3))
    b.add_theme_stylebox_override("pressed", _style(Color(0.72, 0.6, 0.82, 0.30), Color("e4d9c3"), 3))
    return b

func show_view(which: String, push_current: bool = true) -> void:
    if push_current and which != current_view:
        view_stack.append(current_view)
    close_modal()
    current_view = which
    _refresh_view()
    _update_hud()
    _save_progress()

func go_back() -> void:
    if view_stack.is_empty():
        show_view("room", false)
        return
    var previous: String = view_stack.pop_back()
    current_view = previous
    close_modal()
    _refresh_view()
    _update_hud()

func _refresh_view() -> void:
    _clear(view_layer)
    match current_view:
        "room": _build_room()
        "bed": _build_bed()
        "bracelet": _build_bracelet()
        "table": _build_table()
        "folder_a": _build_folder("A")
        "folder_b": _build_folder("B")
        "folder_c": _build_folder("C")
        "cabinet": _build_cabinet()
        "fusebox": _build_fusebox()
        "terminal": _build_terminal()
        "card_compartment": _build_card_compartment()
        "ending": _build_ending()
        "laboratory": _build_laboratory()
        _: _build_room()
    _update_hud()

func _build_room() -> void:
    _picture(view_layer, BG_ROOM, Rect2(0, 0, 1280, 720))
    # Invisible hotspots are placed over the corresponding parts of the single continuous supplied background.
    _hotspot(view_layer, Rect2(0, 390, 500, 250), func(): show_view("bed"), "PatientBed", "Examine the patient")
    _hotspot(view_layer, Rect2(270, 355, 330, 150), func(): show_view("table"), "PatientFolders", "Inspect the three patient folders")
    _hotspot(view_layer, Rect2(545, 195, 180, 305), func(): show_view("cabinet"), "MedicalCabinet", "Locked medical supplies cabinet")
    _hotspot(view_layer, Rect2(865, 260, 145, 205), func(): show_view("terminal"), "SecurityTerminal", "Security terminal")
    _hotspot(view_layer, Rect2(1030, 135, 220, 475), _use_door, "LaboratoryDoor", "Restricted Laboratory Door")
    _hotspot(view_layer, Rect2(720, 220, 160, 220), func(): show_view("fusebox"), "FuseBox", "Fuse box and three switches")
    if level_completed:
        _label(view_layer, "LABORATORY ACCESS GRANTED", Rect2(355, 92, 570, 48), 26, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)

func _build_bed() -> void:
    _picture(view_layer, ART["bed"], Rect2(0, 0, 1280, 720))
    _label(view_layer, "PATIENT BED  /  QUARANTINE WARD", Rect2(35, 88, 720, 42), 24)
    _hotspot(view_layer, Rect2(720, 245, 270, 205), func(): show_view("bracelet"), "PatientBracelet", "Inspect the patient bracelet")

func _build_bracelet() -> void:
    _picture(view_layer, ART["bracelet"], Rect2(0, 0, 1280, 720))
    _panel(view_layer, Rect2(270, 548, 740, 65), Color(0.04, 0.035, 0.055, 0.88), Color("8d7d98"))
    _label(view_layer, "PATIENT ID: Q-17     DATE: 14.05     STATUS: QUARANTINE", Rect2(285, 555, 710, 50), 24, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _hotspot(view_layer, Rect2(270, 185, 740, 350), func(): _toast("Clue recorded: Q-17, admitted 14.05, quarantine status."), "InspectBracelet", "Read bracelet details")

func _build_table() -> void:
    _picture(view_layer, ART["table"], Rect2(0, 0, 1280, 720))
    _label(view_layer, "PATIENT RECORDS  /  THREE FOLDERS", Rect2(35, 84, 760, 46), 25)
    # Supplied art has three patient folders (blue, green and tan); the yellow item between them is loose paperwork.
    _hotspot(view_layer, Rect2(205, 255, 225, 285), func(): show_view("folder_b"), "FolderB_Q09", "Folder B — Q-09")
    _hotspot(view_layer, Rect2(515, 255, 210, 285), func(): show_view("folder_a"), "FolderA_Q17", "Folder A — Q-17")
    _hotspot(view_layer, Rect2(850, 270, 225, 275), func(): show_view("folder_c"), "FolderC_Q31", "Folder C — Q-31")
    _label(view_layer, "Tap each closed folder to inspect its record.", Rect2(250, 590, 780, 38), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER)

func _build_folder(which: String) -> void:
    var key := "folder_a" if which == "A" else ("folder_b" if which == "B" else "folder_c")
    _picture(view_layer, ART[key], Rect2(0, 0, 1280, 720))
    var record := ""
    match which:
        "A":
            record = "FOLDER A — CORRECT PATIENT\nPATIENT ID: Q-17\nCABINET CODE: 042\nDATE: 14.05"
        "B":
            record = "FOLDER B — OTHER PATIENT\nPATIENT ID: Q-09\nCABINET CODE: 186\nDATE: 11.05\nThis record does not match the bracelet."
        "C":
            record = "FOLDER C — OTHER PATIENT\nPATIENT ID: Q-31\nCABINET CODE: 275\nDATE: 19.05\nThis record does not match the bracelet."
    _panel(view_layer, Rect2(300, 520, 680, 115), Color(0.035, 0.03, 0.045, 0.93), Color("8d7d98"))
    _label(view_layer, record, Rect2(325, 526, 630, 104), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _hotspot(view_layer, Rect2(170, 120, 940, 390), func(): _inspect_folder(which), "InspectFolder" + which, "Inspect this patient folder")
    _button(view_layer, "Read record", Rect2(505, 642, 270, 54), func(): _inspect_folder(which), "ReadFolder" + which, 20)

func _inspect_folder(which: String) -> void:
    if which == "A":
        correct_folder_inspected = true
        _remember_clue("Q-17 / code 042 / date 14.05")
        _save_progress()
        _toast("Correct match: Q-17. Code 042 and date 14.05 recorded.")
    elif which == "B":
        _toast("Q-09 is not the patient from the bracelet. This code is not valid for the cabinet.")
    else:
        _toast("Q-31 is not the patient from the bracelet. This code is not valid for the cabinet.")

func _build_cabinet() -> void:
    if cabinet_unlocked:
        _picture(view_layer, ART["cabinet_inside"], Rect2(0, 0, 1280, 720))
        _label(view_layer, "MEDICAL SUPPLIES  /  CABINET OPEN", Rect2(35, 82, 770, 45), 24)
        # Separate invisible targets for the fuse and the instruction sheet.
        if not fuse_collected:
            _hotspot(view_layer, Rect2(350, 285, 330, 205), _collect_fuse, "CollectEmergencyFuse", "Collect the emergency fuse")
        else:
            _panel(view_layer, Rect2(290, 390, 160, 55), Color(0.03, 0.12, 0.09, 0.9), Color("7fb99b"))
            _label(view_layer, "FUSE TAKEN", Rect2(300, 395, 140, 45), 17, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)
        _hotspot(view_layer, Rect2(620, 245, 350, 300), _read_instruction, "InstructionSheet", "Read the instruction sheet")
        _label(view_layer, "The fuse and instruction sheet can be examined independently.", Rect2(220, 590, 840, 35), 19, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    else:
        _picture(view_layer, ART["cabinet"], Rect2(0, 0, 1280, 720))
        _label(view_layer, "LOCKED MEDICAL SUPPLIES CABINET", Rect2(35, 82, 760, 45), 24)
        _hotspot(view_layer, Rect2(360, 190, 290, 330), _open_code_keypad, "CabinetKeypad", "Enter the three-digit cabinet code")
        _button(view_layer, "Enter code", Rect2(470, 604, 340, 58), _open_code_keypad, "EnterCabinetCode", 22)

func _open_code_keypad() -> void:
    code_buffer = ""
    _open_keypad_modal("CABINET ACCESS", "Enter the three-digit code found in the correct patient folder.", false)

func _open_keypad_modal(title: String, description: String, is_date: bool) -> void:
    begin_modal()
    _panel(modal_layer, Rect2(350, 38, 580, 640), Color("211b2a"), Color("9b89a5"))
    _label(modal_layer, title, Rect2(385, 52, 510, 42), 28, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _label(modal_layer, description, Rect2(395, 96, 490, 55), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
    var display_text := date_buffer if is_date else code_buffer
    var display := _label(modal_layer, display_text if not display_text.is_empty() else "—", Rect2(440, 153, 400, 52), 34, Color("c6e0d5"), HORIZONTAL_ALIGNMENT_CENTER)
    display.name = "EntryDisplay"
    # Four-column keypad. The terminal password is numeric: 1405.
    var digits := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "⌫"]
    for i in range(digits.size()):
        var col := i % 4
        var row := int(i / 4.0)
        var digit: String = digits[i]
        _button(modal_layer, digit, Rect2(390 + col * 125, 205 + row * 49, 110, 42),
            Callable(self, "_entry_key").bind(digit, is_date), "Digit" + digit.replace("⌫", "Backspace"), 20)
    _button(modal_layer, "CANCEL", Rect2(420, 420, 190, 48), close_modal, "CancelEntry", 19)
    _button(modal_layer, "CONFIRM", Rect2(630, 420, 225, 48), func(): _submit_entry(is_date), "ConfirmEntry", 20)
    _label(modal_layer, "Enter numeric password", Rect2(420, 477, 435, 32), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _entry_key(key: String, is_date: bool) -> void:
    var max_length := 4 if is_date else 3
    if key == "CLR":
        if is_date: date_buffer = ""
        else: code_buffer = ""
    elif key == "⌫":
        if is_date and not date_buffer.is_empty(): date_buffer = date_buffer.substr(0, date_buffer.length() - 1)
        elif not is_date and not code_buffer.is_empty(): code_buffer = code_buffer.substr(0, code_buffer.length() - 1)
    elif key.is_valid_int():
        if is_date and date_buffer.length() < max_length:
            date_buffer += key
        elif not is_date and code_buffer.length() < max_length:
            code_buffer += key
    var display := modal_layer.find_child("EntryDisplay", true, false) as Label
    if display:
        display.text = (date_buffer if is_date else code_buffer)
        if display.text.is_empty(): display.text = "—"

func _submit_entry(is_date: bool) -> void:
    if is_date:
        if date_buffer != "1405":
            _toast("Incorrect password. Check the Q-17 patient record.")
            date_buffer = ""
            _refresh_entry_display(true)
            return
        terminal_authenticated = true
        card_compartment_unlocked = true
        _remember_clue("Terminal authenticated with password 1405")
        _save_progress()
        close_modal()
        _toast("AUTHENTICATION ACCEPTED. Access-card compartment unlocked.")
        _refresh_view()
    else:
        if code_buffer != "042":
            _toast("Incorrect code. Check the matching Q-17 folder. The cabinet remains locked.")
            code_buffer = ""
            _refresh_entry_display(false)
            return
        cabinet_unlocked = true
        _save_progress()
        close_modal()
        _refresh_view()
        _toast("CABINET UNLOCKED. Examine the fuse and instruction sheet.")
    if sound_enabled and is_instance_valid(release_player):
        release_player.play()

func _refresh_entry_display(is_date: bool) -> void:
    var display := modal_layer.find_child("EntryDisplay", true, false) as Label
    if display:
        display.text = date_buffer if is_date else code_buffer
        if display.text.is_empty(): display.text = "—"

func _collect_fuse() -> void:
    if fuse_collected:
        _toast("The emergency fuse is already in your inventory.")
        return
    fuse_collected = true
    selected_item = "fuse"
    _save_progress()
    _refresh_view()
    _toast("Emergency fuse collected and selected. Use it on the fuse socket.")

func _read_instruction() -> void:
    instruction_read = true
    _save_progress()
    begin_modal()
    _panel(modal_layer, Rect2(235, 135, 810, 450), Color("e4d9c3"), Color("8b7b70"))
    _label(modal_layer, "EMERGENCY POWER RESTORE", Rect2(275, 160, 730, 55), 29, INK, HORIZONTAL_ALIGNMENT_CENTER)
    _label(modal_layer, "1. Insert the emergency fuse into the empty socket.\n\n2. Activate the switches in this exact order:\n\nPOWER  →  COOLING  →  SYSTEM\n\nWrong order resets the sequence. You do not lose the fuse.", Rect2(300, 225, 680, 275), 24, INK)
    _button(modal_layer, "Close", Rect2(515, 515, 250, 52), close_modal, "CloseInstructions", 21)

func _build_fusebox() -> void:
    _picture(view_layer, ART["fusebox"], Rect2(0, 0, 1280, 720))
    _label(view_layer, "EMERGENCY POWER PANEL", Rect2(35, 82, 650, 44), 24)
    # Socket target is distinct from the three switch targets.
    _hotspot(view_layer, Rect2(520, 405, 175, 150), _use_fuse_on_socket, "FuseSocket", "Insert the emergency fuse")
    if fuse_installed:
        _panel(view_layer, Rect2(558, 442, 95, 70), Color(0.05, 0.28, 0.17, 0.85), Color("8fc8a2"), 20)
        _label(view_layer, "FUSE\nIN", Rect2(563, 445, 85, 62), 17, Color("d6f0df"), HORIZONTAL_ALIGNMENT_CENTER)
    else:
        _label(view_layer, "EMPTY SOCKET", Rect2(515, 558, 190, 32), 16, Color("e5b4a2"), HORIZONTAL_ALIGNMENT_CENTER)
    # The switch plates are independently clickable. Their labels remain on the supplied image.
    _hotspot(view_layer, Rect2(830, 160, 220, 105), func(): _activate_switch(0), "SwitchPower", "POWER switch")
    _hotspot(view_layer, Rect2(830, 300, 220, 95), func(): _activate_switch(1), "SwitchCooling", "COOLING switch")
    _hotspot(view_layer, Rect2(830, 430, 220, 100), func(): _activate_switch(2), "SwitchSystem", "SYSTEM switch")
    var status := "Select the fuse in inventory, then tap the socket."
    if fuse_installed:
        status = "Fuse installed — sequence progress: %d/3" % switch_sequence_progress
    if power_restored:
        status = "POWER RESTORED"
    _panel(view_layer, Rect2(820, 575, 420, 50), Color(0.035, 0.03, 0.05, 0.92), Color("766782"))
    _label(view_layer, status, Rect2(835, 579, 390, 42), 18, Color("c3e0c0") if power_restored else CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    var indicator_rects := [Rect2(1030, 195, 25, 25), Rect2(1030, 330, 25, 25), Rect2(1030, 465, 25, 25)]
    for i in range(switch_sequence_progress):
        _panel(view_layer, indicator_rects[i], Color("4dba80"), Color("d2f0d9"), 12)

func _use_fuse_on_socket() -> void:
    if power_restored:
        _toast("The panel is already powered.")
        return
    if fuse_installed:
        _toast("The fuse is already installed. Activate POWER → COOLING → SYSTEM.")
        return
    if selected_item != "fuse" or not fuse_collected:
        _toast("The socket is empty. Select the emergency fuse in the inventory first.")
        return
    fuse_installed = true
    selected_item = ""
    switch_sequence_progress = 0
    _save_progress()
    _refresh_view()
    _toast("Fuse installed. Follow the instruction sheet: POWER → COOLING → SYSTEM.")

func _activate_switch(index: int) -> void:
    if power_restored:
        _toast("This switch is already active.")
        return
    if not fuse_installed:
        _toast("Power is unsafe to activate. Insert the emergency fuse first.")
        return
    if index == switch_sequence_progress:
        switch_sequence_progress += 1
        if switch_sequence_progress >= 3:
            power_restored = true
            switch_sequence_progress = 3
            _save_progress()
            _refresh_view()
            _toast("POWER RESTORED. The security terminal is now online.")
            if sound_enabled and is_instance_valid(release_player): release_player.play()
        else:
            _save_progress()
            _refresh_view()
            var expected := "COOLING" if switch_sequence_progress == 1 else "SYSTEM"
            _toast("Switch accepted. Next: %s." % expected)
    else:
        switch_sequence_progress = 0
        _save_progress()
        _refresh_view()
        _toast("Incorrect switch order. Sequence reset to POWER. Fuse remains installed.")

func _build_terminal() -> void:
    _picture(view_layer, ART["terminal"], Rect2(0, 0, 1280, 720))
    _label(view_layer, "SECURITY TERMINAL", Rect2(35, 82, 650, 44), 24)
    if not power_restored:
        _panel(view_layer, Rect2(390, 220, 500, 250), Color(0.015, 0.025, 0.03, 0.9), Color("5d6671"))
        _label(view_layer, "SYSTEM OFFLINE\nRestore power at the fuse box first.", Rect2(430, 265, 420, 150), 27, Color("d2aaa1"), HORIZONTAL_ALIGNMENT_CENTER)
        _hotspot(view_layer, Rect2(400, 180, 480, 300), func(): _toast("The terminal has no power. Restore power at the fuse box."), "InactiveTerminal", "Terminal is inactive")
    else:
        var status := "AUTHENTICATION ACCEPTED" if terminal_authenticated else "POWER ONLINE  /  ENTER DATE DD.MM"
        _panel(view_layer, Rect2(365, 208, 550, 265), Color(0.015, 0.04, 0.045, 0.92), Color("7ba8a1"))
        _label(view_layer, status, Rect2(395, 240, 490, 55), 23, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)
        if not terminal_authenticated:
            _button(view_layer, "Enter date  DD.MM", Rect2(465, 322, 350, 62), _open_date_keypad, "TerminalDateEntry", 22)
            _hotspot(view_layer, Rect2(450, 270, 380, 120), _open_date_keypad, "TerminalScreen", "Enter the patient admission date")
        else:
            _label(view_layer, "ACCESS-CARD COMPARTMENT UNLOCKED", Rect2(395, 310, 490, 50), 19, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
            _button(view_layer, "Open card compartment", Rect2(435, 375, 410, 60), func(): show_view("card_compartment"), "OpenCardCompartment", 21)
            _hotspot(view_layer, Rect2(320, 350, 650, 170), func(): show_view("card_compartment"), "CardCompartment", "Open the unlocked card compartment")

func _open_date_keypad() -> void:
    if not power_restored:
        _toast("Terminal offline. Restore power first.")
        return
    if terminal_authenticated:
        _toast("Terminal already authenticated. The access-card compartment is unlocked.")
        return
    date_buffer = ""
    _open_keypad_modal("SECURITY AUTHENTICATION", "Enter the four-digit password from patient Q-17.", true)

func _build_card_compartment() -> void:
    _picture(view_layer, ART["card_compartment"], Rect2(0, 0, 1280, 720))
    _label(view_layer, "ACCESS-CARD COMPARTMENT", Rect2(35, 82, 720, 44), 24)
    if not terminal_authenticated or not card_compartment_unlocked:
        _panel(view_layer, Rect2(350, 260, 580, 180), Color(0.035, 0.025, 0.04, 0.94), Color("9b89a5"))
        _label(view_layer, "COMPARTMENT LOCKED\nAuthenticate at the powered terminal first.", Rect2(390, 295, 500, 110), 25, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    elif access_card_collected:
        _panel(view_layer, Rect2(420, 505, 440, 72), Color(0.03, 0.10, 0.07, 0.93), Color("7fb99b"))
        _label(view_layer, "ACCESS CARD COLLECTED", Rect2(435, 515, 410, 52), 22, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)
    else:
        _hotspot(view_layer, Rect2(530, 285, 340, 245), _collect_access_card, "CollectAccessCard", "Collect the access card from the open compartment")
        _button(view_layer, "Collect access card", Rect2(465, 594, 350, 60), _collect_access_card, "CollectCardButton", 21)

func _collect_access_card() -> void:
    if not terminal_authenticated:
        _toast("The compartment is still locked.")
        return
    if access_card_collected:
        _toast("The access card is already in your inventory.")
        return
    access_card_collected = true
    selected_item = "access_card"
    _save_progress()
    _refresh_view()
    _toast("ACCESS CARD collected and selected. Use it on the Laboratory Door.")

func _use_door() -> void:
    if level_completed:
        show_view("ending")
        return
    if door_unlocked:
        level_completed = true
        _save_progress()
        show_view("ending")
        return
    if not access_card_collected:
        _toast("The Laboratory Door is restricted. Restore power, authenticate with 14.05, then collect the access card.")
        return
    if selected_item != "access_card":
        _toast("Select the access card in your inventory, then use it on the Laboratory Door.")
        return
    door_unlocked = true
    selected_item = ""
    _save_progress()
    _toast("ACCESS CARD ACCEPTED. The Laboratory Door is unlocked. Tap the door again to enter.")
    _refresh_view()

func _build_ending() -> void:
    _panel(view_layer, Rect2(0, 0, 1280, 720), Color("111019"))
    _panel(view_layer, Rect2(190, 115, 900, 480), Color("211b2a"), Color("a18ca9"))
    _label(view_layer, "LABORATORY ACCESS GRANTED", Rect2(245, 180, 790, 72), 36, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)
    _label(view_layer, "QUARANTINE SECURITY OVERRIDE ACCEPTED\n\nThe Laboratory door unlocks with a heavy mechanical click. The final room lies beyond.\n\nQUARANTINE ROOM COMPLETE", Rect2(280, 275, 720, 170), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _button(view_layer, "Return to room", Rect2(355, 490, 250, 62), func(): show_view("room", false), "ReturnToRoom", 21)
    _button(view_layer, "Continue", Rect2(675, 490, 250, 62), _continue_from_ending, "Continue", 21)

# Integration (GameFlow): go to the next room if one exists, otherwise show the placeholder.
func _continue_from_ending() -> void:
    if not GameFlow.ROOMS[4].is_empty():
        room_completed.emit()
    else:
        show_view("laboratory")

func _build_laboratory() -> void:
    _panel(view_layer, Rect2(0, 0, 1280, 720), Color("111019"))
    _panel(view_layer, Rect2(150, 70, 980, 580), Color("211b2a"), Color("a18ca9"))
    _label(view_layer, "LABORATORY — FINAL ROOM", Rect2(210, 115, 860, 70), 36, Color("c3e0c0"), HORIZONTAL_ALIGNMENT_CENTER)
    _label(view_layer, "The access card has opened the restricted laboratory.\n\nThe quarantine wing is behind you.\nThe final investigation begins here.", Rect2(260, 220, 760, 160), 25, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _label(view_layer, "PATIENT ZERO  /  CHAPTER 02", Rect2(300, 405, 680, 42), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
    _button(view_layer, "Back to Quarantine Room", Rect2(430, 500, 420, 60), func(): show_view("room", false), "BackToQuarantine", 20)
    # Integration (GameFlow): way out of the placeholder.
    _button(view_layer, "Main Menu", Rect2(430, 575, 420, 60), func(): GameFlow.go_to_menu(), "MainMenu", 20)

func _update_hud() -> void:
    if not is_instance_valid(hud_layer): return
    _clear(hud_layer)
    _panel(hud_layer, Rect2(0, 0, 1280, 72), Color(0.055, 0.045, 0.075, 0.93))
    _label(hud_layer, "PATIENT ZERO  /  QUARANTINE ZONE", Rect2(24, 5, 640, 30), 20)
    var objective := _objective()
    _label(hud_layer, objective, Rect2(24, 35, 870, 28), 16, MUTED)
    _button(hud_layer, "Menu", Rect2(1120, 8, 130, 54), _open_pause_menu, "Menu", 19)  # Integration (GameFlow): was show_menu
    _panel(hud_layer, Rect2(0, 640, 1280, 80), Color(0.055, 0.045, 0.075, 0.97))
    if current_view != "room" and current_view != "ending":
        _button(hud_layer, "‹  Back", Rect2(20, 650, 145, 56), go_back, "Back", 19)
    else:
        _label(hud_layer, "Tap an object to inspect", Rect2(26, 655, 330, 42), 17, MUTED)
    _label(hud_layer, "INVENTORY", Rect2(540, 651, 115, 30), 15, MUTED)
    var x := 655
    if fuse_collected:
        var fuse_title := "Fuse ✓" if fuse_installed else "Emergency Fuse"
        var fuse_button := _button(hud_layer, fuse_title, Rect2(x, 648, 210, 58), func(): _select_item("fuse"), "InventoryFuse", 17)
        if selected_item == "fuse":
            fuse_button.add_theme_stylebox_override("normal", _style(Color("655069"), Color("e3c89a")))
        x += 220
    if access_card_collected:
        var card_title := "Access Card ✓" if door_unlocked else "Access Card"
        var card_button := _button(hud_layer, card_title, Rect2(x, 648, 210, 58), func(): _select_item("access_card"), "InventoryAccessCard", 17)
        if selected_item == "access_card":
            card_button.add_theme_stylebox_override("normal", _style(Color("655069"), Color("e3c89a")))
        x += 220
    if not fuse_collected and not access_card_collected:
        _label(hud_layer, "EMPTY", Rect2(660, 651, 190, 32), 16, Color("95899f"))
    if selected_item != "":
        var selected_name := "FUSE" if selected_item == "fuse" else "ACCESS CARD"
        _label(hud_layer, "Selected: %s" % selected_name, Rect2(365, 650, 160, 48), 14, Color("d8c49e"), HORIZONTAL_ALIGNMENT_CENTER)

func _select_item(item: String) -> void:
    if item == "fuse" and (not fuse_collected or fuse_installed):
        _toast("The fuse has already been installed.")
        return
    if item == "access_card" and not access_card_collected:
        _toast("You have not collected the access card yet.")
        return
    selected_item = "" if selected_item == item else item
    _update_hud()
    if selected_item != "":
        var selected_name := "emergency fuse" if selected_item == "fuse" else "access card"
        _toast("Selected %s. Tap the relevant object to use it." % selected_name)
    else:
        _toast("Item deselected.")

func _objective() -> String:
    if level_completed: return "Chapter complete"
    if door_unlocked: return "The Laboratory Door is unlocked — tap it to enter"
    if access_card_collected: return "Select the access card and use it on the Laboratory Door"
    if terminal_authenticated: return "Collect the access card from the unlocked compartment"
    if power_restored: return "Authenticate at the security terminal using date 14.05"
    if fuse_installed: return "Activate POWER → COOLING → SYSTEM at the fuse box"
    if fuse_collected: return "Use the emergency fuse on the fuse box socket"
    if cabinet_unlocked: return "Examine the fuse and instruction sheet in the cabinet"
    if correct_folder_inspected: return "Use cabinet code 042"
    return "Find the bracelet, match patient Q-17, and inspect the folders"

func _remember_clue(clue: String) -> void:
    if not known_clues.has(clue):
        known_clues.append(clue)

func _toast(message: String) -> void:
    if not is_instance_valid(toast_label): return
    toast_label.text = message
    toast_label.visible = true
    # A short timer avoids hidden hotspots being blocked; no timer is needed for game logic.
    get_tree().create_timer(3.2).timeout.connect(func():
        if is_instance_valid(toast_label) and toast_label.text == message:
            toast_label.visible = false
    )

func begin_modal() -> void:
    _clear(modal_layer)
    modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.015, 0.035, 0.78)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    modal_layer.add_child(shade)

func close_modal() -> void:
    if not is_instance_valid(modal_layer): return
    _clear(modal_layer)
    modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast_clear()

func _toast_clear() -> void:
    if is_instance_valid(toast_label):
        toast_label.visible = false

# Integration (GameFlow): opens the shared pause menu (game/ui/pz_pause_menu.gd).
func _open_pause_menu() -> void:
    pause_menu.open()

# Integration (GameFlow): show_menu, _toggle_hotspots, _toggle_sound and _confirm_restart are
# no longer used; the shared pause menu replaces them. Kept unchanged.
func show_menu() -> void:
    begin_modal()
    _panel(modal_layer, Rect2(390, 135, 500, 450), Color("211b2a"), Color("9b89a5"))
    _label(modal_layer, "PAUSE MENU", Rect2(420, 155, 440, 48), 30, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _button(modal_layer, "Resume", Rect2(500, 220, 280, 55), close_modal, "Resume", 21)
    _button(modal_layer, "Show hotspots: " + ("ON" if show_hotspots else "OFF"), Rect2(470, 292, 340, 55), _toggle_hotspots, "ToggleHotspots", 18)
    _button(modal_layer, "Sound: " + ("ON" if sound_enabled else "OFF"), Rect2(500, 360, 280, 55), _toggle_sound, "ToggleSound", 19)
    _button(modal_layer, "Restart level", Rect2(500, 428, 280, 55), _confirm_restart, "RestartLevel", 20)
    _button(modal_layer, "Close menu", Rect2(500, 495, 280, 55), close_modal, "CloseMenu", 20)

func _toggle_hotspots() -> void:
    show_hotspots = not show_hotspots
    close_modal()
    _refresh_view()
    show_menu()

func _toggle_sound() -> void:
    sound_enabled = not sound_enabled
    if is_instance_valid(ambient_player):
        ambient_player.volume_db = -20.0 if sound_enabled else -80.0
    close_modal()
    show_menu()

func _confirm_restart() -> void:
    begin_modal()
    _panel(modal_layer, Rect2(390, 190, 500, 330), Color("211b2a"), Color("9b89a5"))
    _label(modal_layer, "Restart this level?", Rect2(425, 220, 430, 60), 28, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _label(modal_layer, "All Quarantine Room puzzle progress will reset.", Rect2(430, 285, 420, 55), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
    _button(modal_layer, "Cancel", Rect2(435, 390, 170, 58), show_menu, "CancelRestart", 20)
    _button(modal_layer, "Restart", Rect2(635, 390, 200, 58), _reset_progress, "ConfirmRestart", 20)

func _reset_progress() -> void:
    correct_folder_inspected = false
    cabinet_unlocked = false
    fuse_collected = false
    instruction_read = false
    fuse_installed = false
    switch_sequence_progress = 0
    power_restored = false
    terminal_authenticated = false
    card_compartment_unlocked = false
    access_card_collected = false
    door_unlocked = false
    level_completed = false
    selected_item = ""
    known_clues.clear()
    view_stack.clear()
    _save_progress()
    close_modal()
    show_view("room", false)
    _toast("Level progress reset.")

func _save_progress() -> void:
    var data := {
        "version": 1,
        "correct_folder_inspected": correct_folder_inspected,
        "cabinet_unlocked": cabinet_unlocked,
        "fuse_collected": fuse_collected,
        "instruction_read": instruction_read,
        "fuse_installed": fuse_installed,
        "switch_sequence_progress": switch_sequence_progress,
        "power_restored": power_restored,
        "terminal_authenticated": terminal_authenticated,
        "card_compartment_unlocked": card_compartment_unlocked,
        "access_card_collected": access_card_collected,
        "door_unlocked": door_unlocked,
        "level_completed": level_completed,
        "known_clues": known_clues
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
        return
    correct_folder_inspected = bool(parsed.get("correct_folder_inspected", false))
    cabinet_unlocked = bool(parsed.get("cabinet_unlocked", false))
    fuse_collected = bool(parsed.get("fuse_collected", false))
    instruction_read = bool(parsed.get("instruction_read", false))
    fuse_installed = bool(parsed.get("fuse_installed", false))
    switch_sequence_progress = clampi(int(parsed.get("switch_sequence_progress", 0)), 0, 3)
    power_restored = bool(parsed.get("power_restored", false))
    terminal_authenticated = bool(parsed.get("terminal_authenticated", false)) and power_restored
    card_compartment_unlocked = bool(parsed.get("card_compartment_unlocked", false)) and terminal_authenticated
    access_card_collected = bool(parsed.get("access_card_collected", false)) and card_compartment_unlocked
    door_unlocked = bool(parsed.get("door_unlocked", false)) and access_card_collected
    level_completed = bool(parsed.get("level_completed", false)) and door_unlocked
    var clues = parsed.get("known_clues", [])
    if clues is Array:
        for clue in clues:
            known_clues.append(str(clue))
    if power_restored:
        fuse_installed = true
    if fuse_installed:
        fuse_collected = true
