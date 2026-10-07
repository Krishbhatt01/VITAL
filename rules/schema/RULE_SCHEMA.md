# VITAL requirement-record schema

One JSON file per requirement **sub-paragraph**. A section's verdict is the worst of its sub-paragraphs. `vital.io.validateRule` enforces this schema; `vital.io.sampleRule` returns a valid EXAMPLE (placeholder numbers, not a real requirement).

| Field | Type | Required | Meaning |
|---|---|---|---|
| id | string | yes | unique, e.g. `MIL-F-8785C-3.2.2.1.1-L1-CatA` |
| title | string | yes | short description |
| ruleset | object | yes | `{name, revision, basis}`, e.g. MIL-F-8785C, 5 Nov 1980 |
| class | enum | yes | Q-SPEC (numeric criterion in a specification), Q-CFR, Q-STD (licensed standard), Q-PROXY (qualitative rule with a quantitative proxy), PILOT, ANALYSIS-SUPPORT, OUT-OF-SIM, DEFINITION (produces a quantity for other rules) |
| source | object | yes | `{document, paragraph, page}`, all required and non-empty. Optional: transcribed_by, verified. **No record may enter VITAL without a full citation.** |
| applicability | object | yes | e.g. aircraft class (I–IV), flight-phase category (A/B/C) |
| metric | string | yes | name of the metric extractor, e.g. `short_period_damping_ratio` |
| criterion | object | yes | `type: "levels"` with `levels[]` entries `{level 1/2/3, category, min?, max?}` (min < max, at least one bound), or `type: "threshold"` with `{op: >= <= > <, limit}` |
| scale | number > 0 | yes | margin normalization: m = (y − L)/scale (sign chosen so m > 0 satisfies the criterion) |
| conditions | object | yes | condition-space axes and search method |
| status_policy | object | yes | handling of INFEASIBLE / NOT_CONVERGED / OUT_OF_DATA_ENVELOPE. No status other than OK can improve a verdict |

Errors: `vital:rule:missingField` (absent or empty required field, including any citation field) and `vital:rule:badValue` (illegal enum, non-positive scale, min ≥ max, bad operator, non-finite limit).
