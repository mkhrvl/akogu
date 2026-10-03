---
name: implement
description: Use when implementing an approved plan or a directly scoped code change.
disable-model-invocation: true
---

Implement the approved plan. For small work without a plan, implement the user's direct requirements.

Use [testing](../testing/SKILL.md) for repository test conventions, test design, and focused validation. Complete its validation criteria before review.

After validation, use [code-review](../code-review/SKILL.md) when a standards and requirements review could catch a meaningful defect. Review the actual working changes, including relevant untracked files. Skip independent review for pure mechanical changes.

Leave changes uncommitted unless the user's request already authorizes committing.
