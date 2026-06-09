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

function applyState(state) {
  const header = state.header || { kind: "ready", value: "Ready" };
  headerRight.textContent = header.value;
  headerRight.className = "header-right " + header.kind;

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
