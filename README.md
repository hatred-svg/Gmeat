# Gmeat

Fast free-for-all PvP quest race for the Sector 75 map. 2–6 players, ~4 minute rounds.

## Install

1. Subscribe to Sector 75 on the Workshop (map name `sector75`).
2. Copy this whole `gmeat` folder into `garrysmod/addons/` so you have `garrysmod/addons/gmeat/gamemodes/gmeat/...`.
3. Restart Garry's Mod. Pick **Gmeat** in the gamemode list (with its blood-splat icon, `gamemodes/gmeat/icon24.png`; the main menu shows the Gmeat logo, `gamemodes/gmeat/logo.png`) (bottom-right of the main menu) and start `sector75`.
   Use **2+ max players** (a listen server) even when testing alone. Single-player mode behaves differently.

**Coming from Gmaze** (the gamemode's old name): delete the old `garrysmod/addons/gmaze` folder first, so the
two don't both show up in the gamemode list. Every setting and console command is now `gmeat_...` instead of
`gmaze_...`, so any values you changed under the old name start from the defaults again.

### Testing alone

Open the console and run:

```
gmeat_min_players 1
gmeat_quest assembly      (or delivery / bomb / killconfirmed / random)
gmeat_restart
```

`bot` adds a bot that stands still: useful for testing kills, respawns and drops.

## How a round works

Prep countdown (maze resets) → 240s race → winner screen → next round.
The maze never traps anyone: rooms that could cut a player off from the rest of the map never generate in Gmeat (dead ends, "fake dead ends" whose way on is a hidden door, and the Underhalls, whose entrances are one-way drops off a railing or through a hole in the floor). The few ordinary rooms with a door hard-wired to the Underhalls have that door sealed shut. The rules are `GmeatTrapRooms` in `lua/autorun/gmeat_rooms.lua`.
Each round picks one quest. The first player to complete it wins. If time runs out, the player with the most progress wins.
Everyone spawns with no weapons. During the countdown Gmeat builds a small maze (about 2 rooms per player) and puts every player in their own room, as far apart as possible; the first objective goes in a room roughly the same distance from everyone. Players who die respawn after 3 seconds in an opened room away from their opponents (and out of their sight), with 3 seconds of spawn protection that ends early if they shoot.
Supply drops appear 10 seconds into the round, then every 25 seconds. Each holds 2 weapons (3 weapons 40% of the time). Each one is marked on the minimap and with an on-screen waypoint. Hold E for 3s to open it and get those weapons from the server's SWEP library. Which weapons is completely random: every weapon in the pool has exactly the same chance in every drop, at any point in the round (one drop never holds the same weapon twice).

| Quest | Goal |
|---|---|
| Assembly | Collect power cells scattered in new rooms and install 6 at the generator (hold E). Carried cells drop on death. |
| Hot Delivery | Capture the flag: grab the package, then reach the drop-off. The carrier is slowed and visible to everyone. |
| Demolition | Carry the explosive to the demolition site, plant it (hold E 3s, standing still), and keep it from being defused (5s) until it blows. A planted bomb forces overtime. |
| Kill Confirmed | Every kill drops a skull. The killer walks over it to confirm (+1); anyone else walking over it denies it. First to 9 confirmed kills wins; on time-out, most confirmed kills wins. Skulls vanish after 60s. |

**Q** opens the minimap (mouse wheel zooms). It builds as rooms generate. Yellow dots are unopened doors. Each room is mapped on a 64-unit grid when it generates; squares the quick check misses (narrow or off-grid corridors, stairs, sunken or raised sections) are searched over the room's full height and around the square, so rooms show up whole. Areas you haven't opened yet aren't on the map.

## Players

Every player is a random Half-Life 2 citizen with the flesh material (`models/flesh`) painted over the whole body, the first-person hands and the corpse. Change or turn it off with `GMEAT.PlayerMaterial` in `gamemode/sh_config.lua` (`""` = normal look). Note that it covers the clothes, so the per-player colour tint on the model doesn't show.

## Deaths and gore

* Corpses are server-side ragdolls, so they land on Sector 75's room floors instead of falling through (the default client-side corpses only collide with map brushes). They collapse where the player died, then writhe like a slasher-movie victim for about 7 seconds: a violent death spasm, hands clutching the wound (or the stump), rolling and arching, kicking legs, a thrashing head, dragging themselves along the floor away from the killer while moaning, and a final gasp. The torso can't leave the floor. They fade after 20 seconds.
* **Headless crawling**: when the killing blow takes the head off, half the time (`HeadlessCrawlChance`) the body drops and then drags itself along the floor, headless, for a few seconds: one hand reaches out and plants, the body hauls itself up to it, then the other hand, slower and slower as it bleeds out, the legs trailing and pushing weakly, heading away from its killer (turning if it's stuck against a wall), the neck spurting the whole time. Then the usual death throes. With an arm gone it crawls with the other; with both gone it doesn't crawl. A hard hit (25+) stops it. Never for any other death. Settings in `GMEAT.Gore` (`sv_gore.lua`); the movement is `sv_crawl.lua`.
* While dead, the camera orbits your own corpse (move the mouse to look around).
* Every bullet hit pops a small Left 4 Dead 2 style impact: a quick red flash, a dense little puff that blooms and hangs for a moment, and a short spray of droplets, mostly back toward the shooter (gone in under half a second). Half-Life 2's own blood cloud is switched off (players and corpses don't use engine bleeding), so this replaces it. Each hit also leaves a bullet wound mark on the body (a dark hole in a ragged ring of blood, `materials/gmeat/decals/wound1-4`), on players and corpses alike.
* Every hit spurts a stream of dark red liquid from the wound, following that body part for a moment, with small irregular leaks and short squirts in between (spurt size: `SPURT_SCALE` at the top of `cl_gore.lua`, currently 0.2). The blood always comes out of the body as you see it: a hit is sent as the body part plus a point on it, and your game puts it on that part of the model on your screen, on its surface (a bullet's hitbox can sit a few units off the visible body, and a running player is drawn slightly behind where the server saw them, which used to make blood appear out of thin air beside them). Every drop falls all the way to the floor. A corpse keeps gushing from its killing wound while it writhes.
* Blood splats on walls: an impact splat behind the victim when they're hit, and a directional spray wherever a spurt reaches a nearby wall (the droplets stop there). See "Blood decals" below. **Blood on the floor**: every hit drips onto the floor under the victim (a drip or two, three for a headshot), a corpse's gushing wound leaves a pool and keeps dripping for as long as it bleeds, a stump drips where it spurts, and a burst splashes all around (at most 24 floor stains a second however busy it gets). Gibs landing on the floor and vomited blood leave stains too. Floor stains aren't decals: Sector 75's floors are parts of the rooms' models, and a model only keeps a few dozen decals (the oldest vanish), so the server finds the floor and every client draws the stain there itself, lying on the floor and lit by the room's light (flickering included), lit exactly like the blood on the walls (the engine lights a room's wall decals with the light at the room's centre plus the moving lights where they are, and the floor stains are lit the same way), but 27% brighter: they use copies of the wall textures with the colour scaled by 1.27 (`materials/gmeat/decals/floorblood_*`, made from the wall ones by `make_floor_blood.py <decals folder> 1.27`). A stain only ever lands on the rooms' own floors (never on a prop that could be knocked away), and never past a wall between it and the wound: blood flying at a wall lands at its foot. Up to 500 are kept per round (`GMEAT.FloorStains` / `MaxFloorStains` in `sh_config.lua`). The bodies' own shapes for this are `GMEAT.BodySegments` in `sh_config.lua`.
* The killing blow blows off the limb it hit (head, forearm, hand, leg...) into flesh gibs (no bones), and the stump spurts for a few seconds. Explosions, or any single hit of 100+ damage, gib the whole body: flesh chunks, one spine, and the heart, both lungs and sometimes the windpipe fly out with the chunks (once the organ models are compiled, see below).
* **Blood vomiting**: some corpses (`gmeat_bloodvomit_chance`, default 0.4, so 40% of deaths) choke on their own blood. A second or two after death they start coughing it up and vomiting it from the mouth, two to five times at irregular moments: a hacking cough (a short spray and a dark puff, and the body lurches) or a weak gush that pours out in uneven surges for a second or two, falls short of a couple of feet and keeps drooling afterwards. Each gush is weaker than the last. It's silent: no coughing or vomiting sounds. This blood does reach the floor: it splashes there and leaves small pools and drops (`GmeatVomitPool` / `GmeatVomitDrops`, smaller versions of Gmeat's splats; turn them off with `FloorStains` in `GMEAT.BloodVomit`). Never after a headshot, and it stops if the head comes off or the body bursts. Timing and strength: `GMEAT.BloodVomit` in `gamemode/sh_config.lua`.
* **Eating gibs**: when you're hurt, look at a gib (flesh chunk or organ) and press E (the hint says "E: Eat") to eat it and get health back: a flesh chunk or the windpipe 10, a lung 15, the heart 25, the spine 5, never above your max. It plays `gibeat`, spurts a little blood and the gib is gone. One bite per press, at most every half second. Anything you can hold E on (the bomb, a supply drop, the generator) always takes priority over gibs lying next to it, and E never picks gibs up like a prop. Amounts: `GMEAT.GibEating` at the top of `sv_gore.lua`. Gibs last 10–12 seconds.
* Corpses can still be shot: they bleed, thrash again and clutch the new wound, a shot limb blows off (the whole limb below the cut disappears), and an explosion or about 120 total damage bursts the corpse into gibs.
* `gmeat_gore 0` turns off dismemberment and gibs (corpses stay). Players can set `gmeat_blood 0/1/2` for none / normal / extra blood particles. Tunables are in `GMEAT.Gore` at the top of `sv_gore.lua`.

## Flinching

Any damage (bullets, melee, explosions, falls, drowning) makes the hit body part jolt away from where the blow came from and spring back with a small rebound, in about half a second:
* **Head**: the head and neck whip back (and the chest a little).
* **Torso**: the spine bends away, with some whiplash in the head.
* **Arms and legs**: that limb kicks away, plus a little of the joint above it.
* **Explosions** throw the whole upper body away from the blast; **hard landings** buckle it forward.

If it's you, your camera jolts the same way: shot from the front, your head snaps back and up; from behind, forward and down; from one side, it turns and tilts away; landing hard nods it down. Bigger hits and headshots jolt harder. Half-Life 2's red damage arrows are switched off.

The body flinch is drawn on each player's own computer from one small message per hit. Tunables are in `GMEAT.Flinch` (`cl_flinch.lua`) and the `Flinch...` settings in `GMEAT.Camera` (`cl_camera.lua`). The camera part follows `gmeat_camshake` (0 turns it off). If body parts ever jolt toward the shooter instead of away, set `GMEAT.Flinch.Invert = true`.

## Blood decals

Gmeat has its own blood decals in `materials/gmeat/decals/`:
* **Impact splats** (`splat1`–`splat4`, about 51 units across): a dark, thick pool with a scalloped edge and a coagulated rim, thin spines shooting out of it, a crown of satellite droplets with tails, and fine mist. Used on the wall behind someone who's hit, and where gibs land.
* **Sprays** (`spray1`–`spray4`, about 33 units across): a directional burst of droplets that thins and stretches out along the way the blood was travelling. Used where a spurt reaches a wall.

**Half-Life 2's own blood decals are replaced too.** `materials/decals/blood1`–`blood8` (the engine's blood on walls and floors when anyone bleeds) and `materials/decals/flesh/blood1`–`blood5` (the bloody bullet-wound marks on bodies, kept small at about 12 units) are overridden with files pointing at Gmeat's splats and sprays, including their `_subrect` versions, which are the ones Garry's Mod actually loads. Their brush/model pairs live in `materials/gmeat/decals/hl2/`. Because they're plain file overrides, they apply whenever this addon is installed, in every gamemode, not just Gmeat. To get the original blood back, delete the addon's `materials/decals` folder. Alien (yellow) blood and Half-Life 2's blood particle sprites are untouched.

Both lists are in `gamemode/sh_config.lua` (`GMEAT.BloodDecalMaterials`, `GMEAT.SprayDecalMaterials`); one is picked at random per splat. Empty a list to go back to Half-Life 2's `Blood` decal.

### Adding your own

1. **Make the image.** A splat on a transparent background (it needs an alpha channel), saved as PNG or TGA, square, 128, 256 or 512 pixels.
2. **Convert it to VTF** with VTFEdit (or VTFEdit Reloaded): *File > Import*, choose **DXT5** (keeps soft alpha edges), leave *Generate Mipmaps* on, tick **Clamp S** and **Clamp T**. Save it as e.g. `garrysmod/addons/gmeat/materials/gmeat/decals/mysplat.vtf`.
3. **Write two material files** next to it (copy `splat1.vmt` and `splat1_model.vmt` and change the names). The first is used on map brushes, the second on models; Sector 75's rooms are models, so most splats use the second. `$decalscale` is world units per pixel: 256 px at 0.2 is 51 units across.
4. **Add it** to one of the lists in `sh_config.lua`, e.g. `"gmeat/decals/mysplat"` (path inside `materials/`, no `.vmt`, the brush version).
5. **Change map** and shoot a bot standing next to a wall.

A purple/black checkerboard means a path in a `.vmt` is wrong. A splat that shows on map brushes but not on room walls means the `$modelmaterial` line is wrong.

## Sound

All files are in `sound/gmeat/` and listed in `GMEAT.Sounds` in `gamemode/sh_config.lua`, so any of them can be swapped there.

| Sound | When | Who hears it |
|---|---|---|
| `ambient/mazeambient.ogg` | loops the whole time you're on the map, through every round (a seamless 115 s loop; it picks up where it was after each round's map reset) | everyone, in their ears; `gmeat_ambient_volume 0-1` |
| `vo/quest_assembly`, `quest_delivery`, `quest_bomb`, `quest_killconfirmed` | the start of a round of that quest | everyone |
| `vo/supply_drop_1`–`4` | each time a supply drop spawns (one at random) | everyone |
| `vo/narrator_win` / `vo/narrator_lose` | the end of a round: the winner hears *win*, everyone else *lose* (on a draw everyone hears *lose*; a cancelled round gets neither) | each player |
| `vo/killstreak_3`, `_5`, `_10` | 3, 5 and 10 kills without dying | the killer |
| `death/playerdeath1`–`14` | from a player's corpse when they die (one at random). Silent if the body exploded or the head came off, and cut off if the corpse is later decapitated or blown apart. Replaces Half-Life 2's scream, moans and final gasp | nearby players |
| `sfx/gibimpact1`–`5` | gibs hitting walls and floors, louder for harder hits. Replaces Half-Life 2's flesh impacts | nearby players |
| `sfx/dropopen` | while opening a supply drop (stops if you let go) | nearby players |
| `sfx/bombplant` | while planting the explosive (stops if interrupted) | nearby players |
| `sfx/bombdefuse` | while defusing, repeating every 1.1 s (stops if interrupted) | nearby players |
| `sfx/lowhealth.ogg` | loops while your health is at or below 25% of max (`LowHealthBelow`): fades in, fades out once you're healed or dead, and carries on where it left off next time (an 81 s seamless loop) | you, in your ears; `gmeat_lowhealth_volume 0-1` |
| `sfx/gibeat` | eating a gib | nearby players |
| `sfx/weaponscroll` | each step through the weapon list | you |

Narrator lines never talk over each other: they queue, lines for one player (killstreaks, win/lose) go ahead of general announcements, and a line that's waited too long is skipped. Round-start and supply-drop lines are the announcer's own recordings (`sound/gmeat/vo/<line key>.mp3`, see `sh_announcer.lua`), so more lines can be voiced the same way.

The positional sounds (death cries, gib impacts, plant/defuse/crate, eating) are mono so they come from the right direction; the death cries and gib impacts were levelled to a similar loudness. Narrator lines are untouched.

## 80s slasher lighting

The map's lighting can't be rebaked from a gamemode, so the look is layered on top (`cl_slasher.lua`):
* **Film grade**: crushed blacks and higher contrast, colour drained a little, and a cold blue "day for night" moonlight cast lifted into the shadows.
* **Warm halation**: bright lights bleed a soft orange glow, like old film stock.
* **Darkness closing in**: a near-black blue fog swallows anything more than about 1500 units away.
* **Failing lights**: every 25–70 seconds the lights stutter through a few quick dips, sometimes a long one.
* **No flashlight**: Half-Life 2's flashlight is disabled in Gmeat. It's taken away on spawn, pressing **F** does nothing, and anything that still switches one on (another addon, a console command) has it switched off again within half a second.

Players can turn it off with `gmeat_slasher_look 0`. Tunables (contrast, tint, fog distances, flicker timing) are in `GMEAT.Slasher` at the top of `cl_slasher.lua`. For a much darker game, Sector 75's own darkness mode can be switched on in `ApplySector75Settings` in `init.lua` (`sector75_darkness_mode`); without flashlights that makes the maze very dark.

## The flesh maze

* **Flesh walls and ceilings**: every room Sector 75 generates gets the flesh material (`models/flesh`) on its walls and ceilings. Each room model is read once and every material in it is sorted by which way its surfaces face: mostly facing up is a floor and is left alone; facing sideways or down becomes flesh. Lights, glowing, glass and see-through materials are never changed, so the rooms' light fixtures look the same. Doors (separate entities) keep their look.
* **Barnacle tentacles**: 1–3 per room (about one per 10 floor cells), hanging from real ceiling points away from doorways: a barnacle body with the flesh material and its tongue stretched down 40–110 units, swaying slowly. About a third have a skull dangling from the tip. The tongue is laid out like Valve's barnacle does it (`Barnacle.tongue1`–`8` hanging from `Barnacle.base`, each bone pointing along the tongue). Tongue tips stay at least 76 units above the floor, so they hang above head height. They're client-side models: nothing can touch, shoot or walk into them, they block nothing, and the server never knows they exist. Placement comes from the room itself, so everyone sees the same tentacles.
* **The walls bleed**: a bullet or melee blow into a flesh wall or ceiling makes it bleed with Gmeat's own blood: the impact puff sprays back out toward the shooter, a wound opens in the wall (`materials/gmeat/decals/fleshwound1-4`), sometimes with a spray of blood around it, a short spurt comes out and it keeps oozing and dribbling for 2–3 seconds. Shotgun volleys open at most 4 wounds. Scripted weapons (most addon guns) skip their usual bullet hole and dust there; Half-Life 2's built-in weapons can't be changed, so they still leave their normal hole under the blood. Players with `gmeat_flesh_maze 0` just see a normal bullet hole.
* The server picks where tentacles hang while it samples each room (the ceiling above floor cells), and sends those points with the room, so every player gets the same ones. A room's tentacles appear once you've been near it. `gmeat_flesh_debug` in the console shows how many rooms and tentacles have been built.
* None of this touches the 80s slasher lighting: that's a screen effect drawn over whatever is rendered.
* Players can switch it off with `gmeat_flesh_maze 0`. Tunables (material, counts, lengths, bone chance, what counts as a floor) are in `GMEAT.FleshMaze` at the top of `cl_fleshmaze.lua`.

## Survivor camera

The first-person view looks like it's filmed on a shaky handheld camera held by a starving, paranoid survivor: a slow uneasy drift, trembling hands, breathing that gets heavier after sprinting, a dip and sway with each footstep, and now and then a nervous glance to one side. The drift calms down while you hold attack or aim.

* **Getting a kill**: a short, violent shake with a jolt of zoom, the screen floods blood red, and a glowing red maze flashes over it, animating and settling from slightly too close, all in under a second. The maze is `materials/gmeat/fx/killmaze` (24 animation frames); its brightness and speed are `KillMazeAlpha` / `KillMazeFPS` in `GMEAT.Camera`. One kill in three also flashes a glowing red outline image in the middle of the screen (a square maze or the man in the maze), stuttering on like a subliminal frame; the maze dims behind it. Add or remove images in `KillImages` and change the odds with `KillImageChance`.
* **Low health**: the lower your health, the stronger the film grain (kept subtle: even near death it's about a third of what it used to be), the shakier your hands, the more colour drains out and the darker the edges of the screen get.
* The shake moves the camera only. Bullets still go exactly where you aim.
* **Your own legs**: look down and you see your hips and legs, moving with your animation (walking, running, strafing, crouching, jumping) and wearing the flesh material like your hands. They're a client-only copy of your model with everything from the belly up (torso, arms, head) collapsed into a point inside the lower spine, so no arms show and the waist closes over cleanly instead of being cut open, locked to the camera (placed right under it at the moment each frame is drawn, facing exactly where it faces, so they never lag behind a fast turn), a little behind it and leaning back from the feet (`GMEAT.Legs.Back` and `Lean` in `cl_legs.lua`), so they run from below the middle of the screen out past its bottom edge and the hips are never in view. They cast no shadows. Leg flinches show on them too. Hidden in third person, while dead and in vehicles; `gmeat_legs 0` turns them off, and the console command `gmeat_legs_debug` prints what they're doing.
* Players can set `gmeat_camshake 0-2` (0 = off) and `gmeat_grain 0-2` (0 = off). Tunables are in `GMEAT.Camera` at the top of `cl_camera.lua`.

## HUD

* **The round display at the top** (quest name, timer and objective) sits on the same ornate plate, stretched to fit the text, with your progress line just underneath.
* **Health, ammo and the weapon list** sit on an ornate rusted plate (`materials/gmeat/hud/plate`). The plate is drawn in three slices: its two ornate ends always keep their shape, and the middle fills whatever width is needed (repeated, mirrored, rather than smeared), so the same image works for the big health and ammo panels and the slim weapon rows. The selected weapon's plate is bright and sticks out to the left; the others are darker.
* **The blood-red bar** (`materials/gmeat/hud/bar_frame` over `bar_fill`, from `blood_red_bar.xcf`) is used for the health bar, the magazine bar next to the ammo count, and every hold-E progress bar: planting and defusing the bomb, opening supply drops and installing power cells. The frame's rounded ends keep their shape at any length, and the red fill is cut off (not squeezed) as it empties. Health and ammo bars throb when you're down to the last quarter. Sizes are `GMEAT.HUD.BarSource` in `sh_config.lua`.
* **Scrolling the weapon list** (mouse wheel or number keys) plays `sound/gmeat/sfx/weaponscroll.mp3` instead of Half-Life 2's click (`GMEAT.Sounds.WeaponScroll`).
* **Everything else is red**: the text boxes, notices, spawn protection, the chat tag and the minimap (rooms in dark reds, the room you're in in blood red, your arrow in bone white). The colours are `GMEAT.HUD` in `gamemode/sh_config.lua`.

## Console

| Command | |
|---|---|
| `gmeat_restart` | new round now |
| `gmeat_drop` | spawn a supply drop now |
| `gmeat_weapons` | list the supply-drop weapon pool |
| `gmeat_rooms` | list tracked rooms (check "spots" > 0) |
| `gmeat_show_spots` | draw the sampled floor spots and doors (needs `developer 1`) |

Settings (all `gmeat_*`): `min_players`, `round_time`, `prep_time`, `post_time`, `respawn_time`, `spawn_protect`, `quest`,
`drop_first`, `drop_interval`, `drop_max`, `weapon_blacklist`, `weapon_whitelist`, `hl2_weapons`,
`assembly_cells`, `bomb_fuse`, `killconfirmed_goal`, `room_sets`, `s75_exploration`, `gore`, `bloodvomit_chance`, `admin_noclip`.
Client: `gmeat_minimap_rotate`, `gmeat_minimap_corner`, `gmeat_blood`, `gmeat_camshake`, `gmeat_grain`, `gmeat_slasher_look`, `gmeat_ambient_volume`, `gmeat_lowhealth_volume`, `gmeat_legs`, `gmeat_flesh_maze`.

Weapon tiers (`GMEAT.WeaponTierOverrides` in `gamemode/sh_config.lua`) only decide which new weapon you switch to after opening a drop; they don't affect what drops.

Note: Gmeat changes some Sector 75 settings (nextbotless mode on, dungeon crawler off, room set). Those settings are saved, so switch them back in Sandbox if you want.

## For the team

* **Voice lines**: drop files into `sound/gmeat/vo/<key>.wav`. Variants go in `<key>_1.wav` … `<key>_5.wav`. Keys and subtitle text live in `gamemode/sh_announcer.lua`. No code changes are needed.
* **Custom rooms**: `lua/autorun/gmeat_rooms.lua`. A room whose model isn't installed yet is skipped automatically, so it's safe to register rooms before they're built.
* **New quests**: add a file to `gamemode/quests/`. It's loaded automatically. See the header of `sh_quests.lua` for the callbacks.
* **Organ gibs**: the textures are in `materials/models/gmeat/gibs/`; the models are compiled from the separate `gmeat_modelsrc` folder with Crowbar (steps in its README) into `models/gmeat/gibs/`. Missing models are skipped. Meshes: OpenGameArt "Human heart" and "Human lungs" (CC0).

```
gamemodes/gmeat/gamemode/
  shared.lua, sh_config.lua, sh_announcer.lua, sh_quests.lua
  init.lua                 server entry, announcer, Sector 75 settings
  sv_rooms.lua             tracks generated rooms, floor sampling, sends the map to clients
  sv_prebuild.lua          builds the maze during the countdown, separates players
  sv_round.lua             round loop
  sv_player.lua            spawn (no weapons) / death / respawn / protection
  sv_interact.lua          walk-over pickups and hold-E interactions
  sv_carry.lua             CTF-style carriable objectives + zones
  sv_drops.lua             supply drops + weapon pool
  sv_markers.lua           minimap / waypoint markers
  sv_gore.lua              corpses, dismemberment, gibs, blood events
  sv_writhe.lua            slasher-movie death throes
  sv_crawl.lua             headless bodies dragging themselves along the floor
  sv_vomit.lua             blood coughing and vomiting from corpses
  sv_commands.lua          admin commands
  cl_camera.lua            handheld survivor camera, kill flash, low-health grain
  cl_legs.lua              your own legs when you look down
  cl_slasher.lua           80s slasher lighting: grade, glow, fog, flickering lights
  cl_flinch.lua            hit flinches (body part + camera)
  cl_fleshmaze.lua         flesh walls and ceilings, hanging barnacle tentacles
  cl_sound.lua             map ambience and the narrator queue
  cl_rooms.lua, cl_minimap.lua, cl_hud.lua, cl_hud_player.lua, cl_effects.lua, cl_gore.lua
  quests/                  sh_assembly.lua, sh_delivery.lua, sh_bomb.lua, sh_killconfirmed.lua
gamemodes/gmeat/entities/entities/   generator, cell, carriable, zone, planted bomb, supply drop, skull, gib
lua/autorun/gmeat_rooms.lua          custom Sector 75 rooms
materials/models/gmeat/gibs/         organ gib textures (heart, lung, trachea)
materials/gmeat/fx/                  film grain and vignette for the camera
materials/gmeat/decals/              blood splat and spray decals
sound/gmeat/                         ambience, narrator (vo/), death cries (death/), effects (sfx/)
materials/decals/                    overrides that swap Half-Life 2's blood decals for Gmeat's
models/gmeat/gibs/                   compiled organ gibs (put Crowbar's output here)
```
