# Flux Sequencer

A browser-based cue sequencer for the Flux lighting kit found in the target Roblox experience. It supports the live rig's fixture families and capability-gates cues so unsupported controls cannot be exported.

## Workflow

1. Open `index.html` (or the GitHub Pages URL).
2. Patch the fixture counts to match the game.
3. Load an audio file for local waveform-free timing, add cues, and enter the Roblox audio asset ID.
4. Export Luau and paste it into a ModuleScript under `ServerScriptService/FluxlinePlayer/Shows`.
5. Use the in-game Flux Shows button to select and play the show.

The audio file never leaves the browser and is not included in project JSON. Roblox playback requires an audio asset that the experience is permitted to use.

## Verified Flux capability map

- Profile: intensity, RGB/hue, strobe, pan, tilt, iris, shutter, spin, beam and gobo intensity
- Wash: intensity, RGB/hue, strobe, pan, tilt, iris, shutter
- Magic Blade / Magic Panel: intensity, RGB/hue, strobe, pan, tilt
- JDC1: intensity, RGB/hue, strobe, tilt
- Q7 / Line / Display: intensity, RGB/hue, strobe
- Laser: intensity, RGB/hue, strobe, pan, tilt, iris, width, spin, pitch, shutter
- PAR: intensity, RGB/hue, strobe, shutter
- Blinder: intensity
- Atomic: intensity, strobe
- Pyro: sparks, haze, fire, confetti, CO2, fireworks, bubbles
