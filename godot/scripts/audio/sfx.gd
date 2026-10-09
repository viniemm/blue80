class_name Sfx
extends RefCounted
## Plays the generated sound effects and music loops: Sfx.play("click"), Sfx.play_music("game").
## A static class (no autoload) that creates its player nodes under the scene root the first time it is used, so it
## also works from test scripts. Honors the sfx and music toggles in Save, and mutes while the app is in the background.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 10
const SFX_DB := -3.0
const MUSIC_DB := -10.0

class Holder extends Node:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
			AudioServer.set_bus_mute(0, true)
		elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
			AudioServer.set_bus_mute(0, false)

static var sfx_on := true
static var music_on := true
static var _holder: Holder
static var _players: Array = []
static var _next := 0
static var _cache := {}
static var _music: AudioStreamPlayer
static var _music_name := ""
static var _fade: Tween


static func _ensure() -> bool:
	if _holder != null and is_instance_valid(_holder):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	_holder = Holder.new()
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	_players = []
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		_holder.add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	_holder.add_child(_music)
	tree.root.add_child.call_deferred(_holder)           # the root may be busy setting up its children
	apply_settings()
	return true


## Re-read the toggles from Save (called at start and whenever Settings changes).
static func apply_settings() -> void:
	sfx_on = bool(Save.setting("sfx", true))
	music_on = bool(Save.setting("music", true))
	if _music_name == "" or _music == null:
		return
	if music_on:
		if not _music.playing:
			_start_music(_music_name)
	else:
		_music.stop()


static func _stream(path: String, looped: bool = false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if looped and st is AudioStreamWAV:
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2                 # 16-bit mono: samples = bytes / 2
	_cache[path] = st
	return st


## Play a one-shot sound. `jitter` varies the pitch a little so repeats do not sound identical.
static func play(sound: String, delay: float = 0.0, jitter: float = 0.0) -> void:
	apply_settings_once()
	if not sfx_on or not _ensure():
		return
	if delay > 0.0:
		(Engine.get_main_loop() as SceneTree).create_timer(delay).timeout.connect(play.bind(sound, 0.0, jitter))
		return
	var st := _stream(SFX_DIR + sound + ".wav")
	if st == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	if not p.is_inside_tree():
		return
	p.stream = st
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()


static var _settings_read := false


static func apply_settings_once() -> void:
	if not _settings_read:
		_settings_read = true
		sfx_on = bool(Save.setting("sfx", true))
		music_on = bool(Save.setting("music", true))


static func play_music(music: String) -> void:
	apply_settings_once()
	if not _ensure():
		return
	if _music_name == music and _music.playing:
		return
	_music_name = music
	if music_on:
		_start_music(music)


static func stop_music() -> void:
	_music_name = ""
	if _music != null:
		_fade_to(-80.0, 0.4, true)


static func _start_music(music: String) -> void:
	var st := _stream(MUSIC_DIR + music + ".wav", true)
	if st == null or _music == null or not _music.is_inside_tree():
		if _music != null and _holder != null:
			(Engine.get_main_loop() as SceneTree).create_timer(0.2).timeout.connect(func(): _start_music(music))
		return
	if _fade:
		_fade.kill()
	_fade = _music.create_tween()
	if _music.playing:                                   # crossfade: duck the old loop, swap, bring the new one up
		_fade.tween_property(_music, "volume_db", -80.0, 0.3)
	_fade.tween_callback(func():
		_music.stream = st
		_music.volume_db = -80.0
		_music.play())
	_fade.tween_property(_music, "volume_db", MUSIC_DB, 0.8)


static func _fade_to(db: float, sec: float, stop_after: bool) -> void:
	if _fade:
		_fade.kill()
	_fade = _music.create_tween()
	_fade.tween_property(_music, "volume_db", db, sec)
	if stop_after:
		_fade.tween_callback(_music.stop)
