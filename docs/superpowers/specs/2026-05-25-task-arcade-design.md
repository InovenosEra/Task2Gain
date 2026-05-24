# Task2Gain — "Task Arcade" Game Layer — Design

**Date:** 2026-05-25
**Status:** Approved concept, pending spec review
**Supersedes/extends:** `2026-05-23-tasktopay-design.md` (the underlying task→points→money engine stays; this adds the game layer and removes XP/levels)

---

## 1. Vision

Turn Task2Gain from a chore-tracker with a HUD into a game the whole family *loves opening*. The existing engine — anyone in the family (kids **and** parents) does tasks, earns points, converts points to real money — stays as the foundation. On top of it we build a **live-service reward game**: doing a single task feeds three satisfying systems at once, so wherever you look there's a reason to do one more task.

**One-line pitch:** *Duolingo-style daily-engagement + a game-show prize hub + competitive seasons, wrapped around real money.*

The three approved pillars and how they interlock:

1. **⚡ Combo Arcade** — earning is gamey: back-to-back tasks build a points multiplier; power hours and a daily power task add bonus windows.
2. **🎰 Prize Machine** — combos, daily goals, and milestones earn *tokens* (a separate thrill currency). The Prize Machine is the headliner hub: spin the wheel, scratch cards, (later) Plinko & vault. Variable payouts, **never a loss**.
3. **🏆 Seasons & Champions** — points earned this season climb a battle-pass-style **reward track** and a **family leaderboard**; at season end a **Champion** is crowned, then it resets so the race stays fresh.

## 2. Goals / Non-goals

**Goals**
- Make *earning* feel instantly rewarding (juice, sound, motion) instead of a number ticking up.
- Give people a reason to return **every day** (daily goal + streak) and a reason to push **this week/month** (season).
- Layer **variable/surprise rewards** that are exciting but **kid-safe** (no losses, no real-money gambling).
- Keep it a **family** experience: parents both *administer* and *play*; cooperation and friendly competition.
- Preserve the real-money economy exactly (points → ₪ at the family's configured rate; family reward shop).

**Non-goals (v1)**
- No companion/pet, no persistent world/map, no narrative campaign (explored and rejected).
- No real-money *purchases* inside the app (no buying spins/coins with cash). Money only flows *out* (earned → cashed out).
- No cross-family/global leaderboards. Competition is within the family only.

## 3. Core principles

- **Money stays the real goal, but it's the destination — not the moment-to-moment hook.** The game makes the *journey* of earning fun.
- **Kid-safe variable rewards.** Every spin/scratch yields something positive. You can never lose points you earned, and you never spend money to play. Surprise rewards are bonuses funded by the family, on top of guaranteed task points.
- **Everyone plays.** Parents have a daily goal, streak, leaderboard rank, tokens, and season progress just like kids. "Admin" is a separate hat.
- **Instant feedback.** Dopamine should not wait on a parent. Tasks can be auto-approved (honor system) for instant rewards; approval-required tasks still give an instant "submitted!" celebration with a pending-reward preview.
- **Nobody is hopelessly behind.** Seasons reset; trailing players get a gentle catch-up nudge.

## 4. The currencies (this is the crux — keep them distinct)

| Currency | Earned by | Spent on | Notes |
|---|---|---|---|
| **Points (balance)** | Completing tasks (× combo/bonus), prize wins | (a) Cash out → money, (b) family reward shop, (c) cosmetics | The spendable value currency. Decreases when spent. |
| **Season Points (SP)** | Automatically, whenever you *earn* points this season | — (not spendable) | Drives the season reward track **and** leaderboard rank. Never decreases mid-season. Resets each season. |
| **Money (₪)** | Converting points (family rate, default 100 pts = ₪1) | Cash-out / CashCash transfer (existing) | Unchanged from today. |
| **Tokens (spins)** | Combos, hitting daily goal, streak milestones, season tiers | Plays at the Prize Machine only | The *thrill* currency. **Cannot be bought** — only earned. Keeps the Prize Machine non-gambling. |
| **Cosmetics** | Bought with points, or won from prize machine / season track | Equipped for flair (avatar frames, app themes, prize-machine skins) | Optional points sink for players who'd rather flex than cash out. |

**Key relationship:** earning 1 point increments **both** `balance` and `seasonPoints`. Spending decrements `balance` only. The leaderboard and reward track read `seasonPoints`, so spending your points (cashing out, buying rewards) never hurts your rank — you're rewarded for *earning*, not *hoarding*.

## 5. Mechanics in detail

### 5.1 Earning & Combos (⚡)
- Each task pays its base points. On top:
- **Daily combo multiplier.** The more tasks you complete in a day, the higher today's multiplier on *subsequent* task points: 1st task ×1.0, after 2 done ×1.2, after 3 ×1.5, after 5 ×2.0 (cap ×2.0 in v1). The multiplier is **locked in at completion time** and applied when the task resolves (instantly if auto-approved, on approval otherwise), so the approval delay doesn't break the math. Multiplier resets at local midnight.
- **Power hour.** A time-boxed "🔥 Double Points!" window. v1: parent-triggered ("surprise the kids now"); v2: optional auto-scheduled random daily hour. All task points ×2 during the window (stacks additively-capped with combo, see Open Questions).
- **Daily power task.** One task each day flagged ⭐ for a bonus (+50%). v1: parent flags a task; v2: system auto-features one.

### 5.2 Daily goal & streak
- **Daily goal:** a per-person daily points target (parent-set per member, or a sensible default like 50). Shown on Home as a **progress ring** that fills as you earn. Filling it triggers a celebration, awards **1 token**, and **keeps your streak alive**.
- **Streak 🔥:** consecutive days the daily goal was met. Prominent flame + count. Streak milestones (3, 7, 14, 30 days) award bonus tokens and a badge. Missing a day resets to 0 (v2: optional "streak freeze" earned occasionally). Reuses the existing `users.streak` field.

### 5.3 Tokens & the Prize Machine (🎰)
- **Tokens** accumulate from: completing a combo tier, hitting the daily goal, streak milestones, and season-tier rewards.
- **The Prize Machine** is a dedicated, bright hub screen. v1 games:
  - **Spin the Wheel** — segments: bonus points (small→jackpot), extra tokens, a point multiplier for your next task, a cosmetic, and a rare jackpot.
  - **Scratch Card** — 3 panels; match/reveal prizes.
  - v2+: **Plinko**, **Mystery Vault/Chest**.
- **No-loss rule:** every outcome is positive; the smallest wheel segment is still e.g. `+5 pts`. Payout weights are config-driven (so rares stay rare).
- **Jackpot:** parents may optionally fund a real-reward jackpot (rare segment) for extra excitement.
- Every play writes to a `prizeWins` log (audit + replayable animation + "recent wins" feed).

### 5.4 Seasons & Champions (🏆)
- A **season** runs for a family-configured duration (default ~30 days).
- **Season Reward Track (battle-pass style):** tiers at SP thresholds (e.g., every 100 SP). Each tier unlocks a reward: bonus points, tokens, a cosmetic; **milestone tiers** can unlock a parent-set real reward. Players *claim* tier rewards (claim animation).
- **Season Leaderboard:** ranks all family members by SP this season. Live, with podium for top 3. Parents are ranked too.
- **Champion:** at season end, #1 gets a trophy, a champion title/badge (persists across seasons), and an optional parent-set **grand prize**. Then SP resets to 0, a new season begins; balance/money/cosmetics/streak persist.
- **Catch-up:** trailing members get a small SP bonus on tasks in the final stretch (configurable; v2).

### 5.5 The approval gate vs. instant feedback
- Each task has an **approval mode** set by its creator:
  - **Auto (honor system):** completing the task instantly credits points/tokens with full celebration. Best for low-stakes/young kids.
  - **Approval-required:** completing shows an instant "✅ Submitted!" animation and a *pending* reward chip (`+50 pts pending`); points/tokens/combo land — with celebration — when a parent approves. A notification nudges the approver.
- Default: photo-proof or high-value tasks → approval-required; everything else → auto. Parent can override per task.

## 6. The parent / admin role
Parents wear two hats:
- **Player** (same as kids): own daily goal, streak, tokens, Prize Machine, leaderboard rank, season track.
- **Admin** (gated, separate UI — today's "ניהול" tab): create/edit tasks (family-wide or, v2, assigned to specific members); approve submissions; manage the reward shop; set conversion rate, daily goals, and season length; set season/champion/jackpot prizes; trigger power hours; manage members.

## 7. Data model (Firestore)

**Changed**
- `users/{uid}`: **remove** `xp`, `level`, `xpToNextLevel`. **Keep** `streak`. **Add** `dailyGoal` (int), `equippedCosmetics` (map).
- `wallets/{uid}`: keep `points`, `moneyILS`, `lifetimeEarned`. **Add** `tokens` (int), `cosmeticsOwned` (list).
- `quests/{id}`: **remove** `xpReward`. **Add** `approvalMode` (`auto`|`required`), `bonus` (e.g. power-task flag/multiplier), optional `assignedTo` (uid|null).
- `questInstances/{id}`: **remove** `xpReward`. **Add** `comboMultiplier` (num), `tokensAwarded` (int), `pointsAwarded` already exists.
- `badge.dart` / badges: **remove** level-based badges (`level_5`, `level_10`) and `BadgeMetrics.level`; **add** points/season/streak-based badges (e.g. `streak_7`, `season_gold`, `champion`).
- `families/{id}.settings`: keep `pointToShekelRate`, `minPointsToConvert`. **Add** `seasonLengthDays`, `dailyGoalDefault`, `currentSeasonId`, `seasonEndsAt`.

**New**
- `families/{id}/seasons/{seasonId}`: `index`, `startsAt`, `endsAt`, `status` (`active`|`closed`), `championUid?`, `grandPrize?`.
- `families/{id}/seasons/{seasonId}/standings/{uid}`: `seasonPoints`, `tasksCompleted`, `tiersClaimed` (list). Powers leaderboard + track. (Increment alongside wallet on every earn.)
- `prizeWins/{id}`: `userId`, `familyId`, `game` (`wheel`|`scratch`|…), `reward` (type+value), `seasonId`, `createdAt`. Audit + feed.
- `seasonRewardTracks` (config, per family or global default): tier thresholds → reward definitions.

**Migration:** existing `users` docs keep orphaned `xp/level/xpToNextLevel` (harmless; new code ignores them). A one-time script can `seasonPoints = lifetimeEarned.points` seed the first season, or just start everyone at 0.

## 8. Screens

- **Home ("משימות" / Task Arcade dashboard) — redesigned.** Top: daily-goal **progress ring** + **streak flame** + today's **combo multiplier**; a compact **season strip** ("Tier 4 · 40 pts to next · #2 this season"); a **Prize Machine** entry showing tokens available; then the task list (with combo/bonus/pending states and juicy completion). Replaces today's level badge + XP bar.
- **Prize Machine (new):** the games hub (wheel, scratch), token balance, recent wins.
- **Season (new or merged into "משפחה"):** the reward track (claimable tiers) + the leaderboard/podium + season countdown + champion history.
- **Wallet / Cash-out:** points balance, money, convert (unchanged logic), tokens shown.
- **Reward shop ("חנות"):** unchanged purpose; gains cosmetics alongside parent rewards.
- **Admin ("ניהול"):** existing + season config, prize/jackpot config, power-hour trigger, approval-mode on task form.

## 9. Removing XP / levels (explicit)
Delete: `widgets/level_up_overlay.dart`, `widgets/level_change_listener.dart`, `_LevelBadge` & `_XpBar` in `home_tab.dart`, XP/level reads in `profile_tab.dart` and `family_tab.dart`, XP chips/labels in `quest_detail_screen.dart`, `approvals_screen.dart`, `admin_screen.dart`, `home_tab.dart`. Remove `_xpForDifficulty` and `xpReward` writes in `quest_service.dart`; remove the level-up loop and xp/level writes in `quest_instance_service.dart` (keep points + streak + badges). Remove xp/level init in `auth_service.dart`. Leaderboard sort changes from (level, xp) to **seasonPoints**. The integration harness's home assertions still hold (`משימות פתוחות`).

## 10. Phasing (ship value early)

- **Phase 1 — Feel + Prizes + Daily loop.** Remove XP/levels. Add instant feedback + auto-approve option + coin/celebration juice. Daily-goal ring + streak. Tokens + Prize Machine (Wheel + Scratch, no-loss). *This alone transforms the app.*
- **Phase 2 — Combos + Power.** Daily combo multiplier, parent-triggered power hour, daily power task.
- **Phase 3 — Seasons.** Season points + standings, reward track (claim), leaderboard revamp, champion + reset, cosmetics catalog.
- **Phase 4 — Depth.** Plinko/vault, auto power hours, per-member task assignment, streak freezes, catch-up, champion history.

## 11. Testing
- **Unit:** economy transactions — points & SP increment together; spending touches balance only; combo math; **prize no-loss invariant** (every outcome > 0); token earn/spend; season reset.
- **Integration:** extend the existing `integration_test` harness to cover the new Home, Prize Machine, and Season screens render and that a spin yields a positive reward.
- **Manual:** the juice (animations/sound) verified on-device.

## 12. Open questions / risks
- **Combo × power-hour stacking:** additive then capped (×2.0) or multiplicative (could spike)? Leaning capped-additive for predictability. (Decide in Phase 2.)
- **Leaderboard fairness:** parents vs a 5-year-old on the same board. Options: handicap, kid-only board, or accept it (parents may do fewer tasks). Flag for decision in Phase 3.
- **Variable reward + real money for kids — ethics.** Mitigated by no-loss, parent-funded, full transparency, no cash purchases. Worth a deliberate stance documented in-app for parents.
- **Season prize funding** depends on parent follow-through (same trust model as today's reward shop / cash-out).
- **Notifications** (approval nudges, power-hour alerts, "your streak is at risk") — valuable but require push setup; scope per phase.
