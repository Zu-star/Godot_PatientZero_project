extends Control

# Integration (GameFlow): "Show hotspots" for FIRST ROOM. Draws outlines over the room's own
# hit areas (computer, door, and the key while it is on screen) without changing how the room
# builds them. Same look as the hotspot outlines of rooms 2-4. Added by first_room.gd.

const FILL := Color(0.42, 0.34, 0.55, 0.12)
const BORDER := Color("b6a4bf")

var room: Control

func _init(owner_room: Control) -> void:
	room = owner_room
	name = "HotspotOutlines"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	# Above the hit areas (2) and the key (12), below the task screen (20) and other overlays.
	z_index = 13
	visible = false

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	for node in [room.computer_hotspot, room.door_hotspot, room.key_sprite]:
		if is_instance_valid(node) and (node as Control).visible:
			var r := (node as Control).get_rect()
			draw_rect(r, FILL, true)
			draw_rect(r, BORDER, false, 2.0)
