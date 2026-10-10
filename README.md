# Slime: Rise of Tempest 🟢

RPG 2D de visão superior inspirado em *Tensei shitara Slime Datta Ken*.
Demonstração jogável: Prólogo (caverna + Veldora) → Capítulo 1 (floresta, goblins, lobos, Rei Lobo Borboleta, fundação de Tempest) → Capítulo 2 (Vila Jura, artesãos, Rei Ogro Gido).

## Como jogar (Windows)

O executável está em `export/SlimeRiseOfTempest.exe` (requer o `.pck` ao lado).
Não precisa instalar nada.

## Como abrir no Godot

1. Instale/abra o **Godot 4.7.x** (ou use `tools/godot/`, ignorado pelo git).
2. Importe a pasta como projeto e rode com F5 (cena inicial: menu).

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover | WASD / setas | D-pad |
| Correr | Shift | — |
| Interagir / confirmar | E, Z, Enter | A |
| Cancelar | X, Esc | B |
| Grande Sábio (menu) | Q | LB |

## Sistemas implementados

- **Predador**: absorva inimigos com PV baixo → habilidades, passivas, materiais (chefes só dão materiais; algumas recompensas exigem análise completa).
- **Grande Sábio**: bestiário com análise de fraquezas, biblioteca de habilidades, **síntese** (4 combinações, requer laboratório) e missões.
- **Tempest**: recursos (comida/material/população), serviços (ferreiro, cozinha, laboratório) que alteram visualmente a cidade.
- **Diplomacia**: 3 eventos resolvidos por combate, negociação ou demonstração de poder.
- Combate por turnos com barra de ordem, PV/PM, 7 elementos, status, aliados (até 2), fuga.
- Autosave em pontos-chave + save manual em `user://save1.json`.

## Estrutura

```
data/        JSON de habilidades, inimigos, itens, sínteses, missões, encontros e diálogos
scripts/     autoloads (Data, GameState, SaveSystem, Flow), mundo, batalha, UI
scenes/      main_menu, world, battle, ending
assets/      tiles Kenney CC0 + sprites gerados (scripts/dev/generate_sprites.ps1)
tests/       smoke.tscn — executa: godot --headless --path . tests/smoke.tscn
```

Regenerar sprites: `powershell -ExecutionPolicy Bypass -File scripts\dev\generate_sprites.ps1`

## Créditos

- Tiles: **Kenney — Roguelike/RPG pack** (CC0, domínio público) — `kenney.nl`
- Sprites de personagens gerados por script neste repositório (arte original placeholder)
- Feito com **Godot 4** + GDScript
