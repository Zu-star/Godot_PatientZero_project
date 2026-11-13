extends Node
## Persistent level state. The puzzle is independent of its presentation.
signal changed
var save_path = "user://archive_save.json"
const INITIAL = ["DISPOSAL", "TRANSFERS", "STAFF", "INCIDENTS"]
const SOLUTION = ["DISPOSAL", "INCIDENTS", "STAFF", "TRANSFERS"]
const BOX_CODE = "7416"
var labels: Array = INITIAL.duplicate()
var shelf_solved = false
var note_read = false
var photo_seen = false
var records_read = false
var box_open = false
var has_card = false
var door_unlocked = false
var completed = false
var persist_enabled = true

func _ready() -> void:
	load_progress()

func swap_labels(a: int, b: int) -> bool:
	if shelf_solved or a == b or a < 0 or b < 0 or a >= 4 or b >= 4:
		return false
	var temp = labels[a]
	labels[a] = labels[b]
	labels[b] = temp
	shelf_solved = labels == SOLUTION
	commit()
	return shelf_solved

func try_code(code: String) -> bool:
	if not shelf_solved or code != BOX_CODE:
		return false
	box_open = true
	commit()
	return true

func collect_card() -> bool:
	if not box_open or has_card:
		return false
	has_card = true
	commit()
	return true

func unlock_door() -> bool:
	if not has_card:
		return false
	door_unlocked = true
	commit()
	return true

func commit() -> void:
	if persist_enabled:
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"version":1,"labels":labels,"shelf_solved":shelf_solved,
				"note_read":note_read,"photo_seen":photo_seen,"records_read":records_read,
				"box_open":box_open,"has_card":has_card,"door_unlocked":door_unlocked,"completed":completed}))
	changed.emit()

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version") != 1:
		return
	var saved = data.get("labels", [])
	var sorted_saved = saved.duplicate()
	sorted_saved.sort()
	var expected = INITIAL.duplicate()
	expected.sort()
	if sorted_saved != expected:
		return
	labels = saved
	shelf_solved = labels == SOLUTION
	note_read = bool(data.get("note_read", false))
	photo_seen = bool(data.get("photo_seen", false))
	records_read = bool(data.get("records_read", false)) and shelf_solved
	box_open = bool(data.get("box_open", false)) and shelf_solved
	has_card = bool(data.get("has_card", false)) and box_open
	door_unlocked = bool(data.get("door_unlocked", false)) and has_card
	completed = bool(data.get("completed", false)) and door_unlocked

func reset() -> void:
	labels = INITIAL.duplicate()
	shelf_solved = false
	note_read = false
	photo_seen = false
	records_read = false
	box_open = false
	has_card = false
	door_unlocked = false
	completed = false
	commit()

func objective() -> String:
	if completed: return "Archive complete"
	if door_unlocked: return "Enter the quarantine zone"
	if has_card: return "Use the access card at the quarantine door"
	if box_open: return "Collect the quarantine access card"
	if shelf_solved: return "Find the custodian’s code and open the chained box"
	return "Search the archive for quarantine access"
