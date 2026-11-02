# ANA-GAME-003-A — Vehicle GLB Validation Report

**Missão:** Official Vehicle GLB Import, Inspection & Validation · **Data:** 2026-11-01 · **Branch:** `feat/ana-game-003` (sem commit)
**Base verificada:** `main` = `origin/main` = `4b925e96be31196a3e8d344af07633e7dd844793` (fetch de `origin main` OK; árvore limpa antes do branch).
**Escopo:** importação, inspeção e validação isolada. O GLB **não** foi integrado ao gameplay; `RideOnVisual`, `vehicle_controller.gd`, câmera, colisões e `main.tscn` não foram tocados.

**Avaliação geral: `READY WITH DOCUMENTED ADJUSTMENTS`** · **Status da missão: `PASS WITH LIMITATIONS`** (limitações na seção K).

---

## A. Source asset

| Item | Valor |
|---|---|
| Origem | `D:\ana game\producao-assets-3d\exports-glb\ana-veiculo-integracao-v01.glb` |
| Tamanho | 400.436 bytes |
| SHA-256 | `E1725EF7618C869DAFF49477002EB977C2633BC0EE4A11E9B6D2C2EE2ACE846E` |
| Modificação (UTC) | 2026-11-01T21:18:54Z (inalterada ao fim da missão; hash reconferido no Teste 09) |
| Cópia no projeto | `res://assets/vehicles/ana-veiculo-integracao-v01.glb` (pasta nova; o projeto não tinha pasta de assets) |
| Verificação da cópia | SHA-256 e tamanho idênticos (byte a byte) — PASS |

O original não foi aberto/regravado no Blender; `.blend` e scripts de produção não foram tocados.

## B. Import

- Godot `4.7.2.stable.official.ed1daf0bf`; renderer `gl_compatibility` (inalterado; `project.godot` sem diff).
- `--headless --editor --import --quit`: exit 0, **sem erros nem avisos** (`log_import.txt`).
- Importador `scene` nativo, **opções padrão** (nenhum ajuste de importação foi necessário): `apply_root_scale=true`, `root_scale=1.0`, `generate_lods=true`, `create_shadow_meshes=true`, `animation/import=true`, `materials/extract=0`. Nenhuma colisão gerada, nenhum nó de animação/luz/câmera/esqueleto no cena importada.
- Raiz importada: `Node3D` `ana-veiculo-integracao-v01` → filho `Vehicle` (`Node3D`, identidade). Transform da raiz: identidade (escala 1, sem offset, sem rotação).
- Carregamento: `load()` retorna `PackedScene`, instanciável; 5 materiais e 11 recursos de malha disponíveis.
- `ana-veiculo-integracao-v01.glb.import` é gerado pelo Godot e deve ser versionado junto do GLB (convenção Godot).

## C. Geometry

Contagem de triângulos (método: soma de `surface_get_arrays` por `MeshInstance3D`; LODs/shadow meshes gerados pelo importador **não** contados):

| Contagem | Resultado |
|---|---|
| Por instância (cada `MeshInstance3D` contada) | **25.772** = referência Blender (diferença 0) |
| Por recurso de malha único (sem duplicar malhas compartilhadas) | 18.908 (11 recursos; `WheelMesh_Left`/`WheelMesh_Right` são reutilizadas 2× cada) |

Inventário (13 `MeshInstance3D`): `PinkBody` 1.872 · `ElongatedSeat` 3.216 · `FrontAxle` 92 · `RearAxle` 92 · `FrontLamp` 336 · `SteeringPostLower` 2.110 · `SteeringPostUpper` 774 · `TriangularHandlebar` 864 · `HandlebarGrip` 2.688 · 4 × malha de roda 3.432. Todas com bounds finitos e não degenerados; transforms de malha = identidade (geometria "assada" nas coordenadas do veículo).

## D. Materials

Esperado 5 · **real 5** (todos `StandardMaterial3D`, opacos, **sem texturas**, só cor base/rugosidade/metálico):

| Material | Albedo (RGB) | Rugosidade | Metálico | Usado em |
|---|---|---|---|---|
| `ANA_Mat_Rosa_Provisorio` | 0,957 / 0,659 / 0,761 | 0,34 | 0 | corpo, banco, guidão, empunhadura, hastes (colar) |
| `ANA_Mat_VerdeMenta_Provisorio` | 0,690 / 0,831 / 0,769 | 0,45 | 0 | pneus, eixos, colar/haste |
| `ANA_Mat_RosaCalota_Provisorio` | 0,941 / 0,588 / 0,698 | 0,38 | 0 | calotas (superfície 1 das rodas) |
| `ANA_Mat_VermelhoAmbar_Provisorio` | 0,804 / 0,235 / 0,157 | 0,20 | 0 | lente da lâmpada |
| `ANA_Mat_AroAplique_Provisorio` | 0,745 / 0,686 / 0,647 | 0,35 | 0,25 | aro da lâmpada |

Observação visual (Godot, Compatibility): corpo/banco rosa, rodas verde-menta com calota rosa, lâmpada vermelha — preservados. Sem faces faltando, sem geometria preta/sem luz, sem normais invertidas visíveis nos 7 screenshots. Rosa e menta do GLB são **mais pálidos** que as cores do placeholder (rosa 1,0/0,55/0,76; menta 0,62/0,86/0,74). Os sufixos `_Provisorio` indicam materiais ainda provisórios — decisão final é da arte.

## E. Hierarchy

Caminhos reais (relativos à raiz importada; posições locais em m, todas as rotações 0 e escalas 1):

```
Vehicle                              Node3D (0,0,0)
├─ PinkBody, ElongatedSeat, FrontAxle, RearAxle, FrontLamp, SteeringPostLower   MeshInstance3D (origem 0,0,0)
├─ SeatAnchor                        Node3D  (0, 0.287595, 0.105)
├─ HandlebarPivot                    Node3D  (0, 0.33, -0.25)
│  ├─ HandlebarGrip, TriangularHandlebar, SteeringPostUpper   MeshInstance3D (0,0,0)
├─ FrontLeftWheel   Node3D (-0.1425, 0.12, -0.25) └─ Spin  └─ FrontLeftWheelMesh
├─ FrontRightWheel  Node3D ( 0.1425, 0.12, -0.25) └─ Spin2 └─ FrontRightWheelMesh
├─ RearLeftWheel    Node3D (-0.1425, 0.12,  0.25) └─ Spin3 └─ RearLeftWheelMesh
└─ RearRightWheel   Node3D ( 0.1425, 0.12,  0.25) └─ Spin4 └─ RearRightWheelMesh
```

- **Pivôs das 4 rodas:** `Vehicle/FrontLeftWheel`, `FrontRightWheel`, `RearLeftWheel`, `RearRightWheel` — nomes do contrato preservados. Centro do pivô = centro da malha (desvio ≤ 0,0015 m em X por causa da calota 3 mm mais saliente para fora; 0 em Y/Z). Eixo de rolagem = X (eixo mais estreito da malha). Entre-eixos 0,50 m; bitola 0,285 m (dianteira = traseira); centro das rodas y = 0,12.
- **Independência (Teste 04):** em instância em memória, rolar o `Spin` e esterçar o pivô de cada uma das 4 rodas move **apenas** aquela roda; o pivô permanece no eixo; transforms restaurados.
- **Tire/Hub:** cada roda é **uma** `MeshInstance3D` com 2 superfícies (pneu menta + calota rosa), não nós `Tire`/`Hub` separados. Alinhamento pneu/calota é garantido por ser a mesma malha.
- **HandlebarPivot:** `Vehicle/HandlebarPivot`, no topo da coluna (gap 0,0000 m até o topo de `SteeringPostLower`; desvio do eixo da haste 0,0004 m). Guidão triangular, empunhadura e haste superior são filhos; chassi, banco e haste inferior ficam fora. Giro em Y em memória move só o guidão. **Suporta esterçamento visual futuro** (eixo Y local); nada foi implementado.
- **SeatAnchor:** `Vehicle/SeatAnchor` (`Node3D`, não `Marker3D`), local = espaço do veículo = (0, 0,2876, 0,105), rotação 0.

## F. Dimensions

Sistema de coordenadas: espaço da raiz do GLB (origem no chão, entre os eixos; +Y cima; frente −Z; direita +X), vértices de todas as malhas transformados para esse espaço (sem marcadores). Ordem dos eixos: **X × Y × Z**.

| Propriedade | Referência | Medição Godot | Diferença | Avaliação |
|---|---|---|---|---|
| Dimensões do veículo (X×Y×Z) | 0,40 × 0,578 × 0,745 m | 0,4000 × 0,5777 × 0,7452 m (min −0,2/−0,0027/−0,3726; max 0,2/0,575/0,3726) | 0,0000 / −0,0003 / +0,0002 m (0,00 % / −0,05 % / +0,03 %) | PASS — INFORMATIONAL |
| Raio da roda (GLB) | ≈ 0,12 m | efetivo da malha 0,1226 m (altura do pivô 0,12) | +0,0026 m (+2,2 %) | PASS — INFORMATIONAL |
| Ponto mais baixo do pneu | y = 0 ± 0,01 | y = −0,0027 | 2,7 mm abaixo do plano | PASS — INFORMATIONAL |
| Raio físico/visual do placeholder (`RideOnVisual.wheel_radius`) | 0,13 m | 0,13 m (lido da cena real) | GLB nominal −0,010 m (−7,7 %); efetivo −0,0074 m (−5,7 %) | MINOR (ver abaixo) |
| SeatAnchor Y (GLB) | 0,2876 m | 0,287595 m | −0,000005 m | PASS |
| SeatAnchor do placeholder | 0,22 m (Y), 0,10 (Z) | (0, 0,22, 0,10) em `VehicleVisualRoot` | GLB − placeholder = (0, **+0,0676**, +0,005) | MINOR (ver abaixo) |
| Orientação | −Z frente / +Y cima | frente −Z, cima +Y, esquerda −X; base da raiz = identidade | nenhuma rotação corretiva necessária | PASS |

**Comparação com o placeholder (mesmo espaço, origem no chão):** GLB 0,400 × 0,578 × 0,745 vs placeholder 0,562 × 0,675 × 0,820 → razões X/Y/Z = 0,712 / 0,856 / 0,909. O veículo oficial é **menor** que o placeholder em todos os eixos (bitola 0,285 vs 0,46/0,40; entre-eixos 0,50 vs 0,56). Cápsula de colisão atual: r 0,24 (0,48 m de largura) × 0,80 m de comprimento > visual (0,40 × 0,745).

**Raio da roda — implicações:** colisão/física independem do raio visual (cápsula única), então contato com o solo e `VehicleWheel3D` (inexistente) não são afetados. Se `wheel_radius` ficar 0,13 com o GLB, a rolagem visual `v/r` gira ~5,7 % mais devagar que o deslocamento (leve escorregamento visual); usar o raio efetivo 0,1226 (ou 0,12 nominal, a decidir) na 003-B. Pneus 2,7 mm abaixo de y=0: imperceptível.

**SeatAnchor — causa da diferença (0,0676 m):** não é escala nem pivô (raiz = identidade; ambos referem-se à origem no chão entre eixos). Vem das proporções e do significado do ponto: topo do banco GLB 0,343 m vs placeholder 0,31 m (+0,033), e âncora GLB 0,0554 m abaixo do topo do banco vs 0,09 m no placeholder (o placeholder marcava a base da cápsula do jogador; o GLB marca um ponto dentro do estofado, como pede o contrato §6). Hoje `VehicleInteraction._attach_rider` copia o `global_transform` do `SeatAnchor` para o `Player` (origem = base da cápsula) e `VehicleController.seat_anchor` é tipado `Marker3D` (o GLB traz `Node3D`).

## G. Screenshots

Renderizados no Godot (OpenGL 3.3, GL Compatibility, RTX 3050 Laptop, 1280×720), por `tests/validation/capture_vehicle_screenshots.gd` (apenas a câmera do preview se move; veículo intacto). PNGs válidos e não uniformes (checados pelo script).

`validation/ana-game-003-a/screenshots/`: `vehicle_front.png` · `vehicle_rear.png` · `vehicle_left.png` · `vehicle_right.png` · `vehicle_three_quarter.png` · `vehicle_wheel_detail.png` · `vehicle_handlebar_seat.png` — **7 de 7 capturados**.

Inspeção visual: com a câmera em −Z aparecem guidão triangular e lente vermelha (frente); em −X (esquerda) a frente fica à esquerda da imagem; banco alongado atrás. Nota de iluminação: a luz direcional do preview ilumina forte as faces traseira/direita (quase estouradas em `vehicle_rear`), efeito da luz, não do asset. Pequenos filetes claros nos entalhes do pneu (brilho especular), INFORMATIONAL.

Cena de preview: `scenes/validation/ana_vehicle_glb_preview.tscn` (raiz `Node3D`, instância nativa do GLB, piso cinza, `DirectionalLight3D`, `WorldEnvironment` neutro, `Camera3D`, marcadores de eixo X vermelho/Y verde/Z azul no canto). Sem controlador, colisão ou ligação à cena principal; a main scene não foi alterada.

## H. Automated tests

Comando: `godot --headless --path <projeto> --script res://tests/validation/test_vehicle_glb_import.gd` (log: `log_test_vehicle_glb_import.txt`). Resultado: **50 PASS, 0 FAIL, 1 NOT VERIFIED** (exit 0).

| Teste | Resultado | Evidência |
|---|---|---|
| 01 Disponibilidade | PASS | `load` → `PackedScene`, raiz `Node3D` |
| 02 Geometria | PASS | 13 malhas, 25.772 tris, corpo/banco/guidão/4 rodas; sem animação/luz/câmera/colisão/skeleton |
| 03 Materiais | PASS | 5 materiais, todas as superfícies com material, rosa e menta identificados |
| 04 Pivôs das rodas | PASS | 4 pivôs + Spin + malha; independência e restauração |
| 05 Guidão | PASS | `HandlebarPivot` no eixo da haste; hierarquia correta |
| 06 SeatAnchor | PASS | dentro do banco; Y = 0,2876 |
| 07 Dimensões/escala | PASS | 0,4000 × 0,5777 × 0,7452; raiz identidade; finito |
| 08 Orientação | PASS (medido) / NOT VERIFIED (semântico) | marcadores −Z/+Z; o juízo semântico foi feito pelos screenshots (seção G) |
| 09 Preservação | PASS | hash da cópia = hash gravado do original; original acessível e inalterado |
| 10 Isolamento | PASS | `main_scene` inalterada; `main.tscn`/`ride_on_vehicle.tscn` sem referência ao GLB; `git status` só em `assets/vehicles/`, `scenes/validation/`, `tests/validation/`, `validation/`; HEAD = main = base |

Regressão do ANA-GAME-002 (`--fixed-fps 60`) e boot: 

| Execução | Resultado |
|---|---|
| --import (headless editor) | exit 0, sem erros/avisos |
| boot da main.tscn (--quit-after 120) | exit 0, sem erros |
| boot da cena de preview (--quit-after 60) | exit 0, sem erros |
| smoke_test / 	est_camera_follow / 	est_farm_terrain / 	est_sprint / 	est_vehicle / 	est_drift | todos PASS (0 falhas), stderr vazio |

Logs: alidation/ana-game-003-a/log_*.txt; resumo em summary_runs.txt..

## I. Integration recommendations (para ANA-GAME-003-B — nada implementado)

1. **Raiz visual:** instanciar o GLB como filho de `VehicleVisualRoot` (origem no chão, escala 1, **sem rotação extra**); nenhuma correção de 180° é necessária (frente −Z igual ao placeholder).
2. **Adaptador `RideOnVisualGLB extends RideOnVisual`** (contrato §9): não executar `_build()`; localizar as rodas por nome dos pivôs e obter o `Spin` como **primeiro filho `Node3D`** (nomes `Spin/Spin2/Spin3/Spin4`, não `Spin` exato); preencher `_front_wheels` (FL/FR) e `_spin_nodes` (4); `wheel_radius` = 0,1226 (efetivo) ou 0,12 — decisão da arte/Orquestrador.
3. **Guidão:** `HandlebarPivot` pronto para `rotation.y = steer_angle` com a mesma convenção das rodas (+ = esquerda); exige aprovação (contrato §11: guidão hoje é fixo).
4. **SeatAnchor:** o export do controlador é `Marker3D`; manter `VehicleVisualRoot/SeatAnchor` (Marker3D) e copiar a posição (0, 0,2876, 0,105) do `Vehicle/SeatAnchor`. A base do `Player` ficará 0,0676 m acima da atual; definir com a arte se a âncora é pélvis ou pés (pose sentada ainda pendente).
5. **Escala/colisão:** o veículo é menor (0,40 × 0,578 × 0,745); a cápsula (r 0,24 / 0,80 m) fica maior que o visual — reavaliar cápsula, `DismountAnchor` (0,85) e `VehicleCameraTarget` (0,6) na 003-B; `wheel_radius` e posições das rodas mudam.
6. **Testes existentes:** `tests/test_vehicle.gd` (seção do visual) busca `FrontLeftWheel/Spin/Tire`, lê cor via `PrimitiveMesh.material` e limita o tamanho a < 1,0 × 0,7 × 0,8 m — precisam ser adaptados (não há nó `Tire`; materiais são `StandardMaterial3D` em superfícies; nomes `PinkBody`, `ElongatedSeat`, `TriangularHandlebar`, `HandlebarGrip` existem).
7. **Física × visual:** manter o `CharacterBody3D` e a inclinação só no `VehicleVisualRoot`; o GLB não traz colisão (correto).
8. **Contrato (atualização a aprovar):** registrar Tire+Hub como uma malha de 2 superfícies, `Spin` com sufixo numérico, `HandlebarPivot` (novo), `SeatAnchor` como `Node3D`, e substituir as medidas provisórias pelas reais desta seção.
9. **Orçamento:** 25.772 tris (≈ 18,9 mil únicos) cabem na ordem de grandeza sugerida pelo contrato; desempenho Web com o GLB **não medido**.

## J. Discrepâncias e severidade

| # | Discrepância | Severidade |
|---|---|---|
| 1 | Tire/Hub não são nós separados (1 malha, 2 superfícies) | MINOR |
| 2 | `Spin` renomeado `Spin`/`Spin2`/`Spin3`/`Spin4` pelo importador (nomes únicos) | MINOR |
| 3 | `SeatAnchor` é `Node3D`; controlador espera `Marker3D` | MINOR |
| 4 | `HandlebarPivot` existe (contrato previa guidão fixo) | INFORMATIONAL |
| 5 | Veículo menor que o placeholder (razão 0,71/0,86/0,91); cápsula maior que o visual | MINOR |
| 6 | Raio da roda 0,12 (efetivo 0,1226) vs 0,13 do placeholder | MINOR |
| 7 | SeatAnchor +0,0676 m acima do placeholder | MINOR |
| 8 | Pneus 2,7 mm abaixo de y=0 | INFORMATIONAL |
| 9 | Rosa/menta mais pálidos que o placeholder; materiais `_Provisorio` | MINOR (decisão da arte) |

Nenhum item CRITICAL ou MAJOR.

## K. Limitações / não verificado

- Importação feita via `--editor --import` headless; o **editor Godot em GUI não foi aberto** nem foi feito F5 interativo.
- Orientação semântica (frente/esquerda) conferida por mim nos screenshots; sem revisão humana/artística.
- Rolagem/esterçamento testados só como rotações temporárias em memória, não em movimento no jogo.
- Render do GLB no **export Web/WebGL 2 não testado**; desempenho Web com o GLB não medido.
- Aprovação artística final (cores, proporções) pendente; `Contratos de Assets 3D` segue como o contrato `ANA-ASSET-CONTRACT-001`, **não alterado**.

## L. Arquivos criados/alterados

Novos: `assets/vehicles/ana-veiculo-integracao-v01.glb` (+ `.import`), `scenes/validation/ana_vehicle_glb_preview.tscn`, `tests/validation/test_vehicle_glb_import.gd`, `tests/validation/capture_vehicle_screenshots.gd`, `validation/.gdignore`, `validation/ana-game-003-a/{validation_report.md, screenshots/*.png, log_*.txt, summary_runs.txt}`. **Nenhum arquivo existente do projeto foi modificado.** Sem commit, push ou merge.


---

# FIX-01 — Refinamento visual da pré-visualização (ANA-GAME-003-A-FIX-01, 2026-11-01)

**Escopo:** só a apresentação no Godot, em cena isolada. GLB, `main.tscn`, controlador, física, câmera de jogo, assets Blender e renderer global **intactos**; sem commit/push; 003-B não iniciada. Materiais oficiais do GLB **preservados** (nenhum override; variante com overrides de material **não foi necessária**).

## 1. Diagnóstico — o que é ambiente e o que é modelo

Referência: render Cycles do v02 (`previews/ana-veiculo-blockout-v02_*.png`; script `ana_veiculo_render_v02.py`): mundo cinza 150/255 (luz ambiente uniforme ≈ 0,30 linear + reflexo suave), sol-chave 2,2 + sol-fill 0,9 (ângulos 18°/40° → sombras suaves), view transform *Standard*, sem chão visível, materiais Principled (rugosidade 0,34/0,45/0,38; specular padrão) — os **mesmos valores** que o GLB traz no Godot.

| # | Diferença observada na cena original | Causa | Pertence a |
|---|---|---|---|
| 1 | Superexposição e perda de contraste (rosa/menta lavados, traseira estourada; frente escura) | Um único sol (e ambiente branco) vindo de um lado só; a energia de luz direcional do Godot rende ~π× mais que o "strength" do sol do Blender (medido empiricamente; sol 2,2 ≈ energia ~0,2) | **Ambiente** |
| 2 | Aparência chapada, sem reflexo suave | Fundo cor lisa, sem sky → sem radiância/reflexo ambiente; sem luz de preenchimento | **Ambiente** |
| 3 | Sombras duras e escuras | Sombra sem blur/opacidade e quase sem ambiente de preenchimento | **Ambiente** |
| 4 | Linhas brancas nos sulcos dos pneus | Saturação (clip) + brilho especular nas faces chanfradas dos sulcos; com exposição correta viram degraus sutis idênticos aos do Blender. A geometria dos sulcos é a do modelo (chevron com chanfro) | **Ambiente** (geometria OK) |
| 5 | Chão com quina visível, cor diferente do fundo; bordas serrilhadas | Piso 6×6 com albedo ≠ fundo; sem MSAA | **Ambiente** |
| 6 | Normais/suavização | Sem artefatos: `shade_smooth_by_angle(50°)` exportado corretamente; sem faces invertidas | — (sem defeito) |
| 7 | Lâmpada frontal maior e com aro metálico no GLB; no v02 é um pequeno bico vermelho | Diferença entre o v02 e o `integracao-v01` exportado | **Modelo / arte** |
| 8 | Nervuras do banco pouco perceptíveis | Relevo raso (~mm) na geometria; no Cycles o GI/AO o realça. Visível em close/luz rasante (`seat_detail`) | **Modelo** (parcial) |
| 9 | Sem oclusão de contato (sombra suave sob corpo/rodas) | Compatibility não tem SSAO/GI | **Limitação do renderer** |

## 2. Refinamento aplicado (apenas na nova cena)

Nova cena `scenes/validation/ana_vehicle_glb_preview_refined.tscn` (a original `ana_vehicle_glb_preview.tscn` foi mantida para a comparação A):
- Sol-chave 0,131 e fill 0,058 nas **mesmas direções** do Blender v02 (convertidas Z-up → Y-up); chave com sombra `shadow_blur` 3,0 e `shadow_opacity` 0,65; ambos `sky_mode = LIGHT_ONLY`.
- Fundo e iluminação ambiente/reflexos vindos de um `Sky` procedural **cinza uniforme 150/255** (ambient e reflexo `SKY`, energia 0,735), tonemap *Linear* (= *Standard* do Blender). Compatível com Web Compatibility (sem SSAO/SDFGI/glow/volumétricos).
- Piso 60×60 cinza 160 (iluminado ≈ 150: sem quina nem faixa de horizonte marcante) (sem marcadores de eixo na cena refinada).
- Câmera padrão equivalente à do Blender (3/4 do lado direito, fov vertical 26°).
- MSAA 4× local via `scripts/validation/vehicle_preview_setup.gd` (aplica ao viewport que hospeda a cena de preview; `project.godot` intacto).
- Exposição calibrada por amostragem de pixels contra o render do Blender (vista frontal): rosa C 225/158/180 → B 233/160/185 (+3,5 %); menta 174/205/191 → 170/204/189; fundo 150 = 150. Original A: rosa 195/133/154 (escuro) na frente e estourado na traseira.
- Cena criada por script auxiliar de geração (não versionado); parâmetros: chave 0,131 · fill 0,058 · ambiente 0,735 · blur 3,0 · opacidade 0,65 · piso 160.

## 3. Comparação A | B | C (enquadramentos equivalentes, 1400×1075)

`validation/ana-game-003-a/fix01/comparison/` — `compare_three_quarter.png`, `compare_side.png`, `compare_front.png`, `compare_rear.png` (A = Godot original, B = Godot refinado, C = Blender v02 aprovado). Originais individuais em `fix01/A_original/` e `fix01/B_refined/` (inclui `seat_detail` e `vehicle_wheel_detail`). Os 7 screenshots padrão refeitos (1280×720): `validation/ana-game-003-a/screenshots_refined/`. Os screenshots originais continuam em `screenshots/`.

**Resultado:** B aproxima C em rosa pastel, menta, rugosidade acetinada, volume e sombras suaves; os sulcos dos pneus ficam discretos, sem linhas brancas artificiais.

## 4. Diferenças ainda não resolvidas

1. **Lâmpada** maior e com aro no GLB vs bico vermelho no v02 — decisão/correção da arte (Blender).
2. **Nervuras do banco** de relevo raso: perceptíveis em close, fracas à distância. Recomendação ao agente Blender: aprofundar o relevo ou fornecer normal map/AO assado (se aprovado; o contrato hoje evita texturas).
3. **Sem oclusão de contato/GI** (limitação do Compatibility): recomendação — AO assado em cor de vértice ou textura (Blender) ou "blob shadow" no jogo; não aplicado.
4. Pequenas diferenças residuais: faixa fraca de horizonte do piso em ângulos baixos; banda sombreada na calota nas vistas laterais (sombra do aro, ambiente); pink ~3,5 % mais claro que o Blender; reflexos do Cycles mais suaves.
5. **Nenhum defeito de geometria** identificado (normais, faces, sulcos OK).

## 5. Testes FIX-01

`test_vehicle_glb_import.gd` (agora com Teste 11: cenas de preview carregam, instanciam o GLB oficial, materiais sem override, sem corpo físico): **60 PASS, 0 FAIL, 1 NOT VERIFIED** (o mesmo item semântico do T08). Boot headless de `main.tscn` e das duas cenas de preview e boot com janela (OpenGL 3.3) da cena refinada: sem erros. `--import` sem erros. Regressão `smoke_test`, `test_camera_follow`, `test_farm_terrain`, `test_sprint`, `test_vehicle`, `test_drift`: todos PASS. Logs em `fix01/log_*.txt`; resumo em `fix01/summary_runs.txt`. `git status`: nenhum arquivo preexistente modificado.

## 6. Arquivos novos do FIX-01

`scenes/validation/ana_vehicle_glb_preview_refined.tscn`, `scripts/validation/vehicle_preview_setup.gd`, `tests/validation/capture_vehicle_views.gd`, `tests/validation/build_comparison.gd` (+ `.uid`), `validation/ana-game-003-a/{screenshots_refined, fix01}/`. Alterado: `tests/validation/test_vehicle_glb_import.gd` (Teste 11, prefixo permitido `scripts/validation/`).

## 7. Recomendações

- Usar na 003-B, se houver cena de apresentação/jogo, a mesma temperatura de luz: fill/ambiente por céu cinza + chave suave; no jogo real a iluminação é do mundo (não definida aqui).
- Pedir ao agente Blender: (a) confirmar a lâmpada; (b) relevo do banco mais profundo ou normal map; (c) AO assado opcional.
- Manter o GLB como está (importação aprovada); nenhuma correção de geometria necessária.
