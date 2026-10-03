// Plain words: the provider's words at a 6th-grade reading level, for the
// parent's "What to do". They may change wording, never doses, ratios,
// brands, or conditions. Same checks as the app's PlainWords.isFaithful.

export const GRADE_LIMIT = 6;

/** Flesch-Kincaid grade level. */
export function grade(text: string): number {
  const words = text.split(/[^A-Za-z'’]+/).filter((w) => /[A-Za-z]/.test(w));
  if (words.length === 0) return 0;
  const sentences = Math.max(1, text.split(/[.!?]/).filter((s) => s.trim().length > 0).length);
  const syllables = words.map(syllableCount).reduce((a, b) => a + b, 0);
  return 0.39 * (words.length / sentences) + 11.8 * (syllables / words.length) - 15.59;
}

/** A vowel-group count with the usual English adjustments. */
export function syllableCount(word: string): number {
  const w = word.toLowerCase().replace(/[^a-z]/g, "");
  if (w.length === 0) return 0;
  if (w.length <= 3) return 1;
  let count = (w.match(/[aeiouy]+/g) ?? []).length;
  if (w.endsWith("e") && !w.endsWith("le") && count > 1) count--;
  if ((w.endsWith("es") || w.endsWith("ed")) && count > 1 && !w.endsWith("ted") && !w.endsWith("ded")) count--;
  return Math.max(1, count);
}

/** "2.5", "50:50", "96%", "5ml". */
function numbers(text: string): string[] {
  return text.match(/\d+(?:[.:/]\d+)?%?(?:ml|mg|g|oz)?/g) ?? [];
}

/** Capitalised words inside a sentence: brand and product names. */
function brands(text: string): string[] {
  const result: string[] = [];
  for (const sentence of text.split(/[.!?:]/)) {
    const words = sentence.trim().split(/\s+/).map((w) => w.replace(/^[^\w]+|[^\w]+$/g, ""));
    for (const word of words.slice(1)) {
      if (/^[A-Z]/.test(word) && word.length > 1 && word !== "I") result.push(word);
    }
  }
  return result;
}

/** Keeps a plain version only if it changes no number or brand and reads at grade 6 or easier. */
export function isFaithful(plain: string, source: string): boolean {
  const mine = new Set(numbers(plain));
  const theirs = new Set(numbers(source));
  if ([...theirs].some((n) => !mine.has(n)) || [...mine].some((n) => !theirs.has(n))) return false;
  const lower = plain.toLowerCase();
  if (brands(source).some((b) => !lower.includes(b.toLowerCase()))) return false;
  return grade(plain) <= GRADE_LIMIT;
}

export const PLAIN_SYSTEM = `You rewrite a child's care plan lines in plain words for a tired parent.

Rules:
- Write at a 6th-grade reading level or easier: short sentences, everyday words ("cream", not "topical").
- Keep every number, dose, ratio, percent, unit, brand, and product name exactly as written.
- Keep every condition ("if tolerated", "if it burns, wash it off"). Never drop a sentence's meaning.
- Never add advice, a number, a brand, or anything the line doesn't say.
- Say what to do, as steps if there are several.`;

export const PLAIN_TOOL = {
  name: "record_plain_words",
  description: "Record a plain-words version of each line, by its id.",
  input_schema: {
    type: "object",
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          properties: { id: { type: "string" }, plain: { type: "string" } },
          required: ["id", "plain"],
        },
      },
    },
    required: ["items"],
  },
} as const;
