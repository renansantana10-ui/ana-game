# ANA-GAME-003-C — Inventário de artefatos de validação (003-A e 003-B)

Base: HEAD `a98d130` na `feat/ana-game-003`. Escopo: 117 arquivos rastreados em `assets/`, `scenes/validation/`, `scripts/validation/`, `tests/validation/` e `validation/` (≈ 11 MB). **Nada foi apagado, movido ou desversionado**; é uma classificação para a futura distribuição.

Verificações feitas: nenhuma fotografia/referência da criança no projeto (só 1 GLB e PNGs gerados pelo Godot; `producao-assets-3d/referencias/` está fora do repositório e do pacote Web); nenhum segredo/credencial (busca por password/secret/token/api key: 0 resultados); nenhum `.blend`, nota do cofre ou `.git` no pacote Web.

## Pacote Web real (`export/web`, ~40,3 MB) e conteúdo do `index.pck` (709 KB)

`index.html`, `index.js`, `index.wasm`, `index.pck`, `index.png`, `index.icon.png`, `index.apple-touch-icon.png`, 2 worklets de áudio — **sem** `.import`, logs, relatórios, screenshots ou documentos. O `.pck` contém (via `export_filter = all_resources`): cenas e scripts do jogo (compilados `.gdc`), o GLB oficial importado, os shaders **e também** `tests/*.gdc`, `tests/validation/*`, `scripts/validation/*` e as duas cenas de preview (`scenes/validation/*`). Nenhum PNG de `validation/` (a pasta tem `.gdignore`), nenhuma foto, nenhum `.md`. Itens extras no `.pck` são código de teste sem dados privados; recomendação futura: `exclude_filter="tests/*, scenes/validation/*, scripts/validation/*, export/*"` no preset (**não alterado nesta missão**). Em `export/web` há 3 arquivos `*.import` antigos de ícones (gerados pelo editor porque `export/` fica dentro do projeto); não são servidos como parte do jogo e podem ser removidos do diretório de publicação.

## Classificação

| Arquivo(s) | Categoria | Observação |
|---|---|---|
| `assets/vehicles/ana-veiculo-integracao-v01.glb` + `.import` | **KEEP — REQUIRED SOURCE** | GLB oficial (SHA-256 `E1725EF7…846E`) e sua importação |
| `scripts/official_vehicle_visual.gd`, `scenes/ride_on_vehicle.tscn` | **KEEP — REQUIRED SOURCE** | integração (003-B) |
| `scripts/validation/vehicle_preview_setup.gd`, `scenes/validation/ana_vehicle_glb_preview*.tscn` | KEEP — TECHNICAL EVIDENCE | só para a pré-visualização; excluir do build público |
| `tests/validation/test_vehicle_glb_import.gd`, `test_vehicle_official_visual.gd` | **KEEP — REQUIRED SOURCE** (testes de regressão) | adaptados, não removidos |
| `tests/validation/capture_*.gd`, `build_comparison.gd`, `perf_probe.gd` | KEEP — TECHNICAL EVIDENCE | ferramentas de captura/medição (exigem janela) |
| `validation/ana-game-003-a/validation_report.md`, `validation/ana-game-003-b/integration_report.md`, `validation/ana-game-003-c/*.md` | KEEP — TECHNICAL EVIDENCE | contêm caminhos locais (`D:\ana game\…`) → REVIEW antes de qualquer publicação externa |
| `validation/ana-game-003-a/screenshots/` (7 PNG, 0,5 MB) | EXCLUDE FROM FUTURE RELEASE | capturas da primeira iluminação; superadas por `screenshots_refined/` e pela comparação |
| `validation/ana-game-003-a/screenshots_refined/` (7 PNG) | KEEP — TECHNICAL EVIDENCE | capturas aprovadas |
| `validation/ana-game-003-a/fix01/comparison/` (4 PNG, 1,7 MB) | KEEP — TECHNICAL EVIDENCE | A\|B\|C aprovado |
| `validation/ana-game-003-a/fix01/A_original`, `B_refined` (12 PNG, 2,4 MB) | EXCLUDE FROM FUTURE RELEASE | intermediários das comparações (reproduzíveis com `capture_vehicle_views.gd`) |
| `validation/ana-game-003-a/log_*.txt`, `summary_runs.txt`, `fix01/log_*.txt`, `fix01/summary_runs.txt` | EXCLUDE FROM FUTURE RELEASE | logs de execução (resultados já resumidos nos relatórios); contêm caminhos locais |
| `validation/ana-game-003-b/screenshots/` (16 PNG, ≈ 3 MB) | REVIEW BEFORE PUBLICATION | mostram a HUD e o jogo (sem dados privados); manter 3–4 representativas |
| `validation/ana-game-003-b/log_baseline_*.txt`, `log_final_*.txt`, `summary_*.txt`, `perf_*.txt` | EXCLUDE FROM FUTURE RELEASE | logs temporários/medições; evidência já consolidada no relatório |
| `validation/ana-game-003-c/log_*.txt`, `web/*.json`, `web/*.png` | EXCLUDE FROM FUTURE RELEASE (evidência local) | logs e capturas da validação Web desta missão; ficam não rastreados até decisão |
| `validation/.gdignore` | **KEEP — REQUIRED SOURCE** | impede o Godot de importar os PNGs e de empacotá-los |

## `.gitignore` / exportação — recomendações (não aplicadas)

- `/export/` e `/build/` já estão ignorados; `export_credentials.cfg` também; `.godot/` também. Nada gerado do Web build está rastreado.
- Os arquivos de `validation/` **já estão rastreados**; ignorar não os remove. Para evitar novos logs/capturas sem querer, considerar `validation/**/log_*.txt` e `validation/**/*.err` (padrões estreitos; não escondem testes nem código).
- Preset Web: acrescentar `exclude_filter` (acima) para tirar testes/preview do `.pck` público e diminuir o pacote; hoje irrelevante (≈ 100 KB de código).
- Manter o diretório servido separado do projeto: copiar apenas `index.*` para uma pasta de publicação (ex.: `release/web`) quando houver autorização.

## Publicação (PR da ANA-GAME-003)
Incluídos no commit da 003-C: `web_validation_report.md`, este inventário, `godot_version.txt`, `summary_godot_tests.txt`, `web_build_hashes.txt`, `web/cache_results_8060.json`, `web/cold_load.json`, `web/chrome_gpu_info.json` (sem a linha de comando do Chrome, que continha o caminho local do perfil), `web/perf/*.json` e 7 capturas representativas do Chrome. **Não incluídos** (ficam só no disco local): logs `log_*.txt`, as demais ~45 capturas exploratórias (`g*`, `h*`, `k*`, `m*`, `w_e*`), `chrome_gpu_summary.txt` (vazio) e `w_e13_stopped` (PNG sem extensão). Nenhum build Web, cache, perfil do Chrome, segredo ou foto. Nenhum arquivo versionado de commits anteriores foi alterado ou removido.