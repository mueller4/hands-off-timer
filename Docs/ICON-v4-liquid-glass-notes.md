# Hands-Off Timer — App icon v4 (LOCKED)

**Display name (locked):** Hands-Off Timer
**Icon status (locked):** v4 full-bleed — Default + Dark + Mono (tapered hand, no white matte). **Default BG:** original navy→royal. **Accents:** Mail/system blue `#0A84FF` (same as Dark). v3 superseded.
**Primary:** `app-icon-v4-liquid-glass.png` · **1024:** `AppIcon-1024-liquid-glass.png`
**Later:** Icon Composer `.icon` on Mac/Xcode — not blocking this lock.

DNA from locked flat v3.

## Deliverables
| Variant | Preview | 1024 |
|---|---|---|
| Default (primary marketing) | `app-icon-v4-liquid-glass.png` (= `app-icon-v4-default.png`) | `AppIcon-1024-liquid-glass.png` |
| Dark | `app-icon-v4-dark.png` | `AppIcon-1024-v4-dark.png` |
| Mono (Clear/Tinted source) | `app-icon-v4-mono.png` | `AppIcon-1024-v4-mono.png` |

Prior heavier frosted preview superseded by this flatter set (less baked specular).

## What changed vs locked v3
- Same silhouette: white dial, blue ~2 o’clock hand, segmented ring + cardinals, T-crown, blue gradient BG
- **Bolder filled shapes / hard edges** (no hairlines)
- **No heavy baked glass** (no frosted blur, fake bevels, glow halos) — light suggestion only via gradient BG + clean layering
- Added **Dark** + **Mono** with identical silhouette for appearance modes

## Suggested Icon Composer stack (≤4 groups)
1. **BG** — navy→royal blue gradient (Default); near-black (Dark); neutral gray (Mono)
2. **Case / bezel** — segmented ring + cardinal dots (+ optional slight translucency later in Composer)
3. **Dial face** — solid white / light (optional slight translucency in Composer)
4. **Hands + crown** — high-contrast solid accents

## Apple constraints (CoS brief + HIG / WWDC 220 & 361)
- System Liquid Glass + Icon Composer add specular / refraction / blur — **don’t bake those into the PNG**
- Production path: simplified graphic layers → **`.icon`** via Icon Composer; flat PNG alone only gets weak edge specular
- Unmasked **1024×1024** square; system applies mask
- Keep silhouette consistent across Default / Dark / Clear / Tinted (Clear/Tinted derive from Mono)


## Hand shape (Jacob lock direction)
- **Tapered** hand at ~2 o’clock: **wider clean circular base** at the hub, narrowing to a **rounded tip** — not a uniform capsule.
- Base must be even/symmetric (no blob / uneven root); tip is the narrow end.
- Applied on Default, Dark, and Mono (+ 1024 exports).

## Full-bleed (Jacob / HIG)
- Icons are **unmasked full-bleed squares** — gradient/BG to all four edges.
- **No** white matte, pre-drawn squircle, or white corner halo (system applies continuous corner mask).

## Accent / BG lock (Jacob)
- **Default BG:** original navy→royal v4 gradient (not Mail cyan).
- **Accents (Default + Dark):** Mail/system blue `#0A84FF` (ring / hand / crown / dots).
- Mono unchanged (grayscale).
