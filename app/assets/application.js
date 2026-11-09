export const FACETS = ["day", "when", "who", "discipline", "attire", "format", "city", "gym"];

const VIEWS = ["list", "week"];
const DAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

export function emptyState() {
  return { filters: Object.fromEntries(FACETS.map((facet) => [facet, new Set()])), q: "", view: "list" };
}

export function matches(entry, state) {
  for (const facet of FACETS) {
    const selected = state.filters[facet];
    if (selected.size && !(entry.facets[facet] ?? []).some((value) => selected.has(value))) return false;
  }

  return state.q.toLowerCase().split(/\s+/).filter(Boolean).every((word) => entry.text.includes(word));
}

export function parseQuery(search) {
  const params = new URLSearchParams(search);
  const state = emptyState();

  for (const facet of FACETS) {
    state.filters[facet] = new Set((params.get(facet) ?? "").split(",").filter(Boolean));
  }
  state.q = params.get("q") ?? "";
  if (VIEWS.includes(params.get("view"))) state.view = params.get("view");

  return state;
}

export function toQuery(state) {
  const params = new URLSearchParams();

  for (const facet of FACETS) {
    if (state.filters[facet].size) params.set(facet, [...state.filters[facet]].join(","));
  }
  if (state.q) params.set("q", state.q);
  if (state.view !== "list") params.set("view", state.view);

  const query = params.toString();
  return query ? `?${query}` : "";
}

export function todayKey(date = new Date()) {
  return DAY_KEYS[date.getDay()];
}

function boot() {
  const root = document.documentElement;
  const form = document.querySelector("#filter-form");
  const panel = document.querySelector("#filters");
  const schedule = document.querySelector("#schedule");
  const count = document.querySelector("#result-count");
  const empty = document.querySelector("#no-results");
  const clear = document.querySelector("[data-clear]");
  const dialog = document.querySelector("#gym-card");
  const days = [...document.querySelectorAll(".day")];
  const entries = [...document.querySelectorAll(".entry")].map((el) => ({
    el,
    text: el.querySelector(".entry-text").textContent.toLowerCase(),
    facets: Object.fromEntries(FACETS.map((facet) => [facet, (el.dataset[facet] ?? "").split(" ").filter(Boolean)])),
  }));

  let state = parseQuery(location.search);

  function writeForm() {
    for (const input of form.querySelectorAll("input[type=checkbox]")) {
      input.checked = state.filters[input.name].has(input.value);
    }
    for (const group of form.querySelectorAll("details")) {
      if (group.querySelector("input:checked")) group.open = true;
    }
    form.elements.q.value = state.q;
    form.elements.view.value = state.view;
  }

  function readForm() {
    const next = emptyState();

    for (const input of form.querySelectorAll("input[type=checkbox]:checked")) next.filters[input.name].add(input.value);
    next.q = form.elements.q.value.trim();
    next.view = form.elements.view.value;

    return next;
  }

  function render() {
    let visible = 0;

    for (const entry of entries) {
      entry.el.hidden = !matches(entry, state);
      if (!entry.el.hidden) visible += 1;
    }
    for (const day of days) day.hidden = !day.querySelector(".entry:not([hidden])");

    const query = toQuery(state);
    schedule.dataset.view = state.view;
    count.textContent = `${visible.toLocaleString()} ${visible === 1 ? "class" : "classes"}`;
    empty.hidden = visible > 0;
    clear.hidden = !FACETS.some((facet) => state.filters[facet].size) && !state.q;
    history.replaceState(null, "", query || location.pathname);
  }

  function update(next) {
    state = next;
    writeForm();
    render();
  }

  function openGym(slug) {
    const card = document.getElementById(`gym-${slug}`).cloneNode(true);
    card.removeAttribute("id");
    dialog.querySelector("[data-gym-slot]").replaceChildren(card);
    dialog.querySelector("[data-only-gym]").value = slug;
    dialog.showModal();
  }

  function printAs(mode) {
    root.dataset.print = mode;
    window.print();
  }

  form.addEventListener("input", () => {
    state = readForm();
    render();
  });
  form.addEventListener("submit", (event) => event.preventDefault());
  window.addEventListener("afterprint", () => delete root.dataset.print);

  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-today], [data-clear], [data-print-as], [data-gym-link], [data-only-gym], [data-close]");
    if (!target) {
      if (event.target === dialog) dialog.close();
      return;
    }

    if (target.matches("[data-gym-link]")) {
      if (event.metaKey || event.ctrlKey || event.shiftKey) return;
      event.preventDefault();
      openGym(target.dataset.gymLink);
    } else if (target.matches("[data-today]")) {
      const next = readForm();
      next.filters.day = new Set([todayKey()]);
      update(next);
    } else if (target.matches("[data-clear]")) {
      update({ ...emptyState(), view: state.view });
    } else if (target.matches("[data-print-as]")) {
      printAs(target.dataset.printAs);
    } else if (target.matches("[data-only-gym]")) {
      const next = readForm();
      next.filters.gym = new Set([target.value]);
      update(next);
      dialog.close();
      schedule.scrollIntoView();
    } else {
      dialog.close();
    }
  });

  const wide = window.matchMedia("(min-width: 60rem)");
  panel.open = wide.matches;
  wide.addEventListener("change", () => (panel.open = wide.matches));

  writeForm();
  render();
}

if (typeof document !== "undefined") boot();
