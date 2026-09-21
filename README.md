# Roblox CQC Shooter

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**. Open a **hub**, pick a **game mode** (**Casual** or **One in the Chamber**), then spawn into a **grid of connected square rooms** with directional doors, half-wall cover, and crawl gaps. Server-authoritative raycast damage, kill scoring, training dummies, and polished gun feel (camera-only recoil, muzzle flash, tracers, hitmarkers, sounds).

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## Game modes

### Casual (default)

- Pick a **starter weapon** (Shotgun / SMG / Pistol); all three go to the hotbar.
- Full magazines, **R** to reload, normal falloff damage.
- Freeplay / training against dummies; kill counter on the HUD.

### One in the Chamber (OITC)

Classic CoD-style rules:

| Rule | Behavior |
|------|----------|
| Loadout | **Pistol only** + **Knife** (no Shotgun / SMG) |
| Starting ammo | **1 bullet** (magazine display = 1, reserve 0) |
| On kill | **+1 bullet** (gun *or* melee kill) |
| Empty ammo | **Melee only** — short-range server raycast / Knife |
| Win | First to `Config.OITC.KillsToWin` (**default 5**) → winner UI → optional **Back to Hub** |
| Death / respawn | Still in-match; ammo resets to **1 bullet** again |
| Reload | **Disabled** — bullets only from kills or spawn |
| Gun damage | OITC pistol is **one-shot** (`Config.OITC.GunDamage`) |

Hub flow: select **One in the Chamber** → **START** (gun pick is skipped / locked to Pistol).

## What’s included

| Piece | Role |
|--------|------|
| `Hub.client.lua` | Lobby: mode select (Casual / OITC), Casual loadout, Start, winner → hub |
| `GameModeService` | Mode tracking, OITC score / win, return to hub |
| `WorldSetup.server.lua` | **3×3 room complex**: floors, lights, walls, doorways, doors, half-walls, crawl gaps, spawns |
| `DoorService` | Server door tween; **opens away from the triggering player** |
| `CombatService` | Fire + **melee** validation, OITC ammo awards on kill, `FireResult` juice |
| `WeaponService` | Casual = three guns; OITC = Pistol + Knife; grants after Start |
| `NPCService` | Training dummies in marked rooms |
| Client HUD + WeaponController + FirstPerson | HUD (bullets / OITC score), hold-to-fire, melee when empty, LockFirstPerson after Start |
| `Shared/Config.lua` | `Weapons`, `OITC`, `Modes`, `Feel`, `Map`, `Hub`, remotes |

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
        GameModeService.lua
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

You should see the **hub**, pick **Casual** or **One in the Chamber**, press **Start**, then play in first person.

## Manual paste (no Rojo)

1. Create folders:
   - `ReplicatedStorage.Shared`
   - `ServerScriptService.Server` + `Server.Modules`
   - `StarterPlayer.StarterPlayerScripts.Client`
2. Set StarterPlayer `CameraMode = LockFirstPerson`, Min/Max zoom `0.5`.
3. Copy ModuleScripts:
   - `Config.lua` → `ReplicatedStorage.Shared.Config`
   - `CombatService.lua`, `WeaponService.lua`, `GameModeService.lua`, `NPCService.lua`, `DoorService.lua` → `Server.Modules`
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

### Casual

1. **Play Solo** — hub appears (Classic camera so you can click UI).
2. Mode **Casual** → select **Shotgun**, **SMG**, or **Pistol** → **START**.
3. Camera locks **first person**; all three guns on the hotbar.
4. **Hold Left Mouse** to fire; **R** to reload; **1–3** to switch.
5. Doors, half-walls, crawl gaps, and training dummies work as before.

### One in the Chamber

1. Hub → select **One in the Chamber** (loadout list hides; rules card shows).
2. **START** — you get **Pistol** + **Knife** only; HUD shows **BULLETS 1** and **SCORE 0 / 5**.
3. Fire your one shot at a **Training Dummy** — kill awards **+1 bullet** and increments score.
4. Shoot until empty → HUD shows **MELEE**; **LMB** does a short-range knife attack (also awards a bullet on kill).
5. Reach **5 kills** (`Config.OITC.KillsToWin`) → winner banner → **Back to Hub** (or wait for auto-return).
6. Die / Reset mid-match → respawn with **1 bullet** again, score kept.

### Controls

| Input | Action |
|--------|--------|
| Hub mode buttons | Casual vs One in the Chamber |
| Hub Start | Begin match; grant mode loadout |
| Hotbar | Casual 1–3 guns; OITC Pistol / Knife |
| Hold LMB | Fire gun, or melee when OITC ammo is 0 |
| R | Reload current magazine (**Casual only**) |
| ProximityPrompt on door | Open away from you / close |
| WASD / Jump | Move; jump half-walls; crawl-slide |
| Mouse | Look (first person after Start) |

## Weapons

| Weapon | Role | Notes (defaults) |
|--------|------|------------------|
| **Shotgun** | Close blast | 8 pellets, wide spread, slow fire, mag 6 (**Casual only**) |
| **SMG** | Spray | Fast cooldown, mag 30 (**Casual only**) |
| **Pistol** | Precision / OITC | Casual: mag 12. OITC: 1 bullet, one-shot, kill = +1 ammo |
| **Knife** | OITC melee | Short-range server raycast when empty |

Tune under `Config.Weapons` / `Config.OITC` in `src/Shared/Config.lua`.

## Map notes

- **3×3 grid** of square rooms (`Config.Map.RoomSize` default 30 studs) sharing walls with **doorway gaps**.
- **Doors**: wood parts on hinges; **ProximityPrompt** → `DoorService` tweens CFrame **away from the player**.
- **Half-walls**: ~2.8 studs tall — jump over for CQC peek cover.
- **Crawl gaps**: side pillars + overhead beam + ForceField slide trigger.
- **Spawn** pads only in the START room (grid 1,1). NPCs marked in other rooms.

## First-person / hub note

- While **hub** is open (`CQCInHub`), camera is **Classic** so buttons are clickable; HUD is hidden.
- After **Start**, `FirstPerson.client.lua` forces `LockFirstPerson` and zoom `0.5`.
- After an OITC win, winner UI appears; **Back to Hub** (or auto after `WinnerRestartSeconds`) restores the lobby.

## Teleport-on-shoot fix

**Root cause:** `WeldConstraint` before aligning muzzle / flash CFrames yanked the Tool Handle.

**Fix:** set part `CFrame` **before** `WeldConstraint`; recoil is **camera-only** via `BindToRenderStep` at `Camera+1`.

## Config knobs (`src/Shared/Config.lua`)

### Modes / OITC

| Knob | Default | Meaning |
|------|---------|---------|
| `DefaultMode` | `"Casual"` | Hub default mode |
| `OITC.KillsToWin` | **5** | First to this many kills wins |
| `OITC.StartingAmmo` | 1 | Bullets on spawn / match start |
| `OITC.WeaponId` | `"Pistol"` | Only gun granted in OITC |
| `OITC.GunDamage` | 100 | One-shot pistol in OITC |
| `OITC.MeleeRange` | 7 | Melee raycast studs |
| `OITC.MeleeDamage` | 100 | Knife damage |
| `OITC.MeleeCooldown` | 0.5 | Seconds between melee swings |
| `OITC.WinnerRestartSeconds` | 6 | Auto return to hub after win |
| `OITC.AllowReload` | false | No R-reload in OITC |

### Weapons / combat

| Knob | Meaning |
|------|---------|
| `Weapons.Shotgun` / `SMG` / `Pistol` | Per-gun damage, range, cooldown, mag, pellets, spread |
| `WeaponOrder` | Hotbar / hub order |
| `DefaultWeaponId` | Casual hub default (`SMG`) |
| `Combat.HeadshotMultiplier` | Extra damage on Head (Casual) |
| `Combat.FriendlyFire` | Players can hurt each other |

### Remotes

| Name | Direction | Purpose |
|------|-----------|---------|
| `StartMatch` | C→S | `{ weaponId, mode }` begin match + loadout |
| `MatchStarted` | S→C | Hide hub / confirm mode |
| `MatchEnded` | S→C | OITC winner payload |
| `ReturnToHub` | C↔S | Request / force lobby |
| `FireWeapon` | C→S | Origin + look, or `"reload"` / `"sync"` |
| `MeleeAttack` | C→S | OITC empty-ammo melee origin + look |
| `FireResult` | S→C | Shot / empty / reload / melee FX |
| `AmmoUpdate` / `StatsUpdate` / `KillFeed` | S→C | HUD (includes OITC score / meleeReady) |
| `ToggleDoor` | reserved | Doors use server ProximityPrompt |

## Design notes

- **Hub gate**: no tools until `StartMatch`; combat ignores fire while not in-match.
- **Mode gate**: `GameModeService` owns Casual vs OITC; `CombatService` applies ammo / melee / win hooks.
- **Server authority**: origin + look validated; equipped Tool selects weapon stats; melee is a separate short raycast.
- **Directional doors**: hinge + leaf offset; open away from the player.
- **WorldSetup** deletes default `Baseplate` / `SpawnLocation`.

## Caveats

- Runtime Tool visuals are simple Parts — swap Handle for a mesh later if you want.
- Sound asset IDs may 404 for some accounts; replace in `Config.SoundIds`.
- `WorldSetup` destroys Workspace `Baseplate` and `SpawnLocation` once at boot.
- NPCs are dumb wanderers (no pathfinding / shooting back). Dummy kills **do** count for OITC score (handy for solo playtest).
- Crawl “slide” is a short HipHeight hack.
- FilteringEnabled / modern Roblox networking assumed.

## License

Use freely for learning, jams, and prototypes.
