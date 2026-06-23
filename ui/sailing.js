// Discworld Sailing — panel UI.
//
// Receives a single `state` message per push from the Lua side. The state
// is a full snapshot (header + 6 rows + active index + total) — we replace
// the DOM contents wholesale rather than diffing, since there's nothing
// pinned/scrollable to preserve and the row count is tiny.

const ROWS = 6;
const NBSP = " ";

const rowsEl      = document.getElementById("rows");
const headerRight = document.getElementById("header-right");
const totalTime   = document.getElementById("total-time");
const totalXp     = document.getElementById("total-xp");

const rowEls = [];
for (let i = 0; i < ROWS; i++) {
  const tr = document.createElement("tr");
  tr.innerHTML =
    '<td class="name"></td>' +
    '<td class="xp"></td>'   +
    '<td class="time"></td>';
  rowsEl.appendChild(tr);
  rowEls.push({
    tr,
    name: tr.children[0],
    xp:   tr.children[1],
    time: tr.children[2],
  });
}

// nbsp keeps the row at its natural height when content is empty, so the
// table doesn't reflow as legs are filled in.
function cell(value) { return (value == null || value === "") ? NBSP : value; }

// Port of smuggling.lua fmt_hhmmss — must stay byte-identical to it so the
// client-ticked countdown reads the same as a Lua-rendered one would.
function fmtHHMMSS(s) {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return h + ":" + String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0");
}

// The cooldown header counts down from an absolute epoch (header.endsAt, shared
// Unix clock) entirely client-side, so the Lua side no longer pushes once a
// second for the full 2 h window. We self-flip to "Ready" at expiry.
let cooldownEndsAt = null;
let cooldownTimer  = null;

function tickCooldown() {
  if (cooldownEndsAt == null) return;
  const remaining = cooldownEndsAt - Date.now() / 1000;
  if (remaining <= 0) {
    cooldownEndsAt = null;
    if (cooldownTimer != null) { clearInterval(cooldownTimer); cooldownTimer = null; }
    headerRight.textContent = "Ready";
    headerRight.className = "header-right ready";
    return;
  }
  headerRight.textContent = fmtHHMMSS(remaining);
  headerRight.className = "header-right cooldown";
}

function renderHeader(header) {
  if (header.kind === "cooldown" && typeof header.endsAt === "number") {
    cooldownEndsAt = header.endsAt;
    if (cooldownTimer == null) cooldownTimer = setInterval(tickCooldown, 1000);
    tickCooldown();
    return;
  }
  // Ready (or any non-cooldown header): stop ticking and show the static label.
  cooldownEndsAt = null;
  if (cooldownTimer != null) { clearInterval(cooldownTimer); cooldownTimer = null; }
  headerRight.textContent = "Ready";
  headerRight.className = "header-right ready";
}

function applyState(state) {
  renderHeader(state.header || { kind: "ready" });

  const rows = state.rows || [];
  const activeIndex = state.activeIndex;

  for (let i = 0; i < ROWS; i++) {
    const row = rows[i] || {};
    const el = rowEls[i];
    el.tr.classList.toggle("active", i === activeIndex);
    el.name.textContent = cell(row.name);
    el.xp.textContent   = cell(row.xp);
    el.time.textContent = cell(row.time);
  }

  const total = state.total;
  totalTime.textContent = cell(total && total.time);
  totalXp.textContent   = cell(total && total.xp);
}

// `panel` is the iframe-side SDK injected by the host. Mirrors the pattern
// used by examples/plugins/discworld-chat/ui/chat.js.
panel.on("state", applyState);
panel.post("ready", {});
