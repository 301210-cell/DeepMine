## Helpers shared by the DeepMine tile/decor/background generators.
extends RefCounted

const PX = preload("res://px.gd")

static func pal(arr: Array) -> Array[Color]:
	var o: Array[Color] = []
	for s in arr:
		o.append(Color.html(s))
	return o

static func lighten(c: Color, f: float) -> Color:
	return Color(lerpf(c.r, 1.0, f), lerpf(c.g, 0.96, f), lerpf(c.b, 0.84, f), c.a)

static func darken(c: Color, f: float) -> Color:
	return Color(lerpf(c.r, 0.03, f), lerpf(c.g, 0.03, f), lerpf(c.b, 0.09, f), c.a)

static func mix(a: Color, b: Color, t: float) -> Color:
	return Color(lerpf(a.r, b.r, t), lerpf(a.g, b.g, t), lerpf(a.b, b.b, t), lerpf(a.a, b.a, t))

static func h01(x: int, y: int, s: int) -> float:
	return PX.hash01(x, y, s)

static func ri(arr: Array[Color], i: int) -> Color:
	return arr[clampi(i, 0, arr.size() - 1)]

## Jittered grid points inside a period x period square.
static func jitter_points(grid: int, seed: int, jit: float = 0.85, period: float = 16.0) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var cs := period / grid
	for gy in grid:
		for gx in grid:
			var px_ := (gx + 0.5 + (h01(gx, gy, seed) - 0.5) * jit) * cs
			var py_ := (gy + 0.5 + (h01(gx, gy, seed + 77) - 0.5) * jit) * cs
			pts.append(Vector2(px_, py_))
	return pts

## Wrapped voronoi: returns [d1, d2, idx, nearest_point]
static func vor(p: Vector2, pts: Array[Vector2], period: float = 16.0) -> Array:
	var d1 := 1e9
	var d2 := 1e9
	var idx := -1
	var nq := Vector2.ZERO
	for i in pts.size():
		for oy in [-1, 0, 1]:
			for ox in [-1, 0, 1]:
				var q: Vector2 = pts[i] + Vector2(ox * period, oy * period)
				var d := p.distance_to(q)
				if d < d1:
					d2 = d1
					d1 = d
					idx = i
					nq = q
				elif d < d2:
					d2 = d
	return [d1, d2, idx, nq]

## 2D value noise wrapping with separate x / y periods (in pixels).
static func wnoise(x: float, y: float, scale: float, period_x: int, period_y: int, seed: int) -> float:
	var cx := maxi(1, int(round(period_x / scale)))
	var cy := maxi(1, int(round(period_y / scale)))
	var sx := float(period_x) / cx
	var sy := float(period_y) / cy
	var fx := x / sx
	var fy := y / sy
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var x0 := posmod(ix, cx)
	var x1 := posmod(ix + 1, cx)
	var y0 := posmod(iy, cy)
	var y1 := posmod(iy + 1, cy)
	return lerpf(lerpf(h01(x0, y0, seed), h01(x1, y0, seed), tx), lerpf(h01(x0, y1, seed), h01(x1, y1, seed), tx), ty)

static func fbm(x: float, y: float, scale: float, px_: int, py_: int, seed: int, oct: int = 3) -> float:
	var v := 0.0
	var amp := 0.5
	var tot := 0.0
	var s := scale
	for i in oct:
		v += wnoise(x, y, s, px_, py_, seed + i * 31) * amp
		tot += amp
		amp *= 0.5
		s *= 0.5
		if s < 1.0:
			break
	return v / tot

## Shaded lump (ore chunk / pebble). ramp dark->light, at least 5 entries.
static func lump(c, cx: float, cy: float, rx: float, ry: float, ramp: Array[Color], outline: Color, spec: bool = true) -> void:
	var x0 := int(floor(cx - rx - 1))
	var x1 := int(ceil(cx + rx + 1))
	var y0 := int(floor(cy - ry - 1))
	var y1 := int(ceil(cy + ry + 1))
	var tmp := Image.create(c.w, c.h, false, Image.FORMAT_RGBA8)
	tmp.fill(Color(0, 0, 0, 0))
	for yy in range(y0, y1 + 1):
		for xx in range(x0, x1 + 1):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			var nx := (xx + 0.5 - cx) / rx
			var ny := (yy + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var z := sqrt(maxf(0.0, 1.0 - d))
			var l := (-nx * 0.6 - ny * 0.8)
			var inten := 0.45 + 0.4 * l + 0.25 * z
			var n := ramp.size()
			var i := clampi(int(inten * (n - 1) + 0.5), 0, n - 2)
			tmp.set_pixel(xx, yy, ramp[i])
	# outline
	var src := tmp.duplicate() as Image
	for yy in range(y0 - 1, y1 + 2):
		for xx in range(x0 - 1, x1 + 2):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			if tmp.get_pixel(xx, yy).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx2: int = xx + o.x
				var ny2: int = yy + o.y
				if nx2 >= 0 and ny2 >= 0 and nx2 < c.w and ny2 < c.h and src.get_pixel(nx2, ny2).a > 0.0:
					tmp.set_pixel(xx, yy, outline)
					break
	if spec:
		var sx := int(cx - rx * 0.45)
		var sy := int(cy - ry * 0.5)
		if sx >= 0 and sy >= 0 and sx < c.w and sy < c.h and tmp.get_pixel(sx, sy).a > 0.0:
			tmp.set_pixel(sx, sy, ramp[ramp.size() - 1])
	c.blit(tmp, 0, 0)

## Faceted gem. shape: "hex", "diamond", "round", "rect", "tri"
static func gem(c, cx: float, cy: float, r: float, ramp: Array[Color], outline: Color, shape: String = "hex") -> void:
	var poly := PackedVector2Array()
	match shape:
		"hex":
			for i in 6:
				var a := PI / 6.0 + i * PI / 3.0
				poly.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * 0.95))
		"diamond":
			poly = PackedVector2Array([Vector2(cx, cy - r * 1.15), Vector2(cx + r * 0.9, cy), Vector2(cx, cy + r * 1.15), Vector2(cx - r * 0.9, cy)])
		"round":
			for i in 8:
				var a := PI / 8.0 + i * PI / 4.0
				poly.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		"rect":
			poly = PackedVector2Array([Vector2(cx - r * 0.7, cy - r), Vector2(cx + r * 0.7, cy - r), Vector2(cx + r, cy - r * 0.7), Vector2(cx + r, cy + r * 0.7), Vector2(cx + r * 0.7, cy + r), Vector2(cx - r * 0.7, cy + r), Vector2(cx - r, cy + r * 0.7), Vector2(cx - r, cy - r * 0.7)])
		"tri":
			poly = PackedVector2Array([Vector2(cx, cy - r * 1.1), Vector2(cx + r, cy + r * 0.8), Vector2(cx - r, cy + r * 0.8)])
	var tmp := Image.create(c.w, c.h, false, Image.FORMAT_RGBA8)
	tmp.fill(Color(0, 0, 0, 0))
	var n := ramp.size()
	for yy in range(int(cy - r - 2), int(cy + r + 3)):
		for xx in range(int(cx - r - 2), int(cx + r + 3)):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			var p := Vector2(xx + 0.5, yy + 0.5)
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			var dx := (p.x - cx) / r
			var dy := (p.y - cy) / r
			var i := 2
			var s := dx + dy
			if absf(dx) < 0.42 and absf(dy) < 0.42:
				i = 3 # table facet
				if dx + dy < -0.2:
					i = 4
			elif s < -0.45:
				i = 4
			elif s < 0.05:
				i = 3
			elif s < 0.6:
				i = 2
			else:
				i = 1
			tmp.set_pixel(xx, yy, ramp[clampi(i, 0, n - 1)])
	var src := tmp.duplicate() as Image
	for yy in range(int(cy - r - 3), int(cy + r + 4)):
		for xx in range(int(cx - r - 3), int(cx + r + 4)):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			if tmp.get_pixel(xx, yy).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx2: int = xx + o.x
				var ny2: int = yy + o.y
				if nx2 >= 0 and ny2 >= 0 and nx2 < c.w and ny2 < c.h and src.get_pixel(nx2, ny2).a > 0.0:
					tmp.set_pixel(xx, yy, outline)
					break
	# sparkle
	var sx := int(cx - r * 0.35)
	var sy := int(cy - r * 0.45)
	if sx >= 0 and sy >= 0 and sx < c.w and sy < c.h and tmp.get_pixel(sx, sy).a > 0.0:
		tmp.set_pixel(sx, sy, Color(1, 1, 1))
	c.blit(tmp, 0, 0)

## Crystal prism growing from (bx,by) upward, rotated by ang (degrees).
static func crystal(c, bx: float, by: float, height: float, width: float, ang: float, ramp: Array[Color], outline: Color) -> void:
	var a := deg_to_rad(ang)
	var up := Vector2(sin(a), -cos(a))
	var right := Vector2(cos(a), sin(a))
	var hw := width * 0.5
	var tip := Vector2(bx, by) + up * height
	var shoulder := height - width * 0.8
	var p_l := Vector2(bx, by) - right * hw
	var p_r := Vector2(bx, by) + right * hw
	var s_l := Vector2(bx, by) - right * hw + up * shoulder
	var s_r := Vector2(bx, by) + right * hw + up * shoulder
	var poly := PackedVector2Array([p_l, s_l, tip, s_r, p_r])
	var tmp := Image.create(c.w, c.h, false, Image.FORMAT_RGBA8)
	tmp.fill(Color(0, 0, 0, 0))
	var n := ramp.size()
	var minx := int(minf(minf(p_l.x, tip.x), p_r.x) - 2)
	var maxx := int(maxf(maxf(p_l.x, tip.x), p_r.x) + 2)
	var miny := int(minf(minf(p_l.y, tip.y), p_r.y) - 2)
	var maxy := int(maxf(maxf(p_l.y, tip.y), p_r.y) + 2)
	for yy in range(miny, maxy + 1):
		for xx in range(minx, maxx + 1):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			var p := Vector2(xx + 0.5, yy + 0.5)
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			var rel := p - Vector2(bx, by)
			var side := rel.dot(right) / maxf(hw, 0.5)
			var along := rel.dot(up) / maxf(height, 1.0)
			var i := 2
			if side < -0.25:
				i = 3
			elif side > 0.35:
				i = 1
			if along > 0.62 and side < 0.2:
				i += 1
			if absf(side + 0.1) < 0.18 and along > 0.15:
				i = 4
			tmp.set_pixel(xx, yy, ramp[clampi(i, 0, n - 1)])
	var src := tmp.duplicate() as Image
	for yy in range(miny - 1, maxy + 2):
		for xx in range(minx - 1, maxx + 2):
			if xx < 0 or yy < 0 or xx >= c.w or yy >= c.h:
				continue
			if tmp.get_pixel(xx, yy).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx2: int = xx + o.x
				var ny2: int = yy + o.y
				if nx2 >= 0 and ny2 >= 0 and nx2 < c.w and ny2 < c.h and src.get_pixel(nx2, ny2).a > 0.0:
					tmp.set_pixel(xx, yy, outline)
					break
	c.blit(tmp, 0, 0)

## Soft additive-looking glow (pre-blended alpha) around a point.
static func glow(c, cx: float, cy: float, r: float, col: Color, strength: float = 0.5) -> void:
	for yy in range(int(cy - r - 1), int(cy + r + 2)):
		for xx in range(int(cx - r - 1), int(cx + r + 2)):
			if not c.inb(xx, yy):
				continue
			var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var a := (1.0 - d) * (1.0 - d) * strength
			# quantise for pixel look
			a = floor(a * 6.0) / 6.0
			if a <= 0.0:
				continue
			c.blend(xx, yy, Color(col.r, col.g, col.b, a))

static func scale_nearest(img: Image, f: int) -> Image:
	var o := img.duplicate() as Image
	o.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	return o

static func preview_dir() -> String:
	return "C:/Users/Jeremy/AppData/Local/Temp/claude/8bd127b22df0a1ed/aa2076d7-1a4a-41ce-aca4-0aa005bd01b8/scratchpad/previews"

static func save_preview(img: Image, name: String, f: int = 4) -> void:
	DirAccess.make_dir_recursive_absolute(preview_dir())
	var o := scale_nearest(img, f)
	o.save_png(preview_dir().path_join(name))
	print("preview ", name)
