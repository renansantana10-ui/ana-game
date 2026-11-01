# ANA-GAME-003-C — Web Validation and Release Readiness

**Data:** 2026-11-01 · **Branch:** `feat/ana-game-003` · **HEAD:** `a98d130e22e8e9abf5622c4e4aaab9b6608508f1` (003-B), pai `76fa645` (003-A) · **Sem commit/push/merge/PR; nada publicado.**
**Classificação: `READY WITH LIMITATIONS` — pronto para a revisão do Orquestrador, NÃO pronto para publicação**: a jogabilidade humana no Chrome (teclado/mouse reais, captura de mouse, câmera) está `NOT VERIFIED` até o teste manual do usuário.

## A. Baseline
Godot `4.7.2.stable.official.ed1daf0bf` (Compatibility, export Web single-thread) · Chrome `156.0.8078.74` (instância de teste com perfil descartável + DevTools Protocol; o perfil do usuário não foi tocado) · Windows 11 10.0.26300 · CPU i5-11400H, 15,8 GB RAM, GPUs NVIDIA RTX 3050 Laptop (usada pelo Chrome) + Intel UHD · monitor 1920×1080 (144 Hz) · árvore de trabalho limpa no início (só arquivos novos de `validation/ana-game-003-c/` ao final).

## B. Godot (nativo/headless) — Nível 1 e 2
| Verificação | Resultado |
|---|---|
| `--version` | `4.7.2.stable.official.ed1daf0bf` |
| `--editor --import --quit` | exit 0, sem erros/avisos |
| Boot `main.tscn` (`--quit-after 120`, headless e com janela OpenGL 3.3) | exit 0, sem erros |
| `test_vehicle_official_visual` (003-B) | PASS (0 falhas) |
| `test_vehicle_glb_import` (003-A) | 58 PASS, 0 FAIL, 1 NOT VERIFIED (semântica visual da orientação, já documentada) |
| `smoke_test`, `test_camera_follow`, `test_farm_terrain`, `test_sprint`, `test_vehicle`, `test_drift` | todos PASS, stderr vazio |
| F5 nativo humano | **12/12 PASS pelo usuário** (registrado na 003-B); não repetido aqui |

Testes obsoletos: nenhum removido. Logs em `validation/ana-game-003-c/log_*.txt`.

## C. Export Web
`godot --headless --path . --export-release "Web" export/web/index.html` (preset `Web` inalterado: Compatibility, `thread_support=false`, PWA desligado, `all_resources`) → exit 0 (4 s). Saída em `export/web/` (ignorada pelo Git):

| Arquivo | Bytes | SHA-256 (16) |
|---|---|---|
| `index.wasm` | 39.514.754 | `FC74679E3B97F768` |
| `index.pck` | 708.904 | `B5F148F903AC3C58` |
| `index.js` | 279.815 | `33C94CB3175F3333` |
| `index.html` | 5.438 | `624749A50219BBAB` |
| `index.png`, `index.icon.png`, `index.apple-touch-icon.png`, 2 worklets | 21.443 / 5.765 / 11.939 / 7.298 / 2.973 | em `web_build_hashes.txt` |

Total ≈ 40,3 MB. O `.pck` inclui o GLB oficial importado, as cenas e scripts do jogo (`.gdc`), shaders; **sem** fotos, `.md`, PNG de `validation/` (`.gdignore`), Blender ou cofre. Extras sem dados privados: testes e cenas de preview (ver `artifact_inventory.md`).

## D. Servidor local
| Item | Valor |
|---|---|
| **URL principal verificada** | **http://127.0.0.1:8060/** (`index.html` 200) |
| PID / processo | **39880**, `python -m http.server 8060 --bind 127.0.0.1` (o servidor do projeto desde a 002-C; serve `export\web`, já com o build novo — hash do `.pck` servido = local) |
| Reserva independente | **http://127.0.0.1:8061/** — PID **26880**, `pythonw "D:\ana game\tools\serve_web.py" "…\export\web" 8061` (iniciado via WMI, sem terminal; MIME corretos, `Cache-Control: no-cache`; log `D:\ana game\tools\serve_web.log`) |
| MIME verificados | html `text/html`, js `text/javascript`, wasm `application/wasm`, pck `application/octet-stream`, png `image/png` |
| Disponibilidade | verificada de novo ao final (portas 8060 e 8061 em escuta, respostas 200) |
| Ressalva | o processo 8060 é filho de uma aba do Terminal do app; se essa aba for fechada ele pode cair — nesse caso use a 8061. Não matei o 8060 (a ação foi negada e não era necessária). |
| Parar | `Stop-Process -Id 39880` / `Stop-Process -Id 26880` (PowerShell). Loopback apenas; sem firewall, serviço ou tarefa agendada. |

## E. Chrome real — Nível 3
- **WebGL 2** `WebGL 2.0 (OpenGL ES 3.0 Chromium)`; renderer `ANGLE (NVIDIA GeForce RTX 3050 Laptop GPU, Direct3D11)`; aceleração por hardware ativa (`gpu_compositing`, `rasterization`, `webgl` = enabled; **sem SwiftShader/software**); contexto seguro (localhost); não isolado entre origens (não necessário no export single-thread). `web/chrome_gpu_info.json`.
- Carregamento: Godot inicia (banner 4.7.2, Compatibility, Emscripten 4.0.20 single-thread) em ≈ 1,3–2,3 s locais; fazenda, HUD e **veículo oficial rosa/menta** renderizam (`web/cold_load_start.png`, `w_*.png`).
- Console: apenas 3 logs do motor; **0 exceções, 0 erros, 0 avisos WebGL** (os 4 avisos de "framebuffer zero size" do painel embutido na 003-B não ocorreram no Chrome). Rede: todos os recursos 200, MIME corretos, 0 falhas.
- Materiais: pneus menta, corpo/banco rosa, calotas rosa, lâmpada vermelha — sem texturas faltando/superfícies pretas; sob o céu azul provisório o rosa tende a lilás (já registrado; decisão de arte).

## F. Cache
| Etapa | Resultado |
|---|---|
| 1ª visita (cache habilitado, perfil novo) | `index.html/js/wasm/pck` 200; pronto em 1,9 s |
| Reload normal (×2) | html/js revalidados (≈ 300 B), `index.pck` do cache de disco (0 B), `index.wasm` baixado de novo (39,5 MB, 110–130 ms local); build correto nas capturas |
| Hard reload (ignora cache) | tudo baixado; mesmo build |
| Service worker | **0 registros** (PWA desligado); Cache Storage vazio |
| Conteúdo antigo | **nenhum** visto: o veículo oficial aparece em todas as cargas |
Recuperação se aparecer build velho: Ctrl+F5; a reserva 8061 envia `no-cache`. `web/cache_results_8060.json`.

## G. Desempenho (Chrome 156, viewport 1600×900, display 144 Hz, GPU RTX 3050, build release)
Medido por `requestAnimationFrame` (30 s/cenário, aquecimento antes) e por contador injetado de chamadas `drawArrays/drawElements` do WebGL (inclui passes de sombra). Perfil `Performance` do Godot não é legível em export release; draw calls vêm do contador WebGL (ambiente = navegador). Para o nativo ver 003-B (131–146 draw calls).

| Cenário | FPS médio (reps) | Frame p99 | Frame máx. | Quadros > 25 ms | Draw calls (média / máx.) | JS heap / memória wasm |
|---|---|---|---|---|---|---|
| A — parado | 144,0 / 143,8 / 144,0 | 7,1 ms | 7,2 / 20,8 / 13,9 ms | 0 | 177 / 177 | 11 MB / 107 MB |
| B — a pé | 144,0 / 144,0 / 143,6 | 7,1 ms | 14,2 / 7,7 / 20,9 ms | 0 | 158–169 / 177 | 13 MB / 107 MB |
| C — dirigindo | 143,9 / 144,0 (n=2) | 7,1 ms | 14,1 / 7,7 ms | 0 | 145 / 175 | 12 MB / 107 MB |
| D — colina + derrapagem (terreno) | 144,0 / 144,0 (n=2) | 7,1 ms | 14,0 / 13,9 ms | 0 | 154 / 175 | 12 MB / 107 MB |

Leitura: o jogo roda **travado na taxa de atualização (144 Hz)**, sem engasgos sustentados; picos isolados ≤ 21 ms. Limitações: o limite do monitor oculta a folga real de FPS; uma só GPU/monitor; repetições C e D têm n=2 (a sessão de teste do Chrome foi encerrada após o cenário B na repetição 2 — Chrome de teste fechou; refeito sem causa identificada); sem teste a 1920×1080 em tela cheia nem em hardware fraco; carga inicial ≈ 2 s local (rede real não medida). Nenhum otimização/alteração de ativos foi feita.

## H. Matriz de regressão (Chrome real, entrada via DevTools Protocol — não é teste humano)
| Área | Teste | Resultado | Evidência |
|---|---|---|---|
| Player | WASD (diagonal), pular | PASS (automatizado) / **humano NOT VERIFIED** | `w_e15_jump_on_foot.png` (sombra separada do chão) |
| Camera | seguir o personagem | PASS | capturas sequenciais |
| Camera | órbita pelo mouse, captura/liberação (Esc/clique) | **NOT VERIFIED** — o Chrome recusa `requestPointerLock` sob automação (`WrongDocumentError`, igual ao painel embutido); validado por humano na 001 | pendente do usuário |
| Vehicle | detectar, E monta/desmonta, 1 personagem, sentada | PASS | `k04/k05`, `w_e03_mounted`, `w_e14_dismounted` |
| Wheels | giro frente/ré, esterço das dianteiras | PASS (visual + testes nativos) | `m05_steer_left`, `w_e04…` |
| Handlebar | acompanha a direção | PASS | `m05`, `w_e04` |
| Driving | acelerar, frear, ré, curvas | PASS | `m01…m07`, `w_e11/e12` |
| Terrain | colina (sobe e desce) e rampa pequena (no ar, pouso) | PASS | `w_hill_*`, `w_e05/e06/e07` |
| Drift | Espaço + A/D e recuperação, sem pulo | PASS (visual + `test_drift`) | `w_e08/e09/e10` |
| Dismount + andar + pular | | PASS | `w_e14…e16` |
| Reload consistente | | PASS | `cache_*.png` |
| Web | Chrome/WebGL2/materiais | PASS | seções E/F |
| Tela cheia | não há controle de tela cheia no jogo | NOT VERIFIED / não implementado | — |
| Jogabilidade **humana** no Chrome (teclado/mouse reais) | | **NOT VERIFIED** | aguarda teste manual do usuário |

**Anomalia registrada (não reproduzida):** na primeira sessão CDP, com a janela do Chrome parcialmente oculta (renderização limitada pelo Chrome), o veículo apareceu montado e andando sozinho depois de comandos de teclado enviados em rajadas (tecla W aparentemente "presa"; o E não foi enviado). Após desativar a limitação por janela oculta na instância de teste, nenhuma das ≈ 12 sessões seguintes repetiu o caso. Causa não esclarecida; sugere-se que o usuário observe, no Chrome real, se ao trocar de aba/janela com W pressionado a tecla "gruda".

## I. Inventário de artefatos
Ver `artifact_inventory.md` (classificação KEEP/EXCLUDE/REVIEW de 117 arquivos rastreados; nada removido).

## J. Avaliação de release
**READY WITH LIMITATIONS.** Funciona no Chrome real com WebGL2 por hardware, sem erros, sem conteúdo velho, sem fotos/segredos no pacote, desempenho estável. Pendentes antes de qualquer publicação: (1) teste humano no Chrome (teclado, mouse/captura, Alt+Tab, tela cheia); (2) decisão sobre excluir testes/preview do `.pck` público (`exclude_filter`) e sobre `validation/` no repositório; (3) revisão artística (lilás sob o céu atual; personagem definitiva — 003-C de personagem não iniciada); (4) medição em hardware/rede mais fracos. Nenhuma correção de jogo foi necessária; nenhum defeito bloqueante encontrado.

## K. Atualização pós-teste humano (aprovação do Orquestrador)
O usuário confirmou manualmente no Google Chrome os itens que estavam `NOT VERIFIED` acima: captura, liberação e recaptura do mouse; WASD e câmera com dispositivos reais; Alt+Tab sem travamentos; **nenhuma tecla W presa** após trocar de janela (a anomalia da sessão automatizada não ocorre com uso humano); F11 (tela cheia) funcionando. Desempenho reportado ≈ 144 FPS. Nenhuma regressão crítica conhecida. A ANA-GAME-003 (A, B e C) foi **aprovada** e o push/PR foi autorizado; este relatório permanece como registro da validação automatizada anterior ao teste humano.