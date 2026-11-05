## Camp / machines / menu drawing kit (DeepMine asset generator).
## Static helpers operating on PX.Canvas. Ramps are dark -> light.
extends RefCounted

const PX = preload("res://px.gd")

static func pal(a: Array) -> Array[Color]:
	var out: Array[Color] = []
	for s in a:
		out.append(Color.html(s))
	return out

static var OUT: Color = Color.html("0b0d18")
static var OUTW: Color = Color.html("1a0e0a")
static var WOOD: Array[Color] = pal(["24130a", "3e2312", "5c361a", "834e26", "ad6c36", "d69454", "f0bc7a"])
static var STONE: Array[Color] = pal(["171b28", "262c3e", "394257", "535e78", "76829c", "a2acc2", "d0d6e4"])
static var WSTONE: Array[Color] = pal(["1e1818", "332a2a", "4c403c", "6a5a52", "8e7a6c", "b6a090", "d8c6b4"])
static var METAL: Array[Color] = pal(["14182a", "262c40", "3c465e", "5a6680", "8290aa", "b4bed2", "e6ecf6"])
static var RUST: Array[Color] = pal(["2e140c", "552414", "80381c", "a8522a", "cc7440", "eaa068"])
static var FIRE: Array[Color] = pal(["4a0a04", "8e1a06", "d23c0c", "ff6a1a", "ffa22c", "ffd862", "fff6cc"])
static var BLUE: Array[Color] = pal(["0c1640", "17337e", "2560e0", "3f96ff", "5fe6ff", "b8fbff", "ffffff"])
static var PURP: Array[Color] = pal(["1a0e32", "341a62", "54299a", "7a44d4", "a476ff", "d2acff", "f4e8ff"])
static var GOLD: Array[Color] = pal(["4e2c06", "80520e", "b8821c", "f0b830", "ffd86a", "fff4c4"])
static var RED: Array[Color] = pal(["3e0a12", "6e121e", "a6202e", "d8384a", "ff6c78", "ffb0b4"])
static var CLOTH: Array[Color] = pal(["4a4234", "776a52", "a69676", "cfc2a2", "efe6d0", "fffaf0"])
static var GREEN: Array[Color] = pal(["0c2416", "164226", "236a34", "3a9a42", "6ccc5a", "b0f08a", "e6ffd0"])
static var TEAL: Array[Color] = pal(["0a2230", "123e4c", "1e6670", "2e9696", "52c8bc", "a8f0e0"])
static var NAVY: Array[Color] = pal(["070a1c", "0b1026", "141a3a", "1e2650", "2a3466", "3c4a86"])
static var CYAN: Array[Color] = pal(["0a3a4a", "107a8c", "22b8cc", "5ff2ff", "b8fbff", "ffffff"])
static var GLASS: Array[Color] = pal(["101830", "1c2c50", "2c4878", "4878a8", "88b8e0"])

static func rnd(x: int, y: int, s: int = 0) -> float:
	return PX.hash01(x, y, s)

static func ci(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## Filled rect with bevel: highlight top/left, shadow bottom/right (ramp index base).
static func bevel_rect(c, x: int, y: int, w: int, h: int, r: Array[Color], base: int, outline: bool = false) -> void:
	c.fill_rect(x, y, w, h, r[base])
	c.fill_rect(x, y, w, 1, r[mini(base + 2, r.size() - 1)])
	c.fill_rect(x, y + 1, 1, h - 1, r[mini(base + 1, r.size() - 1)])
	c.fill_rect(x, y + h - 1, w, 1, r[maxi(base - 2, 0)])
	c.fill_rect(x + w - 1, y + 1, 1, h - 1, r[maxi(base - 1, 0)])
	if outline:
		c.rect_outline(x - 1, y - 1, w + 2, h + 2, OUT)

## Stone brick wall.
static func bricks(c, x: int, y: int, w: int, h: int, r: Array[Color], bw: int = 8, bh: int = 5, seed: int = 1, light_left: bool = true) -> void:
	c.fill_rect(x, y, w, h, r[0])
	var row := 0
	var yy := y
	while yy < y + h:
		var off := 0 if row % 2 == 0 else -bw / 2
		var xx := x + off
		var col := 0
		while xx < x + w:
			var bx0 := maxi(xx, x)
			var bx1 := mini(xx + bw - 1, x + w)
			var by1 := mini(yy + bh - 1, y + h)
			if bx1 - bx0 >= 1:
				var v := rnd(col, row, seed)
				var base := 2 + (1 if v > 0.62 else 0) - (1 if v < 0.15 else 0)
				for py in range(yy, by1):
					for pxx in range(bx0, bx1):
						var cc: Color = r[base]
						if py == yy:
							cc = r[mini(base + 2, r.size() - 1)]
						elif py == by1 - 1:
							cc = r[maxi(base - 1, 1)]
						elif pxx == bx0 and light_left:
							cc = r[mini(base + 1, r.size() - 1)]
						# tiny speckles
						if rnd(pxx, py, seed + 7) > 0.93:
							cc = r[maxi(base - 1, 1)]
						c.px(pxx, py, cc)
			xx += bw
			col += 1
		yy += bh
		row += 1

## Wooden planks (vertical or horizontal) with grain and seams.
static func planks(c, x: int, y: int, w: int, h: int, r: Array[Color], pw: int = 4, vertical: bool = true, seed: int = 3, base: int = 3) -> void:
	for py in range(y, y + h):
		for pxx in range(x, x + w):
			var along := py - y if vertical else pxx - x
			var across := pxx - x if vertical else py - y
			var plank := across / pw
			var inp := across % pw
			var pv := rnd(plank, 0, seed)
			var b := base + (1 if pv > 0.7 else 0) - (1 if pv < 0.25 else 0)
			var cc: Color = r[b]
			if inp == 0:
				cc = r[mini(b + 1, r.size() - 1)]
			elif inp == pw - 1:
				cc = r[maxi(b - 2, 0)]
			else:
				var g := PX.vnoise(float(along), float(plank * 13 + inp), 5.0, seed)
				if g > 0.72:
					cc = r[maxi(b - 1, 0)]
			# end seams
			var seg_len := 13 + int(pv * 9)
			if (along + int(pv * 31)) % seg_len == 0 and inp != 0:
				cc = r[maxi(b - 2, 0)]
			c.px(pxx, py, cc)

## Timber beam with dark outline, highlight and grain.
static func beam(c, x: int, y: int, w: int, h: int, horizontal: bool = true, seed: int = 5) -> void:
	var r := WOOD
	for py in range(y, y + h):
		for pxx in range(x, x + w):
			var t := float(py - y) / maxf(1.0, h - 1) if horizontal else float(pxx - x) / maxf(1.0, w - 1)
			var b := 4 if t < 0.25 else (3 if t < 0.7 else 2)
			var along := pxx if horizontal else py
			var across := py if horizontal else pxx
			if PX.vnoise(float(along), float(across) * 3.0, 6.0, seed) > 0.7:
				b -= 1
			c.px(pxx, py, r[b])
	c.rect_outline(x, y, w, h, r[0])
	# end grain / nails
	if horizontal:
		c.px(x + 2, y + h / 2, METAL[5]); c.px(x + w - 3, y + h / 2, METAL[5])
	else:
		c.px(x + w / 2, y + 2, METAL[5]); c.px(x + w / 2, y + h - 3, METAL[5])

## Soft glow (quantised alpha so it stays pixel-crisp).
static func glow(c, cx: float, cy: float, rad: float, col: Color, amax: float = 0.5) -> void:
	for yy in range(int(cy - rad), int(cy + rad) + 1):
		for xx in range(int(cx - rad), int(cx + rad) + 1):
			var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length() / rad
			if d >= 1.0:
				continue
			var a := amax * pow(1.0 - d, 1.6)
			a = floor(a * 10.0) / 10.0
			if a <= 0.0:
				continue
			c.blend(xx, yy, ci(col, a))

## Additive brighten of existing opaque pixels inside radius (for light pooling on walls).
static func light(c, cx: float, cy: float, rad: float, col: Color, strength: float = 0.5) -> void:
	for yy in range(int(cy - rad), int(cy + rad) + 1):
		for xx in range(int(cx - rad), int(cx + rad) + 1):
			if not c.inb(xx, yy):
				continue
			var p: Color = c.get_px(xx, yy)
			if p.a < 0.5:
				continue
			var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length() / rad
			if d >= 1.0:
				continue
			var k := strength * pow(1.0 - d, 1.4)
			k = floor(k * 8.0) / 8.0
			if k <= 0.0:
				continue
			c.px(xx, yy, Color(minf(1.0, p.r + col.r * k), minf(1.0, p.g + col.g * k), minf(1.0, p.b + col.b * k), p.a))

## Small hanging lantern; top = hook point. flick 0..3 alters flame.
static func lantern(c, cx: int, top: int, flick: int = 0, with_glow: bool = true, hook: bool = true) -> void:
	if with_glow:
		glow(c, cx + 0.5, top + 6.5, 13.0, FIRE[5], 0.45)
	if hook:
		c.px(cx, top, METAL[2])
	# cap
	c.fill_rect(cx - 1, top + 1, 3, 1, METAL[1])
	c.fill_rect(cx - 2, top + 2, 5, 1, METAL[2])
	# glass body
	c.fill_rect(cx - 2, top + 3, 5, 5, METAL[1])
	c.fill_rect(cx - 1, top + 3, 3, 5, FIRE[5])
	c.px(cx, top + 5 - (flick % 2), FIRE[6])
	c.px(cx, top + 6, FIRE[6])
	c.px(cx - 1, top + 7, FIRE[4])
	c.px(cx + 1, top + 3 + (flick % 3), FIRE[4])
	# base
	c.fill_rect(cx - 2, top + 8, 5, 1, METAL[2])
	c.fill_rect(cx - 1, top + 9, 3, 1, METAL[1])

## Window with warm interior light.
static func window(c, x: int, y: int, w: int, h: int, lit: bool = true, frame_r = null) -> void:
	var frame: Array[Color] = WOOD if frame_r == null else frame_r
	c.fill_rect(x - 1, y - 1, w + 2, h + 2, frame[1])
	for py in range(y, y + h):
		for pxx in range(x, x + w):
			var t := float(py - y) / maxf(1.0, h - 1)
			var cc: Color
			if lit:
				cc = FIRE[5] if t < 0.35 else (FIRE[4] if t < 0.75 else FIRE[3])
			else:
				cc = GLASS[2] if t < 0.4 else GLASS[1]
			c.px(pxx, py, cc)
	# cross mullion
	c.fill_rect(x + w / 2, y, 1, h, frame[2])
	c.fill_rect(x, y + h / 2, w, 1, frame[2])
	# sill
	c.fill_rect(x - 2, y + h + 1, w + 4, 1, frame[3])
	c.px(x, y, ci(Color.WHITE, 0.6) if lit else GLASS[4])

## Shingle roof inside a polygon.
static func shingle_roof(c, poly: PackedVector2Array, r: Array[Color], sh: int = 3, sw: int = 5, seed: int = 9) -> void:
	var m = PX.Canvas.new(c.w, c.h)
	m.polygon(poly, Color.WHITE)
	var miny := 99999
	for p in poly:
		miny = mini(miny, int(p.y))
	var HH: int = c.h
	var WW: int = c.w
	for yy in HH:
		for xx in WW:
			if m.get_px(xx, yy).a < 0.5:
				continue
			var row := (yy - miny) / sh
			var iny := (yy - miny) % sh
			var off := (row % 2) * (sw / 2)
			var col := (xx + off) / sw
			var inx := (xx + off) % sw
			var v := rnd(col, row, seed)
			var b := 3 if v > 0.5 else 2
			if v > 0.9:
				b = 4
			var cc: Color = r[b]
			if iny == sh - 1:
				cc = r[0]
			elif iny == 0:
				cc = r[mini(b + 1, r.size() - 1)]
			elif inx == 0:
				cc = r[1]
			c.px(xx, yy, cc)

## Fill everything inside polygon via callable(x, y) -> Color (alpha 0 = skip).
static func fill_poly_fn(c, poly: PackedVector2Array, fn: Callable) -> void:
	var m = PX.Canvas.new(c.w, c.h)
	m.polygon(poly, Color.WHITE)
	var HH: int = c.h
	var WW: int = c.w
	for yy in HH:
		for xx in WW:
			if m.get_px(xx, yy).a >= 0.5:
				var cc: Color = fn.call(xx, yy)
				if cc.a > 0.0:
					c.px(xx, yy, cc)

## Erase polygon (set transparent).
static func erase_poly(c, poly: PackedVector2Array) -> void:
	c.polygon(poly, Color(0, 0, 0, 0))

## Draw a crystal (pointed hexagonal prism) pointing at angle (radians, 0 = up).
static func crystal(c, bx: float, by: float, length: float, width: float, ang: float, r: Array[Color]) -> void:
	var dir := Vector2(sin(ang), -cos(ang))
	var nrm := Vector2(dir.y, -dir.x)
	var tip := Vector2(bx, by) + dir * length
	var shoulder := Vector2(bx, by) + dir * (length * 0.72)
	var hw := width * 0.5
	var left_face := PackedVector2Array([Vector2(bx, by) - nrm * hw, shoulder - nrm * hw, tip, Vector2(bx, by)])
	var right_face := PackedVector2Array([Vector2(bx, by), tip, shoulder + nrm * hw, Vector2(bx, by) + nrm * hw])
	# faces: left lit, right shadow
	var lit_left := nrm.x < 0.0
	c.polygon(left_face, r[4] if lit_left else r[2])
	c.polygon(right_face, r[2] if lit_left else r[4])
	# centre ridge highlight
	c.line(int(bx), int(by), int(tip.x), int(tip.y), r[5])
	# edge dark
	var e1 := Vector2(bx, by) - nrm * hw
	var e2 := Vector2(bx, by) + nrm * hw
	c.line(int(e1.x), int(e1.y), int((shoulder - nrm * hw).x), int((shoulder - nrm * hw).y), r[3] if lit_left else r[1])
	c.line(int(e2.x), int(e2.y), int((shoulder + nrm * hw).x), int((shoulder + nrm * hw).y), r[1] if lit_left else r[3])
	c.px(int(tip.x), int(tip.y), r[6] if r.size() > 6 else r[5])

## 4-point sparkle.
static func sparkle(c, x: int, y: int, col: Color, big: bool = false) -> void:
	c.px(x, y, Color.WHITE)
	c.px(x - 1, y, col); c.px(x + 1, y, col); c.px(x, y - 1, col); c.px(x, y + 1, col)
	if big:
		c.px(x - 2, y, ci(col, 0.6)); c.px(x + 2, y, ci(col, 0.6)); c.px(x, y - 2, ci(col, 0.6)); c.px(x, y + 2, ci(col, 0.6))

## Riveted metal plate.
static func plate(c, x: int, y: int, w: int, h: int, r_in = null, base: int = 3, rivets: bool = true) -> void:
	var r: Array[Color] = METAL if r_in == null else r_in
	bevel_rect(c, x, y, w, h, r, base)
	if rivets and w >= 6 and h >= 6:
		for p in [Vector2i(x + 2, y + 2), Vector2i(x + w - 3, y + 2), Vector2i(x + 2, y + h - 3), Vector2i(x + w - 3, y + h - 3)]:
			c.px(p.x, p.y, r[mini(base + 3, r.size() - 1)])
			c.px(p.x + 1, p.y + 1, r[maxi(base - 2, 0)])

## Gear / wheel with teeth, rotation phase in radians.
static func gear(c, cx: float, cy: float, rad: float, teeth: int, phase: float, r: Array[Color], hub: bool = true) -> void:
	for yy in range(int(cy - rad - 2), int(cy + rad + 3)):
		for xx in range(int(cx - rad - 2), int(cx + rad + 3)):
			var v := Vector2(xx + 0.5 - cx, yy + 0.5 - cy)
			var d := v.length()
			var a := atan2(v.y, v.x) - phase
			var tooth := fposmod(a * teeth / TAU, 1.0) < 0.5
			var rr := rad + (1.5 if tooth else 0.0)
			if d <= rr:
				var cc: Color = r[3]
				if d > rad - 1.0:
					cc = r[2]
				if v.y < -rad * 0.3 and d > rad * 0.5:
					cc = r[4]
				if d < rad * 0.45 and hub:
					cc = r[1]
				if d < rad * 0.2 and hub:
					cc = r[4]
				c.px(xx, yy, cc)

## Spoked wheel (for carts).
static func wheel(c, cx: float, cy: float, rad: float, phase: float, r_in = null) -> void:
	var r: Array[Color] = METAL if r_in == null else r_in
	c.circle(cx, cy, rad, r[1])
	c.circle(cx, cy, rad - 1.0, r[3])
	c.circle(cx, cy, rad - 2.0, r[1])
	for i in 4:
		var a := phase + i * PI / 4.0
		var dx := cos(a) * (rad - 2.0)
		var dy := sin(a) * (rad - 2.0)
		c.line(int(round(cx - dx)), int(round(cy - dy)), int(round(cx + dx)), int(round(cy + dy)), r[4])
	c.px(int(cx), int(cy), r[5])
	c.px(int(cx - rad * 0.5), int(cy - rad * 0.7), r[5])

# ---------------------------------------------------------------- fonts
const F35 := {
	"A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"], "I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"], "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"], "N": ["110", "101", "101", "101", "101"], "O": ["111", "101", "101", "101", "111"],
	"P": ["110", "101", "110", "100", "100"], "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"], "U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"], "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"], "!": ["010", "010", "010", "000", "010"],
	" ": ["000", "000", "000", "000", "000"], "?": ["110", "001", "010", "000", "010"], ".": ["000", "000", "000", "000", "010"],
}

const F57 := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"], "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"], "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"], "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"], "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"], "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"], "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"], "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

static func text_width(t: String, font: Dictionary, gw: int, scale: int = 1, spacing: int = 1) -> int:
	return t.length() * (gw + spacing) * scale - spacing * scale

## Draw text with optional 1px drop shadow.
static func text(c, t: String, x: int, y: int, col: Color, font: Dictionary = F35, scale: int = 1, shadow: Color = Color(0, 0, 0, 0), spacing: int = 1) -> void:
	var cx := x
	for ch in t.to_upper():
		var g: Array = font.get(ch, font[" "])
		var gw: int = (g[0] as String).length()
		for gy in g.size():
			var row: String = g[gy]
			for gx in row.length():
				if row[gx] == "1":
					if shadow.a > 0.0:
						c.fill_rect(cx + gx * scale + scale, y + gy * scale + scale, scale, scale, shadow)
					c.fill_rect(cx + gx * scale, y + gy * scale, scale, scale, col)
		cx += (gw + spacing) * scale

## Preview: scale and composite on a background, save to the scratchpad.
static func preview(img: Image, name: String, scale: int = 4, bg: Color = Color.html("2a3050")) -> void:
	var dir := "C:/Users/Jeremy/AppData/Local/Temp/claude/8bd127b22df0a1ed/aa2076d7-1a4a-41ce-aca4-0aa005bd01b8/scratchpad/previews"
	DirAccess.make_dir_recursive_absolute(dir)
	var b := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	b.fill(bg)
	b.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	b.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	b.save_png(dir.path_join(name + ".png"))
