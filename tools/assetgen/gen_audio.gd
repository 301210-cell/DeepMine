## Generates all DeepMine audio into assets/audio/.
## Usage (from the DeepMine folder):
##   Godot_console.exe --headless --path tools/assetgen --script res://gen_audio.gd            (everything)
##   ... --script res://gen_audio.gd -- sfx                                                    (only SFX)
##   ... --script res://gen_audio.gd -- music [track ...]                                      (all or some tracks)
##   ... --script res://gen_audio.gd -- amb [name ...]                                         (all or some ambiences)
extends SceneTree

const SFX = preload("res://audio_sfx.gd")
const MUSIC = preload("res://audio_music.gd")
const AMB = preload("res://audio_amb.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	if args.is_empty():
		SFX.run()
		MUSIC.run([])
		AMB.run([])
	else:
		var what: String = args[0]
		var rest := args.slice(1)
		match what:
			"sfx":
				SFX.run()
			"music":
				MUSIC.run(rest)
			"amb":
				AMB.run(rest)
			_:
				push_error("unknown target " + what)
	print("Audio generation finished in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
