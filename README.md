# 🌙 Quiet Clock

**A minimalist clock app for feeling time—quietly.**

Quiet Clock is designed not to *measure* time, but to *feel* it.
It expresses the passage of time through the moon’s position and the tone of the sky, offering a calm and elegant experience of time.

---

## ✨ Features

* **🌙 Moon Position Visualization**: Maps time to an angle (0°–360°) and displays it as the moon’s position.
* **🎨 Sky Tone Gradients**: Four beautiful color palettes for morning, day, evening, and night.
* **💭 Gentle Messages**: Soft, time-based messages for each phase of the day.
* **🌊 Wave Animation**: Elegant wave motion at the bottom of the screen that mirrors the flow of time.
* **📱 Minimal UI**: A clean, single-screen experience.

---

## 🏗️ Architecture

```
QuietClockView (SwiftUI)
 ├─ QuietClockVM (Observable)
 │    ├─ time: Date
 │    ├─ phaseAngle: Double        // Moon position (0°–360°)
 │    ├─ skyTone: SkyTone          // Dawn / Day / Dusk / Night
 │    ├─ caption: String           // Message based on the time of day
 │    └─ tick()                    // Timeline update handler
 └─ MoonPainter (Canvas helper)
      └─ drawMoon(phaseAngle, skyTone)
```

---

## 🧮 Mathematical Model of Time

### Phase Angle (Moon Position)

```
θ = (hour × 60 + minute) / 1440 × 360°
```

* 0:00 = 0°
* 6:00 = 90°
* 12:00 = 180°
* 18:00 = 270°

### Sky Tone

* **🌅 Dawn**: 04:00–08:00 (purple-tinted deep blue)
* **☀️ Day**: 08:00–16:00 (water blue gradient)
* **🌆 Dusk**: 16:00–18:00 (deep navy)
* **🌙 Night**: 18:00–04:00 (deepest navy/black)

---

## 🎨 Design System

### Color Palette

* **Dawn**: `#293f72` → `#ca9cff` (purple-tinted night sky)
* **Day**: `#3a61a1` → `#b6d7ff` (water blue)
* **Dusk**: `#0F1420` → `#1A2030` (deep navy)
* **Night**: `#0B0F18` → `#141A26` (deepest navy)

---

## 🚀 Setup

### Requirements

* iOS 17.0+
* Xcode 16.0+
* Swift 5.9+

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/azu-azu/clock-tsukiusagi.git
   cd clock-tsukiusagi
   ```
2. Open the project in Xcode:

   ```bash
   open clock-tsukiusagi.xcodeproj
   ```
3. Build and run on simulator or device.

---

## 📁 Project Structure

```
clock-tsukiusagi/
├── App/                    # Application entry point
├── Core/                   # Core systems and services
│   ├── Audio/              # Audio system (Service, Synthesis, Processing, Mixing, Playback, Presets)
│   ├── Services/           # System services (Route, Volume, Scheduler, NowPlaying)
│   ├── Settings/           # Settings models
│   └── Extensions/         # Swift extensions
├── Domain/                 # World concepts (pure knowledge)
│   └── Moon/               # Lunar system (MoonPhaseCalculator, MoonPainter, Templates)
├── DesignSystem/           # Design system
│   ├── Color/              # Sky tones and semantic colors
│   ├── DesignTokens.swift  # Unified visual tokens
│   └── SettingsComponents.swift
├── Features/               # Feature-based modules
│   ├── Clock/              # Clock screen
│   │   ├── Components/     # UI components (MoonGlyph, etc.)
│   │   ├── Animations/     # Clock-specific animations
│   │   └── Views/          # SwiftUI views
│   ├── Audio/              # Audio feature
│   │   ├── Views/          # Audio playback UI
│   │   ├── Components/     # Audio-specific UI (CircularWaveformView)
│   │   └── LiveActivity/   # Live Activity support
│   └── Settings/           # Settings screen
│       ├── Views/          # Settings UI
│       └── Components/     # Settings-specific components
├── SharedUI/               # Pure, reusable UI primitives (3+ Feature reuse only)
│   └── Primitives/         # Visual primitives (DotGrid, etc.)
└── Resources/              # Resource files
    ├── Audio/              # Audio files (.caf format)
    └── Localization/       # i18n resources
```

---

## 📖 Documentation

All documentation is located in `clock-tsukiusagi/Docs/`:

### Architecture & Specs
* `Docs/architecture/` — Architecture specifications and ADRs
* `Docs/architecture/audio-system-spec.md` — Complete audio system specification
* `CLAUDE.md` — Claude Code guidance (architecture overview)
* `ENGINEERING_RULES.md` — Development rules and architectural principles

### Implementation Guides
* `Docs/implementation/` — Implementation guides (prefix: `_guide-*.md`)
* `Docs/implementation/_guide-audio-system-impl.md` — Audio system implementation
* `Docs/implementation/navigation-design.md` — Navigation bar and tab integration

### Troubleshooting
* `Docs/trouble-*.md` — Troubleshooting guides for common issues

---

## 🔧 Development

### Build

```bash
# Debug build
xcodebuild -project clock-tsukiusagi.xcodeproj -scheme clock-tsukiusagi -configuration Debug

# Release build
xcodebuild -project clock-tsukiusagi.xcodeproj -scheme clock-tsukiusagi -configuration Release
```

### Test

```bash
# Run unit tests
xcodebuild test -project clock-tsukiusagi.xcodeproj -scheme clock-tsukiusagi
```

---

## 🌐 Localization

Supported languages:

* 🇺🇸 English (Base)
* 🇯🇵 Japanese

To add a new language, create an `.lproj` folder under `Resources/Localization/`.

---

## 📝 License

This project is released under the MIT License.
See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

We welcome pull requests and issue reports!
Before contributing, please review the following steps:

1. Fork the repository and create a new branch
2. Commit your changes
3. Open a pull request

---

## 📞 Support

If you encounter issues or have questions, please open a ticket in
[Issues](https://github.com/azu-azu/clock-tsukiusagi/issues).

---

**Quiet Clock** – Feel time beautifully. 🌙
