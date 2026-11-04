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

## More features

- **Stereo files just work.** `static` sounds that are not mono are mixed down to mono automatically (`downmix = false` turns this off). `stream` sounds still need to be mono.
- **One-shot sounds.** `som3d.playAt(path, x, y, z, options)` plays a sound once at a position and cleans itself up when it ends (shots, footsteps, explosions). The file is loaded only the first time.
- **Follow a model.** `emitter:follow(model, offsetX, offsetY, offsetZ)` (or `follow = model` in the options) moves the sound with a g3d model, Doppler included. `som3d.update(camera, dt)` does the work, `follow(nil)` stops it.
- **Doppler safety.** Speeds are capped by `som3d.maxSpeed` (200 by default, also settable in `som3d.init`) so teleports don't cause pitch spikes. Call `som3d.resetListener()` after teleporting the camera.
- **Master volume and stop all.** `som3d.setMasterVolume(v)`, `som3d.getMasterVolume()` and `som3d.stopAll()`.
- **Extras.** `emitter:resume()`, `emitter:getPosition()`, `emitter:getVolume()`. Volumes are always clamped to 0-1, including in the creation options.
- **Portuguese names**, like g3d-glb: `som3d.novo`, `som3d.tocarEm`, `emitter:tocar()`, `pausar()`, `continuar()`, `parar()`, `seguir()`, `volume()`, `tom()`, `repetir()`, `destruir()` and more (see the end of `som3d.lua`).

```lua
local som3d = require "som3d"
som3d.init({ maxSpeed = 150 })

local engine = som3d.new("assets/engine.wav", { loop = true, follow = car })
engine:play()

function love.update(dt)
    som3d.update(g3d.camera, dt)   -- listener + followers + cleanup
end

function shoot(x, y, z)
    som3d.playAt("assets/shot.wav", x, y, z, { volume = 0.8, maxDistance = 80 })
end
```

## Credits and licenses

- **Demo models, textures and WAV test sounds:** created for this project by `generico_cube`.
- **g3d:** third-party 3D engine by [groverburger](https://github.com/groverburger/g3d), included with its original MIT license in `g3d-LICENSE`. Its source files are kept separate from the original `som3d` module.
- **som3d:** MIT License; see `LICENSE`.
