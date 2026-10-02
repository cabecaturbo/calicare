// The safety filter for meal ideas (prompt 5.4): no idea that mentions a
// paused or avoided food ever reaches the phone. Category words expand
// ("dairy" also catches milk, cheese, butter…). Every ingredient must come
// from what the parent said is in the fridge or on the safe list.

/** Words a category also covers. Conservative on purpose. */
export const CATEGORIES: Record<string, string[]> = {
  dairy: ["dairy", "milk", "cheese", "butter", "yogurt", "yoghurt", "cream", "whey", "casein", "ghee", "kefir"],
  egg: ["egg", "mayonnaise", "mayo", "meringue"],
  gluten: ["gluten", "wheat", "barley", "rye", "spelt", "flour", "bread", "pasta", "couscous", "semolina"],
  wheat: ["wheat", "flour", "bread", "pasta", "couscous", "semolina", "spelt"],
  peanut: ["peanut"],
  nut: ["nut", "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia"],
  "tree nut": ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia"],
  soy: ["soy", "soya", "tofu", "edamame", "tempeh", "miso", "tamari"],
  shellfish: ["shellfish", "shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop"],
  fish: ["fish", "salmon", "cod", "tuna", "trout", "sardine", "halibut", "anchovy"],
  corn: ["corn", "maize", "cornstarch", "polenta"],
  citrus: ["citrus", "orange", "lemon", "lime", "grapefruit", "clementine", "mandarin"],
  nightshade: ["nightshade", "tomato", "potato", "pepper", "eggplant", "paprika", "chili", "cayenne"],
};

/** Ingredients that are always fine to use without being listed. */
export const PANTRY = ["water", "salt"];

export interface Idea {
  title: string;
  ingredients: string[];
  steps: string[];
}

export function singular(word: string): string {
  const w = word.toLowerCase().trim();
  if (w.endsWith("ies")) return w.slice(0, -3) + "y";
  if (w.endsWith("oes")) return w.slice(0, -2);
  if (w.endsWith("es") && /(ch|sh|x|s)es$/.test(w)) return w.slice(0, -2);
  if (w.endsWith("s") && !w.endsWith("ss")) return w.slice(0, -1);
  return w;
}

/** The words to block for one avoided food or category. */
export function blockedWords(avoid: string[]): string[] {
  const words = new Set<string>();
  for (const raw of avoid) {
    const name = singular(raw);
    words.add(name);
    for (const [category, members] of Object.entries(CATEGORIES)) {
      if (name === category || name === singular(category)) members.forEach((m) => words.add(singular(m)));
    }
  }
  return [...words].filter((w) => w.length > 0);
}

/** Whole-word (plural-tolerant) match, so "egg" catches "eggs" but not "eggplant". */
export function mentions(text: string, word: string): boolean {
  const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`\\b${escaped}(?:s|es)?\\b`, "i").test(text);
}

/** Keeps ideas that avoid every blocked word and only use allowed ingredients. */
export function filterIdeas(ideas: unknown, avoid: string[], allowed: string[]): { ideas: Idea[]; rejected: number } {
  const blocked = blockedWords(avoid);
  const allowedWords = [...allowed, ...PANTRY].map(singular);
  const kept: Idea[] = [];
  let rejected = 0;
  for (const raw of Array.isArray(ideas) ? ideas : []) {
    const idea = raw as Partial<Idea>;
    const title = typeof idea.title === "string" ? idea.title.trim() : "";
    const ingredients = Array.isArray(idea.ingredients) ? idea.ingredients.filter((i): i is string => typeof i === "string") : [];
    const steps = Array.isArray(idea.steps) ? idea.steps.filter((s): s is string => typeof s === "string") : [];
    const all = [title, ...ingredients, ...steps].join("\n");
    const mentionsBlocked = blocked.some((word) => mentions(all, word));
    const onlyAllowed = ingredients.length > 0 &&
      ingredients.every((ingredient) => allowedWords.some((word) => mentions(ingredient, word)));
    if (!title || mentionsBlocked || !onlyAllowed) {
      rejected++;
      continue;
    }
    kept.push({ title, ingredients, steps: steps.slice(0, 8) });
  }
  return { ideas: kept, rejected };
}
