#!/usr/bin/env python3
"""
scripts/kokoro_tts.py
Generates local speech using Kokoro-82M ONNX runtime.
"""
import argparse
import os
import sys
import soundfile as sf
from kokoro_onnx import Kokoro

def main():
    parser = argparse.ArgumentParser(description="Kokoro ONNX TTS CLI for AgentPet")
    parser.add_argument("--text", required=True, help="Text to speak")
    parser.add_argument("--voice", default="af_sarah", help="Voice identifier (e.g. af_sarah, af_bella, am_adam)")
    parser.add_argument("--output", required=True, help="Output WAV path")
    parser.add_argument("--speed", type=float, default=1.0, help="Speech speed multiplier")
    args = parser.parse_args()

    home = os.path.expanduser("~")
    model_path = os.path.join(home, ".agentpet", "kokoro", "kokoro-v0_19.onnx")
    voices_path = os.path.join(home, ".agentpet", "kokoro", "voices.bin")

    if not os.path.exists(model_path) or not os.path.exists(voices_path):
        print(f"Error: Kokoro model files not found at {model_path}", file=sys.stderr)
        sys.exit(1)

    kokoro = Kokoro(model_path, voices_path)
    voice = args.voice
    if voice not in kokoro.get_voices():
        # Fall back to af_sarah if requested voice not available
        voice = "af_sarah"

    samples, sample_rate = kokoro.create(args.text, voice=voice, speed=args.speed, lang="en-us")
    out_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(out_dir, exist_ok=True)
    sf.write(args.output, samples, sample_rate)
    print(f"SUCCESS:{args.output}:{len(samples)/sample_rate:.2f}s")

if __name__ == "__main__":
    main()
