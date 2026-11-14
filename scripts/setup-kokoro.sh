#!/bin/bash
set -euo pipefail

# scripts/setup-kokoro.sh
# Installs Kokoro-82M ONNX runtime & voice files for AgentPet

DEST_DIR="$HOME/.agentpet/kokoro"
ENV_DIR="$HOME/.agentpet/kokoro-env"

echo "=== AgentPet Kokoro Local TTS Setup ==="
mkdir -p "$DEST_DIR"

# 1. Set up Python virtualenv
if [ ! -f "$ENV_DIR/bin/python" ]; then
    echo "Creating virtual environment in $ENV_DIR..."
    python3 -m venv "$ENV_DIR"
    "$ENV_DIR/bin/pip" install --upgrade pip
    "$ENV_DIR/bin/pip" install kokoro-onnx soundfile
fi

# 2. Download ONNX weights if missing
ONNX_FILE="$DEST_DIR/kokoro-v0_19.onnx"
if [ ! -f "$ONNX_FILE" ]; then
    echo "Downloading kokoro-v0_19.onnx (~310MB)..."
    curl -L -o "$ONNX_FILE" "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/kokoro-v0_19.onnx"
fi

# 3. Download voices.bin if missing
VOICES_FILE="$DEST_DIR/voices.bin"
if [ ! -f "$VOICES_FILE" ]; then
    echo "Downloading voices.bin (~5.5MB)..."
    curl -L -o "$VOICES_FILE" "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/voices.bin"
fi

echo "Kokoro Local TTS setup complete! Ready at $DEST_DIR"
