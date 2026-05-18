import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write

# --- CONFIGURATION ---
# Based on your pactl output: 
# Sink (Speaker) is likely Device 2, Source (Mic) is Device 3
# You can also use 'default' if you've set the USB as default
FS = 48000  # Hardware native rate for your USB-MV-SILICON
DURATION = 5  # Seconds
FILENAME = "lva_recording.wav"
GAIN_BOOST = 2.5  # Adjust this to fix the "lowww" audio

print(f"--- LVA Audio Test ---")
print(f"Recording for {DURATION} seconds at {FS}Hz...")

try:
    # Record audio
    # device=(input, output)
    recording = sd.rec(int(DURATION * FS), samplerate=FS, channels=1, dtype='float32')
    sd.wait()  # Wait until recording is finished
    print("Recording finished.")

    # Apply gain boost
    recording = recording * GAIN_BOOST

    # Save to file
    write(FILENAME, FS, (recording * 32767).astype(np.int16))
    print(f"Saved to {FILENAME}")

    # Playback
    print("Playing back...")
    sd.play(recording, FS)
    sd.wait()
    print("Playback finished. Test complete!")

except Exception as e:
    print(f"Error: {e}")
    print("Tip: Run 'pactl list cards' to verify your device IDs.")
