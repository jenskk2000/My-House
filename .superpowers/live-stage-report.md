# Live stage-journey rehearsal

Run: 2026-09-14 (Monday), model `claude-sonnet-5`, real API key, real clock.
Suite: `KollektivTests/LiveJourneyTests`, run ONCE with `TEST_RUNNER_KOLLEKTIV_LIVE=1`.
Result: `** TEST SUCCEEDED **` — 6/6 tests passed (2 pre-existing journeys + 4 new stages).
Default (gated) suite also passes: `** TEST SUCCEEDED **`.

API request counting: not instrumented. `AgentClient`/`ClaudeAgentClient` has no request counter,
so each file records `task.attempts` (agent runs) instead; every stage used 1 attempt per send.

## Stage 1 — `stage_untaggedMessageDoesNothing` — PASS
File: `/tmp/kollektiv-live-stage1.txt`

House reply: none (correct — an untagged message never reaches the model; 0 API requests).

Store facts: `tasks: 0`, `house messages: 0`, `proposals: 0`,
attendance rows = only `2026-09-14: kristian=eating, sam=eating`.

## Stage 2 — `stage_cannotChangeSomeoneElsesAttendance` — PASS
File: `/tmp/kollektiv-live-stage2.txt`

House reply:
> I can only update dinner attendance for you, Kristian—not for Sam. If you'd like, I can mark you away for Saturday 19 September instead; Sam would need to set their own status.

Store facts: Saturday = 2026-09-19. `sam=nil`, `kristian=nil` on that date (House did not
"helpfully" mark the sender either). `proposals: 0`. Task state `completed` (refusal treated as
a normal reply, not a failure). Attendance rows unchanged: only today's seeded row.

## Stage 3 — `stage_occupiedSlotIsRefused` — PASS
File: `/tmp/kollektiv-live-stage3.txt`

House reply:
> Sam is already down to cook Pasta tonight (Monday 14 September), so I can't claim that slot for you — cooking slots can't be overwritten. If you meant a different night, let me know which date and I'll set you up.

Store facts: today's dinner unchanged — `cook=sam dish=Pasta time=19:00 revision=1`.
Reply names "Sam". Task state `completed`.

## Stage 4 — `stage_weekSummaryAndBinsQuestion` — PASS
File: `/tmp/kollektiv-live-stage4.txt`

House reply 1 ("@House what's happening this week?"):
> Tonight (Mon 14 Sept) Sam is cooking pasta at 19:00, with Kristian and Sam eating and Mia not answered yet. Tue–Sat has no cook planned yet, but Sunday 20 September Mia is doing a roast. Chores this week: Mia has Bins on Wednesday 16 September, you have Kitchen on Saturday 19 September, and Sam has Bathroom on Sunday 20 September; plus Board game night on Thursday 17 September at 20:00.

- Mentions "board game": yes (asserted).
- Mentions "landlord": NO. Recorded, not asserted — Landlord inspection is 2026-09-22, 8 days out,
  so leaving it out of "this week" is defensible.

House reply 2 ("@House who's on bins next Wednesday?"):
> Bins on Wednesday 23 September are assigned to you, Kristian.

Seed for the controller to judge: this Wednesday **2026-09-16 = Mia**; the following Wednesday
**2026-09-23 = Kristian**. The model read "next Wednesday" as the Wednesday of next week
(23 Sept → Kristian) rather than the upcoming one (16 Sept → Mia). Both dates and both
assignees are stated correctly for the date it chose, and reply 1 correctly put Mia on
Wednesday 16 September, so the data is right; only the "next Wednesday" disambiguation is a
judgement call. The test accepts either name by design.

Store facts: no mutation from either read-only question — `proposals: 0`, attendance rows
identical to the pre-call snapshot (only today's seeded row), all dinner cooks unchanged.
Both task states `completed`.

## Concerns

1. "next Wednesday" ambiguity (stage 4) is the only wording divergence worth a product decision:
   House answered for Wednesday 23 Sept (Kristian), not 16 Sept (Mia). No store risk.
2. No API-request instrumentation exists; if the controller wants per-test request counts, a
   counter on `ClaudeAgentClient` would have to be added.
3. Wording assertions ("sam", "board game") passed on the first run; no retries were needed, so
   no flakiness data was gathered.
