# Little City — AI Art Asset Spec & Generation Prompts

**Purpose:** produce a *consistent* set of isometric building sprites (Clash-of-Clans / Hay Day / Township vibe) that drop into the Flame `CityGame`, replacing the placeholder coral blocks. Consistency is the whole game — every asset must share the same projection, lighting, scale, and style, or the city looks like a ransom note.

---

## 1. Global rules (apply to EVERY asset)

| Property | Value |
|---|---|
| **Projection** | True isometric, **2:1 dimetric** (classic game iso, ~30° tilt). Camera looks down from the **upper-front**. Same angle on every sprite. |
| **Lighting** | Single sun from the **upper-left**. Left/top faces bright, right faces in shadow. Identical on every asset. |
| **Style** | Cozy, rounded, vibrant mobile-game 3D-render look (think Clash of Clans / Township). Clean, soft edges, gentle gradients, subtle baked ambient occlusion. **No outlines/cel shading.** Not realistic, not flat-vector. |
| **Background** | **Transparent** (PNG with alpha). No ground, no scenery, no drop shadow baked in — the game draws the tile + shadow. |
| **Canvas** | Square **1024×1024** (downscaled in-app). Building **centered**, with ~12% padding so nothing clips. |
| **Footprint** | Each building sits on a **1×1 iso tile**. Its base diamond should occupy the **center ~55% width**; height grows upward only. Keep bases the same size across all 1×1 buildings so they align on the grid. |
| **Palette** | Warm daylight. Walls: cream `#F6F1E7` / `#E9E2D2`. Roof accents pick ONE per building from: coral `#FF8B6B`, teal `#2BB7A3`, mustard `#F4B942`, periwinkle `#7C83FF`, mint `#57C9A0`. Windows: soft sky-blue glass `#BFE3FF`. |
| **No** | No text, no logos, no people, no UI, no borders, no shadow plate, no multiple buildings per image. |

**Output naming:** `assets/city/<id>.png` (e.g. `house.png`). For upgrade tiers (optional, see §4): `<id>_l1.png`, `<id>_l2.png`, `<id>_l3.png`.

---

## 2. Reusable STYLE BLOCK (append to every prompt)

> *isometric 2:1 game asset, single building centered, cozy stylized mobile-game 3D render style like Clash of Clans and Township, soft rounded forms, warm midday sunlight from the upper-left, gentle ambient occlusion, cream walls with a colored roof, sky-blue glass windows, clean and polished, no outline, transparent background, no ground, no shadow, no text, high detail, 1:1 square*

Tool flags:
- **Midjourney:** add `--ar 1:1 --style raw --v 6`. MJ can't do true transparency — generate on a flat neutral background, then remove it (§5). To hold style across the set, generate the **house first**, then reuse its image as a style reference: `--sref <house_image_url>` (or `--cref` for character-like consistency) and keep `--seed` fixed.
- **DALL·E 3 / GPT-Image:** ask explicitly for "transparent background PNG." It honors it better than MJ.
- **Stable Diffusion (SDXL):** use an isometric LoRA if available; generate on green-screen `#00FF00` then key it out.

---

## 3. Per-building prompts (the 8 catalog types)

Paste subject + the §2 STYLE BLOCK. IDs match `lib/game/building_catalog.dart`.

1. **house** — *a small cozy two-story suburban house, coral-red sloped roof, a chimney, a tiny front door and two windows, a window box with flowers*
2. **shop** — *a small corner shop with a teal flat roof, a striped awning over a glass storefront, a hanging sign bracket (blank), crates by the door*
3. **park** — *a small green park tile: two rounded leafy trees, a curved path, a little pond and a bench, low hedges* (roof rule N/A — keep it a ground feature, same 1×1 footprint, low height)
4. **school** — *a friendly small schoolhouse, periwinkle-blue roof, a little clock/bell tower, arched windows, double front doors*
5. **factory** — *a small tidy factory, mustard-yellow roof, two short smokestacks (no smoke), a roller door, small vents on the roof*
6. **apartment** — *a slim 4-story apartment block, mint-green flat roof with a small rooftop unit, a grid of sky-blue windows, a recessed entrance*
7. **decor** — *a small decorative plaza statue: a rounded abstract monument on a cream pedestal with a couple of potted plants* (low height, 1×1)
8. **road** — *a single straight paved road segment tile, light-grey asphalt with a faint dashed centerline and thin sidewalk edges, flat, almost no height* (this one is essentially a textured ground tile)

> Tip: generate **house** first and lock it as the style anchor (seed + style-ref) before doing the rest, so roofs/windows/scale match.

---

## 4. Upgrade tiers (optional, recommended later)

Buildings have `level` (1, 2, 3…). Two approaches:
- **MVP (fewer assets):** one sprite per type; show level with a small in-game badge (drawn by the UI, not the sprite). Start here.
- **Satisfying (more assets):** 3 sprites per type — `_l1` modest, `_l2` bigger/with extras, `_l3` grand (more floors, banners, gold trim). Same footprint base, taller/fancier as level rises.

Decide per-building; you can mix (e.g., houses get 3 tiers, roads stay 1).

---

## 5. Post-processing checklist (per asset)

1. Remove background → true alpha PNG (remove.bg, Photoshop, or `rembg` CLI). MJ/SD outputs especially.
2. Trim to content, then re-center on a 1024² canvas with consistent base placement (so all 1×1 bases align).
3. Confirm the **base diamond** sits at the same spot/size across buildings (overlay two and check).
4. Export as `assets/city/<id>.png`.

---

## 6. How these wire into the game — ✅ DONE (pipeline is live)

The sprite pipeline is implemented and verified (2026-05-26). **To activate real art, just drop PNGs into `app/assets/city/` named `<id>.png`** (`house.png`, `shop.png`, … matching `building_catalog.dart` ids) and relaunch the app (a full `flutter run`, not just hot reload — Flutter only re-bundles assets on a fresh launch).

What's already wired:
1. `app/pubspec.yaml` registers `assets/city/` under `flutter/assets`.
2. `CityGame.onLoad` preloads each catalog id from `assets/city/<id>.png` via a Flame `Images(prefix: 'assets/city/')` cache into `_sprites`. Missing files are swallowed (expected).
3. `_drawBuilding` renders `_sprites[typeId]` when present (`_drawSprite`: anchored bottom-centre to the tile centre, scaled to ~`1.9·tileW`, `levelScale` grows it per level, soft contact shadow, level badge on top). Depth-sort by `gx+gy` is unchanged.
4. **Any missing sprite falls back to the canvas-drawn art** (cream walls + windows + pyramid/flat roofs, road/park/decor features), so a partial set still runs — you don't need all 8 at once. Even `house.png` alone shows a real sprite next to canvas buildings.

Tuning notes for when real art lands: assets are assumed **square** with the building centred and its base around the middle (§1). If buildings sit too high/low or too big/small, adjust the `size` (`tileW * 1.9`) and the `contact.dy + tileH * 0.5` seat offset in `CityGame._drawSprite`.

---

## 7. Suggested first batch

Generate these 3 first to validate the pipeline end-to-end: **house**, **park**, **shop**. Send them over, I wire them in, we check the look on the simulator, then you produce the rest with the locked style.
