# Robot Factory Tycoon

A Roblox tycoon written in Luau. Claim a factory plot, buy droppers, conveyors and machines
that turn scrap into robots, hire those robots as workers, rebirth for permanent multipliers,
and take your rare Prototype robots into a shared PvP arena.

| Step | Feature | Status |
|---|---|---|
| 1 | Plots and session-locked data saving | ✅ |
| 2 | Buy buttons and unlocking | ✅ |
| 3 | Droppers, conveyors, collector, cash pad | ✅ |
| 4 | Machines that upgrade value (Smelter, Assembler, Painter, Final Assembly) | ✅ |
| 5 | Rebirths, leaderstats, global Top Rebirths board | ✅ |
| 6 | Robot workers | ✅ |
| 7 | Game passes, developer products, safe ProcessReceipt | ✅ |
| 8 | UI: HUD, rebirth confirm, workers menu, shop, notifications | ✅ |
| 9 | Prototype robots and PvP arena | ✅ |

---

> **Going live?** Follow [LAUNCH.md](LAUNCH.md): store items, badges, server size, thumbnails, testing.

## Opening the game

**Easiest:** open `RobotFactoryTycoon.rbxlx` in Roblox Studio and press **Play**.

**To make saving work:**
1. File → Publish to Roblox.
2. Home → Game Settings → Security → turn on **Enable Studio Access to API Services**.

Until then the game runs with an in-memory save, and the Output window warns about it.

**Before going live:**
- Set **Server Size = 6** (Creator Dashboard → your experience → Places), so there's one
  plot per player.
- Create the game passes and developer products and paste their IDs into
  `ReplicatedStorage > Shared > Config > MonetizationConfig` (see Monetization below).

### Optional: live-sync with Rojo
If you edit code in VS Code instead of Studio: `rokit install`, `rojo plugin install`, `rojo serve`,
then Studio → Plugins → Rojo → Connect. `rojo build -o RobotFactoryTycoon.rbxlx` rebuilds the place file.

---

## How the game plays

1. **Join.** You're given one of 6 plots and teleported onto it. Your name appears on its gate.
2. **Build.** Step on green buy buttons. A button turns red when you can't afford it.
   Free starter set: Conveyor Belt → Collector → Scrap Dropper.
3. **Produce.** Droppers drop **Scrap** onto the belt, and machines upgrade it as it passes:
   - **Smelter:** Scrap → Metal (x2)
   - **Assembler:** Metal → Robot Part (x2.5)
   - **Painter:** random color (x1.5)
   - **Final Assembly:** every 3 Robot Parts → 1 **Robot** (sum x2)
4. **Earn.** The collector sells items into the **cash pad** in front of it. Step on the pad to
   collect, or buy the Auto-Collect pass.
5. **Workers.** Each robot sold adds +1 to your robot count. Spend robots in the **Workers** menu
   on bots that speed up droppers or boost machine value. Hired bots appear on your plot.
6. **Prototypes.** Each robot has a 1% chance to be a glowing ★ PROTOTYPE ★ worth 10x. Collecting
   one adds a Prototype to your account.
7. **Rebirth.** The **Rebirth** menu resets your cash and items for a permanent cash multiplier
   (+0.5x per rebirth). You keep workers, robots, Prototypes and passes. Rebirths show in the
   player list and on the **Top Rebirths** board in the lobby.
8. **Arena.** The purple portal in the lobby leads to the floating PvP arena. Everyone gets a
   Robo Sword. If you own a Prototype, **Deploy** it: it follows you and zaps enemies.
   Kills pay cash. Leave through the blue portal or the Leave button.

---

## v2.0: more to do

| Feature | How it works | Config |
|---|---|---|
| 🎁 Daily rewards | Popup on join, 7-day UTC streak: cash on days 1–6, a guaranteed rare Prototype on day 7; missing a day resets it | `DailyConfig` |
| ⚡ Factory events | Every 10–20 min: Power Surge (3x speed, 30 s), Golden Rain (10x parts, 20 s), Malfunction (click the sparking machine to fix it), Cash Frenzy, Robot Parade. Banner, siren and countdown | `EventConfig` |
| 📋 Daily quests | 3 per day ("Build 50 robots", "Collect cash 20 times", "Win 1 robot battle"...) with progress bars; rewards are cash, robots or short boosts | `QuestConfig` |
| ⬆️ Upgrades | Walk up to a dropper or machine and press **E** to level it up (max Lv 5). Resets on rebirth | `UpgradeConfig` |
| 🎲 Robot rarities | Every robot rolls Common → Legendary (x1 to x10 value), with glow, sparkles and a name tag | `RarityConfig` |
| 📖 Collection book | 40 robot types (rarity × paint color). Each one you sell = +1% cash forever | `RarityConfig` |
| 🛸 Pets | Hatch drone pets from Scrap/Neon eggs; equip 3; each boosts cash; they follow you | `PetConfig` |
| 🏆 Leaderboards | Top Rebirths, Richest, Most Robots, Arena Champions boards in the lobby | `LeaderboardConfig` |
| 👥 Visit and like | Players menu → Visit any factory; press **F** at a gate to like it; most-liked factory gets a 👑 crown | — |
| ⚔️ Arena rounds | 3-minute rounds: knockouts and holding the center hill score points; winner gets a trophy and cash | `ArenaConfig.Rounds` |
| 🏗️ 2nd floor | After **2 rebirths**: a second floor with a ramp, Quantum Droppers, Laser Cutter and AI Core | `ItemConfig` (`MinRebirths`) |
| 🤝 Trading | Players menu → Trade: swap robots and Prototypes. Both press Ready, then a 5 s countdown; any change cancels | `TradeConfig` |
| 🏢 3rd floor | After **5 rebirths**: lift pads from the 2nd floor, Plasma Droppers, Fusion Reactor and Mega Assembler | `ItemConfig` |
| ⚔️ Weapons and PvP | Unlock weapons in the **Armory**: Robo Sword, Laser Blaster, Plasma Hammer, Shock Rifle, Rocket Launcher, and the Prototype Cannon (free with a Prototype). They work in the arena, or anywhere when both players switch **PvP on**. Hits are checked by the server | `WeaponConfig` |
| 🌌 Galaxy Egg | A third, pricier egg ($2.5M) with the Mythic **Quasar** pet (+350% cash) | `PetConfig` |
| ☠️ Boss raids | Every hour, after a 60 s countdown, the Omega Destroyer lands in the lobby; health scales with players; damage share = loot, plus a rare exclusive boss skin | `BossConfig` |
| 🚨 Factory defense | Rogue drones raid cash pads and drain cash until you click/shoot them | `DefenseConfig` |
| 🏁 Robot races | Enter your race bot, upgrade it with robots, prizes for the top 3; watch at the 🏁 portal | `RaceConfig` |
| 📜 Contracts | Timed jobs with big rewards | `ContractConfig` |
| ⛏️ Crystal mine | Mine ore (portal in the lobby), sell it or craft Machine Cores (+10% machine value each) | `MiningConfig` |
| ✨ Ascension | At 10 rebirths: reset for x2 cash forever and a new factory theme (Space Station, Underwater Lab, Volcano Forge) | `AscensionConfig` |
| 🏅 Achievements and badges | 22 achievements, Roblox badges and titles shown overhead and in chat | `AchievementConfig` |
| 🌠 Style | Trails and factory accent colors (cash or achievements) | `CosmeticConfig` |
| 🤝 Co-op | Invite friends to build your factory with you (Players menu → BUILD) | — |
| 🛡️ Crews | Cross-server clans with a bank, levels (+5% cash each) and a Top Crews board | `CrewConfig` |
| 🎃 Seasons | Auto Halloween / Winter events with decorations and a limited egg | `SeasonConfig` |
| 🎓 Tutorial | Step-by-step guide for new players with a reward | `TutorialConfig` |
| ⭐ Premium and Starter Pack | +10% cash for Roblox Premium; one-time Starter Pack product | `MonetizationConfig` |
| 📊 Balance tool | `/balance` prints how long every purchase takes (admins/Studio) | `BalanceModel` |
| 🎨 Look and feel | Hazard-striped plots, industrial gates with spinning gears, machine fire/sparks/paint effects, moving belt arrows, factory skyline with smokestacks, robot mascots, hologram title, sci-fi UI, confetti, screen flash on rebirth | `SceneryConfig`, `ItemConfig` |

## v2.3: the big update

| Feature | How it works | Config |
|---|---|---|
| 🥊 Robot Battle Arena | Queue your Prototype (More → Battle, or the terminal at the end of the lobby). 1v1 stat fights with lunges, crits and health bars; wins/losses saved and ranked on a lobby board; a Training Bot fights you if nobody else queues | `BattleConfig` |
| 📦 Logistics Yard | A grid behind every factory. Place and rotate Conveyors, Speed Conveyors, Splitters, Sorters and Mergers (More → Yard) to route crates to the Seller or the Rare Buyer. Placement is checked on the server | `YardConfig` |
| ☁️ Sky Factory | At 8 rebirths, a blue pad flies you to a floating island with its own machines (Sky Laser Cutter, AI Core Installer, Nano Painter, Quantum Assembler) that build Sky Androids and Titan Mechs. Saved separately, never reset | `SkyConfig`, `ItemConfig` (`World = "Sky"`) |
| 🤖 Collector workers + slots | Collector Bots grab pad cash for you; more worker slots unlock with rebirths; bots walk to their machines | `WorkerConfig` |
| ⏱️ Boosts | 2x Cash, Turbo Droppers, Lucky Line: from quests, codes and the Starter Pack; timers in the HUD | `BoostConfig` |
| 🎟️ Codes | More → Codes. One use per player, optional expiry date | `CodesConfig` |
| 👥 Group reward | Join your group: one-time cash + 10% cash forever. Shop → Join / Check | `GroupConfig` |
| 🎒 Starter Pack popup | Pops up 3 minutes into the first visit and once in the second; never after buying | `MonetizationConfig.StarterOffer` |
| 📅 Weekly board | Cash earned this week, resets Monday 00:00 UTC; top 3 get a title + skin on their next join | `LeaderboardConfig` |
| 👍 Most Liked board | Global board of factory likes (likes also show on every gate) | `LeaderboardConfig` |
| 🎨 Customize | Wall and machine paint, floors, a neon sign with your own text (filtered), and decorations; free, cash and VIP options | `CustomConfig` |
| 🤖 Robot skins | Recolor every robot you build; exclusive skins from the Starter Pack, bosses, weekly prizes and codes; some are tradable | `CosmeticConfig.Skins` |
| 🤝 Trading v2 | Trade tradable skins too; both sides saved instantly; every trade logged | `TradeConfig` |
| ⚙️ Settings | Music, sound effects, screen shake, guide arrow (saved) | — |
| 🎓 Tutorial v2 | Arrow points at the first 5 buttons, then the cash pad, then Rebirth; Skip button; progress saved | `TutorialConfig` |
| 📱 Mobile | Menu moves to the top-left on phones, windows shrink to fit the screen, bigger close buttons | `UIKit` |

---

## Configuration: everything tunable lives in `src/shared/Config/`

| File | What you change there |
|---|---|
| `ItemConfig.luau` | Every buy button: price, unlock order (`Requires`), position, looks, dropper rates, machine effects |
| `ProductionConfig.luau` | Belt speed, max items per plot, cleanup time, item looks per stage, Prototype chance |
| `RebirthConfig.luau` | Rebirth cost and growth, multiplier per rebirth, leaderboard settings |
| `WorkerConfig.luau` | Worker bots: robot cost, effect, max count (slots) |
| `MonetizationConfig.luau` | Game pass and developer product IDs, names, prices shown, rewards |
| `ArenaConfig.luau` | Arena size and position, sword and Prototype damage, kill reward |
| `PlotConfig.luau` | Number of plots, size, layout, colors, lobby spawn |
| `SoundConfig.luau` | Sound effects (click, purchase, denied, cash, rebirth); swap in your own sound IDs |
| `SceneryConfig.luau` | Sky, lighting, day/night length, terrain/mountains/lakes/trees, walkway speed, music playlist |
| `DataConfig.luau` | DataStore name, autosave, session lock timing, new-player save file |

**Adding a buy button** is one entry in `ItemConfig.Items`. No logic changes:

```lua
{
	Id = "Dropper5",                       -- save key: never rename once players own it
	DisplayName = "Mega Dropper",
	Category = "Dropper",
	Price = 40000,
	Requires = { "FinalAssembly" },        -- button appears once these are owned
	Button = Vector3.new(0, 0, 28),        -- where the button sits on the plot
	Dropper = { Interval = 1, Value = 40 },
	Parts = { ... },                       -- needs a part named "Spout"; or use a custom model (below)
},
```

On startup the server warns in Output about duplicate Ids, unknown `Requires`, items that can
never unlock, and buttons that share a spot.

**Custom models:** build a Model in Studio, name it after the item's `Id`, and put it in
`ServerStorage > TycoonItems`. It's used instead of `Parts`. Keep the special part names:
`Spout` (droppers), `Belt` (conveyors), `Zone` (machines), `Intake` and `CashPad` (collector).

---

## World, sky and music

`SceneryService` builds the world when the server starts, from `SceneryConfig`:
- **Sky:** golden-hour start with a pink and purple Atmosphere haze, clouds, bloom, sun rays
  and color grading. A day/night cycle (16 minutes by default) shows 5,000 stars at night,
  when the street lamps and neon glow. You can add a custom skybox via `Sky.Skybox`.
- **World:** terrain grass, rolling hills, two sandy lakes, a ring of snow-capped mountains,
  160 trees (some pine, cherry-blossom and autumn) and rocks. The plots and lobby stay flat.
  Change `Seed` for a different layout.
- **Speedy walkway:** two lanes down the middle of the lobby aisle. The blue lane goes one way
  and the orange lane goes back, at twice walking speed, with glowing arrows sliding along.
  Speed is `Walkway.Speed`.

### Adding music

Use only audio you're allowed to use: tracks uploaded by **Roblox** in the Creator Store
(licensed for use in Roblox experiences) or audio you uploaded yourself.

1. In Studio: **View → Toolbox**, then open the **Creator Store** tab and choose **Audio**.
2. Search a mood, like `upbeat`, `electronic`, `chill` or `factory`. Check that the creator is
   **Roblox**, and press play to preview.
3. Right-click the track → **Copy Asset ID**.
4. Open `ReplicatedStorage > Shared > Config > SceneryConfig`, find `Music.Tracks`, and add:
   ```lua
   Tracks = {
   	{ Id = 1234567890, Name = "Upbeat Factory" },
   	{ Id = 2345678901, Name = "Chill Robots" },
   },
   ```
5. Press Play. A 🔊 **Music** button appears under the side menu so players can mute.
   Tracks that fail to load are skipped, with a warning in Output.

---

## Monetization

| Game pass | Effect |
|---|---|
| 2x Cash | Collector earnings x2 |
| Auto-Collect | Cash skips the pad and goes straight to you |
| Faster Conveyors | Belts move 50% faster |
| VIP Floor | Golden VIP lounge plus a VIP dropper that drops pre-smelted metal |

| Developer product | Effect |
|---|---|
| Cash Pack / Crate / Vault | $5K / $30K / $200K, times your rebirth multiplier |
| Instant Upgrade | Unlocks your cheapest available item (gives cash if everything is owned) |
| Prototype Robot | +1 Prototype for the arena |

**Going live:** Creator Dashboard → your experience → Monetization → create each pass and
product → paste the IDs into `MonetizationConfig` (replacing the `0`s).

**While an ID is 0**, buying it in Studio simulates the purchase through the real grant code,
so you can test the whole shop now. In a live server it says "isn't on sale yet".

**Why purchases are never lost or doubled (`MonetizationService`):**
- The player isn't in this server, or their data hasn't loaded → `NotProcessedYet`.
  Roblox retries later.
- The `PurchaseId` is already recorded in their save → `PurchaseGranted`, with no second grant.
- Otherwise the reward is granted and the `PurchaseId` recorded in the same save data, then
  saved. `PurchaseGranted` is returned only if that save succeeds. If it fails, Roblox retries,
  and the in-memory record stops a double grant.
- The session lock means no other server can be editing that save at the same time.

---

## Architecture

```
src/shared/  -> ReplicatedStorage.Shared   configs, Remotes list, utilities
src/server/  -> ServerScriptService.Server
  Main.server.luau        boots services: Init in order, then Start
  Services/
    Net                   RemoteEvents + per-player rate limiting + pcall-wrapped handlers
    DataService           session-locked DataStore (UpdateAsync), autosave, BindToClose
    PlotService           builds 6 plots, claim/release, teleport home
    EconomyService        the ONLY place cash/stats change; leaderstats + attributes mirror
    TycoonService         buy buttons, purchases, rebuild on join, reset on rebirth, pass items
    ProductionService     droppers, belts, machines, collector, cash pad, lag limits
    WorkerService         hire/dismiss bots, dropper speed and machine value bonuses
    RebirthService        rebirth requests + OrderedDataStore Top Rebirths board
    MonetizationService   passes, products, ProcessReceipt
    ArenaService          arena, Robo Sword, Prototype companions, kill rewards
    PlayerService         join/leave order: data -> plot -> passes -> leaderstats -> ready
  Tycoon/ItemBuilder      builds items from config parts or custom models
  Util/RateLimiter        token bucket
  Dev/DevCommands         Studio-only chat commands
src/client/  -> StarterPlayerScripts.Client
  Controllers/            HUD, notifications, buy-button tint, menus, arena bar
  UI/UIKit, UI/Panels/    shared look + Rebirth / Workers / Shop windows
```

**Server-authoritative:** the client only sends requests (`RequestRebirth`, `HireWorker`,
`DismissWorker`, `RequestPurchase`, `ArenaAction`). Every request is rate limited and
re-validated on the server. Item values live in server-side records, item parts are owned
by the server, and buy buttons and cash pads are server touch handlers.

**Lag control:** at most 80 items per plot (droppers pause at the cap); Logistics Yard crates
are simulated on a grid (no physics), max 40 per yard and 120 pieces per yard. Every item gets a
90-second Debris lifetime, items that fall off the plot are destroyed, and one 20 Hz
loop handles all plots.

---

## Testing in Studio

**Dev chat commands** (Studio only):

| Command | Effect |
|---|---|
| `/cash 5000` | Add cash |
| `/robots 20` | Add robots for hiring workers |
| `/unlockall` | Buy every item for free |
| `/prototype` | The next robot built is a Prototype |
| `/pass DoubleCash` | Grant a pass (`DoubleCash`, `AutoCollect`, `FasterConveyors`, `VIPFloor`) |
| `/buy SmallCash` | Run a product through the receipt code (`SmallCash`, `MediumCash`, `LargeCash`, `NextUpgrade`, `Prototype`) |
| `/rebirths 2` | Set your rebirths (2 unlocks the 2nd floor, 5 unlocks the 3rd) |
| `/event GoldenRain` | Start an event (`PowerSurge`, `GoldenRain`, `Malfunction`, `CashFrenzy`, `RobotParade`) |
| `/pet Omega` | Get a pet (`Bolt`, `Gear`, `Spark`, `Nova`, `Pulse`, `Omega`, `Celestia`) |
| `/daily` | Make today's daily reward claimable again |
| `/quests` | Finish all of today's quests |
| `/balance 0` | Economy timeline at 0 rebirths |
| `/boss` | Start a boss raid now (`/boss countdown` for the warning first) |
| `/battle` | Start a robot battle now |
| `/boost CashX2 5` | Give a boost (`CashX2`, `Turbo`, `Lucky`) |
| `/offer` | Show the Starter Pack popup |
| `/sky` | Unlock the Sky Factory and fly up |
| `/drones` | Send rogue drones to your factory |
| `/save` | Save now |
| `/wipe` | Reset your save and kick you |

**Checklist:**
1. **Production.** Buy the 3 free buttons. Scrap drops, rides the belt into the collector,
   and the cash pad shows `$`. Step on the pad: cash goes up with a `+$` popup.
2. **Machines.** `/cash 20000`, then buy the Smelter, Assembler, Painter and Final Assembly
   as they appear. Scrap turns into metal ingots, then blue parts, then gets painted, and
   every 3 parts become a robot.
3. **Workers.** `/robots 20` → Workers menu → Hire. Bots appear behind the belt, and droppers
   speed up or values rise.
4. **Rebirth.** `/cash 100000` → Rebirth menu → Rebirth → confirm. The plot resets, the HUD
   shows x1.5 cash, and the Rebirths column goes up.
5. **Shop.** Shop → buy any pass or product. It's simulated in Studio and takes effect
   immediately (try VIP Floor).
6. **Arena.** `/prototype` and wait for a robot (or `/buy Prototype`), then walk into the
   purple portal in the lobby and click Deploy. Test fighting with 2 players:
   Test → Clients and Servers → 2 players.
7. **Saving.** With API access on, stop and play again. Cash, items, workers and rebirths
   all come back.
8. **Lag.** Leave it running a few minutes. The `Drops` folder in each plot stays at 80
   items or fewer.
