extends Control

# Shows the 1280x617 FIRST ROOM centred in the 1280x720 game screen, with dark bars above
# and below. GameFlow.ROOMS[1] points to this scene: GameFlow connects room_completed of the
# current scene's root, so the room's own signal is forwarded from here.

signal room_completed

@onready var room: Control = $Stage/FirstRoom

func _ready() -> void:
	room.room_completed.connect(room_completed.emit)
