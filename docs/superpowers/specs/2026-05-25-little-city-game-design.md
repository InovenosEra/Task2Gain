# Little City — Design Spec

**Date:** 2026-05-25
**Status:** Approved for planning
**Supersedes:** the "Task Arcade" direction (a chores app with mini-games). This spec inverts that: a **game** with chores inside it.

---

## 1. Vision

A worldwide, all-ages **isometric city-builder** (Clash-of-Clans-style art). Players spend **tokens** to grow their city. They earn tokens by completing **real-world chores**. They win their **parent's real prizes** by reaching **city milestones**.

The game is the destination; chores are the fuel that keeps it running. This is the opposite of the current app, where tasks were the point and games were decoration.

**One-line product:** *Do chores to earn tokens → spend tokens building your city → earn XP from playing → cash XP out for real prizes or money.*

**Two currencies:**
- **Tokens** — the *spendable* play-fuel. You spend them to build/play. Earned by doing chores (and, at a poor rate, by converting XP back).
- **XP** — the *accumulating* winnings. Earned by playing/building. Convertible into tokens (lossy/capped), prizes, or money. The city itself grows **permanently** and is never consumed by cashing out XP.

---

## 2. Goals & Non-Goals

**Goals**
- A genuinely fun game that a 6-year-old and a 14-year-old both enjoy (scalable depth).
- A loop where doing real chores feels like the natural way to keep playing.
- Parent-funded prizes that feel earned through effort, never luck.
- Reuse the existing Flutter app, Firebase backend, and chore engine.

**Non-Goals (v1)**
- No real money flowing between different families (eliminates gambling/payments/legal risk).
- No player-to-player contact, chat, visiting, or trading.
- No leaderboards in v1 (deferred to v2).
- No commissioned/3D art in v1 (AI-generated assets + placeholders).

---

## 3. Core Loop

```
Build with tokens  →  run low on tokens  →  do a real chore
      ↑                                            ↓
hit a city milestone ← build more ← tokens refuel ← parent approves chore
      ↓
unlock the prize the parent loaded
```

Every part of the UI serves this loop: the city (where tokens are spent), the token "fuel" meter, progress toward the next prize, and the path back to chores when fuel runs out.

---

## 4. Players & Roles ("worldwide")

- The app is open **worldwide** — anyone can sign up.
- Every **player** (typically a child) **must have a funding admin** (a parent) behind them. This is mandatory by design.
  - It provides built-in **verifiable parental consent** (satisfies COPPA / GDPR-K for a child-facing global app).
  - The admin is the **sole source** of that player's prizes.
- **Prizes come only from the player's own admin.** Value never crosses between families. This makes it a gamified allowance, not gambling or money transmission.
- **Ambient social only (v2):** age-banded global leaderboards (e.g., most-developed cities) with **no direct contact**. Gives "I'm part of something huge" without stranger-danger. Deferred from v1.

---

## 5. The Game: Little City

**Setting:** a cozy, vibrant isometric town that grows into a city. Warm daytime palette, rounded friendly forms.

**What you do:**
- **Place & upgrade buildings** on an isometric grid (tap-to-place). Houses, shops, parks, roads, civic buildings.
- Each placement/upgrade **costs tokens** and adds to your **city value / level**.
- The city visibly fills in and levels up with effort — the core sense of progress.

**Win mechanic — effort + surprise (deliberately not gambling):**
- **Building earns XP.** Spending tokens to build/upgrade grows the city permanently **and** drops XP into your separate winnings balance. Effort always pays off.
- **XP is the payoff currency:** cash it out for real prizes or money (parent-funded), or trade it back into tokens at a poor rate to keep playing.
- **Surprise delights** layered on top: occasional **bonus-token/XP drops**, visiting characters, and **mystery crates earned by progress milestones** (NOT paid random pulls). Surprise adds joy; it never gates rewards behind luck and never has real money riding on chance.

**Scalability across ages:** a young child places one house and watches it light up; an older child optimizes layout, upgrade order, and city-value growth. Same game, deep ceiling.

---

## 6. Economy — two currencies (default values, all tunable)

**Tokens (spend to play) — earned by chores**

| Item | Default | Notes |
|---|---|---|
| Starting token grant | **100 tokens** | Generous runway so the game is fun before any chore is required. |
| Place house | ~10 tokens | |
| Place shop / civic | ~20 tokens | |
| Decoration | ~4 tokens | |
| Upgrade building | ~16 tokens | Rising cost per level. |
| Chore token value | **5–20 tokens** | Set per-chore by the admin (tunable; may scale up with the new economy). |

**XP (winnings) — earned by playing**

| Item | Default | Notes |
|---|---|---|
| XP per build/upgrade | scales with cost | Bigger builds → more XP. |
| Bonus XP chores | occasional | Some chores also grant a little XP, set by admin. |
| XP → prize / money | generous rate | The intended payoff path; parent-funded. |
| XP → tokens | **lossy and/or daily-capped** | Allowed, but deliberately poor — see loop guard below. |

**The loop & its guard:**
1. Player spends **tokens** building → city grows permanently → player earns **XP**.
2. Tokens run low → player completes a chore → **admin approves** → tokens credited.
3. Player cashes **XP** out for a prize or money (parent-funded), via the existing convert/shop flow.

> **Loop guard (must be deliberate):** XP→tokens conversion is intentionally **lossy and/or daily-capped** so playing alone always slowly bleeds tokens. This keeps chores necessary and prevents a closed perpetual-play loop. XP→prize/money stays the generous path.

---

## 7. Architecture

**Reuse (already built, keep as-is):**
- Firebase project `task2play-c09f7` (auth, Firestore, Storage; Email/Password).
- `families`, `users`, `wallets`, `quests` (chore templates), `questInstances` (submissions), `rewards` (catalog), `transactions`, `invitations` collections and their security rules.
- The parent↔child family/role model and the chore approval flow.

**Add — the game layer:**
- **Flame** (Flutter's 2D game engine) embedded inside the existing Flutter app, for the isometric city: sprite rendering, depth-sorting, tap-to-place, animation.
- The rest of the app (auth, chores, parent screens, navigation) stays in standard Flutter widgets; the City screen hosts a Flame `GameWidget`.

**Data model extensions (Firestore):**
- **Tokens (new):** a `tokens` balance on the player's wallet — the play-fuel. Chores credit it; building debits it; lossy/capped XP→tokens conversion credits it.
- **XP (reuse existing `points`):** repurpose the wallet's existing `points` field as **XP** — earned by building, convertible to tokens (lossy/capped), money (existing convert-to-money flow), or prizes (existing `rewards` shop). Minimal new machinery.
- **City state (new):** `cities/{uid}` document — permanent `cityLevel` / `cityValue` and a list of placed buildings (`{type, gridX, gridY, level}`). **Independent of XP** — cashing out XP never shrinks the city. Embedded list is fine at MVP scale.
- **Building catalog:** app-side config/constants (`type → tokenCost, xpReward, sprite, footprint`) — not Firestore at MVP.
- **Prizes:** reuse the existing `rewards` catalog + convert-to-money flow; prizes are **redeemed with XP**. (Optional later: bonus prizes tied to a city-level milestone.)

**Sync model:** city state and token balance persist in Firestore so progress survives across devices and the parent can see it. Building actions write through to Firestore; Flame renders local state optimistically.

---

## 8. Art Pipeline (AI-generated assets)

- The look comes from **art assets, not code.** Clash-of-Clans fidelity is impossible to hand-code; it requires real sprites.
- **My responsibility:** produce a precise **art spec** (isometric angle, single consistent lighting direction, style guide, palette, transparent PNGs, a shared scale/footprint grid) and **ready-to-paste generation prompts** for each asset.
- **Art generation:** done with external AI image tools (Midjourney / Stable Diffusion / etc.) by the user — *this cannot be done inside the Claude Code session.*
- **Integration:** I wire each generated sprite into Flame as it arrives. The game ships with **placeholder art first** so mechanics are playable before final art exists, then assets are swapped in.
- **Consistency is the hard part:** all assets must share iso angle, light direction, scale, and style. The art spec enforces this and prompts are templated accordingly.

---

## 9. MVP Scope (v1)

**In:**
- One city per player on an isometric grid.
- ~6–8 building types with tap-to-place and upgrade.
- City level / city-value progression.
- Token fuel + the full chore → token → build loop (reusing the existing chore engine).
- One parent-loaded prize tied to one city milestone, with unlock + "delivered" flow.
- Surprise: bonus-token drops + progress-milestone mystery crates.
- Solo play. Placeholder art with the Flame pipeline ready for AI assets.

**Out (deferred):**
- Leaderboards / any social (v2).
- Player-to-player contact, visiting, trading (not planned).
- Multiple cities, advanced economy, real-money payouts.
- Commissioned/3D art.

---

## 10. Risks & Mitigations

- **Art consistency** (biggest risk to the "CoC look"): mitigated by a strict art spec + templated prompts + a placeholder-first pipeline so the game works regardless of art state.
- **Scope creep:** the game genre invites endless features; the MVP list above is deliberately ruthless. Leaderboards and social are explicitly v2+.
- **Flame learning/integration:** new dependency; mitigated by isolating it to the City screen and keeping all backend/logic in the proven Flutter + Firebase layer.
- **"Surprise" drifting toward gambling:** all surprise is progress-earned, never paid random pulls, and no real money rides on chance. Within-family prize funding keeps it legally clean.

---

## 11. Open Questions (for planning / later)

- Exact city-level curve, XP-per-build curve, and XP→prize/money pacing (tune during implementation).
- The XP→tokens conversion rate and daily cap (the loop guard) — needs play-testing.
- Building catalog final list and upgrade trees.
- Onboarding flow for the new game-first experience (replaces the current welcome screen).
