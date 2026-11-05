extends Control
## Draws the prerequisite paths of the skill tree in canvas space (behind the hex nodes).
## Locked paths are dim slate, paths leading to a reachable node are dashed in the branch colour,
## unlocked paths glow with energy dots travelling toward the next node, and a purchase sends a
## bright energy burst along every incoming path.

const OUTLINE := Color(0.03, 0.04, 0.09, 0.95)
const LOCKED := Color(0.2, 0.23, 0.33)

## Each edge: {"from": id, "to": id, "a": Vector2, "b": Vector2, "color": Color, "glow": Color, "seed": float}
var edges: Array = []
var _bursts: Array = [] # {"edge": int, "t": float}
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_edges(list: Array) -> void:
	edges = list
	queue_redraw()

func burst_into(skill_id: String) -> void:
	for i in edges.size():
		if edges[i].to == skill_id:
			_bursts.append({"edge": i, "t": 0.0})

func _process(delta: float) -> void:
	_time += delta
	for b in _bursts:
		b.t += delta * 2.2
	_bursts = _bursts.filter(func(b): return b.t < 1.35)
	queue_redraw()

func _draw() -> void:
	for i in edges.size():
		var e: Dictionary = edges[i]
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var from_rank := SkillManager.rank(e.from)
		var to_rank := SkillManager.rank(e.to)
		var to_state := SkillManager.state(e.to)
		var hidden := to_state == SkillManager.State.HIDDEN
		draw_line(a, b, OUTLINE, 7.0)
		if hidden:
			draw_line(a, b, Color(0.11, 0.12, 0.19), 3.0)
			continue
		if to_rank > 0 and from_rank > 0:
			var c: Color = e.color
			var g: Color = e.glow
			draw_line(a, b, Color(g.r, g.g, g.b, 0.22), 9.0)
			draw_line(a, b, c, 3.0)
			draw_line(a, b, c.lerp(Color.WHITE, 0.45), 1.0)
			_draw_energy(a, b, g, float(e.seed))
		elif from_rank > 0:
			# reachable next step: dashed branch-coloured path
			draw_line(a, b, Color(0.12, 0.13, 0.2), 3.0)
			_draw_dashed(a, b, (e.color as Color).darkened(0.15), 3.0, 5.0, 4.0, _time * 10.0)
		else:
			draw_line(a, b, LOCKED, 3.0)
	for bu in _bursts:
		var e2: Dictionary = edges[bu.edge]
		_draw_burst(e2.a, e2.b, e2.glow, bu.t)

func _draw_energy(a: Vector2, b: Vector2, col: Color, seed: float) -> void:
	var len := a.distance_to(b)
	if len < 1.0:
		return
	for k in 2:
		var t := fposmod(_time * 0.55 + seed + k * 0.5, 1.0)
		var p := a.lerp(b, t).round()
		var fade := sin(t * PI)
		var head := Color(1, 1, 1, 0.9 * fade)
		var tail := Color(col.r, col.g, col.b, 0.7 * fade)
		var dir := (b - a) / len
		draw_rect(Rect2(p - dir * 4.0 - Vector2(1, 1), Vector2(2, 2)), tail)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), tail)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), head)

func _draw_dashed(a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float, offset: float) -> void:
	var len := a.distance_to(b)
	if len < 1.0:
		return
	var dir := (b - a) / len
	var d := fposmod(offset, dash + gap) - (dash + gap)
	while d < len:
		var s := maxf(d, 0.0)
		var e := minf(d + dash, len)
		if e > s:
			draw_line(a + dir * s, a + dir * e, col, width)
		d += dash + gap

func _draw_burst(a: Vector2, b: Vector2, col: Color, t: float) -> void:
	var tt := clampf(t, 0.0, 1.0)
	var head := a.lerp(b, tt)
	var tail := a.lerp(b, clampf(tt - 0.45, 0.0, 1.0))
	var fade := 1.0 - clampf((t - 1.0) / 0.35, 0.0, 1.0)
	draw_line(tail, head, Color(col.r, col.g, col.b, 0.45 * fade), 11.0)
	draw_line(tail, head, Color(1, 0.97, 0.8, 0.95 * fade), 4.0)
	draw_rect(Rect2(head.round() - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, fade))
