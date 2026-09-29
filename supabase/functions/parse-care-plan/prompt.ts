// The extraction instructions and the tool the model must answer with.

import { KINDS } from "./grounding.ts";

export const SYSTEM = `You extract a care plan that a child's provider wrote, so a parent can review it.

Rules:
- Only extract what the provider wrote. Never add, infer, guess, correct, or complete anything.
- Never suggest treatments, doses, foods, or timing. If a detail isn't written, leave it null.
- For every item, copy the exact line (or phrase) from the plan into source_line, character for character,
  and give its page number from the "--- Page N ---" markers.
- text is the item in the plan's own words, as short as the plan allows.
- dose, frequency, timing, duration: copy them only if the plan states them for that item, exactly as written.
- kind is one of: ${KINDS.join(", ")}.
  routineStep = a daily-routine step; topicalStep = something applied to the skin; bath = a bath;
  supplement; medication; foodRule = a food to avoid, rotate, or add as the plan says;
  fundamental = everyday basics (air, sleep, hydration, movement, bowel movements);
  followUp = visits, messages, tests, or reassessments.
- Rules such as "one at a time, 3 to 5 days apart" or "don't combine" are items too, quoted exactly.
- If the text isn't a care plan, return no items.`;

export const TOOL = {
  name: "record_plan_items",
  description: "Record every item the care plan states, each with its exact source line.",
  input_schema: {
    type: "object",
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          properties: {
            kind: { type: "string", enum: [...KINDS] },
            text: { type: "string" },
            dose: { type: ["string", "null"] },
            frequency: { type: ["string", "null"] },
            timing: { type: ["string", "null"] },
            duration: { type: ["string", "null"] },
            source_page: { type: "integer" },
            source_line: { type: "string" },
          },
          required: ["kind", "text", "dose", "frequency", "timing", "duration", "source_page", "source_line"],
        },
      },
    },
    required: ["items"],
  },
} as const;
