# Claude Gamepad Architecture

A native macOS menu bar application that enables game controller input for Claude Code, built with pure Swift and AppKit.

## Overview

Claude Gamepad transforms game controller input into keyboard events and text, allowing developers to control Claude Code hands-free. The application runs as a menu bar (Dock-less) app, detecting controllers automatically and providing voice input capabilities.

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| Platform | macOS 14.0 (Sonoma)+ |
| UI Framework | AppKit |
| Controller API | GameController.framework |
| Speech Recognition | SFSpeechRecognizer, whisper.cpp |
| Keyboard Simulation | CGEvent ( HID events), AppleScript |
| Build System | Swift Package Manager |

### Key System Frameworks

- **GameController** - GCController for gamepad input handling
- **Speech** - SFSpeechRecognizer for voice-to-text
- **AVFoundation** - Audio capture for speech recognition
- **AppKit** - All UI components (NSPanel, NSWindow, NSStatusBar)

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Gamepad                            │
│                    (Menu Bar Application)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌─────────────────────────────────────┐  │
│  │  AppDelegate │────▶│         GamepadManager                │  │
│  │  (Entry)    │     │  - GCController lifecycle            │  │
│  └──────────────┘     │  - Button event routing              │  │
│                       │  - Voice input orchestration         │  │
│                       └───────────────┬─────────────────────┘  │
│                                       │                          │
│        ┌──────────────────────────────┼──────────────────────┐  │
│        │                              │                      │  │
│        ▼                              ▼                      ▼  │
│  ┌─────────────┐            ┌──────────────┐        ┌─────────┐ │
│  │ KeySimulator│            │  OverlayPanel │        │ Speech  │ │
│  │             │            │   (HUD)      │        │ Engines │ │
│  │ - CGEvent   │            │              │        │         │ │
│  │ - AppleScript│           │ - Waveform   │        │ -Speech │ │
│  │ - Focus     │            │ - Messages   │        │ -Whisper│ │
│  │   routing   │            │ - Combo UI   │        │ -LLM    │ │
│  └─────────────┘            └──────────────┘        └─────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Settings Subsystem                      │  │
│  │  ┌──────────────┐  ┌────────────────┐  ┌──────────────┐  │  │
│  │  │ButtonMapping │  │ SpeechSettings │  │SettingsWindow│  │  │
│  │  │ (Config)     │  │   (Config)     │  │   (UI)       │  │  │
│  │  └──────────────┘  └────────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Claude Code    │
                    │  (Terminal)     │
                    └─────────────────┘
```

## Core Modules

### 1. GamepadManager (Central Coordinator)

**File**: `GamepadManager.swift`

The orchestrator that coordinates all subsystems. Acts as the single point of control for gamepad input.

**Responsibilities**:
- GCController discovery and lifecycle management
- Input event routing based on current mode (normal, voice, preset menu, command mode)
- Mode state management (voice active, preset menu open, command mode)
- Callback orchestration for speech engines

**Key States**:
```swift
isVoiceActive: Bool      // Voice input in progress
isInPresetMenu: Bool     // Preset prompt browser open
isInCommandMode: Bool   // Combo input mode (LT+RT held)
ltHeld / rtHeld: Bool   // Trigger modifier keys
```

**Input Flow**:
1. GCController button press detected
2. Handler invoked based on button (onButtonA, onDpadPress, etc.)
3. Mode-aware routing determines action
4. Execute via KeySimulator or voice subsystem

### 2. KeySimulator (Output Layer)

**File**: `KeySimulator.swift`

Converts controller input into keyboard events for Claude Code control.

**Mechanisms**:

| Method | Use Case | Mechanism |
|--------|----------|-----------|
| `pressKey()` | Single keys | CGEvent HID tap |
| `pressCombo()` | Modifier combos | AppleScript System Events |
| `pasteString()` | Text paste | Clipboard + Cmd+V |
| `typeString()` | Commands | Paste + Enter |
| `typeAccept/Reject()` | Claude suggestions | y/n + Enter |

**Overlay Navigation**:
- Monitors frontmost application PID
- Routes D-pad arrows to overlay windows temporarily
- 3-second capture window after combo fires

### 3. OverlayPanel (Feedback UI)

**File**: `OverlayPanel.swift`

Floating HUD that displays feedback without stealing terminal focus.

**Presentation Modes**:
- **Standard** - Brief action confirmations (2s auto-dismiss)
- **Listening** - Voice input with waveform visualization
- **Transcription** - Recognition result with confirm/cancel
- **PromptSheet** - Trigger cheat sheet (radial button layout)
- **CommandMode** - Combo input sequence display

**Design**:
- `NSPanel` with `.nonactivatingPanel` style
- `NSVisualEffectView` with vibrancy
- Positioned at screen bottom center
- Auto-positions to main screen

### 4. Speech Subsystem

**Files**: `SpeechEngine.swift`, `WhisperEngine.swift`, `LLMRefiner.swift`

Three-layer voice recognition pipeline:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Microphone │───▶│ Speech Engine │───▶│ LLM Refiner │
│   Input      │    │              │    │  (Optional) │
└─────────────┘    └──────────────┘    └─────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
     ┌─────────────┐           ┌─────────────┐
     │    Apple    │           │  whisper.cpp │
     │ SFSpeech    │           │   (CLI)      │
     │ Recognizer  │           │              │
     └─────────────┘           └─────────────┘
```

**SpeechEngine** (System):
- SFSpeechRecognizer with zh-Hans + en-US fallback
- Real-time partial results
- 15-second timeout

**WhisperEngine** (Local):
- External whisper.cpp CLI process
- Model management (tiny to large-v3)
- Supports offline operation

**LLMRefiner** (Optional):
- OpenAI-compatible API (Ollama, LM Studio)
- Speech post-processing/correction

### 5. Configuration System

**Files**: `ButtonMapping.swift`, `SpeechSettings.swift`

**ButtonMapping**:
- All button action bindings
- Trigger prompt presets (LT/RT + face)
- Command combo definitions
- Controller style (Xbox/PS5 label theme)
- JSON persistence to `~/Library/Application Support/ClaudeGamepad/config.json`

**SpeechSettings**:
- Engine selection
- Whisper model and binary paths
- LLM refinement configuration
- Persisted alongside button mapping

### 6. SettingsWindow (Configuration UI)

**File**: `SettingsWindow.swift`

Dark-themed card-based settings interface with sidebar navigation.

**Sections**:
1. **General** - Controller style selection (Xbox/PS5)
2. **Button Mapping** - Visual button editor
3. **Preset Prompts** - Trigger combo editor with preset picker
4. **Command Combos** - Combo sequence builder with conflict detection
5. **Speech Recognition** - Engine/model/LLM configuration

## Data Flow

### Button Press to Action

```
Controller Button
       │
       ▼
GamepadManager.onButtonX()
       │
       ▼
Check State Flags
       │
       ├──▶ isVoiceActive ──▶ A=Confirm, B=Cancel
       │
       ├──▶ isInPresetMenu ──▶ D-pad navigation, A=Select
       │
       ├──▶ isInCommandMode ──▶ Feed to comboBuffer
       │
       ├──▶ ltHeld ──▶ Execute LT prompt
       │
       ├──▶ rtHeld ──▶ Execute RT prompt
       │
       └──▶ Normal ──▶ ButtonMapping.buttonActions[x] → KeySimulator
```

### Voice Input Flow

```
Stick Click (L3/R3)
       │
       ▼
GamepadManager.startVoiceInput()
       │
       ▼
SpeechEngine.startListening() / WhisperEngine.startListening()
       │
       ▼
Audio Capture → Recognition
       │
       ▼
onPartialResult / onFinalResult callbacks
       │
       ▼
OverlayPanel.showMessage() / showListening()
       │
       ▼
User confirms with A button
       │
       ▼
KeySimulator.pasteString(text)
```

### Command Combo Flow

```
LT + RT held simultaneously
       │
       ▼
enterCommandMode()
       │
       ▼
D-pad / face button inputs → comboBuffer
       │
       ▼
Check against activeCombos (prefix match)
       │
       ├──▶ Exact match ──▶ Execute prompt
       │
       ├──▶ Partial match ──▶ Show sequence, reset timeout
       │
       └──▶ No match ──▶ Show error, reset buffer
```

## Directory Structure

```
Sources/ClaudeGamepad/
├── main.swift              # Entry point (NSApplication.shared.run())
├── AppDelegate.swift       # Menu bar icon, permission handling
├── GamepadManager.swift    # Central coordinator, input routing
├── KeySimulator.swift      # Keyboard event generation
├── OverlayPanel.swift      # Floating HUD + WaveformView
├── SpeechEngine.swift      # SFSpeechRecognizer wrapper
├── WhisperEngine.swift     # whisper.cpp CLI wrapper
├── LLMRefiner.swift        # OpenAI-compatible API client
├── ButtonMapping.swift     # Configuration data model
├── SpeechSettings.swift    # Voice configuration model
├── GamepadConfigView.swift # Visual button editor component
└── SettingsWindow.swift   # Settings UI + ComboInputEditor
```

## Key Design Patterns

### Singleton Pattern

All major subsystems use shared instances:
```swift
GamepadManager.shared
KeySimulator.shared
OverlayPanel.shared
SpeechEngine.shared
WhisperEngine.shared
LLMRefiner.shared
```

### Callback-based Communication

Speech engines use closures for async results:
```swift
onPartialResult: ((String) -> Void)?
onFinalResult: ((String) -> Void)?
onError: ((String) -> Void)?
onAudioLevel: ((Float) -> Void)?
```

### State Machine for Input Modes

GamepadManager maintains exclusive state flags:
- Voice mode blocks other input
- Preset menu has its own navigation
- Command mode captures all combo inputs

### Persistence Model

Configuration stored as JSON in Application Support:
- `~/Library/Application Support/ClaudeGamepad/config.json`
- Loaded at startup, saved on Settings window close
- Backward-compatible decoding for new fields

## Extension Points

### Adding New Button Actions

1. Add case to `ButtonAction` enum in `ButtonMapping.swift`
2. Implement handling in `GamepadManager.executeAction()`
3. Add UI option in `GamepadConfigView.swift`

### Adding New Speech Engines

1. Create engine class following SpeechEngine pattern
2. Add engine type to `SpeechEngineType` enum
3. Add engine selection UI in `SettingsWindow.swift`
4. Wire up in `GamepadManager.startVoiceInput()`

### Adding Settings Sections

1. Add case to `SettingsSection` enum
2. Implement `buildSectionView()` in `SettingsWindow.swift`
3. Add sidebar button in `buildSidebar()`
