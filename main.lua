-- som3d + g3d: demonstração 3D real
-- Modelos OBJ e assets de demonstração: // feito por generico_cube

local g3d = require("g3d")
local som3d = require "g3d-cube-tools.som3d"

local camera = g3d.camera
local fonteAzul
local fonteLaranja
local bolaAzul
local bolaLaranja
local chao

local tempo = 0
local yaw = math.pi / 2
local pitch = -0.25
local cameraSpeed = 7
local turnSpeed = 1.8
local orbitEnabled = true
local filterEnabled = false
local reverbEnabled = false
local reverbAvailable = false
local azulPlaying = true
local laranjaPlaying = true
local uiFont
local smallFont

local azulPos = { -4.2, 1.0, 0.92 }
local laranjaPos = { 4.2, 1.0, 0.92 }

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function distanceTo(position)
    local p = camera.position
    local dx = position[1] - p[1]
    local dy = position[2] - p[2]
    local dz = position[3] - p[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function updateCamera()
    -- Usa a câmera real do g3d; som3d lê position, target e up dela.
    camera.lookInDirection(
        camera.position[1], camera.position[2], camera.position[3],
        yaw, pitch
    )
end

local function setSourcePosition(source, model, position, dt)
    model:setTranslation(position[1], position[2], position[3])
    source:update(dt, position[1], position[2], position[3])
end

local function toggleFilter()
    filterEnabled = not filterEnabled
    local settings = filterEnabled and {
        type = "lowpass",
        volume = 1,
        highgain = 0.22,
    } or nil
    fonteAzul:setFilter(settings)
    fonteLaranja:setFilter(settings)
end

local function toggleReverb()
    if not reverbAvailable then
        return
    end

    reverbEnabled = not reverbEnabled
    fonteAzul:setEffect("som3d_room", reverbEnabled)
    fonteLaranja:setEffect("som3d_room", reverbEnabled)
end

local function resetScene()
    camera.position[1], camera.position[2], camera.position[3] = 0, -9, 3.6
    yaw, pitch = math.pi / 2, -0.25
    tempo = 0
    orbitEnabled = true
    updateCamera()
end

function love.load()
    love.graphics.setDefaultFilter("linear", "linear", 2)
    love.graphics.setBackgroundColor(0.035, 0.047, 0.067, 1)

    uiFont = love.graphics.newFont(18)
    smallFont = love.graphics.newFont(13)

    -- Modelos 3D originais do projeto, todos com autoria nos próprios OBJ.
    chao = g3d.newModel(
        "g3d-cube-tools/som3d/assets/models/chao.obj",
        "g3d-cube-tools/som3d/assets/textures/chao_grid.png"
    )
    chao.texture:setWrap("repeat", "repeat")

    bolaAzul = g3d.newModel(
        "g3d-cube-tools/som3d/assets/models/bola_azul.obj",
        "g3d-cube-tools/som3d/assets/textures/bola_azul.png",
        azulPos,
        nil,
        0.92
    )

    bolaLaranja = g3d.newModel(
        "g3d-cube-tools/som3d/assets/models/bola_laranja.obj",
        "g3d-cube-tools/som3d/assets/textures/bola_laranja.png",
        laranjaPos,
        nil,
        0.92
    )

    -- Câmera real do g3d: esta é a posição do ouvinte no áudio 3D.
    camera.position[1], camera.position[2], camera.position[3] = 0, -9, 3.6
    updateCamera()

    som3d.init({
        distanceModel = "inverseclamped",
        dopplerScale = 1,
    })

    fonteAzul = som3d.new("g3d-cube-tools/som3d/assets/audio/ping_azul_mono.wav", {
        type = "static",
        position = azulPos,
        volume = 0.9,
        loop = true,
        referenceDistance = 3,
        maxDistance = 30,
        rolloff = 0.85,
        airAbsorption = 0.25,
    })

    fonteLaranja = som3d.new("g3d-cube-tools/som3d/assets/audio/ping_laranja_mono.wav", {
        type = "static",
        position = laranjaPos,
        volume = 0.9,
        loop = true,
        referenceDistance = 3,
        maxDistance = 30,
        rolloff = 0.85,
        airAbsorption = 0.25,
    })

    fonteAzul:play()
    fonteLaranja:play()

    reverbAvailable = som3d.isEffectsSupported()
    if reverbAvailable then
        reverbAvailable = som3d.defineEffect("som3d_room", {
            type = "reverb",
            volume = 0.22,
        }) == true
    end

    som3d.update(camera, 0)
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    tempo = tempo + dt

    local forward = 0
    local side = 0
    local vertical = 0

    if love.keyboard.isDown("w") then forward = forward + 1 end
    if love.keyboard.isDown("s") then forward = forward - 1 end
    if love.keyboard.isDown("d") then side = side + 1 end
    if love.keyboard.isDown("a") then side = side - 1 end
    if love.keyboard.isDown("space") then vertical = vertical + 1 end
    if love.keyboard.isDown("lshift") then vertical = vertical - 1 end

    local magnitude = math.sqrt(forward * forward + side * side)
    if magnitude > 1 then
        forward = forward / magnitude
        side = side / magnitude
    end

    -- Movimento relativo à direção da câmera, no plano XY do g3d.
    local dx = math.cos(yaw) * forward + math.sin(yaw) * side
    local dy = math.sin(yaw) * forward - math.cos(yaw) * side
    camera.position[1] = camera.position[1] + dx * cameraSpeed * dt
    camera.position[2] = camera.position[2] + dy * cameraSpeed * dt
    camera.position[3] = camera.position[3] + vertical * cameraSpeed * dt

    if love.keyboard.isDown("left") then yaw = yaw + turnSpeed * dt end
    if love.keyboard.isDown("right") then yaw = yaw - turnSpeed * dt end
    if love.keyboard.isDown("up") then pitch = clamp(pitch + turnSpeed * dt, -1.35, 1.35) end
    if love.keyboard.isDown("down") then pitch = clamp(pitch - turnSpeed * dt, -1.35, 1.35) end

    updateCamera()

    -- A bola laranja percorre uma órbita. A posição visual e a posição do áudio
    -- são atualizadas juntas; source:update também informa a velocidade (Doppler).
    if orbitEnabled then
        laranjaPos[1] = 4.1 + math.cos(tempo * 0.72) * 2.25
        laranjaPos[2] = 1.0 + math.sin(tempo * 0.72) * 2.25
        laranjaPos[3] = 0.92 + math.sin(tempo * 1.44) * 0.35
        setSourcePosition(fonteLaranja, bolaLaranja, laranjaPos, dt)
    end

    -- Este é o ponto principal da integração: passamos g3d.camera de verdade.
    som3d.update(g3d.camera, dt)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "1" then
        azulPlaying = not azulPlaying
        if azulPlaying then fonteAzul:play() else fonteAzul:pause() end
    elseif key == "2" then
        laranjaPlaying = not laranjaPlaying
        if laranjaPlaying then fonteLaranja:play() else fonteLaranja:pause() end
    elseif key == "m" then
        orbitEnabled = not orbitEnabled
        if not orbitEnabled then
            fonteLaranja:setVelocity(0, 0, 0)
        end
    elseif key == "f" then
        toggleFilter()
    elseif key == "r" then
        toggleReverb()
    elseif key == "backspace" then
        resetScene()
    end
end

function love.mousemoved(x, y, dx, dy)
    -- Também é possível olhar com o mouse, sem capturar o cursor.
    yaw = yaw - dx * 0.0025
    pitch = clamp(pitch - dy * 0.0025, -1.35, 1.35)
    updateCamera()
end

function love.resize(width, height)
    g3d.camera.resize(width, height)
end

local function textLine(text, x, y, color, font)
    love.graphics.setColor(color or { 0.88, 0.92, 0.97, 1 })
    love.graphics.setFont(font or smallFont)
    love.graphics.print(text, x, y)
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    chao:draw()
    bolaAzul:draw()
    bolaLaranja:draw()

    local width, height = love.graphics.getDimensions()
    love.graphics.setDepthMode("always", false)

    -- Painel superior.
    love.graphics.setColor(0.025, 0.035, 0.052, 0.91)
    love.graphics.rectangle("fill", 16, 16, 410, 190, 10, 10)
    textLine("som3d  /  g3d spatial audio", 30, 28, { 0.95, 0.97, 1, 1 }, uiFont)
    textLine("Câmera do g3d = ouvinte do áudio", 30, 57, { 0.45, 0.78, 1, 1 })
    textLine(string.format("Bola azul:     %.1f m  |  %s", distanceTo(azulPos), azulPlaying and "tocando" or "pausada"), 30, 83)
    textLine(string.format("Bola laranja:  %.1f m  |  %s", distanceTo(laranjaPos), laranjaPlaying and "tocando" or "pausada"), 30, 105)
    textLine("Órbita laranja: " .. (orbitEnabled and "ligada" or "desligada"), 30, 127)
    textLine("Filtro: " .. (filterEnabled and "low-pass ligado" or "desligado"), 30, 149)
    textLine("Reverb: " .. (reverbAvailable and (reverbEnabled and "ligado" or "desligado") or "não suportado"), 30, 171)

    -- Faixa de ajuda inferior.
    love.graphics.setColor(0.025, 0.035, 0.052, 0.88)
    love.graphics.rectangle("fill", 16, height - 104, math.min(width - 32, 860), 88, 10, 10)
    textLine("WASD mover ouvinte   |   Espaço / Shift subir e descer   |   Setas ou mouse olhar", 30, height - 91)
    textLine("1 áudio azul   |   2 áudio laranja   |   M mover/parar bola laranja   |   F filtro   |   R reverb", 30, height - 67)
    textLine("Backspace reiniciar   |   Esc sair", 30, height - 43, { 0.62, 0.70, 0.80, 1 })

    love.graphics.setDepthMode("lequal", true)
    love.graphics.setColor(1, 1, 1, 1)
end

function love.quit()
    if fonteAzul then fonteAzul:destroy() end
    if fonteLaranja then fonteLaranja:destroy() end
end
