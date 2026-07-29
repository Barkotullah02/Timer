# Multi Timer (NSU IT)

A multi-timer Flutter application with a beautiful animated "water-fill" timer UI, scheduled start capability, persistent storage, and a customizable end-of-timer message. Built to be cross-platform (Windows, macOS, Linux, Web, iOS, Android) with native window controls for desktop builds.

> **Tagline:** _Powered by NSU IT_

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots / UI](#screenshots--ui)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Running the App](#running-the-app)
- [Usage Guide](#usage-guide)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Data Storage](#data-storage)
- [Build for Desktop / Mobile](#build-for-desktop--mobile)
- [Known Issues & Fixes](#known-issues--fixes)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

**Multi Timer** lets you create, save, and manage several countdown timers. Each timer can:

- Be **started manually** with start/pause/reset controls, or
- Be **scheduled** to auto-start at a specific date/time in the future, or
- Optionally show a **custom end-of-timer message** in a popup modal.

The running screen features a unique water-wave animation that fills up as time elapses, with a smooth animated progress bar and a live current-time / date display (in UTC+6 / Dhaka time).

---

## Features

| Feature                          | Description                                                                                       |
|----------------------------------|---------------------------------------------------------------------------------------------------|
| Create multiple timers           | Add any number of timers with custom names and durations.                                         |
| Persistent storage               | Timers are saved to a local SQLite database and survive app restarts.                             |
| Scheduled start                  | Schedule a timer to begin automatically at a future date/time.                                     |
| Auto-launch + remaining-time fix | Scheduled timers auto-route to the running screen and compute the **remaining** time accurately. |
| Custom end message               | Show a branded modal (with NSU logo) when a scheduled/manual timer hits `00:00:01`.               |
| Water-wave fill animation        | Animated cyan/blue liquid rising as the timer counts down.                                        |
| Smooth progress bar              | Animated linear progress bar at the bottom of the running screen.                                 |
| Fullscreen mode                  | Toggle fullscreen via toolbar button or `F11`.                                                    |
| Cross-platform                   | Runs on Windows, macOS, Linux, Web, iOS, Android.                                                 |

---

## Screenshots / UI

The project ships with three image assets in `images/`:

- `background_img.png` — dark background for the running screen.
- `logo.png` — main app logo.
- `nsu_logo.png` — NSU IT logo shown inside the end-of-timer modal.

(Add visual screenshots here after running the app once.)

---

## Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) `^3.5.4` (Dart SDK `^3.5.4`)
- **State management:** Built-in `StatefulWidget` + `setState`
- **Persistence:** [`sqflite`](https://pub.dev/packages/sqflite) + [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi) (desktop FFI) + [`path`](https://pub.dev/packages/path)
- **Window control:** [`window_manager`](https://pub.dev/packages/window_manager) (desktop fullscreen toggle)
- **Lints:** [`flutter_lints`](https://pub.dev/packages/flutter_lints) v4

---

## Project Structure

```
Timer/
├── lib/
│   ├── main.dart              # App entry, TimerListPage, AddTimerDialog, TimerRunningPage, SavedTimer model, WaterWaveClipper
│   └── database_helper.dart   # SQLite singleton for the `timers` table
├── images/                    # background_img.png, logo.png, nsu_logo.png
├── test/widget_test.dart      # Default Flutter widget test
├── web/                       # Web build assets
├── windows/                   # Windows desktop runner
├── macos/                     # macOS desktop runner
├── linux/                     # Linux desktop runner
├── device_timer_icon.ico      # Windows app icon
├── pubspec.yaml               # Dependencies & asset declarations
├── analysis_options.yaml      # Lint configuration
└── README.md                  # ← you are here
```

---

## Installation

### Prerequisites

- Flutter SDK (3.5.4 or newer): <https://docs.flutter.dev/get-started/install>
- Dart SDK (bundled with Flutter)
- Platform toolchain:
  - **Windows:** Visual Studio 2022 with "Desktop development with C++"
  - **macOS:** Xcode (for iOS/macOS)
  - **Linux:** `clang`, `cmake`, `ninja-build`, `libgtk-3-dev`

### Clone & install dependencies

```bash
git clone <your-repo-url> Timer
cd Timer
flutter pub get
```

---

## Running the App

Pick the device you want to run on (or start an emulator/simulator first):

```bash
flutter devices              # list available devices
flutter run -d <device-id>   # run on a specific device
```

Examples:

```bash
flutter run -d chrome                    # Web
flutter run -d macos                     # macOS desktop
flutter run -d windows                   # Windows desktop
flutter run -d linux                     # Linux desktop
```

---

## Usage Guide

1. **Launch the app** — you land on the **My Timers** list.
2. **Tap the `+` floating action button** to add a new timer.
3. Fill in:
   - **Timer Name** (required, e.g. "Workout")
   - **Hours / Minutes / Seconds** (all must not be `0`)
   - **End Message** (optional) — shown when the timer hits `00:00:01`
   - **Schedule Timer** (optional) — pick a future date/time
4. **Tap Add**. The timer is saved to SQLite and shown in the list.
5. **Tap a timer card** to open the **Timer Running** screen.
6. On the running screen:
   - Manual timers: use **Start / Pause / Reset**.
   - Scheduled timers: auto-start at the scheduled time (see fix below).
7. **Toggle fullscreen** from the toolbar or with `F11`.

---

## Keyboard Shortcuts

| Key   | Action                                |
|-------|---------------------------------------|
| `F11` | Toggle fullscreen (on either screen). |

---

## Data Storage

All timers are persisted in a local SQLite database (`timers.db`) with the schema:

| Column             | Type    | Notes                                          |
|--------------------|---------|------------------------------------------------|
| `id`               | INTEGER | PRIMARY KEY AUTOINCREMENT                      |
| `name`             | TEXT    | Display name                                   |
| `hours`            | INTEGER | Duration hours                                 |
| `minutes`          | INTEGER | Duration minutes                               |
| `seconds`          | INTEGER | Duration seconds                               |
| `scheduledTime`    | TEXT    | ISO-8601 string, nullable                      |
| `isScheduled`      | INTEGER | `1` if the schedule is still active, else `0`  |
| `wasScheduledStart`| INTEGER | `1` if timer was auto-launched by a schedule   |
| `endMessage`       | TEXT    | Optional modal message shown at `00:00:01`     |

Database location depends on platform:

- **Windows / Linux:** standard `getDatabasesPath()` from `sqflite_common_ffi`.
- **macOS / iOS / Android:** `getDatabasesPath()` from `sqflite`.

> If you reset the database during development, simply delete `timers.db` (and `timers.db-journal` if present) and restart the app — the schema is recreated automatically.

---

## Build for Desktop / Mobile

```bash
flutter build windows
flutter build macos
flutter build linux
flutter build web
flutter build apk
flutter build appbundle
flutter build ios
```

Output binaries appear under `build/<platform>/`.

---

## Known Issues & Fixes

### Issue: Scheduled timers never start if the app was closed at trigger time

**Symptom**
You scheduled a 30-minute timer for 14:00. At 13:55 you closed the app. At 14:05 you reopened the app — the timer card still says "Scheduled: …" and never auto-started, so it never counted down.

**Root cause**
The original `_scheduleTimer()` only fired while the in-memory Dart `Timer` was alive. If the app was closed/restarted between scheduling and trigger time, the Dart timer was gone and the schedule was silently skipped (`difference.isNegative` branch only reset the flag).

**Fix**
On app launch, every saved scheduled timer is re-hydrated from SQLite and re-evaluated. If the scheduled time has **already passed**, we don't drop it — we instead compute the **remaining** seconds from the scheduled start until now (capped at the timer's full duration) and **auto-route** the user into the running screen with `start()` called on the recomputed countdown. From then on the regular `Timer.periodic` ticks it down to zero.

This is implemented in the `TimerListPage._loadTimers()` flow and in `SavedTimer._scheduleTimer()` / `SavedTimer.start()` — see [specs.md](./specs.md) for the full design.

---

## Roadmap

- [ ] Recurring scheduled timers (e.g. "every weekday at 09:00").
- [ ] Sound + vibration when a timer ends.
- [ ] Tray / system notification on timer end while app is minimized.
- [ ] Light/Dark theme toggle.
- [ ] Localization (currently English only).
- [ ] Import / export timer presets as JSON.

---

## License

This project is licensed under the terms described in [`LICENSE`](./LICENSE).

---

_Developed for NSU IT — "Powered by NSU IT"._