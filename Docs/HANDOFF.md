# Handoff — iOS Builder

## How to run

Open `HandsOffTimer.xcodeproj` on a Mac. Scheme **HandsOffTimer**. iPhone simulator, iOS 17+. Automatic signing, Personal Team. Details in the README “Open on Mac” section.

## Architecture choices

- **ChainEngine** is a wall-clock deadline engine (`anchor + pauseAccum + skipBonus`). It does not import `UserNotifications` or `ActivityKit`.
- **NotificationGateway** reschedules local notifications from `snapshot.upcomingEnds` whenever the step/pause signature changes. Skip cancels the current step’s request because that snapshot no longer includes it.
- **AppDelegate** notification callbacks only post `Notification.Name.handsOffOpenRun`. ContentView presents Run. The engine is not paused, stopped, reset, or delayed.
- Persistence is **Codable + FileManager** (Application Support), not SwiftData — fewer moving parts for MVP.
- Live Activity content carries `stepIndex`, `stepCount`, `label`, `endDate`, `nextLabel` (plus `isPaused` so a paused island does not keep counting).
- Active-run session is snapshotted to disk so a force-quit can restore the already-advanced step (best-effort; not reboot survival).

## Known gaps (device / Mac)

- **ActivityKit / Dynamic Island cannot be verified in Simulator.** Confirm on a physical iPhone.
- Local notification tap while backgrounded + Live Activity step-change while suspended need a device pass.
- Push Notifications capability is **not** added. Local notifications do not need it. ActivityKit *push* updates (true force-quit survival) are deferred.
- Icon Composer `.icon` Liquid Glass is deferred; v4 1024 + dark/tinted appearances are wired.
- No unit-test target in Xcode (Linux builder cannot run `xcodebuild`). Engine behavior is covered by the mirrored TypeScript tests in the web preview workspace.

## Don’t add

Watch target, cloud sync, extra settings, templates marketplace, widgets beyond Live Activity.
