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
/// spacing ([kCell3DSpacing], 2.4) so neighbours don't touch. Height scales
/// proportionally, so towers stay tall and houses stay short.
const double kCity3DTargetFootprint = 2.0;

/// PLACEHOLDER model mapping — building type id → GLB filename under
/// [kCity3DModelDir].
///
/// Today every type renders the *same* Kenney `building-m.glb` block. These
/// are deliberately stand-ins: we'll swap in distinct, cozier per-type models
/// later. Keep this map the single source of truth so that swap is a one-file
/// edit. Keys are `BuildingType.id` values from `game/building_catalog.dart`.
const Map<String, String> kBuildingModels = {
  // residential
  'house': 'building-m.glb',
  'apartment': 'building-m.glb',
  'tower': 'building-m.glb',
  // business
  'shop': 'building-m.glb',
  'cafe': 'building-m.glb',
  'factory': 'building-m.glb',
  'bank': 'building-m.glb',
  // civic
  'school': 'building-m.glb',
  'hospital': 'building-m.glb',
  'cityhall': 'building-m.glb',
  // scenery
  'park': 'building-m.glb',
  'fountain': 'building-m.glb',
  'decor': 'building-m.glb',
  'road': 'building-m.glb',
};

/// Used when a building type has no entry in [kBuildingModels].
const String kCity3DFallbackModel = 'building-m.glb';

/// Resolves a building type id to a full bundled asset path, falling back to
/// [kCity3DFallbackModel] for unknown types.
String modelAssetPathFor(String typeId) =>
    '$kCity3DModelDir${kBuildingModels[typeId] ?? kCity3DFallbackModel}';
