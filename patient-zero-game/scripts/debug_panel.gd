extends CanvasLayer

# Debug-only room switcher, created by GameFlow when OS.is_debug_build().
# F9 toggles the panel, F10 counts the current room as finished.
# Room buttons are built from GameFlow.ROOMS, so new rooms appear here automatically.

var panel: PanelContainer
var status_label: Label

func _ready() -> void:
    layer = 110
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_panel()
    panel.visible = false

func _build_panel() -> void:
    panel = PanelContainer.new()
    panel.name = "DebugPanel"
    panel.position = Vector2(16, 16)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.03, 0.04, 0.92)
    style.border_color = Color(0.9, 0.75, 0.2, 0.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 6)
    panel.add_child(stack)
    var title := Label.new()
    title.text = "DEBUG  (F9 — панель, F10 — пройти комнату)"
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
    stack.add_child(title)
    _add_button(stack, "Меню", func(): _jump_to_menu())
    for n in GameFlow.ROOMS:
        if not GameFlow.ROOMS[n].is_empty():
            _add_button(stack, "Комната %d" % n, func(): _jump_to_room(n))
    _add_button(stack, "Сбросить прогресс комнат 2–3", _reset_progress)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 12)
    status_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.85))
    stack.add_child(status_label)

func _add_button(parent: Node, title: String, action: Callable) -> void:
    var b := Button.new()
    b.text = title
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 14)
    b.pressed.connect(action)
    parent.add_child(b)

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.keycode == KEY_F9:
        panel.visible = not panel.visible
        status_label.text = "Сейчас: " + _current_name()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_F10:
        get_viewport().set_input_as_handled()
        var n: int = GameFlow.current_room
        if n == 0:
            print("GameFlow debug: F10 works only inside a room")
            return
        var next_path: String = GameFlow.ROOMS.get(n + 1, "")
        if next_path.is_empty():
            print("GameFlow debug: room %d is the last room, nothing to go to" % n)
        GameFlow.room_finished(n)

func _current_name() -> String:
    return "комната %d" % GameFlow.current_room if GameFlow.current_room > 0 else "не комната"

func _jump_to_menu() -> void:
    panel.visible = false
    GameFlow.go_to_menu()

# Jumping resets the room's own save first, so a completed save cannot block its exit.
func _jump_to_room(n: int) -> void:
    panel.visible = false
    GameFlow.reset_room_progress(n)
    GameFlow.go_to_room(n)

func _reset_progress() -> void:
    for n in GameFlow.ROOMS:
        if n != 1:
            GameFlow.reset_room_progress(n)
    status_label.text = "Прогресс сброшен"
    # A room that is open right now keeps its state in memory, so reload it.
    if GameFlow.current_room >= 2:
        panel.visible = false
        GameFlow.go_to_room(GameFlow.current_room)
