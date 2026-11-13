extends Node
var level
func _ready() -> void:
	ArchiveSession.persist_enabled = false
	ArchiveSession.reset()
	level = load("res://archive_room/scenes/ArchiveLevel.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	# Dispatch actual GUI pointer events instead of invoking signals.
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(800,390)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(800,390)
	down.pressed = true
	get_viewport().push_input(down, true)
	var up = down.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	if level.current_view != "desk":
		push_error("Pointer should navigate to desk")
		get_tree().quit(1)
		return
	motion.position = Vector2(950,360)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var laptop = down.duplicate()
	laptop.position = Vector2(950,360)
	get_viewport().push_input(laptop, true)
	var laptop_up = laptop.duplicate()
	laptop_up.pressed = false
	get_viewport().push_input(laptop_up, true)
	await get_tree().process_frame
	if level.toast_label.text != "It’s broken.":
		push_error("Pointer should activate laptop")
		get_tree().quit(1)
		return
	# Screen-touch events exercise the explicit single-finger GUI bridge.
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(450,300)
	touch.pressed = true
	get_viewport().push_input(touch, true)
	await get_tree().process_frame
	var touch_up = touch.duplicate()
	touch_up.pressed = false
	get_viewport().push_input(touch_up, true)
	await get_tree().process_frame
	if not ArchiveSession.photo_seen:
		push_error("Touch should inspect woman’s framed portrait")
		get_tree().quit(1)
		return
	print("PASS: GUI pointer navigation, laptop hit area, and touch-to-mouse photo interaction")
	level.stop_audio()
	await get_tree().create_timer(0.2).timeout
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
