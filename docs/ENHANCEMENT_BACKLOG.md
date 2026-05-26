# Little City — Enhancement Backlog (autonomous)

Worked top-to-bottom by the autonomous loop. Each item: implement → `flutter
analyze lib test` clean → `flutter test` all pass → (UI) simctl screenshot →
commit + push to `little-city-economy-foundation`. Mark `[x]` when done and log
in AUTONOMOUS_PROGRESS.md. Safe-only: no main, no force-push, no deploys, no
prod writes, no destructive ops.

## Polish / feel
- [x] Haptic feedback on successful build / upgrade / move / remove.
- [x] Large-number formatting for HUD counts (1,234 / 12.3K).
- [ ] Animate currency chips with a brief pulse/flash when they increase.
- [ ] Accessibility: Semantics labels on icon-only buttons (gear, rail, build, +).
- [ ] Pause the Flame game when the app is backgrounded (lifecycle).

## Gameplay
- [x] Daily reward: once-per-day token bonus with a claim popup (date-guarded; TDD).
- [ ] City stats sheet: building count, city value, breakdown by type (read-only).
- [ ] Prize/milestone teaser tying city level to the existing reward system.
- [ ] Quest shortcut: surface count of tasks ready to claim near the rail.

## Robustness / quality
- [ ] Graceful loading + error states for pushed sub-screens (stream errors).
- [x] Expand unit tests: economy_config, building_catalog, City value/level edges.
- [ ] Guard placement against off-grid / duplicate coords (already partly covered).
- [ ] Defensive null/format handling in wallet + city parsing (fuzz-ish tests).

## Performance
- [ ] CityGame.render allocates sets/lists every frame — cache occupied set when
      buildings change instead of per-frame.

## Notes / constraints
- Demo account: builder_1779708698@task2play.test. Wallet writes allowed by
  prototype rules (client self-credit) — fine for prototype, flagged for prod.
- App runs in tmux session `t2g`; landscape-locked so simctl screenshots need
  `sips -r ±90` to view upright.
