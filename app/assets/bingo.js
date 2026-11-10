import { FACETS, element, emptyState, matches, parseQuery, toQuery, todayKey } from "./application.js";

const SIZES = ["5x5", "6x8", "12x24"];

export function sizeOf(size) {
  const [cols, rows] = (SIZES.includes(size) ? size : SIZES[0]).split("x").map(Number);
  return { cols, rows };
}

export function deal(squares, { cols, rows }, random) {
  const middle = cols % 2 && rows % 2 ? (cols * rows - 1) / 2 : -1;
  const needed = cols * rows - (middle < 0 ? 0 : 1);
  if (squares.length < needed) return { cells: [], missing: needed - squares.length };

  const pool = [...squares];
  const cells = Array.from({ length: needed }, () => pool.splice(Math.floor(random() * pool.length), 1)[0]);
  if (middle >= 0) cells.splice(middle, 0, "free");
  return { cells, missing: 0 };
}

function square(cell) {
  if (cell === "free") return element("li", { className: "free", textContent: "Free" });

  return element(
    "li",
    {},
    element("strong", { textContent: cell.title }),
    element("span", { textContent: cell.gym }),
    element("span", { textContent: `${cell.day} ${cell.time}` }),
  );
}

function startBingo() {
  const form = document.querySelector("#filter-form");
  const panel = document.querySelector("#filters");
  const card = document.querySelector("#bingo-card");
  const short = document.querySelector("#bingo-short");
  const squares = JSON.parse(document.querySelector("#bingo-squares").textContent);
  let state = parseQuery(location.search);

  function writeForm() {
    for (const input of form.querySelectorAll("input[type=checkbox]")) input.checked = state.filters[input.name].has(input.value);
    for (const group of form.querySelectorAll("details")) {
      if (group.querySelector("input:checked")) group.open = true;
    }
    form.elements.q.value = state.q;
  }

  function readForm() {
    const next = emptyState();
    for (const input of form.querySelectorAll("input[type=checkbox]:checked")) next.filters[input.name].add(input.value);
    next.q = form.elements.q.value.trim();
    return next;
  }

  function dealCard() {
    const size = form.elements.size.value;
    const { cols, rows } = sizeOf(size);
    const matching = squares.filter((each) => matches(each, state));
    const { cells, missing } = deal(matching, { cols, rows }, Math.random);

    short.hidden = !missing;
    short.textContent = missing ? `Only ${matching.length} classes match. A ${cols} by ${rows} card needs ${matching.length + missing}, so loosen a filter.` : "";
    card.dataset.size = size;
    card.style.setProperty("--cols", cols);
    card.replaceChildren(...cells.map(square));

    const params = new URLSearchParams(toQuery(state));
    if (size !== SIZES[0]) params.set("size", size);
    const query = params.toString();
    history.replaceState(null, "", query ? `?${query}` : location.pathname);
  }

  form.addEventListener("input", () => {
    state = readForm();
    dealCard();
  });
  form.addEventListener("submit", (event) => event.preventDefault());

  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-deal], [data-print], [data-today]");
    if (!target) return;

    if (target.matches("[data-deal]")) dealCard();
    if (target.matches("[data-print]")) window.print();
    if (target.matches("[data-today]")) {
      state = readForm();
      state.filters.day = new Set([todayKey()]);
      writeForm();
      dealCard();
    }
  });

  const wide = window.matchMedia("(min-width: 60rem)");
  panel.open = wide.matches;
  wide.addEventListener("change", () => (panel.open = wide.matches));

  const size = new URLSearchParams(location.search).get("size");
  form.elements.size.value = SIZES.includes(size) ? size : SIZES[0];
  writeForm();
  dealCard();
}

if (typeof document !== "undefined" && document.querySelector("#bingo-card")) startBingo();
