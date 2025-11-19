# Claude Code Guidance for clock-tsukiusagi

**Version**: 3.0 (Updated for Audio System & Navigation Integration)
**Last Updated**: 2025-11-16

This file provides guidance to Claude Code (`claude.ai/code`) when working with code in this repository.

---

## Project Overview

**clock-tsukiusagi** is a SwiftUI-based minimalist clock app that visualizes time through the moon's position and sky tone, accompanied by calming natural sounds.

The app features:
- **Visual time representation**: Moon phase and position indicate current time
- **Ambient audio system**: Natural sound synthesis and audio file playback
- **Safety-first design**: Headphone monitoring, volume limiting, scheduled quiet breaks
- **Calm technology philosophy**: Focus on *feeling* time rather than measuring it

The project follows **Clean Architecture** with **feature-based organization** and a strong **Design System** foundation.

---

## Key Components

### Entry Points
* **App**: `clock-tsukiusagi/App/clock_tsukiusagiApp.swift`
* **Main View**: `clock-tsukiusagi/App/ContentView.swift` — Tab-based navigation (Clock, Audio, Settings)

### Design System
* **DesignTokens**: `DesignSystem/DesignTokens.swift` — Unified visual tokens for all UI
* **Settings Components**: `DesignSystem/SettingsComponents.swift` — Reusable settings UI components
* **Color System**: `DesignSystem/Color/` — Sky tones and semantic colors

### Core Systems
* **Audio Service**: `Core/Audio/AudioService.swift` — Singleton service managing all audio playback
* **Audio Engine**: `Core/Audio/Engine/LocalAudioEngine.swift` — AVAudioEngine wrapper
* **Route Monitor**: `Core/Services/Route/AudioRouteMonitor.swift` — Headphone/speaker detection
* **Volume Limiter**: `Core/Services/Volume/SafeVolumeLimiter.swift` — Output volume protection
* **Break Scheduler**: `Core/Services/Scheduler/QuietBreakScheduler.swift` — Scheduled quiet periods

### Features
* **Clock Screen**: `Features/Clock/Views/ClockScreenView.swift` — Main clock interface with moon visualization
* **Audio**: `Core/Audio/AudioTestView.swift` — Audio playback control interface
* **Settings**: `Features/Settings/Views/AudioSettingsView.swift` — Audio configuration UI

---

## Architecture

### Clean Architecture Layers

```
UI (Views) → Application (Services) → Domain (Audio Sources/Effects)
```

* **Domain layer** is pure: Audio sources, effects, and presets with no UI dependencies
* **Application layer**: AudioService, monitors, schedulers coordinate system behavior
* **UI layer**: Views observe service state via `@Published` properties and send commands

### Audio System Architecture

**Singleton Service Pattern**:
- `AudioService.shared` is the single source of truth for audio state
- Views observe `@Published` properties: `isPlaying`, `outputRoute`, `systemVolume`, etc.
- Views send commands: `play()`, `stop()`, `updateSettings()`
- Audio continues playing during screen transitions

**Component Hierarchy**:
```
AudioService (singleton)
├── LocalAudioEngine (engine lifecycle)
├── AudioRouteMonitor (output detection)
├── QuietBreakScheduler (scheduled breaks)
├── SafeVolumeLimiter (volume protection)
└── Audio Sources/Players
    ├── NaturalSoundSource (synthesis)
    └── TrackPlayer (file playback)
```

See: `Docs/architecture/audio-system-spec.md` for full specification

### Navigation Design

**Tab-based navigation with conditional UI**:
- **Clock screen**: Custom tab bar (upper portion), no NavigationView
- **Audio / Settings**: NavigationView with toolbar icons, no custom tab bar
- Current page icon is hidden from navigation
- Tab state managed in ContentView, passed via `@Binding`

See: `Docs/implementation/navigation-design.md` for full specification

---

## File Structure

```
clock-tsukiusagi/
├── App/                          # App entry point and main views
│   ├── clock_tsukiusagiApp.swift
│   └── ContentView.swift         # Tab navigation controller
├── Core/                         # Core systems and services
│   ├── Audio/                    # Audio system
│   │   ├── AudioService.swift    # Singleton service (main interface)
│   │   ├── AudioTestView.swift   # Test UI
│   │   ├── Engine/               # AVAudioEngine wrapper
│   │   ├── Sources/              # Sound generators (synthesis)
│   │   ├── Players/              # File players
│   │   ├── Effects/              # Audio effects (ADSR, LFO)
│   │   ├── Modulation/           # Modulation sources
│   │   ├── Presets/              # Sound presets
│   │   └── Session/              # AVAudioSession management
│   ├── Services/                 # System services
│   │   ├── Route/                # Audio route monitoring
│   │   ├── Volume/               # Volume limiting
│   │   ├── Scheduler/            # Quiet break scheduling
│   │   └── NowPlaying/           # Now Playing info
│   ├── Settings/                 # Settings models
│   ├── Astronomy/                # Moon phase calculations
│   ├── Activity/                 # Live Activity support
│   └── Extensions/               # Swift extensions
├── Features/                     # Feature modules
│   ├── Clock/                    # Clock screen
│   │   ├── Views/                # Clock UI
│   │   └── Components/           # Reusable clock components
│   └── Settings/                 # Settings screen
│       └── Views/                # Settings UI
├── DesignSystem/                 # Unified design system
│   ├── DesignTokens.swift        # Color, typography, spacing tokens
│   ├── SettingsComponents.swift # Reusable settings UI
│   └── Color/                    # Sky tones and color system
├── Resources/                    # Assets
│   ├── Audio/                    # Audio files (.caf format)
│   └── Localization/             # i18n resources
└── Docs/                         # Documentation
    ├── architecture/             # Architecture specs
    ├── implementation/           # Implementation guides
    ├── runbook/                  # Operational procedures
    ├── changelog/                # Change logs
    ├── reference-audio/          # Reference audio (dev only)
    └── trouble-*.md              # Troubleshooting guides
```

---

## Development Guidelines

### Audio System

**When implementing audio features:**
1. **Never create audio instances in Views** — Always use `AudioService.shared`
2. **Observe state, don't manage it** — Use `@EnvironmentObject` or `@Published` properties
3. **Send commands, not state** — Call `play()`, `stop()`, don't set `isPlaying` directly
4. **Test with real devices** — Simulators don't accurately reflect audio routing

**Audio file format:**
- Use `.caf` (Core Audio Format) for iOS-native playback
- Generate with `scripts/generate_test_tone.py`
- Ensure seamless looping (phase-aligned frequencies)

**Safety features:**
- Headphone-only mode: Auto-pause when headphones removed
- Volume limiting: User-configurable maximum output (-12dB to 0dB)
- Quiet breaks: Scheduled pause periods (configurable duration)

See: `Docs/implementation/_guide-audio-system-impl.md`

### Navigation & UI

**Navigation rules:**
1. **Tab enum is public** — Defined in ContentView, accessible everywhere
2. **Pass selectedTab via @Binding** — Views receive tab state and can modify it
3. **Conditional tab bar** — Only show on Clock screen
4. **Hide current page icon** — Don't show the icon for the page you're on
5. **Left/right icon placement** — Use `.navigationBarLeading` and `.navigationBarTrailing`

**Navigation bar appearance:**
- Scroll edge (top): Completely transparent background, no blur
- Standard (scrolled): Blur effect (`.systemUltraThinMaterialDark`), transparent background
- Font: Rounded design (`.withDesign(.rounded)`)
- Large Title: 28pt bold, Inline Title: 17pt semibold

See: `Docs/implementation/navigation-design.md`

### Design System

**Always use DesignTokens:**
```swift
// ✅ Correct
.foregroundColor(DesignTokens.SettingsColors.textPrimary)
.font(DesignTokens.SettingsTypography.itemTitle)
.padding(DesignTokens.SettingsSpacing.cardPadding)

// ❌ Wrong
.foregroundColor(.white)
.font(.body)
.padding(16)
```

**Reusable components:**
- `SettingsSection` — Section with title and card background
- `SettingsToggle` — Toggle with title and subtitle
- `SettingsStepper` — Stepper with title and value display

### Code Quality

**SwiftUI best practices:**
- Use `.onChange(of:)` for state observation (iOS 17+ syntax)
- Keep Views lightweight — delegate logic to ViewModels or Services
- Use `@MainActor` for UI-related classes
- Provide Preview implementations with mock data

**Commit guidelines:**
- Follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`
- Include Claude Code attribution in footer
- Be descriptive about *why* changes improve UX

### Comment & Log Standards

**✂️ Rule for Learning Comments (学習コメントの✂️運用ルール)**

To improve learning efficiency during development, all comments meant **only for personal understanding or debugging** must include a **✂️ mark**. This clearly distinguishes "comments to be removed before production" from "comments meant to remain."

```swift
// ✂️ This is a temporary learning comment
// This is a permanent documentation comment
```

**Workflow:**
1. Add ✂️ to all temporary learning comments
2. Before merging: Search "✂️" → delete all matches
3. Production code remains clean and professional

**Debug Log Emoji Rule (デバッグログ絵文字ルール)**

All debug logs that must be removed before production must include a specific emoji tag:

- **🔥** — Temporary debug logs (must be deleted)
- **🐛** — Bug investigation logs
- **🧪** — Experimental / testing logs

```swift
print("🔥 [Debug] Temporary trace log")
print("🐛 [Bug] Investigating issue #123")
print("🧪 [Test] Experimental feature enabled")
```

**Workflow:**
1. Add 🔥 / 🐛 / 🧪 to all temporary logs
2. Before merging: Search for these emojis → delete all
3. Production code stays clean and professional

This system avoids accidentally leaving noisy logs in the final code while maintaining debugging flexibility during development.

---

## Common Tasks

### Implementing a New Audio Source

1. Create source in `Core/Audio/Sources/`
2. Implement `AudioSource` protocol with suspend/resume
3. Add preset to `NaturalSoundPresets.swift`
4. Register in `AudioService.register()` switch statement
5. Add to picker in `AudioTestView`

See: `Docs/implementation/natural-sound-presets-restoration.md`

### Adding a Settings Option

1. Add property to `AudioSettings.swift`
2. Add UI control in `AudioSettingsView` using DesignTokens
3. Wire binding to settings state
4. Call `saveSettings()` on value change
5. Handle in `AudioService.updateSettings()`

### Debugging Audio Issues

**No sound:**
1. Check silent switch (device setting)
2. Verify `AVAudioSession` category: `.playback` with `.mixWithOthers`
3. Check if headphone-only mode is enabled
4. Verify volume limiter isn't at -∞

**Distortion/noise:**
1. Check buffer format (Float32, not Int16)
2. Verify sample rate matches session (48kHz typical)
3. Check for AVAudioUnitDistortion — remove if not needed
4. Force audio graph rebuild if switching between sources

See: `Docs/trouble-audio-distortion-noise.md`

---

## Documentation References

### Architecture & Specs
* `Docs/architecture/audio-system-spec.md` — Complete audio system specification
* `Docs/implementation/navigation-design.md` — Navigation bar and tab integration

### Implementation Guides
* `Docs/implementation/_guide-audio-system-impl.md` — Audio system implementation guide
* `Docs/implementation/seamless-loop-audio-generation.md` — Audio file generation for seamless loops
* `Docs/implementation/natural-sound-presets-restoration.md` — Restoring natural sound presets

### Troubleshooting
* `Docs/trouble-audio-distortion-noise.md` — Audio distortion RCA
* `Docs/trouble-audio-no-sound-silent-switch.md` — Silent switch issues
* `Docs/_guide-error-resolution.md` — General error resolution checklist

### Other
* `Docs/README.md` — Documentation index with naming conventions
* `ENGINEERING_RULES.md` — Project-wide development rules (inherited from parent project)

---

## AI Assistant Collaboration

### What Claude Code Should Do

**Code Review:**
* Verify DesignTokens usage (no hardcoded colors/fonts)
* Check AudioService singleton pattern (no audio instances in Views)
* Ensure navigation bindings are correct (public Tab enum, @Binding propagation)
* Validate audio file format (.caf, Float32, seamless loop)

**Implementation:**
* Use DesignTokens for all UI styling
* Follow audio service command pattern (observe state, send commands)
* Implement navigation with conditional tab bar and toolbar icons
* Add suspend/resume for audio sources
* Generate commit messages with Claude Code attribution

**Debugging:**
* Check audio session configuration first
* Verify route monitoring is active
* Test on real device for audio issues
* Check navigation bar appearance settings

### What Claude Code Should NOT Do

* Create audio instances in Views (use AudioService.shared)
* Hardcode colors, fonts, or spacing (use DesignTokens)
* Modify Tab enum to private (must be public)
* Use UIFont.systemFont(ofSize:weight:design:) (doesn't exist — use fontDescriptor.withDesign)
* Skip navigation bar shadowColor setting (causes unwanted borders)

---

## Quick Reference Commands

### Build
```bash
xcodebuild -project clock-tsukiusagi.xcodeproj \
           -scheme clock-tsukiusagi \
           -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Generate Audio Files
```bash
python3 scripts/generate_test_tone.py
```

### Custom Slash Commands
* `/fn` — Generate date-based log filename for documentation

---

## Version History

* **v3.0** (2025-11-16): Updated for navigation integration, design system unification
* **v2.0** (2025-11-10): Added audio system architecture
* **v1.0**: Initial version

---

🌙 *This guide ensures Claude Code assistance stays faithful to the calm, safety-first, and well-structured essence of clock-tsukiusagi.*
