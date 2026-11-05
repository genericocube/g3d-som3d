-- som3d.lua
-- Audio espacial 3D para LÖVE + g3d.
-- Use as mesmas coordenadas XYZ dos modelos e da câmera do g3d.
-- Todos os comandos têm nomes em inglês e em português (veja o fim do arquivo).

local som3d = {}
local Emitter = {}
Emitter.__index = Emitter

-- Limite de velocidade (unidades por segundo) usado no efeito Doppler.
-- Evita um "estalo" de pitch quando a câmera ou uma fonte teletransporta.
-- Use nil para desligar o limite.
som3d.maxSpeed = 200

local listener = { x = 0, y = 0, z = 0, ready = false }
local emitters = setmetatable({}, { __mode = "k" }) -- todas as fontes vivas (para follow)
local oneShots = {}                                  -- sons criados por playAt
local sourceCache = setmetatable({}, { __mode = "k" })

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

local function clampSpeed(vx, vy, vz)
    local max = som3d.maxSpeed
    if max then
        local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
        if speed > max then
            local k = max / speed
            return vx * k, vy * k, vz * k
        end
    end
    return vx, vy, vz
end

local function checkEmitter(self)
    assert(not self.destroyed, "som3d: este som já foi destruído")
end

local function isType(value, typeName)
    return type(value) == "userdata" and value:typeOf(typeName)
end

----------------------------------------------------------------------------------------------------
-- carregamento de áudio
----------------------------------------------------------------------------------------------------

-- mistura um SoundData com vários canais em um só (o LÖVE só espacializa fontes mono)
local function toMono(data)
    local channels = data:getChannelCount()
    if channels == 1 then return data end
    local frames = data:getSampleCount()
    local mono = love.sound.newSoundData(frames, data:getSampleRate(), data:getBitDepth(), 1)
    for i = 0, frames - 1 do
        local sum = 0
        for c = 0, channels - 1 do
            sum = sum + data:getSample(i * channels + c)
        end
        mono:setSample(i, sum / channels)
    end
    return mono
end

-- cria uma Source mono a partir de caminho, File, FileData, Decoder ou SoundData
-- áudios estéreo "static" são convertidos para mono automaticamente (downmix)
-- áudios "stream" precisam já ser mono
local function createSource(sound, sourceType, downmix)
    if sourceType == "stream" and not isType(sound, "SoundData") then
        local decoder = isType(sound, "Decoder") and sound or love.sound.newDecoder(sound)
        local channels = decoder:getChannelCount()
        assert(channels == 1, "som3d: áudio 'stream' precisa ser MONO (1 canal); este tem "
            .. channels .. " canais. Use type = 'static' para converter automaticamente")
        return love.audio.newSource(decoder, "stream")
    end

    local data = isType(sound, "SoundData") and sound or love.sound.newSoundData(sound)
    if data:getChannelCount() ~= 1 then
        assert(downmix, "som3d: áudio precisa ser MONO (1 canal); este tem "
            .. data:getChannelCount() .. " canais")
        data = toMono(data)
    end
    return love.audio.newSource(data, "static")
end

----------------------------------------------------------------------------------------------------
-- configuração global
----------------------------------------------------------------------------------------------------

-- Chame uma vez em love.load().
-- options: distanceModel, dopplerScale, maxSpeed, volume (volume geral)
function som3d.init(options)
    options = options or {}

    love.audio.setDistanceModel(options.distanceModel or "inverseclamped")

    if options.dopplerScale ~= nil then
        checkNumber(options.dopplerScale, "dopplerScale")
        assert(options.dopplerScale > 0, "som3d: dopplerScale precisa ser maior que zero")
        love.audio.setDopplerScale(options.dopplerScale)
    end

    if options.maxSpeed ~= nil then
        checkNumber(options.maxSpeed, "maxSpeed")
        assert(options.maxSpeed > 0, "som3d: maxSpeed precisa ser maior que zero")
        som3d.maxSpeed = options.maxSpeed
    end

    if options.volume ~= nil then
        som3d.setMasterVolume(options.volume)
    end

    listener.ready = false
    return som3d
end

-- Volume geral de todos os sons, de 0 a 1.
function som3d.setMasterVolume(volume)
    checkNumber(volume, "volume")
    love.audio.setVolume(math.max(0, math.min(1, volume)))
end

function som3d.getMasterVolume()
    return love.audio.getVolume()
end

-- Chame depois de teletransportar a câmera para o Doppler não reagir ao salto.
function som3d.resetListener()
    listener.ready = false
end

-- Sincroniza o ouvinte com uma câmera do g3d, move as fontes que usam follow()
-- e limpa os sons de playAt() que terminaram.
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

    if dt and dt > 0 and listener.ready then
        love.audio.setVelocity(clampSpeed(
            (x - listener.x) / dt,
            (y - listener.y) / dt,
            (z - listener.z) / dt
        ))
    else
        love.audio.setVelocity(0, 0, 0)
    end

    listener.x, listener.y, listener.z, listener.ready = x, y, z, true

    -- fontes que seguem um modelo
    for emitter in pairs(emitters) do
        local target = emitter.target
        if target and not emitter.destroyed then
            local t = target.translation or target
            local o = emitter.offset
            -- no primeiro quadro não há velocidade (evita pico de Doppler)
            local moveDt = emitter.followed and dt or nil
            emitter:setPosition(t[1] + o[1], t[2] + o[2], t[3] + o[3], moveDt)
            emitter.followed = true
        end
    end

    -- remove sons de playAt() que já terminaram
    for i = #oneShots, 1, -1 do
        local emitter = oneShots[i]
        if emitter.destroyed then
            table.remove(oneShots, i)
        elseif not emitter.paused and not emitter.source:isPlaying() then
            emitter:destroy()
            table.remove(oneShots, i)
        end
    end
end

----------------------------------------------------------------------------------------------------
-- criação de fontes
----------------------------------------------------------------------------------------------------

local function buildEmitter(source, options)
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

    local emitter = setmetatable({
        source = source,
        x = x,
        y = y,
        z = z,
        destroyed = false,
        paused = false,
        offset = { 0, 0, 0 },
    }, Emitter)

    emitter:setVolume(options.volume == nil and 1 or options.volume)
    emitter:setPitch(options.pitch or 1)
    emitter:setLooping(options.loop == true)

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

    if options.follow then
        emitter:follow(options.follow)
    end

    emitters[emitter] = true
    return emitter
end

-- Cria uma fonte espacial.
-- sound: caminho do áudio, SoundData, File, FileData ou Decoder aceito pelo LÖVE.
-- options: type, position, volume, pitch, loop, referenceDistance, maxDistance, rolloff,
--          direction, cone, airAbsorption, filter, follow e downmix.
--   type = "static" (padrão) ou "stream"
--   downmix = true (padrão) converte áudio estéreo "static" para mono automaticamente
--   follow = modelo do g3d (ou tabela {x, y, z}) que a fonte acompanha
function som3d.new(sound, options)
    assert(sound ~= nil, "som3d.new: informe um arquivo ou dado de áudio")
    options = options or {}

    local sourceType = options.type or "static"
    assert(sourceType == "static" or sourceType == "stream",
        "som3d: type precisa ser 'static' ou 'stream'")

    return buildEmitter(createSource(sound, sourceType, options.downmix ~= false), options)
end

-- Toca um som uma vez em uma posição e se limpa sozinho quando termina
-- (tiros, passos, explosões...). O arquivo é carregado só na primeira vez.
-- Aceita as mesmas options de som3d.new, menos type e loop. Retorna a fonte criada.
function som3d.playAt(sound, x, y, z, options)
    assert(sound ~= nil, "som3d.playAt: informe um arquivo ou dado de áudio")
    checkNumber(x, "x")
    checkNumber(y, "y")
    checkNumber(z, "z")
    options = options or {}

    local template = sourceCache[sound]
    if not template then
        template = createSource(sound, "static", options.downmix ~= false)
        sourceCache[sound] = template
    end

    local settings = {}
    for key, value in pairs(options) do settings[key] = value end
    settings.position = { x, y, z }
    settings.loop = false

    local emitter = buildEmitter(template:clone(), settings)
    oneShots[#oneShots + 1] = emitter
    emitter:play()
    return emitter
end

-- Para todos os sons e destrói os criados por playAt().
function som3d.stopAll()
    love.audio.stop()
    for i = #oneShots, 1, -1 do
        oneShots[i]:destroy()
        oneShots[i] = nil
    end
    for emitter in pairs(emitters) do
        emitter.paused = false
    end
end

----------------------------------------------------------------------------------------------------
-- fontes (Emitter)
----------------------------------------------------------------------------------------------------

function Emitter:play()
    checkEmitter(self)
    self.paused = false
    self.source:play()
    return self
end

function Emitter:pause()
    checkEmitter(self)
    self.paused = true
    self.source:pause()
    return self
end

-- continua um som pausado (o mesmo que play)
Emitter.resume = Emitter.play

function Emitter:stop()
    checkEmitter(self)
    self.paused = false
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
        self.source:setVelocity(clampSpeed(
            (x - self.x) / dt,
            (y - self.y) / dt,
            (z - self.z) / dt
        ))
    else
        self.source:setVelocity(0, 0, 0)
    end

    self.x, self.y, self.z = x, y, z
    self.source:setPosition(x, y, z)
    return self
end

function Emitter:getPosition()
    checkEmitter(self)
    return self.x, self.y, self.z
end

-- Atalho para atualizar a posição de uma fonte móvel.
function Emitter:update(dt, x, y, z)
    checkEmitter(self)
    if x ~= nil then
        self:setPosition(x, y, z, dt)
    end
    return self
end

-- Faz a fonte acompanhar um modelo do g3d (qualquer tabela com .translation) ou uma tabela
-- {x, y, z}, com um deslocamento opcional. O movimento e o Doppler são atualizados em
-- som3d.update(). Chame follow(nil) para parar de seguir.
function Emitter:follow(target, offsetX, offsetY, offsetZ)
    checkEmitter(self)
    assert(target == nil or type(target) == "table",
        "som3d: follow precisa de um modelo do g3d, uma tabela {x, y, z} ou nil")
    self.target = target
    self.offset = { offsetX or 0, offsetY or 0, offsetZ or 0 }
    self.followed = false
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

-- volume de 0 a 1
function Emitter:setVolume(volume)
    checkEmitter(self)
    checkNumber(volume, "volume")
    self.source:setVolume(math.max(0, math.min(1, volume)))
    return self
end

function Emitter:getVolume()
    checkEmitter(self)
    return self.source:getVolume()
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
    self.target = nil
    emitters[self] = nil
end

som3d.Emitter = Emitter

----------------------------------------------------------------------------------------------------
-- nomes em português
----------------------------------------------------------------------------------------------------

som3d.iniciar = som3d.init
som3d.atualizar = som3d.update
som3d.novo = som3d.new
som3d.tocarEm = som3d.playAt
som3d.pararTudo = som3d.stopAll
som3d.volumeGeral = som3d.setMasterVolume
som3d.reiniciarOuvinte = som3d.resetListener

Emitter.tocar = Emitter.play
Emitter.pausar = Emitter.pause
Emitter.continuar = Emitter.resume
Emitter.parar = Emitter.stop
Emitter.tocando = Emitter.isPlaying
Emitter.posicao = Emitter.setPosition
Emitter.seguir = Emitter.follow
Emitter.volume = Emitter.setVolume
Emitter.tom = Emitter.setPitch
Emitter.repetir = Emitter.setLooping
Emitter.distancias = Emitter.setDistances
Emitter.atenuacao = Emitter.setRolloff
Emitter.direcao = Emitter.setDirection
Emitter.cone = Emitter.setCone
Emitter.destruir = Emitter.destroy

return som3d
