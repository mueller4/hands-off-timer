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

4. **Signing:** Hands-Off Timer, the Chain Activity widget, and **HandsOffTimerWidget** use **Automatically manage signing** with team **3LW54H3BCH**.

   **App Group:** `group.com.mueller4.HandsOffTimer` is already on App IDs `com.mueller4.HandsOffTimer` and `com.mueller4.HandsOffTimer.HomeWidget`. Entitlements already include it. In Xcode, enable **App Groups** under Signing & Capabilities for the app and the Home widget targets, then refresh profiles. Until that capability is on the signed build, the widget stays on the empty state.

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
- AlarmKit OK (`AcknowledgeStepIntent`) stops that alarm only — it does **not** open the app. Island / leftover notification taps still post `Notification.Name.handsOffOpenRun` to open Run. Callbacks never call pause/stop/skip on the engine.
- `LiveActivityController` is best-effort ActivityKit, driven by the same snapshot. Compact Island by default; no `alertConfiguration` (that would expand the Island or show a full-width unlocked banner).
- Home Screen widget (v1.1, `systemSmall` + `systemMedium` only) reads an App Group mirror of that snapshot plus the saved chains. Tap opens Home (empty/idle) or Run (running). It does not start, pause, skip, stop, or dismiss AlarmKit. AlarmKit OK is unchanged (`openAppWhenRun` false).

## Deferred

- Icon Composer `.icon` Liquid Glass asset (flat 1024 is wired)
- Cloud sync, accounts, Watch app, templates, extra settings
- Home Screen widget sizes beyond small/medium, Lock Screen / StandBy / Control Center widgets, and any widget controls
- ActivityKit push-to-update after force-quit
