# Handoff — iOS Builder

## How to run

Open `HandsOffTimer.xcodeproj` on a Mac. Scheme **HandsOffTimer**. iPhone simulator, **iOS 26+**. Xcode 26. Automatic signing, Personal Team. Details in the README “Open on Mac” section.

## Platform lock

- **Minimum deployment: iOS 26.0** (project + both targets).
- Step-end breakthrough uses **AlarmKit**, not Critical Alerts.
- Do **not** add `com.apple.developer.usernotifications.critical-alerts` or request `.criticalAlert`.
- `NSAlarmKitUsageDescription` is required. If missing or empty, AlarmKit will not schedule.

## Architecture choices

- **ChainEngine** is a wall-clock deadline engine (`anchor + pauseAccum + skipBonus`). It does not import `AlarmKit`, `UserNotifications`, or `ActivityKit`.
- **AlarmKitGateway** observes `onNaturalEnd` / `onSnapshot` only. It never pauses, stops, skips, or delays the engine.
  - Natural step end → the already-scheduled AlarmKit alarm for that step starts alerting and **stays until the user acknowledges** (system stop / OK / tap-through).
  - Skip → cancel the pending (not-yet-fired) alarm. No AlarmKit alert.
  - Stop → `cancelAllForRun()` (cancel pending + stop alerting) and end the Live Activity.
  - Pause → cancel the pending schedule; resume reschedules the remaining wall-clock end.
- **AcknowledgeStepIntent** (`LiveActivityIntent`) runs on OK. It stops that AlarmKit alarm and posts `Notification.Name.handsOffOpenRun`. Navigation only.
- Persistence is **Codable + FileManager** (Application Support), not SwiftData — fewer moving parts for MVP.
- Live Activity content carries `stepIndex`, `stepCount`, `label`, `endDate`, `nextLabel` (plus `isPaused` so a paused island does not keep counting). Default presentation is **compact** Island (glyph + mm:ss) + compact Lock Screen card. Expanded regions exist only for user expansion. `Activity.request` / `update` never pass `alertConfiguration`.
- Active-run session is snapshotted to disk so a force-quit can restore the already-advanced step (best-effort; not reboot survival).
- The widget extension (`HandsOffTimerWidgets`) hosts both the chain Live Activity and the AlarmKit alert Live Activity (`StepEndAlarmActivity`) so the system has a presentation and does not dismiss the alerting alarm unexpectedly.

## AlarmKit authorization

On first Start the app shows purpose copy, then `AlarmManager.requestAuthorization()`. The user can deny and still run a chain — the engine is independent; they just will not get breakthrough alarms.

Usage string (`NSAlarmKitUsageDescription` / in-app explainer):

> Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready.

## AlarmKit compile note (iOS 26.0 vs 26.1)

Xcode 26.1 SDK marks `AlarmPresentation.Alert.init(title:secondaryButton:secondaryButtonBehavior:)` as **iOS 26.1+**. Against a **26.0** deployment target that initializer is an error (`AlarmKitGateway.swift` ~line 100).

Use the iOS 26.0 initializer instead: `Alert(title:stopButton:)` with an **OK** `AlarmButton`. Do not bump the whole target to 26.1 just to use the title-only init. The stopButton form is deprecated on 26.1 but still compiles; a deprecation warning is OK.

`AlarmManager.alarms` is a throwing getter (`get throws`). Always read it as `(try? manager.alarms) ?? []`.

**Command Ld failed:** expand the failed `Ld` step in Xcode’s Report navigator — the real line is above the generic “nonzero exit code.” This project now:

- Links **AlarmKit** + **AppIntents** on the app, and **AlarmKit** + **AppIntents** + WidgetKit + ActivityKit on the widget (frameworks phase **and** `OTHER_LDFLAGS`)
- Compiles `AcknowledgeStepIntent` **only in the app** (`LiveActivityIntent` runs in the app process; putting it in the widget without AppIntents is a Command Ld / undefined-symbol failure)
- Marks the widget `APPLICATION_EXTENSION_API_ONLY` with `WRAPPER_EXTENSION = appex`

If Ld still fails: Product → Clean Build Folder, delete DerivedData for this project if needed, then rebuild. Paste the **Undefined symbols** / **framework not found** lines from the Ld log, not only the last line.

## Device test (required)

Simulator cannot prove Silent/Focus breakthrough or Dynamic Island.

On a physical iPhone running iOS 26:

1. Allow AlarmKit on first Start.
2. Turn **Silent** on and enable a **Focus**.
3. Run a 2-step chain (~10s + ~10s).
4. When step 1 ends, step 2 must already be counting in-app **and** the AlarmKit alarm must keep sounding until you tap OK / stop. Acknowledging must **not** pause step 2.
5. Skip a step: no alarm.
6. Stop: outstanding alarms cancel; Island / Lock Screen activity ends.
7. Confirm the Island stays **compact** (glyph + mm:ss) while unlocked; expand only on long-press. Lock Screen card is a single compact row.

## Known gaps (device / Mac)

- **ActivityKit / Dynamic Island / AlarmKit Silent+Focus cannot be verified in Simulator.** Confirm on a physical iPhone.
- Push Notifications capability is **not** added. ActivityKit *push* updates (true force-quit survival) are deferred.
- Icon Composer `.icon` Liquid Glass is deferred; v4 1024 + dark/tinted appearances are wired.
- No unit-test target in Xcode (Linux builder cannot run `xcodebuild`). Engine behavior is covered by the mirrored TypeScript tests in the web preview workspace.

## Don’t add

Watch target, Critical Alerts, cloud sync, extra settings, templates marketplace, widgets beyond Live Activity / AlarmKit presentation.
