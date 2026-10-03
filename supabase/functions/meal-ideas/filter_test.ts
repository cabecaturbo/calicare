import { assertEquals } from "jsr:@std/assert@1";
import { blockedWords, filterIdeas, mentions } from "./filter.ts";

const allowed = ["oats", "blueberries", "apple", "rice", "chicken", "carrot", "kale", "sweet potato"];

Deno.test("categories expand: dairy also blocks cheese and butter", () => {
  const words = blockedWords(["Dairy", "Eggs"]);
  for (const word of ["milk", "cheese", "butter", "egg", "mayonnaise"]) assertEquals(words.includes(word), true, word);
});

Deno.test("whole words only: egg is not eggplant", () => {
  assertEquals(mentions("Scrambled eggs", "egg"), true);
  assertEquals(mentions("Roasted eggplant", "egg"), false);
  assertEquals(mentions("PEANUT butter", "peanut"), true);
});

Deno.test("keeps a clean idea that uses only allowed foods", () => {
  const { ideas, rejected } = filterIdeas([
    { title: "Apple oat bowl", ingredients: ["oats", "apple", "water"], steps: ["Cook the oats in water.", "Top with apple."] },
  ], ["Dairy", "Eggs", "Peanuts"], allowed);
  assertEquals(ideas.length, 1);
  assertEquals(rejected, 0);
});

Deno.test("rejects ideas with paused foods, hidden ones, or unlisted ingredients", () => {
  const { ideas, rejected } = filterIdeas([
    { title: "Cheesy rice", ingredients: ["rice", "cheese"], steps: ["Melt cheese over rice."] },
    { title: "Oat pancakes", ingredients: ["oats", "apple"], steps: ["Whisk in an egg."] },
    { title: "Chicken satay", ingredients: ["chicken", "peanut sauce"], steps: [] },
    { title: "Rice and beans", ingredients: ["rice", "black beans"], steps: [] },
    { title: "", ingredients: ["rice"], steps: [] },
  ], ["Dairy", "Eggs", "Peanuts"], allowed);
  assertEquals(ideas, []);
  assertEquals(rejected, 5);
});

Deno.test("fuzz: an avoided food anywhere in an idea always rejects it", () => {
  const avoid = ["Dairy", "Eggs", "Peanuts", "Soy", "Shellfish", "Wheat"];
  const sneaky = ["milk", "Cheese", "butter", "eggs", "Egg", "mayo", "peanut", "PEANUTS", "soy sauce", "tofu", "shrimp",
    "prawns", "flour", "bread", "pasta", "yogurt", "cream", "ghee", "whey", "miso"];
  let seed = 7;
  const random = (n: number) => (seed = (seed * 1103515245 + 12345) % 2147483648) % n;
  for (let i = 0; i < 2000; i++) {
    const bad = sneaky[random(sneaky.length)];
    const where = random(3);
    const idea = {
      title: where === 0 ? `Rice with ${bad}` : "Rice bowl",
      ingredients: where === 1 ? ["rice", bad] : ["rice", "carrot"],
      steps: where === 2 ? [`Stir in some ${bad}.`] : ["Cook the rice."],
    };
    assertEquals(filterIdeas([idea], avoid, allowed).ideas.length, 0, JSON.stringify(idea));
  }
});
