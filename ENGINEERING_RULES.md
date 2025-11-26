# Development Guidelines for TsukiSound

**Version**: 3.0 (Updated for Audio System & Navigation Integration)
**Last Updated**: 2025-11-16

---

## 🌙 Philosophy

### Core Beliefs

* **Feeling over measuring** – Time should be *experienced*, not *calculated*.
* **Simplicity over complexity** – Every line must reveal calmness, not cleverness.
* **Safety first** – Audio features must protect user hearing and provide control.
* **Structure reflects philosophy** – Architecture should embody serenity and safety, not control.
* **Human-guided over AI-driven** – AI assists, but human intention defines meaning.
* **Design is rhythm** – Consistency and timing matter more than speed.

---

## 🌿 Simplicity Means

* Single visual or logical responsibility per file
* No premature optimization — prefer smoothness over speed
* Avoid clever tricks — aim for *readable poetry*
* If it breaks the flow of reading, refactor
* Use design tokens — no hardcoded colors or fonts

---

## 🛠️ Process

### 1. Planning & Staging

Define feature intent, scope, and implementation approach before coding.

Document in relevant places:
- Architecture decisions → `Docs/architecture/`
- Implementation guides → `Docs/implementation/`
- Troubleshooting → `Docs/trouble-*.md`

### 2. Implementation Flow

1. **Understand** — Read existing code and documentation first
2. **Design** — Use DesignTokens, follow singleton patterns for services
3. **Implement** — Write clean, well-documented code
4. **Test** — Verify on real device (especially for audio)
5. **Document** — Update relevant docs
6. **Commit** — Include meaning in the message with Claude Code attribution

### 3. When Stuck (After 3 Attempts)

Stop.
Document the issue in appropriate `Docs/trouble-*.md` or create new guide.

Then:
* Study at least 2 external references (Apple docs, WWDC sessions)
* Re-examine if the approach is too complex
* Simplify instead of adding control
* Ask: "What am I trying to make the user *feel*?"

---

## 🧩 Project-Specific Technical Rules

### arch-01: Architecture Principles

**Last Updated: 2025-11-16**

Core Flow:
```
UI (Views) → Services → Domain
```

**Key patterns:**
* **Singleton services** for app-wide state (AudioService, Activity management)
* **ObservableObject** for state publishing
* **@Published** properties for observable state
* **@EnvironmentObject** or **@Binding** for state injection
* **Protocol-based** abstractions where appropriate

Checklist:
* [ ] Services are singletons with `.shared` accessor
* [ ] Views observe state, don't manage it
* [ ] Commands are sent to services, state is published
* [ ] No business logic in Views

---

### arch-02: Audio System Architecture

**Last Updated: 2025-11-26 (Phase 2: Responsibility-Based Reorganization)**

**Responsibility-Based Directory Structure:**
```
Core/Audio/
├── Service/          # Entry point (API / Session)
│   ├── AudioService.swift
│   ├── AudioSessionManager.swift
│   └── LocalAudioEngine.swift
│
├── Synthesis/        # Sound generation
│   ├── AudioSourceProtocol.swift
│   ├── Oscillators/  # Basic waveform generators
│   ├── Signals/      # Signal processing primitives (Osc, Wave, Mix)
│   ├── PureTone/     # Pure tone presets & builders
│   └── Noise/        # Noise generators (white, bandpass, click masking)
│
├── Processing/       # Sound modification
│   ├── Effects/      # Reverb, filters, limiters
│   ├── Filters/      # Filter buses (FilterBus, ReverbBus)
│   └── Modifiers/    # Envelopes, LFOs, modulation
│
├── Mixing/           # Mixer buses
│   ├── FinalMixer.swift
│   └── FinalMixerOutputNode.swift
│
├── Playback/         # Playback control
│   └── Players/      # File players (TrackPlayer)
│
└── Presets/          # Sound presets
    └── UISoundPreset.swift
```

**Design Philosophy:**
* Directories named by **responsibility** (what they DO), not concepts (what they ARE)
* Signal flow: Service → Synthesis → Processing → Mixing → Playback
* Prevents "historical sedimentation" — each file has a clear responsibility category
* Scales cleanly: new oscillators go to Synthesis/Oscillators/, new effects to Processing/Effects/

**Rules:**
* Views NEVER create audio instances — always use `AudioService.shared`
* Views observe `@Published` properties: `isPlaying`, `outputRoute`, `systemVolume`
* Views send commands: `play()`, `stop()`, `updateSettings()`
* Audio continues during screen transitions
* All audio sources must implement suspend/resume

**Safety features (mandatory):**
* Route monitoring with auto-pause option
* User-configurable volume limit (-12dB to 0dB)
* Scheduled quiet breaks

See: `Docs/architecture/audio-system-spec.md`

---

### arch-03: Navigation Architecture

**Last Updated: 2025-11-16**

**Tab-based navigation with conditional UI:**
```swift
public enum Tab {  // Must be public
    case clock
    case audioPlayback
    case settings
}
```

**Rules:**
* Tab enum is **public** (defined in ContentView)
* Tab state passed via `@Binding` to child views
* **Clock screen**: Custom tab bar, no NavigationView
* **Audio / Settings**: NavigationView with toolbar, no tab bar
* Current page icon hidden from navigation
* Icons placed left/right using `.navigationBarLeading` and `.navigationBarTrailing`

**Navigation bar appearance:**
* scrollEdgeAppearance: transparent background, no blur
* standardAppearance: blur effect (`.systemUltraThinMaterialDark`)
* Font: rounded design via `fontDescriptor.withDesign(.rounded)`
* Large Title: 28pt bold, Inline Title: 17pt semibold
* shadowColor: `.clear` (no borders)

See: `Docs/implementation/navigation-design.md`

---

### arch-04: Domain Layer (World Concepts)

**Added: 2025-11-26**

The **Domain layer** contains core concepts that define the app's "world" — mathematical models, astronomical calculations, and conceptual representations that exist independently of UI or implementation details.

**Domain/Moon/ — Lunar System:**
```
Domain/Moon/
├── MoonPhaseCalculator.swift    # Astronomical calculations
├── MoonPainter.swift             # Geometric rendering logic
└── Templates/                    # Moon phase visual templates
```

**Rules:**
* Domain layer is **pure knowledge** — no UI dependencies, no SwiftUI imports
* World concepts live in Domain/, not SharedUI/ or Features/
* Moon系 is a **world concept**, not a UI component
* Features/ can use Domain concepts, but Domain never depends on Features
* If it defines "what the world is", it belongs in Domain/
* If it's "how we show the world", it belongs in Features/

**Examples:**
```
✅ Domain/Moon/MoonPhaseCalculator.swift  (astronomical math)
✅ Domain/Moon/MoonPainter.swift          (geometric rendering)
❌ SharedUI/Visual/Painters/Moon/         (was incorrectly placed)
✅ Features/Clock/Components/MoonGlyph.swift (UI presentation of moon)
```

**Philosophy:**
Domain represents the **truth** of TsukiUsagi's world. The moon's phase calculation is not a "shared UI component" — it's a fundamental fact about how time and lunar cycles relate in this app's universe.

---

### ui-01: Design System Usage

**Last Updated: 2025-11-16**

**Mandatory:**
* Use **DesignTokens** for ALL styling (colors, typography, spacing)
* NEVER use hardcoded values
* Use semantic naming (`textPrimary`, not `white`)

**Example:**
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
* `SettingsSection` — Section with title and card background
* `SettingsToggle` — Toggle with title and subtitle
* `SettingsStepper` — Stepper with value display

---

### ui-02: SwiftUI Best Practices

**Last Updated: 2025-11-16**

* Use `.onChange(of:)` for state observation (iOS 17+ syntax)
* Keep Views lightweight — delegate to ViewModels or Services
* Use `@MainActor` for UI-related classes
* Provide Preview implementations with mock data
* Use `@EnvironmentObject` for service injection

**Navigation bar:**
* Never use `UIFont.systemFont(ofSize:weight:design:)` — doesn't exist
* Use `fontDescriptor.withDesign(.rounded)` for rounded fonts
* Always set `shadowColor = .clear` to avoid unwanted borders

---

### audio-01: Audio Implementation Standards

**Last Updated: 2025-11-16**

**File format:**
* Use `.caf` (Core Audio Format) for iOS-native playback
* Float32 format, 48kHz sample rate
* Generate with `scripts/generate_test_tone.py`
* Ensure seamless looping (phase-aligned frequencies)

**Audio sources:**
* Implement `AudioSource` protocol
* Provide suspend/resume functionality
* Use shared `AudioState` for lifecycle management
* Register in `AudioService.register()` switch

**Testing:**
* MUST test on real device (simulators unreliable for audio routing)
* Test with headphones connected/disconnected
* Test with silent switch on/off
* Verify volume limiting works

See: `Docs/implementation/_guide-audio-system-impl.md`

---

### struct-01: File Organization

**Last Updated: 2025-11-16**

```
TsukiSound/
├── App/                          # Entry point
├── Core/                         # Core systems
│   ├── Audio/                    # Audio system
│   └── Services/                 # System services
├── Features/                     # Feature modules
│   ├── Clock/                    # Clock feature
│   └── Settings/                 # Settings feature
├── DesignSystem/                 # Design tokens
├── Resources/                    # Assets
└── Docs/                         # Documentation
    ├── architecture/             # Specs
    ├── implementation/           # Guides
    ├── runbook/                  # Procedures
    ├── changelog/                # Change logs
    └── trouble-*.md              # Troubleshooting
```

**Rules:**
* Each directory has one clear role
* No global utils — everything belongs to a feature or system
* Use descriptive, pluralized folder names
* Keep related files together

---

### quality-01: Code Quality Standards

**Last Updated: 2025-11-16**

**Commit messages:**
* Follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`
* Include Claude Code attribution footer
* Describe *why* changes improve UX, not just *what* changed

**Code review checklist:**
* [ ] DesignTokens used (no hardcoded colors/fonts)
* [ ] AudioService singleton pattern followed (no instances in Views)
* [ ] Navigation bindings correct (public Tab, @Binding)
* [ ] Audio file format correct (.caf, Float32, seamless loop)
* [ ] Suspend/resume implemented for audio sources
* [ ] Documentation updated

**Testing:**
* Visual verification in light/dark mode
* Real device testing for audio features
* Headphone connect/disconnect testing
* Silent switch testing

---

### docs-01: Documentation Standards

**Last Updated: 2025-11-16**

**Document types** (Fujiko structure):
* `_arch-*.md` — Architecture and design principles
* `_adr-*.md` — Architecture Decision Records
* `_guide-*.md` — Implementation guides
* `_runbook-*.md` — Operational procedures
* `structure-*.md` — Structure and organization
* `changelog-*.md` — Change history
* `trouble-*.md` — Troubleshooting guides
* `report-*.md` — Task reports

**Key documents:**
* `Docs/README.md` — Documentation index
* `Docs/architecture/audio-system-spec.md` — Audio system spec
* `Docs/implementation/navigation-design.md` — Navigation design
* `Docs/implementation/_guide-audio-system-impl.md` — Audio implementation guide

**Update requirements:**
* Document architecture decisions in relevant `_adr-*.md`
* Create implementation guides for complex features
* Document all troubleshooting in `trouble-*.md`
* Update `Docs/README.md` when adding new docs

---

## 🌕 Quality Gates

**Definition of Done:**
* [ ] Code follows architecture patterns (singleton for services, DesignTokens for UI)
* [ ] Tested on real device (especially audio features)
* [ ] Documentation updated
* [ ] Commit message follows conventions
* [ ] Claude Code attribution included

**Before committing:**
* [ ] No hardcoded colors/fonts
* [ ] No audio instances created in Views
* [ ] Navigation bar shadowColor set to .clear
* [ ] Tab enum is public
* [ ] Audio sources have suspend/resume

---

## 📊 Common Pitfalls

### ❌ DON'T

1. **Create audio instances in Views**
   ```swift
   // ❌ Wrong
   let engine = LocalAudioEngine()
   ```

2. **Hardcode colors or fonts**
   ```swift
   // ❌ Wrong
   .foregroundColor(.white)
   .font(.system(size: 16))
   ```

3. **Make Tab enum private**
   ```swift
   // ❌ Wrong
   private enum Tab { ... }
   ```

4. **Use non-existent UIFont API**
   ```swift
   // ❌ Wrong
   UIFont.systemFont(ofSize: 28, weight: .bold, design: .rounded)
   ```

5. **Forget navigation bar shadow**
   ```swift
   // ❌ Wrong - causes unwanted borders
   // (missing: appearance.shadowColor = .clear)
   ```

### ✅ DO

1. **Use AudioService singleton**
   ```swift
   // ✅ Correct
   @EnvironmentObject var audioService: AudioService
   audioService.play(preset: .clickSuppression)
   ```

2. **Use DesignTokens**
   ```swift
   // ✅ Correct
   .foregroundColor(DesignTokens.SettingsColors.textPrimary)
   .font(DesignTokens.SettingsTypography.itemTitle)
   ```

3. **Make Tab enum public**
   ```swift
   // ✅ Correct
   public enum Tab { ... }
   ```

4. **Use fontDescriptor for rounded fonts**
   ```swift
   // ✅ Correct
   let font = UIFont.systemFont(ofSize: 28, weight: .bold)
   let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
   let roundedFont = UIFont(descriptor: descriptor, size: 28)
   ```

5. **Clear navigation bar shadow**
   ```swift
   // ✅ Correct
   appearance.shadowColor = .clear
   ```

---

## 🔗 Reference Documentation

### Essential Reading
* `CLAUDE.md` — AI assistant guidance (single source of truth for Claude Code)
* `Docs/README.md` — Documentation index and naming conventions
* `Docs/architecture/audio-system-spec.md` — Audio system specification
* `Docs/implementation/navigation-design.md` — Navigation design patterns

### Implementation Guides
* `Docs/implementation/_guide-audio-system-impl.md` — Audio implementation
* `Docs/implementation/seamless-loop-audio-generation.md` — Audio file generation
* `Docs/implementation/natural-sound-presets-restoration.md` — Sound preset restoration

### Troubleshooting
* `Docs/trouble-audio-distortion-noise.md` — Audio distortion RCA
* `Docs/trouble-audio-no-sound-silent-switch.md` — Silent switch issues
* `Docs/_guide-error-resolution.md` — General error resolution

---

🌙 *These rules ensure every commit, every sound, and every interaction embodies serenity, safety, and thoughtful engineering.*
