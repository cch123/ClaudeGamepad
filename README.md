# Claude Gamepad Controller

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-orange)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-red)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/xargin/ClaudeGamepad?style=social)](https://github.com/xargin/ClaudeGamepad)

A native macOS menu bar app that lets you control [Claude Code](https://claude.ai/claude-code) with a game controller. Lean back, vibe code from your couch.

Supports Xbox, PS5 DualSense, and any MFi-compatible controller. Includes voice input via Apple Speech Recognition or local [whisper.cpp](https://github.com/ggerganov/whisper.cpp), with optional LLM-powered speech correction.

## Why Claude Gamepad?

Ever wanted to code from your couch? Claude Gamepad brings the comfort of game controllers to AI-assisted coding. No more hunching over your keyboard—use a controller to navigate Claude Code while standing, stretching, or relaxing.

**Perfect for:**
- Developers with RSI or mobility considerations
- Standing desk setups
- Living room coding sessions
- Voice-first workflows with hands-free control

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Screenshots](#screenshots)
- [Default Button Mapping](#default-button-mapping)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Voice Input](#voice-input)
- [Vibe Island / Overlay Navigation](#vibe-island--overlay-navigation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Architecture](#architecture)
- [License](#license)

## Quick Start

Get up and running in under 5 minutes:

```bash
# 1. Clone and build
git clone https://github.com/xargin/ClaudeGamepad.git
cd ClaudeGamepad
swift build -c release

# 2. Run the app
swift run

# 3. Grant permissions when prompted
# - Accessibility (for keyboard simulation)
# - Speech Recognition (for voice input)
```

Connect your controller, focus your Claude Code terminal, and start coding!

## Features

- **Menu bar app** - runs in the background, no Dock icon
- **Plug and play** - auto-detects Xbox / PS5 / MFi controllers via `GCController`
- **Xbox / PS5 style toggle** - switch button labels and colors across the entire UI
- **Full button mapping** - every button configurable via GUI settings
- **Voice input** - press stick to speak, transcription pasted to terminal
  - System speech recognition (zero setup)
  - Local whisper.cpp (higher quality, offline)
  - Optional LLM refinement (Ollama / OpenAI compatible)
- **Quick prompts** - LT/RT + face button sends preset prompts
- **Command combos** - hold LT+RT to enter command mode with Helldivers or fighting game style input sequences
- **Preset menu** - Start button opens D-pad-navigable prompt list
- **Overlay navigation** - a configurable Guide Key Combo can open Vibe Island or similar overlays, then temporarily route D-pad arrows to the frontmost overlay
- **Combo prefix conflict detection** - settings UI warns when one combo shadows another
- **Floating HUD** - non-intrusive overlay shows button feedback, combos, and transcription
- **macOS native** - pure Swift + AppKit, no Electron, no Python

## Screenshots

### Button Mapping

Configure your controller with an intuitive visual editor. All buttons are grouped by region—shoulders, face buttons, navigation, and system controls—for quick scanning and reassignment.

![Button Mapping](screenshots/button-mapping.png)

### Preset Prompts

Build your command palette. Edit all trigger combos from one focused workspace. Pick a preset or write custom text, with live character count and preview before you save.

![Preset Prompts](screenshots/quick-prompts.png)

### Speech Recognition

See the full voice pipeline at a glance. Check engine status, binary installation state, model download progress, and LLM cleanup toggle without opening multiple windows.

![Speech Recognition](screenshots/speech-recognition.png)

### Menu Bar

The app lives in your menu bar. A green indicator means your controller is connected and ready; gray means no controller detected.

![Menu Bar](screenshots/menu-bar.png)

## Default Button Mapping

| Button (Xbox / PS5) | Action |
|----------------------|--------|
| A / ✕ | Enter (confirm) |
| B / ○ | Ctrl+C (interrupt) |
| X / □ | Accept (y + Enter) |
| Y / △ | Reject (n + Enter) |
| D-pad | Arrow keys |
| LB / L1 | Tab (autocomplete) |
| RB / R1 | Escape |
| L3 / R3 Press | Voice input |
| Start / Options | Preset menu |
| Select / Create | `/clear` |
| LT / L2 + Face | Quick prompt (configurable) |
| RT / R2 + Face | Quick prompt (configurable) |
| LT+RT / L2+R2 | Command mode (combo input) |
| LT + RT + Select | Quit |

All mappings are fully customizable in Settings.

> **Note:** macOS reserves the hardware Guide / Home / PS button. If you want to open Vibe Island or another overlay from the controller, map any capturable button to the `Combo` action instead.

## Installation

### Requirements

- macOS 14.0 (Sonoma) or later
- A game controller (Xbox, PS5 DualSense, or MFi compatible)
- For Whisper (optional): `brew install whisper-cpp`

### Build from Source

```bash
git clone https://github.com/xargin/ClaudeGamepad.git
cd ClaudeGamepad
swift build -c release
# Binary at .build/release/ClaudeGamepad
```

### Run

```bash
swift run
```

Or build and copy to your PATH:

```bash
swift build -c release
cp .build/release/ClaudeGamepad /usr/local/bin/
```

## First Launch

1. Run `swift run` or the built binary
2. Grant **Accessibility** permission when prompted (System Settings > Privacy & Security > Accessibility) — needed for keyboard simulation
3. Grant **Speech Recognition** permission if using voice input
4. Connect your controller — the menu bar icon turns active
5. Focus your terminal running Claude Code
6. Start pressing buttons!

## Usage

### Basic Controls

| Action | Controller Input |
|--------|------------------|
| Navigate code | D-pad |
| Accept suggestion | X / □ |
| Reject suggestion | Y / △ |
| Trigger autocomplete | LB / L1 |
| Cancel / Interrupt | B / ○ |
| Send / Confirm | A / ✕ |

### Voice Input

1. Press **L3 / R3** (stick click)
2. Floating HUD shows "Listening..." with a live waveform
3. Speak your prompt (auto-detects Chinese and English)
4. HUD shows transcription with confirm/cancel options
5. Press **A / ✕** to paste to terminal, or **B / ○** to cancel

### Quick Prompts

Hold a trigger (LT or RT) and press a face button for instant commands:

| Trigger | Button | Command |
|---------|--------|---------|
| LT | A | `showtime` |
| LT | B | `fix the failing tests` |
| LT | X | `continue` |
| LT | Y | `undo the last change` |
| RT | A | `run the tests` |
| RT | B | `show me the diff` |
| RT | X | `looks good, commit this` |
| RT | Y | `add types and documentation` |

### Command Combos

Hold both triggers (LT+RT) to enter command mode. Input directional sequences to trigger actions:

**Helldivers 2 style** (D-pad only):
- ↑ ↓ → ← ↑ → "Reinforce" command

**Fighting game style** (D-pad + button):
- ↓ → A → "Hadouken" style action

## Configuration

Click the menu bar icon > **Settings** to open the settings window. The settings panel uses a dark-themed card layout with five tabs.

### General

Choose your **controller style** — Xbox or PS5. This changes all button labels and colors across the UI, overlays, and settings panels.

### Button Mapping

All button bindings organized by region: Shoulders, Face Buttons, Navigation, and System & Sticks. Each button has a dropdown to pick its action. LT/RT (L2/R2) serve as modifier keys, so their quick prompts are managed in the Preset Prompts tab. If you assign a button to `Combo`, the row expands to show the keyboard shortcut used to open an overlay window.

### Preset Prompts

The left panel lists all quick prompt slots (LT+A, LT+B, RT+A, etc.); the right panel is a focused editor. Each slot can use a preset prompt or custom text, with live character count and preview.

**Default Quick Prompts:**

| Trigger | Prompt |
|---------|--------|
| LT + A | showtime |
| LT + B | fix the failing tests |
| LT + X | continue |
| LT + Y | undo the last change |
| RT + A | run the tests |
| RT + B | show me the diff |
| RT + X | looks good, commit this |
| RT + Y | add types and documentation |

### Command Combos

Hold both triggers (LT+RT / L2+R2) to enter command mode. Input directional sequences to trigger preset prompts — two styles available:

- **Helldivers 2** — D-pad only sequences (e.g. ↑ ↓ → ← ↑ for "Reinforce")
- **Fighting Game** — D-pad + face button finisher (e.g. ↓ → A for "Hadouken")

A button-based input editor lets you build sequences by clicking, no Unicode typing needed. The settings UI detects and warns about prefix conflicts between combos.

### Speech Recognition

A top-level Voice Pipeline status bar shows engine, binary install state, model status, and LLM cleanup toggle at a glance. Below are two cards:

- **Whisper Local** — select a model (tiny 75MB to large-v3 3.1GB), one-click install binary, one-click download model
- **LLM Refinement** — configure API URL, API Key, and model name; works with Ollama, LM Studio, or any OpenAI-compatible endpoint

## Voice Input Flow

1. Press **L3 / R3** (stick click)
2. Floating HUD shows "Listening..." with a live waveform
3. Speak your prompt (auto-detects Chinese and English)
4. HUD shows transcription with confirm/cancel options
5. Press **A / ✕** to paste to terminal, or **B / ○** to cancel

## Vibe Island / Overlay Navigation

Use this when you want a controller button to open a keyboard-driven overlay such as Vibe Island.

1. In **Settings > Button Mapping**, assign any spare button to the `Combo` action.
2. Configure the keyboard shortcut for that action in the Guide Key Combo controls. The default is `⌘G`.
3. Trigger that button to open the overlay.
4. For a short window after the overlay opens, D-pad arrows are routed to the frontmost overlay app instead of your terminal.
5. If you click back into your terminal, the app stops reclaiming focus and arrow input returns to the terminal path.

## Troubleshooting

**Q: The controller opens Vibe Island but D-pad does nothing**
> Make sure Accessibility permission is granted and the overlay is actually frontmost after the combo fires.

**Q: The terminal loses focus after using an overlay**
> Current builds stop routing arrows to the overlay as soon as you manually switch back to the terminal.

**Q: The physical Guide / Home / PS button does not trigger anything**
> This is a macOS limitation. Bind another button to `Combo` and use that button to launch the overlay shortcut.

**Q: Voice input is not working**
> Check that Speech Recognition permission is granted in System Settings > Privacy & Security > Speech Recognition. For better quality, install whisper.cpp with `brew install whisper-cpp`.

**Q: Controller not detected**
> Make sure your controller is Mac-compatible. Xbox and PS5 controllers work best. MFi controllers should work but may have limited button support.

## Contributing

Contributions are welcome! Please read our guidelines before submitting:

### Development Setup

```bash
# Clone the repository
git clone https://github.com/xargin/ClaudeGamepad.git
cd ClaudeGamepad

# Build in debug mode
swift build

# Run with logging
swift run 2>&1 | tee debug.log
```

### Testing

1. Test with both Xbox and PS5 controllers if possible
2. Test voice input with both system speech and whisper.cpp
3. Test all button mappings after making changes
4. Verify the app works with Claude Code in a real terminal session

### Pull Request Guidelines

- Keep commits atomic and descriptive
- Update documentation if changing user-facing features
- Test on macOS 14.0+ before submitting
- Follow Swift code style conventions

## Architecture

For detailed system architecture, module relationships, and data flow documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

```
Sources/ClaudeGamepad/
├── main.swift              # Entry point (NSApplication.shared.run())
├── AppDelegate.swift       # Menu bar icon, permission handling
├── GamepadManager.swift    # Central coordinator, input routing
├── KeySimulator.swift     # Keyboard event generation
├── OverlayPanel.swift      # Floating HUD + WaveformView
├── SpeechEngine.swift      # SFSpeechRecognizer wrapper
├── WhisperEngine.swift     # whisper.cpp CLI wrapper
├── LLMRefiner.swift        # OpenAI-compatible API client
├── ButtonMapping.swift     # Configuration data model
├── SpeechSettings.swift   # Voice configuration model
├── GamepadConfigView.swift # Visual button editor component
└── SettingsWindow.swift   # Settings UI + ComboInputEditor
```

## License

MIT
