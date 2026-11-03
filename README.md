# som3d — LÖVE + g3d Spatial Audio Demo

**A real 3D test project for `som3d.lua` using the actual g3d camera and models.**

> 3D demonstration models, textures, and test audio created for this project by **generico_cube**.

## Run

1. Install **LÖVE 11.4 or newer**.
2. Download or clone this repository.
3. Drag the project folder onto the LÖVE executable, or run `love .` from this folder.
4. Make sure your audio output is enabled. The two test sounds are mono WAV files.

## What is included

- `som3d.lua` — spatial audio helper module.
- `g3d/` — the actual g3d library source included in this demo.
- `main.lua` — real 3D scene, using `require("g3d")`, `g3d.newModel()` and `g3d.camera`.
- `assets/models/` — two original sphere models and a ground model.
- `assets/audio/` — two original mono test sounds.
- `assets/textures/` — textures generated for the demo.

The `.obj` files contain the comment `# // feito por generico_cube` in their headers.

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move the listener/camera |
| `Space` / `Left Shift` | Move up / down |
| Arrow keys or mouse | Rotate the camera |
| `1` | Toggle the blue sound source |
| `2` | Toggle the orange sound source |
| `M` | Toggle the orange sphere's orbit (Doppler test) |
| `F` | Toggle low-pass filter |
| `R` | Toggle reverb, when supported by the audio device |
| `Backspace` | Reset the scene |
| `Esc` | Quit |

## How g3d is connected to som3d

`som3d.lua` does not secretly load g3d. The game imports both modules and passes the real camera explicitly:

```lua
local g3d = require("g3d")
local som3d = require("som3d")

function love.update(dt)
    -- Update the 3D camera first.
    -- ...camera movement...

    -- The camera is the audio listener.
    som3d.update(g3d.camera, dt)
end
```

Sound sources and g3d models use the same XYZ coordinates. The orange sphere and its audio source are moved together; `Emitter:update` also provides velocity data for the Doppler effect.

## Use som3d in another project

Copy `som3d.lua` into your project and import it with `require("som3d")`. Your project must also include g3d if you want to pass `g3d.camera` as the listener.

```lua
local g3d = require("g3d")
local som3d = require("som3d")
local sound

function love.load()
    som3d.init({
        distanceModel = "inverseclamped",
        dopplerScale = 1,
    })

    sound = som3d.new("assets/my_sound_mono.wav", {
        position = { 5, 0, 1 },
        volume = 1,
        loop = true,
        referenceDistance = 3,
        maxDistance = 30,
        rolloff = 1,
    })

    sound:play()
end

function love.update(dt)
    -- Update your g3d camera and models here.
    som3d.update(g3d.camera, dt)
end
```

**Important:** LÖVE's positional audio requires mono (one-channel) audio files. The demo WAVs are mono.

## Credits and licenses

- **Demo models, textures and WAV test sounds:** created for this project by `generico_cube`.
- **g3d:** third-party 3D engine by [groverburger](https://github.com/groverburger/g3d), included with its original MIT license in `g3d-LICENSE`. Its source files are kept separate from the original `som3d` module.
- **som3d:** MIT License; see `LICENSE`.
