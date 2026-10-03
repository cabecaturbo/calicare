// Grounding (prompt 4.2): the model only extracts; this file makes sure of it.
// Every item must quote a line that is really in the plan, every detail
// (dose, frequency, timing, duration) must appear in the plan's text, and
// anything missing stays blank and is flagged. Nothing is ever filled in.

import { isFaithful } from "./plain.ts";

export const KINDS = [
  "routineStep", "topicalStep", "bath", "supplement", "medication", "foodRule", "fundamental", "followUp",
] as const;
export type Kind = typeof KINDS[number];

export const DETAILS = ["dose", "frequency", "timing", "duration"] as const;

/** Step categories, the same as the app's StepCategory. */
export const CATEGORIES = ["wash", "apply", "give", "feed", "dress"] as const;
export type Category = typeof CATEGORIES[number];

/** Verbs a label may start with: the same list as the app's StepLabeler. */
const VERBS = new Set([
  "apply", "wash", "give", "feed", "put", "take", "rinse", "seal", "bathe", "dress", "offer", "use", "rub",
  "massage", "spray", "soak", "pat", "dry", "brush", "change", "open", "wrap", "cover", "read", "drink", "eat",
  "mix", "add", "check", "trim", "clean", "moisturize", "moisturise", "remove", "start", "soothe", "layer", "dab",
]);
const MAX_LABEL_WORDS = 6;
export type Detail = typeof DETAILS[number];

/** What the model returns for one item, before checking. */
export interface RawItem {
  kind?: unknown;
  text?: unknown;
  dose?: unknown;
  frequency?: unknown;
  timing?: unknown;
  duration?: unknown;
  source_page?: unknown;
  source_line?: unknown;
  label?: unknown;
  detail?: unknown;
  category?: unknown;
  plain?: unknown;
}

/** A checked item, ready for the phone's review screen. */
export interface Item {
  kind: Kind;
  text: string;
  dose: string | null;
  frequency: string | null;
  timing: string | null;
  duration: string | null;
  source_page: number;
  source_line: string;
  /** A short, verb-first label made only of the plan's words, or null. */
  label: string | null;
  detail: string | null;
  category: Category | null;
  /** Plain words, kept only if they change no number or brand and read at grade 6. */
  plain: string | null;
  /** Details the plan left blank that a parent would expect: "Worth asking at your next visit." */
  blanks: Detail[];
}

export interface Checked {
  items: Item[];
  /** Items dropped because their source line isn't in the plan, or their kind is unknown. */
  dropped: number;
  /** Details removed because they weren't in the plan's text. */
  ungrounded: number;
  /** Labels dropped for breaking the label rules or adding words. */
  rejectedLabels: number;
}

/** Numbers, percents, ratios, and capitalised words: they must be copied, never made up. */
function tokens(text: string, skipFirst: boolean): string[] {
  return text.split(/[ ,.()]+/).filter(Boolean).filter((word, index) => {
    if (skipFirst && index === 0) return false;
    return /\d/.test(word) || (index > 0 && /^[A-Z]/.test(word));
  });
}

/**
 * A label is valid when it starts with a verb, is one action of at most 6
 * words, has no "Step N:", and every number, ratio, and capitalised word in
 * it and its detail appears in the source line exactly. Same rule as
 * StepLabeler.isValid in the app.
 */
export function isValidLabel(label: string, detail: string | null, source: string): boolean {
  const words = label.trim().split(/\s+/);
  if (words.length === 0 || words.length > MAX_LABEL_WORDS) return false;
  if (!VERBS.has(words[0].toLowerCase())) return false;
  if (/^\s*step\s*\d/i.test(label) || label.includes(". ")) return false;
  // A detail is the plan's words, copied: it must appear in the line as written.
  if (detail && !normalize(source).includes(normalize(detail))) return false;
  return [...tokens(label, true), ...tokens(detail ?? "", false)].every((token) => source.includes(token));
}

/** Which details a parent would expect for each kind. Missing ones are flagged. */
const EXPECTED: Record<Kind, Detail[]> = {
  supplement: ["dose", "frequency"],
  medication: ["dose", "frequency"],
  topicalStep: ["frequency"],
  bath: ["frequency"],
  routineStep: [],
  foodRule: [],
  fundamental: [],
  followUp: [],
};

/** Lowercase, straight quotes and hyphens, single spaces: so layout differences don't matter. */
export function normalize(text: string): string {
  return text
    .toLowerCase()
    .replace(/[‘’ʼ]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[‐-―−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Splits text marked with "--- Page N ---" lines into pages (1-based).
 * Text without markers is one page.
 */
export function pages(source: string): Map<number, string> {
  const result = new Map<number, string>();
  const parts = source.split(/^--- Page (\d+) ---$/m);
  if (parts.length === 1) {
    result.set(1, normalize(source));
    return result;
  }
  for (let i = 1; i < parts.length; i += 2) {
    result.set(Number(parts[i]), normalize(parts[i + 1] ?? ""));
  }
  return result;
}

function clean(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** Keeps only what's grounded in the plan's text. */
export function check(raw: RawItem[], source: string): Checked {
  const byPage = pages(source);
  const whole = normalize(source);
  const items: Item[] = [];
  let dropped = 0;
  let ungrounded = 0;
  let rejectedLabels = 0;

  for (const r of raw) {
    const kind = typeof r.kind === "string" && (KINDS as readonly string[]).includes(r.kind) ? r.kind as Kind : null;
    const line = clean(r.source_line);
    if (!kind || !line) {
      dropped++;
      continue;
    }
    // The quoted line must really be in the plan: on its page if it has one, else anywhere.
    const claimed = typeof r.source_page === "number" ? byPage.get(r.source_page) : undefined;
    const found = claimed?.includes(normalize(line)) ? r.source_page as number
      : [...byPage.entries()].find(([, text]) => text.includes(normalize(line)))?.[0];
    if (found === undefined) {
      dropped++;
      continue;
    }
    const pageText = byPage.get(found) ?? whole;

    // The item's words: kept if they're in the plan, otherwise the quoted line itself.
    const said = clean(r.text);
    const text = said && pageText.includes(normalize(said)) ? said : line;

    const details = {} as Record<Detail, string | null>;
    for (const detail of DETAILS) {
      const value = clean(r[detail]);
      if (value && !pageText.includes(normalize(value))) ungrounded++;
      details[detail] = value && pageText.includes(normalize(value)) ? value : null;
    }

    // A proposed label stays only if it follows the rules and adds nothing.
    let label = clean(r.label);
    let detail = clean(r.detail);
    if (label && !isValidLabel(label, detail, line)) {
      rejectedLabels++;
      label = null;
      detail = null;
    }
    if (!label) detail = null;
    const category = typeof r.category === "string" && (CATEGORIES as readonly string[]).includes(r.category)
      ? r.category as Category
      : null;

    const proposed = clean(r.plain);
    const plain = proposed && isFaithful(proposed, line) ? proposed : null;

    items.push({
      kind,
      text,
      ...details,
      source_page: found,
      source_line: line,
      label,
      detail,
      category,
      plain,
      // Only items that give some of the expected details can be missing one:
      // a rule like "rotate after 3 weeks" has no dose to miss. Same rule as
      // PlanItemInfo.blanks.
      blanks: EXPECTED[kind].some((detail) => details[detail] !== null)
        ? EXPECTED[kind].filter((detail) => details[detail] === null)
        : [],
    });
  }
  return { items, dropped, ungrounded, rejectedLabels };
}
