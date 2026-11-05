extends Node
## Autoload "AudioManager": pooled one-shot SFX, crossfading music and ambience loops,
## and the Music / SFX / Ambient audio buses that the settings sliders control.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/ambience/"
const POOL_SIZE := 18

var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_key := ""
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_active: AudioStreamPlayer
var _amb_key := ""
var _cache: Dictionary = {}
var _variants: Dictionary = {}
var _last_play: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_active = _music_a
	_amb_a = _make_player("Ambient")
	_amb_b = _make_player("Ambient")
	_amb_active = _amb_a

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p

func apply_volumes(s: Dictionary) -> void:
	_set_bus("Master", float(s.get("master", 1.0)))
	_set_bus("Music", float(s.get("music", 0.65)))
	_set_bus("SFX", float(s.get("sfx", 0.85)))
	_set_bus("Ambient", float(s.get("ambient", 0.55)))
	AudioServer.set_bus_mute(0, bool(s.get("mute", false)))

func _set_bus(name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[path] = s
	return s

func _resolve_sfx(name: String) -> AudioStream:
	if not _variants.has(name):
		var list: Array[AudioStream] = []
		var direct := _load(SFX_DIR + name + ".wav")
		if direct:
			list.append(direct)
		for i in range(1, 5):
			var v := _load("%s%s_%d.wav" % [SFX_DIR, name, i])
			if v:
				list.append(v)
		_variants[name] = list
	var arr: Array = _variants[name]
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]

## Play a one-shot sound effect. Variants name_1..name_4 are picked at random.
func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.06, min_gap: float = 0.03) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(name, -1.0)) < min_gap:
		return
	_last_play[name] = now
	var stream := _resolve_sfx(name)
	if stream == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)

func play_music(key: String, fade: float = 1.6) -> void:
	if key == _music_key:
		return
	_music_key = key
	var s := _load(MUSIC_DIR + key + ".wav")
	var old := _music_active
	var new_p := _music_b if _music_active == _music_a else _music_a
	_music_active = new_p
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if s:
		_make_loop(s)
		new_p.stream = s
		new_p.volume_db = -50.0
		new_p.play()
		var tw2 := create_tween()
		tw2.tween_property(new_p, "volume_db", 0.0, fade)

func stop_music(fade: float = 1.0) -> void:
	_music_key = ""
	var p := _music_active
	if p.playing:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.stop)

func play_ambience(key: String, fade: float = 2.0) -> void:
	if key == _amb_key:
		return
	_amb_key = key
	var s := _load(AMB_DIR + key + ".wav") if key != "" else null
	var old := _amb_active
	var new_p := _amb_b if _amb_active == _amb_a else _amb_a
	_amb_active = new_p
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if s:
		_make_loop(s)
		new_p.stream = s
		new_p.volume_db = -50.0
		new_p.play()
		var tw2 := create_tween()
		tw2.tween_property(new_p, "volume_db", -4.0, fade)

func current_music() -> String:
	return _music_key
