# Ana Game — Regras Permanentes do Projeto

## Stack
- Engine: Godot 4.7.2 (stable). Linguagem: GDScript.
- Renderer: GL Compatibility (mantido para export Web).
- Executável: `D:\ana game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`
- Validação headless: `<godot> --headless --path "<projeto>" --quit`

## Plataforma e controles
- Plataforma exclusiva: navegador de PC (export Web), fullscreen horizontal.
- Controles: WASD + mouse. Sem mobile/gamepad/touch.

## Documentação (Obsidian)
- Cofre: `D:\ana game\Cofre de Contexto\ana game` (fonte de documentação).
- **Antes de qualquer nova missão, ler `Estado Atual e Handoff.md` no cofre.**
- Ao fim de cada missão/etapa importante, atualizar o handoff: estado efetivo, sem duplicação, sem transcrição.
- Nunca registrar como concluído o que não foi implementado e testado.
- Não reestruturar nem sobrescrever outras notas do cofre sem autorização.

## Desenvolvimento
- Arquitetura modular; desenvolvimento incremental (uma missão por vez).
- Preservar arquivos existentes; não apagar/mover/sobrescrever sem autorização.
- Não alterar decisões artísticas aprovadas sem autorização explícita.
- Não implementar missões sem autorização do usuário.
- Git: repositório local; não publicar remotamente nem commitar sem pedido.
- Nunca versionar credenciais (`export_credentials.cfg`) nem `.godot/`.

## Comunicação
- Responder SEMPRE em português brasileiro, curto, objetivo e organizado.
- Sem logs completos; apenas o resultado relevante. Sem repetir informação.
- Nomes de arquivos, comandos, APIs e identificadores permanecem no idioma original.
- Prompts técnicos podem ser em inglês; resumos ao usuário sempre em português.
- Resposta final de missão (até ~150 palavras), neste formato:

```
MISSÃO: [nome]
STATUS: [Concluída / Parcial / Bloqueada]
IMPLEMENTADO: resumo breve
TESTES: resultado objetivo
PENDÊNCIAS: somente o pendente
PRÓXIMO PASSO: uma ação recomendada
HANDOFF: [Atualizado / Não atualizado]
```
