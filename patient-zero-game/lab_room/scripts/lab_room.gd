extends Control

# Patient Zero — Laboratory (room 4, the last room). Everything is built in code.
# Layout, HUD, menu and hints follow the Archive Room; the view stack and Escape/H keys follow the Quarantine Room.
# State lives only in memory: the room starts from scratch on every entry.
# room_completed is emitted once when the ending screen appears. GameFlow has no room 5, so it stays here.
signal room_completed

const T := preload("res://lab_room/scripts/lab_texts.gd")
# Integration (GameFlow): shared pause menu, the same in every room.
const PZ_PAUSE_MENU := preload("res://game/ui/pz_pause_menu.gd")
const ASSETS := "res://lab_room/assets/"
const ART := {
	"room": "backgrounds/lab_room.png",
	"ending": "backgrounds/ending.png",
	"desk": "closeups/closeup_desk.png",
	"coat": "closeups/closeup_coat.png",
	"whiteboard": "closeups/closeup_whiteboard.png",
	"vault": "closeups/closeup_vault.png",
	"vault_open": "closeups/closeup_vault_open.png",
	"keycard_icon": "icons/keycard_icon.png",
	"vaccine_icon": "icons/vaccine_icon.png",
}
# Centres of the three empty white squares on the whiteboard close-up: red, blue, green.
const CODE_CENTERS := [Vector2(465, 360), Vector2(692, 365), Vector2(883, 369)]
const FULL := Rect2(0, 0, 1280, 720)
const INK := Color("241f2c")
const CREAM := Color("e4d9c3")
const OBJECTIVE_COLOR := Color("c0b0c9")
const FOOTER_COLOR := Color("b4a6bd")
const EMPTY_COLOR := Color("95899f")
const WINDOW_FILL := Color("302737")
const WINDOW_BORDER := Color("9c8aa7")

# Puzzle state.
var notebook_read := false
var has_keycard := false
var card_selected := false
var code_seen := false
var keypad_unlocked := false
var vault_open := false
var has_vaccine := false
var finished := false

var current_view := "room"
var view_stack: Array[String] = []
var show_hotspots := false
var sound_enabled := true
var hint_step := 0
var hint_stage := ""
var entered_code := ""
var code_display: Label
var lock_feedback: Label
var busy := false
var completed_emitted := false
var view_layer: Control
var hud_layer: Control
var modal_layer: Control
var fade_rect: ColorRect
var toast_label: Label
var toast_timer: Timer
var ambient_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var release_player: AudioStreamPlayer
var pause_menu: CanvasLayer  # Integration (GameFlow)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_audio()
	view_layer = _layer("View")
	hud_layer = _layer("HUD")
	modal_layer = _layer("Modal")
	toast_label = _label(self, "", Rect2(235, 557, 810, 66), 23, CREAM, true)
	toast_label.name = "InteractionText"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(Color(0.08, 0.06, 0.11, 0.95), Color("8e7e98")))
	toast_label.visible = false
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 4.0
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	add_child(toast_timer)
	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	show_view("room", false)
	# Integration (GameFlow): shared pause menu.
	pause_menu = PZ_PAUSE_MENU.new()
	add_child(pause_menu)
	pause_menu.setup({
		"get_hotspots": func(): return show_hotspots,
		"set_hotspots": func(on: bool): show_hotspots = on; _refresh_view(),
		"on_restart": _restart_level,
	})

func _setup_audio() -> void:
	# ambient.wav loops through its import settings (edit/loop_mode=2).
	ambient_player = _audio("AmbientAudio", "ambient.wav", -15.0)
	click_player = _audio("ClickAudio", "click.wav", -17.0)
	release_player = _audio("ReleaseAudio", "release.wav", -12.0)
	ambient_player.play()

func _audio(id: String, file: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = id
	player.stream = load(ASSETS + "audio/" + file) as AudioStream
	player.volume_db = volume
	add_child(player)
	return player

func _play(player: AudioStreamPlayer) -> void:
	if sound_enabled and is_instance_valid(player):
		player.play()

func _exit_tree() -> void:
	for player in [ambient_player, click_player, release_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

# --- Building blocks -------------------------------------------------------

func _layer(id: String) -> Control:
	var c := Control.new()
	c.name = id
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _style(fill: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s

func _panel(parent: Node, rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(fill, border))
	parent.add_child(p)
	return p

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 24, color: Color = CREAM, wrapped: bool = false) -> Label:
	var l := Label.new()
	# Wrapping is set before the size, otherwise a long line widens the label first.
	if wrapped:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# Missing art is replaced by a labelled placeholder and reported as "MISSING ART: <file>".
func _art_exists(file: String) -> bool:
	if ResourceLoader.exists(ASSETS + file):
		return true
	print("MISSING ART: " + file)
	return false

func _picture(parent: Node, file: String, rect: Rect2) -> Control:
	var path := ASSETS + file
	if not _art_exists(file):
		var stub := ColorRect.new()
		stub.color = Color("1d1824")
		stub.position = rect.position
		stub.size = rect.size
		stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(stub)
		var caption := _label(stub, "MISSING ART\n" + file, Rect2(Vector2.ZERO, rect.size), 24, FOOTER_COLOR)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return stub
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = load(path) as Texture2D
	t.position = rect.position
	t.size = rect.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _button(parent: Node, title: String, rect: Rect2, action: Callable, id: String = "") -> Button:
	var b := Button.new()
	b.text = title
	if not id.is_empty():
		b.name = id
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _style(Color("302a3b"), Color("8d7d98")))
	b.add_theme_stylebox_override("hover", _style(Color("494054"), Color("cab7c9")))
	b.add_theme_stylebox_override("pressed", _style(Color("66536d"), CREAM))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("e2c8a1")))
	b.pressed.connect(func():
		if busy:
			return
		_play(click_player)
		action.call()
	)
	parent.add_child(b)
	return b

func _hotspot(parent: Node, rect: Rect2, action: Callable, id: String, caption: String) -> Button:
	var b := _button(parent, "", rect, action, id)
	b.tooltip_text = caption
	b.focus_mode = Control.FOCUS_NONE
	var base_fill := Color(0.42, 0.34, 0.55, 0.12) if show_hotspots else Color(0, 0, 0, 0)
	var base_border := Color("b6a4bf") if show_hotspots else Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", _style(base_fill, base_border, 3))
	b.add_theme_stylebox_override("hover", _style(Color(0.58, 0.45, 0.72, 0.23), Color(0.82, 0.73, 0.9, 0.75), 3))
	b.add_theme_stylebox_override("pressed", _style(Color(0.72, 0.6, 0.82, 0.30), CREAM, 3))
	return b

# --- Views -----------------------------------------------------------------

func show_view(which: String, push_current: bool = true) -> void:
	if push_current and which != current_view:
		view_stack.append(current_view)
	current_view = which
	close_modal()
	_refresh_view()

func go_back() -> void:
	current_view = "room"
	if not view_stack.is_empty():
		current_view = view_stack.pop_back()
	close_modal()
	_refresh_view()

func _refresh_view() -> void:
	_clear(view_layer)
	match current_view:
		"desk": _build_desk()
		"coat": _build_coat()
		"whiteboard": _build_whiteboard()
		"vault": _build_vault()
		"ending": _build_ending()
		_: _build_room()
	_update_hud()

func _build_room() -> void:
	_picture(view_layer, ART["room"], FULL)
	_hotspot(view_layer, Rect2(53, 223, 147, 327), func(): show_view("coat"), "LabCoat", T.CAPTION_COAT)
	_hotspot(view_layer, Rect2(227, 320, 336, 307), func(): show_view("desk"), "Desk", T.CAPTION_DESK)
	# Added after the desk so the whiteboard wins where the two areas overlap.
	_hotspot(view_layer, Rect2(523, 205, 297, 243), func(): show_view("whiteboard"), "Whiteboard", T.CAPTION_WHITEBOARD)
	_hotspot(view_layer, Rect2(847, 137, 410, 476), func(): show_view("vault"), "ColdVault", T.CAPTION_VAULT)

func _build_desk() -> void:
	_picture(view_layer, ART["desk"], FULL)
	_hotspot(view_layer, Rect2(200, 273, 893, 347), show_notes, "Notebook", T.CAPTION_NOTEBOOK)

func _build_coat() -> void:
	_picture(view_layer, ART["coat"], FULL)
	_hotspot(view_layer, Rect2(667, 410, 130, 190), _search_pocket, "ChestPocket", T.CAPTION_POCKET)

# Opening this view is enough to see the code.
func _build_whiteboard() -> void:
	code_seen = true
	_picture(view_layer, ART["whiteboard"], FULL)
	var digit_font := FontVariation.new()
	digit_font.base_font = ThemeDB.fallback_font
	digit_font.variation_embolden = 1.2
	for i in range(CODE_CENTERS.size()):
		var center: Vector2 = CODE_CENTERS[i]
		var digit := _label(view_layer, T.VAULT_CODE[i], Rect2(center - Vector2(60, 60), Vector2(120, 120)), 76, INK)
		digit.name = "CodeDigit%d" % i
		digit.add_theme_font_override("font", digit_font)
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func show_notes() -> void:
	notebook_read = true
	_update_hud()
	begin_modal()
	_panel(modal_layer, Rect2(200, 110, 880, 500), WINDOW_FILL, WINDOW_BORDER)
	_label(modal_layer, T.NOTES_TITLE, Rect2(240, 135, 800, 49), 31)
	_label(modal_layer, T.NOTES_TEXT, Rect2(240, 200, 800, 300), 24, CREAM, true)
	_button(modal_layer, T.CLOSE, Rect2(520, 520, 240, 64), close_modal, "Close")

func _search_pocket() -> void:
	if has_keycard:
		say(T.POCKET_EMPTY)
		return
	has_keycard = true
	card_selected = true
	_update_hud()
	say(T.FOUND_KEYCARD)

func _select_card() -> void:
	if keypad_unlocked:
		say(T.KEYCARD_ALREADY_USED)
		return
	card_selected = not card_selected
	_update_hud()
	say(T.KEYCARD_SELECTED_MESSAGE if card_selected else T.KEYCARD_DESELECTED_MESSAGE)

func _build_vault() -> void:
	if vault_open:
		_picture(view_layer, ART["vault_open"], FULL)
		_hotspot(view_layer, Rect2(573, 253, 134, 214), _take_vaccine, "Vial", T.CAPTION_VIAL)
		return
	_picture(view_layer, ART["vault"], FULL)
	_hotspot(view_layer, Rect2(310, 100, 540, 540), func(): say(T.DOOR_LOCKED), "VaultDoor", T.CAPTION_VAULT_DOOR)
	_hotspot(view_layer, Rect2(890, 203, 147, 140), _use_reader, "CardReader", T.CAPTION_READER)
	_hotspot(view_layer, Rect2(890, 367, 147, 180), show_lock, "Keypad", T.CAPTION_KEYPAD)

func _use_reader() -> void:
	if keypad_unlocked:
		say(T.READER_ALREADY_ACTIVE)
	elif not has_keycard:
		say(T.READER_NO_CARD)
	elif not card_selected:
		say(T.READER_NOT_SELECTED)
	else:
		keypad_unlocked = true
		card_selected = false
		_play(release_player)
		_update_hud()
		say(T.READER_ACCEPTED)

func show_lock() -> void:
	if not keypad_unlocked:
		say(T.KEYPAD_LOCKED)
		return
	entered_code = ""
	begin_modal()
	_panel(modal_layer, Rect2(363, 78, 554, 558), WINDOW_FILL, WINDOW_BORDER)
	_label(modal_layer, T.KEYPAD_TITLE, Rect2(393, 97, 470, 43), 25)
	_label(modal_layer, T.KEYPAD_SUBTITLE, Rect2(393, 141, 470, 38), 21, Color("c5b8cb"))
	code_display = _label(modal_layer, "", Rect2(421, 187, 440, 61), 40)
	code_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_feedback = _label(modal_layer, T.KEYPAD_PROMPT, Rect2(393, 250, 480, 35), 20, Color("c2b2cc"))
	for i in range(9):
		_button(modal_layer, str(i + 1), Rect2(408 + (i % 3) * 157, 298 + int(i / 3.0) * 70, 145, 62), keypad.bind(str(i + 1)), "Digit%d" % (i + 1))
	_button(modal_layer, T.KEYPAD_CLEAR, Rect2(408, 508, 145, 62), keypad.bind("clear"), "ClearCode")
	_button(modal_layer, "0", Rect2(565, 508, 145, 62), keypad.bind("0"), "Digit0")
	_button(modal_layer, T.KEYPAD_ENTER, Rect2(722, 508, 145, 62), keypad.bind("enter"), "EnterCode")
	_button(modal_layer, "×", Rect2(917, 78, 65, 64), close_modal, "Close")
	_update_code_display()

func keypad(key: String) -> void:
	var length := T.VAULT_CODE.length()
	if key == "clear":
		entered_code = ""
	elif key == "enter":
		if entered_code.length() < length:
			lock_feedback.text = T.KEYPAD_TOO_SHORT
		elif entered_code == T.VAULT_CODE:
			vault_open = true
			_play(release_player)
			show_view("vault", false)
			say(T.VAULT_OPENS)
			return
		else:
			lock_feedback.text = T.KEYPAD_WRONG
			entered_code = ""
	elif entered_code.length() < length:
		entered_code += key
	_update_code_display()

func _update_code_display() -> void:
	var shown := PackedStringArray()
	for i in range(T.VAULT_CODE.length()):
		shown.append(entered_code[i] if i < entered_code.length() else "_")
	code_display.text = "  ".join(shown)

# Taking the vial again (after closing the window with Escape) reopens the window, so the ending stays reachable.
func _take_vaccine() -> void:
	if not has_vaccine:
		has_vaccine = true
		_play(release_player)
	begin_modal()
	_panel(modal_layer, Rect2(390, 110, 500, 450), WINDOW_FILL, WINDOW_BORDER)
	_picture(modal_layer, ART["vaccine_icon"], Rect2(550, 140, 180, 180))
	var title := _label(modal_layer, T.VACCINE_TITLE, Rect2(410, 345, 460, 50), 31)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(modal_layer, T.CONTINUE, Rect2(520, 450, 240, 64), _start_ending, "Continue")

func _start_ending() -> void:
	busy = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await fade_out.finished
	finished = true
	view_stack.clear()
	show_view("ending", false)
	toast_label.visible = false
	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 0.0, 0.6)
	await fade_in.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false

func _build_ending() -> void:
	_picture(view_layer, ART["ending"], FULL)
	_panel(view_layer, Rect2(40, 150, 400, 420), Color(0.188, 0.153, 0.216, 0.88), WINDOW_BORDER)
	_label(view_layer, T.ENDING_TITLE, Rect2(70, 172, 340, 45), 31)
	_label(view_layer, T.ENDING_SUBTITLE, Rect2(70, 222, 340, 30), 21, OBJECTIVE_COLOR)
	_label(view_layer, T.ENDING_TEXT, Rect2(70, 268, 340, 190), 21, CREAM, true)
	_button(view_layer, T.MAIN_MENU, Rect2(70, 482, 165, 62), func(): GameFlow.go_to_menu(), "MainMenu")
	_button(view_layer, T.PLAY_AGAIN, Rect2(245, 482, 165, 62), func(): GameFlow.start_new_game(), "PlayAgain")
	if not completed_emitted:
		completed_emitted = true
		room_completed.emit()

# --- HUD -------------------------------------------------------------------

func _update_hud() -> void:
	if not is_instance_valid(hud_layer):
		return
	_clear(hud_layer)
	if current_view == "ending":
		return
	_panel(hud_layer, Rect2(0, 0, 1280, 72), Color(0.07, 0.055, 0.10, 0.91))
	_label(hud_layer, T.TITLE, Rect2(26, 8, 440, 28), 20)
	_label(hud_layer, _objective(), Rect2(26, 37, 960, 30), 19, OBJECTIVE_COLOR)
	_button(hud_layer, T.HINT, Rect2(1010, 8, 98, 56), show_hint, "Hint")
	_button(hud_layer, T.MENU, Rect2(1122, 8, 130, 56), _open_pause_menu, "Menu")  # Integration (GameFlow): was show_menu
	_panel(hud_layer, Rect2(0, 640, 1280, 80), Color(0.07, 0.055, 0.10, 0.94))
	if current_view != "room":
		_button(hud_layer, T.BACK, Rect2(24, 649, 144, 60), go_back, "Back")
	else:
		_label(hud_layer, T.TAP_TO_INSPECT, Rect2(28, 666, 430, 40), 21, FOOTER_COLOR)
	if has_keycard:
		var title := T.KEYCARD
		if keypad_unlocked:
			title = T.KEYCARD_USED
		elif card_selected:
			title = T.KEYCARD_SELECTED
		var card := _button(hud_layer, title, Rect2(926, 649, 326, 60), _select_card, "InventoryKeycard")
		if _art_exists(ART["keycard_icon"]):
			card.icon = load(ASSETS + ART["keycard_icon"]) as Texture2D
			card.add_theme_constant_override("icon_max_width", 44)
		if card_selected:
			card.add_theme_stylebox_override("normal", _style(Color("655069"), Color("e3c89a")))
	else:
		_label(hud_layer, T.INVENTORY_EMPTY, Rect2(966, 669, 285, 32), 18, EMPTY_COLOR)

# The stage drives both the objective line and the hint set.
func _stage() -> String:
	if finished: return "done"
	if vault_open: return "vaccine"
	if keypad_unlocked: return "keypad"
	if has_keycard and code_seen: return "reader"
	if has_keycard: return "code"
	if notebook_read or code_seen: return "card"
	return "start"

func _objective() -> String:
	match _stage():
		"done": return T.OBJ_DONE
		"vaccine": return T.OBJ_VACCINE
		"keypad": return T.OBJ_KEYPAD
		"reader": return T.OBJ_READER
		"code", "card": return T.OBJ_FIND_BOTH % (int(has_keycard) + int(code_seen))
	return T.OBJ_START

# --- Messages and windows --------------------------------------------------

func say(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_timer.start()

func begin_modal() -> void:
	_clear(modal_layer)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.015, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(shade)
	toast_label.visible = false

func close_modal() -> void:
	if not is_instance_valid(modal_layer):
		return
	_clear(modal_layer)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_hint() -> void:
	var stage := _stage()
	if stage != hint_stage:
		hint_stage = stage
		hint_step = 0
	var hints: Array = T.HINTS.get(stage, T.HINTS["vaccine"])
	var level := mini(hint_step, hints.size() - 1)
	var hint: String = hints[level]
	if stage == "reader" and level == hints.size() - 1 and not card_selected:
		hint = T.HINT_READER_NOT_SELECTED
	if hint.contains("%s"):
		var digits := PackedStringArray()
		for digit in T.VAULT_CODE:
			digits.append(digit)
		hint = hint % ", ".join(digits)
	begin_modal()
	_panel(modal_layer, Rect2(200, 190, 880, 310), WINDOW_FILL, WINDOW_BORDER)
	_label(modal_layer, T.HINT_TITLE, Rect2(240, 218, 740, 45), 29)
	_label(modal_layer, hint, Rect2(240, 280, 790, 115), 25, CREAM, true)
	_button(modal_layer, T.MORE_HELP, Rect2(241, 414, 240, 64), _more_help, "MoreHint")
	_button(modal_layer, T.CLOSE, Rect2(789, 414, 240, 64), close_modal, "Close")

func _more_help() -> void:
	hint_step += 1
	show_hint()

# Integration (GameFlow): opens the shared pause menu (game/ui/pz_pause_menu.gd).
func _open_pause_menu() -> void:
	pause_menu.open()

# Integration (GameFlow): show_menu, _toggle_hotspots_from_menu, _toggle_sound and _confirm_restart
# are no longer used; the shared pause menu replaces them. Kept unchanged.
func show_menu() -> void:
	begin_modal()
	_panel(modal_layer, Rect2(375, 100, 530, 425), WINDOW_FILL, WINDOW_BORDER)
	_label(modal_layer, T.MENU_TITLE, Rect2(418, 125, 450, 49), 31)
	_button(modal_layer, T.RESUME, Rect2(416, 195, 448, 64), close_modal, "Close")
	_button(modal_layer, T.HIDE_HOTSPOTS if show_hotspots else T.SHOW_HOTSPOTS, Rect2(416, 273, 448, 64), _toggle_hotspots_from_menu, "ToggleHotspots")
	_button(modal_layer, T.SOUND_ON if sound_enabled else T.SOUND_OFF, Rect2(416, 351, 448, 64), _toggle_sound, "ToggleSound")
	_button(modal_layer, T.RESTART_LEVEL, Rect2(416, 429, 448, 64), _confirm_restart, "Restart")

func _toggle_hotspots_from_menu() -> void:
	show_hotspots = not show_hotspots
	_refresh_view()
	show_menu()

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	ambient_player.stream_paused = not sound_enabled
	show_menu()

func _confirm_restart() -> void:
	begin_modal()
	_panel(modal_layer, Rect2(270, 225, 740, 270), WINDOW_FILL, WINDOW_BORDER)
	_label(modal_layer, T.RESTART_QUESTION, Rect2(310, 260, 680, 65), 27)
	_button(modal_layer, T.CANCEL, Rect2(310, 367, 280, 64), show_menu, "CancelRestart")
	_button(modal_layer, T.RESTART, Rect2(660, 367, 310, 64), _restart_level, "ConfirmRestart")

func _restart_level() -> void:
	notebook_read = false
	has_keycard = false
	card_selected = false
	code_seen = false
	keypad_unlocked = false
	vault_open = false
	has_vaccine = false
	finished = false
	hint_step = 0
	hint_stage = ""
	entered_code = ""
	view_stack.clear()
	toast_label.visible = false
	show_view("room", false)

# --- Keys ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or busy or current_view == "ending":
		return
	if key.keycode == KEY_ESCAPE:
		if modal_layer.get_child_count() > 0:
			close_modal()
		elif current_view != "room":
			go_back()
		else:
			_open_pause_menu()  # Integration (GameFlow): was show_menu()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_H and modal_layer.get_child_count() == 0:
		show_hotspots = not show_hotspots
		_refresh_view()
		say(T.HOTSPOTS_ON_MESSAGE if show_hotspots else T.HOTSPOTS_OFF_MESSAGE)
		get_viewport().set_input_as_handled()
