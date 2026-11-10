export const FACETS = ["day", "when", "who", "discipline", "attire", "format", "region", "city", "gym"];

const VIEWS = ["list", "week", "map"];
const DAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
const LEAFLET = {
  js: ["https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js", "sha512-puJW3E/qXDqYp9IfhAI54BJEaWIfloJ7JWs7OeD5i6ruC9JZL1gERT1wjtwXFlh7CjE7ZJ+/vcRZRkIYIb6p4g=="],
  css: ["https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css", "sha512-h9FcoyWjHcOcmEVkxOfTLnmZFWIH0iZhZT1H2TbOq55xssQGEJHEaIm+PgoUaZbRvQTNTluNOEfb1ZRy6D3BOw=="],
};
const TILES = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

export function emptyState() {
  return { filters: Object.fromEntries(FACETS.map((facet) => [facet, new Set()])), q: "", view: "week" };
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
  if (state.view !== "week") params.set("view", state.view);

  const query = params.toString();
  return query ? `?${query}` : "";
}

export function todayKey(date = new Date()) {
  return DAY_KEYS[date.getDay()];
}

export function pinsFor(pins, visibleEntries) {
  const counts = new Map();
  for (const entry of visibleEntries) {
    for (const slug of entry.facets.gym) counts.set(slug, (counts.get(slug) ?? 0) + 1);
  }

  return pins.filter((pin) => counts.has(pin.slug)).map((pin) => ({ ...pin, classes: counts.get(pin.slug) }));
}

// Okabe-Ito colors, which stay distinct for colorblind viewers, lightened where they'd vanish on a dark map.
const REGION_PALETTE = ["#E69F00", "#56B4E9", "#009E73", "#F0E442", "#CC79A7", "#D55E00", "#8FB8FF", "#E0E0E0"];

export function regionColors(slugs) {
  return Object.fromEntries(slugs.map((slug, index) => [slug, REGION_PALETTE[index % REGION_PALETTE.length]]));
}

let leaflet;

function loadLeaflet() {
  leaflet ??= new Promise((resolve, reject) => {
    const css = Object.assign(document.createElement("link"), { rel: "stylesheet", href: LEAFLET.css[0], integrity: LEAFLET.css[1], crossOrigin: "" });
    const js = Object.assign(document.createElement("script"), { src: LEAFLET.js[0], integrity: LEAFLET.js[1], crossOrigin: "" });
    js.onload = () => resolve(window.L);
    js.onerror = reject;
    document.head.append(css, js);
  });
  return leaflet;
}

function element(tag, props = {}, ...children) {
  const el = Object.assign(document.createElement(tag), props);
  el.append(...children);
  return el;
}

function popupFor(pin) {
  const link = (text, href) => element("a", { href, target: "_blank", rel: "noopener", textContent: text });

  return element(
    "div",
    { className: "pin" },
    element("strong", {}, link(pin.name, pin.site ?? pin.directions)),
    element("p", { textContent: `${pin.city}, ${pin.classes} ${pin.classes === 1 ? "class" : "classes"}` }),
    element(
      "p",
      { className: "pin-links" },
      link("Directions", pin.directions),
      element("button", { type: "button", className: "text-button", value: pin.slug, textContent: "See classes" }),
    ),
  );
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
  const mapEl = document.querySelector("#map");
  const mapToggle = document.querySelector("[data-map-toggle]");
  const pins = JSON.parse(document.querySelector("#gym-pins").textContent);
  const regions = [...form.querySelectorAll("input[name=region]")].map((input) => ({ slug: input.value, name: input.parentElement.textContent.trim() }));
  const colors = regionColors(regions.map((region) => region.slug));
  for (const input of form.querySelectorAll("input[name=region]")) {
    input.after(element("span", { className: "region-dot", style: `--region: ${colors[input.value]}` }));
  }
  let map;
  let markers;
  let legend;
  const days = [...document.querySelectorAll(".day")];
  const slots = [...document.querySelectorAll(".slot")];
  const hours = [...document.querySelectorAll(".hour")];
  const entries = [...document.querySelectorAll(".entry")].map((el) => ({
    el,
    text: el.querySelector(".entry-text").textContent.toLowerCase(),
    facets: Object.fromEntries(FACETS.map((facet) => [facet, (el.dataset[facet] ?? "").split(" ").filter(Boolean)])),
  }));

  function paint(el, slugs) {
    el.style.setProperty("--region", colors[slugs[0]]);
    el.style.setProperty("--region-2", colors[slugs.at(-1)]);
  }
  for (const entry of entries) paint(entry.el, entry.facets.region);
  const gymCards = [...document.querySelectorAll("#gyms .gym")].map((el) => ({ el, regions: el.dataset.region.split(" ") }));
  for (const gym of gymCards) paint(gym.el, gym.regions);

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
    const rows = new Set();
    for (const slot of slots) {
      slot.hidden = !slot.querySelector(".entry:not([hidden])");
      if (!slot.hidden) rows.add(slot.style.getPropertyValue("--row"));
    }
    for (const hour of hours) hour.hidden = !rows.has(hour.style.getPropertyValue("--row"));

    let column = 2;
    for (const day of days) {
      const shown = day.querySelectorAll(".entry:not([hidden])").length;
      day.hidden = !shown;
      day.querySelector(".day-count").textContent = shown;
      if (shown) day.style.setProperty("--col", column++);
    }
    schedule.style.setProperty("--cols", Math.max(column - 2, 1));
    for (const gym of gymCards) gym.el.hidden = state.filters.region.size > 0 && !gym.regions.some((slug) => state.filters.region.has(slug));

    const query = toQuery(state);
    schedule.dataset.view = state.view;
    mapEl.hidden = state.view !== "map";
    mapToggle.textContent = state.view === "map" ? "Back to the schedule" : "Map";
    if (state.view === "map") drawMap(pinsFor(pins, entries.filter((entry) => !entry.el.hidden)));
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

  async function drawMap(visible) {
    const L = await loadLeaflet();
    if (!map) {
      mapEl.classList.toggle("dark", getComputedStyle(root).colorScheme.includes("dark"));
      map = L.map(mapEl, { scrollWheelZoom: false, zoomSnap: 0.25 });
      L.tileLayer(TILES, { attribution: ATTRIBUTION, maxZoom: 18 }).addTo(map);
      markers = L.featureGroup().addTo(map);
      legend = L.control({ position: "bottomleft" });
      legend.onAdd = () => element("div", { className: "legend" });
      legend.addTo(map);
      L.DomEvent.disableClickPropagation(legend.getContainer());
      mapEl.addEventListener("click", (event) => {
        const pinButton = event.target.closest(".pin button");
        const regionButton = event.target.closest(".legend button");
        if (pinButton) showGym(pinButton.value);
        if (regionButton) toggleRegion(regionButton.value);
      });
    }

    markers.clearLayers();
    for (const pin of visible) {
      const radius = 4 + Math.sqrt(pin.classes);
      const [first, second = first] = pin.regions.map((slug) => colors[slug]);
      const marker = first === second
        ? L.circleMarker([pin.lat, pin.lng], { radius, color: "#000", weight: 1.5, fillColor: first, fillOpacity: 0.95 })
        : L.marker([pin.lat, pin.lng], {
            icon: L.divIcon({ className: "split-pin", iconSize: [radius * 2 + 3, radius * 2 + 3], html: `<span style="background: linear-gradient(90deg, ${first} 50%, ${second} 50%)"></span>` }),
          });
      marker
        .bindPopup(() => popupFor(pin))
        .bindTooltip(pin.name)
        .addTo(markers);
    }
    drawLegend(new Set(visible.flatMap((pin) => pin.regions)));
    map.invalidateSize();
    if (visible.length) map.fitBounds(markers.getBounds(), { padding: [16, 16], maxZoom: 13 });
    else map.setView([42.45, -83.2], 9);
  }

  function drawLegend(shown) {
    const items = regions.map((region) =>
      element(
        "button",
        { type: "button", value: region.slug, className: state.filters.region.has(region.slug) ? "on" : shown.has(region.slug) ? "" : "off" },
        element("span", { className: "swatch", style: `background: ${colors[region.slug]}` }),
        region.name,
      ),
    );
    legend.getContainer().replaceChildren(element("strong", { textContent: "Regions" }), ...items);
  }

  function toggleRegion(slug) {
    const next = readForm();
    if (next.filters.region.has(slug)) next.filters.region.delete(slug);
    else next.filters.region.add(slug);
    update(next);
  }

  function showGym(slug) {
    const next = readForm();
    next.filters.gym = new Set([slug]);
    if (next.view === "map") next.view = "week";
    update(next);
    schedule.scrollIntoView();
  }

  function openGym(slug) {
    const card = document.getElementById(`gym-${slug}`).cloneNode(true);
    card.hidden = false;
    card.removeAttribute("id");
    dialog.querySelector("[data-gym-slot]").replaceChildren(card);
    dialog.querySelector("[data-only-gym]").value = slug;
    dialog.showModal();
  }

  function printAs(mode) {
    root.dataset.print = mode;
    if (mode !== "gyms") schedule.dataset.view = mode;
    window.print();
  }

  form.addEventListener("input", () => {
    state = readForm();
    render();
  });
  form.addEventListener("submit", (event) => event.preventDefault());
  window.addEventListener("beforeprint", () => {
    root.dataset.print ||= state.view === "map" ? "list" : state.view;
    schedule.dataset.view = root.dataset.print === "gyms" ? state.view : root.dataset.print;
  });
  window.addEventListener("afterprint", () => {
    delete root.dataset.print;
    schedule.dataset.view = state.view;
  });

  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-today], [data-clear], [data-print-as], [data-gym-link], [data-only-gym], [data-map-toggle], [data-close]");
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
      dialog.close();
      showGym(target.value);
    } else if (target.matches("[data-map-toggle]")) {
      update({ ...readForm(), view: state.view === "map" ? "week" : "map" });
    } else {
      dialog.close();
    }
  });

  const wide = window.matchMedia("(min-width: 60rem)");
  panel.open = wide.matches;
  days.find((day) => day.id.startsWith(todayKey()))?.setAttribute("data-today", "");
  wide.addEventListener("change", () => (panel.open = wide.matches));

  writeForm();
  render();
}

if (typeof document !== "undefined") boot();
