---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Use when the user says "diagnose"/"debug this", or reports something broken/throwing/failing/slow.
---

# Diagnosing Bugs

A reusable diagnosis workflow. Adapt investigation and validation to the repository's documented conventions and available tools.

For diagnosis-only requests, investigate and explain without editing source or configuration. For fix requests, continue through repair and validation. Keep failure diagnosis and decisions in the main session.

Read the repository's relevant domain and testing guidance before judging business behavior or choosing validation. Use available testing, browser, or orchestration skills when those operations are needed; otherwise follow the repository's documented tools directly. Do not assume a particular stack or running host.

## Redact

This skill has you show commands, outputs and captured artifacts. **Redact every secret first**: write `<REDACTED>` in its place. Build loops against env vars, so the credential stays in the environment rather than in what you show. Captured artifacts carry auth headers: quote only the lines that carry the signal.

If the redacted output is not enough to diagnose the bug, say so and ask the user.

## Phase 1 — Build a feedback loop

A focused pass/fail signal helps distinguish causes and verify a repair. Build one when needed; direct source and log evidence may be sufficient for a diagnosis without an executable reproduction.

Start with bounded source, configuration, and log inspection. Choose a signal that distinguishes plausible causes. A direct exception or configuration mismatch may need only a focused check; intermittent or cross-boundary failures may require a replay or harness.

If this evidence establishes the cause, skip reproduction, hypothesis ranking, and instrumentation that would add no useful confidence. For diagnosis-only requests, report the cause, evidence, uncertainty, and recommended repair now. For repair requests, proceed to Phase 5 with validation appropriate to the change. Use the intervening phases when competing explanations or missing evidence require them.

### Ways to construct one — try them in roughly this order

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) — drives the UI, asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** For input-dependent failures, use bounded generated inputs with a recorded seed in an isolated environment.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **Human-assisted reproduction.** Request a specific inaccessible interaction and the minimum non-secret result needed to continue.

Record the command or interaction and its observed result.

### Tighten the loop

Treat the loop as a product. Once you have _a_ loop, **tighten** it:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

Prefer repeatability and speed appropriate to the boundary. Database and browser setup may take longer than a unit test.

### Non-deterministic bugs

Record attempts and failures. Vary one factor at a time and use bounded repetitions in an isolated environment; do not stress shared state without task-specific authorization.

### When execution is unavailable

Continue safe source and log inspection. Distinguish established conclusions from hypotheses. Request missing access or evidence only when it prevents further useful diagnosis. An unrun reproduction is not a verified cause or repair.

### Completion criterion

For a reproduction, record the command or interaction already run, its output, and how it detects the user's exact symptom. For an evidence-only diagnosis, cite the failing path and supporting observations, and identify remaining uncertainty.

## Phase 2 — Reproduce + minimise

When a reproduction is available, run it and confirm the actual symptom. For an evidence-only diagnosis, continue to evaluate the available evidence without pretending these execution checks passed.

Confirm:

- [ ] The loop produces the failure mode the **user** described — not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

### Minimise

Once it's red, shrink the repro to the **smallest scenario that still goes red**. Cut inputs, callers, config, data, and steps **one at a time**, re-running the loop after each cut — keep only what's load-bearing for the failure.

Why bother: a minimal repro shrinks the hypothesis space in Phase 3 (fewer moving parts left to suspect) and becomes the clean regression test in Phase 5.

Minimize when it helps distinguish causes or produces a useful regression case. Keep enough of the original scenario to exercise the actual failure.

## Phase 3 — Hypothesise

Rank the plausible causes supported by evidence. Consider alternatives when competing explanations remain; do not invent hypotheses to satisfy a fixed count.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

Share the leading hypotheses when the update helps the user contribute missing context or understand a substantial investigation. Continue safe checks without a mandatory approval checkpoint.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses, only when source changes are authorized. For diagnosis-only requests, use existing logs or read-only inspection.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

## Phase 5 — Fix + regression test

For a diagnosis-only request, report the cause, evidence, uncertainty, and recommended repair here. Continue below only when repair is requested.

Write a failing regression test before the fix when its cost is justified by repository testing guidance and it exercises the real failure.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

If no suitable automated seam is available, record the coverage gap and validate with the original scenario. Test difficulty alone does not justify an architecture change.

If a suitable regression test is justified:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario.

## Phase 6 — Cleanup + post-mortem

Required before declaring a repair complete:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] State the established cause and validation in the handoff. Commit only when already authorized.
- [ ] Refresh affected running services and verify readiness when required by the repository's validation workflow. Preserve pre-existing shared services; clean up task-owned temporary instances.

Recommend follow-up architecture work only when evidence demonstrates a recurring problem outside the repair's scope. Record that work separately rather than expanding the fix.
