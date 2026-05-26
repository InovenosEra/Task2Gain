# Little City — Architecture Overview

A handoff map of the game-first "Little City" feature (built on the existing
Task2Play Firebase backend + chore engine). All paths under `app/`.

## Data & economy
- **`lib/models/city.dart`** — `City` (uid, name, `List<PlacedBuilding>`) and
  `PlacedBuilding` (typeId, gridX, gridY, level). `City.cityValue` /
  `cityLevel`, `isOccupied`, `indexAt`, `displayName` (chosen name or a
  deterministic Hebrew default). `fromDoc`/`fromMap` are **defensive** — they
  tolerate malformed Firestore data (non-list buildings, non-map entries,
  string/null coords) via `_toInt`.
- **`lib/game/economy_config.dart`** — tunables: `kStartingTokens` (100),
  `kCityValuePerLevel` (100), `kXpToTokenRate`/`kXpToTokenDailyCap` (lossy
  loop guard), `kSurpriseChance`/`kSurpriseBonusTokens`, `kDailyRewardTokens`
  (15). `cityLevelForValue`, `tokensFromXp`.
- **`lib/game/building_catalog.dart`** — `kBuildingCatalog`: 14 `BuildingType`s
  (house/shop/park/school/factory/apartment/tower/cityhall/hospital/cafe/bank/
  fountain/decor/road), each with token cost + XP reward that scale by level.

## Service (all transactional, read-modify-write; testable with fake_cloud_firestore)
**`lib/services/city_service.dart`** — `CityService({firestore, rng, clock})`:
- `placeBuilding` — debit tokens, credit XP, append building, maybe surprise bonus.
- `upgradeBuilding` — rising cost, credit XP, maybe bonus.
- `moveBuilding` — relocate to an empty tile, free, keep level.
- `removeBuilding` — delete + refund half current value.
- `renameCity` — trimmed/capped, merge-safe.
- `claimDailyReward` / `isDailyRewardAvailable` — once-per-calendar-day token
  bonus, date-guarded via the injectable `clock`.
- `watchCity` — stream of `City`.

## Rendering (Flame)
**`lib/game/city_game.dart`** (`CityGame extends FlameGame`):
- Isometric 2:1 projection (`_iso` / inverse `tileAt`); 10×10 grid; floating
  island base (`_drawIsland`), drifting clouds + birds, sun glow.
- Per-type canvas art via `_Style` (`_Roof` pyramid/flat/dome/none, `_Kind`
  building/road/park/decor, `glass`): cream walls + sky-blue window grids,
  per-type details (chimneys, awnings, smokestacks+smoke, glass curtain wall +
  antenna, dome, red cross, columns+pediment, parasol, rooftop units, school
  clock), ambient scenery (bushes/flowers/rocks/people), water shimmer.
- **Sprite pipeline**: `onLoad` reads the AssetManifest and loads only the
  `assets/city/<id>.png` files that exist (no failed-asset exceptions); a
  present sprite replaces the canvas art per type, else canvas fallback.
- Interactions surfaced to the screen via `onCellTapped`; drag-to-move via
  `beginDrag`/`updateDrag`/`endDrag`; `setBuildMode` (buildable highlight),
  `setSelected` (ring), `celebrate`/`burstConfetti` (juice). Engine pauses when
  the app is backgrounded.

## Screen / HUD
**`lib/screens/city_screen.dart`** (`CityScreen`, the full-screen shell):
- Floating chrome: gear (settings sheet), animated points/tokens chips (pulse
  on increase, `+`→tasks, compact `formatCount`), city card (→ stats panel with
  rename + per-type breakdown + next-level teaser), action rail
  (tasks/shop/family → pushed `_SubScreen`s), build button (hammer/✕ "ביטול").
- Build flow: tap בנייה → tray (items show cost + XP, dim when unaffordable,
  scale-in) → pick a type (arms it, "מציב:" chip) → tap empty tiles to place.
- Selection: tap a building → ring + popup (level, שדרוג w/ affordability dim,
  move, remove); tap anywhere or drag to relocate; tap-away deselects.
- Banners: daily reward, level-up celebration, moving hint, empty-state — all
  mutually exclusive at the top anchor.
- `main_navigation.dart` renders `CityScreen` as the root (no bottom nav).

## Tests
13 test files (~69 tests): city model (incl. malformed-data), city service
(place/upgrade/move/remove/daily/rename), economy, catalog, format, plus the
pre-existing wallet/quest/prize suites.

## Held for review (see AUTONOMOUS_PROGRESS.md)
Tie city milestones to the real prize/reward system; loading/error states in
the pushed sub-screens; Cloud Functions to harden wallet credits (currently
client-cheatable prototype rules); real AI building sprites (drop PNGs into
`app/assets/city/`).
