https://reflexapp.pages.dev/

# Reflex Beta — Cognitive Load Monitor

**Know when your brain needs a break. No wearable needed.**

Reflex Beta is a native macOS menu bar app that observes typing rhythm, mouse dynamics, switching behavior, and session duration to estimate cognitive load in real time. It helps people protect focus, reduce context-friction, and recover before mental fatigue compounds.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Why Reflex Beta

Digital work often breaks down through invisible overload: frequent task jumping, rising error rates, and long uninterrupted stretches with no recovery. Reflex Beta turns those hidden patterns into a clear, live signal and triggers interventions at the right moment.

It is designed for high-context daily work where attention quality matters: writing, coding, analysis, planning, study-heavy routines, and collaborative execution.

## Core Features

- **Real-time cognitive load scoring** — 0–100 scale from behavioral signals
- **Menu bar monitor** — always-visible score with quick status popover
- **Dashboard with trends** — session history, insights, and key metrics
- **Smart break flow** — cursor follower, action popup, and full-screen break overlay
- **Time-based reminders** — independent focus-limit trigger even during steady flow
- **Eye-rest prompts** — optional 20-second visual recovery routine on interval
- **Fatigue-aware scoring** — session-length factor raises risk during prolonged activity
- **Natural break detection** — idle periods automatically reset timers
- **Context-switch tracking** — app, window-title, and workspace changes
- **Personal baseline calibration** — adapts to each individual pattern in ~15 minutes
- **Hydration reminders** — optional interval-based prompts
- **Fully local operation** — no cloud dependency, no account required

## Signal Model

| Signal | What It Indicates |
|--------|-------------------|
| Typing rhythm variance | Consistency drift and cognitive strain |
| Backspace ratio | Rising correction pressure |
| Inter-key pauses | Hesitation and heavier processing load |
| Mouse jitter/velocity variance | Motor instability under stress |
| Scroll reversals | Search turbulence and uncertainty |
| Context-switch rate | Attention fragmentation |
| Continuous focus duration | Fatigue accumulation over time |

## Real-World Outcome Focus

Reflex Beta is built around practical value, not vanity metrics:

- Protect uninterrupted concentration windows
- Cut avoidable context loss from overload spirals
- Improve consistency of output quality across long sessions
- Encourage sustainable work cadence with gentle, adaptive intervention

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/KamalReddy2901/reflex-app/releases/latest)
2. Open the DMG and drag **Reflex Beta** to **Applications**
3. **Right-click** Reflex Beta.app -> **Open** (first launch for unsigned app)
4. Confirm the macOS prompt
5. Grant **Accessibility** permission when prompted

> Requires macOS 15.0 (Sequoia) or later.

## How It Works

Reflex Beta uses weighted signal fusion to compute a live score:

```text
Load Score = Typing Variance (25%)
           + Error Rate (20%)
           + Context Switches (20%)
           + Mouse Jitter (15%)
           + Pause Frequency (10%)
           + Scroll Chaos (10%)
           + Fatigue Factor (up to +25 after sustained activity)
```

Scores are smoothed with exponential moving average and adjusted relative to a personal baseline captured during onboarding.

### Break Logic

Reflex Beta uses three independent triggers:

1. **Load-based trigger** — high strain sustained across a rolling time window
2. **Focus-duration trigger** — continuous activity threshold
3. **Eye-rest trigger** — periodic visual recovery interval

When triggered, Reflex Beta runs a staged flow:

1. Cursor-following countdown cue
2. Actionable popup (start, snooze, skip)
3. Guided full-screen break or eye-rest overlay

If you step away for 2+ minutes, the app counts it as a natural break and resets timers.

## Privacy

- **No key content capture** — only timing metadata
- **No screenshots or screen recording**
- **No telemetry pipeline**
- **No forced internet dependency**
- Data stored locally at `~/Library/Application Support/Reflex/`

## Repository Layout

This public repository (`reflex-app`) is used for:

- Landing website source (`site/`)
- Release distribution and install artifacts
- Public project documentation

Application source is maintained in a separate development repository:

- [KamalReddy2901/reflex](https://github.com/KamalReddy2901/reflex)

## Building from Source

If you have access to the development repository:

```bash
git clone https://github.com/KamalReddy2901/reflex.git
cd reflex
brew install xcodegen
xcodegen generate
open Reflex.xcodeproj
```

Requires Xcode 16+ and macOS 15.0+ SDK.

## License

MIT — see [LICENSE](LICENSE).

---

*Built for humans who forget to take breaks.*
