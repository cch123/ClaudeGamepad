.PHONY: run setup

run:
	.venv/bin/python3 gamepad_claude.py

setup:
	python3 -m venv .venv
	.venv/bin/pip install pygame-ce pynput faster-whisper sounddevice numpy
