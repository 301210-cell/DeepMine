## Character/icon art helpers (used by gen_player.gd and gen_icons.gd).
extends RefCounted
const PX = preload("res://px.gd")

const OUTLINE := Color(0.106, 0.078, 0.141) # 1b1424
const PREVIEW_DIR := "C:/Users/Jeremy/AppData/Local/Temp/claude/8bd127b22df0a1ed/aa2076d7-1a4a-41ce-aca4-0aa005bd01b8/scratchpad/previews"

static func c(s: String, a: float = 1.0) -> Color:
	var col := Color.html(s)
	col.a = a
	return col

## Make a 5-step ramp [darkest, dark, mid, light, lightest] from three hex strings + extremes.
static func r5(d2: String, d1: String, m: String, l1: String, l2: String) -> Array:
	return [c(d2), c(d1), c(m), c(l1), c(l2)]

static func key(col: Color) -> String:
	return col.to_html(false)

static func _open(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return true
	return img.get_pixel(x, y).a < 0.5

## Replace every pixel whose colour equals ramp[2] (mid) with a shade based on exposure
## (light from top-left). ramps: Array of 5-colour arrays.
static func autoshade(cv: PX.Canvas, ramps: Array, strength: int = 1) -> void:
	var lut := {}
	for r in ramps:
		lut[key(r[2])] = r
	var src: Image = cv.img.duplicate()
	for y in cv.h:
		for x in cv.w:
			var p := src.get_pixel(x, y)
			if p.a < 0.5:
				continue
			var k := key(p)
			if not lut.has(k):
				continue
			var r: Array = lut[k]
			var up := _open(src, x, y - 1)
			var lf := _open(src, x - 1, y)
			var dn := _open(src, x, y + 1)
			var rt := _open(src, x + 1, y)
			var lv := 0
			if dn or rt:
				lv = -1
				if dn and rt:
					lv = -2 if strength > 1 else -1
			if up or lf:
				lv = 1 if lv >= 0 else 0
				if up and lf and lv > 0:
					lv = 2 if strength > 1 else 1
			if lv == 0 and strength > 1:
				# second ring: soft shading one pixel further in
				if _open(src, x, y + 2) or _open(src, x + 2, y):
					lv = -1 if randf() < 0.0 else 0
			cv.img.set_pixel(x, y, r[2 + lv])

## Draw a thick polyline by stamping discs.
static func thick(cv: PX.Canvas, pts: Array, radius: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) * 2.0)) + 1
		for s in n + 1:
			var p := a.lerp(b, float(s) / float(maxi(n, 1)))
			disc(cv, p.x, p.y, radius, col)
	if pts.size() == 1:
		disc(cv, pts[0].x, pts[0].y, radius, col)

## Pixel-exact disc: radius 0.5 -> 1px, 1.0 -> plus, 1.5 -> 3x3, 2 -> 4-5px
static func disc(cv: PX.Canvas, cx: float, cy: float, r: float, col: Color) -> void:
	var r2 := r * r
	for yy in range(int(floor(cy - r - 1)), int(ceil(cy + r + 1)) + 1):
		for xx in range(int(floor(cx - r - 1)), int(ceil(cx + r + 1)) + 1):
			var dx := (xx + 0.5) - cx
			var dy := (yy + 0.5) - cy
			if dx * dx + dy * dy <= r2 + 0.01:
				cv.px(xx, yy, col)

## Paint from a character map. pal: Dictionary char -> Color. '.' / ' ' are transparent.
static func pmap(cv: PX.Canvas, ox: int, oy: int, rows: Array, pal: Dictionary, flip: bool = false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		var w := row.length()
		for x in w:
			var ch := row[x]
			if ch == "." or ch == " ":
				continue
			if pal.has(ch):
				var dx := (w - 1 - x) if flip else x
				cv.px(ox + dx, oy + y, pal[ch])

## Composite a layer onto dst after giving it its own outline.
static func comp(dst: PX.Canvas, layer: PX.Canvas, outline: bool = true, ocol: Color = OUTLINE) -> void:
	if outline:
		layer.outline(ocol)
	dst.blit(layer.img, 0, 0)

static func layer(w: int, h: int) -> PX.Canvas:
	return PX.Canvas.new(w, h)

## 4-point sparkle
static func sparkle(cv: PX.Canvas, x: int, y: int, col: Color, size: int = 1) -> void:
	cv.px(x, y, col)
	for i in range(1, size + 1):
		var a := col
		if i == size and size > 1:
			a = Color(col.r, col.g, col.b, col.a * 0.7)
		cv.blend(x + i, y, a)
		cv.blend(x - i, y, a)
		cv.blend(x, y + i, a)
		cv.blend(x, y - i, a)

## Additive-ish glow ring around opaque pixels.
static func glow(cv: PX.Canvas, col: Color, radius: int = 2) -> void:
	var src: Image = cv.img.duplicate()
	for y in cv.h:
		for x in cv.w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var best := 99.0
			for oy in range(-radius, radius + 1):
				for ox in range(-radius, radius + 1):
					var nx := x + ox
					var ny := y + oy
					if nx >= 0 and ny >= 0 and nx < cv.w and ny < cv.h and src.get_pixel(nx, ny).a > 0.5:
						best = minf(best, sqrt(ox * ox + oy * oy))
			if best <= radius:
				var a := col.a * (1.0 - (best - 1.0) / float(radius)) * 0.6
				if a > 0.05:
					cv.blend(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))

## Save an upscaled preview with a grid.
static func preview(img: Image, name: String, scale: int, cell: Vector2i = Vector2i.ZERO, bg: Color = Color(0.12, 0.13, 0.22)) -> void:
	var w := img.get_width() * scale
	var h := img.get_height() * scale
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(bg)
	var big: Image = img.duplicate()
	big.resize(w, h, Image.INTERPOLATE_NEAREST)
	out.blend_rect(big, Rect2i(0, 0, w, h), Vector2i.ZERO)
	if cell != Vector2i.ZERO:
		var gc := Color(1, 1, 1, 0.18)
		for x in range(0, w, cell.x * scale):
			for y in h:
				out.set_pixel(x, y, gc)
		for y in range(0, h, cell.y * scale):
			for x in w:
				out.set_pixel(x, y, gc)
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIR)
	out.save_png(PREVIEW_DIR.path_join(name))

static func save(img: Image, rel: String) -> void:
	var path := PX.out_root().path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("saved ", rel, " ", img.get_width(), "x", img.get_height(), " err=", err)
