import assert from "node:assert/strict";
import { test } from "node:test";
import { emptyState, matches, parseQuery, toQuery, todayKey } from "../../app/assets/application.js";

const entry = (facets, text = "") => ({ facets, text });

const stateWith = (filters = {}, q = "") => {
  const state = emptyState();
  for (const [facet, values] of Object.entries(filters)) state.filters[facet] = new Set(values);
  state.q = q;
  return state;
};

test("an empty state matches everything", () => {
  assert.equal(matches(entry({ day: ["mon"] }), emptyState()), true);
});

test("values within a facet are alternatives", () => {
  const state = stateWith({ day: ["mon", "tue"] });

  assert.equal(matches(entry({ day: ["tue"] }), state), true);
  assert.equal(matches(entry({ day: ["wed"] }), state), false);
});

test("separate facets must all match", () => {
  const state = stateWith({ day: ["mon"], who: ["kids"] });

  assert.equal(matches(entry({ day: ["mon"], who: ["kids"] }), state), true);
  assert.equal(matches(entry({ day: ["mon"], who: ["adults"] }), state), false);
});

test("an entry with several disciplines matches any of them", () => {
  const state = stateWith({ discipline: ["judo"] });

  assert.equal(matches(entry({ discipline: ["bjj", "judo"] }), state), true);
});

test("a facet the entry lacks does not match a selected filter", () => {
  assert.equal(matches(entry({}), stateWith({ attire: ["gi"] })), false);
});

test("search requires every word, in any order", () => {
  const judo = entry({}, "shojin judo adult beginner southfield");

  assert.equal(matches(judo, stateWith({}, "judo shojin")), true);
  assert.equal(matches(judo, stateWith({}, "Judo Troy")), false);
});

test("reads filters, search and view from the query string", () => {
  const state = parseQuery("?day=mon,tue&who=kids&q=judo&view=week");

  assert.deepEqual([...state.filters.day], ["mon", "tue"]);
  assert.deepEqual([...state.filters.who], ["kids"]);
  assert.equal(state.q, "judo");
  assert.equal(state.view, "week");
});

test("ignores unknown params and views", () => {
  const state = parseQuery("?nope=1&view=sideways");

  assert.equal(state.filters.nope, undefined);
  assert.equal(state.view, "list");
});

test("writes only what is set, so a clean page has a clean URL", () => {
  assert.equal(toQuery(emptyState()), "");
});

test("a query string survives the round trip", () => {
  const search = "?day=mon%2Ctue&who=kids&q=open+mat&view=week";

  assert.equal(toQuery(parseQuery(search)), search);
});

test("todayKey follows the schedule's day keys", () => {
  assert.equal(todayKey(new Date(2026, 10, 9)), "mon");
  assert.equal(todayKey(new Date(2026, 10, 8)), "sun");
});
