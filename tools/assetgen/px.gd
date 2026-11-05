## Shared pixel-art drawing helpers for DeepMine asset generators.
## Usage inside a generator (extends SceneTree):
##   const PX = preload("res://px.gd")
##   var c := PX.Canvas.new(64, 64)
##   c.fill_rect(0, 0, 16, 16, PX.hex("1e2650"))
##   c.save("tilesets/terrain.png")   # relative to DeepMine/assets
extends RefCounted

static func out_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../../assets").simplify_path()

static func hex(s: String, a: float = 1.0) -> Color:
	var c := Color.html(s)
	c.a = a
	return c

## Deterministic hash noise in [0,1).
static func hash01(x: int, y: int, seed: int = 0) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0

## Smooth value noise in [0,1).
static func vnoise(x: float, y: float, scale: float, seed: int = 0) -> float:
	var fx := x / scale
	var fy := y / scale
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := hash01(ix, iy, seed)
	var b := hash01(ix + 1, iy, seed)
	var c := hash01(ix, iy + 1, seed)
	var d := hash01(ix + 1, iy + 1, seed)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

## Tileable value noise (wraps every `period` pixels).
static func vnoise_wrap(x: float, y: float, scale: float, period: int, seed: int = 0) -> float:
	var cells := maxi(1, int(round(period / scale)))
	var fx := x / scale
	var fy := y / scale
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var x0 := posmod(ix, cells)
	var x1 := posmod(ix + 1, cells)
	var y0 := posmod(iy, cells)
	var y1 := posmod(iy + 1, cells)
	return lerpf(lerpf(hash01(x0, y0, seed), hash01(x1, y0, seed), tx), lerpf(hash01(x0, y1, seed), hash01(x1, y1, seed), tx), ty)

## Build a hue-shifted shade ramp from dark to light around a base colour.
static func ramp(base: Color, steps: int = 5, spread: float = 0.55, hue_shift: float = 0.06) -> Array[Color]:
	var out: Array[Color] = []
	for i in steps:
		var t := (float(i) / float(steps - 1)) * 2.0 - 1.0 # -1..1
		var c := base
		var h := fposmod(c.h + (-hue_shift if t < 0.0 else hue_shift * 0.6) * absf(t), 1.0)
		var v := clampf(c.v + t * spread * 0.5, 0.03, 1.0)
		var s := clampf(c.s * (1.0 - t * 0.25), 0.0, 1.0)
		out.append(Color.from_hsv(h, s, v, c.a))
	return out


class Canvas:
	var img: Image
	var w: int
	var h: int

	func _init(width: int, height: int, fill: Color = Color(0, 0, 0, 0)) -> void:
		w = width
		h = height
		img = Image.create(width, height, false, Image.FORMAT_RGBA8)
		img.fill(fill)

	func inb(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h

	func px(x: int, y: int, c: Color) -> void:
		if inb(x, y):
			img.set_pixel(x, y, c)

	## Alpha-blend a pixel over what is there.
	func blend(x: int, y: int, c: Color) -> void:
		if not inb(x, y):
			return
		var d := img.get_pixel(x, y)
		img.set_pixel(x, y, d.blend(c))

	func get_px(x: int, y: int) -> Color:
		if not inb(x, y):
			return Color(0, 0, 0, 0)
		return img.get_pixel(x, y)

	func fill_rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				px(xx, yy, c)

	func rect_outline(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for xx in range(x, x + rw):
			px(xx, y, c)
			px(xx, y + rh - 1, c)
		for yy in range(y, y + rh):
			px(x, yy, c)
			px(x + rw - 1, yy, c)

	func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			px(x0, y0, c)
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, filled: bool = true) -> void:
		for yy in range(int(floor(cy - ry - 1)), int(ceil(cy + ry + 1)) + 1):
			for xx in range(int(floor(cx - rx - 1)), int(ceil(cx + rx + 1)) + 1):
				var nx := (xx + 0.5 - cx) / maxf(rx, 0.01)
				var ny := (yy + 0.5 - cy) / maxf(ry, 0.01)
				var d := nx * nx + ny * ny
				if filled:
					if d <= 1.0:
						px(xx, yy, c)
				elif d <= 1.0 and d >= 0.62:
					px(xx, yy, c)

	func circle(cx: float, cy: float, r: float, c: Color, filled: bool = true) -> void:
		ellipse(cx, cy, r, r, c, filled)

	## Scanline polygon fill. pts = PackedVector2Array of vertices.
	func polygon(pts: PackedVector2Array, c: Color) -> void:
		if pts.size() < 3:
			return
		var miny := INF
		var maxy := -INF
		for p in pts:
			miny = minf(miny, p.y)
			maxy = maxf(maxy, p.y)
		for yy in range(int(floor(miny)), int(ceil(maxy)) + 1):
			var sy := yy + 0.5
			var xs: Array[float] = []
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
					xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var i2 := 0
			while i2 + 1 < xs.size():
				for xx in range(int(round(xs[i2])), int(round(xs[i2 + 1]))):
					px(xx, yy, c)
				i2 += 2

	## Add a 1px outline of colour `c` around every opaque pixel (4-neighbour).
	func outline(c: Color, alpha_threshold: float = 0.5, diagonal: bool = false) -> void:
		var src := img.duplicate() as Image
		for yy in h:
			for xx in w:
				if src.get_pixel(xx, yy).a >= alpha_threshold:
					continue
				var hit := false
				for o in ([Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)] if not diagonal else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]):
					var nx: int = xx + o.x
					var ny: int = yy + o.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a >= alpha_threshold:
						hit = true
						break
				if hit:
					img.set_pixel(xx, yy, c)

	## Copy another canvas/image region onto this one with alpha blending.
	func blit(src: Image, dx: int, dy: int, sx: int = 0, sy: int = 0, sw: int = -1, sh: int = -1, flip_h: bool = false) -> void:
		if sw < 0:
			sw = src.get_width()
		if sh < 0:
			sh = src.get_height()
		for yy in sh:
			for xx in sw:
				var c := src.get_pixel(sx + (sw - 1 - xx if flip_h else xx), sy + yy)
				if c.a > 0.0:
					blend(dx + xx, dy + yy, c)

	## Multiply brightness of all pixels in region.
	func shade_rect(x: int, y: int, rw: int, rh: int, mul: float) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				if inb(xx, yy):
					var c := img.get_pixel(xx, yy)
					img.set_pixel(xx, yy, Color(c.r * mul, c.g * mul, c.b * mul, c.a))

	func save(rel_path: String) -> void:
		var path := PX_out().path_join(rel_path)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := img.save_png(path)
		print("saved ", rel_path, " (", w, "x", h, ") err=", err)

	static func PX_out() -> String:
		return ProjectSettings.globalize_path("res://").path_join("../../assets").simplify_path()
