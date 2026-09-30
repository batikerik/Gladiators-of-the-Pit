# Build plan — The Pit / Яма

Source: .summer/GameSoul.md (2026-09-29)

## Milestone 1: Core Combat & Controls (GladiHoppers + Free Weapon Aim)
- [x] `combatant.tscn`: Multi-part 2D physics character with hopping locomotion (A/D jump impulses, balance stabilization)
- [x] Free mouse weapon control: Weapon joint follows/whips with mouse movement, registering angular velocity and collision impact
- [x] Body part hitboxes: Distinct collision zones for Head, Torso, and Legs with directional hit reaction and velocity-scaled damage
- [x] Sound/Visual punch: Hit flashes, impact sparks, blood/dust particles, camera shake

## Milestone 2: Intro & Combat Tutorial
- [x] Intro cutscene: Spartan-kick into the abyss ("This is Sparta!"), falling sequence, landing on a pile of corpses
- [x] First weapon pickup on the corpse pile
- [x] Tutorial Zombie: Harmless, immortal until player lands hits on required body zones:
  - Task 1: Hit Head
  - Task 2: Hit Torso
  - Task 3: Hit Legs
- [x] Objective UI overlay displaying tutorial checklist

## Milestone 3: Inventory, Food & Weapon Variety
- [x] Inventory data system (weapons, food items)
- [x] Weapon stats & behaviors (different weight, reach, damage multiplier)
- [x] Food system (consumable resources required to rest safely) — `RunState.rest()` ready; the rest UI comes with the Safe Room (Milestone 4)

## Milestone 4: Node Map & Safe Room (Inscryption Style)
- [x] Node-based room progression map (Combat, Loot/Cache, Safe Room, Boss)
- [x] Safe Room scene: Campfire/rest station, inventory management, food consumption to prevent HP loss
- [x] Room transition & encounter generation — the boss room uses a placeholder profile until Milestone 5

## Milestone 5: Death, Corpse Run & First Boss Encounter
- [x] Permadeath & Corpse Run logic: save player death coordinates/room ID, spawn corpse loot pile for subsequent run
- [x] First Boss encounter: Armored Human Survivor with aggressive hopping AI, defensive stances, and weapon swings
- [x] Victory & defeat flow for the vertical slice

## Milestone 6: Main Menu, Settings & English Localisation
- [x] Main menu: title screen over the living catacomb arena — Play, Settings, Exit
- [x] Settings (saved to disk): language, fullscreen, screen shake, erase progress
- [x] Pause menu on Esc: Resume, Settings, Main menu, Quit
- [x] The whole game in English (source language), Russian kept as a translation switchable in Settings
