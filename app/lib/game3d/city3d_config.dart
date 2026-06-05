/// Configuration for the experimental 3D city renderer (flutter_scene).
///
/// The 3D city is built in stages behind [kUse3DCity]; while it is `false`
/// the app keeps rendering the proven Flame board ([CityGame]) and the 3D
/// code is dormant. Flip the flag (or override it at build time) to swap in
/// the 3D view once a stage is ready to try.
library;

/// Master switch: when `false` (default) the app uses the Flame city board.
/// Stage 2 wires this so it swaps the Flame `GameWidget` for the 3D widget.
///
/// Can be overridden without editing code via:
///   flutter run --dart-define=USE_3D_CITY=true
const bool kUse3DCity =
    bool.fromEnvironment('USE_3D_CITY', defaultValue: false);

/// Asset directory (registered in pubspec.yaml) holding the 3D building GLBs.
const String kCity3DModelDir = 'assets/city3d/models/';

/// Shared Kenney colormap palette texture, used as a fallback for models that
/// have no embedded textures (e.g. the Kenney placeholder). Models that embed
/// their own textures (e.g. the ITHappy Cartoon City pack) ignore it.
const String kCity3DColormap = 'assets/city3d/textures/colormap.png';

/// Target horizontal footprint (world units) every building is auto-scaled to,
/// regardless of the source model's native size. Kept a bit under the cell
/// spacing ([kCell3DSpacing], 2.4) so neighbours don't touch.
const double kCity3DTargetFootprint = 2.0;

/// Hybrid height scaling: footprints stay uniform, but a model taller than
/// [kCity3DHeightRef] native units is stretched vertically (beyond the uniform
/// footprint scale) so towers read as tall instead of stubby — capped at
/// [kCity3DMaxVStretch]x to keep distortion mild. Short models are untouched.
const double kCity3DHeightRef = 22.0;
const double kCity3DMaxVStretch = 2.4;

/// MegaCity flat grass tile (15x15) tiled to form the city ground.
const String kCity3DGroundTile = 'assets/city3d/models/grass_001.glb';

/// Model mapping — building type id → GLB filename under [kCity3DModelDir].
///
/// Uses the ITHappy MegaCity pack (embedded textures, auto-scaled/recentered by
/// the loader). Keep this map the single source of truth so re-skinning is a
/// one-file edit. Keys are `BuildingType.id` values from
/// `game/building_catalog.dart`.
///
/// For per-level visual *variants* later, this can become
/// `Map<String, Map<int, String>>` (type → level → model) without touching the
/// renderer — level is currently expressed as scale (see `scaleForLevel`).
///
/// Two types have no exact MegaCity match (user-confirmed):
///   • factory → tool_store (closest industrial/commercial building)
///   • park    → children_playground (closest green/recreational area)
const Map<String, String> kBuildingModels = {
  // residential
  'house': 'residental_building_001.glb',
  'apartment': 'elite_residental_building_001.glb',
  'tower': 'skyscraper_001.glb',
  // business
  'shop': 'supermarket_001.glb',
  'cafe': 'coffee_shop_001.glb',
  'factory': 'tool_store_001.glb', // no factory model; closest commercial
  'bank': 'business_center_001.glb', // no bank model; business center
  // civic
  'school': 'school_001.glb',
  'hospital': 'hospital_001.glb',
  'cityhall': 'government_bilding_001.glb',
  // scenery
  'park': 'children_playground_001.glb', // no park model; playground
  'fountain': 'fountain_001.glb',
  'decor': 'monument_001.glb',
  'road': 'road_001.glb',
};

/// Used when a building type has no entry in [kBuildingModels].
const String kCity3DFallbackModel = 'residental_building_001.glb';

/// Resolves a building type id to a full bundled asset path, falling back to
/// [kCity3DFallbackModel] for unknown types.
String modelAssetPathFor(String typeId) =>
    '$kCity3DModelDir${kBuildingModels[typeId] ?? kCity3DFallbackModel}';
