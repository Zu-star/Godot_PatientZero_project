extends Control
const MENU_SCENE := "res://scenes/menu.tscn"
const DURATION := 3.0
var elapsed := 0.0
var transitioning := false
var ambience_player: AudioStreamPlayer
func _ready() -> void:
    $Background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.008, 0.02, 0.20)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
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
    add_child(title)
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "SplashAmbience"
    var ambience := load("res://assets/sounds/menu_ambience.wav") as AudioStreamWAV
    if ambience:
        ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
        ambience_player.stream = ambience
        ambience_player.volume_db = -21.0
        add_child(ambience_player)
        ambience_player.play()
    modulate.a = 0.0
    create_tween().tween_property(self, "modulate:a", 1.0, 0.45).from(0.0)
func _process(delta: float) -> void:
    if transitioning: return
    elapsed += delta
    if elapsed >= DURATION:
        transitioning = true
        var tween := create_tween()
        tween.tween_property(self, "modulate:a", 0.0, 0.35)
        tween.tween_callback(func(): get_tree().change_scene_to_file(MENU_SCENE))
