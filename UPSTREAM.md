# Submitting to deepseek-harness upstream

Repo: https://github.com/deepseek-ai/deepseek-harness (MIT).

Current policy (CONTRIBUTING.md): NO external pull requests are accepted at the
moment, Issues are closed, and bug reports go through GitHub Discussions.
Community bug reports use a beetle-emoji `Bug:` title prefix. Example: Discussion #3540.

## How to submit this batch

1. File via the GraphQL API (proven: discussions #6074-6076) — no manual paste needed:
   `gh api graphql -F repo=R_kgDOT3T1gw -F cat=DIC_kwDOT3T1g84DDSUb -F title="..." -F body=@body.md`
   with `mutation($repo:ID!,$cat:ID!,$title:String!,$body:String!){createDiscussion(input:{repositoryId:$repo,categoryId:$cat,title:$title,body:$body}){discussion{number url}}}`.
   Category is General (no Bugs category exists). Note: `-F body=@file` works; `--input` conflicts with `-f`.
2. One discussion per bug (keeps review threads separate). Body: the bug folder
   UPSTREAM-DRAFT.md content. Title: `:bug: Bug: <short title>`.
3. State that a tested patch against a pinned version exists and offer the diff.
   Maintainers may ask for it pasted into the thread or placed elsewhere.
4. Record the discussion link in the bug UPSTREAM-DRAFT.md and root STATUS.md.
5. Upvote relevant discussions -- the team is small and prioritises by attention.

## If policy changes (PRs accepted later)

- Clone the repo, locate the source packages (published `repository.directory`
  fields name them, e.g. `packages/interaction/tool-ask-user`), port each
  `patches/*.patch` onto source, add/extend package tests, open one PR per bug
  referencing its discussion.
