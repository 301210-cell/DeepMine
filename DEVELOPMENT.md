# DeepMine — Development Checklist

## Changelog
* **v1.2.0**
  * The mine entrance is carved into a rocky hillside at the east edge of the camp (terrain above ground level, minable and saved). You walk up to the portal instead of behind it.
  * Progression is about 40-50% faster: an easier XP curve, faster mining and walking, 1.5x resource values, gear and machines about 45% cheaper with lower level requirements, faster machines, lower quest and challenge targets with bigger rewards, and branches that unlock sooner.
  * The tutorial arrow disappears once its target has been mined or used.
  * A new hand-made pixel-art title and loading screen (plaque, crystal crest, swaying pickaxes, shining crystals, lit tunnel, gold loading bar), replacing the photo-based one.
  * The HUD is redesigned: coin, gem and level chips, a compact quest box, a clock with a depth line, 4 large buttons with a backpack badge. The level chip opens Skills and the quest box opens the Journal.
  * Event notices are compact and non-blocking above any open window. Windows open and close with animations, buying and selling get coin and sparkle effects, and text no longer overflows its boxes.
  * Gameplay effects: a pickaxe swing smear, a block-break flash, pickup trails and elevator dust.
* **v1.1.0**
  * The mine entrance has no pit any more: press E at the MINE portal for a short cutscene (walk into the tunnel, fade, appear in the timbered entrance hall, walk to the first blocks). An "Exit to Surface" doorway in the hall plays the reverse.
  * Invisible walls at the world edges stop the player from walking off the map.
  * The new title screen and loading screen use the concept-art picture, with animated crystal glow, lantern flicker and twinkling gem sparkles on the still mine cart.
  * Caves always show a rock back wall (no flat blue background holes), and water has a shimmering surface.
* **v1.0.0**: first release.

Status as of v1.2.0 (Godot 4.7.2). Automated checks: `tests/compile_all.gd` (all scripts and scenes compile), `tests/smoke_core.gd` (core logic), `tests/test_worldgen.gd` (generation statistics and save round-trip), `tests/Playtest.tscn` (39-check automated playthrough: tutorial loop including the mine-entrance cutscene, world-edge walls, panels, events and save/load: **39/39 passing**).

## Completed
| Phase | Area | Notes |
|---|---|---|
| 0 | Project foundation | 640×360 logical, `canvas_items` stretch, nearest filtering, pixel snap, Compatibility renderer, input map, Boot splash, loading screen with real threaded progress |
| 1 | Player and camp | CharacterBody2D with coyote time, jump buffer, variable jump, smooth step-up, ladders, water, ice, run; layered animation: frames plus spring squash/stretch, lean, turn squash, speed-matched cycles |
| 2 | Mining | ray aiming, eased swing synced to body frames, crack stages, tier gating with "Needs X Pickaxe", crits, momentum, damage overflow, debris/impact/sparks, hit-stop, screen shake |
| 3 | Inventory and resources | 75 items, rarities, stacks, capacity, sort/filter, drop/store/sell/use, storage with capacity, nothing is ever deleted (overflow goes to storage or the ground) |
| 4 | Surface camp | elevator, shop (pickaxes, equipment, backpacks, specials, machines, sell), smelter, crusher, storage, research board, mining board, museum, Mara; the camp grows as you level |
| 5 | Skill tree | 40 hex nodes in 4 branches plus the core, 5 node states, hover/selected info card, prerequisites (all-of and any-of), drag/zoom/fit/center/minimap, unlock path animation, branch reveal by level, 90% reset with confirmation; every effect feeds `GameState.stat()` |
| 6 | Underground | 6 procedurally generated biomes (192×1608 tiles, about 0.5 s on a worker thread), seal bands gating each biome, chunk streaming, pools of water and lava, ice floors, magma crust, decoration, glow halos, lights, parallax backgrounds |
| 7 | Quests and collection | 12-step Mara tutorial (skip/replay), 15 main quests, rotating challenges, map with fog of war and markers, journal, Mineral Collection with silhouettes and 25/50/75/100% rewards, 29 achievements, 7 special chambers |
| 8 | Equipment and machines | 7 pickaxes, 2 drills, 4 backpacks, 4 lanterns, 2 scanners, 4 boots, 9 machines (processor/drill/auto) with levels, queues, output and animation |
| 9 | Events and atmosphere | 8 timed events with banner, timer, gameplay effect, optional challenge and reward; 24-minute day/night; per-biome ambient particles and lighting |
| 10 | UI and presentation | HUD per the references, all panels, dialogue box, toasts, pickup feed, geode reveal, pause, settings (volumes, fullscreen, shake, rebinding, reset save), credits; 64 audio files |
| 11 | Saving and balancing | JSON save with backup, verification, migration and corruption quarantine; autosave; settings file; first-pass balance of costs, durability, XP and prices |
| — | Distribution | Windows export preset, a self-contained `DeepMine.exe`, GitHub repository |

## Partially completed
* **Balancing:** first-pass numbers only. Late-game pacing (levels 15+) needs more human play.
* **Touch pinch zoom** in the skill tree is supported in code but untested on a touch device.
* **Map travel:** the Map's Travel button opens the elevator list only when you're at camp or a station, by design.

## Not started (ideas for later)
* Controller/gamepad support.
* Weather on the surface, more NPCs, more side quests.
* Localization.

## Needs testing
* Long play sessions (2+ hours) for balance and performance at depth.
* Other GPUs and older machines. The Compatibility renderer was chosen for wide support.

## Known issues
* The Windows `.exe` shows the default Godot file icon in Explorer unless rcedit is configured in Editor Settings. The in-game window icon is correct.
* Godot prints "resources still in use at exit" only in the headless test runners. This is harmless.
