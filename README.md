# Discworld Sailing

A combined Discworld sailing-mission plugin with two pieces:

1. **Highlights** — ~40 regex highlights ported from
   `~/code/3p/tt_dw/scripts/missions/sailing/colours.tin` (sea serpents,
   kraken, fires, ice, helming, rope/hull condition strings).
2. **Smuggling stat panel** — port of Kiki's MUSHclient
   `SmugglersToolbox.xml`. Tracks mission cooldown, per-leg timers + XP,
   monster fight time + XP, and the running voyage total in a grid panel.

`[worlds] match = ["discworld.starturtle.net:*"]` — auto-enabled when
connected to Discworld, no-op elsewhere.

The keypad-remapping (`!sailkeys`) was intentionally not ported.

## Highlights

- `mud.style(pattern, { fg = "color" })` mirrors `#HIGH` rules in the
  source — whole-line recolors.
- `mud.style(pattern, { capture = N, fg = "color" })` mirrors `#sub`
  rules — narrows to the matched substring's spans.

Each block in `src/main.lua`'s HIGHLIGHTS section mirrors a
`#NOP === Section ===` comment block in the upstream tintin file.

| Tintin token  | Rust regex                                |
|---------------|-------------------------------------------|
| `%*`          | `.*`                                      |
| `{a\|b\|c}`   | `(?:a\|b\|c)`                             |
| `%1`, `%2`, … | `(.+?)` capture groups (left-to-right)    |
| `%.`          | `.`                                       |
| `^…$`         | stays `^…$`                               |

## Stat panel

A 1-second timer drives every cell:

- **Cooldown** — counts down 2h after each mission starts; persisted across
  restarts via `storage`.
- **Stage** — current weather stage name while sailing.
- **Leg 1..4 / Monster** — `<name> mm:ss (xp)` per stage; XP fills in when
  the leg-finished message fires.
- **Voyage** — total elapsed time + summed XP across all legs.

### Debug aliases

| alias            | effect                                              |
|------------------|-----------------------------------------------------|
| `!startMission`  | Force-start the mission state machine.              |
| `!endMission`    | Force-end (use if a stage trigger missed and the panel is stuck). |
| `!nextStage <X>` | Force a transition to weather stage `X`.            |
| `!sailData`      | Dump the current trip stages + XP table via `mud.note`. |

## Dev rebuild

```sh
bash scripts/reinstall.sh
```

## Changelog

### v0.4.0
Combined `discworld-sailing-highlights` + `discworld-smugglers-toolbox`
into a single plugin. Panel key + title renamed `smugglers` → `sailing`
for consistency with the plugin id.

### v0.3.0 (Plan #9f, sailing-highlights)
Ported `mud.highlight` / `mud.sub` calls to the canonical `mud.style` surface.

### v0.2.0 (Plan #9e, sailing-highlights)
Span-aware sub: capture-targeted recolors narrowed to the matched substring's spans.

### v0.1.0 (Plan #9d, sailing-highlights)
Initial port of the sailing highlight rules.

### Smuggler's Toolbox v0.1.0
Initial port of the SmugglersToolbox.xml stat panel.
