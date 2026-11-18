---
name: second-opinion
description: Use when the user wants to get a second opinion on the current discussion, decision, design, or problem.
disable-model-invocation: true
---

# Second Opinion Handoff

Prepare a self-contained summary of the current discussion that the user can copy and give to another person or AI for a second opinion.

## Instructions

1. Identify the main question, decision, or problem being discussed.
2. Summarize the relevant context needed to understand it without access to the conversation.
3. Include important constraints, requirements, assumptions, and existing decisions.
4. Include the relevant approaches, options, or tradeoffs already considered.
5. Preserve concrete technical details when they matter, such as:
   - code snippets
   - API contracts
   - architecture or technology choices
   - errors or observed behavior
   - names, versions, and configuration
6. Clearly state what remains uncertain or what opinion is being requested.
7. If specific questions were asked in the discussion, include them in the handoff exactly as written. Do not paraphrase, rewrite, combine, or otherwise alter the questions.
8. Remove conversational filler, repetition, and unrelated details.
9. Do not solve the problem or give your own recommendation unless the user explicitly asks for it.

## Output

Produce a concise but sufficiently detailed handoff that stands on its own.

Prefer clear headings and bullets when they make the context easier to scan.

Save it as a Markdown file where the repository's agent guidance puts scratch or handoff documents; if it names none, use `.scratch/handoffs/`. Reply with the file's path, and say so when git would track it.

## Final Check

Before responding, verify that:

- someone who has not seen the conversation can understand the problem;
- the central question is explicit;
- relevant constraints and tradeoffs are preserved;
- no important context needed for a second opinion has been omitted.
