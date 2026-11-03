-- som3d.lua
-- Audio espacial 3D para LÖVE + g3d.
-- Use as mesmas coordenadas XYZ dos modelos e da câmera do g3d.

local som3d = {}
local Emitter = {}
Emitter.__index = Emitter

local previousListenerPosition

local function checkNumber(value, name)
    assert(type(value) == "number", "som3d: '" .. name .. "' precisa ser um número")
end

local function normalize(x, y, z, fallbackX, fallbackY, fallbackZ)
    local length = math.sqrt(x * x + y * y + z * z)
    if length < 0.000001 then
        return fallbackX, fallbackY, fallbackZ
    end
    return x / length, y / length, z / length
end

local function checkEmitter(self)
    assert(not self.destroyed, "som3d: este som já foi destruído")
end

-- Configuração global. Chame uma vez em love.load().
function som3d.init(options)
    options = options or {}

    love.audio.setDistanceModel(options.distanceModel or "inverseclamped")

    if options.dopplerScale ~= nil then
        checkNumber(options.dopplerScale, "dopplerScale")
        assert(options.dopplerScale > 0, "som3d: dopplerScale precisa ser maior que zero")
        love.audio.setDopplerScale(options.dopplerScale)
    end

    previousListenerPosition = nil
    return som3d
end

-- Sincroniza o ouvinte com uma câmera do g3d.
-- Chame em love.update(dt), depois de atualizar a câmera.
function som3d.update(camera, dt)
    assert(type(camera) == "table", "som3d.update: informe g3d.camera")
    assert(type(camera.position) == "table", "som3d.update: câmera sem position")

    local p = camera.position
    local x, y, z = p[1], p[2], p[3]
    checkNumber(x, "camera.position[1]")
    checkNumber(y, "camera.position[2]")
    checkNumber(z, "camera.position[3]")

    love.audio.setPosition(x, y, z)

    local fx, fy, fz
    if type(camera.getLookVector) == "function" then
        fx, fy, fz = camera.getLookVector()
    elseif type(camera.target) == "table" then
        fx = camera.target[1] - x
        fy = camera.target[2] - y
        fz = camera.target[3] - z
    else
        fx, fy, fz = 1, 0, 0
    end

    fx, fy, fz = normalize(fx or 1, fy or 0, fz or 0, 1, 0, 0)

    local up = camera.up or { 0, 0, 1 }
    local ux, uy, uz = normalize(up[1] or 0, up[2] or 0, up[3] or 1, 0, 0, 1)
    love.audio.setOrientation(fx, fy, fz, ux, uy, uz)

    if dt and dt > 0 and previousListenerPosition then
        love.audio.setVelocity(
            (x - previousListenerPosition[1]) / dt,
            (y - previousListenerPosition[2]) / dt,
            (z - previousListenerPosition[3]) / dt
        )
    else
        love.audio.setVelocity(0, 0, 0)
    end

    previousListenerPosition = { x, y, z }
end

-- Cria uma fonte espacial.
-- path: caminho do áudio, SoundData, File ou Decoder aceito pelo LÖVE.
-- options: type, position, volume, pitch, loop, referenceDistance,
--          maxDistance, rolloff, direction, cone e airAbsorption.
function som3d.new(path, options)
    assert(path ~= nil, "som3d.new: informe um arquivo ou dado de áudio")
    options = options or {}

    local sourceType = options.type or "static"
    assert(sourceType == "static" or sourceType == "stream",
        "som3d: type precisa ser 'static' ou 'stream'")

    local source = love.audio.newSource(path, sourceType)

    -- O LÖVE só espacializa corretamente fontes mono.
    if type(source.getChannelCount) == "function" then
        local channels = source:getChannelCount()
        if channels ~= 1 then
            if type(source.release) == "function" then
                source:release()
            end
            error("som3d: áudio precisa ser MONO (1 canal); este arquivo tem " .. tostring(channels) .. " canais")
        end
    end

    local position = options.position or { 0, 0, 0 }
    local x, y, z = position[1] or 0, position[2] or 0, position[3] or 0
    checkNumber(x, "position[1]")
    checkNumber(y, "position[2]")
    checkNumber(z, "position[3]")

    local referenceDistance = options.referenceDistance or 1
    local maxDistance = options.maxDistance or 50
    local rolloff = options.rolloff or 1
    checkNumber(referenceDistance, "referenceDistance")
    checkNumber(maxDistance, "maxDistance")
    checkNumber(rolloff, "rolloff")
    assert(referenceDistance > 0, "som3d: referenceDistance precisa ser maior que zero")
    assert(maxDistance >= referenceDistance, "som3d: maxDistance precisa ser >= referenceDistance")
    assert(rolloff >= 0, "som3d: rolloff não pode ser negativo")

    source:setRelative(false)
    source:setPosition(x, y, z)
    source:setAttenuationDistances(referenceDistance, maxDistance)
    source:setRolloff(rolloff)
    source:setVolume(options.volume == nil and 1 or options.volume)
    source:setPitch(options.pitch or 1)
    source:setLooping(options.loop == true)

    local emitter = setmetatable({
        source = source,
        x = x,
        y = y,
        z = z,
        destroyed = false,
    }, Emitter)

    if options.direction then
        emitter:setDirection(options.direction[1], options.direction[2], options.direction[3])
    end

    if options.cone then
        emitter:setCone(options.cone.innerAngle, options.cone.outerAngle, options.cone.outerVolume)
    end

    if options.airAbsorption ~= nil then
        emitter:setAirAbsorption(options.airAbsorption)
    end

    if options.filter then
        emitter:setFilter(options.filter)
    end

    return emitter
end

function Emitter:play()
    checkEmitter(self)
    self.source:play()
    return self
end

function Emitter:pause()
    checkEmitter(self)
    self.source:pause()
    return self
end

function Emitter:stop()
    checkEmitter(self)
    self.source:stop()
    return self
end

function Emitter:isPlaying()
    checkEmitter(self)
    return self.source:isPlaying()
end

-- Passe dt para calcular a velocidade e habilitar Doppler nesta movimentação.
function Emitter:setPosition(x, y, z, dt)
    checkEmitter(self)
    checkNumber(x, "x")
    checkNumber(y, "y")
    checkNumber(z, "z")

    if dt and dt > 0 then
        self.source:setVelocity(
            (x - self.x) / dt,
            (y - self.y) / dt,
            (z - self.z) / dt
        )
    else
        self.source:setVelocity(0, 0, 0)
    end

    self.x, self.y, self.z = x, y, z
    self.source:setPosition(x, y, z)
    return self
end

-- Atalho para atualizar a posição de uma fonte móvel.
function Emitter:update(dt, x, y, z)
    checkEmitter(self)
    if x ~= nil then
        self:setPosition(x, y, z, dt)
    end
    return self
end

function Emitter:setVelocity(x, y, z)
    checkEmitter(self)
    checkNumber(x, "x")
    checkNumber(y, "y")
    checkNumber(z, "z")
    self.source:setVelocity(x, y, z)
    return self
end

function Emitter:setVolume(volume)
    checkEmitter(self)
    checkNumber(volume, "volume")
    self.source:setVolume(math.max(0, math.min(1, volume)))
    return self
end

function Emitter:setPitch(pitch)
    checkEmitter(self)
    checkNumber(pitch, "pitch")
    assert(pitch > 0, "som3d: pitch precisa ser maior que zero")
    self.source:setPitch(pitch)
    return self
end

function Emitter:setLooping(enabled)
    checkEmitter(self)
    self.source:setLooping(enabled == true)
    return self
end

function Emitter:setDistances(referenceDistance, maxDistance)
    checkEmitter(self)
    checkNumber(referenceDistance, "referenceDistance")
    checkNumber(maxDistance, "maxDistance")
    assert(referenceDistance > 0 and maxDistance >= referenceDistance,
        "som3d: distâncias inválidas")
    self.source:setAttenuationDistances(referenceDistance, maxDistance)
    return self
end

function Emitter:setRolloff(rolloff)
    checkEmitter(self)
    checkNumber(rolloff, "rolloff")
    assert(rolloff >= 0, "som3d: rolloff não pode ser negativo")
    self.source:setRolloff(rolloff)
    return self
end

function Emitter:setDirection(x, y, z)
    checkEmitter(self)
    checkNumber(x, "x")
    checkNumber(y, "y")
    checkNumber(z, "z")
    self.source:setDirection(x, y, z)
    return self
end

-- Ângulos em radianos. Ex.: math.rad(45), math.rad(90), 0.2.
function Emitter:setCone(innerAngle, outerAngle, outerVolume)
    checkEmitter(self)
    checkNumber(innerAngle, "innerAngle")
    checkNumber(outerAngle, "outerAngle")
    outerVolume = outerVolume == nil and 0 or outerVolume
    checkNumber(outerVolume, "outerVolume")
    self.source:setCone(innerAngle, outerAngle, outerVolume)
    return self
end

function Emitter:setAirAbsorption(amount)
    checkEmitter(self)
    checkNumber(amount, "amount")
    assert(amount >= 0 and amount <= 10, "som3d: airAbsorption precisa estar entre 0 e 10")
    assert(type(self.source.setAirAbsorption) == "function",
        "som3d: setAirAbsorption requer LÖVE 11.2 ou superior")
    self.source:setAirAbsorption(amount)
    return self
end

function Emitter:setFilter(settings)
    checkEmitter(self)
    assert(type(self.source.setFilter) == "function",
        "som3d: filtros requerem LÖVE 11.0 ou superior")
    self.source:setFilter(settings)
    return self
end

function som3d.defineEffect(name, settings)
    assert(type(love.audio.setEffect) == "function",
        "som3d: efeitos requerem LÖVE 11.0 ou superior")
    return love.audio.setEffect(name, settings)
end

function som3d.isEffectsSupported()
    if type(love.audio.isEffectsSupported) ~= "function" then
        return false
    end
    return love.audio.isEffectsSupported()
end

function Emitter:setEffect(name, enabledOrFilter)
    checkEmitter(self)
    assert(type(self.source.setEffect) == "function",
        "som3d: efeitos requerem LÖVE 11.0 ou superior")
    if enabledOrFilter == nil then
        self.source:setEffect(name, true)
    else
        self.source:setEffect(name, enabledOrFilter)
    end
    return self
end

function Emitter:removeEffect(name)
    checkEmitter(self)
    assert(type(self.source.setEffect) == "function",
        "som3d: efeitos requerem LÖVE 11.0 ou superior")
    self.source:setEffect(name, false)
    return self
end

function Emitter:getSource()
    checkEmitter(self)
    return self.source
end

function Emitter:destroy()
    if self.destroyed then
        return
    end
    self.source:stop()
    if type(self.source.release) == "function" then
        self.source:release()
    end
    self.destroyed = true
    self.source = nil
end

som3d.Emitter = Emitter

return som3d
