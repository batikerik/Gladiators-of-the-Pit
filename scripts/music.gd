extends Node
## Autoload "Music": picks the soundtrack from the current scene and
## crossfades between tracks, so music never cuts off on a scene change.
##   tavern — main menu, the descent map, intro, campfire and cache rooms
##   fight  — every fight with the AI (tutorial, combat rooms, boss, arena)
##   death  — the defeat screen (RunEndScreen picks it; victory is silent)
## Keeps playing while the game is paused. Volume: Settings.music_volume.

const TRACKS: Dictionary = {
	&"tavern": preload("res://audio/music/cozy_tavern_hearth.mp3"),
	&"fight": preload("res://audio/music/skirmish_on_the_road.mp3"),
	&"death": preload("res://audio/music/catacomb_steps.mp3"),
}
## Scene root name -> track. Unlisted scenes keep whatever is playing (the
## run end screen chooses its own track).
const SCENE_TRACKS: Dictionary = {
	"MainMenu": &"tavern", "IntroCutscene": &"tavern", "CatacombMap": &"tavern",
	"SafeRoom": &"tavern", "LootRoom": &"tavern",
	"TutorialRoom": &"fight", "CombatRoom": &"fight", "Arena": &"fight",
}
const FADE_TIME: float = 1.2

var current_track: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _last_scene: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	Settings.changed.connect(_apply_volume)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		if scene and SCENE_TRACKS.has(String(scene.name)):
			play(SCENE_TRACKS[String(scene.name)])

## Crossfade to a track (&"" fades out). Same track keeps playing uninterrupted.
func play(track: StringName) -> void:
	if track == current_track:
		return
	current_track = track
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, FADE_TIME)
	if track != &"":
		var stream: AudioStreamMP3 = TRACKS[track]
		stream.loop = true
		new.stream = stream
		new.volume_db = -80.0
		new.play()
		tw.tween_property(new, "volume_db", _target_db(), FADE_TIME)
	tw.chain().tween_callback(old.stop)

func _target_db() -> float:
	return linear_to_db(maxf(Settings.music_volume, 0.0001))

func _apply_volume() -> void:
	if current_track != &"":
		_players[_active].volume_db = _target_db()
