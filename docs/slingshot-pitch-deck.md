# Reflex — AMD Slingshot Pitch Deck

## Slide 1: Title
- Reflex: AI-Powered Cognitive Load Intelligence for Sustainable Productivity
- Theme: Future of Work & Productivity
- Tagline: Know when your brain needs a break. No wearable needed.

## Slide 2: Problem
- Students and early professionals often detect overload too late, after errors and fatigue rise.
- Existing productivity tools mostly track time and tasks, not cognitive state.
- Wearable-first approaches add hardware friction and cost.
- Cloud-first wellness apps create data privacy concerns.

## Slide 3: Solution
- Reflex is a native macOS, on-device AI companion that detects overload in real time from interaction behavior.
- It predicts cognitive load and triggers interventions before burnout degrades output quality.
- All inference stays local: no keystroke content capture, no cloud dependence, no telemetry.

## Slide 4: Why This Is AI
- Continuous behavioral sensing: typing rhythm, corrections, pauses, mouse jitter, scroll chaos, context switches.
- Personal baseline calibration for user-specific scoring.
- Weighted inference + fatigue factor + smoothing into a live 0-100 load score.
- Decision policy engine maps score patterns to adaptive interventions.
- Explainable and privacy-first edge AI.

## Slide 5: Product Workflow
- User works normally.
- Reflex captures non-content interaction events.
- Features are computed every few seconds.
- Cognitive load score updates continuously.
- Trigger logic launches load-based, time-based, or eye-rest intervention flow.
- Session analytics summarize outcomes and trends.

## Slide 6: Features
- Real-time cognitive load score (0-100, 5-second cadence).
- Personal baseline calibration (~15 minutes).
- Three independent break triggers: load-based reminder, time-based safety break, and eye-rest reminder (20-20-20).
- Natural break auto-detection (idle >= 2 minutes).
- Hydration reminders.
- Dashboard with trends, heatmaps, and CSV export.

## Slide 7: Pilot Metrics (Judge-Facing KPI Slide)
- Primary KPI: reduction in high-load minutes per focused session.
- Recovery KPI: increase in timely break adherence after prompts.
- Quality KPI: reduction in context-switch bursts during deep work windows.
- Wellness KPI: reduction in self-reported end-session fatigue (1-5 scale).
- Adoption KPI: weekly active days and average session duration.
- Privacy KPI: 100% local processing, 0 bytes of user behavioral data sent externally.

## Slide 8: Architecture
- Client-only architecture on macOS.
- Pipeline: event monitors -> feature extraction -> inference engine -> intervention orchestrator -> dashboard + local persistence.
- Storage path: `~/Library/Application Support/Reflex/`.
- No backend required for core product behavior.

## Slide 9: AMD Product Usage and Roadmap
- Phase 1 (current): local macOS inference and intervention engine.
- Phase 2 (Slingshot roadmap): optimize model path for AMD Ryzen AI PC targets, leveraging on-device AI acceleration.
- Phase 3: train/evaluate richer behavioral models with AMD GPU/ROCm workflows, then deploy lightweight edge variants.
- Value to AMD ecosystem: privacy-preserving, edge-first productivity AI aligned with AI PC adoption.

## Slide 10: Impact and Ask
- Reflex shifts productivity culture from reactive burnout management to proactive cognitive resilience.
- Immediate value for students, researchers, and early professionals.
- Scalable to campus-wide wellbeing and productivity programs without centralized personal-data collection.
- Ask: mentorship, pilot partnerships, and AMD ecosystem support for cross-platform edge AI deployment.
