extends CanvasLayer

## Shared pause menu for every room. Built in code on its own CanvasLayer, so it looks and sits
## exactly the same in every room, whatever the room's own layout (room 1 lives in a 1280x617
## stage inside a 1280x720 wrapper). Not an autoload: a room creates it with preload(...).new().
##
## Usage:
##   pause_menu = preload("res://game/ui/pz_pause_menu.gd").new()
##   add_child(pause_menu)
##   pause_menu.setup({
##       "on_open": func(): return true,     # optional; return false to refuse opening
##       "on_close": func(): pass,           # optional; called by Resume, Close menu, Escape, Restart
##       "get_hotspots": func(): return show_hotspots,
##       "set_hotspots": func(on: bool): ...,
##       "on_restart": func(): ...,          # the room's own restart function
##   })
##   pause_menu.open()
##
## Sound is global: GameFlow.set_sound_enabled() mutes the Master bus.

const SCREEN := Vector2(1280, 720)
const CREAM := Color("e4d9c3")
const MUTED := Color("b9acbd")
const PANEL_FILL := Color("211b2a")
const PANEL_BORDER := Color("9b89a5")
const SHADE := Color(0.02, 0.015, 0.035, 0.78)
const CLICK_SOUND := "res://quarantine_room/assets/audio/click.wav"

# Layout of the main page, in 1280x720 screen coordinates.
const MENU_PANEL := Rect2(390, 80, 500, 560)
const MENU_TITLE := Rect2(420, 100, 440, 48)
const BUTTON_X := 500.0
const BUTTON_FIRST_Y := 170.0
const BUTTON_SIZE := Vector2(280, 64)
const BUTTON_STEP := 76.0
const BUTTON_FONT := 20
# Layout of the confirmation pages.
const CONFIRM_PANEL := Rect2(390, 190, 500, 330)
const CONFIRM_TITLE := Rect2(425, 222, 430, 60)
const CONFIRM_TITLE_ALONE := Rect2(425, 270, 430, 60)  # title without a text line under it
const CONFIRM_TEXT := Rect2(430, 290, 420, 60)
const CONFIRM_CANCEL := Rect2(440, 420, 190, 64)
const CONFIRM_OK := Rect2(650, 420, 190, 64)

var on_open: Callable
var on_close: Callable
var get_hotspots: Callable
var set_hotspots: Callable
var on_restart: Callable

var page := ""
var leaving := false
var root: Control
var window: Control
var click_player: AudioStreamPlayer

func _init() -> void:
	name = "PZPauseMenu"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "Root"
	root.position = Vector2.ZERO
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = SHADE
	shade.position = Vector2.ZERO
	shade.size = SCREEN
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	window = Control.new()
	window.name = "Window"
	window.position = Vector2.ZERO
	window.size = SCREEN
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(window)
	click_player = AudioStreamPlayer.new()
	click_player.name = "ClickAudio"
	click_player.stream = load(CLICK_SOUND) as AudioStream
	click_player.volume_db = -18.0
	add_child(click_player)

func setup(callbacks: Dictionary) -> void:
	on_open = callbacks.get("on_open", Callable())
	on_close = callbacks.get("on_close", Callable())
	get_hotspots = callbacks.get("get_hotspots", Callable())
	set_hotspots = callbacks.get("set_hotspots", Callable())
	on_restart = callbacks.get("on_restart", Callable())

func is_open() -> bool:
	return root.visible

func open() -> void:
	if is_open() or leaving:
		return
	if on_open.is_valid():
		var allowed = on_open.call()
		if allowed is bool and not allowed:
			return
	root.visible = true
	_show_menu()

func close() -> void:
	if not is_open() or leaving:
		return
	root.visible = false
	page = ""
	_clear()
	if on_close.is_valid():
		on_close.call()

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if leaving:
			return
		if page == "menu":
			close()
		else:
			_show_menu()
	elif key.keycode == KEY_H:
		# Rooms toggle hotspots with H; not while the menu is open, so its label stays true.
		get_viewport().set_input_as_handled()

# --- Pages ----------------------------------------------------------------

func _show_menu() -> void:
	page = "menu"
	_clear()
	_panel(MENU_PANEL)
	_label("Title", "PAUSE MENU", MENU_TITLE, 30, CREAM)
	_menu_button(0, "Resume", close, "Resume")
	_menu_button(1, _hotspots_text(), _toggle_hotspots, "ToggleHotspots")
	_menu_button(2, _sound_text(), _toggle_sound, "ToggleSound")
	_menu_button(3, "Restart level", _confirm_restart, "RestartLevel")
	_menu_button(4, "Main menu", _confirm_main_menu, "MainMenu")
	_menu_button(5, "Close menu", close, "CloseMenu")

func _confirm_restart() -> void:
	page = "confirm_restart"
	_clear()
	_panel(CONFIRM_PANEL)
	_label("Title", "Restart this level?", CONFIRM_TITLE_ALONE, 28, CREAM)
	_button("Cancel", CONFIRM_CANCEL, _show_menu, "CancelRestart")
	_button("Restart", CONFIRM_OK, _restart, "ConfirmRestart")

func _confirm_main_menu() -> void:
	page = "confirm_main_menu"
	_clear()
	_panel(CONFIRM_PANEL)
	_label("Title", "Return to the main menu?", CONFIRM_TITLE, 28, CREAM)
	_label("Text", "Your progress in this level will be lost.", CONFIRM_TEXT, 18, MUTED)
	_button("Cancel", CONFIRM_CANCEL, _show_menu, "CancelMainMenu")
	_button("Main menu", CONFIRM_OK, _go_to_main_menu, "ConfirmMainMenu")

# --- Actions --------------------------------------------------------------

func _hotspots_text() -> String:
	var on: bool = get_hotspots.is_valid() and bool(get_hotspots.call())
	return "Show hotspots: " + ("ON" if on else "OFF")

func _sound_text() -> String:
	return "Sound: " + ("ON" if _sound_on() else "OFF")

func _sound_on() -> bool:
	var flow := get_node_or_null("/root/GameFlow")
	return flow == null or bool(flow.sound_enabled)

func _toggle_hotspots() -> void:
	if get_hotspots.is_valid() and set_hotspots.is_valid():
		set_hotspots.call(not bool(get_hotspots.call()))
	_show_menu()

func _toggle_sound() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow:
		flow.set_sound_enabled(not bool(flow.sound_enabled))
	_show_menu()

func _restart() -> void:
	close()
	if on_restart.is_valid():
		on_restart.call()

func _go_to_main_menu() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow == null:
		return
	# The room stays paused behind the menu while GameFlow fades out and changes the scene.
	leaving = true
	for b in window.find_children("*", "Button", true, false):
		(b as Button).disabled = true
	flow.go_to_menu()

# --- Building blocks (same look as the Quarantine Room) -------------------

func _clear() -> void:
	for child in window.get_children():
		window.remove_child(child)
		child.queue_free()

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _panel(rect: Rect2) -> void:
	var p := Panel.new()
	p.name = "Panel"
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(PANEL_FILL, PANEL_BORDER))
	window.add_child(p)

func _label(id: String, value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var l := Label.new()
	l.name = id
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(l)

func _menu_button(index: int, title: String, action: Callable, id: String) -> void:
	_button(title, Rect2(Vector2(BUTTON_X, BUTTON_FIRST_Y + BUTTON_STEP * index), BUTTON_SIZE), action, id)

func _button(title: String, rect: Rect2, action: Callable, id: String) -> void:
	var b := Button.new()
	b.name = id
	b.text = title
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", BUTTON_FONT)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _style(Color("302a3b"), Color("8d7d98")))
	b.add_theme_stylebox_override("hover", _style(Color("494054"), Color("cab7c9")))
	b.add_theme_stylebox_override("pressed", _style(Color("66536d"), CREAM))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("e2c8a1")))
	b.pressed.connect(func():
		if is_instance_valid(click_player) and click_player.stream:
			click_player.play()
		action.call()
	)
	window.add_child(b)
