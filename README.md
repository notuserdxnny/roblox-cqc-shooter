# Roblox CQC Shooter

Short-range arena shooter for **Roblox Studio** / **Rojo**. Spawn into a small enclosed arena, grab the **CQC Blaster**, and fight at close range. Server-authoritative raycast damage with magazine, reload, kill scoring, and training dummies for solo Play.

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## What’s included

| Piece | Role |
|--------|------|
| `WorldSetup.server.lua` | Builds floor, walls, cover crates, spawn pads on an empty Baseplate |
| `CombatService` | Validates fire requests, raycasts, falloff damage, ammo/reload |
| `WeaponService` | Gives the Tool on every spawn (`CharacterAdded`) |
| `NPCService` | 1–2 wandering training dummies |
| Client HUD + WeaponController | Health, ammo, kills, crosshair, hold-to-fire, R reload |
| `Shared/Config.lua` | All tunables (damage, range, ammo, arena, NPCs) |

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

You should see the arena replace the baseplate, receive a **CQC Blaster** in your backpack, and spot orange training dummies.

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
4. Walk up to a **Training Dummy** (inside ~25 studs for full damage) and shoot until it drops — your **KILLS** counter should rise.
5. Die / Reset → you respawn with a fresh tool and full magazine.
6. Optional: start a local server with 2 players to test PvP (friendly fire is on by default).

### Controls

| Input | Action |
|--------|--------|
| Equip CQC Blaster | Select tool (hotbar) |
| Hold LMB / tap Activate | Fire (client sends look; server raycasts) |
| R | Reload magazine |
| WASD / default Roblox | Move, jump, camera |

## Config knobs (`src/Shared/Config.lua`)

| Knob | Default | Meaning |
|------|---------|---------|
| `Weapon.DamageClose` | 28 | Damage inside effective range |
| `Weapon.DamageFar` | 6 | Damage near max range |
| `Weapon.MaxRange` | 55 | Ray rejected / minimal beyond this (studs) |
| `Weapon.EffectiveRange` | 25 | Full close damage within this |
| `Weapon.FireCooldown` | 0.18 | Seconds between shots |
| `Weapon.MagazineSize` | 12 | Rounds per mag |
| `Weapon.ReloadTime` | 1.6 | Reload duration (seconds) |
| `Weapon.PelletCount` | 1 | Set `>1` + `SpreadDegrees` for shotgun |
| `Combat.HeadshotMultiplier` | 1.35 | Extra damage on Head hits |
| `Combat.FriendlyFire` | true | Players can hurt each other |
| `Arena.Size` | 80 | Floor width/depth |
| `Arena.CoverCount` | 6 | Wooden cover crates |
| `NPC.Count` | 2 | Training dummies |
| `NPC.WalkSpeed` / `WanderRadius` | 6 / 18 | Dummy wander |

## Design notes

- **Server authority**: client only sends origin + look vector (or `"reload"`). Server checks tool equipped, cooldown, ammo, clamps origin near character, raycasts up to `MaxRange`, applies falloff damage.
- **Default Roblox character** + Tool — no custom character required.
- **WorldSetup** deletes the default Baseplate/SpawnLocation and builds the arena in code so an empty place works out of the box.

## Caveats

- Runtime-created Tool visuals are simple Parts (not MeshIds) — swap Handle for a mesh later if you want.
- `WorldSetup` destroys Workspace `Baseplate` and `SpawnLocation` once at boot; don’t store important maps in those names.
- NPCs are dumb wanderers (no pathfinding / shooting back).
- Double `OnServerEvent` listeners on `FireWeapon` (combat + reload) are intentional and cheap.
- FilteringEnabled / modern Roblox networking assumed.
- Not a polished commercial gun kit — a teaching / jam-ready CQC loop.

## License

Use freely for learning, jams, and prototypes.
