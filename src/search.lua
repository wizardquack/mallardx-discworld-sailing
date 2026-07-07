-- Searchable-loot hints — make each item in a "you think you can spot …"
-- line clickable so it fires the matching `search <keyword>` command.
--
-- Source line shape (one full line, variable-length item list):
--   You think you can spot a water tank, a wooden board, a squeaky toy
--   animal, an arbalest, a fire axe and a few nails hidden in there, but
--   it'd take a good search to be sure.
--
-- The list is comma-separated with " and " before the final item; each
-- item is prefixed with "a"/"an". Not every item is searchable — lines
-- also mention loot with no dedicated search keyword (carpenter's hammer,
-- old linen towel), which we leave as plain text.
--
-- We match the whole line, capture the item list (group 1), and rewrite
-- only that capture (`capture = 1`) so the fixed prefix/suffix — and any
-- styling on them — is preserved. The dynamic function walks the list and
-- emits a clickable span per known item, replaying everything else (the
-- articles, commas, "and", and unsearchable items) verbatim.

-- Item phrase (as it appears in the line) → search keyword. Ordered
-- longest-first so overlapping prefixes resolve to the longer phrase —
-- "arbalest bolt" must be tried before "arbalest".
local ITEMS = {
  { "steel-tipped harpoon", "harpoon" },
  { "squeaky toy animal",   "toy" },
  { "tin of shoe polish",   "tin" },
  { "rubber toy ball",      "toy" },
  { "box of bandages",      "box" },
  { "bottle of rum",        "rum" },
  { "arbalest bolt",        "bolt" },
  { "wooden board",         "board" },
  { "control rod",          "rod" },
  { "fire bucket",          "bucket" },
  { "coil of rope",         "rope" },
  { "lump of coal",         "coal" },
  { "water tank",           "tank" },
  { "large lemon",          "lemon" },
  { "few nails",            "nail" },
  { "fire axe",             "axe" },
  { "arbalest",             "arbalest" },
}

-- Word characters for boundary checks: letters, digits, and the
-- intra-word apostrophe / hyphen that appear in item names
-- ("carpenter's", "steel-tipped").
local function is_word_char(c)
  return c ~= "" and c ~= nil and c:match("[%w'%-]") ~= nil
end

-- Turn the captured item list into a flat span list, wrapping each known
-- item phrase in a clickable `search <keyword>` span and copying all
-- other text through unchanged.
local function linkify(list)
  local spans, pending, i = nil, {}, 1

  local function add(span)
    spans = spans and (spans .. span) or span
  end
  local function flush()
    if #pending > 0 then
      add(mud.span(table.concat(pending)))
      pending = {}
    end
  end

  while i <= #list do
    local matched = false
    -- Only start a phrase at a left word boundary so we never match
    -- inside an unsearchable item's name.
    if not is_word_char(list:sub(i - 1, i - 1)) then
      for _, entry in ipairs(ITEMS) do
        local phrase, keyword = entry[1], entry[2]
        local j = i + #phrase - 1
        if list:sub(i, j) == phrase and not is_word_char(list:sub(j + 1, j + 1)) then
          flush()
          add(mud.span(phrase, { send = "search " .. keyword }))
          i, matched = j + 1, true
          break
        end
      end
    end
    if not matched then
      pending[#pending + 1] = list:sub(i, i)
      i = i + 1
    end
  end

  flush()
  return spans
end

mud.replace(
  [[^You think you can spot (.+) hidden in there, but it'd take a good search to be sure\.$]],
  function(m)
    return linkify(m[1])
  end,
  { capture = 1 }
)

return {}
