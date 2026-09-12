# Hands-Off Timer

iOS 26+ SwiftUI app for **consecutive / chained timers**. When step N hits zero, step N+1 is already running — no tap required.

Display name: **Hands-Off Timer** (never ChainTimer). Bundle ID: `com.mueller4.HandsOffTimer`.

## What this MVP does

- Create ordered chains with per-step duration (Clock-style minute/second wheels) and optional labels
- Optional chain name (default **Untitled chain**)
- Auto-advance in the same second; Skip is silent; natural end uses **AlarmKit** until you acknowledge
- Pause/resume the current step only; Stop confirms **End this chain?**
- Start is Home-only (editor is Cancel | Save)
- Local persistence (JSON + FileManager)
- Compact Dynamic Island / Live Activity (best-effort if force-quit; not reboot survival)
- iPhone only — **no watchOS target**, **no Critical Alerts**

See [Docs/PRD-v1.md](Docs/PRD-v1.md) and [Docs/DESIGN-v1.md](Docs/DESIGN-v1.md).

## Open on Mac

1. Clone this repo:

   ```sh
   git clone https://github.com/mueller4/hands-off-timer.git
   cd hands-off-timer
   ```

2. Open **`HandsOffTimer.xcodeproj`** in **Xcode 26**.

3. **Simulator first.** Pick any iPhone simulator running **iOS 26** or later, then Run (⌘R). You do not need a paid Apple Developer Program membership to run in Simulator.

4. **Signing:** set the Hands-Off Timer target (and the Chain Activity widget target) to **Automatically manage signing**. Choose your **Personal Team**. This is OK before Apple Developer enrollment is Active.

5. Capabilities / Info notes:

   - **Live Activities** are enabled via `NSSupportsLiveActivities` in Info. Live Activities and Dynamic Island only appear on a **physical iPhone** (not Simulator). The Island defaults to **compact** (timer glyph + mm:ss); expanded regions are only shown when you expand.
   - **AlarmKit** is the step-end path. `NSAlarmKitUsageDescription` explains that step-end alarms break through Silent/Focus; the next timer is already running. Acknowledge (system stop / OK) dismisses the alarm only — it never pauses the chain.
   - Do **not** add the Critical Alerts entitlement or request `.criticalAlert` authorization.
   - If Xcode offers to add the **Push Notifications** capability, you can decline for this MVP.

6. On first **Start**, the app explains: *“Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready.”* Then it requests AlarmKit authorization.

7. Known Simulator gaps for the iOS Builder:

   - ActivityKit / Dynamic Island: **device only**
   - AlarmKit breakthrough with Silent + Focus: **device only** (see [Docs/HANDOFF.md](Docs/HANDOFF.md))
   - Alarm tap-while-backgrounded + Live Activity updates: verify on a device once a Personal Team can install

## Architecture

- `ChainEngine` owns progression with wall-clock deadlines. It does **not** import AlarmKit, UserNotifications, or ActivityKit.
- `AlarmKitGateway` schedules a one-shot AlarmKit alarm for the current step’s end from `snapshot.upcomingEnds`. Natural end promotes that alarm so it keeps ringing until the user acknowledges; Skip cancels it (never fired); Stop cancels outstanding alarms for the run.
- AlarmKit / notification callbacks are **navigation + acknowledge only** (`Notification.Name.handsOffOpenRun`) and never call pause/stop/skip on the engine.
- `LiveActivityController` is best-effort ActivityKit, driven by the same snapshot. Compact Island by default; no `alertConfiguration` (that would expand the Island or show a full-width unlocked banner).

## Deferred

- Icon Composer `.icon` Liquid Glass asset (flat 1024 is wired)
- Cloud sync, accounts, Watch app, Home Screen widgets, templates, extra settings
- ActivityKit push-to-update after force-quit
