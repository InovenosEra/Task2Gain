# Autonomous Progress Log

Running log of overnight autonomous enhancements. Newest at top. Each entry:
what changed, verification, commit.

## STATUS (autonomous)
Safe, high-value, unsupervised work is largely **exhausted** — ~22 verified
commits this session (feel, engagement, robustness, accessibility, perf, and
full per-type building detail), all pushed, 66 tests green, analyzer clean.
Loop now runs on a slower heartbeat and only commits genuinely useful, low-risk
changes (small polish, more tests). **Held for your review** (too risky/
design-heavy to do unsupervised): (1) tying city milestones to the real prize/
reward system, (2) loading/error states inside the big pushed sub-screens, (3)
Cloud Functions to harden wallet credits (client-cheatable prototype rules),
(4) real AI building sprites (pipeline ready — drop PNGs in app/assets/city/).

- **Wallet-missing error tests** — place/upgrade/remove throw when no wallet doc exists. 72 tests.
- **Upgrade surprise-bonus test** — covers the previously-untested surprise path in upgradeBuilding. 71 tests.
- **Empty-state copy** — onboarding hint now describes the full flow (tap build, choose a building, then a tile). Verified on sim. 70 tests.
- **Tray cheapest-first** — build tray ordered by token cost ascending so affordable basics lead. Verified on sim. 70 tests.
- **Rename controller leak** — dispose the rename dialog TextEditingController after use (controller leak). 70 tests.
- **Daily-claim retry** — a failed daily-reward claim now keeps the banner (with an error toast) so the player can retry, instead of hiding it ungranted. 70 tests.
- **Stream error handling** — city + wallet stream subscriptions now have onError handlers (stream onError) so a transient Firestore error stays unhandled-free. 70 tests.
- **Lifecycle integration test** — place→upgrade→move→remove keeps wallet + city consistent. 70 tests.
- **City-card a11y** — the city card is flagged as a semantic button (city-card a11y). 69 tests.
- **Rail a11y** — action-rail buttons flagged as semantic buttons (rail semantics). 69 tests.
- **Upgrade popup clamp** — selection popup clamped on-screen (no clipping off the top/sides for edge or tall back-row buildings). Verified on sim. 69 tests.
- **Architecture overview doc** — docs/little-city-overview.md: handoff map of
  model/economy/service/rendering/screen/tests. (docs only)
- **Branch coverage tests** — negative tokensFromXp, daily-reward constant, empty-uid displayName stability. 69 tests.
- **Build button cancel label** — the build button reads ביטול (not בנייה) when in its cancel (✕) state. 66 tests.
- **Upgrade affordability** — the upgrade button dims when its cost exceeds the balance (consistent with the tray). Verified on sim. 66 tests.
- **Tray affordability** — build-tray items beyond the token balance are dimmed. Verified on sim. 66 tests.
- **School clock + banner-collision guard** — schools get a clock face; daily/level-up/moving banners are now mutually exclusive. 66 tests.
- **Apartment rooftop unit** — small mechanical unit detail on apartment roofs. 66 tests.
- **Tray scale-in + Hebrew audit** — build-tray items gently scale in when the
  tray opens; audited city UI strings (100% Hebrew, no fixes needed). 66 tests.
- **CityService edge tests** — move-to-same-cell no-op, level-1 remove refund.
  66 tests.
- **Tray XP display** — build-tray items show XP reward (⭐+N) under cost.
- **Milestone teaser** — city stats panel shows next-level goal. 64 tests.
- **Defensive parsing** — City.fromDoc / PlacedBuilding.fromMap tolerate
  malformed Firestore data (non-list buildings, non-map entries, string/null
  coords) without throwing; tolerant int coercion. 64 tests. (commit pending)
- **Perf: cache occupied set** — compute occupied cells once in setBuildings
  instead of every frame in render. 63 tests. (commit pending)
- **Lifecycle pause** — CityScreen observes app lifecycle and pauses/resumes
  the Flame engine on background/foreground (saves CPU/battery). 63 tests.
  (commit pending)
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
