# Multi Timer — Technical Specifications

> Living document. Update when behavior, schemas, or architecture change.

This file complements `README.md` (project overview / usage) with the deeper
**technical** details: data model, screen flows, lifecycle, animations,
scheduling semantics, and the documented bug fix.

---

## 1. Goals & Non-goals

### Goals

- Persist multiple named timers across app launches.
- Support both **manual** and **scheduled** timers.
- Render a high-impact running screen with a water-wave fill animation.
- Survive app-close scenarios for scheduled timers — see §6 (bug fix).
- Run on desktop (Windows / macOS / Linux), web, iOS, and Android.

### Non-goals

- Cloud sync, accounts, or sharing.
- Recurring/periodic timers (planned, not implemented).
- System tray or OS-level notifications while the app is minimized.

---

## 2. High-level architecture

```
+---------------------------+        +----------------------------+
|        MyApp              |        |     DatabaseHelper         |
|  (MaterialApp + theme)    |        |   (sqflite singleton)      |
+-------------+-------------+        +--------------+-------------+
              |                                       |
              v                                       v
+---------------------------+        +----------------------------+
|      TimerListPage        |<------>|  SQLite DB "timers.db"     |
|  - load / add / delete    |  CRUD  |  table: timers             |
|  - rebuilds after edits   |        +----------------------------+
+-------------+-------------+
              |
              | Navigator.push (TimerRunningPage)
              v
+---------------------------+
|     TimerRunningPage      |
|  - start / pause / reset  |
|  - water-wave animation   |
|  - end-message modal      |
+---------------------------+
```

**Pattern:** Plain `StatefulWidget` + `setState` + a small **observer** hook on
`SavedTimer`. No external state-management package.

---

## 3. Data model

### 3.1 SQLite schema

#### `timers` table

| Column             | Type    | Nullable | Notes                                         |
|--------------------|---------|:--------:|-----------------------------------------------|
| `id`               | INTEGER | NO       | `PRIMARY KEY AUTOINCREMENT`                   |
| `name`             | TEXT    | NO       | Display name (e.g. "Workout").                |
| `hours`            | INTEGER | NO       | 0 ≤ value                                     |
| `minutes`          | INTEGER | NO       | 0 ≤ value ≤ 59                                |
| `seconds`          | INTEGER | NO       | 0 ≤ value ≤ 59                                |
| `scheduledTime`    | TEXT    | YES      | ISO-8601 (`DateTime.toIso8601String()`).      |
| `isScheduled`      | INTEGER | NO       | `1` = pending schedule; `0` = past/no schedule. |
| `wasScheduledStart`| INTEGER | NO       | `1` = timer was originally created with a schedule. |
| `endMessage`       | TEXT    | YES      | Optional message shown at `remainingSeconds == 1`. |

#### `greetings` table (schema v3+)

| Column      | Type    | Nullable | Notes                                          |
|-------------|---------|:--------:|------------------------------------------------|
| `id`        | INTEGER | NO       | `PRIMARY KEY AUTOINCREMENT`                    |
| `title`     | TEXT    | NO       | Greeting page title (≤ 80 chars in dialog).    |
| `createdAt` | TEXT    | NO       | ISO-8601 timestamp of creation.                |

Schema version: **3**.
- v1 → v2: added `endMessage` column to `timers`.
- v2 → v3: added `greetings` table.

### 3.2 `SavedTimer` runtime model (in-memory)

```dart
class SavedTimer {
  int? id;                              // DB primary key
  final String name;
  final int hours;
  final int minutes;
  final int seconds;
  final DateTime? scheduledTime;
  final String? endMessage;

  int remainingSeconds = 0;             // mutable, ticking countdown
  Timer? _timer;                        // periodic 1s ticker (countdown)
  Timer? _schedulerTimer;               // one-shot timer for scheduled start
  bool isRunning = false;
  bool isScheduled = false;
  bool wasScheduledStart = false;
  final List<VoidCallback> _listeners;  // observer list
  VoidCallback? onScheduledStart;       // owner-supplied hook
}
```

Derived: `int get totalSeconds => hours * 3600 + minutes * 60 + seconds;`

`SavedTimer.toMap()` / `fromMap()` perform lossless DB round-trips for all
fields except `isScheduled` and `wasScheduledStart`, which are stored as `0|1`
ints.

---

## 4. Screen flows

### 4.1 List page (`TimerListPage`)

Lifecycle:

1. `initState()` → `_loadTimers()`.
2. `_loadTimers()` reads `timers` from SQLite, builds `SavedTimer` objects,
   wires each timer's `onScheduledStart` to `_onTimerScheduledStart`.
3. **Bug-fix hook (added):** any timer whose `scheduledTime` is in the past
   is queued for `rescheduleIfOverdue()` after the first frame.
4. Empty state: "No timers. Add one using the + button!"
5. Each timer card shows name, duration (`HH:MM:SS`), scheduled time (if any),
   and a delete button. Tapping the card opens the running page.

### 4.2 Add timer dialog (`AddTimerDialog`)

- Required: `name` (non-empty).
- Required: at least one of `{hours, minutes, seconds}` is `> 0`.
- Optional: `endMessage` (shown when timer ends).
- Optional: `scheduledTime` (date+time picker, must be future).
- On submit, builds `SavedTimer`, inserts to DB, appends to `_savedTimers`.

### 4.3 Running page (`TimerRunningPage`)

- Subscribes to its `SavedTimer` via `addListener(_onTimerUpdate)`.
- Animations: `waveController` (continuous wave) + `progressController`
  (smooth 1-second progress interpolation).
- Shows the formatted time overlaid with a `WaterWaveClipper` `ShaderMask`
  gradient (`#00D4FF` → `#0099FF` → `#0066FF`).
- Shows current Dhaka time (`UTC+6`) and date.
- Hides Start/Pause/Reset buttons when `wasScheduledStart == true`.
- When `remainingSeconds == 1` and the timer has an `endMessage`, opens a
  `barrierDismissible: false` modal with the NSU logo.

### 4.4 Greeting page (`GreetingPage`)

A fullscreen-friendly display showing a single greeting title and the live
Dhaka clock. Created via **Add Greeting Page** on the home page.

- **Background**: `images/greeting_page.png` (campus photo), with a
  top→bottom dark gradient overlay (`#000000 45% → 65% → 80%`) for legibility,
  plus a subtle radial cyan glow centered behind the title.
- **Title**: rendered with the `_GradientTitle` widget — a `ShaderMask`
  shimmer that animates from cyan (`#00D4FF`) → light cyan (`#80E5FF`) →
  white → back, looping every 3.5 s, with a soft cyan glow shadow.
- **Date**: full weekday + month + day + year (e.g. "Wednesday, July 29, 2026"),
  18–28 px depending on screen width.
- **Clock**: 12-hour Dhaka time (`UTC+6`) in a rounded translucent card with a
  cyan glow shadow, ticks every second.
- **Entrance animation**: 1.4 s fade-in combined with a 1.2 s slide-up and a
  1.6 s `easeOutBack` scale-in.
- **Footer**: "Powered by NSU IT" tagline in monospace at the bottom.
- **Fullscreen**: `F11` or the toolbar icon.

### 4.5 Navigation

```
TimerListPage (home/root)
   ├── push ──> TimerRunningPage   (per timer tap or scheduled auto-launch)
   └── push ──> GreetingPage       (per greeting tap)
```

The list page is the root. `TimerRunningPage` is named `timer-<id>` so it can
be identified on the route stack when auto-launched by a schedule;
`GreetingPage` is named `greeting-<id>`.

---

## 5. Lifecycle & observers

### 5.1 Countdown ticker

`SavedTimer.start()`:

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (remainingSeconds > 0) {
    remainingSeconds--;
    _notifyListeners();
  } else {
    stop();
  }
});
```

### 5.2 Schedule timer

`SavedTimer._scheduleTimer()`:

```dart
final difference = scheduledTime!.difference(now);
if (difference.isNegative) {
  _handleOverdueSchedule(now); // ← bug-fix branch (see §6)
  return;
}
_schedulerTimer = Timer(difference, () {
  isScheduled = false;
  _notifyListeners();
  onScheduledStart?.call();
  start();
});
```

### 5.3 Observer list

`_listeners` are invoked from `_notifyListeners()`. `TimerRunningPage` adds
itself in `initState()` and removes itself in `dispose()`. The list page does
**not** subscribe to changes; it rebuilds on explicit user actions.

### 5.4 Disposal

- `TimerListPage.dispose()` calls `timer.dispose()` on every saved timer.
- `SavedTimer.dispose()` cancels `_timer`, `_schedulerTimer`, and clears
  listeners.
- `TimerRunningPage.dispose()` also closes any in-flight end-message modal
  via `_closeModalSafely()` (post-frame callback to avoid popping mid-build).

---

## 6. Scheduled-timer bug fix (the headline behavior)

### 6.1 The bug

> "I schedule a timer for a future time. It starts automatically, but if I
> don't open the screen and the scheduled time passes, the timer never runs
> at all. I have to calculate the remaining time manually and start another
> timer manually."

### 6.2 Root cause

The original `_scheduleTimer()`:

```dart
if (difference.isNegative) {
  isScheduled = false;
  return;                  // ← silently drops the timer
}
```

The Dart `Timer` driving the schedule lived only in memory. If the app was
**closed** before the trigger fired (or in any scenario where the Dart isolate
restarted between scheduling and trigger), the timer object was gone and the
schedule was effectively lost.

There was also no logic to **compute** the remaining seconds — so even if the
app was open but the trigger fired while the user was looking at a different
screen, the running page was never pushed and the countdown was never
started.

### 6.3 Fix design

The fix has **three parts**, all of which compose together:

1. **Re-evaluate on launch.** When the list page loads timers from SQLite,
   any timer whose `scheduledTime` is in the past and `wasScheduledStart` is
   `true` is queued for `rescheduleIfOverdue()`.

2. **Compute remaining seconds.** `SavedTimer._handleOverdueSchedule(now)`:

   ```dart
   final elapsedSinceStart = now.difference(scheduledTime!).inSeconds;
   final recomputed        = totalSeconds - elapsedSinceStart;
   if (recomputed <= 0) {
     remainingSeconds = 0;       // entire duration has passed
     isScheduled = false;
     _notifyListeners();
     return;
   }
   remainingSeconds = recomputed > totalSeconds ? totalSeconds : recomputed;
   isScheduled = false;
   _notifyListeners();
   onScheduledStart?.call();    // push running page
   start();                     // begin countdown with remaining time
   ```

   This makes the timer run **from the moment it would have started**, minus
   the elapsed time. Result: the visible countdown is the **remaining**
   duration, exactly what the user asked for.

3. **Auto-route to the running page.** `TimerListPage._loadTimers()` now
   iterates overdue timers after the first frame and pushes a fresh
   `TimerRunningPage` for each. Combined with `start()` already being called
   inside `_handleOverdueSchedule`, the user lands directly on a ticking
   countdown — no manual math, no separate timer.

### 6.4 State after the fix

| Scenario                                            | Before                                              | After                                                |
|-----------------------------------------------------|-----------------------------------------------------|------------------------------------------------------|
| App open at trigger time                            | Worked (auto-routed).                               | Works.                                               |
| App closed at trigger time, reopened later          | Timer stuck, never ran.                             | Auto-routes, runs remaining time.                    |
| App open, user on different screen, trigger fires   | Worked (auto-routed).                               | Works.                                               |
| Schedule already fully elapsed before next launch   | Timer stuck at full duration.                       | Marked expired (`remainingSeconds = 0`).             |
| Schedule in the future                              | Worked.                                             | Works.                                               |

### 6.5 Edge cases handled

- `recomputed > totalSeconds` is clamped (defensive: scheduled very far in
  the past relative to its own duration).
- `recomputed <= 0` short-circuits without calling `start()` — avoids
  immediate `0 → stop()` churn.
- `rescheduleIfOverdue()` is a no-op if `isRunning == true`.
- The wiring order matters: the constructor runs `_scheduleTimer()` **before**
  `onScheduledStart` is assigned. We therefore do not rely on the constructor
  to fire the callback; we re-trigger it explicitly via
  `rescheduleIfOverdue()` after construction. See `_loadTimers()` for the
  orchestration.

---

## 7. UI / animation details

### 7.1 Water-wave clipper (`WaterWaveClipper`)

- Primary wave: `amplitude = 8 px`, `waveCount = 3` across width.
- Secondary wave (realism): `0.3 * 8 px` at `2.3×` frequency, `1.7×` phase.
- Phase shifts each frame using `_waveAnimation` (1.5s linear repeat).
- When `progress == 0` the path is empty; when `progress == 1` it fills the
  full rectangle.

### 7.2 Progress interpolation

`TimerRunningPage._onTimerUpdate()` recomputes `progress` every tick and
animates `_progressController` over 1 second (linear), avoiding jumpy UI.

### 7.3 Color palette

| Token                  | Hex       |
|------------------------|-----------|
| App bar / accents      | `#183f78` |
| Water top (cyan)       | `#00D4FF` |
| Water middle (blue)    | `#0099FF` |
| Water bottom (deep)    | `#0066FF` |
| Progress bar (filled)  | `#071642` |

---

## 8. Persistence layer (`DatabaseHelper`)

- Singleton: `DatabaseHelper.instance`.
- Lazy `_database` initialized on first access.
- On Windows/Linux, `sqfliteFfiInit()` is called and `databaseFactory` is
  swapped to `databaseFactoryFfi`.
- File: `timers.db` under the platform's default DB directory.
- API: `insertTimer`, `getAllTimers`, `deleteTimer`, `updateTimer`, `close`.
- Schema version is currently **2**; bumping it requires extending
  `_upgradeDB` with new migrations.

---

## 9. Cross-platform notes

| Platform | DB backend                | Window controls                |
|----------|---------------------------|--------------------------------|
| Windows  | `sqflite_common_ffi`      | `window_manager` (fullscreen)  |
| Linux    | `sqflite_common_ffi`      | `window_manager` (fullscreen)  |
| macOS    | `sqflite` (mobile path)   | `window_manager` (fullscreen)  |
| Web      | `sqflite` (in-memory)     | N/A                            |
| iOS      | `sqflite`                 | N/A                            |
| Android  | `sqflite`                 | N/A                            |

`window_manager` is initialized in `main()` via
`windowManager.ensureInitialized()`.

---

## 10. Testing

- `test/widget_test.dart` — smoke test that the app boots into the list
  page. (The default counter starter test was removed; it referenced a
  widget the project doesn't contain.)
- Recommended next additions:
  - Unit test for `SavedTimer._handleOverdueSchedule` with mocked `DateTime`.
  - Widget test for the running page with a fake `SavedTimer`.
  - Integration test that schedules a timer, closes/relaunches the app,
    and asserts the running page is auto-pushed.

---

## 11. Open questions / future work

- Should the end-message modal block auto-route for *subsequent* overdue
  scheduled timers, or queue them sequentially?
- Should we add a "max overdue" guard (e.g. if more than `2 × duration` has
  passed, drop the timer entirely instead of clamping)?
- Web support for the fullscreen toggle is currently a no-op via
  `window_manager`. Consider using `dart:html` `requestFullscreen` for web.

---

## 12. Changelog

| Date       | Change                                                                                              |
|------------|-----------------------------------------------------------------------------------------------------|
| 2026-07-29 | Initial `specs.md` documenting architecture, scheduling semantics, and the scheduled-timer bug fix. |
| 2026-07-29 | Added Greeting Page feature: `greetings` table (schema v3), `SavedGreeting` model, `AddGreetingDialog`, `GreetingPage` (campus background, shimmering gradient title, live 12h Dhaka clock), and a "Greeting Pages" section on the home page. |