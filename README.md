# Robot Factory Tycoon

A Roblox tycoon written in Luau and synced into Studio with [Rojo](https://rojo.space).
Players claim a factory plot, buy droppers, conveyors and machines that turn scrap into
robots, hire those robots as workers, and rebirth for permanent multipliers.

## Build progress

| Step | Feature | Status |
|---|---|---|
| 1 | Plots and data saving (session-locked DataStore) | ✅ Done |
| 2 | Buy buttons and unlocking | ✅ Done |
| 3 | Droppers, conveyors, collector | ⏳ Next |
| 4 | Machines that upgrade value | |
| 5 | Rebirths and leaderboard | |
| 6 | Robot workers | |
| 7 | Monetization (game passes, dev products, ProcessReceipt) | |
| 8 | UI polish | |
| 9 | Prototype PvP arena | |

---

## One-time setup

1. **Install Rokit** (the Roblox toolchain manager): https://github.com/rojo-rbx/rokit#installation
2. In this folder, run:
   ```sh
   rokit install
   ```
   This installs the Rojo version pinned in `rokit.toml` (7.4.4).
   *Already use Aftman? Copy the `[tools]` line into `aftman.toml` and run `aftman install`.*
3. **Install the Rojo Studio plugin**:
   ```sh
   rojo plugin install
   ```
   You can also get "Rojo" from the Creator Store inside Studio. Restart Studio afterwards.
4. Recommended: VS Code with the **Luau Language Server** extension (JohnnyMorganz.luau-lsp).

## Syncing with Rojo

1. Open Studio and create a new place from the **Baseplate** template.
2. **Publish it** (File → Publish to Roblox). DataStores only work in published places.
3. Turn on **Game Settings → Security → Enable Studio Access to API Services**.
   Without it the game still runs, but it uses an in-memory store and nothing persists
   between play tests. The Output window warns you when that happens.
4. In a terminal in this folder:
   ```sh
   rojo serve
   ```
5. In Studio: **Plugins → Rojo → Connect**. The code appears in:
   - `ReplicatedStorage.Shared`: configs and utilities (both sides)
   - `ServerScriptService.Server`: server services
   - `StarterPlayer.StarterPlayerScripts.Client`: client controllers
6. Edit files in your editor and Rojo pushes the changes into Studio live.
   **Stop the play test before saving files.** Rojo syncs into edit mode, not into a running test.
7. Save the place (Ctrl+S) now and then, so Studio-only settings like the published
   place and API access are kept.

If you'd rather not run a live server, `rojo build -o RobotFactoryTycoon.rbxlx` builds a place file you can open directly.

## Project layout

```
default.project.json         Rojo mapping: folders -> Roblox services
rokit.toml                   Pinned Rojo version
src/
  shared/                    -> ReplicatedStorage.Shared
    Config/                  ALL tunable data lives here (prices, plots, saves...)
      PlotConfig.luau        Plot count, size, layout, colors
      ItemConfig.luau        Every buy button: price, unlock order, position, looks
      DataConfig.luau        DataStore name, autosave, lock timing, new-player template
    Util/
      Signal.luau            Tiny event class for services
      Format.luau            1234 -> "1.23K"
  server/                    -> ServerScriptService.Server
    Main.server.luau         Boots services (Init, then Start)
    Services/
      DataService.luau       Session-locked load/save, autosave, BindToClose
      PlotService.luau       Generates the 6 plots, claim/release, teleport
      EconomyService.luau    The ONLY place cash changes (server-authoritative)
      PlayerService.luau     Join/leave order: data -> plot -> leaderstats -> ready
      TycoonService.luau     Buy buttons, purchases, rebuilding owned items on join
    Tycoon/
      ItemBuilder.luau       Builds an item from config parts or a custom model
    Dev/
      DevCommands.luau       Studio-only chat commands for testing
  client/                    -> StarterPlayerScripts.Client
    Main.client.luau         Starts controllers
    Controllers/
      HudController.luau     Basic cash/plot display
      ButtonController.luau  Tints your buttons green/red by affordability
```

### How data saving works

Each player's DataStore entry looks like `{ Data = {...}, Lock = { JobId, Time } }`.

- **Join:** `UpdateAsync` claims the lock. If another live server holds it (for example,
  you just hopped servers), the load waits and retries. A lock that hasn't been refreshed
  for `LockExpireSeconds` is treated as a dead server and taken over. The final retry
  takes it over regardless.
- **Autosave (every 60s):** saves the data and refreshes the lock.
- **Every save checks the lock first.** If another server owns it now, this server stops
  saving and kicks the player, so stale data can't overwrite newer data.
- **Leave / shutdown:** saves and clears the lock. `BindToClose` waits for every save to finish.
- **New fields:** anything you add to `DataConfig.Template` is filled in automatically for
  existing players the next time they load.
- **Saved now:** `Cash`, `TotalEarned`, `Rebirths`, `Unlocked`, `Workers`, `RobotsBuilt`,
  `Prototypes`, `ProcessedReceipts`. Later steps use these fields.

---

## Testing step 1: plots and data saving

**Studio dev commands** (type in chat; they only exist in Studio):

| Command | Effect |
|---|---|
| `/cash 500` | Add $500 (default is 1000) |
| `/save` | Force a save now |
| `/unlockall` | Unlock every tycoon item for free (step 2+) |
| `/wipe` | Reset your data to a new player's and kick you |
| `/help` | List the commands |

### Checklist

1. **Plots appear.** Press **Play**. Six plots with colored neon borders sit in two rows of
   three, facing a central aisle. Each has a gate reading "Unclaimed Factory".
2. **You claim a plot.** Your gate changes to "*YourName*'s Robot Factory" and you're
   teleported onto your plot. Output shows `[PlayerService] <name> loaded into plot 1`.
   The bottom-left HUD shows "Your factory: Plot 1" and `$0`.
3. **Cash is server-side.** Type `/cash 2500`. The HUD and the player-list `Cash` column
   both show `$2.5K`.
4. **Data persists.** Press **Stop**, then **Play** again. Your cash is still 2500.
   (If you see the "DataStores unavailable" warning, re-check setup steps 2 and 3.)
5. **Respawn returns you home.** Reset your character (Esc → Reset). You respawn on your plot.
6. **Multiple players get separate plots.** Go to **Test → Clients and Servers**, choose
   3 players, and click **Start**. Each player gets a different plot and gate name. Close
   one client: that plot goes back to "Unclaimed Factory".
7. **Wipe works.** `/wipe` kicks you. Press Play again and you're back at $0.

### Notes

- Set the server size to **6** (Creator Dashboard → your experience → Places → Server Size)
  so a server never has more players than plots. A 7th player would be kicked with a
  friendly message.
- `DataConfig.ForceMockInStudio = true` makes Studio tests start fresh every time without
  touching real saves.
- Changing `DataConfig.StoreName` (for example, `_v1` → `_v2`) starts every player over.
- Session locking can't be tested in Studio, because it needs two live servers. The logic
  was unit-tested outside Roblox with a simulated shared DataStore covering takeover,
  stale-server kick, release and reconcile.

---

## Updating your local copy

Each step is pushed to GitHub. If you downloaded the ZIP:

1. In the Terminal window running `rojo serve`, press **Ctrl+C** to stop it.
2. Move the old project folder to the Trash.
3. Download the new ZIP:
   https://github.com/carlosposada0801-blip/Roblox-game/archive/refs/heads/claude/inspiring-hypatia-06fx4v.zip
   and unzip it in the same place.
4. `cd` into the new folder and run `rojo serve` again.
5. In Studio: **Plugins → Rojo → Connect** again.

---

## Testing step 2: buy buttons and unlocking

### Adding or changing items

Open `src/shared/Config/ItemConfig.luau`. Each entry is one buy button:

```lua
{
	Id = "Dropper2",                 -- save key: never rename once players own it
	DisplayName = "Scrap Dropper II",
	Category = "Dropper",
	Price = 75,
	Requires = { "Dropper1" },       -- button appears once these are owned
	Button = Vector3.new(-34, 0, -8), -- where the button sits on the plot
	Parts = dropper(-34, Color3.fromRGB(150, 110, 70)),
},
```

Prices, order and positions are data only. TycoonService never needs editing to add
an item. On startup the server warns in Output about duplicate Ids, unknown
`Requires`, items that can never unlock, and buttons sharing a spot.

**Custom models:** build a Model in Studio, name it after the item's `Id`, and put it in
`ServerStorage > TycoonItems` (create that folder). It's used instead of `Parts`.
Its pivot is placed at the plot center unless the entry sets `Pivot = CFrame.new(...)`.

### Checklist

1. **Starter button.** Press Play. One green **Conveyor Belt — FREE** button sits on your plot.
2. **Free starter chain.** Step on it: the conveyor belt appears and a **Collector — FREE**
   button appears at the right end. Buy it, and a free **Scrap Dropper** appears. Buy that too.
3. **Price and color.** The next button, **Scrap Dropper II**, costs $75. With $0 it is
   **red**. Stepping on it flashes it and nothing is bought.
4. **Buying with cash.** Type `/cash 100`. The button turns **green**. Step on it: $75 is
   taken and the second dropper appears.
5. **Branching.** After Dropper II, two buttons appear: **Factory Floor** and **Smelter**.
6. **Only the owner can buy.** In Test → Clients and Servers with 2 players, walk Player 2
   onto Player 1's button. Nothing happens.
7. **Rebuild on rejoin.** Stop and Play again (with API access on). Every item you bought is
   rebuilt and the right buttons are showing. Output says
   `[TycoonService] Rebuilt N item(s) for <name>`.
8. **The whole factory.** `/unlockall` builds everything: 4 droppers, belt, 2 motors,
   4 machines (labeled), collector, walls, floors, lamps, and the statue.
9. **Clean slate.** `/wipe` resets you to an empty plot.

Droppers, belts and machines are only visual in this step. They start working in steps 3 and 4.
