# Discworld Sailing

A Discworld sailing-mission plugin with two pieces:

1. **Highlights** — ~40 regex highlights for sea serpents, kraken,
   fires, ice, helming, rope/hull condition strings, and dragon
   wrangling.
2. **Smuggling stat panel** — Tracks mission cooldown, per-leg
   timers + XP, monster fight time + XP, and the running voyage total
   in a panel.

## Stat panel

A 1-second timer drives every cell:

- **Cooldown** — counts down 2h after each mission starts; persisted across
  restarts via `storage`.
- **Stage** — current weather stage name while sailing.
- **Leg 1..4 / Monster** — `<name> mm:ss (xp)` per stage; XP fills in when
  the leg-finished message fires.
- **Voyage** — total elapsed time + summed XP across all legs.

### Voyage keymap

The plugin ships a built-in **sailing-numpad** keymap layer (8-direction numpad
steering: numpad8/2/4/6 → fore/aft/port/starboard, corners for diagonals).
It appears in Settings → Keymaps and can be edited freely — rebind the keys or
change the commands to taste; your edits persist.

The layer is activated at voyage start and deactivated at voyage end
automatically. This is controlled by the **Use sailing-numpad keymap during
voyages** setting (on by default); turn it off to leave your keymap untouched
during voyages.

### Debug aliases

| alias            | effect                                              |
|------------------|-----------------------------------------------------|
| `!startMission`  | Force-start the mission state machine.              |
| `!endMission`    | Force-end (use if a stage trigger missed and the panel is stuck). |
| `!nextStage <X>` | Force a transition to weather stage `X`.            |
| `!sailData`      | Dump the current trip stages + XP table via `mud.note`. |

## Credit

Thank you to Kiki for the wonderful Smuggler's toolbox plugin, which helped immensely in sorting through the regex this plugin's panel.
