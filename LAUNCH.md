# Launch Checklist: Robot Factory Tycoon

Work through this top to bottom before making the game public. Every config file mentioned is
in Studio under **ReplicatedStorage → Shared → Config** (double-click to edit).

---

## 1. Publish and basic settings
- [ ] **File → Publish to Roblox**, then give it a name, for example "Robot Factory Tycoon 🤖".
- [ ] **Game Settings → Security:**
  - Turn on **Enable Studio Access to API Services** (saving).
  - Leave **Allow HTTP Requests** off (the game doesn't need it).
- [ ] **Creator Dashboard → your experience → Places → Server Size = 6**, one player per plot.
- [ ] **Game Settings → Avatar:** R15 is recommended (the sword swing uses the default animations).

## 2. Store items (real money)
Create these at **Creator Dashboard → your experience → Monetization** and paste each ID into
`MonetizationConfig`, replacing the `0`s.

| Type | Name | Suggested price |
|---|---|---|
| Game pass | 2x Cash | R$ 199 |
| Game pass | Auto-Collect | R$ 99 |
| Game pass | Faster Conveyors | R$ 149 |
| Game pass | VIP Floor | R$ 249 |
| Developer product | Starter Pack | R$ 49 |
| Developer product | Cash Pack / Crate / Vault | R$ 25 / 99 / 399 |
| Developer product | Instant Upgrade | R$ 49 |
| Developer product | Prototype Robot | R$ 299 |

- [ ] Upload an icon for each one (a screenshot of the item works fine).
- [ ] Test-buy each one in Studio. Studio purchases are free test purchases once the real IDs are in.

## 3. Badges
- [ ] **Creator Dashboard → your experience → Associated Items → Badges.** Create a badge for the
  achievements you want, such as "First Robot", "Millionaire", "Boss Slayer" and "Ascended".
- [ ] Paste each badge ID into `AchievementConfig` (`BadgeId = 0` → your ID). Achievements
  without a badge ID still work in-game; they just don't award a Roblox badge.

## 4. Earning money (no setup needed)
- **Premium Payouts:** Roblox automatically pays you based on how long Premium members play.
  The game gives Premium players +10% cash (`MonetizationConfig.PremiumBonus`) and shows a
  "Get Premium" card in the shop, which helps.
- **Private servers:** Creator Dashboard → your experience → **Places → Private Servers** →
  turn on and set a price, such as R$ 100/month. Players can then rent a server for friends.

## 5. Admin access
- [ ] You (the game's creator) can always use the chat commands (`/cash`, `/balance`, `/boss`...)
  in your live game. To give helpers access, add their UserIds to `AdminConfig.Admins`.
- [ ] Never share admin with people you don't trust: `/cash` can give unlimited money.

## 6. Store page
- [ ] **Icon** (512×512): a robot with a "$" over a factory, bright colors, big and simple.
- [ ] **Thumbnails** (1920×1080), 3 to 5 of them:
  1. Your full factory at night with the neon glowing.
  2. The boss raid.
  3. The PvP arena.
  4. The pets menu.
  5. Robot races.
- [ ] **Description:**
  > 🤖 Build the ultimate ROBOT FACTORY! Drop scrap, smelt it, assemble robots and sell them for cash.
  > ⚡ Events • 🛸 Pets • ⚔️ Weapons & PvP • ☠️ Boss raids • 🏁 Robot races • ⛏️ Mining • 🛡️ Crews
  > 🔄 Rebirth and ✨ Ascend for huge multipliers! New updates every week!
- [ ] **Genre:** Simulator / Tycoon. Fill in the **Maturity & Compliance** questionnaire honestly
  (the game has cartoon combat).

## 7. Test before going public
- [ ] **Phone:** in Studio, **Test → Device** emulator, try an iPhone and an Android tablet. Check that
  menus fit and buttons are tappable, then do a real test on your own phone.
- [ ] **Multiplayer:** Test → Clients and Servers with 3 players. Check trading, co-op, PvP,
  the arena and the boss raid.
- [ ] **Saving:** play, leave, rejoin (in a real server, not Studio) and check everything is still there.
- [ ] **Balance:** type `/balance` in chat to see how long each purchase takes. The first
  rebirth should come after about 20 minutes.
- [ ] Ask 2 or 3 friends to play for 15 minutes without help. Watch where they get stuck.

## 8. Go live
- [ ] Creator Dashboard → your experience → **Public**.
- [ ] Optional: run a small **Sponsored Experience** ad (a few hundred Robux) on day one to get
  the first players in.
- [ ] Check the **Analytics** tab daily for the first week, especially **Day 1 retention**
  and **average session length**.

## 9. After launch
- Seasonal events turn on by themselves (🎃 October, ❄️ December–January).
- Use `/balance` after changing any prices.
- Read the Output/Developer Console (F9 in game) for errors when players report bugs.
