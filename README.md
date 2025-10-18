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

* **🌅 Dawn**: 04:00–08:00
* **☀️ Day**: 08:00–16:00
* **🌆 Dusk**: 16:00–20:00
* **🌙 Night**: 20:00–04:00

---

## 🎨 Design System

### Color Palette

* **Dawn**: Deep blue → Bright blue
* **Day**: Light blue → White
* **Dusk**: Orange → Deep blue
* **Night**: Deep blue → Black

### Messages

* **Dawn**: “Begin softly.”
* **Day**: “Keep a steady rhythm.”
* **Dusk**: “Unwind gently.”
* **Night**: “It’s a gentle hour.”

---

## 🚀 Setup

### Requirements

* iOS 17.0+
* Xcode 16.0+
* Swift 5.9+

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/clock-tsukiusagi.git
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
├── Core/                   # Shared utilities
│   └── Extensions/
├── DesignSystem/           # Design system
│   ├── Color/
│   └── Typography/
├── Features/               # Feature-based modules
│   └── Clock/
│       ├── Components/     # UI components
│       ├── Painters/       # Canvas drawing logic
│       └── Views/          # SwiftUI views
└── Resources/              # Resource files
    └── Localization/
```

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
[Issues](https://github.com/your-username/clock-tsukiusagi/issues).

---

**Quiet Clock** – Feel time beautifully. 🌙
