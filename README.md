# Flux Sequencer

Open-source browser sequencer and Roblox playback bridge for Flux lighting rigs.
The editor imports a Flux fixture setup, sequences lighting cues against music,
and exports one `.lua` show file that Roblox can play and the website can reopen
for editing.

[Open the sequencer](https://mr0ks.github.io/flux-lighting-sequencer/) ·
[Download the complete project](https://github.com/Mr0ks/flux-lighting-sequencer/archive/refs/heads/main.zip)

## What is included

| Path | Purpose |
| --- | --- |
| `index.html` | Complete browser sequencer |
| `version.js` | Passive release indicator used by the website |
| `vendor/interact.min.js` | Local timeline drag/resize dependency |
| `roblox/Server.lua` | Whitelist, show playback, sound sync and fixture control |
| `roblox/Client.lua` | Compact in-game Flux Shows interface |
| `roblox/Config.lua` | Owner/whitelist and Flux kit configuration |
| `roblox/ExampleShow.lua` | Example show ModuleScript |

The repository contains the complete source for this project. The Flux lighting
kit itself is a separate dependency and is not redistributed here.

## Use the hosted editor

1. Open the [Flux Sequencer](https://mr0ks.github.io/flux-lighting-sequencer/).
2. Create a named show or open a browser save.
3. Open **Project → Import DataStore JSON** and paste the JSON copied from the
   Flux exporter in your Roblox game. This loads exact fixture IDs, groups,
   capabilities, and split fixture channels such as JDC1 centre and outer.
4. Use **Load audio** for the local reference track and **Roblox ID** for the
   audio asset ID that the experience is allowed to play.
5. Drag cues onto compatible fixture lanes, or click a cue and click the
   timeline repeatedly to place it.
6. Open **Project → Export Lua show**. Copy the Lua or download the `.lua` file.
7. In Studio, create a ModuleScript inside `FluxlinePlayer/Shows`, then replace
   its source with the exported Lua.
8. Play-test, open **Flux Shows**, select the show, and press play.

The reference audio file remains on the device and is not placed in the Lua
show. The exported `songId` tells Roblox which permitted audio asset to play.

## Install the Roblox playback folder

Download and unzip the project, then create this structure in Roblox Studio:

```text
ServerScriptService
└── FluxlinePlayer (Folder)
    ├── Server (Script)                ← roblox/Server.lua
    ├── Config (ModuleScript)          ← roblox/Config.lua
    └── Shows (Folder)
        └── ExampleShow (ModuleScript) ← roblox/ExampleShow.lua

StarterPlayer
└── StarterPlayerScripts
    └── FluxlineClient (LocalScript)   ← roblox/Client.lua
```

For each arrow above, open the matching repository file, copy all of its source,
and paste it into the Roblox instance with the listed class and name.

Edit `Config` before testing:

```lua
return {
    -- The experience owner is always permitted.
    Whitelist = { 123456789 }, -- additional Roblox user IDs
    KitName = "kit",           -- folder under flux kit/kits
}
```

The server searches Workspace for a model named `flux kit`, then uses
`flux kit/kits/<KitName>`. Keep the Flux fixture hierarchy intact. The game
owner is automatically authorized; everyone else must be in `Whitelist`.

## Publish your own GitHub Pages copy

No build command or web server is required.

1. Sign in to GitHub and fork this repository, or create an empty public
   repository and upload every file from the downloaded ZIP while preserving
   the folders.
2. Open the repository's **Settings → Pages**.
3. Under **Build and deployment**, select **Deploy from a branch**.
4. Select the `main` branch and `/ (root)`, then save.
5. Wait for the `pages-build-deployment` action to finish. GitHub will show the
   public URL, normally `https://<username>.github.io/<repository>/`.
6. Open `version.js` and `index.html` whenever you publish a release and set the
   same release value in both files.

The website only checks `version.js` to display release status. It never updates
itself. When a newer release is detected, the user must click the release icon,
choose what happens to browser saves, and explicitly start the update.

## Shows, saves, and diagnostics

- Named shows and recovery snapshots use browser storage on that device.
- A downloaded Lua show is both the Roblox ModuleScript and the editable backup
  that can be imported into the website later.
- The footer diagnostics icon shows fixture totals, channels, event count,
  release, validation, and runtime errors.
- The complete debug JSON stays hidden until **Show debug script** is pressed.
  It can then be copied and pasted into a bug report.

## Flux capability map

- Profile: intensity, RGB/hue, strobe, pan, tilt, iris, shutter, spin, beam and
  gobo intensity
- Wash: intensity, RGB/hue, strobe, pan, tilt, iris, shutter
- Magic Blade / Magic Panel: intensity, RGB/hue, strobe, pan, tilt
- JDC1: main, centre-pixel and outer-tube channels; intensity, colour, strobe,
  and tilt where supported by the imported setup
- Q7 / Line / Display: intensity, RGB/hue, strobe
- Laser: intensity, RGB/hue, strobe, pan, tilt, iris, width, spin, pitch, shutter
- PAR: intensity, RGB/hue, strobe, shutter
- Blinder: intensity
- Atomic: intensity, strobe
- Pyro: sparks, haze, fire, confetti, CO2, fireworks, bubbles

## Contributing

Issues and pull requests are welcome. When changing the interface, test cue
placement, dragging, resizing, zoom/grid alignment, imports, Lua round-tripping,
and diagnostics before opening a pull request.

## License

Released under the [MIT License](LICENSE).
