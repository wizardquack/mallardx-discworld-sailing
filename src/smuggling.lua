-- Smuggling-mission stat panel — port of Kiki's MUSHclient plugin
-- (SmugglersToolbox.xml). Tracks the smuggling-mission cooldown,
-- per-leg timers + XP, monster fight time + XP, and total voyage
-- stats. Renders into a custom-HTML iframe panel
-- (`ui/sailing.{html,css,js}`) via a single `panel:post("state", …)`
-- per tick + on each state-changing trigger.
--
-- This module registers a panel handle, a timer, triggers and aliases
-- as side effects of being `require`d. Returns an empty table for the
-- require cache.
--
-- The keypad-remapping alias (!sailkeys) was intentionally skipped.

local panel = mud.panel("sailing")

-- ---------------------------------------------------------------------
-- Mission state — mirrors the MUSHclient script's globals.
--
-- currentStage encodes position in the voyage:
--   0 = Search    1 = calmStart    2 = leg1   3 = leg2
--   4 = calmMid   5 = (Monster)    6 = leg3   7 = leg4   8 = calmEnd
--
-- Calm stages aren't surfaced in the UI; they exist so next_stage() can
-- deduce which calm slot a "weather calms" message refers to.
-- ---------------------------------------------------------------------

local COOLDOWN_SECS  = 60 * 60 * 2   -- 2 hours
local CALM_STAGES    = { [1] = true, [4] = true, [8] = true }

-- Visible row order (6 rows reserved): Search, leg1, leg2, Monster, leg3, leg4.
-- The monster lands between leg2 and leg3 in voyage order so a player reading
-- top-to-bottom sees the voyage chronologically.
local ROW_STAGES = { 0, 2, 3, 5, 6, 7 }
local STAGE_TO_ROW = { [0] = 0, [2] = 1, [3] = 2, [5] = 3, [6] = 4, [7] = 5 }

local cooldownEnd      = 0   -- absolute epoch seconds; 0 means no cooldown
local currentStage     = 0
local currentlySailing = false
local fightingMonster  = false
local voyageStart      = 0   -- epoch seconds; 0 while no voyage is live
local voyageDuration   = 0   -- committed final duration of the last voyage
local stageEnterTime   = 0   -- epoch when currentStage was entered; 0 if none
local monsterStart     = 0   -- epoch when fightingMonster became true; 0 otherwise
local monsterName      = "Monster"

local stages          = {}   -- [stageNameString] = seconds
local stageXp         = {}   -- [stageNo] = xp
local thisTripStages  = {}   -- [stageNo] = stageNameString

local function reset_mission_tables()
  stages = {
    Search    = 0,
    calmStart = 0,
    calmMid   = 0,
    calmEnd   = 0,
    Fog       = 0,
    Hail      = 0,
    Gale      = 0,
    Storm     = 0,
    Monster   = 0,
  }
  stageXp        = {}
  thisTripStages = {
    [0] = "Search",
    [1] = "calmStart",
    [4] = "calmMid",
    [5] = "Monster",
    [8] = "calmEnd",
  }
end
reset_mission_tables()

-- ---------------------------------------------------------------------
-- Formatting helpers.
-- ---------------------------------------------------------------------

local function fmt_mmss(s)
  s = math.max(0, math.floor(s))
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function fmt_hhmmss(s)
  s = math.max(0, math.floor(s))
  return string.format("%d:%02d:%02d",
    math.floor(s / 3600),
    math.floor((s % 3600) / 60),
    s % 60)
end

-- Wall-clock derived to avoid drift: 7200 1s decrements accumulate
-- scheduler jitter into minutes over a 2h cooldown.
local function cooldown_remaining()
  local r = cooldownEnd - os.time()
  return r > 0 and r or 0
end

local function current_voyage_duration()
  if currentlySailing and voyageStart > 0 then
    return os.time() - voyageStart
  end
  return voyageDuration
end

-- Per-stage seconds = committed time in `stages[name]` plus the live
-- delta while that stage is the active one. Monster runs concurrently
-- with whatever weather/calm stage is current, so it has its own delta.
local function live_stage_secs(name)
  local secs = stages[name] or 0
  if currentlySailing then
    if stageEnterTime > 0 and thisTripStages[currentStage] == name then
      secs = secs + (os.time() - stageEnterTime)
    end
    if name == "Monster" and monsterStart > 0 then
      secs = secs + (os.time() - monsterStart)
    end
  end
  return secs
end

local function commit_active_stage()
  local name = thisTripStages[currentStage]
  if name and stageEnterTime > 0 then
    stages[name] = (stages[name] or 0) + (os.time() - stageEnterTime)
  end
  stageEnterTime = 0
end

local function commit_monster()
  if monsterStart > 0 then
    stages.Monster = (stages.Monster or 0) + (os.time() - monsterStart)
    monsterStart = 0
  end
end

local function fmt_xp(xp)
  if not xp or xp <= 0 then return nil end
  if xp >= 1000 then
    return string.format("%dk", math.floor(xp / 1000))
  end
  return tostring(xp)
end

-- ---------------------------------------------------------------------
-- State snapshot — derives the full panel render from the mission vars
-- above + an `is_active` map. The iframe replaces its DOM wholesale on
-- each push, so there's no diffing here.
-- ---------------------------------------------------------------------

local function active_row_index()
  if not currentlySailing then return nil end
  -- During the calmMid stage a monster fight is the focus, even though
  -- currentStage is still 4 — surface the Monster row instead.
  if fightingMonster then return 3 end
  return STAGE_TO_ROW[currentStage]
end

local function build_row(stageNo, isActive)
  local rawName = thisTripStages[stageNo]
  local xp      = stageXp[stageNo]

  if stageNo == 5 then
    local secs = live_stage_secs("Monster")
    -- Monster row stays blank until the fight starts (secs ticks > 0),
    -- is in progress (fightingMonster), or has resolved (xp set).
    if not (secs > 0 or xp or fightingMonster) then
      return { name = nil, time = nil, xp = nil }
    end
    return { name = monsterName, time = fmt_mmss(secs), xp = fmt_xp(xp) }
  end

  -- Non-monster rows: blank until the leg has been encountered. Search is
  -- entered immediately at voyage start so it shows from the first tick;
  -- weather legs are added to thisTripStages by next_stage() when reached.
  if not rawName then
    return { name = nil, time = nil, xp = nil }
  end
  local secs = live_stage_secs(rawName)
  if not isActive and secs == 0 and not xp then
    return { name = nil, time = nil, xp = nil }
  end
  return { name = rawName, time = fmt_mmss(secs), xp = fmt_xp(xp) }
end

local function build_header()
  local remaining = cooldown_remaining()
  if remaining > 0 then
    return { kind = "cooldown", value = fmt_hhmmss(remaining) }
  end
  return { kind = "ready", value = "Ready" }
end

local function build_total()
  local duration = current_voyage_duration()
  if duration == 0 then return nil end
  local total_xp = 0
  for _, v in pairs(stageXp) do total_xp = total_xp + (v or 0) end
  return { time = fmt_mmss(duration), xp = fmt_xp(total_xp) }
end

local function build_state()
  local active = active_row_index()
  local rows = {}
  for i, stageNo in ipairs(ROW_STAGES) do
    rows[i] = build_row(stageNo, active == (i - 1))
  end

  -- Between visible stages (calmStart / calmMid) currentlySailing is true
  -- but no row maps to currentStage. Highlight the next-reserved (first
  -- empty) row so the active marker doesn't blink off mid-voyage.
  if active == nil and currentlySailing then
    for i, row in ipairs(rows) do
      if not row.name then active = i - 1; break end
    end
  end

  return {
    header      = build_header(),
    rows        = rows,
    activeIndex = active,
    total       = build_total(),
  }
end

local function push_state() panel:post("state", build_state()) end

-- Custom-HTML panel handshake — iframe posts "ready" after its scripts
-- run; we reply with the current snapshot so it can paint immediately.
panel:on_message("ready", function() push_state() end)

-- ---------------------------------------------------------------------
-- Persistence — cooldown end-time + last-voyage row data.
--
-- We keep the rows visible through cooldown, "Ready", and across restarts
-- until the next voyage starts. The MUSHclient version only persisted the
-- cooldown; we additionally serialize the mission tables so a restart
-- between voyages doesn't blank out the panel.
-- ---------------------------------------------------------------------

local function save_cooldown()
  if cooldownEnd > os.time() then
    storage.set("cooldown_end", cooldownEnd)
  else
    storage.set("cooldown_end", nil)
  end
end

local function save_last_voyage()
  if voyageDuration == 0 then return end
  storage.set("last_voyage", {
    stages         = stages,
    stageXp        = stageXp,
    thisTripStages = thisTripStages,
    voyageDuration = voyageDuration,
    monsterName    = monsterName,
  })
end

-- ---------------------------------------------------------------------
-- Stage transitions.
-- ---------------------------------------------------------------------

local function next_stage(stageName)
  if not currentlySailing then return end

  -- Commit the outgoing stage's elapsed time before we move off it, so
  -- the `stages` table always reflects wall-clock truth up to the moment
  -- of transition. Re-anchored to the new stage at the end.
  commit_active_stage()

  if stageName == "calm" then
    if currentStage == 0 or currentStage == 2 then
      currentStage = 1
    elseif currentStage == 3 or currentStage == 5 or currentStage == 6 then
      currentStage = 4
    else
      currentStage = 8
    end
    stageEnterTime = os.time()
    push_state()
    return
  end

  -- Non-calm: a weather name (Fog/Hail/Gale/Storm). Reuse the slot if
  -- this weather already showed up earlier this voyage (rare, but the
  -- MUSHclient logic handles it).
  local matching = 0
  for i, v in pairs(thisTripStages) do
    if v == stageName then matching = i; break end
  end

  if matching > 0 then
    currentStage = matching
  else
    -- Coming out of the calmMid (monster) phase jumps straight to leg 3.
    if currentStage == 4 then
      currentStage = 6
    else
      currentStage = currentStage + 1
    end
    thisTripStages[currentStage] = stageName
    stages[stageName] = stages[stageName] or 0
  end
  stageEnterTime = os.time()
  push_state()
end

-- ---------------------------------------------------------------------
-- Mission lifecycle.
-- ---------------------------------------------------------------------

local function start_mission()
  cooldownEnd      = os.time() + COOLDOWN_SECS
  currentStage     = 0
  voyageStart      = os.time()
  voyageDuration   = 0
  stageEnterTime   = os.time()   -- anchors Search; subsequent stages re-anchor in next_stage
  monsterStart     = 0
  fightingMonster  = false
  monsterName      = "Monster"
  reset_mission_tables()
  currentlySailing = true
  storage.set("last_voyage", nil)
  save_cooldown()
  push_state()
end

local function end_mission()
  -- Commit any in-flight live deltas before tearing down state so the
  -- persisted `stages` table reflects the full voyage. Monster commit
  -- is a no-op unless the mission aborts mid-fight.
  commit_active_stage()
  commit_monster()
  if voyageStart > 0 then
    voyageDuration = os.time() - voyageStart
    voyageStart    = 0
  end
  currentlySailing = false
  fightingMonster  = false
  save_last_voyage()
  push_state()
end

-- ---------------------------------------------------------------------
-- Per-second tick. Drives cooldown countdown + active-stage timers, then
-- pushes the full state snapshot.
-- ---------------------------------------------------------------------

local cooldownWasActive = false

mud.every(1000, function()
  local changed = false

  -- Cooldown value is wall-clock derived; the tick just drives the UI
  -- refresh so the displayed HH:MM:SS rolls forward each second. The
  -- `or cooldownWasActive` clause forces one final push the tick after
  -- expiry — otherwise the header freezes at 0:00:01 instead of flipping
  -- to "Ready", because the tick would otherwise no-op once remaining=0.
  local cdActive = cooldown_remaining() > 0
  if cdActive or cooldownWasActive then
    changed = true
  end
  cooldownWasActive = cdActive

  if currentlySailing then
    -- All voyage-side timers (voyage duration, per-stage, monster) are
    -- wall-clock derived via current_voyage_duration / live_stage_secs;
    -- the tick just drives the per-second UI repaint.
    changed = true
  end

  if changed then push_state() end
end)

-- ---------------------------------------------------------------------
-- Triggers — patterns copied verbatim from SmugglersToolbox.xml, with
-- MUSHclient's named groups (?P<x>…) downgraded to plain (…) and
-- handlers ported to Lua. Every per-stage trigger no-ops outside of an
-- active mission.
-- ---------------------------------------------------------------------

-- Start mission. Captain Smith / Chidder farewell line.
mud.trigger(
  [[^The loading of the ship complete, (?:Captain Smith|Chidder) wishes you a safe and profitable trip]],
  function() start_mission() end)

-- Voyage begin: the ship starts moving while we're still in the Search
-- phase. Move into calmStart on the first such message.
mud.trigger(
  [[^(?:Steam whistles from the smokestack as the ship begins to move|You feel the ship begin to move|The ship shudders around you as it turns to|The ship steams off, dragging you along by the rope tied around your waist\.|The ship steams off and you hurriedly swim along to keep up with it\.|The ship turns to (?:port|starboard)\.|The ship makes a turn to (?:port|starboard)\.|The ship turns sharply to (?:port|starboard)\.)]],
  function()
    if currentlySailing and currentStage == 0 then next_stage("calm") end
  end)

-- Per-leg XP grant (first/second/third legs — the final leg uses a
-- different message; see FinalXpTrigger below).
mud.trigger(
  [[^As you (?:finish|complete) the (?:first|second|third) leg of your impossible voyage.+ \((\d+) xp\)$]],
  function(m)
    if not currentlySailing then return end
    -- m[1] auto-coerces \d+ captures to numbers.
    local xp = m[1]
    if xp then
      stageXp[currentStage] = xp
      push_state()
    end
  end)

-- Monster fight start.
mud.trigger(
  [[^(A massive (?:kraken|sea serpent) crests|The faint popping sounds of suction cups|The grinding of scales against wood)]],
  function(m)
    if not currentlySailing then return end
    fightingMonster = true
    monsterStart    = os.time()
    local marker = m[1] or ""
    if marker:find("kraken") or marker:find("suction cups") then
      monsterName = "Kraken"
    else
      monsterName = "Serpent"
    end
    push_state()
  end)

-- Monster fight end with XP.
mud.trigger(
  [[^As the (?:kraken|serpent) sinks back beneath the waves.+ \((\d+) xp\)$]],
  function(m)
    if not currentlySailing then return end
    local xp = m[1]
    if xp then stageXp[5] = xp end
    commit_monster()
    fightingMonster = false
    push_state()
  end)

-- Weather transitions. Each clears whatever weather we were in and
-- starts the new one.
mud.trigger(
  [[^(?:The ship leaves the huge bank of fog as the weather calms\.|The howling winds fade away as the weather calms\.|The worst of the thunderstorm passes and the clouds overhead lighten and scatter to the winds as the weather calms\.|The rain of hailstones slowly peters off and the clouds overhead lighten and scatter to the winds as the weather calms\.|The last of the fog seeping in from overhead dissipates\.|The sound of hailstones pounding overhead gradually peters out\.|The sound of thunder overhead gradually peters out\.|The faint howl of the wind overhead gradually peters out\.)$]],
  function() next_stage("calm") end)

mud.trigger(
  [[^(?:The previously calm weather fades away as the ship enters a huge bank of fog\.|The rain of hailstones slowly peters off and the clouds overhead lighten and scatter to the winds just as the ship enters a huge bank of fog\.|The worst of the thunderstorm passes and the clouds overhead lighten and scatter to the winds just as the ship enters a huge bank of fog\.|The howling winds fade away as the ship enters a huge bank of fog\.|Wisps of fog begin to drift in through tiny gaps in the deck above\.|The sound of hailstones pounding overhead gradually peters out as wisps of fog begin to drift in through tiny gaps in the deck above\.|The sound of thunder overhead gradually peters out as wisps of fog begin to drift in through tiny gaps in the deck above\.|The faint howl of the wind overhead gradually peters out as wisps of fog begin to drift in through tiny gaps in the deck above\.)$]],
  function() next_stage("Fog") end)

mud.trigger(
  [[^(?:The previously calm weather fades away as grey clouds gather overhead and hailstones begin to rain from the sky\.|The howling winds fade away as grey clouds gather overhead and hailstones begin to rain from the sky\.|The worst of the thunderstorm passes as hailstones begin to rain from the sky\.|The ship leaves the huge bank of fog as grey clouds gather overhead and hailstones begin to rain from the sky\.|The sound of pounding hail starts to filter through from the deck above\.|The sound of thunder overhead gradually peters out and is replaced by the sound of pounding hail\.|The faint howl of the wind overhead gradually peters out and is replaced by the sound of pounding hail\.|The last of the fog seeping in from overhead dissipates as the sound of pounding hail starts to filter through from the deck above\.)$]],
  function() next_stage("Hail") end)

mud.trigger(
  [[^(?:The previously calm weather fades away as a rimwards gale starts building up, the sheer force of the wind pushing the ship backwards\.|The worst of the thunderstorm passes and the clouds overhead lighten and scatter to the winds just as a rimwards gale starts building up, the sheer force of the wind pushing the ship backwards\.|The rain of hailstones slowly peters off and the clouds overhead lighten and scatter to the winds just as a rimwards gale starts building up, the sheer force of the wind pushing the ship backwards\.|The ship leaves the huge bank of fog as a rimwards gale starts building up, the sheer force of the wind pushing the ship backwards\.|The faint howling of what must be quite a strong wind begins to filter through the deck above\.|The last of the fog seeping in from overhead dissipates as the faint howling of what must be quite a strong wind begins to filter through the deck above\.|The sound of hailstones pounding overhead gradually peters out and is replaced by the faint howling of what must be quite a strong wind\.|The sound of thunder overhead gradually peters out and is replaced by the faint howling of what must be quite a strong wind\.)$]],
  function() next_stage("Gale") end)

mud.trigger(
  [[^(?:The previously calm weather fades away as a growing wind sweeps in dark clouds from all directions, lightning flashes and thunder booms, the beginning of a thunderstorm\.|The ship leaves the huge bank of fog as a growing wind sweeps in dark clouds from all directions, lightning flashes and thunder booms, the beginning of a thunderstorm\.|The howling winds fade away as a growing wind sweeps in dark clouds from all directions, lightning flashes and thunder booms, the beginning of a thunderstorm\.|The rain of hailstones slowly peters off as lightning flashes and thunder booms, the beginning of a thunderstorm\.|The rumble of thunder comes through from the deck above\.|The sound of hailstones pounding overhead gradually peters out and is replaced by the rumble of thunder\.|The last of the fog seeping in from overhead dissipates as the rumble of thunder comes through from the deck above\.|The faint howl of the wind overhead gradually peters out and is replaced by the rumble of thunder\.)$]],
  function() next_stage("Storm") end)

-- Final leg XP + mission end. The "weather calms" line at the end of leg
-- 4 has usually already shifted currentStage from 7 (leg4) to 8 (calmEnd)
-- by the time this XP message arrives, so we can't use currentStage like
-- the per-leg trigger above — hard-code the leg4 slot.
mud.trigger(
  [[^As you (?:finish|complete) the final leg of your impossible voyage.+ \((\d+) xp\)$]],
  function(m)
    if not currentlySailing then return end
    local xp = m[1]
    if xp then stageXp[7] = xp end
    end_mission()
  end)

-- Mission abort (ship sinks, swam too far, beached, etc).
mud.trigger(
  [[^(?:As the ship sinks slowly beneath the waves|As you swim a little too far from the ship|You failed your mission because the SS Unsinkable|The ship steams off\.  You're too tired to follow it)]],
  function() if currentlySailing then end_mission() end end)

-- ---------------------------------------------------------------------
-- Debug client commands ported from the MUSHclient version. Skipped:
-- !sail (the help dialog), !sailFront (window z-order), !sailkeys
-- (keypad remap). Invoke as /startMission, /endMission, etc. (default
-- prefix); the user's `command_prefix` setting controls the leader.
-- ---------------------------------------------------------------------

mud.command("startMission", function() start_mission()
  mud.note("Smuggling mission forced started.") end, {
  description = "Force-start a smuggling mission for tracking.",
  usage = "startMission",
})

mud.command("endMission", function() end_mission()
  mud.note("Smuggling mission forced ended.") end, {
  description = "Force-end the current smuggling mission.",
  usage = "endMission",
})

mud.command("nextStage", function(m)
  next_stage(m.args); mud.note("Forced next stage: " .. m.args) end, {
  description = "Record the next stage of the active mission.",
  usage = "nextStage <stage>",
})

mud.command("sailData", function()
  mud.note("currentStage: " .. tostring(currentStage))
  for k, v in pairs(thisTripStages) do mud.note("  trip[" .. k .. "] = " .. v) end
  for k, v in pairs(stageXp)        do mud.note("  xp[" .. k .. "] = " .. v) end
end, {
  description = "Dump current sailing-run tracking state.",
  usage = "sailData",
})

-- ---------------------------------------------------------------------
-- Restore persistent state across restarts. We store the cooldown
-- end-time absolutely (so the math is trivial) and the last-voyage
-- mission tables as a single blob.
-- ---------------------------------------------------------------------

do
  local saved_end = tonumber(storage.get("cooldown_end"))
  if saved_end then
    if saved_end > os.time() then
      cooldownEnd = saved_end
    else
      storage.set("cooldown_end", nil)
    end
  end

  -- Storage round-trips through JSON, so sparse int-keyed tables come back
  -- with string keys ("2" instead of 2). Coerce keys back for the two
  -- tables the renderer indexes by integer stageNo.
  local function with_int_keys(t)
    if not t then return nil end
    local out = {}
    for k, val in pairs(t) do out[tonumber(k) or k] = val end
    return out
  end

  local v = storage.get("last_voyage")
  if v then
    stages         = v.stages                          or stages
    stageXp        = with_int_keys(v.stageXp)          or stageXp
    thisTripStages = with_int_keys(v.thisTripStages)   or thisTripStages
    voyageDuration = v.voyageDuration                  or 0
    monsterName    = v.monsterName                     or "Monster"
  end
end

push_state()

return {}
