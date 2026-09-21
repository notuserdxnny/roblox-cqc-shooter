# Roblox CQC Shooter

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**. Spawn into a **grid of connected square rooms** with openable doors, half-wall cover, and crawl gaps. Grab the **CQC Blaster** and fight at close range. Server-authoritative raycast damage with magazine, reload, kill scoring, training dummies, and polished gun feel (camera-only recoil, muzzle flash, tracers, hitmarkers, sounds).

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## What’s included

| Piece | Role |
|--------|------|
| `WorldSetup.server.lua` | **3×3 room complex**: varied floors, per-room lights, full walls, doorways, doors, half-walls, crawl gaps, start-room spawns |
| `DoorService` | Server-authoritative door open/close (ProximityPrompt → tween CFrame + CanCollide) |
| `CombatService` | Validates fire, raycasts, falloff damage, ammo/reload; returns `FireResult` for client juice |
| `WeaponService` | Gives the Tool on every spawn (`CharacterAdded`); safe muzzle weld order |
| `NPCService` | Training dummies in marked rooms; wander stays near home room |
| Client HUD + WeaponController + FirstPerson | Health, ammo, kills, **centered crosshair**, hold-to-fire, R reload, **LockFirstPerson**, camera-only recoil / FX |
| `Shared/Config.lua` | All tunables including `Feel`, `SoundIds`, `Map`, `Camera`, NPCs |

## Project layout

```
roblox-cqc-shooter/
  README.md
  default.project.json
  src/
    Shared/
      Config.lua
    Server/
      Main.server.lua
      WorldSetup.server.lua
      Modules/
        CombatService.lua
        WeaponService.lua
        NPCService.lua
        DoorService.lua
    Client/
      HUD.client.lua
      WeaponController.client.lua
      FirstPerson.client.lua
```

Rojo mapping (`default.project.json`):

- `src/Shared` → `ReplicatedStorage.Shared`
- `src/Server` → `ServerScriptService.Server`
- `src/Client` → `StarterPlayer.StarterPlayerScripts.Client`
- StarterPlayer: `CameraMode = LockFirstPerson`, zoom 0.5 / 0.5, shift-lock off
- Remotes folder under `ReplicatedStorage.Remotes` (created at runtime if missing)

## Setup with Rojo (recommended)

1. Install [Rojo](https://rojo.space/) and the Rojo Roblox Studio plugin.
2. Open a terminal in this folder:

   ```bash
   cd roblox-cqc-shooter
   rojo serve
   ```

3. In Roblox Studio: open a **new Baseplate** place → Rojo plugin → **Connect**.
4. Press **Play** (Play Solo is enough).

You should spawn in the **START** room in first person, receive a **CQC Blaster**, see connected rooms with doors, and find orange training dummies in other rooms.

## Manual paste (no Rojo)

1. Create folders:
   - `ReplicatedStorage.Shared`
   - `ServerScriptService.Server` + `Server.Modules`
   - `StarterPlayer.StarterPlayerScripts.Client`
2. Set StarterPlayer `CameraMode = LockFirstPerson`, Min/Max zoom `0.5`.
3. Copy ModuleScripts:
   - `Config.lua` → `ReplicatedStorage.Shared.Config`
   - `CombatService.lua`, `WeaponService.lua`, `NPCService.lua`, `DoorService.lua` → `Server.Modules`
4. Copy Scripts (server):
   - `Main.server.lua` → `Server.Main` (Script)
   - `WorldSetup.server.lua` → `Server.WorldSetup` (Script)
5. Copy LocalScripts:
   - `HUD.client.lua` → `Client.HUD`
   - `WeaponController.client.lua` → `Client.WeaponController`
   - `FirstPerson.client.lua` → `Client.FirstPerson`
6. Play Solo.

## How to playtest

1. **Play Solo** in Studio — camera should be **locked first person** with a centered crosshair.
2. Press **1** (or click) to equip **CQC Blaster**.
3. **Hold Left Mouse** to fire; **R** to reload.
4. Walk to a doorway and use the **ProximityPrompt** (Open / Close) on doors.
5. **Jump** over waist-high half-walls; walk into blue **crawl triggers** to briefly slide under crawl beams.
6. Shoot a **Training Dummy**:
   - Camera should **punch** briefly and recover (**no character teleport**).
   - **Muzzle flash** + short **tracer** beam.
   - On a real hit: **hitmarker**, **damage number**, hit sound.
7. Die / Reset → respawn in the start room with a fresh tool and full magazine.

### Controls

| Input | Action |
|--------|--------|
| Equip CQC Blaster | Select tool (hotbar) |
| Hold LMB / tap Activate | Fire (client sends look; server raycasts + returns `FireResult`) |
| R | Reload magazine |
| ProximityPrompt on door | Open / close (server tween) |
| WASD / Jump | Move; jump half-walls; touch crawl gaps to slide |
| Mouse | Look (first person; shift-lock off by default) |

## Map notes

- **3×3 grid** of square rooms (`Config.Map.RoomSize` default 30 studs) sharing walls with **doorway gaps**.
- **Doors**: wood parts on hinges; **ProximityPrompt** → `DoorService` tweens CFrame; closed doors `CanCollide` + `CanQuery` (block movement and bullets); open doors do not block.
- **Half-walls**: ~2.8 studs tall, `CanCollide` true — jump over for CQC peek cover (bullets clear over the top).
- **Crawl gaps**: side pillars + overhead beam (~3 stud floor opening) + ForceField trigger that briefly lowers `HipHeight` / boosts speed for a slide-through.
- **Full-height walls / closed doors / ceiling** block raycasts (`CanQuery` true).
- **Per-room PointLights** and **varied floor colors** so rooms read clearly.
- **Spawn** pads only in the START room (grid 1,1). NPCs marked in other rooms.

## First-person note

- `FirstPerson.client.lua` forces `CameraMode = LockFirstPerson` and Min/Max zoom `0.5`, and **re-applies on `CharacterAdded`**.
- `default.project.json` sets the same on `StarterPlayer`.
- Shift-lock (`DevEnableMouseLock`) defaults **off** (`Config.Camera.EnableMouseLock = false`).
- HUD crosshair stays at screen center for FPS feel.

## Teleport-on-shoot fix

**Root cause:** `WeldConstraint` was created **before** aligning the muzzle tip / muzzle-flash part CFrames. Welding at the wrong relative offset made physics yank the Tool Handle (and thus the character) when the flash appeared or the tool equipped — felt like a teleport when firing.

**Fix:**

1. Set part `CFrame` **before** creating `WeldConstraint` (WeaponService muzzle tip + client muzzle flash).
2. Recoil is **camera-only**: accumulated pitch/yaw applied in `BindToRenderStep` at `Camera+1`. Never writes `HumanoidRootPart` / character CFrame.

## Gun feel notes

- **Server authority stays intact**: client never applies damage. Juice only after `FireResult`.
- **Hitmarkers** only when the server confirms a damaging hit (`anyHit`).
- **Headshots** distinct marker + `SoundIds.Headshot` when hit part is `Head`.
- **Tracers** short Beams from muzzle → ray end.
- Swap failed `SoundId`s in `Config.SoundIds` if needed.

## Config knobs (`src/Shared/Config.lua`)

### Weapon / combat

| Knob | Default | Meaning |
|------|---------|---------|
| `Weapon.DamageClose` | 28 | Damage inside effective range |
| `Weapon.DamageFar` | 6 | Damage near max range |
| `Weapon.MaxRange` | 55 | Ray max (studs) |
| `Weapon.EffectiveRange` | 25 | Full close damage within this |
| `Weapon.FireCooldown` | 0.18 | Seconds between shots |
| `Weapon.MagazineSize` | 12 | Rounds per mag |
| `Weapon.ReloadTime` | 1.6 | Reload duration (seconds) |
| `Combat.HeadshotMultiplier` | 1.35 | Extra damage on Head hits |
| `Combat.FriendlyFire` | true | Players can hurt each other |

### Feel / camera

| Knob | Default | Meaning |
|------|---------|---------|
| `Feel.RecoilPitchDegrees` | 1.35 | Camera punch up (camera only) |
| `Feel.RecoilYawDegrees` | 0.35 | Random yaw punch |
| `Feel.RecoilRecoverSeconds` | 0.12 | Punch recovery time |
| `Camera.LockFirstPerson` | true | FPS lock |
| `Camera.MinZoom` / `MaxZoom` | 0.5 | Zoom clamp |
| `Camera.EnableMouseLock` | false | Shift-lock off |

### Map / doors / NPCs

| Knob | Default | Meaning |
|------|---------|---------|
| `Map.GridCols` / `GridRows` | 3 / 3 | Room grid |
| `Map.RoomSize` | 30 | Interior square size |
| `Map.DoorWidth` / `DoorHeight` | 6 / 9 | Doorway / door size |
| `Map.DoorTweenSeconds` | 0.35 | Open/close tween |
| `Map.HalfWallRooms` | list | Rooms with jump-over cover |
| `Map.CrawlGapRooms` | list | Rooms with crawl openings |
| `NPC.Count` | 3 | Training dummies |
| `NPC.WanderRadius` | 10 | Stay near home room |

### Remotes

| Name | Direction | Purpose |
|------|-----------|---------|
| `FireWeapon` | C→S | Origin + look, or `"reload"` |
| `FireResult` | S→C | Shot / empty / reload payload for FX |
| `AmmoUpdate` / `StatsUpdate` / `KillFeed` | S→C | HUD |
| `ToggleDoor` | reserved | Door prompts are server-side ProximityPrompt |

## Design notes

- **Server authority**: client sends origin + look (or `"reload"`). Server checks tool, cooldown, ammo, clamps origin, raycasts, applies damage, returns `FireResult`.
- **Cover blocks raycasts** where full-height (`CanCollide` + `CanQuery`). Half-walls are short on purpose.
- **WorldSetup** deletes default `Baseplate` / `SpawnLocation` and places start-room spawns.
- **Default Roblox character** + Tool — no custom character required.

## Caveats

- Runtime Tool visuals are simple Parts — swap Handle for a mesh later if you want.
- Sound asset IDs may 404 for some accounts; replace in `Config.SoundIds`.
- `WorldSetup` destroys Workspace `Baseplate` and `SpawnLocation` once at boot.
- NPCs are dumb wanderers (no pathfinding / shooting back).
- Crawl “slide” is a short HipHeight hack (Roblox has no built-in crouch).
- FilteringEnabled / modern Roblox networking assumed.

## License

Use freely for learning, jams, and prototypes.
