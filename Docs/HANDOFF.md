# Handoff — iOS Builder

## How to run

Open `HandsOffTimer.xcodeproj` on a Mac. Scheme **HandsOffTimer**. iPhone simulator, **iOS 26+**. Xcode 26. Automatic signing, Personal Team. Details in the README “Open on Mac” section.

## Platform lock

- **Minimum deployment: iOS 26.0** (project + both targets).
- Step-end breakthrough uses **AlarmKit**, not Critical Alerts.
- Do **not** add `com.apple.developer.usernotifications.critical-alerts` or request `.criticalAlert`.
- `NSAlarmKitUsageDescription` is required. If missing or empty, AlarmKit will not schedule.
- AlarmKit **sound stays `.default`**. Simulator is silent — that is expected. Confirm sound on a physical iPhone. Do not switch to a named sound to “fix” Simulator.

## Architecture choices

- **ChainEngine** is a wall-clock deadline engine (`anchor + pauseAccum + skipBonus`). It does not import `AlarmKit`, `UserNotifications`, or `ActivityKit`.
- **AlarmKitGateway** observes `onNaturalEnd` / `onSnapshot` only. It never pauses, stops, skips, or delays the engine.
  - Natural step end → the already-scheduled AlarmKit alarm for that step starts alerting and **stays until the user acknowledges** (system stop / OK / tap-through).
  - Skip → cancel the pending (not-yet-fired) alarm. No AlarmKit alert.
  - Stop → `cancelAllForRun()` (cancel pending + stop alerting) and end the Live Activity.
  - **Start (new chain from Home)** → same teardown as Stop *before* `engine.start`: `LiveActivityController.endForRun()` then `AlarmKitGateway.cancelAllForRun()`. A leftover alerting alarm (user didn’t OK, or force-quit) must not keep sounding beside the new run (BUG-1).
  - Pause → cancel pending (not-yet-fired) schedules; resume reschedules remaining wall-clock ends. Alerting alarms are not cancelled.
  - Home title is **Hands-Off Timer** (locked display name).
- **AcknowledgeStepIntent** (`LiveActivityIntent`) runs on OK. It stops that AlarmKit alarm, removes the id from `alertingIDs`, and posts `Notification.Name.handsOffOpenRun`. Navigation + bookkeeping only — never mutates the engine.
- Persistence is **Codable + FileManager** (Application Support), not SwiftData — fewer moving parts for MVP.
- Live Activity content carries `stepIndex`, `stepCount`, `label`, `endDate`, `nextLabel` (plus `isPaused` so a paused island does not keep counting). Default presentation is **compact** Island (glyph + mm:ss) + compact Lock Screen card. Expanded regions exist only for user expansion. `Activity.request` / `update` never pass `alertConfiguration`.
- Lock / Home / StandBy Live Activity is a **leading cluster** (timer glyph + step label) and **trailing** countdown. The HStack uses `frame(maxWidth: .infinity)` so `Spacer` actually pushes time to the trailing edge (without that, the banner hugs leading). Compact Island trailing uses intrinsic `fixedSize()` / `caption` monospacedDigit — no `minWidth` gutter.
- Live Activity **type is one step larger** (Lock countdown `title3`, label `body`; Island compact trailing `caption` bold; expanded time `title3`) so Lock/Home/Island and the **system-mirrored Watch presentation** read at a glance. Watch has no companion app — it uses these iPhone ActivityKit / AlarmKit widget layouts. Long labels use `minimumScaleFactor(0.8–0.85)`. Stay one compact row; do not add minWidth frames.
- Active-run session is snapshotted to disk so a force-quit can restore the already-advanced step (best-effort; not reboot survival).
- The widget extension (`HandsOffTimerWidgets`) hosts both the chain Live Activity and the AlarmKit alert Live Activity (`StepEndAlarmActivity`) so the system has a presentation and does not dismiss the alerting alarm unexpectedly.
- Natural-end **haptic** (`Haptics.light`) runs only when `UIApplication.shared.applicationState == .active` (BUG-2). Not Silent-gated. AlarmKit sound is independent and stays `.default`. Skip does not fire `onNaturalEnd`, so Skip stays silent and haptic-free.
- `NotificationGateway` is a **dead stub**. Do not schedule from it. Leftover `UNUserNotificationCenter` taps in `AppDelegate` only post `handsOffOpenRun` (navigation).

## Restore / force-quit (do not cancel an alerting alarm)

`ChainEngine.restoreIfNeeded()` jumps `lastStepIndex` to the current wall-clock step **without** `onNaturalEnd` (hooks are not attached yet at `init`). The gateway therefore **must not** rely on `noteNaturalEnd` after a cold start.

On every `sync` / `apply`:

1. Query `AlarmManager.alarms` (`get throws` → `(try? manager.alarms) ?? []`).
2. Any alarm with `state == .alerting` is copied into `alertingIDs` (protected).
3. `cancel` / `stop` of those IDs is forbidden except:
   - user OK / `AcknowledgeStepIntent` (`noteAcknowledged`)
   - explicit Stop (`cancelAllForRun` / `tearDownAll`)
   - **new Home Start** (`cancelAllForRun` before `engine.start` — BUG-1)
4. Still-scheduled system alarms whose fire date matches an upcoming end are **adopted** (same UUID) instead of cancelled-and-recreated.

Still-scheduled leftovers that are not alerting and not adopted are cancelled so a relaunch does not double-schedule.

## Multi-step catch-up

While running, the gateway schedules **every remaining step-end** in `snapshot.upcomingEnds`, not only the current step. Each natural end therefore has (or had) its own AlarmKit schedule, including while the process is suspended or force-quit.

If the process stays alive and the ticker emits several `onNaturalEnd`s at once (long suspend):

- The end that matches `pendingByStep[completedIndex]` is promoted into `alertingIDs`.
- Any extra natural end with **no** pending schedule gets an acknowledge-required catch-up alarm (`schedule: .fixed(now + 0.25s)`), added to `alertingIDs` immediately. The engine is not blocked.

Skip never fires `onNaturalEnd`, so skipped steps stay silent.

If the process was killed **before** this multi-schedule shipped, only the then-current step had a system alarm; middle steps that elapsed with no schedule will not be retroactively alarmed. After this change, remaining steps are pre-scheduled.

## AlarmKit authorization

On first Start the app shows purpose copy, then `AlarmManager.requestAuthorization()`. The user can deny and still run a chain — the engine is independent; they just will not get breakthrough alarms.

Usage string (`NSAlarmKitUsageDescription` / in-app explainer):

> Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready.

## AlarmKit compile note (iOS 26.0 vs 26.1)

Xcode 26.1 SDK marks `AlarmPresentation.Alert.init(title:secondaryButton:secondaryButtonBehavior:)` as **iOS 26.1+**. Against a **26.0** deployment target that initializer is an error.

Use the iOS 26.0 initializer instead: `Alert(title:stopButton:)` with an **OK** `AlarmButton`. Do not bump the whole target to 26.1 just to use the title-only init. The stopButton form is deprecated on 26.1 but still compiles; a deprecation warning is OK.

`AlarmManager.alarms` is a throwing getter (`get throws`). Always read it as `(try? manager.alarms) ?? []`.

Schedule failures are logged with `os.Logger` (subsystem `com.mueller4.HandsOffTimer`, category `AlarmKit`). Sound remains `.default`.

## Apple Watch (no companion app)

AlarmKit **system-forwards** step-end alerts to a paired Apple Watch (WWDC25: StandBy and Watch when paired). That is system UI, not a Watch app we ship.

**There is no public iOS 26 AlarmKit / ActivityKit API** to prefer Watch-only, suppress iPhone audio, or pick a presentation device. `AlarmConfiguration` exposes schedule, attributes, stop/secondary intents, and `sound` (we keep `.default`). Muting iPhone sound or skipping AlarmKit would break Silent/Focus breakthrough — we will not fake Watch-only that way. No watchOS target.

Honest user guidance (do not invent Settings paths):

- Dual-ring (iPhone + Watch) is **system behavior** for AlarmKit, not something Hands-Off Timer can route.
- Clock’s Sleep Schedule **Always Play on iPhone** (iOS 26.4, Health / Clock → Sleep) is the *inverse* (force iPhone too) and applies to **Sleep Schedule only**, not third-party AlarmKit.
- Apple Watch app → My Watch → **Notifications** → Mirror iPhone is for **notifications**, not AlarmKit alarms.
- Apple Watch app → My Watch → **Clock** → Push Alerts from iPhone is for the **Clock** app, not AlarmKit.
- Cover-to-mute on Watch can silence a Watch alert in-progress; it does not stop the iPhone alarm.

Do not add an in-app Watch-pairing tip: `WCSession.isPaired` without a Watch target is not a reliable signal.

Engine / OK / Skip / Stop are unchanged.

**Command Ld failed:** expand the failed `Ld` step in Xcode’s Report navigator — the real line is above the generic “nonzero exit code.” This project now:

- Links **AlarmKit** + **AppIntents** on the app, and **AlarmKit** + **AppIntents** + WidgetKit + ActivityKit on the widget (frameworks phase **and** `OTHER_LDFLAGS`)
- Compiles `AcknowledgeStepIntent` **only in the app** (`LiveActivityIntent` runs in the app process; putting it in the widget without AppIntents is a Command Ld / undefined-symbol failure)
- Marks the widget `APPLICATION_EXTENSION_API_ONLY` with `WRAPPER_EXTENSION = appex`

If Ld still fails: Product → Clean Build Folder, delete DerivedData for this project if needed, then rebuild. Paste the **Undefined symbols** / **framework not found** lines from the Ld log, not only the last line.

## Device test (required)

Simulator cannot prove Silent/Focus breakthrough, Dynamic Island, or AlarmKit sound (Simulator silence is expected).

On a physical iPhone running iOS 26:

1. Allow AlarmKit on first Start.
2. Turn **Silent** on and enable a **Focus**.
3. Run a 2-step chain (~10s + ~10s).
4. When step 1 ends, step 2 must already be counting in-app **and** the AlarmKit alarm must keep sounding until you tap OK / stop. Acknowledging must **not** pause step 2.
5. Skip a step: no alarm.
6. Stop: outstanding alarms cancel; Island / Lock Screen activity ends.
7. **Start after leftover alarm (BUG-1):** run a short step, let it end, do **not** tap OK, go back to Home if needed, Start another chain. The old alarm must stop; the new run’s Island/Lock card is for the new chain only.
8. Compact Island hugs **glyph + time** with little trailing gutter. Lock / Home banner is **leading** label, **trailing** mm:ss (not all left). Type should read **one step larger** (Lock time `title3`, Island compact time `caption` bold). Watch mirror uses the same layouts.
9. **Force-quit restore:** start a 2-step chain (~15s + ~15s). Force-quit during step 1 near the end, **or** while the step-end alarm is sounding. Relaunch. The alarm must still sound until OK. Step 2 (or the current wall-clock step) must already be running / correct. OK must not pause or rewind the engine.
10. **Catch-up (optional):** start a 3-step chain of short steps, background the app until at least two ends have elapsed, foreground. Engine should already be on the current step; each missed *natural* end should have produced an acknowledge-required alarm (Skip remains silent).
11. **Watch:** with a paired Watch, expect the system to also alert on the Watch. Hands-Off Timer cannot silence iPhone and keep Watch. See “Apple Watch” above.

## Known gaps (device / Mac)

- **ActivityKit / Dynamic Island / AlarmKit Silent+Focus cannot be verified in Simulator.** Confirm on a physical iPhone. Simulator AlarmKit has no sound; keep `.default`.
- Push Notifications capability is **not** added. ActivityKit *push* updates (true force-quit survival) are deferred.
- Icon Composer `.icon` Liquid Glass is deferred; v4 1024 + dark/tinted appearances are wired.
- No unit-test target in Xcode (Linux builder cannot run `xcodebuild`). Engine behavior is covered by the mirrored TypeScript tests in the web preview workspace.
- Reboot (not force-quit) is not a survival target for the in-app run UI. AlarmKit schedules that the system still holds may still alert.
- **Watch dual-ring** is a system AlarmKit limitation (no public Watch-only API). See “Apple Watch” above.

## Don’t add

Watch target, Critical Alerts, cloud sync, extra settings, templates marketplace, widgets beyond Live Activity / AlarmKit presentation.
