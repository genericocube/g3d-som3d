# som3d

Módulo de áudio espacial 3D para **LÖVE 11.4+**, pensado para usar as mesmas coordenadas XYZ de `g3d`.

## Testar a demonstração

1. Instale o LÖVE 11.4 ou mais recente.
2. Extraia o ZIP.
3. Arraste a pasta `som3d-demo` para o executável do LÖVE ou execute `love som3d-demo` no terminal.
4. Use os controles mostrados na janela para mover o ouvinte e a fonte sonora.

O mapa da demonstração é uma vista superior 2D para facilitar a visualização das coordenadas. **O áudio é espacializado em 3D**, incluindo altura (Z), distância, orientação, atenuação e Doppler. O exemplo usa uma câmera de teste com a mesma estrutura pública de `g3d.camera`, sem exigir que o g3d esteja instalado apenas para testar o áudio.

### Controles

| Tecla | Ação |
|---|---|
| `W A S D` | Mover o ouvinte no plano X/Y |
| `Espaço` / `Shift` | Subir / descer o ouvinte (Z) |
| Setas | Girar a direção do ouvinte |
| `I J K L` | Mover a fonte sonora no plano X/Y |
| `U` / `O` | Subir / descer a fonte sonora (Z) |
| `P` | Pausar / reproduzir o som |
| `F` | Ativar / desativar filtro low-pass |
| `R` | Ativar / desativar reverb (depende do suporte do dispositivo) |
| `C` | Ativar / desativar áudio direcional |
| `Backspace` | Reiniciar as posições |
| `Esc` | Fechar |

O arquivo `assets/beep_mono.wav` é um som de demonstração mono gerado para este projeto.

## Usar no seu projeto com g3d

Copie `som3d.lua` para a pasta do seu projeto e importe o módulo:

```lua
local som3d = require("som3d")
local som

function love.load()
    som3d.init({
        distanceModel = "inverseclamped",
        dopplerScale = 1,
    })

    som = som3d.new("assets/meu_som_mono.ogg", {
        position = { 8, 0, 0 },
        volume = 1,
        loop = true,
        referenceDistance = 1,
        maxDistance = 35,
        rolloff = 1,
    })

    som:play()
end

function love.update(dt)
    g3d.camera.firstPersonMovement(dt)
    som3d.update(g3d.camera, dt)
end
```

**Importante:** fontes posicionais precisam ser arquivos de áudio **mono (1 canal)**. Arquivos estéreo não podem ser espacializados pelo áudio posicional nativo do LÖVE. As coordenadas do som e da câmera devem usar a mesma escala e os mesmos eixos.

## API básica

### `som3d.init(options)`

Inicializa as configurações globais. Opções:

- `distanceModel`: `"inverseclamped"`, `"inverse"`, `"linear"`, `"linearclamped"`, `"exponent"`, `"exponentclamped"` ou `"none"`.
- `dopplerScale`: intensidade global do efeito Doppler (maior que zero).

### `som3d.update(camera, dt)`

Atualiza posição, orientação e velocidade do ouvinte. No g3d, passe `g3d.camera` depois de atualizar a câmera.

### `som3d.new(path, options)`

Cria uma fonte espacial. Opções principais:

- `position = {x, y, z}`
- `type = "static"` ou `"stream"`
- `volume`, `pitch`, `loop`
- `referenceDistance`, `maxDistance`, `rolloff`
- `direction = {x, y, z}`
- `cone = {innerAngle, outerAngle, outerVolume}` — ângulos em radianos
- `airAbsorption` — de 0 a 10 (quando disponível na versão do LÖVE)
- `filter` — configuração de filtro suportada pelo LÖVE

### Métodos da fonte

`play()`, `pause()`, `stop()`, `isPlaying()`, `setPosition(x, y, z, dt)`, `update(dt, x, y, z)`, `setVelocity(x, y, z)`, `setVolume(value)`, `setPitch(value)`, `setLooping(bool)`, `setDistances(referenceDistance, maxDistance)`, `setRolloff(value)`, `setDirection(x, y, z)`, `setCone(inner, outer, outerVolume)`, `setAirAbsorption(value)`, `setFilter(settings)`, `setEffect(name, enabled)`, `removeEffect(name)`, `getSource()` e `destroy()`.

O Doppler depende da atualização de velocidade: use `som3d.update(camera, dt)` para o ouvinte e `source:update(dt, x, y, z)` para fontes móveis.

## Efeitos

Os efeitos de áudio dependem do suporte do dispositivo/driver. Verifique `som3d.isEffectsSupported()` antes de usar `som3d.defineEffect(name, settings)` e `source:setEffect(name, true)`.

Filtros nativos estão disponíveis por `source:setFilter({ type = "lowpass", highgain = 0.2 })`. Para remover o filtro, use `source:setFilter(nil)`.

## Estrutura

```text
som3d-demo/
├── assets/
│   └── beep_mono.wav
├── conf.lua
├── main.lua
├── som3d.lua
└── README.md
```

## Licença

Este projeto é disponibilizado sob a licença MIT. O arquivo WAV de demonstração foi gerado especificamente para este exemplo.
