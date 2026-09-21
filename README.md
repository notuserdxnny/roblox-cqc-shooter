# Roblox CQC Shooter

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**. Open a **hub** to pick a starter weapon (**Shotgun**, **SMG**, or **Pistol**), then spawn into a **grid of connected square rooms** with doors that **swing away from you**, half-wall cover, and crawl gaps. Server-authoritative raycast damage with per-weapon magazines, reload, kill scoring, training dummies, and polished gun feel (camera-only recoil, muzzle flash, tracers, hitmarkers, sounds).

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## What’s included

| Piece | Role |
|--------|------|
| `Hub.client.lua` | Lobby ScreenGui: title, loadout select, how-to, **Start** → `StartMatch` |
| `WorldSetup.server.lua` | **3×3 room complex**: floors, lights, walls, doorways, doors, half-walls, crawl gaps, spawns |
| `DoorService` | Server door tween; **opens away from the triggering player** (±angle from side / facing) |
| `CombatService` | Validates fire per equipped weapon, raycasts, falloff, ammo/reload; `FireResult` juice |
| `WeaponService` | Builds Shotgun / SMG / Pistol; grants **all three** after Start (equips selected) |
| `NPCService` | Training dummies in marked rooms |
| Client HUD + WeaponController + FirstPerson | HUD (hidden in hub), hold-to-fire, R reload, LockFirstPerson after Start |
| `Shared/Config.lua` | `Weapons`, `Feel`, `SoundIds`, `Map`, `Camera`, `Hub`, remotes |

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
      Hub.client.lua
      HUD.client.lua
      WeaponController.client.lua
      FirstPerson.client.lua
```

Rojo mapping (`default.project.json`):

- `src/Shared` → `ReplicatedStorage.Shared`
- `src/Server` → `ServerScriptService.Server`
- `src/Client` → `StarterPlayer.StarterPlayerScripts.Client`
- StarterPlayer: `CameraMode = LockFirstPerson`, zoom 0.5 / 0.5 (hub temporarily uses Classic for UI clicks)
- Remotes under `ReplicatedStorage.Remotes` (created at runtime if missing)

## Setup with Rojo (recommended)

1. Install [Rojo](https://rojo.space/) and the Rojo Roblox Studio plugin.
2. Open a terminal in this folder:

   ```bash
   cd roblox-cqc-shooter
   rojo serve
   ```

3. In Roblox Studio: open a **new Baseplate** place → Rojo plugin → **Connect**.
4. Press **Play** (Play Solo is enough).

You should see the **hub**, pick a starter gun, press **Start**, then play in first person with all three tools on the hotbar and training dummies in other rooms.

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
   - `Hub.client.lua` → `Client.Hub`
   - `HUD.client.lua` → `Client.HUD`
   - `WeaponController.client.lua` → `Client.WeaponController`
   - `FirstPerson.client.lua` → `Client.FirstPerson`
6. Play Solo.

## How to playtest

1. **Play Solo** — hub appears (Classic camera so you can click UI).
2. Select **Shotgun**, **SMG**, or **Pistol** as starter → **START**.
3. Camera locks **first person**; all three guns are in the hotbar; selected one is equipped.
4. **Hold Left Mouse** to fire; **R** to reload; **1–3** to switch weapons.
5. Walk to a doorway and use the **ProximityPrompt** — door **swings away from your side**.
6. **Jump** half-walls; walk into blue **crawl triggers** to slide under beams.
7. Shoot a **Training Dummy** — camera punch, muzzle flash, tracer, hitmarker on real hits.
8. Die / Reset → respawn still in-match with the full loadout.

### Controls

| Input | Action |
|--------|--------|
| Hub Start | Begin match; receive Shotgun + SMG + Pistol |
| Hotbar 1–3 | Switch weapons |
| Hold LMB / Activate | Fire (server raycasts + `FireResult`) |
| R | Reload current magazine |
| ProximityPrompt on door | Open away from you / close |
| WASD / Jump | Move; jump half-walls; crawl-slide |
| Mouse | Look (first person after Start) |

## Weapons

| Weapon | Role | Notes (defaults) |
|--------|------|------------------|
| **Shotgun** | Close blast | 8 pellets, wide spread, slow fire, mag 6 |
| **SMG** | Spray | Fast cooldown, mag 30, light damage |
| **Pistol** | Precision | Hard hits, tight spread, mag 12 |

Tune each under `Config.Weapons` in `src/Shared/Config.lua`.

## Map notes

- **3×3 grid** of square rooms (`Config.Map.RoomSize` default 30 studs) sharing walls with **doorway gaps**.
- **Doors**: wood parts on hinges; **ProximityPrompt** → `DoorService` tweens CFrame **away from the player** (chooses +/− open angle from which side you stand; facing breaks ties). Closed doors `CanCollide` + `CanQuery`; open doors do not block. Last open direction is stored for close.
- **Half-walls**: ~2.8 studs tall — jump over for CQC peek cover.
- **Crawl gaps**: side pillars + overhead beam + ForceField slide trigger.
- **Full-height walls / closed doors / ceiling** block raycasts (`CanQuery` true).
- **Per-room PointLights** and **varied floor colors**.
- **Spawn** pads only in the START room (grid 1,1). NPCs marked in other rooms.

## First-person / hub note

- While **hub** is open (`CQCInHub`), camera is **Classic** so buttons are clickable; HUD is hidden.
- After **Start**, `FirstPerson.client.lua` forces `LockFirstPerson` and zoom `0.5`, and re-applies on `CharacterAdded`.
- `default.project.json` sets LockFirstPerson on `StarterPlayer` as the post-hub default.

## Teleport-on-shoot fix

**Root cause:** `WeldConstraint` before aligning muzzle / flash CFrames yanked the Tool Handle (felt like a teleport).

**Fix:** set part `CFrame` **before** `WeldConstraint`; recoil is **camera-only** via `BindToRenderStep` at `Camera+1`.

## Gun feel notes

- Server authority: client never applies damage. Juice only after `FireResult`.
- Hitmarkers only on confirming damaging hits; headshots distinct.
- Recoil scale per weapon via `Feel.RecoilByWeapon`.
- Swap failed `SoundId`s in `Config.SoundIds` if needed.

## Config knobs (`src/Shared/Config.lua`)

### Weapons / combat

| Knob | Meaning |
|------|---------|
| `Weapons.Shotgun` / `SMG` / `Pistol` | Per-gun damage, range, cooldown, mag, pellets, spread |
| `WeaponOrder` | Hotbar / hub order |
| `DefaultWeaponId` | Hub default selection (`SMG`) |
| `Combat.HeadshotMultiplier` | Extra damage on Head |
| `Combat.FriendlyFire` | Players can hurt each other |

### Feel / camera / hub

| Knob | Meaning |
|------|---------|
| `Feel.RecoilPitchDegrees` / `Yaw` | Base camera punch |
| `Feel.RecoilByWeapon` | Multipliers per gun |
| `Camera.LockFirstPerson` | FPS lock after Start |
| `Hub.Title` / `Subtitle` / `HowTo` | Lobby copy |

### Map / doors / NPCs

| Knob | Default | Meaning |
|------|---------|---------|
| `Map.GridCols` / `GridRows` | 3 / 3 | Room grid |
| `Map.RoomSize` | 30 | Interior square size |
| `Map.DoorWidth` / `DoorHeight` | 6 / 9 | Doorway / door size |
| `Map.DoorTweenSeconds` | 0.35 | Open/close tween |
| `Map.DoorOpenAngleDegrees` | 95 | Swing magnitude (± chosen at open) |
| `Map.HalfWallRooms` | list | Jump-over cover rooms |
| `Map.CrawlGapRooms` | list | Crawl opening rooms |
| `NPC.Count` | 3 | Training dummies |

### Remotes

| Name | Direction | Purpose |
|------|-----------|---------|
| `StartMatch` | C→S | `{ weaponId }` begin match + loadout |
| `MatchStarted` | S→C | Hide hub / confirm |
| `FireWeapon` | C→S | Origin + look, or `"reload"` |
| `FireResult` | S→C | Shot / empty / reload FX payload |
| `AmmoUpdate` / `StatsUpdate` / `KillFeed` | S→C | HUD |
| `ToggleDoor` | reserved | Doors use server ProximityPrompt |

## Design notes

- **Hub gate**: no tools until `StartMatch`; combat ignores fire while not in-match.
- **Server authority**: origin + look validated; equipped Tool selects weapon stats.
- **Directional doors**: hinge + leaf offset registered; open CFrame = hinge × Y±angle × leaf; pick sign so open leaf is opposite the player.
- **Cover** blocks raycasts where full-height; half-walls are short on purpose.
- **WorldSetup** deletes default `Baseplate` / `SpawnLocation`.

## Caveats

- Runtime Tool visuals are simple Parts — swap Handle for a mesh later if you want.
- Sound asset IDs may 404 for some accounts; replace in `Config.SoundIds`.
- `WorldSetup` destroys Workspace `Baseplate` and `SpawnLocation` once at boot.
- NPCs are dumb wanderers (no pathfinding / shooting back).
- Crawl “slide” is a short HipHeight hack.
- FilteringEnabled / modern Roblox networking assumed.

## License

Use freely for learning, jams, and prototypes.
