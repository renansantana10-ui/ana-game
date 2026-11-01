# ANA-GAME-003-B — Official Vehicle Gameplay Integration Report

**Data:** 2026-11-01 · **Branch:** `feat/ana-game-003` · **Commit inicial (HEAD, preservado):** `76fa645bbd2a3f889b399c7b6bf7b1ffee94a86a` (ANA-GAME-003-A) · **Sem commit/push/merge.**
**Status:** `PASS WITH LIMITATIONS` — integração implementada e validada por testes automatizados, capturas reais com janela e smoke test Web; **teste manual F5 humano e revisão artística não realizados** (NOT VERIFIED).

## 1. O que mudou (visual apenas)

| Arquivo | Mudança |
|---|---|
| `scripts/official_vehicle_visual.gd` (novo) | `OfficialVehicleVisual extends RideOnVisual`: adaptador de apresentação. Mantém `update_wheels(speed, steer_angle, delta)`; gira as 4 rodas, esterça as dianteiras e o guidão; expõe a pose efetiva do banco. Não lê input, não toca física. |
| `scenes/ride_on_vehicle.tscn` | `VehicleVisualRoot` usa o adaptador; novo `VisualAlignmentRoot/OfficialVehicleGLB` (GLB instanciado **uma vez**); `ground_lift = 0.012`. Corpo, cápsula, `VehicleCameraTarget`, `DismountAnchor` e caminhos exportados inalterados. |
| `tests/test_vehicle.gd` | Só a seção 1 (checagem do visual): troca `…/Spin/Tire` e `PrimitiveMesh` por pivô → malha da roda e `BaseMaterial3D` do GLB. |
| `tests/validation/test_vehicle_glb_import.gd` | T10 atualizado (checagem de "HEAD = base" ficou obsoleta com o commit 003-A; agora confere que os artefatos da 003-A não mudaram). |
| novos | `tests/validation/{test_vehicle_official_visual,capture_gameplay,perf_probe}.gd`, esta pasta de evidências. |

**Não alterados** (verificado por `git diff` contra o commit 003-A): `vehicle_controller.gd`, `vehicle_interaction.gd`, `player_controller.gd`, `third_person_camera.gd`, `controls_hud.gd`, `ride_on_visual.gd`, `main.tscn`, `player.tscn`, `farm_world.tscn`, `project.godot`, `export_presets.cfg`, o GLB e as cenas de preview da 003-A. GLB de produção e importado: SHA-256 `E1725EF7…846E` inalterado.

## 2. Decisões técnicas

- **Física:** o veículo é `CharacterBody3D` cinemático (sem `VehicleBody3D`/`VehicleWheel3D`). O controlador chama `visual_root.update_wheels(speed, steer*0.5, delta)` se `visual_root is RideOnVisual`; o adaptador herda de `RideOnVisual` só para manter essa chamada intacta, sobrescreve `_ready()` (nunca monta os primitivos) e `update_wheels()`.
- **Mapeamento das rodas** (papel pelo nome do pivô; Spin = primeiro filho `Node3D`): FL `Vehicle/FrontLeftWheel`→`Spin`; FR `…FrontRightWheel`→`Spin2`; RL `…RearLeftWheel`→`Spin3`; RR `…RearRightWheel`→`Spin4`. O teste confere também a posição física (esquerda = −X, frente = −Z).
- **Rolagem:** `ângulo −= speed·delta/0,1226` (raio visual medido; o 0,13 do placeholder não é usado), acumulado, ±π, sobre o *rest transform*; eixo X local (igual nas 4). Sinal vem de `speed` do controlador (com sinal; inclusive no ar e na derrapagem).
- **Esterço:** pivô das rodas dianteiras `Basis(UP, steer)·rest` (+ = esquerda); rolagem preservada no `Spin`; traseiras fixas. **Guidão:** `HandlebarPivot` em Y = `steer × 1,0`, suavizado (24/s), relativo ao rest.
- **Alinhamento:** orientação já coincide (−Z/+Y), sem rotação corretiva. O corpo repousa 0,0093 m abaixo da superfície e o pneu do GLB tem 0,0027 m abaixo de y=0 → `ground_lift` 0,012 m (visual) deixa o pneu a −0,6 mm do piso.
- **Banco:** o `Marker3D` `SeatAnchor` do gameplay recebe a pose do `SeatAnchor` do GLB: **(0, 0,2996, 0,105)** (antes (0, 0,22, 0,10); +0,0796 m = +0,0676 do GLB + 0,012 de lift). `VehicleInteraction` não mudou.
- **Placeholder desativado:** nenhum primitivo é construído (13 malhas = só as do GLB). Reverter: script de `VehicleVisualRoot` de volta para `ride_on_visual.gd`.

## 3. Testes (Godot 4.7.2, Compatibility)

| Execução | Resultado |
|---|---|
| Baseline pré-edição (`baseline_*`) | `--import`, boot, `smoke_test`, `test_camera_follow`, `test_farm_terrain`, `test_sprint`, `test_vehicle`, `test_drift` todos PASS; `test_vehicle_glb_import` 59/1 (falha esperada: check "HEAD = main" obsoleto após o commit 003-A) |
| `--import` | exit 0, sem erros/avisos |
| `test_vehicle_official_visual.gd` (novo) | **PASS, 0 falhas** — T01 integração/assinatura; T02 visual único (13 malhas, 0 primitivos, 1 PinkBody, sem 2º corpo/câmera); T03 mapeamento; T04 rolagem (ângulo = −v·t/r, dobro, ±π, rodas no eixo); T05 ré; T06 frenagem monotônica/idle sem reset; T07 esterço (dianteiras, traseiras fixas, retorno exato); T08 guidão (alvo, sentido, interpolação, retorno); T09 raio 0,1226 vs 0,13, física inalterada, pneus ≤ 3 mm do piso; T10 banco/montar/1 jogador/pose; T11–T13 teclas reais W/A/D/S, deriva com Espaço (sem impulso vertical) e recuperação; T15 desmontar; T16 finitos; T17 hash do GLB, git sem alterações protegidas, sem novo commit |
| `test_vehicle_glb_import.gd` (003-A) | 58 PASS, 0 FAIL, 1 NOT VERIFIED (semântica de orientação, já registrada) |
| `smoke_test`, `test_camera_follow`, `test_farm_terrain`, `test_sprint`, `test_vehicle`, `test_drift` | **todos PASS** com o GLB oficial (cobrem aceleração, freio, ré, curvas, derrapagem, colinas, rampas, E, câmera, a pé) |
| Boot `main.tscn` (headless e janela OpenGL 3.3) | sem erros |

Prova adicional de que a física não mudou: a sonda de desempenho com o mesmo script de teclas termina na **mesma posição exata** (−11,95856; 0,155598; −42,17855) com o placeholder e com o GLB oficial.

## 4. Verificação visual (capturas reais, janela 1280×720, Compatibility)

`validation/ana-game-003-b/screenshots/` (16 imagens, via `capture_gameplay.gd`, com teclas reais): veículo estacionado (2 ângulos), câmera do jogo a pé, montado (lateral/frente/traseira + câmera do jogo), curva à esquerda (rodas e guidão esterçados), derrapagem (Espaço + D), rampa no ar, colina, a pé. Observado: GLB oficial rosa/menta no lugar do placeholder, sem geometria duplicada, pneus no chão, rodas dianteiras e guidão virando para o lado correto, personagem provisória sentada e centrada no banco, seguindo a inclinação.

Observações (não são defeitos do GLB): a iluminação provisória do mundo (céu azul) tinge o rosa de lilás; a personagem provisória (cápsula 0,4 m) é grande para o brinquedo (0,40 × 0,578 × 0,745 m); a câmera de pilotagem a 4,5 m deixa o veículo pequeno — **não alterado** (câmera aprovada).

## 5. Desempenho (1280×720, vsync desligado, RTX 3050 Laptop, mesma rota por teclas)

| Cenário | Frame médio | p99 | Máx. | Draw calls | Primitivas | Objetos | Memória estática / VRAM |
|---|---|---|---|---|---|---|---|
| Placeholder, parado montado | 0,57 ms | 1,13 | 7,48 | 131 | 204.446 | 211 | 73,5 / 23,2 MB |
| Placeholder, dirigindo | 0,59 ms | 1,33 | 2,05 | 116 | 200.331 | 196 | — |
| **GLB oficial, parado** (3 execuções) | 0,57–0,58 ms | 1,05–1,09 | 1,5–2,3 | 146 | 126.467 | 226 | 73,9 / 19–25 MB |
| **GLB oficial, dirigindo** (3 execuções) | 0,56–0,57 ms | 1,08 | 1,65–3,15 | 131 | ~122.300 | 211 | — |

Instanciar `main.tscn`: 55 ms (placeholder) vs 35 ms (oficial). Conclusão: **+15 draw calls/objetos, sem regressão mensurável de tempo de quadro**; menos primitivas renderizadas (204 mil → 126 mil; causa não investigada, provavelmente a tesselação dos primitivos do placeholder). Em hardware fraco/Web real não medido (a GPU aqui é muito acima da média).

## 6. Web

Export `godot --headless --export-release "Web" export/web/index.html` (preset existente): exit 0, `index.pck` 709 KB, `index.wasm` 39,5 MB (pasta `export/` ignorada pelo Git). Servido em `http://127.0.0.1:8060` e aberto no navegador embutido (WebGL 2.0, Emscripten 4.0.20 single-thread): GLB renderiza com materiais corretos; prompt "E — Subir no veículo"; montou, dirigiu, virou, derrapou (Espaço + D), desmontou e voltou a andar; console sem erros (apenas 4 avisos WebGL de framebuffer "zero size" no carregamento do pane, já vistos na 002-C). **Limitação:** entrada por **eventos de teclado sintéticos** (não é teste humano) e pane de 800×600; Chrome real e captura de mouse **NOT VERIFIED**.

## 7. Classificação

| Item | Status |
|---|---|
| GLB oficial ativo, sem duplicata; adaptador modular; assinatura `update_wheels` preservada | PASS |
| 4 rodas girando (frente/ré), dianteiras esterçando, guidão acompanhando | PASS (testes + capturas) |
| Raio visual 0,1226 vs física intocada; pneus no solo | PASS (≤ 3 mm; lift visual documentado) |
| Banco/personagem, 1 jogador, E montar/desmontar | PASS (testes + capturas) |
| Pilotagem, derrapagem (Espaço), câmera, a pé, colinas/rampas | PASS (regressão existente + novo teste) |
| Desempenho inicial | PASS (sem regressão mensurável) |
| Web local (smoke com teclas sintéticas) | PASS WITH LIMITATIONS |
| **F5 interativo humano (sequência A–G da missão)** | **NOT VERIFIED** — depende do usuário |

## 8. Pendências / recomendações

1. Usuário rodar o F5 (roteiro A–G do pedido) e o Chrome real.
2. 003-C: personagem definitiva com pose sentada (capsule atual > brinquedo); reavaliar `riding_camera_distance`, cápsula do veículo (0,48 × 0,80 vs visual 0,40 × 0,745) e `DismountAnchor` — todos inalterados aqui.
3. Iluminação/ambiente do mundo: decisão da arte (rosa fica lilás sob o céu atual).
4. Contrato: anexo "Achados da integração ANA-GAME-003-B" adicionado a `ANA-ASSET-CONTRACT-001` (decisões originais preservadas).
