-- Sailing TTS mode — a curated set of spoken callouts for notable
-- sailing events, gated behind the single `tts_mode` setting.
--
-- Design:
--   * One user setting (`tts_mode`, off by default). The cached `enabled`
--     flag is refreshed via `settings.on("change")` — the same idiom the
--     combat plugin uses — so a toggle in the UI takes effect immediately
--     without a plugin reload and without a `settings.get` round-trip on
--     any per-line path.
--   * Milestones (voyage start/end, weather stages, leg completion,
--     monster spawn/defeat) are spoken by `smuggling.lua` calling the
--     hooks below at its authoritative state-machine transitions — so the
--     spoken set never drifts from the panel's tracking regexes.
--   * Line cues (ship under way, fire, boiler dry, serpent strikes) have
--     no state-machine home, so this module registers their triggers
--     itself. They only speak while a voyage is live (`sailing`) and are
--     debounced per-cue so a recurring line (fire intensifying, repeated
--     strikes) can't machine-gun.
--
--   * All speech goes to a dedicated "sailing" channel so it queues in
--     order and can be flushed wholesale when the mode is switched off.
--     Only genuinely time-critical cues (monster spawn, serpent "Run!"
--     strike) pass `interrupt` to purge the lane and speak now.
--
-- Returns a table of hooks for `smuggling.lua`.

local M = {}

local CHANNEL = "sailing"

-- Cached enable flag + live-voyage flag. `enabled` gates all speech;
-- `sailing` additionally gates the independent hazard triggers so they
-- stay silent between voyages (a fire in a shop shouldn't talk).
local enabled = settings.get("tts_mode") and true or false
local sailing = false

settings.on("change", function(key)
  if key == "tts_mode" then
    enabled = settings.get("tts_mode") and true or false
    -- Flush anything queued/mid-utterance so turning the mode off is silent
    -- immediately rather than after the current backlog drains.
    if not enabled then mud.stop_speech(CHANNEL) end
  end
end)

-- Milestone speak: never debounced (these fire only at genuine state
-- transitions). `urgent` purges the lane and speaks now.
local function say(text, urgent)
  if not enabled then return end
  mud.speak(text, { channel = CHANNEL, interrupt = urgent or false })
end

-- Line-cue speak: gated on an active voyage and debounced per cue key so
-- a line that repeats (fire intensifying, strike after strike) speaks at
-- most once per `window` seconds.
local last = {}
local function say_hazard(key, text, window, urgent)
  if not enabled or not sailing then return end
  local now = os.time()
  if last[key] and (now - last[key]) < (window or 8) then return end
  last[key] = now
  mud.speak(text, { channel = CHANNEL, interrupt = urgent or false })
end

-- ---------------------------------------------------------------------
-- Milestone hooks, called from smuggling.lua's lifecycle.
-- ---------------------------------------------------------------------

-- Voyage boundaries also own the `sailing` flag that hazard triggers read.
function M.set_sailing(v) sailing = v end

function M.voyage_begun()    say("Voyage begun")   end
function M.voyage_complete() say("Voyage complete") end
function M.voyage_failed()   say("Voyage failed", true) end

-- Weather stage entered. `smuggling.lua` passes the internal stage name
-- ("Fog"/"Hail"/"Gale"/"Storm") verbatim, or "calm" for a mid-voyage
-- calming (never the launch calm — that's filtered upstream).
function M.stage(name)
  if name == "calm" then
    say("Calm seas")
  else
    say(name)
  end
end

-- Leg finished; the label only, no XP. `which` is the completing stage
-- number for legs 1..3, or the string "final" for the last leg (whose
-- stage has usually already advanced by the time its XP line lands —
-- see smuggling.lua).
local LEG_LABEL = { [2] = "Leg one complete", [3] = "Leg two complete", [6] = "Leg three complete" }
function M.leg_complete(which)
  say((which == "final") and "Final leg complete" or (LEG_LABEL[which] or "Leg complete"))
end

-- Monster spawn is the one milestone that interrupts: it wants to reach
-- the player over any queued weather chatter.
function M.monster_spawn(name)
  say((name or "Monster") .. "!", true)
end

function M.monster_defeated(name, xp)
  local label = (name or "Monster") .. " defeated"
  if xp and xp > 0 then label = label .. ", " .. xp .. " xp" end
  say(label)
end

-- ---------------------------------------------------------------------
-- Line-driven cues — independent of the mission state machine. Patterns
-- mirror the lines already flagged in highlights.lua; for hazards we
-- trigger on the *onset* only (not the recurring condition/status
-- strings) and debounce so one that lingers doesn't repeat itself.
-- ---------------------------------------------------------------------

-- Ship under way. `smuggling.lua` also matches this line (among several
-- other movement messages) to advance Search → calm, but we want the
-- callout on this specific smokestack line only, so it gets its own
-- trigger rather than a milestone hook.
mud.trigger(
  [[^.*Steam whistles from the smokestack as the ship begins to move\..*$]],
  function() say_hazard("under_way", "Ship under way", 8) end)

-- Serpent strike — the urgent "move now" cue. Short debounce so rapid
-- consecutive strikes don't stutter, but each fresh strike still lands.
mud.trigger(
  [[^.*(?:The|the) sea serpent (?:lunges|reaches|strikes).*Run!.*$]],
  function() say_hazard("serpent_strike", "Run!", 4, true) end)

-- Fire on deck.
mud.trigger(
  [[^.*(?:The room catches on fire!|a small fire has started here).*$]],
  function() say_hazard("fire", "Fire started", 8) end)

-- Boiler run dry — the engine stalls until refilled.
mud.trigger(
  [[^(?:.*A little bell on the MK I Boiling Engine rings to indicate that it's out of water\.|The MK I Boiling Engine makes a sizzling sound as it boils dry\.).*$]],
  function() say_hazard("boiler", "Boiler dry", 8) end)

return M
