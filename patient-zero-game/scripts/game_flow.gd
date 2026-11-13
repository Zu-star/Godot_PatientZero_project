extends Node

# Room order for the whole game. This is the ONLY place where rooms are listed.
# An empty path means the room does not exist yet: the previous room stays on its own ending.
const ROOMS := {
    1: "res://first_room/scenes/FirstRoomHost.tscn",
    2: "res://archive_room/scenes/ArchiveLevel.tscn",
    3: "res://quarantine_room/scenes/QuarantineRoom.tscn",
    4: "res://lab_room/scenes/LabRoom.tscn",
}
# Rooms that convert touches to mouse events themselves. OS mouse emulation is turned off
# there to avoid double taps, and turned back on for every other scene.
const ROOMS_WITH_OWN_TOUCH_BRIDGE := [2]

const MENU_SCENE := "res://scenes/menu.tscn"
const QUARANTINE_SAVE_PATH := "user://quarantine_room_save.json"
const FADE_TIME := 0.5
const ROOM_END_SIGNALS := ["room_completed", "quarantine_entered"]

var current_room := 0
var transitioning := false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
# Sound of the whole game (Master bus). Toggled by the shared pause menu (game/ui/pz_pause_menu.gd).
var sound_enabled := true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_fade()
    get_tree().scene_changed.connect(_on_scene_changed)
    get_tree().auto_accept_quit = false
    if OS.is_debug_build():
        add_child(load("res://scripts/debug_panel.gd").new())

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit_game()

# A stream still playing at shutdown (ZombieAmbience, room ambience) is reported as leaked,
# and the audio thread needs a moment after stop() to release it. So stop every player first.
func quit_game(exit_code: int = 0) -> void:
    for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
        player.stop()
        player.stream = null
    await get_tree().create_timer(0.1).timeout
    get_tree().quit(exit_code)

func _build_fade() -> void:
    fade_layer = CanvasLayer.new()
    fade_layer.name = "GameFlowFade"
    fade_layer.layer = 100
    add_child(fade_layer)
    fade_rect = ColorRect.new()
    fade_rect.color = Color(0, 0, 0, 0)
    fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade_layer.add_child(fade_rect)

func set_sound_enabled(on: bool) -> void:
    sound_enabled = on
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)

func start_new_game() -> void:
    for n in ROOMS:
        if n != 1:
            reset_room_progress(n)
    go_to_room(1)

# Erases the saved progress of rooms that keep their own save. Update this together with ROOMS.
func reset_room_progress(n: int) -> void:
    match n:
        2:
            var session := get_node_or_null("/root/ArchiveSession")
            if session:
                session.reset()
        3:
            if FileAccess.file_exists(QUARANTINE_SAVE_PATH):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(QUARANTINE_SAVE_PATH))

func go_to_room(n: int) -> void:
    var path: String = ROOMS.get(n, "")
    if path.is_empty():
        return
    if not ResourceLoader.exists(path):
        push_error("GameFlow: room %d scene not found: %s" % [n, path])
        return
    _change_scene(path)

func room_finished(n: int) -> void:
    var next_path: String = ROOMS.get(n + 1, "")
    if next_path.is_empty():
        return
    go_to_room(n + 1)

func go_to_menu() -> void:
    _change_scene(MENU_SCENE)

func room_of_scene(path: String) -> int:
    for n in ROOMS:
        if not ROOMS[n].is_empty() and ROOMS[n] == path:
            return n
    return 0

func _change_scene(path: String) -> void:
    if transitioning:
        return
    transitioning = true
    fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, FADE_TIME)
    await tween.finished
    var err := get_tree().change_scene_to_file(path)
    if err != OK:
        push_error("GameFlow: could not change scene to %s (error %d)" % [path, err])
        _finish_transition()
        return
    await get_tree().scene_changed
    _finish_transition()

func _finish_transition() -> void:
    transitioning = false
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    create_tween().tween_property(fade_rect, "color:a", 0.0, FADE_TIME)

# Runs after every scene change, including changes made by the rooms themselves
# (for example room 1's "menu" buttons), so touch mode and audio always match the scene.
func _on_scene_changed() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    current_room = room_of_scene(scene.scene_file_path)
    Input.emulate_mouse_from_touch = not ROOMS_WITH_OWN_TOUCH_BRIDGE.has(current_room)
    if current_room >= 1 and has_node("/root/ZombieAmbience"):
        ZombieAmbience.stop_ambience()
    if current_room > 0:
        _connect_room_end(scene, current_room)

func _connect_room_end(scene: Node, n: int) -> void:
    for signal_name in ROOM_END_SIGNALS:
        if scene.has_signal(signal_name):
            scene.connect(signal_name, room_finished.bind(n), CONNECT_ONE_SHOT)
            return
