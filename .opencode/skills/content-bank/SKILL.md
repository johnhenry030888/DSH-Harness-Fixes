---
name: content-bank
description: Educational content pipeline - topic packs, question-bank schemas, memo rubrics, and verification before seeding.
compatibility: agent-only educational projects with lessons, quizzes, or drills (opencode + dsh)
metadata:
  role: content
  version: 1
---

# Content Bank (teachable content, verified)

Content is data with a rubric. Nothing seeds docs/domain.md or the database
until its schema and memo rules exist. One topic pack per loop.

## Loop per topic pack

1. Pack: topic scope, learning goals, vocabulary list, core explanations.
   Keep packs small; one pack seeds one verifiable slice.
2. Question bank: schema first (stem, options, answer, marks, illustrasie
   where visual). Every question carries marks and exactly one answer.
3. Memo rubric: per-question memo text plus acceptance rules (partial marks,
   alternative phrasings). No memo, no ship.
4. Verify: every answer re-checked against the pack explanations; spelling
   per project gate; figures follow preview -> look -> validate -> vision_qa.
5. Seed through the domain-modeling loop (never direct production writes).
6. Commit task-scoped with the pack name; update STATE.md.

## CAPS overlay (on demand only)

- Load caps-ingest + figure-forge ONLY when paper search, doc conversion,
  ATP packs, or figure generation is in scope (about 23 niche tools).
- Otherwise leave the overlay unloaded (prompt-tax rule); this playbook
  works standalone on plain topic packs.
- Never attach binary blobs; quote transcribed or extracted text instead.

## Routing (never reassign)

- Content verification belongs here; code quality belongs to
  linter-formatter; visual critique belongs to opendesign + ui gates.
- Artifacts under content/ or docs/, never the server dir.

## Stop conditions

- Answer key disputed or memo ambiguous: stop and ask (product decision).
- Source material missing for a claimed fact: do not invent; report the gap.
