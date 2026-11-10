import assert from "node:assert/strict";
import { test } from "node:test";
import { deal, sizeOf } from "../../app/assets/bingo.js";

const squares = (count) => Array.from({ length: count }, (_, index) => ({ title: `Class ${index}` }));
const firstPick = () => 0;

test("sizes read as columns by rows, defaulting to 5 by 5", () => {
  assert.deepEqual(sizeOf("6x8"), { cols: 6, rows: 8 });
  assert.deepEqual(sizeOf("12x24"), { cols: 12, rows: 24 });
  assert.deepEqual(sizeOf("nonsense"), { cols: 5, rows: 5 });
});

test("a 5 by 5 card has a free middle square", () => {
  const card = deal(squares(30), sizeOf("5x5"), firstPick);

  assert.equal(card.cells.length, 25);
  assert.equal(card.cells[12], "free");
  assert.equal(card.cells.filter((cell) => cell !== "free").length, 24);
});

test("cards without a middle square fill every cell", () => {
  const card = deal(squares(300), sizeOf("12x24"), Math.random);

  assert.equal(card.cells.length, 288);
  assert.equal(card.cells.includes("free"), false);
});

test("no class shows up twice on a card", () => {
  const card = deal(squares(48), sizeOf("6x8"), Math.random);

  assert.equal(new Set(card.cells.map((cell) => cell.title)).size, 48);
});

test("too few classes leaves no card and says how many are missing", () => {
  const card = deal(squares(40), sizeOf("6x8"), Math.random);

  assert.deepEqual(card, { cells: [], missing: 8 });
});
