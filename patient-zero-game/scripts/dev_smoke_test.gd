extends SceneTree

# Developer smoke test: loads every room from GameFlow.ROOMS (empty paths are skipped),
# instantiates it, lets it run for 2 seconds and frees it. Run without a window:
#   godot --headless --path . -s res://scripts/dev_smoke_test.gd
# Exit code 0 = all rooms loaded. Errors raised by the rooms themselves appear in the output.
# Note: room 3 writes its save file (user://quarantine_room_save.json) when it opens.

const RUN_SECONDS := 2.0

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var flow := root.get_node("GameFlow")
    var failed := 0
    for n in flow.ROOMS:
        var path: String = flow.ROOMS[n]
        if path.is_empty():
            print("SMOKE room %d: skipped (no scene yet)" % n)
            continue
        var packed := load(path) as PackedScene
        if packed == null:
            printerr("SMOKE room %d: FAILED to load %s" % [n, path])
            failed += 1
            continue
        var room := packed.instantiate()
        if room == null:
            printerr("SMOKE room %d: FAILED to instantiate %s" % [n, path])
            failed += 1
            continue
        root.add_child(room)
        await create_timer(RUN_SECONDS).timeout
        room.queue_free()
        await process_frame
        print("SMOKE room %d: OK (%s)" % [n, path])
    print("SMOKE result: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
    flow.quit_game(1 if failed > 0 else 0)
