extends Control

const ROOM_CLOSED: Texture2D = preload("res://assets/room_closed.jpg")
const ROOM_OPEN: Texture2D = preload("res://assets/room_door_open.jpg")
const TASK_SCREEN: Texture2D = preload("res://assets/task_reference.jpg")
const KEY_REWARD_SCREEN: Texture2D = preload("res://assets/key_reward_reference.jpg")
const GAME_OVER_SCREEN: Texture2D = preload("res://assets/game_over.jpg")
const SPLASH_SCREEN: Texture2D = preload("res://assets/backgrounds/splash_icon_art.png")
const MENU_CINEMATIC: Texture2D = preload("res://assets/backgrounds/menu_cinematic.png")
const ROOM2_BACKGROUND: Texture2D = preload("res://assets/room2_background.png")
const KEY_TEXTURE: Texture2D = preload("res://assets/key.png")

const VIEW_SIZE := Vector2(1280, 617)
const BLUE := Color("#2d8de0")
const ICE := Color("#9bd4ff")
const NAVY := Color("#071322")
const PALE := Color("#e8f3ff")
const METAL := Color("#252d33")

var time_left: int = 35
var attempts_left: int = 3
var selected_answer: String = ""
var current_state: String = "playing"
var task_layer: Control
var reward_layer: Control
var gameover_layer: Control
var menu_layer: Control
var splash_layer: Control
var howto_layer: Control
var pause_layer: Control
var room2_layer: Control
var state_before_pause: String = "playing"
var ambience_player: AudioStreamPlayer
var timer: Timer
var timer_label: Label
var task_timer_label: Label
var attempts_label: Label
var task_attempts_label: Label
var answer_highlights: Dictionary = {}
var feedback_label: Label
var hint_panel: Panel
var key_sprite: TextureRect
var key_dragging: bool = false
var key_drag_offset := Vector2.ZERO
var key_home_position := Vector2(600, 450)
var door_drop_rect := Rect2(885, 72, 345, 455)
var main_hud: Control
var main_bg: TextureRect
var computer_hotspot: Button
var door_hotspot: Button

func _ready() -> void:
	_build_room()
	_build_timer()
	_start_ambient()
	_show_splash()

func _process(_delta: float) -> void:
	if key_dragging and is_instance_valid(key_sprite):
		key_sprite.position = get_global_mouse_position() - key_drag_offset

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if current_state == "paused":
			_resume_game()
		elif current_state in ["playing", "key_ready", "room2", "door_open"]:
			_show_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if current_state != "key_ready" or not is_instance_valid(key_sprite):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and key_sprite.get_global_rect().has_point(event.position):
			key_dragging = true
			key_drag_offset = event.position - key_sprite.position
			key_sprite.z_index = 100
			get_viewport().set_input_as_handled()
		elif not event.pressed and key_dragging:
			key_dragging = false
			_play_sound("user_release.wav", -5.0)
			if door_drop_rect.has_point(event.position):
				if is_instance_valid(key_sprite):
					key_sprite.queue_free()
					key_sprite = null
				_show_door_open()
			else:
				key_sprite.position = key_home_position
			get_viewport().set_input_as_handled()

func _build_room() -> void:
	main_bg = TextureRect.new()
	main_bg.texture = ROOM_CLOSED
	main_bg.position = Vector2.ZERO
	main_bg.size = VIEW_SIZE
	main_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	main_bg.stretch_mode = TextureRect.STRETCH_SCALE
	main_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_bg)

func _build_timer() -> void:
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)

func _build_hud() -> void:
	main_hud = Control.new()
	main_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_hud)

	var title_panel := _panel(main_hud, Vector2(24, 14), Vector2(530, 77), Color(0.015, 0.035, 0.065, 0.92), Color("#5b9dd9"), 12)
	var title := _label("INITIAL TASK", Vector2(22, 11), Vector2(490, 31), 27, PALE)
	title.add_theme_constant_override("outline_size", 1)
	title_panel.add_child(title)
	var subtitle := _label("Solve the puzzle to unlock the door", Vector2(23, 44), Vector2(490, 22), 17, Color("#8dbbe9"))
	title_panel.add_child(subtitle)

	var time_panel := _panel(main_hud, Vector2(566, 14), Vector2(210, 77), Color(0.015, 0.035, 0.065, 0.92), Color("#5b9dd9"), 12)
	var time_title := _label("TIME LEFT", Vector2(17, 9), Vector2(190, 20), 15, ICE)
	time_panel.add_child(time_title)
	timer_label = _label("00:35", Vector2(17, 29), Vector2(190, 39), 29, Color("#7cc9ff"))
	timer_label.add_theme_font_size_override("font_size", 30)
	time_panel.add_child(timer_label)

	var attempts_panel := _panel(main_hud, Vector2(790, 14), Vector2(245, 77), Color(0.015, 0.035, 0.065, 0.92), Color("#5b9dd9"), 12)
	var attempts_title := _label("ATTEMPTS", Vector2(18, 9), Vector2(205, 20), 15, ICE)
	attempts_panel.add_child(attempts_title)
	attempts_label = _label("●   ●   ●", Vector2(18, 29), Vector2(205, 38), 28, Color("#78c8ff"))
	attempts_panel.add_child(attempts_label)

	var menu_button := _button(main_hud, "MENU  ☰", Vector2.ZERO, Vector2(122, 48), Color("#172b3b"), Color("#74b7ed"), PALE, 17)
	# Anchor to the actual viewport edge so resizing cannot leave the button floating inward.
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.anchor_top = 0.0
	menu_button.anchor_bottom = 0.0
	menu_button.offset_left = -136.0
	menu_button.offset_right = -14.0
	menu_button.offset_top = 12.0
	menu_button.offset_bottom = 60.0
	menu_button.tooltip_text = "Pause / game menu"
	menu_button.pressed.connect(_show_pause_menu)

func _build_hotspots() -> void:
	computer_hotspot = _button(self, "", Vector2(88, 198), Vector2(340, 214), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	computer_hotspot.tooltip_text = "Click the computer to open the task"
	computer_hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	computer_hotspot.pressed.connect(_open_task)
	computer_hotspot.z_index = 2
	# Transparent hit area over the industrial door. It remains locked until the key is dragged to it.
	door_hotspot = _button(self, "", Vector2(895, 98), Vector2(320, 420), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	door_hotspot.tooltip_text = "Locked. Solve the computer task first."
	door_hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	door_hotspot.pressed.connect(_on_door_clicked)
	door_hotspot.z_index = 2

func _open_task() -> void:
	if current_state != "playing" or is_instance_valid(task_layer) or is_instance_valid(reward_layer):
		return
	_play_sound("computer_beep.wav", -8.0)
	selected_answer = ""
	task_layer = Control.new()
	task_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_layer.z_index = 20
	add_child(task_layer)
	var art := TextureRect.new()
	art.texture = TASK_SCREEN
	art.position = Vector2.ZERO
	art.size = VIEW_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_layer.add_child(art)

	# Small blue status chips stay in the ceiling area, leaving the reference computer UI untouched.
	var time_chip := _panel(task_layer, Vector2(15, 5), Vector2(183, 39), Color(0.015, 0.045, 0.085, 0.96), Color("#438bd0"), 8)
	task_timer_label = _label("TIME  00:35", Vector2(12, 5), Vector2(160, 28), 18, Color("#8ed4ff"))
	time_chip.add_child(task_timer_label)
	var task_menu := _button(task_layer, "MENU", Vector2(218, 5), Vector2(96, 39), Color("#172b3b"), Color("#438bd0"), PALE, 15)
	task_menu.tooltip_text = "Pause / game menu"
	task_menu.pressed.connect(_show_pause_menu)
	var tries_chip := _panel(task_layer, Vector2(948, 5), Vector2(315, 39), Color(0.015, 0.045, 0.085, 0.96), Color("#438bd0"), 8)
	var tries_title := _label("ATTEMPTS", Vector2(12, 6), Vector2(100, 24), 15, ICE)
	tries_chip.add_child(tries_title)
	task_attempts_label = _label("●   ●   ●", Vector2(150, 2), Vector2(145, 31), 22, Color("#7bc9ff"))
	tries_chip.add_child(task_attempts_label)

	# Click targets sit directly over the four answer choices in the supplied computer-screen artwork.
	_add_answer_target("A", Rect2(365, 360, 315, 54))
	_add_answer_target("B", Rect2(692, 360, 315, 54))
	_add_answer_target("C", Rect2(365, 421, 315, 54))
	_add_answer_target("D", Rect2(692, 421, 315, 54))

	# Different, high-contrast blue submit button; positioned over the original submit control.
	var submit := _button(task_layer, "SUBMIT ANSWER", Vector2(535, 493), Vector2(295, 43), Color("#1767ad"), Color("#83caff"), Color.WHITE, 15)
	submit.pressed.connect(_submit_answer)
	submit.z_index = 8
	var hint := _button(task_layer, "HINT", Vector2(366, 493), Vector2(126, 43), Color("#1a3047"), Color("#548bbd"), Color("#b9dfff"), 15)
	hint.pressed.connect(_toggle_hint)
	hint.z_index = 8
	feedback_label = _label("", Vector2(500, 543), Vector2(470, 28), 15, Color("#ffcb9a"))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_layer.add_child(feedback_label)

	# Functional close button over the monitor's top-right close control.
	var close := _button(task_layer, "×", Vector2(1119, 57), Vector2(40, 32), Color("#14283c"), Color("#74b7ed"), PALE, 23)
	close.tooltip_text = "Close computer"
	close.pressed.connect(_close_task)
	close.z_index = 10
	_update_status_labels()

func _add_answer_target(letter: String, rect: Rect2) -> void:
	var outline := Panel.new()
	outline.position = rect.position
	outline.size = rect.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.45, 0.80, 0.17)
	style.border_color = Color("#7acaff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	outline.add_theme_stylebox_override("panel", style)
	task_layer.add_child(outline)
	answer_highlights[letter] = outline
	var hit := _button(task_layer, "", rect.position, rect.size, Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	hit.pressed.connect(_select_answer.bind(letter))
	hit.z_index = 5

func _select_answer(letter: String) -> void:
	if current_state != "playing":
		return
	selected_answer = letter
	for key in answer_highlights.keys():
		var panel: Panel = answer_highlights[key]
		panel.visible = key == letter
	if is_instance_valid(feedback_label):
		feedback_label.text = "SELECTED: %s" % letter
		feedback_label.add_theme_color_override("font_color", Color("#8ed4ff"))

func _submit_answer() -> void:
	if selected_answer == "":
		if is_instance_valid(feedback_label):
			feedback_label.text = "SELECT AN ANSWER FIRST"
			feedback_label.add_theme_color_override("font_color", Color("#ffcf91"))
		return
	if selected_answer == "C":
		_play_sound("correct_answer.wav", -8.0)
		_show_key_reward()
		return
	attempts_left -= 1
	_update_status_labels()
	if attempts_left <= 0:
		_show_game_over()
		return
	if is_instance_valid(feedback_label):
		feedback_label.text = "INCORRECT — %d ATTEMPT(S) LEFT" % attempts_left
		feedback_label.add_theme_color_override("font_color", Color("#ff9b9b"))
	selected_answer = ""
	for key in answer_highlights.keys():
		(answer_highlights[key] as Panel).visible = false

func _toggle_hint() -> void:
	if not is_instance_valid(task_layer):
		return
	if is_instance_valid(hint_panel):
		hint_panel.queue_free()
		hint_panel = null
		return
	hint_panel = _panel(task_layer, Vector2(320, 535), Vector2(640, 48), Color(0.02, 0.08, 0.14, 0.98), Color("#66b5f3"), 8)
	var hint_text := _label("HINT: The differences increase by 2 each time: +3, +5, +7, then +9.", Vector2(12, 8), Vector2(615, 30), 15, Color("#c8e7ff"))
	hint_panel.add_child(hint_text)
	hint_panel.z_index = 15

func _close_task() -> void:
	if is_instance_valid(task_layer):
		task_layer.queue_free()
		task_layer = null
	answer_highlights.clear()
	hint_panel = null
	selected_answer = ""

func _show_key_reward() -> void:
	_close_task()
	reward_layer = Control.new()
	reward_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_layer.z_index = 30
	add_child(reward_layer)
	var art := TextureRect.new()
	art.texture = KEY_REWARD_SCREEN
	art.position = Vector2.ZERO
	art.size = VIEW_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_layer.add_child(art)
	# The screenshot already contains the blue OK button; this invisible target makes it functional.
	var ok := _button(reward_layer, "", Vector2(548, 501), Vector2(258, 51), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	ok.pressed.connect(_collect_key)
	ok.z_index = 5

func _collect_key() -> void:
	_play_sound("key_pickup.wav", -7.0)
	if is_instance_valid(reward_layer):
		reward_layer.queue_free()
		reward_layer = null
	current_state = "key_ready"
	key_sprite = TextureRect.new()
	key_sprite.texture = KEY_TEXTURE
	key_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_sprite.size = Vector2(92, 92)
	key_sprite.position = key_home_position
	key_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	key_sprite.tooltip_text = "Drag the key to the locked door"
	key_sprite.z_index = 12
	add_child(key_sprite)
	var note := _panel(self, Vector2(430, 535), Vector2(420, 48), Color(0.015, 0.045, 0.075, 0.95), Color("#5b9dd9"), 8)
	note.name = "KeyDragInstruction"
	var note_text := _label("DRAG THE KEY TO THE DOOR  →", Vector2(12, 7), Vector2(395, 30), 18, Color("#c4e7ff"))
	note.add_child(note_text)
	# Remove instruction automatically when the key is dropped or game ends.

func _on_door_clicked() -> void:
	if current_state == "key_ready":
		_show_toast("DRAG THE KEY ONTO THE DOOR TO UNLOCK IT")
	else:
		_show_toast("DOOR LOCKED — SOLVE THE COMPUTER TASK FIRST")

func _show_door_open() -> void:
	_play_sound("door_open.wav", -5.0)
	current_state = "door_open"
	if is_instance_valid(timer):
		timer.stop()
	if is_instance_valid(main_bg):
		# Show the opened-door background with the next room visible behind it.
		main_bg.texture = ROOM_OPEN
	if is_instance_valid(computer_hotspot):
		computer_hotspot.visible = false
	if is_instance_valid(door_hotspot):
		door_hotspot.visible = false
	var instruction := get_node_or_null("KeyDragInstruction")
	if instruction:
		instruction.queue_free()
	# No "THE DOOR OPENED" overlay and no "MOVE TO THE NEXT ROOM" button.
	# The player remains on this screen with the open doorway visible.

func _show_game_over() -> void:
	_play_sound("zombie_attack.mp3", -3.0)
	current_state = "gameover"
	timer.stop()
	_close_task()
	if is_instance_valid(reward_layer):
		reward_layer.queue_free()
		reward_layer = null
	if is_instance_valid(key_sprite):
		key_sprite.queue_free()
		key_sprite = null
	var instruction := get_node_or_null("KeyDragInstruction")
	if instruction:
		instruction.queue_free()
	gameover_layer = Control.new()
	gameover_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_layer.z_index = 80
	add_child(gameover_layer)
	var art := TextureRect.new()
	art.texture = GAME_OVER_SCREEN
	art.position = Vector2.ZERO
	art.size = VIEW_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_layer.add_child(art)
	var restart := _button(gameover_layer, "", Vector2(486, 414), Vector2(345, 60), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	restart.pressed.connect(_restart_game)
	var main_menu := _button(gameover_layer, "", Vector2(486, 480), Vector2(345, 59), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.WHITE, 1)
	main_menu.pressed.connect(_show_main_menu)

func _restart_game() -> void:
	# Clear all overlays and gameplay controls before creating a fresh run.
	for layer in [gameover_layer, menu_layer, splash_layer, howto_layer, pause_layer, reward_layer, task_layer]:
		if is_instance_valid(layer):
			layer.queue_free()
	gameover_layer = null
	menu_layer = null
	splash_layer = null
	howto_layer = null
	pause_layer = null
	reward_layer = null
	task_layer = null

	if is_instance_valid(key_sprite):
		key_sprite.queue_free()
	key_sprite = null
	var instruction := get_node_or_null("KeyDragInstruction")
	if instruction:
		instruction.queue_free()
	for child in get_children():
		if child.name == "DoorOpenedOverlay":
			child.queue_free()

	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = null
	if is_instance_valid(main_hud):
		main_hud.queue_free()
	main_hud = null
	if is_instance_valid(computer_hotspot):
		computer_hotspot.queue_free()
	computer_hotspot = null
	if is_instance_valid(door_hotspot):
		door_hotspot.queue_free()
	door_hotspot = null
	if is_instance_valid(room2_layer):
		room2_layer.queue_free()
	room2_layer = null

	current_state = "playing"
	time_left = 35
	attempts_left = 3
	selected_answer = ""
	key_dragging = false
	answer_highlights.clear()
	if is_instance_valid(main_bg):
		main_bg.texture = ROOM_CLOSED
	_build_hud()
	_build_hotspots()
	_update_status_labels()
	timer.start()


func _show_splash() -> void:
	current_state = "splash"
	if is_instance_valid(timer):
		timer.stop()
	splash_layer = Control.new()
	splash_layer.name = "SplashScreen"
	splash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_layer.z_index = 100
	# Keep the splash fully opaque from its first frame so the room background
	# underneath cannot flash during the transition.
	splash_layer.modulate.a = 1.0
	add_child(splash_layer)

	var art := TextureRect.new()
	art.texture = SPLASH_SCREEN
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_layer.add_child(art)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.008, 0.02, 0.20)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_layer.add_child(shade)

	var title := Label.new()
	title.text = "PATIENT ZERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.12
	title.anchor_right = 0.88
	title.anchor_top = 0.68
	title.anchor_bottom = 0.88
	title.add_theme_font_override("font", load("res://assets/fonts/NotoSerif-CondensedBold.ttf"))
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.87))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.02, 0.95))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_layer.add_child(title)

	# Hold the splash for three seconds, then build the main menu before the
	# splash is removed, avoiding a transparent frame that reveals the room.
	await get_tree().create_timer(3.0).timeout
	if current_state == "splash" and is_instance_valid(splash_layer):
		_show_main_menu()

func _show_main_menu() -> void:
	current_state = "menu"
	if is_instance_valid(timer):
		timer.stop()
	_close_task()
	for layer in [gameover_layer, menu_layer, splash_layer, howto_layer, pause_layer, reward_layer]:
		if is_instance_valid(layer):
			layer.queue_free()
	gameover_layer = null
	menu_layer = null
	splash_layer = null
	howto_layer = null
	pause_layer = null
	reward_layer = null
	if is_instance_valid(key_sprite):
		key_sprite.queue_free()
	key_sprite = null
	var instruction := get_node_or_null("KeyDragInstruction")
	if instruction:
		instruction.queue_free()
	for child in get_children():
		if child.name == "DoorOpenedOverlay":
			child.queue_free()
	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = null
	if is_instance_valid(main_hud):
		main_hud.queue_free()
	main_hud = null
	if is_instance_valid(computer_hotspot):
		computer_hotspot.queue_free()
	computer_hotspot = null
	if is_instance_valid(door_hotspot):
		door_hotspot.queue_free()
	door_hotspot = null
	if is_instance_valid(main_bg):
		main_bg.texture = ROOM_CLOSED

	menu_layer = Control.new()
	menu_layer.name = "MainMenu"
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.z_index = 90
	add_child(menu_layer)

	var art := TextureRect.new()
	art.texture = MENU_CINEMATIC
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.003, 0.008, 0.015, 0.20)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)

	var panel := _panel(menu_layer, Vector2(700, 153), Vector2(535, 310), Color(0.008, 0.018, 0.028, 0.88), Color("#31515c"), 8)
	var title := _label("PATIENT ZERO", Vector2(28, 22), Vector2(475, 68), 48, Color("#f0e9dd"))
	title.add_theme_font_override("font", load("res://assets/fonts/NotoSerif-CondensedBold.ttf"))
	panel.add_child(title)
	panel.add_child(_label("THE OUTBREAK HAS BEGUN", Vector2(29, 91), Vector2(470, 24), 14, Color("#82bfc2")))
	var line := ColorRect.new()
	line.position = Vector2(28, 130)
	line.size = Vector2(478, 2)
	line.color = Color("#b3212b")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)

	var begin := _button(panel, "BEGIN SURVIVAL   ›", Vector2(28, 154), Vector2(478, 60), Color("#650d14"), Color("#d13a43"), Color("#fff4ec"), 22)
	begin.pressed.connect(_restart_game)
	var howto := _button(panel, "HOW TO PLAY", Vector2(28, 229), Vector2(478, 54), Color(0.015, 0.035, 0.045, 0.92), Color("#42606b"), Color("#f0e9dd"), 18)
	howto.pressed.connect(_show_how_to_play)


func _show_pause_menu() -> void:
	if current_state == "paused" or current_state in ["menu", "splash", "gameover"]:
		return
	state_before_pause = current_state
	current_state = "paused"
	if is_instance_valid(timer):
		timer.stop()
	key_dragging = false
	pause_layer = Control.new()
	pause_layer.name = "PauseMenu"
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.z_index = 120
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.008, 0.015, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(shade)
	var panel := _panel(pause_layer, Vector2(430, 105), Vector2(420, 405), Color(0.012, 0.026, 0.04, 0.97), Color("#5b9dd9"), 10)
	var title := _label("PAUSED", Vector2(25, 22), Vector2(370, 58), 36, PALE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var line := ColorRect.new()
	line.position = Vector2(35, 86)
	line.size = Vector2(350, 2)
	line.color = Color("#5b9dd9")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var resume := _button(panel, "RESUME", Vector2(35, 120), Vector2(350, 58), Color("#163d5d"), Color("#74b7ed"), PALE, 20)
	resume.pressed.connect(_resume_game)
	var restart := _button(panel, "START AGAIN", Vector2(35, 200), Vector2(350, 58), Color("#29343a"), Color("#8b9aa2"), PALE, 20)
	restart.pressed.connect(_restart_game)
	var main_menu := _button(panel, "GO TO MAIN MENU", Vector2(35, 280), Vector2(350, 58), Color("#111e2a"), Color("#5b9dd9"), PALE, 19)
	main_menu.pressed.connect(_show_main_menu)

func _resume_game() -> void:
	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = null
	current_state = state_before_pause
	if current_state in ["playing", "key_ready"] and time_left > 0 and is_instance_valid(timer):
		timer.start()

func _start_ambient() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "GameAmbience"
	var stream := load("res://assets/sounds/user_ambient.wav") as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience_player.stream = stream
		ambience_player.volume_db = -5.0
		add_child(ambience_player)
		ambience_player.play()

func _play_ui_click() -> void:
	_play_sound("user_click.wav", -3.0)

func _play_sound(file_name: String, volume_db: float = -10.0) -> void:
	var stream := load("res://assets/sounds/" + file_name) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _show_how_to_play() -> void:
	if is_instance_valid(howto_layer):
		howto_layer.queue_free()
	howto_layer = Control.new()
	howto_layer.name = "HowToPlay"
	howto_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_layer.z_index = 110
	add_child(howto_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.003, 0.008, 0.015, 0.64)
	shade.size = VIEW_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	howto_layer.add_child(shade)

	# Text-only instructions styled like the approved aged-paper note. No tutorial pictures.
	var paper := _panel(howto_layer, Vector2(145, 42), Vector2(990, 500), Color("#d8c29c"), Color("#65503a"), 5)
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color("#d8c29c")
	paper_style.border_color = Color("#6b533b")
	paper_style.set_border_width_all(4)
	paper_style.set_corner_radius_all(5)
	paper.add_theme_stylebox_override("panel", paper_style)

	var title := _label("HOW TO PLAY", Vector2(40, 18), Vector2(910, 52), 36, Color("#201b16"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper.add_child(title)

	var underline := ColorRect.new()
	underline.position = Vector2(320, 73)
	underline.size = Vector2(310, 3)
	underline.color = Color("#3b2d20")
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(underline)

	var close := _button(paper, "×", Vector2(920, 7), Vector2(48, 43), Color("#d8c29c"), Color("#d8c29c"), Color("#201b16"), 34)
	close.pressed.connect(func():
		if is_instance_valid(howto_layer):
			howto_layer.queue_free()
			howto_layer = null
	)

	var rules := [
		["1. EXPLORE", "Click the computer to open the task and examine the clues."],
		["2. SOLVE", "Answer the logical multiple-choice question. You have 1 minute and 3 attempts in each room."],
		["3. FIND ITEMS", "A correct answer gives you a key or another important item."],
		["4. ESCAPE", "Drag the key to the locked door to unlock it, then move to the next room."],
		["FAILURE", "If time runs out or you use all 3 attempts, the zombies catch you. Game over."]
	]
	var y := 95
	for rule in rules:
		var heading := _label(rule[0], Vector2(55, y), Vector2(850, 28), 21, Color("#211a14"))
		paper.add_child(heading)
		var body := _label(rule[1], Vector2(55, y + 27), Vector2(850, 40), 17, Color("#30271e"))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.clip_text = false
		paper.add_child(body)
		y += 73 if rule[0] != "FAILURE" else 64

	var back := _button(howto_layer, "BACK", Vector2(515, 555), Vector2(250, 48), Color("#202a30"), Color("#a8b7b7"), Color("#f4eee2"), 20)
	back.pressed.connect(func():
		if is_instance_valid(howto_layer):
			howto_layer.queue_free()
			howto_layer = null
	)


func _on_timer_tick() -> void:
	if current_state not in ["playing", "key_ready"]:
		return
	time_left -= 1
	if time_left <= 10 and time_left > 0:
		_play_sound("timer_tick.wav", -18.0)
	_update_status_labels()
	if time_left <= 0:
		_show_game_over()

func _update_status_labels() -> void:
	var time_text := "%02d:%02d" % [int(time_left / 60), time_left % 60]
	if is_instance_valid(timer_label):
		timer_label.text = time_text
	if is_instance_valid(task_timer_label):
		task_timer_label.text = "TIME  " + time_text
	var dots := ""
	for i in range(3):
		dots += ("●" if i < attempts_left else "○")
		if i < 2:
			dots += "   "
	if is_instance_valid(attempts_label):
		attempts_label.text = dots
	if is_instance_valid(task_attempts_label):
		task_attempts_label.text = dots

func _show_toast(message: String) -> void:
	var toast := _panel(self, Vector2(335, 535), Vector2(610, 48), Color(0.015, 0.035, 0.065, 0.96), Color("#5b9dd9"), 8)
	toast.z_index = 40
	toast.add_child(_label(message, Vector2(12, 7), Vector2(585, 30), 16, Color("#c9e8ff")))
	var dismiss := _button(toast, "×", Vector2(570, 2), Vector2(34, 36), Color("#182b3b"), Color("#5b9dd9"), PALE, 20)
	dismiss.pressed.connect(func(): toast.queue_free())

func _panel(parent: Control, pos: Vector2, dimensions: Vector2, fill: Color, border: Color, radius: int = 8) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(text_value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label

func _button(parent: Control, text_value: String, pos: Vector2, dimensions: Vector2, fill: Color, border: Color, font_color: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(min(fill.r + 0.10, 1.0), min(fill.g + 0.13, 1.0), min(fill.b + 0.16, 1.0), fill.a)
	hover.border_color = Color("#b6e5ff")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(max(fill.r - 0.07, 0.0), max(fill.g - 0.07, 0.0), max(fill.b - 0.07, 0.0), fill.a)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	parent.add_child(button)
	button.pressed.connect(_play_ui_click)
	return button
