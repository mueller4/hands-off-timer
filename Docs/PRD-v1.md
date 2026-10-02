# Hands-Off Timer — PRD v1 (MVP)

Locked product rules for the iOS 26+ SwiftUI MVP. Prefer a shippable chain runner over polish.

## Identity

- **Display name:** Hands-Off Timer (never brand as ChainTimer)
- **Bundle ID:** `com.mueller4.HandsOffTimer`
- **Minimum iOS:** 26.0, iPhone-first
- **Watch:** no watchOS target / Watch app
- **Critical Alerts:** not used. Step-end breakthrough is AlarmKit.

## Problem

People running consecutive timed blocks (warm-up → work → rest, cooking stages, rehab circuits) should not have to tap “next.” When step N hits zero, step N+1 must already be running.

## Core loop

1. Create an ordered **chain** of steps. Each step has a duration (`mm:ss` wheels, ≥ 1s) and an optional short label.
2. Optional chain name; empty saves as **Untitled chain**.
3. **Start is Home-only.** The editor is Cancel | Save — no Start in the editor.
4. Save requires ≥ 2 steps, each duration ≥ 1 second.
5. While running: **auto-advance** when a step hits 0 — step N+1 starts in the same second. No user tap.
6. On complete: brief Done, then dismiss to Home.

## Run controls

| Action | Behavior |
| --- | --- |
| **Pause** | Freezes the **current step only**. Resume continues that remaining time. |
| **Skip** | Silent advance. **No** AlarmKit alarm, **no** sound, **no** haptic. |
| **Stop** | Confirm **“End this chain?”** then end cleanly (cancel outstanding AlarmKit alarms, end Live Activity). |

## AlarmKit vs auto-advance (acceptance)

These two systems are independent. Alarms **never gate** progression.

- **Natural step end** → AlarmKit alarm that breaks Silent/Focus and continues until the user acknowledges (system stop / OK / tap-through). The next step is **already running**.
- **Skip** → silent. Do not schedule/present an AlarmKit alarm for the skipped step.
- **Acknowledge / dismiss** must **never** pause, stop, reset, or delay the next timer.
- Request AlarmKit permission on **first Start** with purpose copy: *“Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready.”*
- `NSAlarmKitUsageDescription` must match that purpose. No Critical Alerts entitlement.

## Live Activity / Dynamic Island

- Default: **compact** Dynamic Island (leading timer glyph, trailing mm:ss) + minimal.
- Expanded regions only when the user expands the Island. Not expanded-by-default. Not a full-width top banner while unlocked.
- Lock Screen Live Activity card stays compact (single row: glyph + label + mm:ss).
- Attributes / content: `stepIndex`, `stepCount`, `label`, `endDate`, `nextLabel`.
- Starts with the run, updates on step/pause/resume, ends on stop/complete.
- Best-effort if force-quit. **Not** reboot survival.
- v1 shipped no Home Screen widget. v1.1 adds systemSmall and systemMedium only (glance + open; Live Activity is unchanged).

## Persistence

- Chains persist locally on device (JSON via FileManager).
- No accounts, no cloud sync.

## Out of scope (v1)

Accounts, cloud sync, Home Screen widgets larger than medium, Lock Screen / StandBy / Control Center widgets, widget controls, templates marketplace, settings beyond AlarmKit permission, watchOS app, Critical Alerts, custom brand theme (use semantic system colors, light + dark).

## Screens

1. **Home / Chains** — empty state, list (name + “N steps · total…”), New Chain (+), Start on row, Edit/Delete.
2. **Chain Editor** — name field, reorderable steps (label + Clock-style minute/second wheels), Add Step, Cancel | Save.
3. **Run** — “Step X of Y”, label, large monospaced remaining, next line (or “Last step”), Skip / Pause|Resume / Stop (confirm). Full-screen cover while active.
