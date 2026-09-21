# Roblox CQC Shooter — One in the Chamber

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**.

**Game is One in the Chamber (OITC) only for now.** Casual mode and the hub mode picker are removed. You begin in a dedicated **Lobby** (not the combat map). Open the **hub UI**, press **Start** for a **3…2…1…GO!** countdown at the combat spawn, then fight in the **grid of connected square rooms** with directional doors, half-wall cover, and crawl gaps. Server-authoritative raycast damage, kill scoring, training dummies, and polished gun feel (camera-only recoil, muzzle flash, tracers, hitmarkers, sounds).

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## One in the Chamber (OITC)

Classic CoD-style rules (the only active mode):

| Rule | Behavior |
|------|----------|
| Loadout | **Pistol only** + **Knife** (Shotgun / SMG defs remain in Config for later, not granted) |
| Starting ammo | **1 bullet** (magazine display = 1, reserve 0) |
| On kill | **+1 bullet** (gun *or* melee kill) |
| Empty ammo | **Melee** — LMB with empty mag *or* Knife equipped → server melee raycast |
| Win | First to `Config.OITC.KillsToWin` (**default 5**) → end overlay (**Play Again** / **Hub**) |
| Death / respawn | Still in-match; ammo resets to **1 bullet** again |
| Reload | **Disabled** — bullets only from kills or spawn |
| Gun damage | OITC pistol is **one-shot** (`Config.OITC.GunDamage`) |

Hub flow: **START** only (no mode picker / loadout row).

## What’s included

| Piece | Role |
|--------|------|
| `Hub.client.lua` | OITC hub UI, **match countdown** (3…2…1…GO!), end overlay (**Play Again** / **Hub**) |
| `GameModeService` | Countdown → combat, OITC score / win (`KillsToWin`), return to hub |
| `LobbyService` | Lobby freeze / frozen combat teleport for countdown / release after GO |
| `WorldSetup.server.lua` | **3×3 combat grid** + separate **Lobby** room; combat teleport pads |
| `DoorService` | Server door tween; **opens away from the triggering player** |
| `CombatService` | Fire + **melee** validation, OITC ammo awards on kill, `FireResult` juice |
| `WeaponService` | OITC = Pistol + Knife; grants after Start |
| `NPCService` | Training dummies in marked rooms |
| Client HUD + WeaponController + FirstPerson | HUD (bullets / OITC score), hold-to-fire, melee when empty, LockFirstPerson after Start |
| `Shared/Config.lua` | `Weapons`, `OITC`, `Feel`, `Map`, `Hub`, remotes |

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
        LobbyService.lua
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
- StarterPlayer: `CameraMode = Classic`, zoom 8–20 (match forces LockFirstPerson after Start)
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

You should see the **OITC hub**, press **Start**, then play in first person.

## Manual paste (no Rojo)

1. Create folders:
   - `ReplicatedStorage.Shared`
   - `ServerScriptService.Server` + `Server.Modules`
   - `StarterPlayer.StarterPlayerScripts.Client`
2. Set StarterPlayer `CameraMode = Classic`, Min/Max zoom `8` / `20` (match locks FP after Start).
3. Copy ModuleScripts:
   - `Config.lua` → `ReplicatedStorage.Shared.Config`
   - `CombatService.lua`, `WeaponService.lua`, `GameModeService.lua`, `LobbyService.lua`, `NPCService.lua`, `DoorService.lua` → `Server.Modules`
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

1. **Play Solo** — you spawn in the **Lobby** room; OITC hub UI appears (Classic camera, free mouse).
2. Read the rules card → **START MATCH** (or expand **HOW TO PLAY**).
3. Teleport to combat spawn → **3…2…1…GO!** (still frozen) → then unfreeze; camera locks **first person**; **Pistol** + **Knife** on the hotbar.
4. HUD shows **BULLETS 1** and **SCORE 0 / 5**.
5. Fire your one shot at a **Training Dummy** — kill awards **+1 bullet** and increments score.
6. Shoot until empty → HUD shows **MELEE**; **LMB** does a short-range knife attack (also awards a bullet on kill).
7. Reach **5 kills** (`Config.OITC.KillsToWin`) → end overlay (**Play Again** / **Hub**) or wait for auto-return.
8. Die / Reset mid-match → respawn with **1 bullet** again, score kept.

### Controls

| Input | Action |
|--------|--------|
| Hub Start | Begin OITC match; grant Pistol + Knife after GO |
| Hotbar | Pistol / Knife |
| Hold LMB | Fire pistol, or melee when ammo is 0 |
| R | Reload disabled in OITC |
| ProximityPrompt on door | Open away from you / close |
| WASD / Jump | Move; jump half-walls; crawl-slide |
| Mouse | Look (first person after Start) |

## Weapons

| Weapon | Role | Notes (defaults) |
|--------|------|------------------|
| **Pistol** | OITC gun | 1 bullet, one-shot (`GunDamage`), kill = +1 ammo |
| **Knife** | OITC melee | Short-range server raycast when empty |
| **Shotgun** / **SMG** | Unused | Still defined in `Config.Weapons` for a future Casual mode; **not granted** |

Tune under `Config.Weapons` / `Config.OITC` in `src/Shared/Config.lua`.

## Map notes

- **3×3 grid** of square rooms (`Config.Map.RoomSize` default 30 studs) sharing walls with **doorway gaps**.
- **Doors**: wood parts on hinges; **ProximityPrompt** → `DoorService` tweens CFrame **away from the player**.
- **Half-walls**: ~2.8 studs tall — jump over for CQC peek cover.
- **Crawl gaps**: side pillars + overhead beam + ForceField slide trigger.
- **Lobby** SpawnLocation is the only join spawn. Combat **START** room (grid 1,1) has teleport pads used on StartMatch. NPCs marked in other rooms.

## Lobby vs match flow

| Phase | Where you are | Camera / mouse | Tools | Movement |
|-------|---------------|----------------|-------|----------|
| **Lobby** (before Start) | Dedicated **Lobby** room (`WorldSetup` → `CQCArena.Lobby`), far from the combat grid | **Classic**, mouse **unlocked** for UI | None | Frozen (`WalkSpeed` / jump 0) |
| **Countdown** (after Start) | Teleported to combat **START** pads | **LockFirstPerson** peek, mouse **unlocked** for overlay | None yet | Still **frozen** |
| **Match** (after GO) | Same combat pads | **LockFirstPerson**, mouse locked | Pistol + Knife | Normal |
| **End overlay** | Frozen in place | Classic / unlocked mouse for buttons | Stripped on Hub / Play Again | Frozen |
| **Return to hub** | Strip tools → teleport back to Lobby → freeze | Classic again | None | Frozen |

### Match countdown

1. Hub **START** → server teleports you to a combat spawn **still frozen**, no shooting (`CQCInMatch` still false).
2. Server fires `MatchCountdown` → client full-screen **3… 2… 1… GO!** (`Config.Match.CountdownSeconds` default **3**).
3. Optional tick / round-start sounds (`Config.Match.RoundStartSoundId`, `Config.SoundIds.CountdownTick`).
4. After countdown + GO hold → server **unfreezes**, grants OITC loadout, sets `CQCInMatch`, fires `MatchStarted` → first-person combat.

### End screen

When a player reaches `Config.OITC.KillsToWin`:

- Winner is **frozen**; combat blocked (`CQCMatchOver`).
- Hub-themed overlay: **YOU WIN** / match over, winner name, final score, optional match time.
- **Play Again** — OITC again → back through the countdown.
- **Hub** — return to lobby UI.
- Auto-return after `Config.Match.WinnerRestartSeconds` (default 20) if no button is pressed.

- Hub UI sets `CQCInHub`; countdown sets `CQCCountdown`; live combat sets `CQCInMatch`.
- `FirstPerson.client.lua` gates on `CQCInHub` / `CQCCountdown` / `CQCInMatch` / `CQCMatchOver` — lobby mouse stays unlocked; FP after countdown (mouse locks on GO).
- StarterPlayer defaults to **Classic** zoom 8–20; match camera applies during countdown/match.
- Only the Lobby has a Roblox `SpawnLocation`. Combat pads are teleport targets only.

## Teleport-on-shoot fix

**Root cause:** `WeldConstraint` before aligning muzzle / flash CFrames yanked the Tool Handle.

**Fix:** set part `CFrame` **before** `WeldConstraint`; recoil is **camera-only** via `BindToRenderStep` at `Camera+1`.

## Knife / OITC melee fix

**Root cause:** `CombatService.HandleMelee` bailed whenever pistol ammo was `> 0`, so an equipped **Knife** still did nothing after a kill refill. Empty-mag `FireWeapon` also returned without routing to melee (client had to fire a separate `MeleeAttack` remote). Server never listened to Knife `Tool.Activated`.

**Fix:** melee allowed when **Knife is equipped OR ammo is 0**; empty OITC LMB routes to `HandleMelee`; Knife `Tool.Activated` is bound on the server; client also treats MouseButton1 as a fire/melee backup.

## Config knobs (`src/Shared/Config.lua`)

### Match countdown / end

| Knob | Default | Meaning |
|------|---------|---------|
| `Match.CountdownSeconds` | **3** | Seconds shown before GO |
| `Match.GoDisplaySeconds` | 0.85 | How long "GO!" stays before combat |
| `Match.EndFreezeSeconds` | 1.25 | Freeze after win before end overlay |
| `Match.WinnerRestartSeconds` | 20 | Auto Hub if end buttons ignored |
| `Match.RoundStartSoundId` | rbxassetid | Optional sting on GO (empty = silent) |
| `Match.RoundStartSoundVolume` | 0.55 | GO sound volume |

### OITC

| Knob | Default | Meaning |
|------|---------|---------|
| `DefaultMode` | `"OITC"` | Only active mode |
| `OITC.KillsToWin` | **5** | First to this many kills wins |
| `OITC.StartingAmmo` | 1 | Bullets on spawn / match start |
| `OITC.WeaponId` | `"Pistol"` | Only gun granted |
| `OITC.GunDamage` | 100 | One-shot pistol |
| `OITC.MeleeRange` | 8 | Melee raycast studs |
| `OITC.MeleeDamage` | 100 | Knife damage |
| `OITC.MeleeCooldown` | 0.5 | Seconds between melee swings |
| `OITC.WinnerRestartSeconds` | 20 | Fallback auto-hub (prefer `Match.*`) |
| `OITC.AllowReload` | false | No R-reload |

### Weapons / combat

| Knob | Meaning |
|------|---------|
| `Weapons.Shotgun` / `SMG` / `Pistol` | Per-gun defs (only Pistol granted in OITC) |
| `WeaponOrder` | Catalog order |
| `DefaultWeaponId` | `"Pistol"` |
| `Combat.HeadshotMultiplier` | Extra damage on Head |
| `Combat.FriendlyFire` | Players can hurt each other |

### Remotes

| Name | Direction | Purpose |
|------|-----------|---------|
| `StartMatch` | C→S | Begin OITC match (hub Start **or** Play Again); server ignores mode/weapon payload |
| `MatchCountdown` | S→C | `{ seconds, mode, weaponId }` → show 3…2…1…GO! |
| `MatchStarted` | S→C | After GO — combat live / lock FP mouse |
| `MatchEnded` | S→C | `{ winnerName, youWin, kills, killsToWin, durationSec, mode }` |
| `ReturnToHub` | C↔S | Request / force lobby |
| `FireWeapon` | C→S | Origin + look, or `"reload"` / `"sync"` |
| `MeleeAttack` | C→S | Empty-ammo melee origin + look |
| `FireResult` | S→C | Shot / empty / reload / melee FX |
| `AmmoUpdate` / `StatsUpdate` / `KillFeed` | S→C | HUD (OITC score / meleeReady) |
| `ToggleDoor` | reserved | Doors use server ProximityPrompt |

## Design notes

- **Lobby gate**: spawn in Lobby (separate space); no tools / frozen until Start.
- **Countdown gate**: teleport frozen → `MatchCountdown` → GO → loadout + `CQCInMatch`; combat ignores fire until then.
- **OITC-only**: `GameModeService.StartMatch` always uses OITC rules; hub has no mode picker.
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
