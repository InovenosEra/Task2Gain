# Autonomous Progress Log

Running log of overnight autonomous enhancements. Newest at top. Each entry:
what changed, verification, commit.

- **Accessibility** — Semantics(button+label) on icon-only controls: gear,
  currency "+", popup move/remove. 63 tests. (commit pending)
- **Fix: sprite-loader exception** — consult AssetManifest and only load
  sprites that are actually bundled, so missing PNGs no longer throw an
  unhandled "Unable to load asset" exception at startup. Verified gone on sim.
  63 tests. (commit pending)
- **Currency chip pulse** — icon badge pops (1→1.32→1) when value rises.
  (f609870)
- **City stats panel** — tap the city card to open a scrollable sheet: level,
  city value, building count + per-type breakdown, with a rename action.
  Verified on sim. 63 tests. (commit pending)
- **Test coverage** — catalog completeness (all 14 ids), City.cityValue ignores
  unknown types, indexAt hit/miss. 63 tests. (commit pending)
- **Daily reward** — once-per-day +15 token bonus, date-guarded, injectable
  clock; TDD'd `CityService.claimDailyReward`/`isDailyRewardAvailable`. Tappable
  green banner on the city; confetti + haptic on claim. Verified banner on sim.
  60 tests. (commit pending)
- **Number formatting** — `formatCount` util (commas + K/M) with tests, wired
  into HUD chips. 59 tests. (30823d2)
- **Haptics** — medium impact on build/upgrade/remove, selection click on move;
  added backlog + this log. 54 tests. (145b715)

(Started after commit 3e4f0e3 — drag-to-move. 54 tests passing.)
