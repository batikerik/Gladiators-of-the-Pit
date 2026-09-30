# The Pit — Gladiators of the Catacombs

A 2D roguelite brawler made for the **GenAI Game Jam**, built with **Summer Engine** (Godot 4.7) and GDScript.

A thief who stole grain to feed a starving city is sentenced by the High Judge and kicked into the Pit — a maze of catacombs full of the condemned. Hop, swing and fight your way through branching rooms, scavenge weapons and food, and face the Armoured Survivor to see daylight again.

## Features

- **Physics-driven combat with free weapon aim.** Hop with A/D and aim every blow with the mouse: head (critical), torso or legs (trips the enemy).
- **Deep but fast fighting:**
  - charged slashes and quick thrusts;
  - guard, and parry by raising the guard at the right moment;
  - guard breaks, counter-hits, combos, blade clashes.
- **Five weapons with their own feel:**

  | Weapon | Style |
  |---|---|
  | Rusty Gladius | Balanced |
  | Prisoner's Shiv | Fast combos |
  | Rusty Spear | Long thrust |
  | Executioner's Axe | Cuts through guards |
  | Bone Club | Stuns |

  Weight changes charge time, swing speed and how far you hop.
- **Survival:** an inventory, food that heals, and resting by a campfire, which costs food. Rest hungry and you lose health.
- **A new branching map every descent (Inscryption-style):** fights, caches, safe rooms and a boss. Enemies grow tougher with depth.
- **Permadeath with a corpse run.** When you die, your body and everything you carried stay in the Pit. The next escapee finds it at the same depth. Die before reaching it and it is gone.
- **Boss — the Armoured Survivor:**
  - plate armour, so aim for the head;
  - poise: it takes three leg hits to floor him;
  - phase 1, defensive stance;
  - phase 2, rage: aggressive hops, combo swings and a telegraphed leap attack.
- **Intro cutscene and tutorial:** the sentence, the Spartan kick into the abyss, a fall onto a pile of corpses, and a training zombie.
- **Main menu, settings and pause:** language, fullscreen, screen shake, music volume, nickname, erase progress.
- **Nicknames** shown above your health bar and on your corpse.
- **English and Russian**, switchable in Settings.
- **Music** for the menu and map, for fights, and for the death screen.
- **All art is procedural** — characters, weapons, catacombs and the parchment map are drawn in code.

## Controls

| Key | Action |
|---|---|
| A / D | Hop left / right |
| Hold & release LMB | Slash (cursor height picks head / torso / legs; full charge breaks guards) |
| RMB | Thrust |
| S / Shift | Guard (raise it just before a hit to parry) |
| E | Pick up, search a body, use a gate, rest by the fire |
| Q | Eat |
| 1-3 | Switch weapon |
| Tab / I | Inventory |
| Esc | Pause |

## Running the game

### In the editor

1. Install Summer Engine (`npx -y summer-engine@latest install`) or Godot 4.7.
2. Open the project folder (it contains `project.godot`).
3. Press Play. The game starts on the main menu.

### Web build

Summer Engine is a .NET build of Godot, and .NET builds cannot export to the web. The web version is assembled by hand instead:

1. Export the data pack with the `PackOnly` preset:
   ```bash
   Summer --headless --path . --export-pack "PackOnly" build/web/index.pck
   ```
2. Combine the pack with the official Godot 4.7.2 `web_nothreads_release` template.

The full steps are in `DEVLOG_GENAI.md`, entry #13.

To play a built version locally, run `run_web.bat`. It needs Node.js, starts a small server and opens `http://localhost:8060`.

## Tests

Six headless test scenes play the game by themselves: combat, tutorial, inventory, map and rooms, permadeath and boss, menus and localisation. Run one with:

```bash
Summer --headless --path . res://tests/combat_mechanics_test.tscn
```

The other scenes: `tutorial_flow_test`, `inventory_test`, `map_flow_test`, `permadeath_boss_test`, `menu_i18n_test`. Each prints `PASS` or `FAIL`.

## Project structure

```
scenes/       intro, tutorial, map, rooms, main menu, run end screen
scripts/      combat (combatant, weapon), AI and boss brain, rooms, map, UI
scripts/i18n/ Russian translation (English is the source language)
data/items/   weapon and food resources (.tres, editable in the inspector)
audio/music/  soundtrack
tests/        headless test scenes
tools/        local web server for the web build
```

## How it was made

The game was designed and directed by the author and built together with AI tools:

- **Claude Code (Claude Opus 5.5)**, connected to Summer Engine through its MCP server: code, scenes, tests, playtesting in the engine.
- **Antigravity (Gemini)**: the initial concept, the plan and the first combat prototype.
- **Google Flow Music**: the soundtrack.

The story of the development is in [DEVLOG.md](DEVLOG.md). The detailed technical log of every change is in [DEVLOG_GENAI.md](DEVLOG_GENAI.md).

## Credits

- Game design and direction: batikerik
- Music: generated with Google Flow Music — "Cozy Tavern Hearth", "Skirmish on the Road", "Catacomb Steps"
- Engine: Summer Engine, built on Godot Engine
