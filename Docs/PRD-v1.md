# Hands-Off Timer — PRD v1 (MVP)

Locked product rules for the iOS 17+ SwiftUI MVP. Prefer a shippable chain runner over polish.

## Identity

- **Display name:** Hands-Off Timer (never brand as ChainTimer)
- **Bundle ID:** `com.mueller4.HandsOffTimer`
- **Minimum iOS:** 17.0, iPhone-first
- **Watch:** mirrored iPhone local notifications only — **no watchOS target / Watch app**

## Problem

People running consecutive timed blocks (warm-up → work → rest, cooking stages, rehab circuits) should not have to tap “next.” When step N hits zero, step N+1 must already be running.

## Core loop

1. Create an ordered **chain** of steps. Each step has a duration (`mm:ss`, ≥ 1s) and an optional short label.
2. Optional chain name; empty saves as **Untitled chain**.
3. **Start is Home-only.** The editor is Cancel | Save — no Start in the editor.
4. Save requires ≥ 2 steps, each duration ≥ 1 second.
5. While running: **auto-advance** when a step hits 0 — step N+1 starts in the same second. No user tap.
6. On complete: brief Done, then dismiss to Home.

## Run controls

| Action | Behavior |
| --- | --- |
| **Pause** | Freezes the **current step only**. Resume continues that remaining time. |
| **Skip** | Silent advance. **No** notification, **no** sound, **no** haptic. |
| **Stop** | Confirm **“End this chain?”** then end cleanly (cancel pending notifications, end Live Activity). |

## Notifications vs auto-advance (acceptance)

These two systems are independent. Notifications **never gate** progression.

- **Natural step end** → local notification + sound + light haptic, **non-blocking**. The next step is already running.
- **Skip** → silent. Do not notify, sound, or haptic.
- **Notification tap / dismiss** must **never** pause, stop, reset, or delay the next timer.
- **Notification actions:** none. Tap opens Run on the **current already-advanced** wall-clock state.
- Request permission on **first Start** (or first Save) with purpose copy: *“Hands-Off Timer notifies you when each step ends so you can keep moving.”*

## Live Activity / Dynamic Island

- Attributes / content: `stepIndex`, `stepCount`, `label`, `endDate`, `nextLabel`.
- Starts with the run, updates on step/pause/resume, ends on stop/complete.
- Best-effort if force-quit. **Not** reboot survival.
- No widgets beyond Live Activity.

## Persistence

- Chains persist locally on device (JSON via FileManager).
- No accounts, no cloud sync.

## Out of scope (v1)

Accounts, cloud sync, widgets beyond Live Activity, templates marketplace, settings beyond notification permission, watchOS app, custom brand theme (use semantic system colors, light + dark).

## Screens

1. **Home / Chains** — empty state, list (name + “N steps · total…”), New Chain (+), Start on row, Edit/Delete.
2. **Chain Editor** — name field, reorderable steps (label + duration), Add Step, Cancel | Save.
3. **Run** — “Step X of Y”, label, large monospaced remaining, next line (or “Last step”), Skip / Pause|Resume / Stop (confirm). Full-screen cover while active.
