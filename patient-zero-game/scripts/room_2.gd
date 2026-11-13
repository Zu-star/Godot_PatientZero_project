extends Control

const MENU_SCENE := "res://scenes/menu.tscn"

var buttons_layer: Control

func _ready() -> void:
    # Room 2 is a visual destination placeholder: its own artwork, title, and one menu button.
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_room_title()
    _build_back_button()
    modulate.a = 0.0
    create_tween().tween_property(self, "modulate:a", 1.0, 0.55).from(0.0)

func _build_room_title() -> void:
    var title := Label.new()
    title.name = "Room2Title"
    title.text = "ROOM 2"
    title.anchor_left = 0.0
    title.anchor_right = 1.0
    title.anchor_top = 0.0
    title.anchor_bottom = 0.0
    title.offset_top = 48.0
    title.offset_bottom = 128.0
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_font_override("font", load("res://assets/fonts/NotoSerif-CondensedBold.ttf"))
    title.add_theme_font_size_override("font_size", 56)
    title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
    title.add_theme_constant_override("shadow_offset_x", 3)
    title.add_theme_constant_override("shadow_offset_y", 4)
    add_child(title)

func _build_back_button() -> void:
    var shade := ColorRect.new()
    shade.name = "ButtonBackdrop"
    shade.anchor_left = 0.0
    shade.anchor_right = 1.0
    shade.anchor_top = 1.0
    shade.anchor_bottom = 1.0
    shade.offset_top = -108.0
    shade.offset_bottom = 0.0
    shade.color = Color(0.015, 0.025, 0.035, 0.72)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    var button := Button.new()
    button.name = "BackToMenuButton"
    button.text = "BACK TO MENU"
    button.anchor_left = 0.5
    button.anchor_right = 0.5
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.offset_left = -190.0
    button.offset_right = 190.0
    button.offset_top = -82.0
    button.offset_bottom = -24.0
    button.custom_minimum_size = Vector2(0, 58)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 19)
    button.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.015, 0.025, 0.035, 0.96)
    normal.border_color = Color(0.12, 0.72, 0.86, 0.95)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(9)
    normal.content_margin_left = 18
    normal.content_margin_right = 18
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.025, 0.10, 0.13, 0.98)
    hover.border_color = Color(0.24, 0.88, 1.0, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.pressed.connect(_go_to_menu)
    add_child(button)

func _go_to_menu() -> void:
    get_tree().change_scene_to_file(MENU_SCENE)
