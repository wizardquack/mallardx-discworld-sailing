-- Discworld Sailing — combined sailing-mission plugin.
--
-- Two responsibilities, both gated to Discworld via [worlds] match:
--
--   src/highlights.lua  ~83 mud.style rules ported from tt_dw's
--                       missions/sailing/colours.tin (sea serpents,
--                       kraken, fires, ice, helming, rope/hull
--                       condition). Declarative, no state.
--
--   src/smuggling.lua   smuggling-mission stat panel ported from
--                       Kiki's MUSHclient SmugglersToolbox.xml.
--                       Cooldown, per-leg timers + XP, monster fight,
--                       voyage total — driven by a 1s timer and a
--                       wad of triggers.
--
--   src/search.lua      linkifies each searchable item in a "you think
--                       you can spot …" hint into a clickable
--                       `search <keyword>` command.
--
--   src/tts.lua         optional spoken callouts for notable sailing
--                       events, gated behind the single `tts_mode`
--                       setting (off by default). Registers its own
--                       hazard triggers and exposes milestone hooks that
--                       smuggling.lua drives from its state machine.
--
-- Each module registers its host-API calls as side effects of being
-- required; the returned table is unused here (smuggling.lua pulls in
-- tts.lua itself for the milestone hooks — requiring it here too is
-- idempotent and keeps the module roster explicit).

require("highlights")
require("tts")
require("smuggling")
require("search")
