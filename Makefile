.PHONY: run setup identify init map

run:
	.venv/bin/python3 gamepad_claude.py

init:
	.venv/bin/python3 gamepad_claude.py --init

map:
	.venv/bin/python3 gamepad_claude.py --map

identify:
	.venv/bin/python3 gamepad_claude.py --identify

setup:
	python3 -m venv .venv
	.venv/bin/pip install pygame-ce pynput faster-whisper sounddevice numpy
