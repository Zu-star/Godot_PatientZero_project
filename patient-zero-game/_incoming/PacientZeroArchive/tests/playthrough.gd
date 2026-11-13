extends Node
var failures = 0
var checks = 0
var level
var captures = false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)

func press(id: String) -> void:
	var b = level.find_child(id, true, false)
	check(b != null and b is Button, "Interactive node exists: " + id)
	if b: b.pressed.emit()
	await get_tree().process_frame

func capture(name_: String) -> void:
	if not captures: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + name_ + ".png")

func _ready() -> void:
	captures = "--capture" in OS.get_cmdline_user_args()
	ArchiveSession.save_path = "user://archive_automated_test.json"
	ArchiveSession.persist_enabled = false
	ArchiveSession.reset()
	level = load("res://archive_room/scenes/ArchiveLevel.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	check(not ArchiveSession.try_code("7416"), "Code cannot bypass shelf puzzle")
	check(not ArchiveSession.collect_card(), "Cannot collect card from locked box")
	check(not ArchiveSession.unlock_door(), "Door cannot unlock without card")
	await capture("01_room")
	await press("QuarantineDoor")
	check(not ArchiveSession.door_unlocked, "Door stays locked on initial tap")
	await press("Desk")
	await press("BrokenLaptop")
	check(level.toast_label.text == "It’s broken.", "Laptop interaction text")
	await capture("02_desk")
	await press("FramedPhoto")
	check(ArchiveSession.photo_seen, "Woman photo can be inspected before solving shelf")
	await press("Close")
	await press("Back")
	await press("ArchiveShelf")
	await capture("03_shelf")
	await press("ArchiveBox3")
	check(level.current_view == "shelves", "Records gated before sorting")
	await press("RolledNote")
	check(ArchiveSession.note_read, "Hidden rolled note reveals readable rules")
	await capture("04_rules")
	await press("Close")
	await press("ArchiveLabel1")
	await press("ArchiveLabel3")
	await get_tree().create_timer(0.4).timeout
	check(ArchiveSession.shelf_solved, "Animated label swap solves exact unique order")
	check(ArchiveSession.labels == ArchiveSession.SOLUTION, "Final label order matches rules")
	await press("ArchiveLabel3")
	check(level.current_view == "discovery", "Transfers reveals records and box together")
	await capture("05_discovery")
	await press("TransferRecords")
	await press("NextRecord")
	check(level.record_page == 1, "Can browse to matching woman agent")
	await capture("06_records")
	await press("NextRecord")
	await press("NextRecord")
	check(level.record_page == 0, "Records cycle without losing progress")
	await press("Close")
	await press("ChainedBox")
	await press("Digit0")
	await press("UnlockBox")
	check(not ArchiveSession.box_open, "Incomplete code rejected")
	await press("Digit0")
	await press("Digit0")
	await press("Digit0")
	await press("UnlockBox")
	check(not ArchiveSession.box_open and level.entered_code.is_empty(), "Wrong code rejected and cleared")
	await capture("07_lock")
	for digit in [7,4,1,6]: await press("Digit%d" % digit)
	await press("UnlockBox")
	check(ArchiveSession.box_open and not ArchiveSession.has_card, "Code opens box but requires collecting card")
	await capture("08_card")
	await press("CollectCard")
	check(ArchiveSession.has_card, "Card added to inventory")
	check(not ArchiveSession.collect_card(), "Card cannot be collected twice")
	await press("Back")
	await press("Back")
	await press("InventoryCard") # Deselect auto-selected card.
	await press("CardReader")
	check(not ArchiveSession.door_unlocked, "Inventory card must be selected")
	await press("InventoryCard")
	await press("CardReader")
	check(ArchiveSession.door_unlocked, "Selected card unlocks quarantine door")
	var signals_seen = [0]
	level.quarantine_entered.connect(func(): signals_seen[0] += 1)
	await press("OpenDoor")
	check(ArchiveSession.completed and signals_seen[0] == 1, "Exit completes level and emits transition signal")
	await capture("09_complete")
	level.complete_level()
	check(signals_seen[0] == 1, "Completion signal fires once")
	ArchiveSession.persist_enabled = true
	ArchiveSession.commit()
	ArchiveSession.labels = ArchiveSession.INITIAL.duplicate()
	ArchiveSession.has_card = false
	ArchiveSession.load_progress()
	check(ArchiveSession.completed and ArchiveSession.has_card and ArchiveSession.shelf_solved, "Save/load restores puzzle and inventory state")
	ArchiveSession.reset()
	check(not ArchiveSession.has_card and not ArchiveSession.shelf_solved and not ArchiveSession.completed, "Restart clears progression")
	DirAccess.remove_absolute(ArchiveSession.save_path)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	level.stop_audio()
	await get_tree().create_timer(0.2).timeout
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
