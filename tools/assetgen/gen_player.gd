## Generates player.png, tools.png, mara.png, mara_portrait.png
extends SceneTree
const PX = preload("res://px.gd")
const L = preload("res://chlib.gd")

var P := {}   # palette ramps for current character
var SEC := {"pack_dy": 0, "sway": 0, "lamp": 0}   # secondary motion for the frame being drawn

func pal_player() -> Dictionary:
	return {
		"helmet": L.r5("7a3e0c", "c47a14", "f2b022", "ffd84a", "fff1a0"),
		"skin": L.r5("9a5a3c", "c8805a", "f0a878", "ffd0a4", "ffe6c8"),
		"hair": L.r5("2e160a", "4e2612", "74401e", "9a5a2c", "b8783c"),
		"jacket": L.r5("6e2a10", "b04a1c", "e87a2a", "ffa448", "ffc878"),
		"pants": L.r5("16224e", "24398a", "3a62c0", "5a8ee8", "8ab4ff"),
		"bib": L.r5("16224e", "24398a", "3a62c1", "5a8ee8", "8ab4ff"),
		"glove": L.r5("3a2010", "5e3a1c", "8a5a30", "b07a44", "cfa070"),
		"boot": L.r5("1e1008", "3a2010", "5a3418", "7a4a24", "9a6234"),
		"pack": L.r5("3a1e0c", "5e3416", "8a5528", "b07038", "d0904c"),
		"roll": L.r5("4a1a1a", "7a2a2a", "a83a3a", "d05a4a", "e88a6a"),
		"lamp": L.r5("2a2e3c", "3c4458", "5a6378", "8a93a8", "c3cad8"),
		"eye": L.c("1b1424"), "mouth": L.c("9a3a3a"), "blush": L.c("ff8a7a"),
		"light": L.c("fffbe0"), "light2": L.c("ffe680"),
		"braid": false, "bandana": false,
	}

func pal_mara() -> Dictionary:
	var p := pal_player()
	p["hair"] = L.r5("4a140a", "7a2a18", "b0482a", "d86a3a", "f09050")
	p["jacket"] = L.r5("0c3a3a", "146060", "23908a", "3ac0b0", "7ae8d8")
	p["pants"] = L.r5("2a1a10", "4a3020", "6a4a30", "8a6a48", "aa8a60")
	p["bib"] = L.r5("2a1a10", "4a3020", "6a4a31", "8a6a48", "aa8a60")
	p["skin"] = L.r5("8a4a34", "c07a58", "eaa27a", "ffcaa2", "ffe2c8")
	p["pack"] = L.r5("2a2a3a", "3c4458", "566078", "7a86a0", "a0aac0")
	p["braid"] = true
	p["bandana"] = true
	return p

func R(name: String) -> Array:
	return P[name]

func M(name: String) -> Color:
	return P[name][2]

func back_ramp(name: String) -> Array:
	var r: Array = P[name]
	return [r[0], r[0], r[1], r[2], r[3]]

## Two-bone IK. bend_dir: +1 bends toward +x, -1 toward -x
func ik(a: Vector2, b: Vector2, l1: float, l2: float, bend_dir: float) -> Vector2:
	var d := a.distance_to(b)
	var mid := (a + b) * 0.5
	if d >= l1 + l2 - 0.01 or d < 0.01:
		return mid
	var h := sqrt(maxf(0.0, l1 * l1 - (d * 0.5) * (d * 0.5)))
	var dirv := (b - a).normalized()
	var perp := Vector2(-dirv.y, dirv.x)
	if perp.x * bend_dir < 0.0:
		perp = -perp
	return mid + perp * h

# ----------------------------------------------------------------------------- body parts
func draw_leg(hip: Vector2, ankle: Vector2, back: bool) -> PX.Canvas:
	var ly := L.layer(32, 48)
	var pant := back_ramp("pants") if back else R("pants")
	var boot := back_ramp("boot") if back else R("boot")
	var knee := ik(hip, ankle, 4.2, 4.2, 1.0)
	L.thick(ly, [hip, knee, ankle], 1.45, pant[2])
	# boot: 5 wide x 3 tall, toe forward
	var ax := int(round(ankle.x - 0.5))
	var ay := int(round(ankle.y - 0.5))
	ly.fill_rect(ax - 1, ay, 5, 2, boot[2])
	ly.fill_rect(ax - 1, ay + 2, 5, 1, boot[0])  # sole
	ly.px(ax + 4, ay + 1, boot[2])
	ly.px(ax + 4, ay + 2, boot[0])
	L.autoshade(ly, [pant, boot])
	return ly

func draw_arm(shoulder: Vector2, hand: Vector2, back: bool) -> PX.Canvas:
	var ly := L.layer(32, 48)
	var jk := back_ramp("jacket") if back else R("jacket")
	var gl := back_ramp("glove") if back else R("glove")
	var elbow := ik(shoulder, hand, 2.9, 2.9, -1.0)
	L.thick(ly, [shoulder, elbow, hand], 1.2, jk[2])
	L.disc(ly, hand.x, hand.y, 1.5, gl[2])
	L.autoshade(ly, [jk, gl])
	return ly

func draw_torso(hx: int, hip: int, top: int, lean: int) -> PX.Canvas:
	var ly := L.layer(32, 48)
	var h := hip - top
	for y in range(top, hip):
		var t := float(hip - y) / float(maxi(h, 1))
		var sh := int(round(lean * t))
		var x0 := hx - 4 + sh
		var x1 := hx + 4 + sh
		if y == top:
			x0 += 1
			x1 -= 1
		var col := M("jacket")
		if y >= hip - 3:
			col = M("pants")
		for x in range(x0, x1 + 1):
			ly.px(x, y, col)
		# bib + strap
		if y >= hip - 7 and y < hip - 3:
			for x in range(hx + sh, hx + 4 + sh):
				ly.px(x, y, M("bib"))
		if y >= top + 1 and y < hip - 7:
			ly.px(hx + sh + int(round((hip - 7 - y) * -0.4)), y, M("bib"))
	# collar / bandana
	if P["bandana"]:
		for x in range(hx - 2 + lean, hx + 4 + lean):
			ly.px(x, top, L.c("d03a3a"))
		ly.px(hx + 1 + lean, top + 1, L.c("d03a3a"))
	L.autoshade(ly, [R("jacket"), R("pants"), R("bib")])
	# bib pocket detail + buttons
	ly.px(hx + 1 + int(round(lean * 0.4)), hip - 6, R("bib")[1])
	ly.px(hx + 2 + int(round(lean * 0.4)), hip - 6, R("bib")[1])
	ly.px(hx + int(round(lean * 0.6)), hip - 7, L.c("ffd84a"))
	return ly

func draw_pack(hx: int, hip: int, top: int, lean: int) -> PX.Canvas:
	var ly := L.layer(32, 48)
	var sh := int(round(lean * 0.6))
	var x0 := hx - 8 + sh
	top += int(SEC["pack_dy"])
	hip += int(SEC["pack_dy"])
	ly.fill_rect(x0, top, 5, hip - top - 1, M("pack"))
	ly.px(x0, top, Color(0, 0, 0, 0))
	ly.px(x0, hip - 2, Color(0, 0, 0, 0))
	L.autoshade(ly, [R("pack"), R("roll")])
	# top flap + buckle + side pocket
	for x in range(x0, x0 + 5):
		ly.px(x, top + 3, R("pack")[1])
	ly.px(x0 + 1, top + 1, R("pack")[3])
	ly.px(x0 + 2, top + 1, R("pack")[3])
	ly.px(x0 + 2, top + 4, L.c("ffd84a"))
	ly.px(x0 + 1, hip - 4, R("pack")[1])
	ly.px(x0 + 2, hip - 4, R("pack")[1])
	return ly

func draw_head(cx: int, top: int, blink: bool, mouth_open: bool) -> Array:
	# returns [face_layer, helmet_layer]
	var face := L.layer(32, 48)
	var hel := L.layer(32, 48)
	# face block rows top+6 .. top+12
	for y in range(top + 6, top + 13):
		var x0 := cx - 5
		var x1 := cx + 5
		if y == top + 12:
			x0 = cx - 3
			x1 = cx + 3
		elif y == top + 11:
			x0 = cx - 4
			x1 = cx + 4
		elif y >= top + 8 and y <= top + 10:
			x1 = cx + 5
		for x in range(x0, x1 + 1):
			face.px(x, y, M("skin"))
	# hair at back
	for y in range(top + 6, top + 11):
		for x in range(cx - 6, cx - 2 + (1 if y < top + 8 else 0)):
			face.px(x, y, M("hair"))
	if P["braid"]:
		var bx := cx - 6
		for y in range(top + 10, top + 17):
			var sw := (1 if y > top + 13 else 0) + (int(SEC["sway"]) if y > top + 12 else 0)
			face.px(bx - sw, y, M("hair"))
			face.px(bx + 1 - sw, y, M("hair"))
	L.autoshade(face, [R("skin"), R("hair")])
	# ear
	face.px(cx - 2, top + 8, R("skin")[1])
	face.px(cx - 2, top + 9, R("skin")[1])
	# eyes
	if blink:
		face.px(cx + 1, top + 9, L.c("1b1424"))
		face.px(cx + 4, top + 9, L.c("1b1424"))
	else:
		for ex in [cx + 1, cx + 4]:
			face.px(ex, top + 8, L.c("1b1424"))
			face.px(ex, top + 9, L.c("1b1424"))
	face.px(cx + 4, top + 10, P["blush"].lerp(M("skin"), 0.35))
	face.px(cx - 1, top + 10, P["blush"].lerp(M("skin"), 0.5))
	if mouth_open:
		face.px(cx + 2, top + 11, L.c("5a1a1a"))
		face.px(cx + 3, top + 11, L.c("5a1a1a"))
		face.px(cx + 2, top + 12, P["mouth"])
	else:
		face.px(cx + 2, top + 11, P["mouth"])
		face.px(cx + 3, top + 11, P["mouth"])
	if P["braid"]:
		# eyelashes
		face.px(cx + 5, top + 8, L.c("1b1424"))
		face.px(cx + 2, top + 8, L.c("1b1424"))
	# helmet dome
	var ccx := cx + 0.5
	var ccy := top + 6.5
	for y in range(top, top + 6):
		for x in range(cx - 8, cx + 9):
			var nx := (x + 0.5 - ccx) / 6.6
			var ny := (y + 0.5 - ccy) / 6.2
			if nx * nx + ny * ny <= 1.0:
				hel.px(x, y, M("helmet"))
	for x in range(cx - 7, cx + 9):
		hel.px(x, top + 6, R("helmet")[1])
	L.autoshade(hel, [R("helmet")])
	# ridge highlight
	hel.px(cx - 2, top + 1, R("helmet")[4])
	hel.px(cx - 3, top + 2, R("helmet")[4])
	# lamp
	for y in range(top + 2, top + 5):
		for x in range(cx + 4, cx + 7):
			hel.px(x, y, R("lamp")[2])
	hel.px(cx + 4, top + 2, R("lamp")[3])
	hel.px(cx + 6, top + 3, P["light"])
	hel.px(cx + 7, top + 3, P["light"] if int(SEC["lamp"]) == 0 else P["light2"])
	hel.px(cx + 6, top + 2, P["light2"])
	hel.px(cx + 6, top + 4, P["light2"])
	return [face, hel]

func draw_head_back(cx: int, top: int) -> Array:
	var face := L.layer(32, 48)
	var hel := L.layer(32, 48)
	for y in range(top + 6, top + 12):
		var x0 := cx - 5
		var x1 := cx + 5
		if y == top + 11:
			x0 = cx - 3
			x1 = cx + 3
		for x in range(x0, x1 + 1):
			face.px(x, y, M("hair"))
	face.px(cx - 6, top + 8, M("skin"))
	face.px(cx + 6, top + 8, M("skin"))
	face.fill_rect(cx - 2, top + 12, 5, 1, M("skin"))
	if P["braid"]:
		for y in range(top + 11, top + 17):
			face.px(cx, y, M("hair"))
			face.px(cx + 1, y, M("hair"))
	L.autoshade(face, [R("skin"), R("hair")])
	var ccx := cx + 0.5
	var ccy := top + 6.5
	for y in range(top, top + 6):
		for x in range(cx - 8, cx + 9):
			var nx := (x + 0.5 - ccx) / 6.6
			var ny := (y + 0.5 - ccy) / 6.2
			if nx * nx + ny * ny <= 1.0:
				hel.px(x, y, M("helmet"))
	for x in range(cx - 7, cx + 8):
		hel.px(x, top + 6, R("helmet")[1])
	L.autoshade(hel, [R("helmet")])
	hel.px(cx - 2, top + 1, R("helmet")[4])
	# lamp strap
	for x in range(cx - 6, cx + 7):
		hel.px(x, top + 4, R("lamp")[1])
	return [face, hel]

# ----------------------------------------------------------------------------- full figure
## pose keys: hx, hip, ff, bf (ankles), fh, bh (hands, null to hide), lean, breath, blink, mouth
func figure(pose: Dictionary) -> PX.Canvas:
	var cv := L.layer(32, 48)
	var hx: int = pose.get("hx", 16)
	var hip: int = pose.get("hip", 38)
	var lean: int = pose.get("lean", 0)
	var breath: int = pose.get("breath", 0)
	var top := hip - 10 + breath
	var head_top := top - 13 + int(pose.get("headdy", 0))
	var head_cx := hx + lean
	var sh_f := Vector2(hx + 2.5 + lean * 0.9, top + 1.5)
	var sh_b := Vector2(hx - 2.0 + lean * 0.9, top + 1.5)
	var fh = pose.get("fh", null)
	var bh = pose.get("bh", null)
	SEC = {"pack_dy": pose.get("pack_dy", 0), "sway": pose.get("sway", 0), "lamp": pose.get("lamp", 0)}
	if pose.get("back", false):
		return figure_back(pose)
	if bh != null:
		L.comp(cv, draw_arm(sh_b, sh_b + bh, true))
	L.comp(cv, draw_leg(Vector2(hx - 1.5, hip + 0.5), pose["bf"], true))
	L.comp(cv, draw_pack(hx, hip, top, lean))
	L.comp(cv, draw_leg(Vector2(hx + 1.5, hip + 0.5), pose["ff"], false))
	L.comp(cv, draw_torso(hx, hip, top, lean))
	var hd := draw_head(head_cx, head_top, pose.get("blink", false), pose.get("mouth", false))
	L.comp(cv, hd[0])
	L.comp(cv, hd[1])
	if fh != null:
		var soft: Color = R("jacket")[0]
		L.comp(cv, draw_arm(sh_f, sh_f + fh, false), true, soft)
		silhouette_fix(cv, [soft])
	return cv

## Selective outlining: soft inner outlines become the strong outline where they touch the outside.
func silhouette_fix(cv: PX.Canvas, soft: Array) -> void:
	var keys := {}
	for s in soft:
		keys[L.key(s)] = true
	var src: Image = cv.img.duplicate()
	for y in cv.h:
		for x in cv.w:
			var p := src.get_pixel(x, y)
			if p.a < 0.5 or not keys.has(L.key(p)):
				continue
			if L._open(src, x + 1, y) or L._open(src, x - 1, y) or L._open(src, x, y + 1) or L._open(src, x, y - 1):
				cv.img.set_pixel(x, y, L.OUTLINE)

func figure_back(pose: Dictionary) -> PX.Canvas:
	var cv := L.layer(32, 48)
	var hx: int = pose.get("hx", 16)
	var hip: int = pose.get("hip", 38)
	var top := hip - 10
	var head_top := top - 13
	var sh_l := Vector2(hx - 3.5, top + 1.5)
	var sh_r := Vector2(hx + 4.5, top + 1.5)
	L.comp(cv, draw_leg(Vector2(hx - 1.5, hip + 0.5), pose["bf"], false))
	L.comp(cv, draw_leg(Vector2(hx + 2.5, hip + 0.5), pose["ff"], false))
	# torso (back): jacket with pants at bottom
	var t := L.layer(32, 48)
	for y in range(top, hip):
		var x0 := hx - 4
		var x1 := hx + 5
		if y == top:
			x0 += 1
			x1 -= 1
		for x in range(x0, x1 + 1):
			t.px(x, y, M("pants") if y >= hip - 3 else M("jacket"))
	L.autoshade(t, [R("jacket"), R("pants")])
	L.comp(cv, t)
	# backpack centred
	var pk := L.layer(32, 48)
	pk.fill_rect(hx - 3, top + 1, 8, hip - top - 2, M("pack"))
	if not P["braid"]:
		pk.fill_rect(hx - 4, top - 1, 10, 2, M("roll"))
	L.autoshade(pk, [R("pack"), R("roll")])
	pk.fill_rect(hx - 2, top + 4, 6, 1, R("pack")[1])
	pk.px(hx + 1, top + 5, L.c("ffd84a"))
	L.comp(cv, pk)
	var hd := draw_head_back(hx, head_top)
	L.comp(cv, hd[0])
	L.comp(cv, hd[1])
	L.comp(cv, draw_arm(sh_l, sh_l + pose["bh"], false))
	L.comp(cv, draw_arm(sh_r, sh_r + pose["fh"], false))
	return cv

# ----------------------------------------------------------------------------- animations
func A(x: float, y: float) -> Vector2:
	return Vector2(x, y)

func walk_pose(i: int, n: int, stride: float, lift_amt: float, run: bool) -> Dictionary:
	var p := TAU * float(i) / float(n)
	var hx := 16
	var fx := hx + 1.5 + stride * cos(p)
	var bx := hx - 1.0 + stride * cos(p + PI)
	var fl := lift_amt * maxf(0.0, -sin(p))
	var bl := lift_amt * maxf(0.0, -sin(p + PI))
	var bob := 1 if absf(cos(p)) > 0.7 else 0
	if run:
		bob = 2 if absf(cos(p)) > 0.75 else (0 if absf(cos(p)) < 0.35 else 1)
	var hip := 38 + bob
	var arm_amp := 4.0 if run else 2.6
	var fh := A(-arm_amp * cos(p) + (1.5 if run else 0.5), 4.5 if not run else 3.0)
	var bh := A(arm_amp * cos(p) + (1.5 if run else 0.0), 4.5 if not run else 3.0)
	return {"hx": hx, "hip": hip, "ff": A(fx, 45.5 - fl), "bf": A(bx, 45.5 - bl), "fh": fh, "bh": bh, "lean": 1 if run else 0}

func base_pose() -> Dictionary:
	return {"hx": 16, "hip": 38, "ff": A(18.5, 45.5), "bf": A(13.5, 45.5), "fh": A(0.5, 5.0), "bh": A(-0.5, 5.0)}

func with(d: Dictionary, extra: Dictionary) -> Dictionary:
	var o := d.duplicate()
	for k in extra:
		o[k] = extra[k]
	return o


## Explicit 8-key gait: contact, down, passing, up (x2). Returns pose list.
func gait(run: bool) -> Array:
	# per key: [front_foot_x, front_lift, back_foot_x, back_lift, bob, arm]
	var walk_keys := [
		[20.5, 0.0, 12.0, 0.0, 0, -2.5], [19.0, 0.0, 13.0, 1.0, 1, -1.5], [16.5, 0.0, 16.0, 2.5, 0, 0.0], [14.0, 0.0, 19.0, 1.0, -1, 1.5],
		[12.0, 0.0, 20.5, 0.0, 0, 2.5], [13.0, 1.0, 19.0, 0.0, 1, 1.5], [16.0, 2.5, 16.5, 0.0, 0, 0.0], [19.0, 1.0, 14.0, 0.0, -1, -1.5]]
	var run_keys := [
		[22.0, 0.0, 10.5, 1.0, 0, -4.0], [20.0, 0.0, 12.0, 2.5, 2, -2.5], [16.5, 0.0, 15.0, 4.0, 1, 0.0], [13.5, 1.0, 20.0, 3.0, -1, 2.5],
		[10.5, 1.0, 22.0, 0.0, 0, 4.0], [12.0, 2.5, 20.0, 0.0, 2, 2.5], [15.0, 4.0, 16.5, 0.0, 1, 0.0], [20.0, 3.0, 13.5, 1.0, -1, -2.5]]
	var keys: Array = run_keys if run else walk_keys
	var out: Array = []
	for k in keys:
		var bob: int = k[4]
		var arm: float = k[5]
		var hy := 2.5 if run else 4.5
		out.append({"hx": 16, "hip": 38 + bob, "ff": Vector2(k[0], 45.5 - k[1]), "bf": Vector2(k[2], 45.5 - k[3]),
			"fh": Vector2(arm + (1.5 if run else 0.5), hy), "bh": Vector2(-arm + (0.5 if run else -0.5), hy),
			"lean": 1 if run else 0, "mouth": run and bob == 2})
	return out

## Secondary motion: backpack + braid lag one frame behind the body; lamp flickers.
func add_secondary(rows: Array) -> void:
	for frames in rows:
		var n: int = frames.size()
		for f in n:
			var cur: Dictionary = frames[f]
			var prev: Dictionary = frames[(f - 1 + n) % n]
			var ct: int = int(cur.get("hip", 38)) + int(cur.get("breath", 0))
			var pt: int = int(prev.get("hip", 38)) + int(prev.get("breath", 0))
			if not cur.has("pack_dy"):
				cur["pack_dy"] = clampi(pt - ct, -1, 1)
			if not cur.has("sway"):
				cur["sway"] = clampi(pt - ct, -1, 1)
			if not cur.has("lamp"):
				cur["lamp"] = 1 if (f % 4 == 2) else 0

## 8x onion skin: each frame drawn over the previous frame ghosted in red.
func onion(sheet: Image, rows: Array, name: String) -> void:
	var fw := 32
	var fh := 48
	var out := Image.create(fw * 8, fh * rows.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.11, 0.18))
	for ri in rows.size():
		var r: int = rows[ri]
		var count := 0
		for f in 8:
			if sheet.get_region(Rect2i(f * fw, r * fh, fw, fh)).is_invisible():
				break
			count += 1
		for f in count:
			var prev := sheet.get_region(Rect2i(((f - 1 + count) % count) * fw, r * fh, fw, fh))
			var cur := sheet.get_region(Rect2i(f * fw, r * fh, fw, fh))
			for y in fh:
				for x in fw:
					var pc := prev.get_pixel(x, y)
					if pc.a > 0.5:
						out.set_pixel(f * fw + x, ri * fh + y, Color(0.9, 0.2, 0.25, 1).lerp(Color(0.1, 0.11, 0.18), 0.55))
			out.blend_rect(cur, Rect2i(0, 0, fw, fh), Vector2i(f * fw, ri * fh))
	L.preview(out, name, 8 if rows.size() <= 2 else 5, Vector2i(fw, fh))

func build_sheet(rows: Array, fw: int = 32, fh: int = 48, cols: int = 8) -> Image:
	add_secondary(rows)
	var sheet := Image.create(fw * cols, fh * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for r in rows.size():
		var frames: Array = rows[r]
		for f in frames.size():
			var cvs: PX.Canvas = figure(frames[f])
			sheet.blit_rect(cvs.img, Rect2i(0, 0, fw, fh), Vector2i(f * fw, r * fh))
	return sheet

func player_rows() -> Array:
	var b := base_pose()
	var rows: Array = []
	# 0 idle x4
	rows.append([b, with(b, {"breath": 0, "fh": A(0.5, 5.0)}), with(b, {"breath": 1, "fh": A(0.5, 4.5), "bh": A(-0.5, 4.5)}), with(b, {"breath": 1, "blink": true, "fh": A(0.5, 4.5), "bh": A(-0.5, 4.5)})])
	# 1 walk x8
	rows.append(gait(false))
	# 2 run x8
	rows.append(gait(true))
	# 3 jump x2
	rows.append([
		{"hx": 16, "hip": 41, "ff": A(19.5, 45.5), "bf": A(13.0, 45.5), "fh": A(-3.0, 3.5), "bh": A(-4.0, 2.5), "lean": 1, "headdy": 1},
		{"hx": 16, "hip": 37, "ff": A(19.0, 42.0), "bf": A(13.5, 43.0), "fh": A(4.0, -4.0), "bh": A(-3.0, -3.5), "lean": 0, "mouth": true},
	])
	# 4 fall x2
	rows.append([
		{"hx": 16, "hip": 37, "ff": A(20.0, 44.0), "bf": A(13.0, 45.5), "fh": A(4.0, -3.5), "bh": A(-4.0, -3.0), "mouth": true},
		{"hx": 16, "hip": 37, "ff": A(19.5, 45.0), "bf": A(12.5, 44.5), "fh": A(4.5, -4.5), "bh": A(-4.5, -2.0), "mouth": true},
	])
	# 5 land x2
	rows.append([
		{"hx": 16, "hip": 41, "ff": A(20.5, 45.5), "bf": A(11.5, 45.5), "fh": A(4.0, 2.5), "bh": A(-4.0, 2.5), "lean": 1},
		{"hx": 16, "hip": 39, "ff": A(19.5, 45.5), "bf": A(12.5, 45.5), "fh": A(2.0, 4.0), "bh": A(-2.0, 4.0)},
	])
	# 6 mine_body x4 (front arm hidden)
	rows.append([
		{"hx": 16, "hip": 38, "ff": A(20.5, 45.5), "bf": A(12.0, 45.5), "fh": null, "bh": A(2.5, 1.5), "lean": -1},
		{"hx": 16, "hip": 38, "ff": A(20.5, 45.5), "bf": A(12.0, 45.5), "fh": null, "bh": A(1.5, -2.0), "lean": -2, "headdy": -1},
		{"hx": 16, "hip": 39, "ff": A(20.5, 45.5), "bf": A(12.0, 45.5), "fh": null, "bh": A(4.5, 3.0), "lean": 2},
		{"hx": 16, "hip": 39, "ff": A(20.5, 45.5), "bf": A(12.0, 45.5), "fh": null, "bh": A(4.0, 4.0), "lean": 1},
	])
	# 7 collect x4
	rows.append([
		{"hx": 16, "hip": 39, "ff": A(19.5, 45.5), "bf": A(12.5, 45.5), "fh": A(3.0, 4.5), "bh": A(-1.0, 4.5), "lean": 1},
		{"hx": 16, "hip": 41, "ff": A(19.5, 45.5), "bf": A(12.5, 45.5), "fh": A(5.0, 6.5), "bh": A(0.0, 4.5), "lean": 3},
		{"hx": 16, "hip": 41, "ff": A(19.5, 45.5), "bf": A(12.5, 45.5), "fh": A(4.5, 6.0), "bh": A(0.0, 4.5), "lean": 3, "blink": true},
		{"hx": 16, "hip": 39, "ff": A(19.5, 45.5), "bf": A(12.5, 45.5), "fh": A(3.0, 0.5), "bh": A(-1.0, 4.5), "lean": 1, "mouth": true},
	])
	# 8 climb x4 (back view)
	rows.append([
		{"back": true, "hx": 16, "hip": 38, "ff": A(19.5, 45.5), "bf": A(13.5, 43.5), "fh": A(1.0, -9.0), "bh": A(-1.0, -5.0)},
		{"back": true, "hx": 16, "hip": 37, "ff": A(19.5, 44.5), "bf": A(13.5, 44.5), "fh": A(1.0, -7.0), "bh": A(-1.0, -7.0)},
		{"back": true, "hx": 16, "hip": 38, "ff": A(19.5, 43.5), "bf": A(13.5, 45.5), "fh": A(1.0, -5.0), "bh": A(-1.0, -9.0)},
		{"back": true, "hx": 16, "hip": 37, "ff": A(19.5, 44.5), "bf": A(13.5, 44.5), "fh": A(1.0, -7.0), "bh": A(-1.0, -7.0)},
	])
	# 9 interact x3
	rows.append([
		with(b, {"fh": A(3.5, 2.0), "lean": 0}),
		with(b, {"fh": A(5.5, -0.5), "lean": 1}),
		with(b, {"fh": A(5.5, 0.5), "lean": 1, "mouth": true}),
	])
	return rows

func mara_rows() -> Array:
	var b := base_pose()
	var rows: Array = []
	rows.append([b, b, with(b, {"breath": 1}), with(b, {"breath": 1, "blink": true})])
	rows.append([
		with(b, {"mouth": true, "fh": A(3.0, 2.0)}),
		with(b, {"mouth": false, "fh": A(3.5, 1.0)}),
		with(b, {"mouth": true, "fh": A(3.0, 0.0), "breath": 1}),
		with(b, {"mouth": false, "fh": A(2.0, 3.0)}),
	])
	rows.append([
		with(b, {"fh": A(4.5, -5.0), "mouth": true}),
		with(b, {"fh": A(5.5, -3.5), "mouth": true}),
		with(b, {"fh": A(4.5, -5.0), "mouth": true}),
		with(b, {"fh": A(3.5, -5.5), "mouth": false}),
	])
	return rows

# ----------------------------------------------------------------------------- tools
func tool_handle(cv, a: Vector2, b: Vector2, ramp: Array, rad: float = 1.0) -> void:
	L.thick(cv, [a, b], rad, ramp[2])

func glove(cv) -> void:
	var g := L.layer(32, 32)
	var gr: Array = pal_player()["glove"]
	# fist wrapped around the handle at (7,25)
	g.fill_rect(5, 23, 5, 5, gr[2])
	g.px(5, 23, Color(0, 0, 0, 0))
	g.px(9, 27, Color(0, 0, 0, 0))
	g.fill_rect(4, 25, 1, 2, gr[2])  # thumb side
	L.autoshade(g, [gr])
	g.px(6, 24, gr[3])
	g.px(7, 25, gr[1])
	g.px(8, 26, gr[1])
	g.px(9, 24, gr[1])
	L.comp(cv, g)

func pick_head(cv, ramp: Array, half: float, thick_c: float, curve: float, tipcol = null) -> void:
	# centre at (21,11), perpendicular u=(.707,.707), handle dir d=(-.707,.707)
	var C := Vector2(21.5, 10.5)
	var u := Vector2(0.7071, 0.7071)
	var d := Vector2(-0.7071, 0.7071)
	var pts: Array = []
	for i in range(-6, 7):
		var t := float(i) / 6.0
		var p := C + u * (t * half) + d * (curve * t * t) - d * 0.6
		pts.append(p)
	for i in pts.size():
		var t := absf(float(i - 6) / 6.0)
		var rr := lerpf(thick_c, 0.6, pow(t, 1.4))
		L.disc(cv, pts[i].x, pts[i].y, rr, ramp[2])
	if tipcol != null:
		var a: Vector2 = pts[0]
		var b2: Vector2 = pts[pts.size() - 1]
		cv.px(int(a.x), int(a.y), tipcol)
		cv.px(int(b2.x), int(b2.y), tipcol)

func tool_canvas(kind: int) -> PX.Canvas:
	var cv := L.layer(32, 32)
	var wood := L.r5("3a1e0c", "5e3416", "8a5528", "b07038", "d0904c")
	var dark_wood := L.r5("24140a", "3e2412", "5e3a1e", "7e5030", "9e6a40")
	var steel_h := L.r5("1e2232", "3c4458", "5a6378", "8a93a8", "c3cad8")
	match kind:
		0, 1, 2, 3, 4:
			var hl := L.layer(32, 32)
			var handle_ramp: Array = wood
			if kind == 2:
				handle_ramp = dark_wood
			if kind == 3:
				handle_ramp = L.r5("2a1a12", "4a2a1a", "6a3a24", "8a5034", "aa6a44")
			if kind == 4:
				handle_ramp = steel_h
			tool_handle(hl, Vector2(3.5, 28.5), Vector2(20.5, 11.5), handle_ramp, 1.0)
			L.autoshade(hl, [handle_ramp])
			if kind == 3:
				# leather wraps
				for i in range(3):
					var p := Vector2(11.5, 20.5) + Vector2(1, -1) * i * 1.5
					hl.px(int(p.x), int(p.y), L.c("2a1a12"))
			if kind == 0:
				# rope binding near head
				hl.px(18, 13, L.c("c8a060"))
				hl.px(19, 12, L.c("c8a060"))
			L.comp(cv, hl)
			var hd := L.layer(32, 32)
			var ramp: Array
			match kind:
				0: ramp = L.r5("2e2a2a", "4a4444", "6e6662", "948a84", "b8aea6")
				1: ramp = L.r5("5a2008", "9a4418", "d8742e", "f8a050", "ffd090")
				2: ramp = L.r5("1e2028", "3a3e4a", "5e6472", "8a92a2", "c0c8d6")
				3: ramp = L.r5("1a2a44", "3a5478", "6a8cb8", "a8c8ec", "eaf6ff")
				4: ramp = L.r5("2a1060", "4a2aa8", "6a5aff", "8ab8ff", "c8f4ff")
			var half := 8.5 + kind * 0.4
			pick_head(hd, ramp, half, 1.6 + kind * 0.15, 2.4, null)
			L.autoshade(hd, [ramp], 2)
			if kind == 4:
				# crystal facets & glow
				hd.px(19, 9, L.c("ffffff"))
				hd.px(24, 14, L.c("e8fcff"))
				hd.px(15, 6, L.c("b8fbff"))
			if kind == 3:
				hd.px(17, 7, L.c("ffffff"))
				hd.px(26, 16, L.c("ffffff"))
			L.comp(cv, hd)
			if kind == 4:
				L.glow(cv, L.c("5ff2ff", 0.8), 2)
		5:
			# diamond drill: body tube from grip to (18,14), conical spiral bit to (28,4)
			var body := L.layer(32, 32)
			var yel := L.r5("5a3a08", "a86a10", "f2b022", "ffd84a", "fff1a0")
			L.thick(body, [Vector2(5.5, 26.5), Vector2(10.5, 21.5)], 1.6, steel_h[2]) # grip
			L.thick(body, [Vector2(10.5, 21.5), Vector2(17.5, 14.5)], 3.2, yel[2])
			L.autoshade(body, [steel_h, yel], 2)
			body.px(12, 17, L.c("1b1424"))
			body.px(14, 15, L.c("1b1424"))
			body.px(13, 21, L.c("ff5a1f"))
			L.comp(cv, body)
			var bit := L.layer(32, 32)
			var dia := L.r5("0a4a6a", "1a90c0", "5ae0f8", "b0f8ff", "ffffff")
			for i in range(0, 11):
				var t := float(i) / 10.0
				var p := Vector2(18.0, 14.0).lerp(Vector2(28.0, 4.0), t)
				L.disc(bit, p.x, p.y, lerpf(2.8, 0.6, t), dia[2])
			L.autoshade(bit, [dia], 2)
			# spiral grooves
			for i in range(0, 4):
				var t2 := 0.15 + i * 0.2
				var p2 := Vector2(18.0, 14.0).lerp(Vector2(28.0, 4.0), t2)
				var off := Vector2(0.7, 0.7) * lerpf(2.0, 0.4, t2)
				bit.px(int(p2.x + off.x), int(p2.y + off.y), dia[0])
				bit.px(int(p2.x + off.x) - 1, int(p2.y + off.y) - 1, dia[1])
			bit.px(28, 4, L.c("ffffff"))
			L.comp(cv, bit)
			cv.px(29, 3, L.c("ffffff", 0.8))
		6:
			# plasma tool: dark metal shaft with glowing cyan fork emitter
			var shaft := L.layer(32, 32)
			var dm := L.r5("0e1020", "1e2238", "343a58", "565e84", "8a92b8")
			L.thick(shaft, [Vector2(3.5, 28.5), Vector2(18.5, 13.5)], 1.2, dm[2])
			L.disc(shaft, 18.5, 13.5, 2.2, dm[2])
			L.autoshade(shaft, [dm], 2)
			shaft.px(12, 19, L.c("d0a0ff"))
			shaft.px(14, 17, L.c("d0a0ff"))
			L.comp(cv, shaft)
			var cy := L.r5("3a0a6a", "6a1ab0", "a64cff", "d8a0ff", "ffffff")
			# glowing plasma pick blades (same silhouette family as the pickaxes)
			var arc := L.layer(32, 32)
			pick_head(arc, cy, 10.0, 1.7, 2.6, null)
			L.autoshade(arc, [cy], 2)
			L.thick(arc, [Vector2(16.5, 6.5), Vector2(26.5, 16.5)], 0.5, L.c("ffffff"))
			L.glow(arc, L.c("c08aff", 0.9), 2)
			cv.blit(arc.img, 0, 0)
			# dark emitter housing at the centre
			var em := L.layer(32, 32)
			em.fill_rect(19, 9, 4, 4, dm[2])
			L.autoshade(em, [dm])
			em.px(20, 10, L.c("ffffff"))
			em.px(21, 11, L.c("c08aff"))
			L.comp(cv, em)
		7:
			# portable drill: orange power drill with grey bit
			var bd := L.layer(32, 32)
			var org := L.r5("5a1a08", "a83a10", "ff6a1f", "ff9a4a", "ffc890")
			L.thick(bd, [Vector2(6.5, 26.5), Vector2(10.5, 22.5)], 1.6, L.r5("1e1e28", "2e2e3a", "44445a", "60607a", "8a8aa0")[2])
			L.thick(bd, [Vector2(9.5, 21.5), Vector2(17.5, 13.5)], 3.0, org[2])
			L.disc(bd, 10.0, 20.0, 3.3, org[2])
			L.autoshade(bd, [org, L.r5("1e1e28", "2e2e3a", "44445a", "60607a", "8a8aa0")], 2)
			bd.px(12, 18, L.c("1b1424"))
			bd.px(13, 19, L.c("ffd84a"))
			L.comp(cv, bd)
			var bit2 := L.layer(32, 32)
			L.thick(bit2, [Vector2(18.0, 13.0), Vector2(25.5, 5.5)], 0.9, steel_h[2])
			L.autoshade(bit2, [steel_h])
			bit2.px(20, 11, steel_h[0])
			bit2.px(22, 9, steel_h[0])
			bit2.px(24, 7, steel_h[0])
			L.comp(cv, bit2)
	glove(cv)
	return cv

# ----------------------------------------------------------------------------- portrait
func portrait(kind: int) -> PX.Canvas:
	P = pal_mara()
	var cv := L.layer(64, 64)
	var skin: Array = R("skin")
	var hair: Array = R("hair")
	var hel: Array = R("helmet")
	var jk: Array = R("jacket")
	# shoulders / jacket
	var body := L.layer(64, 64)
	body.ellipse(32, 66, 25, 16, jk[2])
	L.autoshade(body, [jk], 2)
	# collar + bandana
	body.polygon(PackedVector2Array([Vector2(22, 50), Vector2(42, 50), Vector2(36, 58), Vector2(28, 58)]), L.c("d03a3a"))
	body.polygon(PackedVector2Array([Vector2(29, 56), Vector2(35, 56), Vector2(32, 61)]), L.c("a82a2a"))
	body.px(30, 52, L.c("ff6a5a"))
	body.px(31, 52, L.c("ff6a5a"))
	# straps
	body.fill_rect(17, 54, 3, 10, R("pants")[2])
	body.fill_rect(44, 54, 3, 10, R("pants")[2])
	body.px(18, 58, L.c("ffd84a"))
	body.px(45, 58, L.c("ffd84a"))
	L.comp(cv, body)
	# braid over right shoulder (viewer's left)
	var br := L.layer(64, 64)
	for i in range(6):
		br.ellipse(15.0 - i * 0.3, 38.0 + i * 4.0, 3.2, 2.6, hair[2])
	L.autoshade(br, [hair], 2)
	for i in range(6):
		br.px(14, 37 + i * 4, hair[0])
		br.px(16, 39 + i * 4, hair[0])
	br.fill_rect(12, 60, 5, 2, L.c("3ac0b0"))
	L.comp(cv, br)
	# neck
	var nk := L.layer(64, 64)
	nk.fill_rect(27, 42, 10, 9, skin[2])
	L.autoshade(nk, [skin])
	nk.fill_rect(27, 42, 10, 2, skin[1])
	L.comp(cv, nk)
	# hair back mass
	var hb := L.layer(64, 64)
	hb.ellipse(32, 30, 17, 15, hair[2])
	L.autoshade(hb, [hair], 2)
	L.comp(cv, hb)
	# face
	var fc := L.layer(64, 64)
	fc.ellipse(32, 31, 13.5, 13, skin[2])
	fc.ellipse(32, 36, 11, 9, skin[2])
	L.autoshade(fc, [skin], 2)
	# ears
	fc.ellipse(18.5, 33, 2, 3, skin[2])
	fc.ellipse(45.5, 33, 2, 3, skin[2])
	fc.px(18, 33, skin[1])
	fc.px(45, 33, skin[1])
	L.comp(cv, fc)
	# bangs
	var bg := L.layer(64, 64)
	bg.polygon(PackedVector2Array([Vector2(18, 20), Vector2(46, 20), Vector2(46, 27), Vector2(40, 24), Vector2(36, 28), Vector2(31, 24), Vector2(25, 28), Vector2(20, 25), Vector2(18, 30)]), hair[2])
	L.autoshade(bg, [hair], 2)
	bg.px(26, 23, hair[4])
	bg.px(27, 22, hair[4])
	bg.px(37, 23, hair[4])
	L.comp(cv, bg)
	# eyes
	var ey := L.layer(64, 64)
	var wink := kind == 2
	for side in [-1, 1]:
		var ex: int = 32 + side * 6
		if wink and side == 1:
			ey.line(ex - 2, 33, ex + 2, 33, L.c("2a1424"))
			ey.px(ex - 2, 32, L.c("2a1424"))
			ey.px(ex + 2, 32, L.c("2a1424"))
			continue
		if kind == 0:
			# happy closed arcs ^ ^
			ey.px(ex - 2, 33, L.c("2a1424"))
			ey.px(ex - 1, 32, L.c("2a1424"))
			ey.px(ex, 31, L.c("2a1424"))
			ey.px(ex + 1, 32, L.c("2a1424"))
			ey.px(ex + 2, 33, L.c("2a1424"))
			continue
		ey.fill_rect(ex - 1, 30, 3, 5, L.c("2a1424"))
		ey.fill_rect(ex - 2, 31, 1, 3, L.c("2a1424"))
		ey.px(ex + 2, 31, L.c("2a1424"))
		ey.px(ex + 2, 32, L.c("2a1424"))
		ey.px(ex + 2, 33, L.c("2a1424"))
		ey.px(ex - 1, 31, L.c("3a8a6a"))
		ey.px(ex, 33, L.c("3a8a6a"))
		ey.px(ex, 31, L.c("ffffff"))
		ey.px(ex - 1, 30, L.c("ffffff"))
	# brows
	ey.line(23, 27, 28, 27, hair[1])
	ey.line(36, 27, 41, 27, hair[1])
	cv.blit(ey.img, 0, 0)
	# nose, blush, mouth
	cv.px(32, 36, skin[1])
	cv.px(33, 37, skin[1])
	for bx in [22, 23, 24, 40, 41, 42]:
		cv.blend(bx, 37, L.c("ff6a6a", 0.55))
	if kind == 1:
		cv.ellipse(32.5, 40.5, 2.5, 2.2, L.c("6a1a24"))
		cv.px(32, 41, L.c("e85a6a"))
		cv.px(33, 41, L.c("e85a6a"))
	else:
		cv.line(28, 39, 36, 39, L.c("6a1a24"))
		cv.px(27, 38, L.c("6a1a24"))
		cv.px(37, 38, L.c("6a1a24"))
		cv.line(29, 40, 35, 40, L.c("e85a6a"))
		cv.line(30, 41, 34, 41, L.c("6a1a24"))
		cv.line(29, 39, 35, 39, L.c("ffffff"))
	# helmet
	var hm := L.layer(64, 64)
	for y in range(4, 22):
		for x in range(10, 55):
			var nx := (x + 0.5 - 32.5) / 19.0
			var ny := (y + 0.5 - 22.0) / 17.0
			if nx * nx + ny * ny <= 1.0:
				hm.px(x, y, hel[2])
	# brim
	hm.fill_rect(9, 20, 47, 3, hel[1])
	hm.fill_rect(8, 21, 49, 2, hel[1])
	L.autoshade(hm, [hel], 2)
	# ridge
	hm.line(32, 5, 32, 19, hel[3])
	hm.line(33, 5, 33, 19, hel[1])
	hm.line(20, 9, 18, 14, hel[4])
	hm.line(21, 8, 19, 13, hel[4])
	L.comp(cv, hm)
	# headlamp
	var lp := L.layer(64, 64)
	lp.circle(32.5, 13.5, 5.0, R("lamp")[2])
	L.autoshade(lp, [R("lamp")], 2)
	lp.circle(32.5, 13.5, 3.2, L.c("ffe680"))
	lp.circle(32.0, 13.0, 1.8, L.c("fffbe0"))
	L.comp(cv, lp)
	# lamp glow
	var gl := L.layer(64, 64)
	gl.circle(32.5, 13.5, 3.0, L.c("ffffff"))
	L.glow(gl, L.c("fff1a0", 0.9), 4)
	for y in 64:
		for x in 64:
			var col := gl.img.get_pixel(x, y)
			if col.a > 0.0 and col.a < 0.9:
				cv.blend(x, y, col)
	# thumbs-up hand
	if kind == 2:
		var hd := L.layer(64, 64)
		var gr: Array = pal_player()["glove"]
		hd.fill_rect(45, 46, 11, 10, gr[2])
		hd.fill_rect(44, 48, 1, 6, gr[2])
		hd.fill_rect(48, 37, 4, 10, gr[2])  # thumb
		hd.px(48, 37, Color(0, 0, 0, 0))
		hd.fill_rect(44, 56, 12, 8, jk[2])
		L.autoshade(hd, [gr, jk], 2)
		for fy in [48, 51, 54]:
			hd.line(46, fy, 54, fy, gr[1])
		hd.px(50, 39, gr[4])
		L.comp(cv, hd)
	return cv

# ----------------------------------------------------------------------------- main
func _init() -> void:
	seed(7)
	P = pal_player()
	var psheet := build_sheet(player_rows())
	L.save(psheet, "sprites/player/player.png")
	L.preview(psheet, "ch_player.png", 4, Vector2i(32, 48))
	onion(psheet, [1, 2], "ch_onion_gait.png")
	onion(psheet, [0, 3, 5, 6], "ch_onion_misc.png")

	var tools := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	tools.fill(Color(0, 0, 0, 0))
	for k in 8:
		var tc := tool_canvas(k)
		tools.blit_rect(tc.img, Rect2i(0, 0, 32, 32), Vector2i(k * 32, 0))
	L.save(tools, "sprites/player/tools.png")
	L.preview(tools, "ch_tools.png", 6, Vector2i(32, 32))

	P = pal_mara()
	var msheet := build_sheet(mara_rows(), 32, 48, 4)
	# Mara faces LEFT
	msheet.flip_x()
	# flipping the whole sheet reverses frame order within rows; restore order
	var fixed := Image.create(msheet.get_width(), msheet.get_height(), false, Image.FORMAT_RGBA8)
	fixed.fill(Color(0, 0, 0, 0))
	for r in 3:
		for f in 4:
			fixed.blit_rect(msheet, Rect2i((3 - f) * 32, r * 48, 32, 48), Vector2i(f * 32, r * 48))
	L.save(fixed, "sprites/player/mara.png")
	L.preview(fixed, "ch_mara.png", 5, Vector2i(32, 48))
	onion(fixed, [0, 1, 2], "ch_onion_mara.png")

	var por := Image.create(192, 64, false, Image.FORMAT_RGBA8)
	por.fill(Color(0, 0, 0, 0))
	for k in 3:
		var pc := portrait(k)
		por.blit_rect(pc.img, Rect2i(0, 0, 64, 64), Vector2i(k * 64, 0))
	L.save(por, "sprites/player/mara_portrait.png")
	L.preview(por, "ch_portrait.png", 4, Vector2i(64, 64))
	quit()
