---
name: second-opinion
description: Package the current discussion into a self-contained brief for a second opinion from another person or AI.
argument-hint: "What should the reviewer focus on?"
disable-model-invocation: true
---

Write a brief that lets a reviewer who has not seen this conversation give an independent second opinion. The reviewer has no access to the conversation, the repository, or your tools: the brief is everything they get.

## Contents

- **Question**: the decision or problem to weigh in on, in one or two sentences at the top. Arguments the user passed name the focus.
- **Context**: what the reviewer needs to understand the question.
- **Constraints and decisions**: requirements and fixed choices, each with its reason.
- **Assumptions**: labelled as assumptions, so the reviewer can challenge them.
- **Options**: steelman each one, including those the discussion leaned against; say what was tried or ruled out, and why.
- **Evidence**: paste the code, API contracts, error output, versions, and configuration the question turns on. Paste the content itself; the reviewer cannot open a path.
- **Questions**: every question asked in the discussion, copied verbatim.

Keep the brief unanchored: present the options neutrally and leave out your own recommendation unless the user asks for it, so the reviewer's view stays independent.

Redact secrets and personal data; the brief is meant to leave this machine.

## Output

Save the brief as Markdown where the repository's agent guidance puts scratch or handoff documents; if it names none, use `.scratch/handoffs/`. Reply with the file's path, and say so when git would track it.

## Done when

A reader holding only the brief could answer its Question without asking you anything: every term, constraint, and piece of evidence the answer depends on is in it.
