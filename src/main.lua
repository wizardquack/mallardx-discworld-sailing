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
-- Each module registers its host-API calls as side effects of being
-- required; the returned table is unused here.

require("highlights")
require("smuggling")
