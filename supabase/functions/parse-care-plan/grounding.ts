// Grounding (prompt 4.2): the model only extracts; this file makes sure of it.
// Every item must quote a line that is really in the plan, every detail
// (dose, frequency, timing, duration) must appear in the plan's text, and
// anything missing stays blank and is flagged. Nothing is ever filled in.

export const KINDS = [
  "routineStep", "topicalStep", "bath", "supplement", "medication", "foodRule", "fundamental", "followUp",
] as const;
export type Kind = typeof KINDS[number];

export const DETAILS = ["dose", "frequency", "timing", "duration"] as const;
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
  /** Details the plan left blank that a parent would expect: "Worth asking at your next visit." */
  blanks: Detail[];
}

export interface Checked {
  items: Item[];
  /** Items dropped because their source line isn't in the plan, or their kind is unknown. */
  dropped: number;
  /** Details removed because they weren't in the plan's text. */
  ungrounded: number;
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

    items.push({
      kind,
      text,
      ...details,
      source_page: found,
      source_line: line,
      // Only items that give some detail can be missing one: a rule like
      // "add one at a time" has no dose to miss. Same rule as PlanItemInfo.blanks.
      blanks: DETAILS.some((detail) => details[detail] !== null)
        ? EXPECTED[kind].filter((detail) => details[detail] === null)
        : [],
    });
  }
  return { items, dropped, ungrounded };
}
