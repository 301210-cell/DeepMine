# DeepMine — Architecture & Asset Contract

Engine: **Godot 4.7.2** (APIs kept 4.4+ compatible). Language: GDScript. Renderer: `gl_compatibility`.
Logical resolution **640×360**, stretch `canvas_items`, aspect `expand`, nearest filtering, 2D pixel snap on.
Default window 1280×720 (2×). 1 tile = **16 px** = **2 meters** of depth.

This file is the contract between the code and the generated assets. Asset generators live in
`tools/assetgen/` (a tiny standalone Godot project, ignored by the game via `tools/.gdignore`) and write
PNG/WAV/FNT files into `assets/`. Re-generate with:

```
Godot_console.exe --headless --path tools/assetgen --script res://gen_<name>.gd
```

---------------------------------------------------------------------------------------------------
## 1. World model

* World grid: **W = 192** columns × **H = 1608** rows. Row 0 = surface ground row. Sky is rows < 0
  (not stored). Depth in meters = `row * 2`.
* Data: `PackedByteArray blocks` (W×H, block id per cell), `PackedByteArray decor`, `PackedByteArray seen`
  (map fog). Generated once per save from a seed in a worker thread (loading screen shows progress),
  saved compressed in the save file.
* Chunks of 32×32 are streamed into TileMapLayers around the camera.

### Biomes (depth meters → rows)
| # | key | name | meters | rows | base / hard material |
|---|-----|------|--------|------|------------------------|
| 0 | `stone` | Stone Caverns | 0–300 | 0–149 | stone / hard_stone |
| 1 | `iron` | Iron Depths | 300–700 | 150–349 | dark_stone / basalt |
| 2 | `crystal` | Crystal Caves | 700–1200 | 350–599 | crystal_rock / gem_rock |
| 3 | `frozen` | Frozen Depths | 1200–1800 | 600–899 | frost_rock / ice (+snow_pack) |
| 4 | `magma` | Magma Caverns | 1800–2500 | 900–1249 | volcanic_rock / scorched_rock (+magma_crust) |
| 5 | `ancient` | Ancient Core | 2500–3200 | 1250–1599 | ancient_brick / ruin_stone (+ancient_metal) |

Biome boundaries are sealed by a 3-row **seal band** that needs a better pickaxe tier (seal_1..seal_5).

### Block ids (byte)
```
0 AIR
Terrain materials (rendered from terrain.png, material index in brackets):
1 DIRT[0] 2 GRASS[1] 3 STONE[2] 4 HARD_STONE[3] 5 DARK_STONE[4] 6 BASALT[5] 7 CRYSTAL_ROCK[6]
8 GEM_ROCK[7] 9 FROST_ROCK[8] 10 ICE[9] 11 SNOW_PACK[10] 12 VOLCANIC_ROCK[11] 13 SCORCHED_ROCK[12]
14 MAGMA_CRUST[13] 15 ANCIENT_BRICK[14] 16 RUIN_STONE[15] 17 ANCIENT_METAL[16] 18 BEDROCK[17]
19 SHAFT_WALL[18] 20 SEAL_1[19] 21 SEAL_2[20] 22 SEAL_3[21] 23 SEAL_4[22] 24 SEAL_5[23]
25 WOOD_PLANK[24] 26 SEALED_ANCIENT[25]
Deposits (rendered as the biome base material + ore overlay row from ores.png):
40 COAL[0] 41 COPPER[1] 42 QUARTZ[2] 43 GEODE_SMALL[3] 44 IRON[4] 45 SILVER[5] 46 GEODE_IRON[6]
47 GOLD[7] 48 AMETHYST[8] 49 SAPPHIRE[9] 50 EMERALD[10] 51 RUBY[11] 52 CRYSTAL_SHARD[12]
53 TOPAZ[13] 54 GEODE_RARE[14] 55 FROST_CRYSTAL[15] 56 FROZEN_IRON[16] 57 BLUE_SAPPHIRE[17]
58 GEODE_ICE[18] 59 OPAL[19] 60 OBSIDIAN[20] 61 VOLCANIC_IRON[21] 62 MAGMA_CRYSTAL[22]
63 EMBERSTONE[23] 64 DIAMOND[24] 65 ANCIENT_SHARD[25] 66 RELIC_FRAGMENT[26] 67 STAR_CRYSTAL[27]
68 ANCIENT_GOLD[28] 69 PROTOTYPE_MINERAL[29] 70 GEODE_LEGENDARY[30] 71 METEORITE[31] 72 FOSSIL[32]
73 ARTIFACT[33] 74 GEODE_MAGMA[34] 75 CRACKED_WALL[35]  (hidden-passage hint)
Non-solid specials (special.png):
90 LADDER 91 RAIL 92 LAVA 93 WATER 94 TORCH
```

---------------------------------------------------------------------------------------------------
## 2. Asset contract (all PNG RGBA, true pixel art, transparent backgrounds unless noted)

### Palette guidance (match the reference boards)
Dark navy `#0b1026 #141a3a #1e2650 #2a3466`, deep purple `#2a1a4a #4a2a7a #6b3fa8`, steel gray
`#3c4458 #5a6378 #8a93a8 #c3cad8`, bright blue `#2f7bff #4aa3ff`, cyan `#5ff2ff #b8fbff`, gold `#ffc93c #ffb000
#fff1a8`, orange `#ff8a2a #ff5a1f`, warm wood `#5a3418 #8a5528 #c08040`. Outlines are dark (never pure black,
use `#0b0d18`/darkest shade of the hue). Light from top-left. Use 3–5 shade ramps, hue-shifted (shadows
toward blue/purple, highlights toward yellow). Dithering only sparingly.

### Tilesets — `assets/tilesets/`
| file | size | layout |
|------|------|--------|
| `terrain.png` | 256×832 | 16×16 cells. **Column = edge mask 0–15** (bit0 top exposed, bit1 right exposed, bit2 bottom exposed, bit3 left exposed; exposed = neighbour is not solid). **Row = material*2 + variant** (2 variants each), 26 materials in the order of the bracket indices above. Exposed edges get a 1px dark outline; exposed top gets a lighter lip/highlight (GRASS gets grass blades on an exposed top, plain dirt otherwise). Tiles must tile seamlessly with each other on non-exposed sides. |
| `ores.png` | 64×576 | 16×16 overlays, transparent. **Row = ore index** (bracket numbers in deposits list, 0–35), **column = 4 variants**. Ore chunks/gems drawn inside a 1–2px margin, with highlights and dark outline, so the base rock shows around them. Row 35 = subtle hairline cracks (hidden passage). |
| `backwalls.png` | 64×128 | 16×16, row = wall type, 4 variant columns: 0 stone, 1 iron, 2 crystal, 3 frozen, 4 magma, 5 ancient, 6 dirt (near surface), 7 wooden mine planks. Darker/desaturated (≈45% brightness) so foreground pops. Seamless. |
| `special.png` | 64×112 | 16×16, row-based, columns = animation frames: row0 ladder (col0 ladder, col1 ladder top), row1 rail (col0 straight, col1 left bumper, col2 right bumper), row2 lava surface ×4 frames, row3 lava body ×4, row4 water surface ×4, row5 water body ×4, row6 wall torch ×4 frames. |
| `decor.png` | 256×160 | Grid of **32×32 cells**, 8 columns. Index i → cell (i%8, i/8). See decor table below. Floor items sit on the cell's bottom edge, ceiling items hang from the top edge, centred horizontally. |
| `crack.png` | 80×16 | 5 frames of 16×16 crack overlays (light → heavy), dark lines with a few light chips. |

Decor indices (`F`=floor anchor bottom, `C`=ceiling anchor top, `*`=glows):
```
0 F small rocks        1 F pebbles           2 F red mushrooms     3 F* blue glow mushrooms
4 F* small blue crystal 5 F* blue crystal cluster 6 F* purple crystal cluster 7 F* green crystal
8 F stone stalagmite   9 F ice stalagmite    10 F* ice crystal     11 F bones
12 F skull             13 F lava rock spire  14 F* ember vent      15 F broken ancient pillar
16 F* glowing glyph stone 17 F* star crystal formation 18 F broken minecart 19 F wooden crate
20 F barrel            21 F pickaxe in ground 22 F fern/cave plant 23 F grass tuft
24 F rusty gears/pipe  25 F sign post        26 C small stalactite 27 C large stalactite
28 C icicles           29 C* hanging crystal 30 C* hanging lantern on chain 31 C roots/vines
32 C chain             33 C* magma drip      34 F wooden support beam (post+crossbeam, full 32×32)
35 F* lantern on post
```

### Backgrounds — `assets/backgrounds/` (all horizontally tileable)
| file | size | notes |
|------|------|-------|
| `surface_mountains_far.png` | 640×220 | snow-capped blue/indigo mountains, transparent sky |
| `surface_mountains_near.png` | 640×170 | darker hills + pine silhouettes, transparent top |
| `surface_clouds.png` | 640×120 | soft pixel clouds, white/grey, transparent |
| `cave_<key>_far.png` (6) | 640×360 | opaque, very dark cave depth for that biome (tiles in both axes) |
| `cave_<key>_near.png` (6) | 640×360 | transparent rock pillars / formations / crystals silhouettes (tiles horizontally) |
| `menu_far.png` | 640×360 | opaque: night sky, snowy peak, cave walls (main menu, like loading-screen reference) |
| `menu_main.png` | 640×360 | transparent: big stone+timber mine entrance with lanterns, blue crystals left, purple right, track curving to bottom-right |
| `menu_cart.png` | 64×48 ×2 frames (128×48) | mine cart full of purple gems |
| `logo.png` | 400×128 | "DEEPMINE" chunky pixel logo: DEEP in icy blue gradient, MINE in gold→orange gradient, thick dark outline, pickaxe accent; subtitle "UNDERGROUND MINING SIMULATOR" in gold underneath |

### Sprites — `assets/sprites/`
| file | size | layout |
|------|------|--------|
| `player/player.png` | 256×480 | 32×48 frames, feet at y=47, body centred at x=16, ~18px wide. Rows: 0 idle×4, 1 walk×8, 2 run×8, 3 jump×2, 4 fall×2, 5 land×2, 6 mine_body×4 (front arm hidden, leaning; tool drawn by code), 7 collect×4, 8 climb×4 (back view on ladder), 9 interact×3, all facing RIGHT. Helmet with headlamp, orange/brown work jacket, blue overalls, gloves, boots, small backpack. |
| `player/tools.png` | 256×32 | 32×32 cells: 0 basic(wood), 1 copper, 2 iron, 3 steel, 4 crystal, 5 diamond drill, 6 plasma tool, 7 portable drill. Each drawn with a **gloved hand gripping the handle at pixel (7,25)** (the rotation pivot), tool pointing up-right at 45°, head in the top-right. |
| `player/mara.png` | 128×144 | 32×48 frames: row0 idle×4, row1 talk×4, row2 wave×4. Female miner guide: yellow helmet+lamp, auburn braid, teal jacket, facing LEFT. |
| `player/mara_portrait.png` | 192×64 | 3 portraits 64×64: happy, talking, thumbs-up (like the tutorial reference). |
| `items/items.png` | 256×N | 16×16 icons, 16 per row, **index = `icon` field in `data/resources/resources.json`** |
| `items/equipment.png` | 256×48 | 16×16 icons, index = `icon` in `data/tools/equipment.json` |
| `items/skill_icons.png` | 256×48 | 16×16 icons, index = `icon` in `data/skills/skills.json` |
| `items/event_icons.png` | 256×32 | 32×32 icons, 8: crystal surge, geode fever, ore rush, meteor shower, abandoned cart, double extraction, ancient discovery, rare expedition |
| `world/shop.png` | 96×80 | general store, red/white striped awning, "SHOP" sign |
| `world/skill_board.png` | 128×64 | 2 frames 64×64, research terminal with glowing hex diagram (pulse) |
| `world/storage.png` | 80×64 | storage shed with crates |
| `world/mining_board.png` | 48×48 | quest notice board |
| `world/museum.png` | 80×72 | Mineral Collection hall with gem display |
| `world/mara_tent.png` | 64×48 | Mara's tent |
| `world/mine_entrance.png` | 112×96 | stone & timber mine portal with 2 lanterns; dark opening in the centre-bottom |
| `world/elevator.png` | 240×64 | 5 frames 48×64: closed, opening×3, open (cage with doors) |
| `world/elevator_top.png` | 48×32 | winch housing on top of the surface elevator |
| `world/machine_pad.png` | 64×24 | concrete pad with "SOON" sign |
| `world/minecart.png` | 96×24 | 3 frames 32×24: idle, roll1, roll2 |
| `world/minecart_loot.png` | 32×24 | abandoned cart with glowing gems |
| `world/chest.png` | 64×16 | 4 frames 16×16: closed, opening, open, gold chest (closed) |
| `world/props.png` | 256×128 | 32×32 grid: 0 campfire f1,1 f2,2 f3,3 f4, 4 lamp post, 5 fence, 6 pine tree (top) , 7 pine tree (bottom), 8 bush, 9 rocks, 10 crate stack, 11 flag f1, 12 flag f2, 13 bench, 14 barrel stack, 15 sign "MINE", 16–23 spare |
| `machines/<id>.png` | 320×64 | 5 frames 64×64: idle, working×4. ids: smelter, crusher, auto_drill, advanced_smelter, gem_polisher, crystal_extractor, deep_core_drill, ore_sorter, mining_robot |
| `effects/particles.png` | 64×64 | 8×8 cells, rows: 0 dust×4 + glow dot×4, 1 debris×4 (white, tinted in code) + spark×4, 2 sparkle×4 + smoke×4, 3 star×4 + coin×4 |
| `effects/impact.png` | 64×16 | 4 frames 16×16 hit flash |
| `effects/meteor.png` | 32×16 | 2 frames 16×16 |
| `effects/geode_open.png` | 288×48 | 6 frames 48×48: geode shakes, cracks, splits open revealing glow |

### UI — `assets/ui/` (9-slice margins in brackets: left,top,right,bottom)
| file | size | notes |
|------|------|-------|
| `panel.png` | 48×48 [12] | main window: navy fill, steel-blue bevel border, corner rivets (reference style) |
| `panel_dark.png` | 24×24 [6] | inner inset panel |
| `panel_purple.png` | 48×48 [12] | event/rare panel, purple border, gold corner accents |
| `panel_title.png` | 48×20 [10,6,10,6] | title ribbon |
| `hud_box.png` | 24×24 [8] | HUD chip (coins, level, clock) |
| `button_blue_{normal,hover,pressed,disabled}.png` | 48×24 [8,8,8,10] | like the "Next >"/"Travel" buttons |
| `button_green_{normal,hover,pressed,disabled}.png` | 48×24 [8,8,8,10] | Buy/Upgrade buttons |
| `button_red_{normal,hover,pressed}.png` | 48×24 [8,8,8,10] | danger |
| `button_gold_{normal,hover,pressed,disabled}.png` | 48×24 [8,8,8,10] | skill unlock |
| `button_dark_{normal,hover,pressed}.png` | 48×24 [8,8,8,10] | secondary / inactive tab |
| `tab_active.png` | 48×20 [8,8,8,4] | active tab (blue) |
| `close_{normal,hover,pressed}.png` | 16×16 | red square X button |
| `slot.png`, `slot_hover.png`, `slot_selected.png` | 24×24 [6] | inventory slot |
| `slot_rarity.png` | 24×24 [6] | white frame to be tinted by rarity |
| `bar_bg.png` | 24×10 [5,4,5,4] | progress bar track |
| `bar_fill_{blue,red,green,gold,orange,purple}.png` | 24×10 [5,4,5,4] | progress fills |
| `tooltip.png` | 24×24 [6] | tooltip |
| `hotbar_slot.png`, `hotbar_selected.png` | 26×26 [7] | hotbar |
| `cursor.png` | 16×16 | pointer arrow (gold-outlined) |
| `crosshair.png` | 16×16 | mining target reticle |
| `arrow_bounce.png` | 64×16 | 4 frames 16×16 gold down-arrow |
| `keycap.png` | 16×16 | keyboard key background for "E" prompts |
| `ui_icons.png` | 256×64 | 16×16 icons, index list below |
| `hex_frame.png` | 52×60 | pointy-top hex frame (light grey/white, to be tinted), bevelled, 3px thick |
| `hex_fill.png` | 52×60 | inner hex fill (white with subtle top highlight & bottom shade, tinted in code) |
| `hex_glow.png` | 84×92 | soft white glow around a hex (additive) |
| `hex_select.png` | 60×68 | bright selection ring |
| `hex_core.png` | 72×82 | central start node (gold & cyan, ornate) |
| `hex_lock.png` | 16×16 | padlock |
| `hex_max.png` | 24×12 | gold "MAX" badge |
| `skilltree_bg.png` | 128×128 | tileable deep-navy background with faint hex grid and specks |

`ui_icons.png` indices: 0 coin, 1 skill gem (purple), 2 star/level, 3 xp, 4 heart, 5 clock, 6 sun, 7 moon,
8 backpack, 9 gear, 10 map, 11 journal, 12 skill hex, 13 shop cart, 14 lock, 15 check, 16 close, 17 arrow right,
18 arrow left, 19 arrow up, 20 arrow down, 21 plus, 22 minus, 23 fit/expand, 24 target/center, 25 reset,
26 trophy, 27 quest "!", 28 info, 29 hammer, 30 flame, 31 cog, 32 depth/mountain, 33 elevator, 34 stopwatch,
35 coin bag, 36 sort, 37 filter, 38 trash, 39 pickaxe, 40 chest, 41 sparkle, 42 warning, 43 speaker, 44 music
note, 45 keyboard, 46 mouse, 47 storage box, 48 lantern, 49 compass, 50 fossil, 51 geode, 52 crown, 53 save disk.

### Fonts — `assets/fonts/` (AngelCode BMFont text format + PNG page)
* `pixel.fnt` + `pixel_0.png`: proportional pixel font, cap height 7, line height 10, base 8, ASCII 32–126
  plus `• × → ← ↑ ↓ ✓ ★ …` if possible. Used at size 10 (×1) and 20 (×2).
* `pixel_big.fnt` + `pixel_big_0.png`: chunky bold display font, cap height 12, line height 16, ASCII 32–126.

### Audio — `assets/audio/` (WAV, 16-bit mono 22050 Hz unless noted)
`sfx/`: swing, hit_rock_1..3, hit_ore, hit_crystal, hit_ice, hit_metal, break_rock_1..2, break_crystal,
pickup, pickup_rare, coin, sell, buy, geode_crack, geode_reveal, elevator_move, elevator_ding, minecart,
smelter, crusher, machine_done, ui_click, ui_hover, ui_open, ui_close, ui_error, skill_unlock, skill_max,
level_up, event_start, event_end, rare_discovery, legendary, step_1, step_2, jump, land, ladder, hurt,
fuse, explosion, chest_open, quest_complete, notify, splash, lava_bubble, place
`music/` (loopable, 44100 Hz stereo allowed): menu, camp, stone, iron, crystal, frozen, magma, ancient
`ambience/` (loopable): surface, cave, crystal, frozen, magma, ancient

---------------------------------------------------------------------------------------------------
## 3. Code layout

```
scripts/autoload/  Events.gd (signal bus), GameState.gd, ResourceDatabase.gd, SkillManager.gd,
                   SaveManager.gd, AudioManager.gd
scripts/world/     world_gen.gd, world_data.gd, world_renderer.gd (chunk streaming), camp.gd, day_night.gd
scripts/player/    player.gd, mining_controller.gd
scripts/mining/    pickup.gd, effects.gd
scripts/inventory/ inventory.gd (pure logic, used by GameState)
scripts/skills/    skill_tree_panel.gd, skill_node.gd, skill_connections.gd
scripts/progression/ quest_manager.gd, event_manager.gd, tutorial.gd, achievements.gd
scripts/machines/  machine.gd
scripts/ui/        hud.gd, ui_root.gd, panels...
data/*.json        all definitions (items, blocks, tools, skills, quests, events, biomes, machines)
```

**Rules**
* All definitions come from `data/**/*.json` through `ResourceDatabase` (autoload name `DB`).
* All persistent state lives in `GameState` (`GS`). Systems mutate it only through its methods,
  which emit `Events` signals. UI listens to `Events`.
* Every gameplay number that skills/equipment/events can change is read through
  `GS.stat(&"name")` — the single central stat calculator (base + equipment + skills + events).
* UI uses only one major panel at a time (`UIRoot.open_panel(name)`).

---------------------------------------------------------------------------------------------------
## 4. UI integration contract

Autoload names: `Events`, `ResourceDatabase`, `GameState`, `SkillManager`, `AudioManager`, `SaveManager`.
Helper scripts are used with `preload` (no `class_name` dependencies):
`res://scripts/machines/machine_logic.gd` (MachineLogic), `res://scripts/progression/loot.gd` (Loot).
Tests/tools run with `--script` cannot `preload` scripts that reference autoloads; `load()` them at runtime.

* **UIRoot** `scenes/ui/UIRoot.tscn` (CanvasLayer, layer 10, script `scripts/ui/ui_root.gd`) is instanced by the Game
  scene. Children: `HUD`, `PanelHost` (one panel at a time), `Overlay` (toasts, pickup feed, dialogue, event banner,
  level-up, geode popup, confirm dialog, interaction prompt, fade).
  API: `open_panel(name: String, data = null)`, `close_panel()`, `toggle_panel(name)`, `is_open() -> bool`,
  `current_panel() -> String`, `show_prompt(text: String)` / `hide_prompt()`, `fade_out(t) / fade_in(t)` (awaitable),
  `show_confirm(title, text, on_yes: Callable)`, `show_dialog(lines: Array, title := "Mara")` (awaitable, emits
  `Events.dialog_finished`), `set_tutorial_objective(title, text, progress: String)`.
  It listens to `Events.open_panel_requested(name, data)`. While a panel is open it sets `GameState.ui_blocking = true`.
  Only `pause` and `settings` pause the SceneTree (`process_mode` of UIRoot = ALWAYS).
  Hotkeys handled by UIRoot: `inventory`(I/Tab), `skill_tree`(K, only after tutorial step t_board or tutorial done),
  `map`(M), `journal`(J), `pause`(Esc closes current panel first).
* **Panel scenes** `scenes/ui/panels/<Name>Panel.tscn`, root `Control` (full rect) with script exposing
  `func open(data) -> void` and `signal close_requested`. Names → scenes:
  `inventory` InventoryPanel, `storage` StoragePanel, `shop` ShopPanel, `skills` SkillTreePanel (scenes/ui/SkillTreePanel.tscn),
  `machine` MachinePanel (data = machine id), `elevator` ElevatorPanel (data = {"current": station_index}),
  `map` MapPanel, `journal` JournalPanel (data = tab name: "quests" | "collection" | "discoveries" | "achievements"),
  `pause` PauseMenu, `settings` SettingsPanel.
* **Theme**: `scripts/ui/ui_theme.gd` → `static func build() -> Theme` (StyleBoxTexture from assets/ui with the 9-slice
  margins in §2, fonts from assets/fonts with `fixed_size_scale_mode = integer`). Saved to `assets/ui/theme.tres` by
  `scripts/tools/build_theme.gd` and set as project `gui/theme/custom`. Type variations: `ButtonGreen`, `ButtonGold`,
  `ButtonRed`, `ButtonDark`, `TabActive`, `PanelDark`, `PanelPurple`, `HudBox`, `LabelTitle` (pixel_big), `LabelSmall`,
  `LabelGold`, `LabelDim`.
* **Game → UI data**: everything in `GameState` + signals in `Events`. Player HP: `GameState.hp / MAX_HP`.
  Depth: `GameState.current_depth`, biome `GameState.current_biome`. Day: `GameState.day_time` (0..1, 0.25=06:00),
  `GameState.day_count`. Active world event: `GameState.event_state` =
  `{"id": String ("" if none), "time_left": float, "progress": int, "count": int, "quest_text": String}`.
  Main quest for the HUD: `GameState.quest_state.get("hud", {"title": "", "text": "", "progress": ""})`.
  Map data: `GameState.world` (WorldData: `W`, `H`, `get_block(x,y)`, `seen` PackedByteArray W*H, `entities` Array of
  `{"type": "station"|"chest"|"cart"|"loot_cart"|"chamber", "x": int, "y": int, ...}`), player cell from
  `GameState.player_pos / 16`.
* **UI → game requests** (emit, the game handles them): `Events.elevator_travel_requested(i)`,
  `Events.drop_item_requested(id, n)`, `Events.use_item_requested(id)`, `Events.recall_requested`.
  Shop/inventory/storage/machines call GameState / MachineLogic / SkillManager methods directly.
* Selling, storage, geode opening and machines are only available when `GameState.at_surface` is true.
