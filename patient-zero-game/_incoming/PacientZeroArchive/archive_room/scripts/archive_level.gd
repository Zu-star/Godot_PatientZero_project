extends Control
## Standalone, reusable level. All interactive plates, documents and props are separate nodes.
signal quarantine_entered
@export_file("*.tscn") var next_level_scene: String = ""
const INK = Color("241f2c")
const CREAM = Color("e4d9c3")
const AGENTS = [
	{"name":"Mara Voss", "role":"Records auditor", "id":"6082", "transfer":"Central records / review team", "image":"agent_mara.svg"},
	{"name":"Elena Morozova", "role":"Quarantine logistics officer", "id":"7416", "transfer":"Quarantine zone / access custodian", "image":"agent_elena.png"},
	{"name":"Viktor Orlov", "role":"Security liaison", "id":"2953", "transfer":"Perimeter security / night shift", "image":"agent_viktor.svg"}
]
var view: Control
var hud: Control
var modal: Control
var toast_label: Label
var current_view = "room"
var selected_label = -1
var label_nodes: Array[Button] = []
var card_selected = false
var show_hotspots = false
var entered_code = ""
var code_display: Label
var lock_feedback: Label
var toast_serial = 0
var record_page = 0
var hint_step = 0
var busy = false
var objective_label: Label
var inventory_button: Button
var ambient: AudioStreamPlayer
var click_sound: AudioStreamPlayer
var release_sound: AudioStreamPlayer
var sound_enabled = true
var toast_timer: Timer

func _ready() -> void:
	ambient = AudioStreamPlayer.new()
	var hum = load("res://archive_room/assets/ambient.wav") as AudioStreamWAV
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = hum.data.size() / 2
	ambient.stream = hum
	ambient.volume_db = -15
	add_child(ambient)
	ambient.play()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 4.0
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	add_child(toast_timer)
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://archive_room/assets/click.wav")
	click_sound.volume_db = -17
	add_child(click_sound)
	release_sound = AudioStreamPlayer.new()
	release_sound.stream = load("res://archive_room/assets/release.wav")
	release_sound.volume_db = -12
	add_child(release_sound)
	view = Control.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	hud = Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	modal = Control.new()
	modal.name = "Modal"
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	toast_label = text(self, "", Rect2(235, 557, 810, 66), 25, CREAM)
	toast_label.name = "InteractionText"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", style(Color(0.08, 0.06, 0.11, 0.95), Color("8e7e98")))
	toast_label.visible = false
	ArchiveSession.changed.connect(update_hud)
	show_view("room")

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func style(fill: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s

func panel(parent: Node, r: Rect2, fill: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var p = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(fill, border))
	parent.add_child(p)
	return p

func text(parent: Node, value: String, r: Rect2, font_size: int = 24, color: Color = CREAM) -> Label:
	var l = Label.new()
	l.text = value
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func picture(parent: Node, asset: String, r: Rect2) -> TextureRect:
	var t = TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = load("res://archive_room/assets/" + asset)
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func button(parent: Node, title: String, r: Rect2, action: Callable, id: String = "") -> Button:
	var b = Button.new()
	b.text = title
	if not id.is_empty(): b.name = id
	b.position = r.position
	b.size = r.size
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", style(Color("302a3b"), Color("8d7d98")))
	b.add_theme_stylebox_override("hover", style(Color("494054"), Color("cab7c9")))
	b.add_theme_stylebox_override("pressed", style(Color("66536d"), CREAM))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), Color("e2c8a1")))
	b.pressed.connect(func():
		if busy and parent == hud: return
		if sound_enabled: click_sound.play()
		action.call()
	)
	parent.add_child(b)
	return b

func hotspot(parent: Node, r: Rect2, action: Callable, id: String, caption: String) -> Button:
	var b = button(parent, "", r, action, id)
	b.tooltip_text = caption
	var border = Color("b6a4bf") if show_hotspots else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", style(Color(0.5,0.4,0.7,0.08) if show_hotspots else Color.TRANSPARENT, border))
	b.add_theme_stylebox_override("hover", style(Color(0.5,0.4,0.7,0.08), Color(0.8,0.7,0.9,0.35)))
	b.add_theme_stylebox_override("pressed", style(Color(0.7,0.6,0.8,0.16), Color("c8b4cf")))
	return b

func show_view(which: String) -> void:
	close_modal()
	clear(view)
	current_view = which
	selected_label = -1
	label_nodes.clear()
	busy = false
	match which:
		"room": build_room()
		"shelves": build_shelves()
		"desk": build_desk()
		"discovery": build_discovery()
	update_hud()

func update_hud() -> void:
	if not is_instance_valid(hud): return
	clear(hud)
	panel(hud, Rect2(0,0,1280,72), Color(0.07,0.055,0.10,0.91))
	text(hud, "PACIENT ZERO  /  ARCHIVE", Rect2(26,8,440,28), 20)
	objective_label = text(hud, ArchiveSession.objective(), Rect2(26,37,960,30), 19, Color("c0b0c9"))
	button(hud, "Hint", Rect2(1010,8,98,56), show_hint, "Hint")
	button(hud, "Menu", Rect2(1122,8,130,56), show_menu, "Menu")
	panel(hud, Rect2(0,640,1280,80), Color(0.07,0.055,0.10,0.94))
	if current_view != "room":
		button(hud, "‹  Back", Rect2(24,649,144,60), func(): show_view("shelves" if current_view == "discovery" else "room"), "Back")
	else:
		text(hud, "Tap an object to inspect", Rect2(28,666,430,40), 21, Color("b4a6bd"))
	if ArchiveSession.has_card:
		inventory_button = button(hud, "✓ Card selected" if card_selected else "Access card", Rect2(926,649,326,60), select_card, "InventoryCard")
		if card_selected: inventory_button.add_theme_stylebox_override("normal", style(Color("655069"), Color("e3c89a")))
	else:
		text(hud, "INVENTORY  —  EMPTY", Rect2(966,669,285,32), 18, Color("95899f"))

func build_room() -> void:
	picture(view, "room.png", Rect2(0,0,1280,720))
	hotspot(view, Rect2(10,241,370,177), func(): show_view("shelves"), "ArchiveShelf", "Archive boxes")
	hotspot(view, Rect2(739,291,355,208), func(): show_view("desk"), "Desk", "Inspect the desk")
	hotspot(view, Rect2(1116,133,126,401), inspect_door, "QuarantineDoor", "Quarantine door")
	hotspot(view, Rect2(1213,270,65,102), inspect_door, "CardReader", "Card reader")
	if ArchiveSession.door_unlocked:
		panel(view, Rect2(1147,146,56,358), Color("16121e"), Color("777184"))
		text(view, "OPEN", Rect2(1135,340,90,36), 20, Color("b5d3b9"))
		hotspot(view, Rect2(1116,133,126,401), inspect_door, "OpenDoor", "Enter quarantine")

func build_desk() -> void:
	picture(view, "desk.png", Rect2(0,0,1280,720))
	hotspot(view, Rect2(310,150,270,320), inspect_photo, "FramedPhoto", "Woman’s photograph")
	hotspot(view, Rect2(670,170,568,430), func(): say("It’s broken."), "BrokenLaptop", "Broken laptop")
	hotspot(view, Rect2(15,470,455,155), func(): say("Routine requisitions. Nothing about quarantine access."), "DeskPapers", "Loose papers")
	hotspot(view, Rect2(563,300,205,110), func(): say("Sealed sample slides. I should leave them alone."), "SlideCase", "Slide case")

func build_shelves() -> void:
	panel(view, Rect2(0,0,1280,720), Color("19151f"))
	text(view, "RESEARCH ARCHIVE", Rect2(35,86,650,44), 28)
	picture(view, "shelf_base.png", Rect2(0,150,1280,357))
	picture(view, "rolled_note.png", Rect2(43,407,42,42))
	hotspot(view, Rect2(24,388,81,82), show_rules, "RolledNote", "Rolled paper")
	var coords = [Rect2(125,347,177,69),Rect2(416,347,174,69),Rect2(698,347,176,69),Rect2(992,347,178,69)]
	for i in range(4):
		var r: Rect2 = coords[i]
		picture(view, "label_%d.png" % i, r)
		var b = button(view, ArchiveSession.labels[i], r, choose_label.bind(i), "ArchiveLabel%d" % i)
		b.add_theme_font_size_override("font_size", 23)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_stylebox_override("normal", style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
		b.add_theme_stylebox_override("hover", style(Color(0.8,0.7,0.9,0.13), Color("cbb5cf")))
		label_nodes.append(b)
		# Lid/body interaction is independent of movable label plates.
		hotspot(view, Rect2(76 + i*285,267,267,70), open_archive_box.bind(i), "ArchiveBox%d" % i, "Open archive box")
	var caption = "Labels restored. Tap the TRANSFERS box to look inside." if ArchiveSession.shelf_solved else "The labels are mixed up. A rolled note is tucked beside the boxes."
	text(view, caption, Rect2(35,521,1210,48), 23, Color("c4b4ce"))
	text(view, "Tap one label, then another to swap them.", Rect2(35,578,1210,34), 20, Color("9e91aa"))

func choose_label(index: int) -> void:
	if busy: return
	if ArchiveSession.shelf_solved:
		open_archive_box(index)
		return
	if selected_label == -1:
		selected_label = index
		label_nodes[index].add_theme_stylebox_override("normal", style(Color(0.5,0.3,0.7,0.27), Color("e5c995")))
		return
	if selected_label == index:
		selected_label = -1
		show_view("shelves")
		return
	busy = true
	var a = selected_label
	var first = label_nodes[a]
	var second = label_nodes[index]
	var start = first.position
	var end = second.position
	var tween = create_tween().set_parallel(true)
	tween.tween_property(first, "position", end, 0.23).set_trans(Tween.TRANS_SINE)
	tween.tween_property(second, "position", start, 0.23).set_trans(Tween.TRANS_SINE)
	await tween.finished
	var solved = ArchiveSession.swap_labels(a, index)
	show_view("shelves")
	if solved: say("That’s the correct order. Quarantine transfers are on the right.")

func open_archive_box(index: int) -> void:
	if busy: return
	if not ArchiveSession.shelf_solved:
		say("I need to restore the labels to locate the transfer records.")
	elif ArchiveSession.labels[index] == "TRANSFERS":
		show_view("discovery")
	else:
		say("Nothing here about quarantine access.")

func begin_modal() -> Control:
	clear(modal)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.position = Vector2.ZERO
	modal.size = Vector2(1280,720)
	var shade = ColorRect.new()
	shade.color = Color(0.025,0.015,0.04,0.78)
	shade.size = Vector2(1280,720)
	modal.add_child(shade)
	toast_label.visible = false
	return modal

func close_modal() -> void:
	if not is_instance_valid(modal): return
	clear(modal)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.size = Vector2.ZERO

func show_rules() -> void:
	ArchiveSession.note_read = true
	ArchiveSession.commit()
	begin_modal()
	picture(modal, "paper.png", Rect2(228,140,824,431))
	text(modal, "FILING RULES", Rect2(273,174,660,55), 35, INK)
	text(modal, "1. INCIDENTS goes immediately left of STAFF.\n\n2. TRANSFERS belongs at the far right.\n\n3. DISPOSAL must not touch STAFF.", Rect2(273,248,735,245), 26, INK)
	button(modal, "×", Rect2(969,152,66,60), close_modal, "Close")

func inspect_photo() -> void:
	ArchiveSession.photo_seen = true
	ArchiveSession.commit()
	begin_modal()
	picture(modal, "framed_photo.png", Rect2(442,95,395,461))
	text(modal, "A quarantine officer. Her face looks familiar.", Rect2(274,571,840,49), 25)
	button(modal, "Close", Rect2(1004,90,170,64), close_modal, "Close")

func build_discovery() -> void:
	picture(view, "desk.png", Rect2(0,0,1280,720)).modulate = Color(0.29,0.25,0.34)
	panel(view, Rect2(26,99,1228,520), Color("292330"), Color("72647d"))
	text(view, "QUARANTINE TRANSFER ARCHIVE", Rect2(55,118,1150,45), 28)
	# Physical folder separate from the box. Both are discovered together.
	picture(view, "paper.png", Rect2(65,224,398,257))
	text(view, "QUARANTINE\nTRANSFER RECORDS", Rect2(95,258,345,90), 27, INK)
	text(view, "PERSONNEL / RESTRICTED\n3 authorised agents", Rect2(95,375,345,65), 20, INK)
	hotspot(view, Rect2(65,215,398,285), show_records.bind(0), "TransferRecords", "Read agent profiles")
	text(view, "Seal code: assigned custodian’s agent ID", Rect2(520,180,675,43), 22)
	var chest = Control.new()
	chest.name = "LayeredLockbox"
	chest.position = Vector2(570,250)
	view.add_child(chest)
	picture(chest, "box_body.svg", Rect2(0,0,580,290))
	var kit_label = text(chest, "QUARANTINE / ACCESS KIT", Rect2(100,200,425,38), 20, CREAM)
	kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ArchiveSession.box_open:
		panel(chest, Rect2(65,50,482,100), Color("17141d"), Color("a28b73"))
		var lid = picture(chest, "box_lid.svg", Rect2(0,-40,580,120))
		lid.modulate = Color(0.85,0.80,0.9)
		lid.position.y = 0
		create_tween().tween_property(lid, "position:y", -40.0, 0.3).set_trans(Tween.TRANS_SINE)
		if not ArchiveSession.has_card:
			picture(chest, "card.svg", Rect2(182,63,230,144))
			text(chest, "QUARANTINE", Rect2(237,89,180,30), 18, CREAM)
			text(chest, "ACCESS • 03", Rect2(263,144,150,30), 15, INK)
			hotspot(view, Rect2(737,300,266,177), pickup_card, "CollectCard", "Collect access card")
		else:
			text(chest, "EMPTY", Rect2(220,92,240,50), 25, Color("b4a5b8"))
	else:
		picture(chest, "box_lid.svg", Rect2(0,0,580,290))
		# Chains are separate movable links rather than baked pixels.
		var chain = Node2D.new()
		chain.name = "Chain"
		chest.add_child(chain)
		for row in range(2):
			for i in range(16):
				var link = Line2D.new()
				link.width = 5
				link.default_color = Color("aca3a6")
				var x = 55.0 + i*31.0
				var y = 62.0 + row*31.0 + sin(i*0.45)*6
				link.points = PackedVector2Array([Vector2(x,y),Vector2(x+11,y-9),Vector2(x+25,y),Vector2(x+11,y+9),Vector2(x,y)])
				chain.add_child(link)
		picture(chest, "padlock.svg", Rect2(238,65,100,129))
		hotspot(view, Rect2(570,250,580,290), show_lock, "ChainedBox", "Inspect combination lock")
	text(view, "Records and a sealed access kit, stored together.", Rect2(64,558,1140,40), 22, Color("b5a7bf"))

func show_records(page: int = 0) -> void:
	record_page = posmod(page, AGENTS.size())
	ArchiveSession.records_read = true
	ArchiveSession.commit()
	var agent: Dictionary = AGENTS[record_page]
	begin_modal()
	picture(modal, "paper.png", Rect2(130,86,1020,548))
	text(modal, "QUARANTINE TRANSFER RECORDS", Rect2(170,112,850,44), 29, INK)
	text(modal, "PERSONNEL RECORD  /  %d OF 3" % (record_page+1), Rect2(170,158,850,36), 19, Color("655862"))
	picture(modal, str(agent.image), Rect2(180,213,205,254))
	text(modal, str(agent.name), Rect2(430,214,650,54), 34, INK)
	text(modal, str(agent.role), Rect2(430,274,650,44), 24, INK)
	text(modal, "AGENT ID     " + str(agent.id), Rect2(430,341,650,52), 31, INK)
	text(modal, "TRANSFER ASSIGNMENT", Rect2(430,415,650,36), 18, Color("655862"))
	text(modal, str(agent.transfer), Rect2(430,455,650,40), 23, INK)
	button(modal, "‹ Previous", Rect2(174,545,205,62), show_records.bind(record_page-1), "PreviousRecord")
	button(modal, "Next ›", Rect2(900,545,205,62), show_records.bind(record_page+1), "NextRecord")
	button(modal, "×", Rect2(1071,97,64,61), close_modal, "Close")

func show_lock() -> void:
	if ArchiveSession.box_open: return
	entered_code = ""
	begin_modal()
	panel(modal, Rect2(363,78,554,558), Color("302a38"), Color("9c8b9f"))
	text(modal, "ACCESS KIT / COMBINATION", Rect2(393,97,470,43), 25)
	text(modal, "Assigned custodian’s agent ID", Rect2(393,141,470,38), 21, Color("c5b8cb"))
	code_display = text(modal, "_  _  _  _", Rect2(421,187,440,61), 40)
	code_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_feedback = text(modal, "Enter four digits", Rect2(393,250,480,35), 20, Color("c2b2cc"))
	for i in range(9):
		button(modal, str(i+1), Rect2(408+(i%3)*157,298+(i/3)*70,145,62), keypad.bind(str(i+1)), "Digit%d" % (i+1))
	button(modal, "Clear", Rect2(408,508,145,62), keypad.bind("clear"), "ClearCode")
	button(modal, "0", Rect2(565,508,145,62), keypad.bind("0"), "Digit0")
	button(modal, "Unlock", Rect2(722,508,145,62), keypad.bind("enter"), "UnlockBox")
	button(modal, "×", Rect2(917,78,65,64), close_modal, "Close")

func keypad(key: String) -> void:
	if key == "clear":
		entered_code = ""
	elif key == "enter":
		if entered_code.length() < 4:
			lock_feedback.text = "Four digits are required."
		elif ArchiveSession.try_code(entered_code):
			if sound_enabled: release_sound.play()
			show_view("discovery")
			say("The chain releases. There’s an access card inside.")
			return
		else:
			lock_feedback.text = "Incorrect code. Check the custodian’s record."
			entered_code = ""
	elif entered_code.length() < 4:
		entered_code += key
	var display = ""
	for i in range(4):
		display += (entered_code[i] if i < entered_code.length() else "_") + "  "
	code_display.text = display.strip_edges()

func pickup_card() -> void:
	if ArchiveSession.collect_card():
		card_selected = true
		show_view("discovery")
		say("Quarantine access card collected. Return to the door.")

func select_card() -> void:
	card_selected = not card_selected
	update_hud()
	say("Card selected. Tap the quarantine reader." if card_selected else "Card deselected.")

func inspect_door() -> void:
	if ArchiveSession.door_unlocked:
		complete_level()
	elif not ArchiveSession.has_card:
		say("Quarantine access restricted. I need an access card.")
	elif not card_selected:
		say("Select the access card from your inventory first.")
	else:
		ArchiveSession.unlock_door()
		if sound_enabled: release_sound.play()
		card_selected = false
		show_view("room")
		say("Access granted. Tap the open door to enter quarantine.")

func complete_level() -> void:
	if not ArchiveSession.completed:
		ArchiveSession.completed = true
		ArchiveSession.commit()
		quarantine_entered.emit()
	if not next_level_scene.is_empty() and ResourceLoader.exists(next_level_scene):
		get_tree().change_scene_to_file(next_level_scene)
		return
	begin_modal()
	panel(modal, Rect2(260,190,760,330), Color("282130"), Color("9b88a5"))
	text(modal, "QUARANTINE ACCESS GRANTED", Rect2(300,230,700,56), 32)
	text(modal, "Archive Room complete.\nThe quarantine zone lies ahead.", Rect2(300,313,700,100), 26)
	button(modal, "Return to archive", Rect2(459,432,360,64), close_modal, "Close")

func say(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_timer.start()

func show_hint() -> void:
	var hints: Array
	if ArchiveSession.door_unlocked: hints = ["Tap the open quarantine door."]
	elif ArchiveSession.has_card: hints = ["Select your access card, then tap the door’s reader."]
	elif ArchiveSession.box_open: hints = ["Tap the access card inside the opened box."]
	elif ArchiveSession.shelf_solved:
		hints = ["The framed portrait identifies the access kit’s custodian.", "Compare the woman’s face with the transfer records.", "Elena Morozova is the custodian. Her agent ID is the lock code."]
	else:
		hints = ["Inspect the archive boxes on the left.", "A rolled note is hidden beside the first box. Tap it.", "Transfers is last. Incidents sits immediately before Staff.", "The order is Disposal, Incidents, Staff, Transfers."]
	begin_modal()
	panel(modal, Rect2(200,190,880,310), Color("302737"), Color("9c8aa7"))
	text(modal, "ARCHIVE HINT", Rect2(240,218,740,45), 29)
	var l = text(modal, str(hints[mini(hint_step,hints.size()-1)]), Rect2(240,280,790,115), 25)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(modal, "More help", Rect2(241,414,240,64), func(): hint_step += 1; show_hint(), "MoreHint")
	button(modal, "Close", Rect2(789,414,240,64), close_modal, "Close")

func show_menu() -> void:
	begin_modal()
	panel(modal, Rect2(375,100,530,515), Color("302737"), Color("9c8aa7"))
	text(modal, "ARCHIVE ROOM", Rect2(418,125,450,49), 31)
	button(modal, "Resume", Rect2(416,195,448,64), close_modal, "Close")
	button(modal, "Hide hotspots" if show_hotspots else "Show hotspots", Rect2(416,273,448,64), func(): show_hotspots = not show_hotspots; show_view(current_view), "ToggleHotspots")
	button(modal, "Sound: on" if sound_enabled else "Sound: off", Rect2(416,351,448,64), func(): sound_enabled = not sound_enabled; ambient.stream_paused = not sound_enabled; show_menu(), "ToggleSound")
	button(modal, "Restart level…", Rect2(416,429,448,64), confirm_reset, "Restart")
	text(modal, "Progress saves automatically", Rect2(418,540,450,35), 19, Color("b9a9c3"))

func confirm_reset() -> void:
	begin_modal()
	panel(modal, Rect2(270,225,740,270), Color("302737"), Color("9c8aa7"))
	text(modal, "Restart and erase this level’s progress?", Rect2(310,260,680,65), 27)
	button(modal, "Cancel", Rect2(310,367,280,64), close_modal, "Close")
	button(modal, "Restart", Rect2(660,367,310,64), func(): ArchiveSession.reset(); card_selected = false; hint_step = 0; show_view("room"), "ConfirmRestart")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal.get_child_count() > 0: close_modal()
		elif current_view != "room": show_view("shelves" if current_view == "discovery" else "room")
		else: show_menu()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Explicit single-finger GUI bridge. Mouse emulation is disabled to avoid double taps.
	if event is InputEventScreenTouch and event.index == 0:
		get_viewport().set_input_as_handled()
		var motion = InputEventMouseMotion.new()
		motion.position = event.position
		motion.global_position = event.position
		get_viewport().push_input(motion, true)
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = event.position
		click.global_position = event.position
		click.pressed = event.pressed
		get_viewport().push_input(click, true)
	elif event is InputEventScreenDrag and event.index == 0:
		get_viewport().set_input_as_handled()
		var motion = InputEventMouseMotion.new()
		motion.position = event.position
		motion.global_position = event.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)

func stop_audio() -> void:
	for player in [ambient, click_sound, release_sound]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	stop_audio()
