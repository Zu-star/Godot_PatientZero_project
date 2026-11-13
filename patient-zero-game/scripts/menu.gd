extends Control

const ROOM_SCENE := "res://scenes/room_1.tscn"
var ambience_player: AudioStreamPlayer
var title_label: Label
var subtitle_label: Label
var menu_panel: PanelContainer
var howto_panel: PanelContainer

func _ready() -> void:
    if has_node("/root/ZombieAmbience"):
        ZombieAmbience.resume_ambience()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    $UI.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $Background.texture = load("res://assets/backgrounds/menu_cinematic.png")
    $Background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    $Overlay.color = Color(0.005, 0.012, 0.022, 0.28)
    # The previous background baked the title and buttons into the image. Replace them
    # with native controls so the menu feels like a real game UI, not a poster.
    for n in ["TitlePatient", "TitleZero"]:
        var old: Node = $UI.get_node(n)
        old.hide()
    for n in ["PlayButton", "HowToPlayButton", "QuitButton"]:
        var b: Button = $UI.get_node(n)
        b.text = ""
        b.focus_mode = Control.FOCUS_NONE
        b.mouse_filter = Control.MOUSE_FILTER_STOP
    _create_menu_ui()
    $UI/PlayButton.pressed.connect(_on_play)
    $UI/HowToPlayButton.pressed.connect(_on_how_to_play)
    $UI/QuitButton.pressed.connect(_on_quit)
    _build_howto_art()
    _layout_menu()
    _start_menu_ambience()
    get_viewport().size_changed.connect(_layout_menu)

func _create_menu_ui() -> void:
    menu_panel = PanelContainer.new()
    menu_panel.name = "CinematicMenuPanel"
    menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.015, 0.025, 0.04, 0.78)
    panel_style.border_color = Color(0.30, 0.48, 0.53, 0.75)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(8)
    panel_style.content_margin_left = 28
    panel_style.content_margin_right = 28
    panel_style.content_margin_top = 24
    panel_style.content_margin_bottom = 24
    menu_panel.add_theme_stylebox_override("panel", panel_style)
    $UI.add_child(menu_panel)
    menu_panel.z_index = 1
    var stack := VBoxContainer.new()
    stack.name = "MenuStack"
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_theme_constant_override("separation", 14)
    menu_panel.add_child(stack)
    title_label = Label.new()
    title_label.text = "PATIENT ZERO"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_label.add_theme_font_override("font", load("res://assets/fonts/NotoSerif-CondensedBold.ttf"))
    title_label.add_theme_font_size_override("font_size", 50)
    title_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.87))
    stack.add_child(title_label)
    subtitle_label = Label.new()
    subtitle_label.text = "THE OUTBREAK HAS BEGUN"
    subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    subtitle_label.add_theme_font_size_override("font_size", 12)
    subtitle_label.add_theme_color_override("font_color", Color(0.52, 0.78, 0.78))
    stack.add_child(subtitle_label)
    var line := ColorRect.new()
    line.custom_minimum_size = Vector2(0, 2)
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.color = Color(0.70, 0.12, 0.16, 0.95)
    stack.add_child(line)
    _style_menu_button($UI/PlayButton, "BEGIN SURVIVAL   ›", true)
    _style_menu_button($UI/HowToPlayButton, "HOW TO PLAY", false)
    _style_menu_button($UI/QuitButton, "QUIT", false)
    $UI/PlayButton.z_index = 3
    $UI/HowToPlayButton.z_index = 3
    $UI/QuitButton.z_index = 3

func _style_menu_button(b: Button, label: String, primary: bool) -> void:
    b.text = label
    b.add_theme_font_size_override("font_size", 22 if primary else 17)
    b.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.42, 0.035, 0.055, 0.94) if primary else Color(0.025, 0.045, 0.06, 0.78)
    normal.border_color = Color(0.86, 0.16, 0.20, 1.0) if primary else Color(0.34, 0.49, 0.55, 0.85)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(5)
    normal.content_margin_left = 18
    normal.content_margin_right = 18
    normal.content_margin_top = 12
    normal.content_margin_bottom = 12
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.62, 0.055, 0.075, 1.0) if primary else Color(0.08, 0.12, 0.15, 0.96)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", hover)

func _start_menu_ambience() -> void:
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "MenuAmbience"
    var sound := load("res://assets/sounds/menu_ambience.wav") as AudioStreamWAV
    if sound:
        sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
        ambience_player.stream = sound
        ambience_player.volume_db = -28.0
        add_child(ambience_player)
        ambience_player.play()

func _play_ui_click() -> void:
    var player := AudioStreamPlayer.new()
    player.stream = load("res://assets/sounds/ui_click.wav")
    player.volume_db = -8.0
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _build_howto_art() -> void:
    var art := TextureRect.new()
    art.name = "HowToArtwork"
    art.texture = load("res://assets/backgrounds/storyboard/how_to_play_art.jpg")
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.stretch_mode = TextureRect.STRETCH_SCALE
    art.mouse_filter = Control.MOUSE_FILTER_STOP
    art.visible = false
    $UI.add_child(art)
    art.z_index = 10
    var back := Button.new()
    back.name = "HowToBackHitTarget"
    back.text = ""
    back.focus_mode = Control.FOCUS_NONE
    # The tutorial artwork already contains its BACK lettering. Keep only an invisible
    # touch target on top of that lettering so it is not drawn twice.
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0, 0, 0, 0)
    st.border_color = Color(0, 0, 0, 0)
    st.set_border_width_all(0)
    st.set_corner_radius_all(0)
    back.add_theme_stylebox_override("normal", st)
    back.add_theme_stylebox_override("hover", st)
    back.add_theme_stylebox_override("pressed", st)
    back.add_theme_color_override("font_color", Color(1, 1, 1, 0))
    art.add_child(back)
    back.pressed.connect(func(): art.hide())

func _layout_menu() -> void:
    var s := get_viewport_rect().size
    var panel_w := minf(560.0, s.x * 0.47)
    var panel_h := minf(470.0, s.y * 0.84)
    menu_panel.position = Vector2(s.x - panel_w - s.x * 0.04, (s.y - panel_h) * 0.5)
    menu_panel.size = Vector2(panel_w, panel_h)
    var left := menu_panel.position.x + 28
    var width := panel_w - 56
    $UI/PlayButton.position = Vector2(left, menu_panel.position.y + panel_h * 0.42)
    $UI/PlayButton.size = Vector2(width, 72)
    $UI/HowToPlayButton.position = Vector2(left, menu_panel.position.y + panel_h * 0.62)
    $UI/HowToPlayButton.size = Vector2(width, 54)
    $UI/QuitButton.position = Vector2(left, menu_panel.position.y + panel_h * 0.78)
    $UI/QuitButton.size = Vector2(width, 54)
    if $UI.has_node("HowToArtwork"):
        var art: TextureRect = $UI/HowToArtwork
        var back: Button = art.get_node("HowToBackHitTarget")
        back.position = Vector2(s.x * 0.41, s.y * 0.87)
        back.size = Vector2(s.x * 0.18, s.y * 0.08)

func _on_play() -> void:
    _play_ui_click()
    if is_instance_valid(ambience_player): ambience_player.stop()
    GameFlow.start_new_game()

func _on_how_to_play() -> void:
    _play_ui_click()
    $UI/HowToArtwork.show()

func _on_quit() -> void:
    _play_ui_click()
    GameFlow.quit_game()
