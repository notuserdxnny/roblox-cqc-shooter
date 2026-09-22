# Roblox CQC Shooter — One in the Chamber

Short-range **first-person** room shooter for **Roblox Studio** / **Rojo**.

**Game is One in the Chamber (OITC) only for now.** You begin in a dedicated **Lobby** with a full-screen **hub** (**Play | Shop | Inventory | Settings**). Press **START** for a punchy **3…2…1…GO!** announcer countdown, then fight in a **themed 3×3 room grid** with doors, half-walls, crawl gaps, and **4 combat bots** that path, shoot, and melee. Quiet match music + win sting. Server-authoritative combat, **Credits** economy, cosmetic shop (Part-based pistol/knife skins), and polished gun feel.

No free Robux, no exploits, no aimbot — just a clean Luau starter.

## Hub tabs

| Tab | Contents |
|-----|----------|
| **Play** | OITC title, rules card, **START**, expandable how-to |
| **Shop** | Browse cosmetics; buy with **Credits** (server-authoritative) |
| **Inventory** | Owned items; **Equip** pistol/knife skin, trail, hitmarker, title |
| **Settings** | Stub (points to Roblox Esc for audio/graphics) |

Hub is a **true full-bleed game menu** (not a floating centered modal):

- Root `Frame` **Size (1,0,1,0)**, **fully opaque** dark background, `IgnoreGuiInset`, high `DisplayOrder` — **zero world visibility** behind the hub
- **Left sidebar** (~248px): logo/title, nav **PLAY / SHOP / INVENTORY / SETTINGS**, credits badge at bottom
- **Main content** fills remaining width/height with ~40px padding (hero + wide rules + bottom START bar on Play; scrolling **card grids** on Shop/Inventory)
- Camera set to **Scriptable** fixed above the map while hub is open (belt-and-suspenders with opaque UI)
- Shared `Theme` tokens (sidebar width, content pad, card size, gradients, hover/selected states)

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

## Combat bots

Passive Training Dummies are **replaced** by fighting bots (`NPCService`):

| Behavior | Detail |
|----------|--------|
| Count | **4** (`Config.NPC.Count`) |
| Movement | Pathfind / MoveTo between room centers, cover, and `BotWaypoints` |
| Target | Live match only: `CQCInMatch` and **not** countdown / hub / match-over |
| Gun | Server raycast pistol, **OITC one-shot**, max **~36** studs, **LOS required** (walls/doors block) |
| Melee | Within `MeleeRange` (~7) **and** clear LOS (no through-wall knife) |
| Ammo refill | On bot kill of player (`RefillAmmoOnKill`), or after `EmptyAmmoRegenSeconds` |
| Player kill of bot | Same as player kill: **+1 OITC ammo**, score, Credits, kill feed |
| Spawn | Floor-snapped marks; avoids spawning on top of players |
| Respawn | After `RespawnDelay` (default 5s) |

Tune in `Config.NPC`.

## Recent bugfixes

- **Unexplained deaths:** Bots no longer damage during countdown/hub; gun + melee require raycast LOS; engagement range capped for CQC; safer spawn/teleport heights; void rescue + under-map safety slab; kill feed shows **“BotName killed you”** when you die.
- **Shoot freezes look:** While InMatch, client continuously re-asserts `MouseBehavior = LockCenter` (RenderStepped + InputEnded). Tools use `ManualActivationOnly` so Tool clicks do not unlock the mouse. Recoil remains camera-CFrame-only.
- **Door prompt unlocks mouse:** Doors no longer use `ProximityPrompt` (its GUI stole LockCenter). Non-Active `[E] Open/Close` BillboardGui + client E / ButtonX → `ToggleDoor` remote; server still picks open direction.

## Map art (room themes)

Each of the 9 combat rooms has a distinct theme (floor material/color, wall tint, neon trim, ceiling lamps, floor pattern):

Briefing · Lockers · Server · Armory · Ops · MedBay · Storage · Range · Vault

Lobby gets a nicer desk, accent neon, and weapon display stands. **Gameplay geometry** (doors, half-walls, crawl gaps, spawn pads) is unchanged.

## Round music / announcer

Documented in `Config.SoundIds` / `Config.SoundVolumes` / `Config.Match`:

| Key | Asset ID | Use |
|-----|----------|-----|
| `CountdownTick` / `Countdown3`–`1` | `rbxassetid://9113895097` | Punchy 3-2-1 beeps (pitch rises toward GO) |
| `CountdownGo` / `RoundStart` | `rbxassetid://9113824583` | GO! stinger |
| `MatchLoop` | `rbxassetid://1848354536` | Quiet looping bed while in match |
| `WinSting` | `rbxassetid://5852410825` | Victory sting on match end |

Wired in `Hub.client.lua`: countdown beeps → GO sting → match loop on `MatchStarted` → stop loop + win sting on `MatchEnded` / return to hub.

> Replace any ID with your own uploaded audio if a catalog asset is moderated or unavailable.

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
        NPCService.lua       # combat bots (path / shoot / melee)
        DoorService.lua
    Client/
      Hub.client.lua      # full-bleed sidebar hub + countdown/end
      HUD.client.lua      # strip HUD, kill feed, vignette
      WeaponController.client.lua
      FirstPerson.client.lua
      DoorInput.client.lua  # E-key door toggle (no ProximityPrompt)
```

## Setup with Rojo

```bash
cd roblox-cqc-shooter
rojo serve
```

Studio: new Baseplate → Rojo Connect → **Play**.

## How to playtest

1. Spawn in **Lobby** — full-bleed hub menu (opaque UI; 3D world not visible).
2. **Shop** — buy a skin with starting Credits; **Inventory** — equip it.
3. **Play → START** → countdown → FP combat with skinned tools.
4. Fight **bots** (and other players) for score + Credits; win at 5 kills → win sting + end overlay.

### Controls

| Input | Action |
|--------|--------|
| Hub tabs | Play / Shop / Inventory / Settings |
| START | Begin OITC match |
| Hold LMB | Fire or melee when empty |
| R | Disabled in OITC |
| E (near door) | Open away from you / close |

## Config knobs

See `Config.Economy`, `Config.ShopItems`, `Config.Lighting.Post`, `Config.OITC`, `Config.Match`, `Config.NPC` (bots), `Config.SoundIds` (countdown/music), `Config.Feel`, `Config.Remotes`.

## Design notes

- **Full-bleed hub** (sidebar + main) fully occludes the lobby; match HUD uses the same Theme.
- **Server authority** for purchases, equip, credits, combat.
- **DataStore** with memory fallback — Studio playtests always work.
- Tools stay first-person friendly scale; muzzle part named `Muzzle` for FX.

## License

Use freely for learning, jams, and prototypes.
