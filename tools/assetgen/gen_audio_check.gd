## Verifies the generated audio: every contract file exists, loads as WAV, does not clip,
## and loops (music/ambience/looping SFX) are seamless at the wrap point.
extends SceneTree

const SFX := ["swing", "hit_rock_1", "hit_rock_2", "hit_rock_3", "hit_ore", "hit_crystal", "hit_ice", "hit_metal",
	"break_rock_1", "break_rock_2", "break_crystal", "pickup", "pickup_rare", "coin", "sell", "buy", "geode_crack",
	"geode_reveal", "elevator_move", "elevator_ding", "minecart", "smelter", "crusher", "machine_done", "ui_click",
	"ui_hover", "ui_open", "ui_close", "ui_error", "skill_unlock", "skill_max", "level_up", "event_start", "event_end",
	"rare_discovery", "legendary", "step_1", "step_2", "jump", "land", "ladder", "hurt", "fuse", "explosion",
	"chest_open", "quest_complete", "notify", "splash", "lava_bubble", "place"]
const LOOP_SFX := ["elevator_move", "minecart", "smelter", "crusher", "fuse"]
const MUSIC := ["menu", "camp", "stone", "iron", "crystal", "frozen", "magma", "ancient"]
const AMB := ["surface", "cave", "crystal", "frozen", "magma", "ancient"]

var problems := 0
var total_bytes := 0

func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../../assets/audio").simplify_path()
	for n in SFX:
		check(root.path_join("sfx/%s.wav" % n), LOOP_SFX.has(n))
	for n in MUSIC:
		check(root.path_join("music/%s.wav" % n), true)
	for n in AMB:
		check(root.path_join("ambience/%s.wav" % n), true)
	print("TOTAL %.1f MB, %d problems" % [total_bytes / 1048576.0, problems])
	quit()

func check(path: String, loop: bool) -> void:
	if not FileAccess.file_exists(path):
		print("MISSING ", path)
		problems += 1
		return
	total_bytes += FileAccess.get_file_as_bytes(path).size()
	var w := AudioStreamWAV.load_from_file(path)
	if w == null:
		print("UNLOADABLE ", path)
		problems += 1
		return
	var data := w.data
	var ch := 2 if w.stereo else 1
	var frames := data.size() / 2 / ch
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	var msg := "%-22s %6.2fs %s %dHz peak %5.1f dB" % [path.get_file(), float(frames) / w.mix_rate, ("st" if w.stereo else "mo"), w.mix_rate, linear_to_db(peak / 32767.0)]
	if peak >= 32767:
		msg += "  CLIP?"
		problems += 1
	if loop:
		# seam jump vs typical sample-to-sample step
		var worst := 0.0
		for c in ch:
			var first := data.decode_s16(c * 2)
			var last := data.decode_s16((frames - 1) * ch * 2 + c * 2)
			# typical step size right around the wrap point (last/first 96 samples)
			var sum := 0.0
			var cnt := 0
			for f in range(1, 96):
				sum += absi(data.decode_s16(f * ch * 2 + c * 2) - data.decode_s16((f - 1) * ch * 2 + c * 2))
				var g := frames - f
				sum += absi(data.decode_s16(g * ch * 2 + c * 2) - data.decode_s16((g - 1) * ch * 2 + c * 2))
				cnt += 2
			var avg := sum / maxf(1.0, cnt)
			worst = maxf(worst, absi(first - last) / maxf(1.0, avg))
		msg += "  seam %.2fx local step" % worst
		if worst > 4.0:
			msg += "  SEAM!"
			problems += 1
	print(msg)
