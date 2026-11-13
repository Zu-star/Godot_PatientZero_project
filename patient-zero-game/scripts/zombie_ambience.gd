extends Node

# Persistent user-supplied zombie apocalypse ambience across all scenes.
var player: AudioStreamPlayer
var one_shots: Array[AudioStreamPlayer] = []
var ambience_enabled := true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_start_ambience")

func _start_ambience() -> void:
    var stream := load("res://assets/sounds/zombie_ambience.mp3") as AudioStreamMP3
    if stream == null:
        push_error("Patient Zero: could not load user zombie_ambience.mp3")
        return
    stream.loop = true

    if not is_instance_valid(player):
        player = AudioStreamPlayer.new()
        player.name = "ZombieApocalypseAmbience"
        player.process_mode = Node.PROCESS_MODE_ALWAYS
        player.bus = "Master"
        add_child(player)

    player.stream = stream
    player.volume_db = 0.0
    if ambience_enabled and not player.playing:
        player.play()

func stop_ambience() -> void:
    ambience_enabled = false
    if is_instance_valid(player):
        player.stop()

func resume_ambience() -> void:
    ambience_enabled = true
    if not is_instance_valid(player) or player.stream == null:
        _start_ambience()
    elif not player.playing:
        player.play()

func set_ambience_volume(volume_db: float) -> void:
    if is_instance_valid(player):
        player.volume_db = clampf(volume_db, -20.0, 3.0)

func play_one_shot(file_name: String, volume_db: float = -3.0) -> void:
    var stream := load("res://assets/sounds/" + file_name) as AudioStream
    if stream == null:
        push_warning("Patient Zero: missing sound asset: " + file_name)
        return
    var sfx := AudioStreamPlayer.new()
    sfx.name = "OneShot_" + file_name.get_basename()
    sfx.process_mode = Node.PROCESS_MODE_ALWAYS
    sfx.bus = "Master"
    sfx.stream = stream
    sfx.volume_db = volume_db
    add_child(sfx)
    one_shots.append(sfx)
    sfx.finished.connect(func():
        one_shots.erase(sfx)
        sfx.queue_free()
    )
    sfx.play()

func play_lose_sound() -> void:
    # Give the supplied attack sound a clear foreground when the player loses.
    stop_ambience()
    play_one_shot("zombie_attack.mp3", 0.0)
