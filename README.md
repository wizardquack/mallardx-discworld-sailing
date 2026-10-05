# Discworld Sailing

A Discworld sailing-mission plugin with three pieces:

1. **Highlights** — ~90 regex highlights for sea serpents, kraken,
   fires, ice, helming, rope/hull condition strings, dragon
   wrangling, and sun-sighting position reports.
2. **Smuggling stat panel** — Tracks mission cooldown, per-leg
   timers + XP, monster fight time + XP, and the running voyage total
   in a panel.
3. **TTS mode** — an optional set of spoken callouts for notable sailing
   events (off by default; one setting to toggle).

## TTS mode

Turn on **Speak notable sailing events (TTS)** in the plugin's settings to
have Mallard read out a curated set of callouts through its text-to-speech.
The toggle takes effect immediately (no reload). Voice, rate and volume are
configured globally under **Settings → Speech**.

What it speaks, all on a dedicated `sailing` speech channel so callouts queue
in order:

- **Milestones** — "Voyage begun", each weather stage as it arrives
  (Fog / Hail / Gale / Storm / Calm seas), "Leg _n_ complete",
  monster defeated, and "Voyage complete" / "Voyage failed".
- **Urgent cues** — a monster spawn ("Kraken!" / "Serpent!") and a serpent
  strike ("Run!") *interrupt* whatever is queued and speak immediately.
- **Line cues** — "Ship under way", fire started, and boiler run dry.
  Each is debounced so a repeating line can't say itself twice, and they
  stay silent outside a live voyage.

The milestone callouts are driven by the same mission state machine that
feeds the stat panel, so the spoken set stays in lock-step with the panel's
tracking rather than matching lines independently.

## Stat panel

A 1-second timer drives every cell:

- **Cooldown** — counts down 2h after each mission starts; persisted across
  restarts via `storage`.
- **Stage** — current weather stage name while sailing.
- **Leg 1..4 / Monster** — `<name> mm:ss (xp)` per stage; XP fills in when
  the leg-finished message fires.
- **Voyage** — total elapsed time + summed XP across all legs.

The cooldown and the last-voyage rows are stored per character, keyed by
`char.info.name` — the in-game cooldown is per-character, so a world with
several of your characters tracks each one separately. The panel re-reads
the current character's data on login and on `su` (but not mid-voyage).
Before the character name is known, a `_default` bucket is used.

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
