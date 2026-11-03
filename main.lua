local som3d = require("som3d")

-- Câmera de teste com a mesma estrutura pública usada por g3d.camera.
-- No seu jogo, passe diretamente g3d.camera para som3d.update().
local camera = {
    position = { 0, 0, 0 },
    target = { 1, 0, 0 },
    up = { 0, 0, 1 },
}

function camera.getLookVector()
    local p, t = camera.position, camera.target
    local x, y, z = t[1] - p[1], t[2] - p[2], t[3] - p[3]
    local length = math.sqrt(x * x + y * y + z * z)
    if length < 0.000001 then
        return 1, 0, 0
    end
    return x / length, y / length, z / length
end

local speaker
local fontTitle
local fontSmall
local speakerPosition = { 8, 0, 0 }
local yaw = 0
local pitch = 0
local speed = 6
local turnSpeed = 1.8
local filterEnabled = false
local reverbEnabled = false
local reverbAvailable = false
local coneEnabled = true
local infoText = ""
local infoTimer = 0

local function updateCameraTarget()
    local cp = math.cos(pitch)
    camera.target[1] = camera.position[1] + math.cos(yaw) * cp
    camera.target[2] = camera.position[2] + math.sin(yaw) * cp
    camera.target[3] = camera.position[3] + math.sin(pitch)
end

local function setInfo(message)
    infoText = message
    infoTimer = 2.5
end

local function toggleFilter()
    filterEnabled = not filterEnabled
    if filterEnabled then
        speaker:setFilter({
            type = "lowpass",
            volume = 1,
            highgain = 0.18,
        })
    else
        speaker:setFilter(nil)
    end
    setInfo("Filtro low-pass: " .. (filterEnabled and "ligado" or "desligado"))
end

local function toggleReverb()
    if not reverbAvailable then
        setInfo("Reverb não é suportado neste dispositivo/driver.")
        return
    end

    reverbEnabled = not reverbEnabled
    if reverbEnabled then
        speaker:setEffect("som3d_demo_reverb", true)
    else
        speaker:removeEffect("som3d_demo_reverb")
    end
    setInfo("Reverb: " .. (reverbEnabled and "ligado" or "desligado"))
end

local function toggleCone()
    coneEnabled = not coneEnabled
    if coneEnabled then
        speaker:setDirection(-1, 0, 0)
        speaker:setCone(math.rad(65), math.rad(120), 0.12)
    else
        speaker:setDirection(0, 0, 0)
    end
    setInfo("Áudio direcional: " .. (coneEnabled and "ligado" or "desligado"))
end

local function resetScene()
    camera.position[1], camera.position[2], camera.position[3] = 0, 0, 0
    yaw, pitch = 0, 0
    speakerPosition[1], speakerPosition[2], speakerPosition[3] = 8, 0, 0
    updateCameraTarget()
    speaker:setPosition(speakerPosition[1], speakerPosition[2], speakerPosition[3])
    setInfo("Posições reiniciadas.")
end

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    fontTitle = love.graphics.newFont(24)
    fontSmall = love.graphics.newFont(13)
    love.graphics.setBackgroundColor(0.055, 0.065, 0.085)

    som3d.init({
        distanceModel = "inverseclamped",
        dopplerScale = 1,
    })

    reverbAvailable = som3d.isEffectsSupported()
    if reverbAvailable then
        reverbAvailable = som3d.defineEffect("som3d_demo_reverb", {
            type = "reverb",
            volume = 0.35,
        }) == true
    end

    speaker = som3d.new("assets/beep_mono.wav", {
        type = "static",
        position = speakerPosition,
        volume = 0.85,
        pitch = 1,
        loop = true,
        referenceDistance = 1,
        maxDistance = 35,
        rolloff = 1,
        direction = { -1, 0, 0 },
        cone = {
            innerAngle = math.rad(65),
            outerAngle = math.rad(120),
            outerVolume = 0.12,
        },
        airAbsorption = 0.35,
    })

    speaker:play()
    updateCameraTarget()
end

function love.update(dt)
    local moveForward, moveSide, moveHeight = 0, 0, 0

    if love.keyboard.isDown("w") then moveForward = moveForward + 1 end
    if love.keyboard.isDown("s") then moveForward = moveForward - 1 end
    if love.keyboard.isDown("d") then moveSide = moveSide + 1 end
    if love.keyboard.isDown("a") then moveSide = moveSide - 1 end
    if love.keyboard.isDown("space") then moveHeight = moveHeight + 1 end
    if love.keyboard.isDown("lshift") then moveHeight = moveHeight - 1 end

    local moveLength = math.sqrt(moveForward * moveForward + moveSide * moveSide)
    if moveLength > 0 then
        moveForward = moveForward / moveLength
        moveSide = moveSide / moveLength
    end

    local dx = math.cos(yaw) * moveForward - math.sin(yaw) * moveSide
    local dy = math.sin(yaw) * moveForward + math.cos(yaw) * moveSide
    camera.position[1] = camera.position[1] + dx * speed * dt
    camera.position[2] = camera.position[2] + dy * speed * dt
    camera.position[3] = camera.position[3] + moveHeight * speed * dt

    if love.keyboard.isDown("left") then yaw = yaw + turnSpeed * dt end
    if love.keyboard.isDown("right") then yaw = yaw - turnSpeed * dt end
    if love.keyboard.isDown("up") then pitch = math.min(pitch + turnSpeed * dt, math.rad(80)) end
    if love.keyboard.isDown("down") then pitch = math.max(pitch - turnSpeed * dt, math.rad(-80)) end

    local sourceSpeed = 5
    if love.keyboard.isDown("i") then speakerPosition[1] = speakerPosition[1] + sourceSpeed * dt end
    if love.keyboard.isDown("k") then speakerPosition[1] = speakerPosition[1] - sourceSpeed * dt end
    if love.keyboard.isDown("l") then speakerPosition[2] = speakerPosition[2] + sourceSpeed * dt end
    if love.keyboard.isDown("j") then speakerPosition[2] = speakerPosition[2] - sourceSpeed * dt end
    if love.keyboard.isDown("u") then speakerPosition[3] = speakerPosition[3] + sourceSpeed * dt end
    if love.keyboard.isDown("o") then speakerPosition[3] = speakerPosition[3] - sourceSpeed * dt end

    updateCameraTarget()

    -- Atualiza velocidade e posição da fonte (inclui Doppler).
    speaker:update(dt, speakerPosition[1], speakerPosition[2], speakerPosition[3])

    -- Atualiza posição, orientação e velocidade do ouvinte.
    som3d.update(camera, dt)

    if infoTimer > 0 then
        infoTimer = math.max(0, infoTimer - dt)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "p" then
        if speaker:isPlaying() then
            speaker:pause()
            setInfo("Áudio pausado.")
        else
            speaker:play()
            setInfo("Áudio reproduzindo.")
        end
    elseif key == "f" then
        toggleFilter()
    elseif key == "r" then
        toggleReverb()
    elseif key == "c" then
        toggleCone()
    elseif key == "backspace" then
        resetScene()
    end
end

local function drawText(text, x, y, color)
    color = color or { 0.85, 0.88, 0.93, 1 }
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setFont(fontSmall)
    love.graphics.print(text, x, y)
end

local function drawMap(panelX, panelY, panelW, panelH)
    local centerX = panelX + panelW * 0.5
    local centerY = panelY + panelH * 0.52
    local scale = math.min(panelW, panelH) / 48
    local mapRadius = scale * 22

    love.graphics.setColor(0.075, 0.09, 0.12, 1)
    love.graphics.circle("fill", centerX, centerY, mapRadius)
    love.graphics.setColor(0.17, 0.2, 0.25, 1)
    for radius = 5, 20, 5 do
        love.graphics.circle("line", centerX, centerY, radius * scale)
    end
    love.graphics.line(centerX - mapRadius, centerY, centerX + mapRadius, centerY)
    love.graphics.line(centerX, centerY - mapRadius, centerX, centerY + mapRadius)

    -- O mapa mostra X/Y; a altura Z aparece nos indicadores laterais.
    local sourceDX = speakerPosition[1] - camera.position[1]
    local sourceDY = speakerPosition[2] - camera.position[2]
    local sourceMapX = centerX + sourceDX * scale
    local sourceMapY = centerY - sourceDY * scale
    local mapDX, mapDY = sourceMapX - centerX, sourceMapY - centerY
    local mapDistance = math.sqrt(mapDX * mapDX + mapDY * mapDY)
    if mapDistance > mapRadius then
        sourceMapX = centerX + mapDX / mapDistance * mapRadius
        sourceMapY = centerY + mapDY / mapDistance * mapRadius
    end

    love.graphics.setColor(0.95, 0.54, 0.22, 0.22)
    love.graphics.line(centerX, centerY, sourceMapX, sourceMapY)

    if coneEnabled then
        local coneRadius = math.min(110, mapRadius * 0.7)
        local sourceAngle = math.pi -- a fonte aponta para -X.
        local halfAngle = math.rad(120) * 0.5
        local ax = sourceMapX + math.cos(sourceAngle - halfAngle) * coneRadius
        local ay = sourceMapY - math.sin(sourceAngle - halfAngle) * coneRadius
        local bx = sourceMapX + math.cos(sourceAngle + halfAngle) * coneRadius
        local by = sourceMapY - math.sin(sourceAngle + halfAngle) * coneRadius
        love.graphics.setColor(0.95, 0.54, 0.22, 0.75)
        love.graphics.line(sourceMapX, sourceMapY, ax, ay)
        love.graphics.line(sourceMapX, sourceMapY, bx, by)
    end

    -- Direção atual do ouvinte.
    love.graphics.setColor(0.25, 0.78, 0.98, 1)
    local headX = centerX + math.cos(yaw) * 28
    local headY = centerY - math.sin(yaw) * 28
    love.graphics.setLineWidth(3)
    love.graphics.line(centerX, centerY, headX, headY)
    love.graphics.circle("fill", centerX, centerY, 8)

    love.graphics.setColor(1, 0.62, 0.28, 1)
    love.graphics.circle("fill", sourceMapX, sourceMapY, 8)
    love.graphics.setLineWidth(1)

    drawText("X", centerX + mapRadius + 8, centerY - 7, { 0.55, 0.6, 0.68, 1 })
    drawText("Y", centerX - 6, centerY - mapRadius - 22, { 0.55, 0.6, 0.68, 1 })
    drawText("Ouvinte", centerX + 14, centerY + 12, { 0.25, 0.78, 0.98, 1 })
    drawText("Fonte", sourceMapX + 12, sourceMapY - 20, { 1, 0.68, 0.38, 1 })

    love.graphics.setColor(0.5, 0.55, 0.63, 1)
    love.graphics.printf("Vista superior (X/Y) · escala aproximada", panelX, panelY + panelH - 25, panelW, "center")
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    local margin = 22
    local gap = 18
    local leftW = math.min(560, width * 0.56)
    local panelY = 84
    local panelH = height - panelY - margin
    local rightX = margin + leftW + gap
    local rightW = width - rightX - margin

    love.graphics.setColor(0.92, 0.94, 0.98, 1)
    love.graphics.setFont(fontTitle)
    love.graphics.print("som3d", margin, 20)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.58, 0.65, 0.74, 1)
    love.graphics.print("Demonstração de áudio espacial para LÖVE + g3d", margin + 92, 29)

    love.graphics.setColor(0.09, 0.11, 0.15, 1)
    love.graphics.rectangle("fill", margin, panelY, leftW, panelH, 12, 12)
    love.graphics.rectangle("fill", rightX, panelY, rightW, panelH, 12, 12)

    drawMap(margin + 8, panelY + 8, leftW - 16, panelH - 16)

    local px = rightX + 20
    local y = panelY + 20
    local line = 25
    local dx = speakerPosition[1] - camera.position[1]
    local dy = speakerPosition[2] - camera.position[2]
    local dz = speakerPosition[3] - camera.position[3]
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    drawText("ESTADO DO ÁUDIO", px, y, { 0.95, 0.96, 1, 1 }); y = y + line * 1.25
    drawText("Distância: " .. string.format("%.2f", distance) .. " unidades", px, y); y = y + line
    drawText("Ouvinte: " .. string.format("%.1f, %.1f, %.1f", camera.position[1], camera.position[2], camera.position[3]), px, y); y = y + line
    drawText("Fonte: " .. string.format("%.1f, %.1f, %.1f", speakerPosition[1], speakerPosition[2], speakerPosition[3]), px, y); y = y + line
    drawText("Reprodução: " .. (speaker:isPlaying() and "tocando" or "pausada"), px, y); y = y + line
    drawText("Filtro low-pass: " .. (filterEnabled and "ligado" or "desligado"), px, y); y = y + line
    drawText("Reverb: " .. (reverbAvailable and (reverbEnabled and "ligado" or "desligado") or "indisponível"), px, y); y = y + line
    drawText("Cone direcional: " .. (coneEnabled and "ligado" or "desligado"), px, y); y = y + line
    drawText("Atenuação: inverseclamped · Doppler: ligado", px, y, { 0.65, 0.75, 0.88, 1 }); y = y + line * 1.5

    drawText("CONTROLES", px, y, { 0.95, 0.96, 1, 1 }); y = y + line * 1.15
    local controls = {
        "W A S D     mover ouvinte",
        "Espaço / Shift     subir / descer ouvinte",
        "Setas     girar a direção do ouvinte",
        "I J K L     mover a fonte no plano X/Y",
        "U / O     subir / descer a fonte",
        "P     pausar / reproduzir",
        "F     alternar filtro low-pass",
        "R     alternar reverb (se suportado)",
        "C     alternar cone direcional",
        "Backspace     reiniciar posições",
        "Esc     sair",
    }
    for _, text in ipairs(controls) do
        drawText(text, px, y, { 0.73, 0.78, 0.85, 1 })
        y = y + 22
    end

    if infoTimer > 0 then
        love.graphics.setColor(0.12, 0.19, 0.27, 0.96)
        love.graphics.rectangle("fill", margin, height - 54, width - margin * 2, 34, 7, 7)
        love.graphics.setColor(0.9, 0.94, 1, 1)
        love.graphics.printf(infoText, margin + 10, height - 46, width - margin * 2 - 20, "center")
    end
end

function love.quit()
    if speaker then
        speaker:destroy()
    end
end
