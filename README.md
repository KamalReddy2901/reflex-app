# Reflex Beta — Cognitive Load Monitor

**Know when your brain needs a break. No wearable needed.**

Reflex Beta is a native macOS menu bar app that passively monitors your typing patterns, mouse behavior, app switching, and scroll activity to infer your cognitive load in real-time. It nudges you to take breaks before burnout hits.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Real-time cognitive load scoring** — 0–100 scale based on behavioral signals
- **Menu bar monitor** — always-visible score with quick status popover
- **Glassmorphic dashboard** — session history, insights, and metric trends
- **Smart break system** — DeskRest-style cursor follower, notification popup, and fullscreen overlay with breathing exercises
- **Time-based break reminders** — triggers after continuous focus (default 25 min), regardless of cognitive load score
- **Eye rest reminders (20-20-20 rule)** — full-screen overlay every 40 min prompting a 20-second eye break with cursor-following countdown, skippable
- **Fatigue-aware scoring** — cognitive load score naturally increases with sustained work duration (30+ min), ensuring breaks are recommended even during steady "flow" sessions
- **Natural break detection** — automatically credits idle periods (2+ min) as micro-breaks, resetting break timers
- **Context switch tracking** — app switches, desktop/space switches, and window title changes
- **Personal baseline calibration** — learns your normal patterns in 15 minutes
- **Hydration reminders** — optional gentle system notification to drink water (configurable interval)
- **Smart escalation** — tracks consecutive skipped breaks for more insistent reminders
- **100% local** — no data leaves your Mac, ever

## What It Measures

| Signal | What It Tells Us |
|--------|-----------------|
| Typing rhythm variance | Mental consistency — erratic timing = high load |
| Backspace ratio | Error rate — more corrections = struggling |
| Inter-key pauses | Hesitation frequency — thinking hard |
| Mouse jitter | Physical tension — shaky movement = stress |
| Scroll behavior | Scanning vs reading — rapid reversals = searching |
| Context switches | Focus fragmentation — rapid switching = overload |
| Continuous focus duration | Fatigue factor — longer sessions = higher baseline load |

## Installation

1. Download **Reflex-Beta-3.1.dmg** from [Releases](../../releases/latest)
2. Open the DMG and drag **Reflex Beta** to **Applications**
3. **Right-click** Reflex Beta.app → **Open** (required first time only since the app is not notarized)
4. Click **Open** when macOS asks for confirmation
5. Grant **Accessibility** permission when prompted — this is required for monitoring keyboard and mouse patterns

> Requires macOS 15.0 (Sequoia) or later.

## How It Works

Reflex Beta uses a weighted heuristic engine to compute cognitive load:

```
Load Score = Typing Variance (25%)
           + Error Rate (20%)
           + Context Switches (20%)
           + Mouse Jitter (15%)
           + Pause Frequency (10%)
           + Scroll Chaos (10%)
           + Fatigue Factor (up to +25 bonus after 30+ min)
```

Scores are smoothed with an exponential moving average and calibrated against your personal baseline (established during the first 15 minutes of use).

### Break System

Reflex Beta uses **three independent break triggers**:

1. **Cognitive load-based** — when accumulated high-load time reaches 5+ minutes in a 30-minute window
2. **Time-based** — after 25 minutes of continuous activity (configurable: 20–60 min), regardless of load score
3. **Eye rest** — every 40 minutes of focus (configurable: 20–60 min), a quick 20-second eye break

When a break is triggered, Reflex Beta:

1. Shows a small **cursor-following countdown** ring (15–30s)
2. Pops up a **notification card** with Start/Snooze/Skip options
3. If you start a break: displays a **fullscreen overlay** with a breathing exercise (4-4-4 cycle) and countdown timer
4. If you skip: shows a gentle "We understand" message (click anywhere to dismiss)

**Eye rest** follows the same flow but shows a 20-second "Give Rest to Your Eyes" overlay instead.

Natural breaks (2+ minutes of no input) are automatically detected and credited, resetting all break timers.

Break durations are configurable (2, 5, or 10 minutes). Breathing exercises can be toggled off.

## Privacy

- **No keystrokes recorded** — only timing between keys
- **No screenshots** — only input event patterns
- **No network calls** — zero data transmission
- **No analytics** — no telemetry of any kind
- All data stored locally in `~/Library/Application Support/Reflex/`

## Building from Source

```bash
# Install xcodegen if you don't have it
brew install xcodegen

# Clone and build
git clone https://github.com/YOUR_USERNAME/reflex.git
cd reflex
xcodegen generate
open Reflex.xcodeproj
# Press ⌘R in Xcode to build and run
```

Requires Xcode 16+ and macOS 15.0+ SDK.

## License

MIT — do whatever you want with it.

---

*Built for humans who forget to take breaks.*
