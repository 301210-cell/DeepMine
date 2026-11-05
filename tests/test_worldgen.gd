extends SceneTree
func _initialize() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var gen = load("res://scripts/world/world_gen.gd").new()
	var wd = gen.generate(4242)
	var ms := Time.get_ticks_msec() - t0
	var counts := {}
	var air := 0
	for i in wd.blocks.size():
		var b: int = wd.blocks[i]
		counts[b] = int(counts.get(b, 0)) + 1
		if b == 0: air += 1
	print("gen ms=", ms, " air%=", snappedf(100.0 * air / wd.blocks.size(), 0.1))
	var DB = root.get_node("ResourceDatabase")
	var ores := []
	for id in counts:
		if id >= 40 and id < 90:
			ores.append("%s:%d" % [DB.block(id).key, counts[id]])
	print("ores: ", ", ".join(ores))
	var types := {}
	for e in wd.entities: types[e.type] = int(types.get(e.type, 0)) + 1
	print("entities: ", types)
	print("markers: ", wd.markers)
	var s = wd.serialize()
	print("serialized blocks b64 len=", String(s.blocks).length())
	var wd2 = load("res://scripts/world/world_data.gd").deserialize(s)
	print("roundtrip equal=", wd2.blocks == wd.blocks)
	# ASCII preview of tutorial area rows 0..14, x 84..135
	for y in range(-2, 16):
		var line := ""
		for x in range(84, 136):
			var id: int = wd.get_block(x, y)
			var ch := "."
			if id == 0: ch = " "
			elif id == 19: ch = "#"
			elif id == 90: ch = "H"
			elif id == 94: ch = "*"
			elif id == 41: ch = "c"
			elif id == 40: ch = "k"
			elif id >= 40: ch = "o"
			elif id == 25: ch = "="
			elif id == 2: ch = "^"
			line += ch
		print("%4d %s" % [y, line])
	quit()
