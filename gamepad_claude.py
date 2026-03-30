#!/usr/bin/env python3
"""
🎮 Claude Code Gamepad Controller
Control Claude Code with a gamepad + voice input for prompts.
Lean back, vibe code from your couch.

Requirements:
    pip install pygame-ce pynput faster-whisper sounddevice numpy

Usage:
    python gamepad_claude.py

Button Mapping:
    A           → Enter (confirm)
    B           → Ctrl+C (interrupt)
    X           → Type 'y' + Enter (accept edit)
    Y           → Type 'n' + Enter (reject edit)
    D-pad ↑/↓   → Arrow Up/Down (history / scroll)
    D-pad ←/→   → Arrow Left/Right
    LB          → Tab (autocomplete)
    RB          → Escape
    L-Stick Click → Trigger voice input for prompt
    R-Stick Click → Trigger voice input for prompt (same, either thumb)
    Start       → Preset prompt menu (cycle with D-pad, confirm with A)
    Select/Back → Type '/clear' + Enter

    LT + A/B/X/Y → Quick prompts (hold LT then press)
        LT + A  → "fix the failing tests"
        LT + B  → "explain this error"
        LT + X  → "continue"
        LT + Y  → "undo the last change"

    RT + A/B/X/Y → More quick prompts (hold RT then press)
        RT + A  → "run the tests"
        RT + B  → "show me the diff"
        RT + X  → "looks good, commit this"
        RT + Y  → "refactor this to be cleaner"
"""

import os
import sys
import time
import threading
import subprocess
from enum import Enum, auto

# --- Lazy imports with helpful errors ---

def check_import(module_name, pip_name=None):
    try:
        return __import__(module_name)
    except ImportError:
        pip_name = pip_name or module_name
        install_name = "pygame-ce" if pip_name == "pygame" else pip_name
        print(f"❌ Missing '{module_name}'. Install with: pip install {install_name}")
        sys.exit(1)

pygame = check_import("pygame")
pynput_keyboard = check_import("pynput.keyboard", "pynput")

from pynput.keyboard import Key, Controller as KBController

# Speech recognition via faster-whisper (optional - degrades gracefully)
try:
    from faster_whisper import WhisperModel
    import sounddevice as sd
    import numpy as np
    HAS_SPEECH = True
except ImportError:
    HAS_SPEECH = False
    print("⚠️  Voice input disabled. Install with:")
    print("   pip install faster-whisper sounddevice numpy")

# ─── Voice Config ─────────────────────────────────────────────────

# Whisper model size: "large-v3" for best quality, "medium" for faster, "small" for low RAM
WHISPER_MODEL_SIZE = "large-v3"
# Device: "cpu" or "cuda" (Apple Silicon uses cpu with CTranslate2 auto-optimization)
WHISPER_DEVICE = "cpu"
WHISPER_COMPUTE_TYPE = "int8"  # int8 is fast on CPU, use float16 for GPU

# Audio recording settings
SAMPLE_RATE = 16000  # Whisper expects 16kHz
SILENCE_THRESHOLD = 0.01  # RMS threshold for silence detection
SILENCE_DURATION = 1.5  # Seconds of silence to stop recording
MAX_RECORD_SECONDS = 30  # Safety cap

# Lazy-loaded model (first voice input will take a few seconds to load)
_whisper_model = None

def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        osd(f"🎤 Loading Whisper {WHISPER_MODEL_SIZE} (first time only)...")
        _whisper_model = WhisperModel(
            WHISPER_MODEL_SIZE,
            device=WHISPER_DEVICE,
            compute_type=WHISPER_COMPUTE_TYPE,
        )
        osd(f"🎤 Whisper model loaded!")
    return _whisper_model


# ─── Config ───────────────────────────────────────────────────────

# Polling rate (seconds) - 60Hz is plenty
POLL_INTERVAL = 1 / 60

# Analog stick deadzone
DEADZONE = 0.4

# Scroll repeat rate when stick is held
SCROLL_REPEAT_MS = 120

# D-pad as hat index
HAT_INDEX = 0

# Button indices (Xbox layout on macOS - adjust if needed)
# These are common for Xbox/PS controllers via pygame on macOS.
# Run with --identify to check your controller's mapping.
class Btn:
    A = 0
    B = 1
    X = 3
    Y = 4
    LB = 6
    RB = 7
    SELECT = 10
    START = 11
    L_STICK = 13
    R_STICK = 14

# Trigger axes (Xbox controllers)
class Axis:
    LX = 0  # Left stick X
    LY = 1  # Left stick Y
    RX = 2  # Right stick X (or 3 on some controllers)
    RY = 3  # Right stick Y
    LT = 4  # Left trigger
    RT = 5  # Right trigger


# ─── Preset prompts (cycle with Start + D-pad) ───────────────────

PRESET_PROMPTS = [
    "fix the failing tests",
    "explain what this code does",
    "add error handling",
    "write tests for this",
    "refactor this to be cleaner",
    "find and fix the bug",
    "optimize this for performance",
    "add types and documentation",
]

# Quick prompts (LT + face button)
LT_PROMPTS = {
    Btn.A: "fix the failing tests",
    Btn.B: "explain this error",
    Btn.X: "continue",
    Btn.Y: "undo the last change",
}

# Quick prompts (RT + face button)
RT_PROMPTS = {
    Btn.A: "run the tests",
    Btn.B: "show me the diff",
    Btn.X: "looks good, commit this",
    Btn.Y: "refactor this to be cleaner",
}


# ─── State ────────────────────────────────────────────────────────

class Mode(Enum):
    NORMAL = auto()
    PRESET_MENU = auto()
    VOICE_INPUT = auto()

class State:
    mode: Mode = Mode.NORMAL
    preset_index: int = 0
    voice_listening: bool = False
    lt_held: bool = False
    rt_held: bool = False
    last_scroll_time: float = 0

state = State()
kb = KBController()


# ─── Helpers ──────────────────────────────────────────────────────

def type_string(s: str):
    """Type a string character by character, then press Enter."""
    for ch in s:
        kb.type(ch)
        time.sleep(0.01)  # tiny delay for reliability
    time.sleep(0.05)
    kb.press(Key.enter)
    kb.release(Key.enter)

def press_key(key):
    kb.press(key)
    kb.release(key)

def press_combo(*keys):
    """Press a key combination (e.g., Ctrl+C)."""
    for k in keys:
        kb.press(k)
    time.sleep(0.02)
    for k in reversed(keys):
        kb.release(k)

def notify(title: str, msg: str = ""):
    """macOS notification via osascript."""
    escaped = msg.replace('"', '\\"')
    subprocess.Popen([
        "osascript", "-e",
        f'display notification "{escaped}" with title "🎮 {title}"'
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def osd(msg: str):
    """On-screen display - just print + optional notification."""
    print(f"  🎮 {msg}")


# ─── Voice Input ──────────────────────────────────────────────────

def record_until_silence() -> np.ndarray:
    """Record audio from mic, stop after silence is detected."""
    osd("🎤 Listening... speak your prompt (auto-stops on silence)")
    notify("Voice Input", "Listening...")

    chunks = []
    silent_chunks = 0
    has_speech = False
    chunk_duration = 0.1  # 100ms chunks
    chunk_samples = int(SAMPLE_RATE * chunk_duration)
    silence_chunks_needed = int(SILENCE_DURATION / chunk_duration)
    max_chunks = int(MAX_RECORD_SECONDS / chunk_duration)

    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="float32") as stream:
        for _ in range(max_chunks):
            data, _ = stream.read(chunk_samples)
            chunks.append(data.copy())
            rms = np.sqrt(np.mean(data ** 2))

            if rms > SILENCE_THRESHOLD:
                has_speech = True
                silent_chunks = 0
            else:
                silent_chunks += 1

            # Stop after enough silence, but only if we've heard speech
            if has_speech and silent_chunks >= silence_chunks_needed:
                break

    audio = np.concatenate(chunks, axis=0).flatten()
    return audio


def voice_input_thread():
    """Record speech, transcribe with faster-whisper, type as prompt."""
    if not HAS_SPEECH:
        osd("Voice input not available (install faster-whisper sounddevice numpy)")
        state.voice_listening = False
        return

    state.voice_listening = True

    try:
        audio = record_until_silence()

        # Skip if too short (just noise)
        duration = len(audio) / SAMPLE_RATE
        if duration < 0.5:
            osd("🎤 Too short, ignored.")
            return

        osd(f"🎤 Transcribing {duration:.1f}s of audio...")

        model = get_whisper_model()
        segments, info = model.transcribe(
            audio,
            beam_size=5,
            language=None,  # auto-detect language (中英文都行)
            vad_filter=True,  # filter out non-speech
            vad_parameters=dict(min_silence_duration_ms=500),
        )

        text = "".join(seg.text for seg in segments).strip()

        if text:
            lang = info.language
            osd(f"🎤 [{lang}] \"{text}\"")
            notify("Voice Input", f"Typing: {text}")
            type_string(text)
        else:
            osd("🎤 Didn't catch that. Try again.")
            notify("Voice Input", "Couldn't understand. Try again.")

    except Exception as e:
        osd(f"🎤 Voice error: {e}")
    finally:
        state.voice_listening = False
        state.mode = Mode.NORMAL


# ─── Preset Menu ──────────────────────────────────────────────────

def show_preset_menu():
    """Display the preset prompt menu in terminal."""
    print("\n  ┌─────────────────────────────────────┐")
    print("  │  📋 Preset Prompts (D-pad ↑↓, A=go) │")
    print("  ├─────────────────────────────────────┤")
    for i, p in enumerate(PRESET_PROMPTS):
        marker = " ▸ " if i == state.preset_index else "   "
        print(f"  │{marker}{p:<34}│")
    print("  └─────────────────────────────────────┘\n")


# ─── Button Handlers ──────────────────────────────────────────────

def on_button_down(button: int):
    # --- Modifier detection ---
    if button == Btn.SELECT:
        osd("/clear")
        type_string("/clear")
        return

    if button == Btn.START:
        if state.mode == Mode.PRESET_MENU:
            state.mode = Mode.NORMAL
            osd("Preset menu closed")
        else:
            state.mode = Mode.PRESET_MENU
            state.preset_index = 0
            show_preset_menu()
        return

    if button in (Btn.L_STICK, Btn.R_STICK):
        if not state.voice_listening:
            state.mode = Mode.VOICE_INPUT
            threading.Thread(target=voice_input_thread, daemon=True).start()
        return

    # --- Preset menu mode ---
    if state.mode == Mode.PRESET_MENU:
        if button == Btn.A:
            prompt = PRESET_PROMPTS[state.preset_index]
            state.mode = Mode.NORMAL
            osd(f"Sending: {prompt}")
            type_string(prompt)
        elif button == Btn.B:
            state.mode = Mode.NORMAL
            osd("Preset menu cancelled")
        return

    # --- LT + button = quick prompt ---
    if state.lt_held and button in LT_PROMPTS:
        prompt = LT_PROMPTS[button]
        osd(f"Quick: {prompt}")
        type_string(prompt)
        return

    # --- RT + button = quick prompt ---
    if state.rt_held and button in RT_PROMPTS:
        prompt = RT_PROMPTS[button]
        osd(f"Quick: {prompt}")
        type_string(prompt)
        return

    # --- Normal mode ---
    if button == Btn.A:
        osd("Enter")
        press_key(Key.enter)
    elif button == Btn.B:
        osd("Ctrl+C")
        press_combo(Key.ctrl, 'c')
    elif button == Btn.X:
        osd("Accept (y)")
        kb.type('y')
        time.sleep(0.02)
        press_key(Key.enter)
    elif button == Btn.Y:
        osd("Reject (n)")
        kb.type('n')
        time.sleep(0.02)
        press_key(Key.enter)
    elif button == Btn.LB:
        osd("Tab")
        press_key(Key.tab)
    elif button == Btn.RB:
        osd("Escape")
        press_key(Key.esc)


def on_hat(x: int, y: int):
    """D-pad input (hat switch)."""
    if state.mode == Mode.PRESET_MENU:
        if y == 1:  # Up
            state.preset_index = (state.preset_index - 1) % len(PRESET_PROMPTS)
            show_preset_menu()
        elif y == -1:  # Down
            state.preset_index = (state.preset_index + 1) % len(PRESET_PROMPTS)
            show_preset_menu()
        return

    if y == 1:
        press_key(Key.up)
    elif y == -1:
        press_key(Key.down)
    if x == 1:
        press_key(Key.right)
    elif x == -1:
        press_key(Key.left)


def handle_sticks(joystick):
    """Left stick for scrolling output."""
    try:
        ly = joystick.get_axis(Axis.LY)
    except:
        return

    now = time.time()
    if abs(ly) > DEADZONE and (now - state.last_scroll_time) > SCROLL_REPEAT_MS / 1000:
        if ly < -DEADZONE:
            press_key(Key.up)
        elif ly > DEADZONE:
            press_key(Key.down)
        state.last_scroll_time = now


def handle_triggers(joystick):
    """Track LT/RT held state for modifier combos."""
    try:
        lt = joystick.get_axis(Axis.LT)
        rt = joystick.get_axis(Axis.RT)
        # Triggers range from -1 (released) to 1 (fully pressed) on many controllers
        # Some controllers: 0 to 1
        state.lt_held = lt > 0.3
        state.rt_held = rt > 0.3
    except:
        pass


# ─── Identify Mode ────────────────────────────────────────────────

def identify_mode(joystick):
    """Interactive mode to identify button/axis mappings."""
    print("\n🔍 Controller Identify Mode")
    print("   Press buttons and move sticks to see their indices.")
    print("   Press Ctrl+C to exit.\n")

    try:
        while True:
            pygame.event.pump()
            for event in pygame.event.get():
                if event.type == pygame.JOYBUTTONDOWN:
                    print(f"   Button {event.button} pressed")
                elif event.type == pygame.JOYAXISMOTION:
                    if abs(event.value) > 0.3:
                        print(f"   Axis {event.axis} = {event.value:.2f}")
                elif event.type == pygame.JOYHATMOTION:
                    print(f"   Hat {event.hat} = {event.value}")
            time.sleep(0.016)
    except KeyboardInterrupt:
        print("\n   Done.")


# ─── Main Loop ────────────────────────────────────────────────────

def main():
    pygame.init()
    pygame.joystick.init()

    identify = "--identify" in sys.argv

    print("""
  ╔═══════════════════════════════════════════════╗
  ║  🎮 Claude Code Gamepad Controller            ║
  ║                                               ║
  ║  A=Enter  B=Ctrl+C  X=Accept  Y=Reject       ║
  ║  D-pad=Navigate  LB=Tab  RB=Esc              ║
  ║  Click Stick=🎤 Voice  Start=Presets          ║
  ║  LT/RT + Face=Quick Prompts                   ║
  ║                                               ║
  ║  Run with --identify to check button mapping  ║
  ╚═══════════════════════════════════════════════╝
    """)

    # Wait for controller
    print("  Waiting for controller...", end="", flush=True)
    joystick = None
    while joystick is None:
        pygame.joystick.quit()
        pygame.joystick.init()
        if pygame.joystick.get_count() > 0:
            joystick = pygame.joystick.Joystick(0)
            joystick.init()
        else:
            print(".", end="", flush=True)
            time.sleep(1)

    print(f"\n  ✅ Connected: {joystick.get_name()}")
    print(f"     Buttons: {joystick.get_numbuttons()}, "
          f"Axes: {joystick.get_numaxes()}, "
          f"Hats: {joystick.get_numhats()}")

    if not HAS_SPEECH:
        print("  ⚠️  Voice input disabled (missing faster-whisper/sounddevice)")
    print("\n  Ready! Focus your terminal with Claude Code.\n")

    notify("Connected", joystick.get_name())

    if identify:
        identify_mode(joystick)
        return

    try:
        while True:
            pygame.event.pump()

            for event in pygame.event.get():
                if event.type == pygame.JOYBUTTONDOWN:
                    on_button_down(event.button)
                elif event.type == pygame.JOYHATMOTION:
                    if event.hat == HAT_INDEX:
                        on_hat(*event.value)
                elif event.type == pygame.JOYDEVICEREMOVED:
                    osd("Controller disconnected! Waiting...")
                    notify("Disconnected", "Plug controller back in")
                    joystick = None
                    while joystick is None:
                        pygame.joystick.quit()
                        pygame.joystick.init()
                        if pygame.joystick.get_count() > 0:
                            joystick = pygame.joystick.Joystick(0)
                            joystick.init()
                            osd(f"Reconnected: {joystick.get_name()}")
                            notify("Reconnected", joystick.get_name())
                        else:
                            time.sleep(1)

            if joystick:
                handle_sticks(joystick)
                handle_triggers(joystick)

            time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        print("\n  👋 Bye!")
    finally:
        pygame.quit()


if __name__ == "__main__":
    main()
