# 🎮 Claude Code Gamepad Controller

Lean back on your couch and vibe code with Claude Code using a gamepad + voice input.

## Setup

```bash
pip install pygame pynput faster-whisper sounddevice numpy
```

> **macOS note**: First voice input will download the Whisper large-v3 model (~3GB). Subsequent runs use the cached model.

## Usage

```bash
# Connect your controller first, then:
python gamepad_claude.py

# Don't know your button mapping? Run identify mode:
python gamepad_claude.py --identify
```

Focus your terminal running Claude Code, and start pressing buttons.

## Button Mapping (Xbox Layout)

```
┌─────────────────────────────────────────────┐
│              Normal Mode                     │
├──────────┬──────────────────────────────────┤
│ A        │ Enter (confirm)                   │
│ B        │ Ctrl+C (interrupt agent)          │
│ X        │ Accept edit (y + Enter)           │
│ Y        │ Reject edit (n + Enter)           │
│ D-pad ↑↓ │ Arrow keys (history / scroll)     │
│ D-pad ←→ │ Arrow left/right                  │
│ LB       │ Tab (autocomplete)                │
│ RB       │ Escape                            │
│ Select   │ /clear + Enter                    │
│ Start    │ Open preset prompt menu           │
│ L/R Stick│ 🎤 Voice input                    │
│ L-Stick  │ Scroll (analog)                   │
├──────────┼──────────────────────────────────┤
│          │ Modifier Combos                   │
├──────────┼──────────────────────────────────┤
│ LT + A   │ "fix the failing tests"           │
│ LT + B   │ "explain this error"              │
│ LT + X   │ "continue"                        │
│ LT + Y   │ "undo the last change"            │
│ RT + A   │ "run the tests"                   │
│ RT + B   │ "show me the diff"                │
│ RT + X   │ "looks good, commit this"         │
│ RT + Y   │ "refactor this to be cleaner"     │
└──────────┴──────────────────────────────────┘
```

## Voice Input

Click either stick → speak your prompt → auto-stops on silence → transcribed and submitted.

Uses **faster-whisper** with `large-v3` locally. Auto-detects language — 中英文混合也行. First run downloads the model (~3GB), then cached.

## Customization

Edit the constants at the top of `gamepad_claude.py`:

- `WHISPER_MODEL_SIZE` — `"large-v3"` (best), `"medium"` (balanced), `"small"` (fast)
- `PRESET_PROMPTS` — cycle through with Start + D-pad
- `LT_PROMPTS` / `RT_PROMPTS` — quick trigger combos
- `Btn` class — remap button indices for your controller
- `DEADZONE` — stick sensitivity

## Troubleshooting

**Wrong button mapping?** Run `python gamepad_claude.py --identify` and press each button to see its index, then update the `Btn` class.

**Controller not detected?** Make sure it's connected via Bluetooth or USB before launching. On macOS, Xbox controllers need the [Xbox Controller Driver](https://github.com/360Controller/360Controller) or connect via Bluetooth.

**Voice not working?** macOS may prompt for microphone permission. Check System Settings → Privacy → Microphone.
