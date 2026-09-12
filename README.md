# Hands-Off Timer

iOS 17+ SwiftUI app for **consecutive / chained timers**. When step N hits zero, step N+1 is already running — no tap required.

Display name: **Hands-Off Timer** (never ChainTimer). Bundle ID: `com.mueller4.HandsOffTimer`.

## What this MVP does

- Create ordered chains with per-step duration (`mm:ss`) and optional labels
- Optional chain name (default **Untitled chain**)
- Auto-advance in the same second; Skip is silent; natural end notifies + sound + light haptic
- Pause/resume the current step only; Stop confirms **End this chain?**
- Start is Home-only (editor is Cancel | Save)
- Local persistence (JSON + FileManager)
- Dynamic Island / Live Activity (best-effort if force-quit; not reboot survival)
- iPhone local notifications only — **no watchOS target**

See [Docs/PRD-v1.md](Docs/PRD-v1.md) and [Docs/DESIGN-v1.md](Docs/DESIGN-v1.md).

## Open on Mac

1. Clone this repo:

   ```sh
   git clone https://github.com/mueller4/hands-off-timer.git
   cd hands-off-timer
   ```

2. Open **`HandsOffTimer.xcodeproj`** in Xcode 15.4+ (Xcode 16 recommended).

3. **Simulator first.** Pick any iPhone simulator running iOS 17 or later, then Run (⌘R). You do not need a paid Apple Developer Program membership to run in Simulator.

4. **Signing:** set the Hands-Off Timer target (and the Chain Activity widget target) to **Automatically manage signing**. Choose your **Personal Team**. This is OK before Apple Developer enrollment is Active.

5. Capabilities / Info notes:

   - **Live Activities** are enabled via `NSSupportsLiveActivities` in Info. Live Activities and Dynamic Island only appear on a **physical iPhone** (not Simulator).
   - **Local notifications** work in Simulator (banners + sound). They do **not** require the Push Notifications capability. Do not add Push Notifications unless you later want ActivityKit *push* updates (needs a paid team).
   - If Xcode offers to add the **Push Notifications** capability, you can decline for this MVP.

6. On first **Start**, the app explains: *“Hands-Off Timer notifies you when each step ends so you can keep moving.”* Then it requests notification permission.

7. Known Simulator gaps for the iOS Builder:

   - ActivityKit / Dynamic Island: **device only**
   - Notification tap-while-backgrounded + Live Activity updates: verify on a device once a Personal Team can install
   - Time Sensitive interruption level is **not** used (would need an extra capability)

## Architecture

- `ChainEngine` owns progression with wall-clock deadlines. It does **not** import UserNotifications.
- `NotificationGateway` schedules local notifications from `snapshot.upcomingEnds`. Notification tap/dismiss is **navigation only** (`Notification.Name.handsOffOpenRun`) and never calls pause/stop/skip.
- `LiveActivityController` is best-effort ActivityKit, driven by the same snapshot.

## Deferred

- Icon Composer `.icon` Liquid Glass asset (flat 1024 is wired)
- Cloud sync, accounts, Watch app, Home Screen widgets, templates, extra settings
- ActivityKit push-to-update after force-quit
