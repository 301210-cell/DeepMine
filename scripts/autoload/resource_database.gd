extends Node
## Autoload "ResourceDatabase": loads every data definition from res://data/**/*.json
## and provides icons/textures. Definitions are plain Dictionaries (read-only by convention).

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS: Array[Color] = [Color("b8bcc8"), Color("5fdc6a"), Color("4aa3ff"), Color("b46bff"), Color("ffc93c")]
const CATEGORY_NAMES := {
	"rock": "Rock", "ore": "Ore", "gem": "Gemstone", "special": "Special", "geode": "Geode",
	"fossil": "Fossil", "artifact": "Artifact", "bar": "Bar", "processed": "Processed",
	"polished": "Polished Gem", "essence": "Essence", "consumable": "Item",
}
## Inventory filter groups -> categories
const FILTERS := {
	"All": [],
	"Ores": ["rock", "ore"],
	"Gems": ["gem", "polished"],
	"Special": ["special", "geode", "fossil", "artifact", "essence"],
	"Bars": ["bar", "processed"],
	"Items": ["consumable"],
}

# Block ids (mirrors ARCHITECTURE.md)
const AIR := 0
const DIRT := 1
const GRASS := 2
const STONE := 3
const BEDROCK := 18
const SHAFT_WALL := 19
const WOOD_PLANK := 25
const SEALED_ANCIENT := 26
const CRACKED_WALL := 75
const LADDER := 90
const RAIL := 91
const LAVA := 92
const WATER := 93
const TORCH := 94

const PATH_ITEMS := "res://assets/sprites/items/items.png"
const PATH_EQUIP := "res://assets/sprites/items/equipment.png"
const PATH_SKILLS := "res://assets/sprites/items/skill_icons.png"
const PATH_EVENTS := "res://assets/sprites/items/event_icons.png"
const PATH_UI_ICONS := "res://assets/ui/ui_icons.png"

var items: Dictionary = {}
var item_order: Array[String] = []
var collectibles: Array[String] = []
var blocks: Array = [] # index = block id, value = Dictionary or null
var biomes: Array = []
var stations: Array = []
var skills: Dictionary = {}
var skill_order: Array[String] = []
var branches: Dictionary = {}
var branch_order: Array[String] = []
var equipment: Dictionary = {} # id -> Dictionary (has "slot")
var equipment_by_slot: Dictionary = {} # slot -> Array[String]
var machines: Dictionary = {}
var machine_order: Array[String] = []
var machine_upgrade: Dictionary = {}
var loot: Dictionary = {}
var quests: Dictionary = {}
var events: Array = []
var event_interval: Array = [240, 420]
var achievements: Array = []

var _tex_cache: Dictionary = {}
var _atlas_cache: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	var d := _load_json("res://data/resources/resources.json")
	items.clear()
	item_order.clear()
	collectibles.clear()
	for it in d.get("items", []):
		items[it.id] = it
		item_order.append(it.id)
		if it.get("collectible", false):
			collectibles.append(it.id)

	blocks.resize(256)
	blocks.fill(null)
	for b in _load_json("res://data/blocks/blocks.json").get("blocks", []):
		blocks[int(b.id)] = b

	var bd := _load_json("res://data/biomes/biomes.json")
	biomes = bd.get("biomes", [])
	stations = bd.get("stations", [])

	var sd := _load_json("res://data/skills/skills.json")
	skills.clear()
	skill_order.clear()
	branches.clear()
	branch_order.clear()
	for br in sd.get("branches", []):
		branches[br.id] = br
		branch_order.append(br.id)
	for s in sd.get("skills", []):
		skills[s.id] = s
		skill_order.append(s.id)

	var ed := _load_json("res://data/tools/equipment.json")
	equipment.clear()
	equipment_by_slot.clear()
	for slot_key in ["pickaxes", "drills", "backpacks", "lanterns", "scanners", "boots", "cosmetics"]:
		var slot: String = slot_key.trim_suffix("s") if slot_key != "boots" else "boots"
		if slot_key == "pickaxes": slot = "pickaxe"
		elif slot_key == "drills": slot = "drill"
		elif slot_key == "backpacks": slot = "backpack"
		elif slot_key == "lanterns": slot = "lantern"
		elif slot_key == "scanners": slot = "scanner"
		elif slot_key == "cosmetics": slot = "cosmetic"
		var arr: Array[String] = []
		for e in ed.get(slot_key, []):
			e["slot"] = slot
			equipment[e.id] = e
			arr.append(e.id)
		equipment_by_slot[slot] = arr

	var md := _load_json("res://data/machines/machines.json")
	machines.clear()
	machine_order.clear()
	machine_upgrade = md.get("upgrade", {})
	for m in md.get("machines", []):
		machines[m.id] = m
		machine_order.append(m.id)

	loot = _load_json("res://data/resources/loot.json")
	quests = _load_json("res://data/quests/quests.json")
	var evd := _load_json("res://data/events/events.json")
	events = evd.get("events", [])
	event_interval = evd.get("interval", [240, 420])
	achievements = _load_json("res://data/quests/achievements.json").get("achievements", [])

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ResourceDatabase: missing data file " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ResourceDatabase: invalid JSON in " + path)
		return {}
	return parsed

# ---------------------------------------------------------------- items
func item(id: String) -> Dictionary:
	return items.get(id, {})

func has_item(id: String) -> bool:
	return items.has(id)

func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)

func item_value(id: String) -> int:
	return int(items.get(id, {}).get("value", 0))

func item_rarity(id: String) -> int:
	return int(items.get(id, {}).get("rarity", 0))

func item_category(id: String) -> String:
	return items.get(id, {}).get("category", "")

func item_matches(id: String, target: String) -> bool:
	## target may be an item id or "@category" (e.g. "@gem", "@geode", "@fossil").
	if target.begins_with("@"):
		var cat := target.substr(1)
		var c := item_category(id)
		if cat == "gem":
			return c == "gem"
		return c == cat
	return id == target

func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 4)]

func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, 4)]

func item_icon(id: String) -> Texture2D:
	var it := item(id)
	if it.is_empty():
		return _atlas(PATH_ITEMS, 0, 16, 16)
	return _atlas(PATH_ITEMS, int(it.icon), 16, 16)

# ---------------------------------------------------------------- blocks / biomes
func block(id: int) -> Dictionary:
	if id <= 0 or id >= blocks.size() or blocks[id] == null:
		return {}
	return blocks[id]

func is_solid(id: int) -> bool:
	if id == AIR:
		return false
	var b: Variant = blocks[id] if id < blocks.size() else null
	if b == null:
		return false
	return b.get("solid", true)

func is_deposit(id: int) -> bool:
	return id >= 40 and id < 90

func biome_index_for_row(row: int) -> int:
	if row < 0:
		return -1
	for b in biomes:
		if row <= int(b.rows[1]):
			return int(b.index)
	return biomes.size() - 1

func biome(i: int) -> Dictionary:
	if i < 0 or i >= biomes.size():
		return {}
	return biomes[i]

func biome_for_depth(m: float) -> int:
	return biome_index_for_row(int(m / 2.0))

# ---------------------------------------------------------------- skills
func skill(id: String) -> Dictionary:
	return skills.get(id, {})

func branch(id: String) -> Dictionary:
	return branches.get(id, {})

func skill_icon(id: String) -> Texture2D:
	var s := skill(id)
	return _atlas(PATH_SKILLS, int(s.get("icon", 0)), 16, 16)

# ---------------------------------------------------------------- equipment / machines
func equip(id: String) -> Dictionary:
	return equipment.get(id, {})

func equip_icon(id: String) -> Texture2D:
	var e := equip(id)
	return _atlas(PATH_EQUIP, int(e.get("icon", 0)), 16, 16)

func equip_icon_index(i: int) -> Texture2D:
	return _atlas(PATH_EQUIP, i, 16, 16)

func machine(id: String) -> Dictionary:
	return machines.get(id, {})

func machine_icon(id: String) -> Texture2D:
	return _atlas(PATH_EQUIP, int(machine(id).get("icon", 23)), 16, 16)

# ---------------------------------------------------------------- generic icons
func ui_icon(i: int) -> Texture2D:
	return _atlas(PATH_UI_ICONS, i, 16, 16)

func event_icon(i: int) -> Texture2D:
	return _atlas(PATH_EVENTS, i, 32, 32)

func tex(path: String) -> Texture2D:
	## Loads a texture, or returns a visible placeholder if the asset is missing.
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	if t == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.35, 0.3, 0.5, 1))
		for i in 16:
			img.set_pixel(i, 0, Color(0.1, 0.1, 0.2))
			img.set_pixel(i, 15, Color(0.1, 0.1, 0.2))
			img.set_pixel(0, i, Color(0.1, 0.1, 0.2))
			img.set_pixel(15, i, Color(0.1, 0.1, 0.2))
		t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

func _atlas(path: String, index: int, w: int, h: int) -> Texture2D:
	var key := "%s#%d" % [path, index]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var base := tex(path)
	var cols := maxi(1, int(base.get_width() / w))
	var at := AtlasTexture.new()
	at.atlas = base
	if base.get_width() < w:
		at.region = Rect2(0, 0, base.get_width(), base.get_height())
	else:
		at.region = Rect2((index % cols) * w, int(index / cols) * h, w, h)
	_atlas_cache[key] = at
	return at

# ---------------------------------------------------------------- formatting helpers
static func fmt_num(n: float) -> String:
	## 12450 -> "12,450"
	var neg := n < 0
	var s := str(int(absf(n)))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out

static func fmt_short(n: float) -> String:
	if n < 10000:
		return fmt_num(n)
	var units := ["", "K", "M", "B", "T"]
	var i := 0
	while n >= 1000.0 and i < units.size() - 1:
		n /= 1000.0
		i += 1
	return ("%.1f" % n).trim_suffix(".0") + units[i]

static func fmt_time(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	return "%02d:%02d" % [s / 60, s % 60]
