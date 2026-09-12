# Hands-Off Timer — Design v1 (MVP)

## Visual language

- **Semantic system colors** only (light + dark). No custom brand theme, no ChainTimer branding.
- iPhone-first. Portrait. Grouped lists, system toolbars, confirmation dialogs / action sheets.
- Run remaining time: large **monospaced / tabular** figures.
- Accent: system blue. Start: system green. Stop / delete: system red.

## App icon (locked v4)

Full-bleed, no white matte.

| Role | File |
| --- | --- |
| Primary 1024 | `HandsOffTimer/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (from `AppIcon-1024-liquid-glass.png`) |
| Dark appearance | `AppIcon-dark.png` |
| Tinted / mono | `AppIcon-tinted.png` |
| Guides in repo | `Docs/assets/app-icon-v4-dark.png`, `Docs/assets/app-icon-v4-mono.png`, `Docs/assets/app-icon-v4-liquid-glass.png` |

True Liquid Glass Icon Composer `.icon` is a later Mac pass — the flat 1024 is enough for this MVP.

## Screen notes

### Home

- Large title **Chains**.
- Trailing **+** for New Chain.
- Row: name, `N steps · total m:ss`, prominent **Start**.
- Swipe: Edit, Delete (confirm).
- Empty state explains that Start lives on Home.

### Editor

- Cancel (leading) / Save (trailing, disabled until valid).
- **No Start control.**
- Name field placeholder `Untitled chain`.
- Steps: optional label, duration as side-by-side **wheel pickers** (minutes 0…99, seconds 0…59 — Clock → Timer), reorder, delete, Add Step.
- Save still requires ≥ 1s per step and ≥ 2 steps.

### Run

- Full-screen cover.
- Hierarchy: Step X of Y → label → remaining → next line.
- Three equal controls: Skip (silent), Pause/Resume, Stop (confirm “End this chain?”).
- Natural end: AlarmKit alert + light haptic, **non-blocking** — the next remaining time is already on screen. The alarm continues until OK.
- Skip never shows an alarm.
- Complete: brief Done, auto-dismiss to Home.

## Dynamic Island / Live Activity

- **Default compact:** timer glyph leading, mm:ss trailing. Minimal is the timer glyph.
- **Expanded** only when the user expands the Island (chain label, step X/Y, countdown). Not a full-width unlocked banner.
- **Lock Screen:** compact single row (glyph + label + mm:ss / Paused).
- Paused: show **Paused** instead of a live countdown.

## Motion

- Short system transitions. No custom brand motion.
- Remaining time ticks; no per-second digit carnival.

## Architecture (design implication)

`ChainEngine` is the source of truth for *when* a step ends. AlarmKit alerts and Live Activities are **output**. Acknowledging an alarm is navigation only — it must not look like a control that pauses or stops the chain.
