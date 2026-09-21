# Roblox CQC Shooter — One in the Chamber

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**.

**Game is One in the Chamber (OITC) only for now.** You begin in a dedicated **Lobby** with a full-screen **hub** (**Play | Shop | Inventory | Settings**). Press **START** for a **3…2…1…GO!** countdown, then fight in a **3×3 room grid** with doors, half-walls, and crawl gaps. Server-authoritative combat, **Credits** economy, cosmetic shop (Part-based pistol/knife skins), and polished gun feel.

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## Hub tabs

| Tab | Contents |
|-----|----------|
| **Play** | OITC title, rules card, **START**, expandable how-to |
| **Shop** | Browse cosmetics; buy with **Credits** (server-authoritative) |
| **Inventory** | Owned items; **Equip** pistol/knife skin, trail, hitmarker, title |
| **Settings** | Stub (points to Roblox Esc for audio/graphics) |

Hub `ScreenGui` uses **IgnoreGuiInset**, full-screen `UDim2.fromScale(1,1)` dark overlay (blocks world clicks), shared `Theme` (corners, strokes, gradients, hover states).

## Credits economy

| Source | Amount (`Config.Economy`) |
|--------|---------------------------|
| Starting balance | **100** |
| Kill | **+25** |
| Win (reach KillsToWin) | **+100** |
| Match played (non-winner, in-match) | **+10** |

Persisted via **DataStore** (`CQCPlayerData_v1`) with **in-memory fallback** when Studio/API fails (`PlayerDataService`).

## Shop items

Skins are **Part/Color3/Material** variants of constructed Tool models (no MeshAssets).

### Pistol skins
| Id | Name | Price |
|----|------|------:|
| `pistol_default` | Stock Iron | 0 (owned) |
| `pistol_crimson` | Crimson Edge | 150 |
| `pistol_arctic` | Arctic Frost | 200 |
| `pistol_neon` | Toxic Neon | 250 |
| `pistol_void` | Void Protocol | 300 |
| `pistol_gold` | Gilded Chamber | 350 |

### Knife skins
| Id | Name | Price |
|----|------|------:|
| `knife_default` | Standard Blade | 0 (owned) |
| `knife_blood` | Bloodletter | 175 |
| `knife_chrome` | Chrome Edge | 200 |
| `knife_ember` | Ember Fang | 275 |

### Trails / hitmarkers / titles
| Id | Name | Price |
|----|------|------:|
| `trail_none` | No Trail | 0 |
| `trail_cyan` | Cyan Wake | 125 |
| `trail_gold` | Gold Wake | 200 |
| `hit_default` | Classic X | 0 |
| `hit_lime` | Lime Confirm | 100 |
| `hit_magenta` | Magenta Pulse | 150 |
| `title_none` | No Title | 0 |
| `title_rookie` | Rookie | 50 |
| `title_chamber` | One Chamber | 175 |
| `title_ace` | Ace | 300 |

**Remotes:** `GetShop`, `PurchaseItem`, `EquipItem`, `ShopResult`, `CreditsUpdate`, `PlayerDataSync`.

Equipped pistol/knife skins apply on **match start** (`WeaponService.GiveLoadout` → `ApplyEquippedCosmetics`). Trails attach to HumanoidRootPart; titles use a BillboardGui; hitmarker colors are read client-side from attributes.

## 3D Tool models (Parts only)

`Shared/WeaponModels.lua` builds welded assemblies (no MeshIds):

- **Pistol** — grip Handle, frame, slide + serrations, cylinder barrel, neon muzzle (+ PointLight), front/rear sights, trigger guard, mag, grip panels
- **Knife** — grip + rings, pommel, crossguard, blade, wedge tip, neon edge + spine

Shop skins recolor **Primary / Accent / Metal** roles and materials (e.g. gold Neon, chrome Glass).

Lobby includes **weapon display stands** + desk (Parts). Half-walls get metal top trim. Lighting adds gentle **ColorCorrection** + **Bloom**.

## One in the Chamber (OITC)

| Rule | Behavior |
|------|----------|
| Loadout | **Pistol** + **Knife** (detailed Part models) |
| Starting ammo | **1 bullet** |
| On kill | **+1 bullet** + Credits |
| Empty ammo | Knife melee (whoosh + hit SFX) |
| Win | First to `Config.OITC.KillsToWin` (**5**) |
| Death / respawn | Still in-match; ammo resets to **1**; cosmetics re-applied |
| Reload | **Disabled** |

## Project layout

```
roblox-cqc-shooter/
  README.md
  default.project.json
  src/
    Shared/
      Config.lua          # weapons, OITC, Economy, ShopItems, remotes, feel
      Theme.lua           # shared UI theme
      WeaponModels.lua    # Part-assembled pistol/knife + skin apply
    Server/
      Main.server.lua
      WorldSetup.server.lua
      Modules/
        PlayerDataService.lua
        ShopService.lua
        CombatService.lua
        WeaponService.lua
        GameModeService.lua
        LobbyService.lua
        NPCService.lua
        DoorService.lua
    Client/
      Hub.client.lua      # full-screen hub tabs + countdown/end
      HUD.client.lua      # strip HUD, kill feed, vignette
      WeaponController.client.lua
      FirstPerson.client.lua
```

## Setup with Rojo

```bash
cd roblox-cqc-shooter
rojo serve
```

Studio: new Baseplate → Rojo Connect → **Play**.

## How to playtest

1. Spawn in **Lobby** — full-screen hub (world dimmed / not clickable).
2. **Shop** — buy a skin with starting Credits; **Inventory** — equip it.
3. **Play → START** → countdown → FP combat with skinned tools.
4. Kill dummies for score + Credits; win at 5 kills → end overlay.

### Controls

| Input | Action |
|--------|--------|
| Hub tabs | Play / Shop / Inventory / Settings |
| START | Begin OITC match |
| Hold LMB | Fire or melee when empty |
| R | Disabled in OITC |
| Door prompt | Open away from you / close |

## Config knobs

See `Config.Economy`, `Config.ShopItems`, `Config.Lighting.Post`, `Config.OITC`, `Config.Match`, `Config.Feel`, `Config.Remotes`.

## Design notes

- **Full-screen hub** blocks the world; match HUD uses the same Theme.
- **Server authority** for purchases, equip, credits, combat.
- **DataStore** with memory fallback — Studio playtests always work.
- Tools stay first-person friendly scale; muzzle part named `Muzzle` for FX.

## License

Use freely for learning, jams, and prototypes.
