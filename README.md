# Roblox CQC Shooter

Short-range arena shooter for **Roblox Studio** / **Rojo**. Spawn into a readable enclosed arena with real cover, grab the **CQC Blaster**, and fight at close range. Server-authoritative raycast damage with magazine, reload, kill scoring, training dummies, and polished gun feel (recoil, muzzle flash, tracers, hitmarkers, sounds).

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## What’s included

| Piece | Role |
|--------|------|
| `WorldSetup.server.lua` | Floor tiles, walls + trim, 8–12 cover pieces (L-shapes, low walls, crates), spawn pads, outdoor lighting |
| `CombatService` | Validates fire, raycasts, falloff damage, ammo/reload; returns `FireResult` for client juice |
| `WeaponService` | Gives the Tool on every spawn (`CharacterAdded`) |
| `NPCService` | Training dummies at cover-adjacent spawn offsets |
| Client HUD + WeaponController | Health, ammo, kills, crosshair, hold-to-fire, R reload, recoil / FX |
| `Shared/Config.lua` | All tunables including `Feel`, `SoundIds`, arena, NPCs |

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
    Client/
      HUD.client.lua
      WeaponController.client.lua
```

Rojo mapping (`default.project.json`):

- `src/Shared` → `ReplicatedStorage.Shared`
- `src/Server` → `ServerScriptService.Server`
- `src/Client` → `StarterPlayer.StarterPlayerScripts.Client`
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

You should see the arena replace the baseplate, receive a **CQC Blaster** in your backpack, and spot orange training dummies near cover.

## Manual paste (no Rojo)

1. Create folders:
   - `ReplicatedStorage.Shared`
   - `ServerScriptService.Server` + `Server.Modules`
   - `StarterPlayer.StarterPlayerScripts.Client`
2. Copy ModuleScripts:
   - `Config.lua` → `ReplicatedStorage.Shared.Config`
   - `CombatService.lua`, `WeaponService.lua`, `NPCService.lua` → `Server.Modules`
3. Copy Scripts (server):
   - `Main.server.lua` → `Server.Main` (Script)
   - `WorldSetup.server.lua` → `Server.WorldSetup` (Script)
4. Copy LocalScripts:
   - `HUD.client.lua` → `Client.HUD` (LocalScript)
   - `WeaponController.client.lua` → `Client.WeaponController` (LocalScript)
5. Play Solo.

## How to playtest

1. **Play Solo** in Studio.
2. Press **1** (or click) to equip **CQC Blaster**.
3. **Hold Left Mouse** to fire; **R** to reload.
4. Walk up to a **Training Dummy** (inside ~25 studs for full damage) and shoot:
   - Camera should **punch** briefly and recover.
   - **Muzzle flash** + short **tracer** beam.
   - On a real hit: **hitmarker** (redder / larger on headshot), **damage number**, hit sound.
   - Empty mag: **dry click**, then auto-reload sound.
5. Peek around **L-cover / low walls / crates** — they block movement and raycasts.
6. Die / Reset → you respawn on a green pad with a fresh tool and full magazine.
7. Optional: local server with 2 players for PvP (friendly fire on by default).

### Controls

| Input | Action |
|--------|--------|
| Equip CQC Blaster | Select tool (hotbar) |
| Hold LMB / tap Activate | Fire (client sends look; server raycasts + returns `FireResult`) |
| R | Reload magazine |
| WASD / default Roblox | Move, jump, camera |

## Gun feel notes

- **Server authority stays intact**: client never applies damage. Juice (recoil, flash, tracer, hitmarker, damage numbers, hit sounds) only plays after `FireResult`.
- **Hitmarkers** appear only when the server confirms a damaging hit (`anyHit`).
- **Headshots** use a distinct marker color/size + `SoundIds.Headshot` when the hit part is named `Head`.
- **Tracers** are short Beams (default ~0.08s) from muzzle → ray end.
- If a `SoundId` fails to load in Studio, swap it in `Config.SoundIds` (common free library IDs; availability can vary by account).

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
| `Weapon.PelletCount` | 1 | Set `>1` + `SpreadDegrees` for shotgun |
| `Combat.HeadshotMultiplier` | 1.35 | Extra damage on Head hits |
| `Combat.FriendlyFire` | true | Players can hurt each other |

### Feel

| Knob | Default | Meaning |
|------|---------|---------|
| `Feel.RecoilPitchDegrees` | 1.35 | Camera punch up |
| `Feel.RecoilYawDegrees` | 0.35 | Random yaw punch |
| `Feel.RecoilRecoverSeconds` | 0.12 | Punch recovery time |
| `Feel.FovKick` | 1.8 | Temporary FOV bump |
| `Feel.FovRecoverSeconds` | 0.14 | FOV recovery |
| `Feel.MuzzleFlashSeconds` | 0.06 | Flash / light duration |
| `Feel.TracerDuration` | 0.08 | Beam lifetime |
| `Feel.HitMarkerSeconds` | 0.12 | Body-shot marker |
| `Feel.HeadshotMarkerSeconds` | 0.18 | Headshot marker |
| `Feel.DamageNumberLifetime` | 0.9 | Floating dmg lifetime |

### SoundIds (document / swap here)

| Key | Default ID | Use |
|-----|------------|-----|
| `SoundIds.Fire` | `rbxassetid://9114224527` | Primary fire |
| `SoundIds.FireAlt` | `rbxassetid://9114226351` | Layered crack |
| `SoundIds.Reload` | `rbxassetid://9111680145` | Reload start |
| `SoundIds.Empty` | `rbxassetid://9113895097` | Dry click |
| `SoundIds.HitConfirm` | `rbxassetid://9114221327` | Body hit |
| `SoundIds.Headshot` | `rbxassetid://9114222212` | Head hit |

Volumes live in `Config.SoundVolumes`.

### Arena / NPCs

| Knob | Default | Meaning |
|------|---------|---------|
| `Arena.Size` | 96 | Floor width/depth |
| `Arena.CoverPieces` | 10 | Designed cover count (layout is scripted) |
| `Lighting.*` | outdoor-ish | Ambient / Brightness / ClockTime |
| `NPC.Count` | 3 | Training dummies |
| `NPC.SpawnOffsets` | 3 vectors | Cover-adjacent spawn spots |
| `NPC.WalkSpeed` / `WanderRadius` | 6 / 22 | Dummy wander |

### Remotes

| Name | Direction | Purpose |
|------|-----------|---------|
| `FireWeapon` | C→S | Origin + look, or `"reload"` |
| `FireResult` | S→C | Shot / empty / reload payload for FX |
| `AmmoUpdate` / `StatsUpdate` / `KillFeed` | S→C | HUD |

## Design notes

- **Server authority**: client only sends origin + look vector (or `"reload"`). Server checks tool equipped, cooldown, ammo, clamps origin near character, raycasts up to `MaxRange`, applies falloff damage, then fires `FireResult` back to the shooter.
- **Cover blocks raycasts**: all cover parts use `CanCollide = true` and `CanQuery = true`.
- **Lanes**: mid axes and center stay open for CQC movement; L-covers sit toward corners.
- **WorldSetup** deletes default `Baseplate` / `SpawnLocation` and places multiple green `SpawnLocation`s on pads so players don’t float.
- **Default Roblox character** + Tool — no custom character required.

## Caveats

- Runtime-created Tool visuals are simple Parts (not MeshIds) — swap Handle for a mesh later if you want.
- Sound asset IDs are well-known public library IDs; if one 404s for your Studio session, replace it in `Config.SoundIds`.
- `WorldSetup` destroys Workspace `Baseplate` and `SpawnLocation` once at boot; don’t store important maps in those names.
- NPCs are dumb wanderers (no pathfinding / shooting back).
- Double `OnServerEvent` listeners on `FireWeapon` (combat + reload) are intentional and cheap.
- FilteringEnabled / modern Roblox networking assumed.
- Not a polished commercial gun kit — a teaching / jam-ready CQC loop with better feel.

## License

Use freely for learning, jams, and prototypes.
