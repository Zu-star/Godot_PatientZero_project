extends Control

const MENU_SCENE := "res://scenes/menu.tscn"
const ROOM_2_SCENE := "res://scenes/room_2.tscn"
const QUESTIONS: Array[Dictionary] = [
    {"question": "What number comes next?\n3, 6, 12, 24, ...", "answers": ["30", "36", "48", "42"], "correct": 2, "hint": "Each number is doubled."},
    {"question": "Which number does NOT belong?\n2, 3, 5, 9, 11", "answers": ["2", "5", "9", "11"], "correct": 2, "hint": "The others are prime numbers."},
    {"question": "Complete the pattern.\n1, 1, 2, 3, 5, ...", "answers": ["6", "7", "8", "9"], "correct": 2, "hint": "Add the previous two numbers."},
    {"question": "Four machines make four vials in four minutes.\nHow long for eight machines to make eight vials?", "answers": ["2 minutes", "4 minutes", "8 minutes", "16 minutes"], "correct": 1, "hint": "Each machine makes one vial in four minutes."},
    {"question": "All red files are locked. This file is red.\nWhat must be true?", "answers": ["It is locked", "It is open", "It is missing", "We cannot tell"], "correct": 0, "hint": "Apply the first statement to this file."},
    {"question": "What comes next?\n10, 7, 4, 1, ...", "answers": ["0", "-1", "-2", "-3"], "correct": 2, "hint": "Subtract 3 each time."}
]

var remaining_time: float = 60.0
var attempts_left: int = 3
var question_cursor: int = 0
var current_question: Dictionary = {}
var key_acquired := false
var game_finished := false
var is_paused := false
var feedback_label: Label
var answer_buttons: Array[Button] = []
var horror_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var zombie_overlay: ColorRect
var inventory_key: TextureButton
var inventory_label: Label
var computer_search_badge: Button
var dragging_key := false
var key_home_position := Vector2.ZERO
var tick_accumulator := 0.0
var instruction_bubble: PanelContainer
var instruction_header: Label
var instruction_tail: Polygon2D
var instruction_tail_outline: Line2D
var instruction_accent: ColorRect

func _ready() -> void:
    if has_node("/root/ZombieAmbience"):
        ZombieAmbience.resume_ambience()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _style_all()
    _create_instruction_bubble()
    _layout_scene()
    _setup_audio()
    var pulse := create_tween().set_loops()
    pulse.tween_property($WorldHotspots/ComputerHotspot, "modulate:a", 0.72, 0.8)
    pulse.tween_property($WorldHotspots/ComputerHotspot, "modulate:a", 1.0, 0.8)
    # Ensure the hotspot is above the background and receives touch input on iOS.
    $WorldHotspots.z_index = 10
    $WorldHotspots.mouse_filter = Control.MOUSE_FILTER_PASS
    # HUD fills the screen; it must not intercept taps meant for world hotspots.
    $HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $WorldHotspots/ComputerHotspot.mouse_filter = Control.MOUSE_FILTER_STOP
    $WorldHotspots/DoorHotspot.mouse_filter = Control.MOUSE_FILTER_STOP
    $ComputerPuzzle.z_index = 30
    $KeyReward.z_index = 31
    $GameOverPanel.z_index = 41
    $PausePanel.z_index = 41
    # The large computer hotspot remains clickable but is visually invisible. A separate
    # round search badge sits centered on the monitor for a clear visual target.
    $WorldHotspots/ComputerHotspot.icon = null
    $WorldHotspots/ComputerHotspot.text = ""
    var invisible_style := StyleBoxFlat.new()
    invisible_style.bg_color = Color(0, 0, 0, 0)
    invisible_style.border_color = Color(0, 0, 0, 0)
    invisible_style.set_border_width_all(0)
    invisible_style.set_corner_radius_all(0)
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        $WorldHotspots/ComputerHotspot.add_theme_stylebox_override(state, invisible_style)
    # The door is an invisible touch target over the actual door artwork.
    $WorldHotspots/DoorHotspot.icon = null
    $WorldHotspots/DoorHotspot.text = ""
    $WorldHotspots/DoorLabel.hide()
    var invisible_door_style := StyleBoxFlat.new()
    invisible_door_style.bg_color = Color(0, 0, 0, 0)
    invisible_door_style.border_color = Color(0, 0, 0, 0)
    invisible_door_style.set_border_width_all(0)
    invisible_door_style.set_corner_radius_all(0)
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        $WorldHotspots/DoorHotspot.add_theme_stylebox_override(state, invisible_door_style)
    $WorldHotspots/ComputerHotspot.pressed.connect(_on_computer_pressed)
    $WorldHotspots/DoorHotspot.pressed.connect(_on_door_pressed)
    _create_computer_search_badge()
    _layout_scene()
    $HUD/PauseButton.pressed.connect(_on_pause_pressed)
    _build_puzzle_panel()
    _build_reward_panel()
    _build_game_over_panel()
    _build_pause_panel()
    _update_hud()
    get_viewport().size_changed.connect(_layout_scene)

func _create_computer_search_badge() -> void:
    if is_instance_valid(computer_search_badge):
        computer_search_badge.queue_free()
    computer_search_badge = Button.new()
    computer_search_badge.name = "ComputerSearchBadge"
    computer_search_badge.focus_mode = Control.FOCUS_NONE
    computer_search_badge.icon = null
    computer_search_badge.text = ""
    var badge_style := StyleBoxFlat.new()
    badge_style.bg_color = Color(0.005, 0.025, 0.04, 0.88)
    badge_style.border_color = Color(0.05, 0.82, 1.0, 1.0)
    badge_style.set_border_width_all(2)
    badge_style.set_corner_radius_all(44)
    computer_search_badge.add_theme_stylebox_override("normal", badge_style)
    computer_search_badge.add_theme_stylebox_override("hover", badge_style)
    computer_search_badge.add_theme_stylebox_override("pressed", badge_style)
    computer_search_badge.pressed.connect(_on_computer_pressed)
    $WorldHotspots.add_child(computer_search_badge)
    computer_search_badge.z_index = 2
    var glyph := TextureRect.new()
    glyph.name = "CenteredSearchGlyph"
    glyph.texture = load("res://assets/ui/search_icon.png")
    glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    glyph.anchor_left = 0.18
    glyph.anchor_top = 0.18
    glyph.anchor_right = 0.82
    glyph.anchor_bottom = 0.82
    glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    computer_search_badge.add_child(glyph)

func _setup_audio() -> void:
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "LabAmbience"
    var ambience := load("res://assets/sounds/lab_ambience.wav") as AudioStreamWAV
    if ambience:
        ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
        ambience_player.stream = ambience
        ambience_player.volume_db = -28.0
        add_child(ambience_player)
        ambience_player.play()
    horror_player = AudioStreamPlayer.new()
    horror_player.name = "HorrorStinger"
    horror_player.stream = load("res://assets/sounds/zombie_stinger.wav")
    horror_player.volume_db = 0.0
    add_child(horror_player)

func _play_sfx(file_name: String, volume_db: float = -5.0) -> void:
    var stream := load("res://assets/sounds/" + file_name) as AudioStream
    if stream == null:
        return
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume_db
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _process(delta: float) -> void:
    if game_finished or is_paused:
        return
    remaining_time -= delta
    tick_accumulator += delta
    if remaining_time <= 10.0 and tick_accumulator >= 1.0:
        tick_accumulator = 0.0
        _play_sfx("timer_tick.wav", -10.0)
    if remaining_time <= 0.0:
        remaining_time = 0.0
        _update_hud()
        _end_game(false, "Time is up. The lab has sealed itself.")
        return
    _update_timer_label()

func _layout_scene() -> void:
    var s := get_viewport_rect().size
    var scale_x := s.x / 1280.0
    var scale_y := s.y / 720.0
    # Large touch target covers the whole computer monitor, keyboard and nearby desk.
    # The background image is 1672x941 and scales almost exactly to the 1280x720 viewport.
    # On mobile, users can tap anywhere on the computer rather than hitting a tiny icon.
    $WorldHotspots/ComputerHotspot.position = Vector2(45 * scale_x, 220 * scale_y)
    $WorldHotspots/ComputerHotspot.size = Vector2(390 * scale_x, 300 * scale_y)
    if is_instance_valid(computer_search_badge):
        computer_search_badge.position = Vector2(175 * scale_x, 310 * scale_y)
        computer_search_badge.size = Vector2(88 * scale_x, 88 * scale_y)
    $WorldHotspots/DoorHotspot.position = Vector2(870 * scale_x, 25 * scale_y)
    $WorldHotspots/DoorHotspot.size = Vector2(390 * scale_x, 660 * scale_y)
    $WorldHotspots/ComputerLabel.position = Vector2(155 * scale_x, 500 * scale_y)
    $WorldHotspots/ComputerLabel.size = Vector2(300 * scale_x, 36 * scale_y)
    $WorldHotspots/DoorLabel.hide()
    $HUD/TimerLabel.position = Vector2(24 * scale_x, 18 * scale_y)
    $HUD/TimerLabel.size = Vector2(150 * scale_x, 52 * scale_y)
    $HUD/AttemptsLabel.position = Vector2(185 * scale_x, 18 * scale_y)
    $HUD/AttemptsLabel.size = Vector2(210 * scale_x, 52 * scale_y)
    # Radio-message speech bubble along the bottom, inspired by the reference UI.
    var bubble_w := minf(900.0 * scale_x, s.x - 48.0 * scale_x)
    var bubble_x := (s.x - bubble_w) * 0.5
    instruction_bubble.position = Vector2(bubble_x, 604.0 * scale_y)
    instruction_bubble.size = Vector2(bubble_w, 72.0 * scale_y)
    instruction_tail.position = Vector2(bubble_x + 28.0 * scale_x, 668.0 * scale_y)
    instruction_tail.scale = Vector2(scale_x, scale_y)
    instruction_tail_outline.position = instruction_tail.position
    instruction_tail_outline.scale = Vector2(scale_x, scale_y)
    instruction_accent.position = Vector2(bubble_x + 10.0 * scale_x, 616.0 * scale_y)
    instruction_accent.size = Vector2(3.0 * scale_x, 46.0 * scale_y)
    instruction_header.position = Vector2(bubble_x + 24.0 * scale_x, 608.0 * scale_y)
    instruction_header.size = Vector2(bubble_w - 48.0 * scale_x, 1.0 * scale_y)
    instruction_header.hide()
    $HUD/InstructionLabel.position = Vector2(bubble_x + 24.0 * scale_x, 615.0 * scale_y)
    $HUD/InstructionLabel.size = Vector2(bubble_w - 48.0 * scale_x, 48.0 * scale_y)
    $HUD/PauseButton.position = Vector2((s.x - 88) * scale_x, 18 * scale_y)
    $HUD/PauseButton.size = Vector2(62 * scale_x, 58 * scale_y)
    $ComputerPuzzle.position = Vector2((s.x - 610 * scale_x) / 2.0, 90 * scale_y)
    $ComputerPuzzle.size = Vector2(610 * scale_x, 540 * scale_y)
    var reward_h := 370.0 * scale_y
    $KeyReward.position = Vector2((s.x - 440 * scale_x) / 2.0, (s.y - reward_h) / 2.0)
    $KeyReward.size = Vector2(440 * scale_x, reward_h)
    var game_over_h := 230.0 * scale_y
    $GameOverPanel.position = Vector2((s.x - 600 * scale_x) / 2.0, (s.y - game_over_h) / 2.0)
    $GameOverPanel.size = Vector2(600 * scale_x, game_over_h)
    var pause_h := 200.0 * scale_y
    $PausePanel.position = Vector2((s.x - 430 * scale_x) / 2.0, (s.y - pause_h) / 2.0)
    $PausePanel.size = Vector2(430 * scale_x, pause_h)
    if is_instance_valid(inventory_key):
        inventory_key.position = Vector2(34 * scale_x, 465 * scale_y)
        inventory_key.size = Vector2(150 * scale_x, 150 * scale_y)
        key_home_position = inventory_key.position
    if is_instance_valid(inventory_label):
        inventory_label.position = Vector2(190 * scale_x, 505 * scale_y)
        inventory_label.size = Vector2(280 * scale_x, 58 * scale_y)

func _create_instruction_bubble() -> void:
    # A compact, game-themed radio/speech bubble frames the contextual hint.
    # It ignores input so it never blocks the computer or door touch targets.
    instruction_tail = Polygon2D.new()
    instruction_tail.name = "InstructionBubbleTail"
    instruction_tail.polygon = PackedVector2Array([Vector2(0, 0), Vector2(48, 0), Vector2(17, 23)])
    instruction_tail.color = Color(0.008, 0.022, 0.032, 0.97)
    $HUD.add_child(instruction_tail)
    $HUD.move_child(instruction_tail, 0)

    instruction_tail_outline = Line2D.new()
    instruction_tail_outline.name = "InstructionBubbleTailOutline"
    instruction_tail_outline.points = PackedVector2Array([Vector2(0, 0), Vector2(17, 23), Vector2(48, 0)])
    instruction_tail_outline.closed = false
    instruction_tail_outline.width = 2.0
    instruction_tail_outline.default_color = Color(0.08, 0.73, 0.86, 0.95)
    $HUD.add_child(instruction_tail_outline)
    $HUD.move_child(instruction_tail_outline, 1)

    instruction_bubble = PanelContainer.new()
    instruction_bubble.name = "InstructionSpeechBubble"
    instruction_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bubble_style := StyleBoxFlat.new()
    bubble_style.bg_color = Color(0.008, 0.022, 0.032, 0.96)
    bubble_style.border_color = Color(0.08, 0.73, 0.86, 0.95)
    bubble_style.set_border_width_all(2)
    bubble_style.set_corner_radius_all(12)
    bubble_style.content_margin_left = 12
    bubble_style.content_margin_right = 12
    bubble_style.content_margin_top = 8
    bubble_style.content_margin_bottom = 8
    instruction_bubble.add_theme_stylebox_override("panel", bubble_style)
    $HUD.add_child(instruction_bubble)
    $HUD.move_child(instruction_bubble, 2)

    instruction_accent = ColorRect.new()
    instruction_accent.name = "InstructionBubbleAccent"
    instruction_accent.color = Color(0.78, 0.08, 0.13, 0.98)
    instruction_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(instruction_accent)
    $HUD.move_child(instruction_accent, 3)

    instruction_header = Label.new()
    instruction_header.name = "InstructionBubbleHeader"
    instruction_header.text = ""
    instruction_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    instruction_header.add_theme_font_size_override("font_size", 1)
    instruction_header.add_theme_color_override("font_color", Color(0.38, 0.88, 0.93))
    instruction_header.hide()
    $HUD.add_child(instruction_header)
    instruction_header.z_index = 2
    $HUD/InstructionLabel.z_index = 2
    $HUD/InstructionLabel.add_theme_font_size_override("font_size", 18)
    $HUD/InstructionLabel.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
    $HUD/InstructionLabel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    $HUD/InstructionLabel.add_theme_constant_override("shadow_offset_x", 1)
    $HUD/InstructionLabel.add_theme_constant_override("shadow_offset_y", 1)

func _style_all() -> void:
    _style_panel($ComputerPuzzle, Color(0.012, 0.025, 0.04, 0.98), Color(0.10, 0.70, 0.92))
    _style_panel($KeyReward, Color(0.015, 0.018, 0.02, 0.98), Color(0.96, 0.61, 0.12))
    _style_panel($GameOverPanel, Color(0.02, 0.012, 0.02, 0.86), Color(0.92, 0.08, 0.13))
    _style_panel($PausePanel, Color(0.012, 0.025, 0.04, 0.98), Color(0.10, 0.70, 0.92))
    _style_button($WorldHotspots/ComputerHotspot, true)
    _style_button($WorldHotspots/DoorHotspot, true)
    _style_button($HUD/PauseButton, false)
    var search_texture: Texture2D = load("res://assets/ui/search_icon.png")
    $WorldHotspots/ComputerHotspot.text = ""
    $WorldHotspots/DoorHotspot.text = ""
    $WorldHotspots/ComputerHotspot.icon = search_texture
    $WorldHotspots/DoorHotspot.icon = null
    $WorldHotspots/ComputerHotspot.expand_icon = true
    $WorldHotspots/ComputerHotspot.add_theme_constant_override("icon_max_width", 72)
    $WorldHotspots/ComputerLabel.add_theme_font_size_override("font_size", 16)
    $WorldHotspots/DoorLabel.add_theme_font_size_override("font_size", 16)
    $WorldHotspots/ComputerLabel.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
    $WorldHotspots/DoorLabel.add_theme_color_override("font_color", Color(0.95, 0.78, 0.70))
    $HUD/TimerLabel.add_theme_font_size_override("font_size", 28)
    $HUD/AttemptsLabel.add_theme_font_size_override("font_size", 23)
    $HUD/InstructionLabel.add_theme_font_size_override("font_size", 20)
    $HUD/InstructionLabel.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97))
    $HUD/InstructionLabel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
    $HUD/InstructionLabel.add_theme_constant_override("shadow_offset_x", 2)
    $HUD/InstructionLabel.add_theme_constant_override("shadow_offset_y", 2)

func _style_button(button: Button, primary: bool) -> void:
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    var is_computer_hotspot := button == $WorldHotspots/ComputerHotspot
    normal.bg_color = Color(0.01, 0.045, 0.07, 0.12 if is_computer_hotspot else 0.90)
    normal.border_color = Color(0.10, 0.75, 0.95, 0.45 if is_computer_hotspot else 1.0) if primary else Color(0.48, 0.60, 0.68, 0.95)
    normal.border_width_left = 2
    normal.border_width_right = 2
    normal.border_width_top = 2
    normal.border_width_bottom = 2
    var radius := 18 if is_computer_hotspot else (46 if button == $WorldHotspots/DoorHotspot else 16)
    normal.corner_radius_top_left = radius
    normal.corner_radius_top_right = radius
    normal.corner_radius_bottom_left = radius
    normal.corner_radius_bottom_right = radius
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.015, 0.13, 0.18, 0.32 if is_computer_hotspot else 0.98)
    hover.border_color = Color(0.45, 0.92, 1.0, 1)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)

func _style_panel(panel: PanelContainer, background: Color, border: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 20
    style.content_margin_bottom = 20
    panel.add_theme_stylebox_override("panel", style)

func _make_label(text: String, size: int, color: Color = Color(0.90, 0.94, 0.97)) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _make_action_button(text: String, size: int = 20) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 50)
    button.add_theme_font_size_override("font_size", size)
    _style_button(button, false)
    return button

func _build_puzzle_panel() -> void:
    var box: VBoxContainer = $ComputerPuzzle/PanelContent
    box.add_theme_constant_override("separation", 12)
    var heading := _make_label("LAB COMPUTER  //  LOGIC TEST", 24, Color(0.25, 0.82, 1.0))
    box.add_child(heading)
    var question := _make_label("", 22)
    question.name = "QuestionLabel"
    question.custom_minimum_size = Vector2(0, 90)
    box.add_child(question)
    feedback_label = _make_label("Choose the correct answer.", 16, Color(0.60, 0.80, 0.89))
    feedback_label.name = "FeedbackLabel"
    box.add_child(feedback_label)
    for i in range(4):
        var button := _make_action_button("Answer", 19)
        button.custom_minimum_size = Vector2(0, 54)
        button.pressed.connect(_on_answer_pressed.bind(i))
        box.add_child(button)
        answer_buttons.append(button)
    var close := _make_action_button("CLOSE", 16)
    close.custom_minimum_size = Vector2(0, 42)
    close.pressed.connect(func(): $ComputerPuzzle.hide())
    box.add_child(close)

func _build_reward_panel() -> void:
    var box: VBoxContainer = $KeyReward/RewardContent
    box.add_theme_constant_override("separation", 7)
    var title := _make_label("AMAZING!", 36, Color(0.30, 1.0, 0.52))
    box.add_child(title)
    var key_image: TextureRect = $KeyReward/KeyImage
    $KeyReward.remove_child(key_image)
    key_image.custom_minimum_size = Vector2(0, 150)
    key_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    box.add_child(key_image)
    var message := _make_label("You received a key.", 20)
    box.add_child(message)
    var take := _make_action_button("TAKE KEY", 22)
    take.custom_minimum_size = Vector2(0, 56)
    take.pressed.connect(_on_take_key)
    box.add_child(take)

func _build_game_over_panel() -> void:
    var box: VBoxContainer = $GameOverPanel/GameOverContent
    box.add_theme_constant_override("separation", 8)
    box.add_child(_make_label("GAME OVER  //  YOU DIED", 36, Color(1.0, 0.12, 0.16)))
    box.add_child(_make_label("", 18))
    box.get_child(1).name = "ReasonLabel"
    var retry := _make_action_button("TRY AGAIN", 22)
    retry.custom_minimum_size = Vector2(0, 46)
    retry.pressed.connect(_restart_game)
    box.add_child(retry)
    var menu := _make_action_button("MAIN MENU", 18)
    menu.custom_minimum_size = Vector2(0, 46)
    menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
    box.add_child(menu)

func _build_pause_panel() -> void:
    var box: VBoxContainer = $PausePanel/PauseContent
    box.add_theme_constant_override("separation", 8)
    box.add_child(_make_label("PAUSED", 32, Color(0.25, 0.82, 1.0)))
    var resume := _make_action_button("RESUME", 22)
    resume.custom_minimum_size = Vector2(0, 44)
    resume.pressed.connect(_on_resume_pressed)
    box.add_child(resume)
    var menu := _make_action_button("MAIN MENU", 18)
    menu.custom_minimum_size = Vector2(0, 44)
    menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
    box.add_child(menu)

func _on_computer_pressed() -> void:
    print("COMPUTER TAP RECEIVED — opening logic puzzle")
    if game_finished or is_paused or key_acquired or $KeyReward.visible:
        return
    if current_question.is_empty():
        current_question = QUESTIONS[question_cursor % QUESTIONS.size()]
        question_cursor += 1
    var box: VBoxContainer = $ComputerPuzzle/PanelContent
    box.get_node("QuestionLabel").text = str(current_question["question"])
    for i in range(answer_buttons.size()):
        answer_buttons[i].text = str(current_question["answers"][i])
        answer_buttons[i].disabled = false
    feedback_label.text = "Choose the correct answer."
    feedback_label.add_theme_color_override("font_color", Color(0.60, 0.80, 0.89))
    _play_sfx("computer_beep.wav", -5.0)
    $ComputerPuzzle.show()
    $ComputerPuzzle.move_to_front()

func _on_answer_pressed(index: int) -> void:
    if game_finished or current_question.is_empty():
        return
    if index == int(current_question["correct"]):
        _play_sfx("correct_answer.wav", -2.0)
        $ComputerPuzzle.hide()
        $KeyReward.show()
        $HUD/InstructionLabel.text = "Correct! Take the key to unlock the exit door."
        for button in answer_buttons:
            button.disabled = true
    else:
        attempts_left -= 1
        _update_hud()
        feedback_label.text = "Not quite. " + str(current_question["hint"]) + "  Attempts left: " + str(attempts_left)
        feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
        if attempts_left <= 0:
            _end_game(false, "You used all three attempts.")

func _on_take_key() -> void:
    if game_finished:
        return
    _play_sfx("key_pickup.mp3", -3.0)
    key_acquired = true
    $KeyReward.hide()
    _create_inventory_key()
    $WorldHotspots/ComputerHotspot.hide()
    $WorldHotspots/ComputerLabel.hide()
    if is_instance_valid(computer_search_badge): computer_search_badge.hide()
    $WorldHotspots/DoorLabel.text = "USE KEY TO ESCAPE"
    $HUD/InstructionLabel.text = "KEY ACQUIRED — drag the key to the exit door!"

func _on_door_pressed() -> void:
    if game_finished or is_paused:
        return
    if key_acquired:
        _escape_to_room_2()
    else:
        $HUD/InstructionLabel.text = "The exit is locked. Solve the computer puzzle to get the key."

func _on_pause_pressed() -> void:
    if game_finished:
        return
    is_paused = true
    $PausePanel.show()

func _on_resume_pressed() -> void:
    is_paused = false
    $PausePanel.hide()

func _update_hud() -> void:
    $HUD/AttemptsLabel.text = "ATTEMPTS: " + str(attempts_left) + "/3"
    _update_timer_label()

func _update_timer_label() -> void:
    var seconds := int(ceil(remaining_time))
    $HUD/TimerLabel.text = "%02d:%02d" % [seconds / 60, seconds % 60]
    if remaining_time <= 10.0:
        $HUD/TimerLabel.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
    else:
        $HUD/TimerLabel.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))

func _end_game(won: bool, reason: String) -> void:
    if game_finished:
        return
    game_finished = true
    is_paused = false
    $ComputerPuzzle.hide()
    $KeyReward.hide()
    $PausePanel.hide()
    var box: VBoxContainer = $GameOverPanel/GameOverContent
    box.get_node("ReasonLabel").text = reason
    box.get_child(0).text = "ESCAPED!" if won else "YOU DIED"
    if not won:
        # Let the zombie breach animation and sting play before showing the game-over card.
        _play_zombie_attack()
        $GameOverPanel.hide()
        get_tree().create_timer(2.45).timeout.connect(_show_game_over_panel)
    else:
        $GameOverPanel.show()

func _show_game_over_panel() -> void:
    if is_instance_valid($GameOverPanel):
        # Keep the zombie attack artwork on screen behind the final retry/menu choices.
        if not has_node("GameOverBackdrop"):
            var art := TextureRect.new()
            art.name = "GameOverBackdrop"
            art.texture = load("res://assets/backgrounds/storyboard/zombie_attack_art.jpg")
            art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            art.stretch_mode = TextureRect.STRETCH_SCALE
            art.mouse_filter = Control.MOUSE_FILTER_IGNORE
            art.z_index = 38
            add_child(art)
            var shade := ColorRect.new()
            shade.name = "GameOverBackdropShade"
            shade.color = Color(0.10, 0.0, 0.015, 0.42)
            shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
            shade.z_index = 39
            add_child(shade)
        $GameOverPanel.show()
        $GameOverPanel.move_to_front()

func _restart_game() -> void:
    get_tree().reload_current_scene()


func _create_inventory_key() -> void:
    if is_instance_valid(inventory_key):
        inventory_key.queue_free()
    if is_instance_valid(inventory_label):
        inventory_label.queue_free()
    inventory_key = TextureButton.new()
    inventory_key.name = "DraggableInventoryKey"
    inventory_key.texture_normal = load("res://assets/ui/key_icon.png")
    inventory_key.texture_hover = load("res://assets/ui/key_icon.png")
    inventory_key.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    var s := get_viewport_rect().size
    var scale_x := s.x / 1280.0
    var scale_y := s.y / 720.0
    inventory_key.position = Vector2(34 * scale_x, 465 * scale_y)
    inventory_key.size = Vector2(150 * scale_x, 150 * scale_y)
    inventory_key.tooltip_text = "Drag key to exit door"
    inventory_key.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.005, 0.025, 0.035, 0.98)
    style.border_color = Color(0.35, 1.0, 0.55, 1.0)
    style.set_border_width_all(3)
    style.set_corner_radius_all(52)
    inventory_key.add_theme_stylebox_override("normal", style)
    inventory_key.add_theme_stylebox_override("hover", style)
    inventory_key.gui_input.connect(_on_inventory_key_input)
    $HUD.add_child(inventory_key)
    inventory_key.z_index = 15
    inventory_label = Label.new()
    inventory_label.name = "InventoryKeyLabel"
    inventory_label.text = "KEY ACQUIRED\nDRAG TO EXIT"
    inventory_label.position = Vector2(190 * scale_x, 505 * scale_y)
    inventory_label.size = Vector2(280 * scale_x, 58 * scale_y)
    inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    inventory_label.add_theme_font_size_override("font_size", 20)
    inventory_label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.75))
    inventory_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    inventory_label.add_theme_constant_override("shadow_offset_x", 2)
    inventory_label.add_theme_constant_override("shadow_offset_y", 2)
    inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(inventory_label)
    inventory_label.z_index = 15
    key_home_position = inventory_key.position

func _on_inventory_key_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            dragging_key = true
        else:
            dragging_key = false
            if $WorldHotspots/DoorHotspot.get_global_rect().has_point(get_global_mouse_position()):
                _escape_to_room_2()
            elif is_instance_valid(inventory_key):
                inventory_key.position = key_home_position
    elif event is InputEventScreenTouch:
        if event.pressed:
            dragging_key = true
        else:
            dragging_key = false
            if $WorldHotspots/DoorHotspot.get_global_rect().has_point(event.position):
                _escape_to_room_2()
            elif is_instance_valid(inventory_key):
                inventory_key.position = key_home_position

func _input(event: InputEvent) -> void:
    if not dragging_key or not is_instance_valid(inventory_key):
        return
    var point := Vector2.ZERO
    if event is InputEventMouseMotion:
        point = event.position
    elif event is InputEventScreenDrag:
        point = event.position
    else:
        return
    inventory_key.global_position = point - inventory_key.size * 0.5

func _escape_to_room_2() -> void:
    if not key_acquired or game_finished:
        return
    ZombieAmbience.play_one_shot("door_open.wav", -3.0)
    game_finished = true
    if is_instance_valid(ambience_player): ambience_player.stop()
    var fade := ColorRect.new()
    fade.color = Color(0.0, 0.0, 0.0, 0.0)
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fade)
    var tween := create_tween()
    tween.tween_property(fade, "color:a", 1.0, 0.65)
    tween.tween_callback(func(): GameFlow.room_finished(1))

func _play_zombie_attack() -> void:
    if is_instance_valid(ambience_player): ambience_player.stop()
    if has_node("/root/ZombieAmbience"):
        ZombieAmbience.play_lose_sound()
    elif is_instance_valid(horror_player):
        horror_player.stop()
        horror_player.volume_db = 0.0
        horror_player.stream = load("res://assets/sounds/zombie_attack.mp3")
        horror_player.play()
    zombie_overlay = ColorRect.new()
    zombie_overlay.color = Color(0.30, 0.0, 0.015, 0.0)
    zombie_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    zombie_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(zombie_overlay)
    zombie_overlay.z_index = 60
    var zombie_art := TextureRect.new()
    zombie_art.texture = load("res://assets/backgrounds/storyboard/zombie_attack_art.jpg")
    zombie_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    zombie_art.stretch_mode = TextureRect.STRETCH_SCALE
    zombie_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    zombie_art.modulate.a = 0.0
    zombie_overlay.add_child(zombie_art)
    zombie_art.z_index = 1
    zombie_art.scale = Vector2(1.08, 1.08)
    zombie_art.pivot_offset = get_viewport_rect().size * 0.5
    var zombie := Label.new()
    zombie.text = "⚠  CONTAINMENT BREACH  ⚠\n\nTHE INFECTED HAVE ENTERED"
    zombie.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    zombie.position = Vector2(-330, -90)
    zombie.size = Vector2(660, 180)
    zombie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    zombie.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    zombie.add_theme_font_size_override("font_size", 34)
    zombie.add_theme_color_override("font_color", Color(1.0, 0.12, 0.15))
    zombie.add_theme_color_override("font_shadow_color", Color.BLACK)
    zombie.add_theme_constant_override("shadow_offset_x", 4)
    zombie.add_theme_constant_override("shadow_offset_y", 4)
    zombie_overlay.add_child(zombie)
    zombie.modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(zombie_overlay, "color:a", 0.64, 0.22)
    tw.parallel().tween_property(zombie, "modulate:a", 1.0, 0.4)
    tw.parallel().tween_property(zombie_art, "modulate:a", 0.92, 0.45)
    tw.parallel().tween_property(zombie_art, "scale", Vector2(1.0, 1.0), 1.1)
    tw.tween_interval(0.65)
    tw.tween_property(zombie_overlay, "color:a", 0.0, 0.55)
    tw.tween_callback(_remove_zombie_overlay)

func _remove_zombie_overlay() -> void:
    if is_instance_valid(zombie_overlay):
        zombie_overlay.queue_free()
