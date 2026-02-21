# Reflex — Cognitive Load Monitor

**Know when your brain needs a break. No wearable needed.**

Reflex is a native macOS menu bar app that passively monitors your typing patterns, mouse behavior, app switching, and scroll activity to infer your cognitive load in real-time. It nudges you to take breaks before burnout hits.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Real-time cognitive load scoring** — 0–100 scale based on behavioral signals
- **Menu bar monitor** — always-visible score with quick status popover
- **Glassmorphic dashboard** — session history, insights, and metric trends
- **Smart break system** — DeskRest-style cursor follower, notification popup, and fullscreen overlay with breathing exercises
- **Context switch tracking** — app switches, desktop/space switches, and window title changes
- **Personal baseline calibration** — learns your normal patterns in 15 minutes
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

## Installation

1. Download **Reflex-1.0.dmg** from [Releases](../../releases/latest)
2. Open the DMG and drag **Reflex** to **Applications**
3. **Right-click** Reflex.app → **Open** (required first time only since the app is not notarized)
4. Click **Open** when macOS asks for confirmation
5. Grant **Accessibility** permission when prompted — this is required for monitoring keyboard and mouse patterns

> Requires macOS 15.0 (Sequoia) or later.

## How It Works

Reflex uses a weighted heuristic engine to compute cognitive load:

```
Load Score = Typing Variance (25%)
           + Error Rate (20%)
           + Context Switches (20%)
           + Mouse Jitter (15%)
           + Pause Frequency (10%)
           + Scroll Chaos (10%)
```

Scores are smoothed with an exponential moving average and calibrated against your personal baseline (established during the first 15 minutes of use).

### Break System

When you've been under high cognitive load for too long, Reflex:

1. Shows a small **cursor-following countdown** ring
2. Pops up a **notification card** with Start/Snooze/Skip options
3. If you start a break: displays a **fullscreen overlay** with a breathing exercise (4-4-4 cycle) and countdown timer
4. If you skip: shows a gentle "We understand" message (click anywhere to dismiss)

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
