# Operations

Once the wiki exists, running it is three operations and two rituals. The operations are **ingest**
(turn raw sources into pages), **query** (actually use the thing), and **lint** (periodic health
check). The rituals are the session-start checklist and `/end-session`. Nothing else is required.

This doc uses `qmd` for the search binary and `concepts/` for the atomic-entry directory; substitute
your own choices for `{{SEARCH_CMD}}` and `{{ENTRY_DIR}}`.

## Session start

Every session, whatever you plan to do, in this order:

| Step | Command or action | What you are checking |
| --- | --- | --- |
| 1 | Open Claude Code at the project root | The root `CLAUDE.md` loads, so Claude is in the librarian role |
| 2 | Ask Claude to read `.claude/handover.md` | The single most important file. It tells you what the last session left half-done |
| 3 | `qmd status` | Index is present and both collections are there. A missing index means a new machine — see [04-search-setup-qmd.md](04-search-setup-qmd.md) |
| 4 | `qmd update` | Picks up files added or edited since last time. Seconds |
| 5 | Skim `wiki/index.md` | Current counts and what already exists |
| 6 | `grep "^## \[" wiki/log.md \| head -5` | The last five operations, in one line of output |
| 7 | Say which operation this session is | Ingest, query, or lint. Pick one |

Step 7 is not ceremony. Ingest and query are different roles with different instruction files, and
mixing them in one session is how you end up with a half-finished batch. A good handover plus a
clean `qmd status` takes about two minutes.

## Operation 1 — Ingest

Pick the batch, then run the five phases. Batch selection is mechanical: `bash
scripts/unprocessed.sh` lists everything in `raw/` with no matching page in `wiki/sources/`, sorted
by word count ascending, and you take the shortest N according to the tier table. Then Claude runs
Phase 1 (extraction) and stops for your approval, Phase 2 is the quality gate where you actually
make decisions, Phases 3–4 write and verify, and Phase 5 integrates. Your job as the human is two
moments: approving the Phase 2 verdict, and confirming Phase 5 finished. Everything else is the
agents' work.

The full procedure — inputs, outputs, batch tiers, the quality-gate criteria, the integration
checklist, and what to do when a phase fails — is [02-ingestion-protocol.md](02-ingestion-protocol.md).
Two rules bear repeating here because they are the ones people break: **one batch per session**, and
**Phase 5 before the session ends**. A medium-tier batch of five sources takes 45–90 minutes of
wall-clock time, most of it agents working while you wait.

## Operation 2 — Query

This is the payoff, and it is the operation people skip. A wiki nobody consults is a filing
exercise.

**Load the expert role, not the librarian role.** The librarian ingests; the expert answers. Two
ways in:

- Open Claude Code with the working directory inside `wiki/`. The nested `wiki/CLAUDE.md` overrides
  the root instructions and you are talking to your domain expert.
- Or stay at the project root and ask for the `domain-expert` sub-agent.

Then work like this:

1. **Give the real situation, not a keyword.** The expert is instructed to ask one or two
   clarifying questions when the question is underspecified. Answer them.
2. **Expect several searches, from different angles.** One question usually has three or four
   entrances. Claude should be running something closer to `qmd query "how do I get a hostile
   stakeholder to back a proposal"`, then the same situation from the influence angle, the
   communication angle, and the timing angle — not one lookup.
3. **Expect citations.** Answers must name the pages they came from as wikilinks, so you can open
   them in VS Code and read the source summary behind each claim. An answer with no citations is
   Claude answering from general knowledge, which is exactly what the wiki exists to prevent.
4. **Expect tensions to be surfaced, not resolved.** If two sources disagree, the honest answer
   says so and helps you choose.

### File good answers back into the wiki

This is the habit that makes the system compound rather than plateau. A genuinely good answer is
usually not in any single page — it is a synthesis Claude assembled across four or five of them, plus
your situation. That reasoning is new knowledge, and if you close the session it is gone.

When an answer is good enough that you would want it again, ask Claude to write it up as a new page
in the entry directory, following the schema in [03-page-schemas.md](03-page-schemas.md), with:

- `related:` listing the entries it synthesises;
- `sources:` listing the source summaries behind those entries, so provenance stays honest;
- a `synthesis` tag, so these pages are auditable as a group later — they are your reasoning, not a
  source's claim;
- the situation genericised. Strip names and specifics; keep the pattern.

Then append a `query`-type entry to `wiki/log.md` recording the question and the page it produced.
Over a year this is the difference between a wiki that reflects your reading and one that reflects
your thinking.

## Operation 3 — Lint

A periodic health check, half mechanical and half judgement.

The mechanical half is a script:

```sh
bash scripts/lint-wiki.sh
bash scripts/lint-wiki.sh --help
```

It checks the things that are decidable without reading for meaning: broken wikilinks, missing or
misspelled frontmatter fields, pages absent from `index.md`, index rows pointing at files that do not
exist, and pages with no inbound links. Fix what it reports before moving on.

The judgement half needs Claude and the search index. Work through these in order and have Claude
write findings into `wiki/log.md` as a `lint` entry rather than fixing everything inline:

| Check | How to look | What to do about it |
| --- | --- | --- |
| Contradictions between pages | Search a theme, read the top pages side by side | If the sources genuinely disagree, keep both and note the tension explicitly on each page. Do not pick a winner |
| Superseded claims | Compare `date_ingested` on the sources behind pages that cover the same ground | Add a note; do not delete the older page |
| Orphans | The script lists pages with no inbound links | Wire each into a topic hub's argument, or into a `related:` list where it belongs |
| Entities with no page | Names, frameworks or terms repeatedly mentioned inside other pages but never defined | Promote to their own entry if a source supports them |
| Missing cross-references | Pages sharing 3+ tags but not linking each other | Add to `related:` and wire into prose |
| Tag sprawl | The tag-frequency command in [03-page-schemas.md](03-page-schemas.md) | Merge near-synonyms; promote any tag at 8–10 entries to a hub |
| Hubs that drifted into link lists | Read each hub top to bottom | Rewrite the argument so new entries are wired into sentences |
| Coverage gaps | Ask Claude which parts of each hub's argument the wiki cannot support | Becomes your sourcing shortlist — see [08-sourcing-content.md](08-sourcing-content.md) |

A lint pass is 30–60 minutes. Run one every four to six ingest sessions, or whenever roughly 50 new
entries have landed. Fix the cheap findings during the pass; schedule the expensive ones as their own
maintenance session.

## Handover discipline

The context window ends. The wiki survives, git survives, the search index survives — the only thing
that does not is *intent*: which batch you were mid-way through, why you dropped three entries, which
source turned out to be a blog roll, what you meant to do next. `.claude/handover.md` is where that
goes, and it is what makes a session boundary survivable instead of a restart.

Rules:

- **One file, overwritten every session.** Handover is current state, not history. History is
  `wiki/log.md`, which is append-only. Do not conflate them.
- **It opens with the immediate next task**, written as a specific sentence. "Ingest the four
  remaining medium-tier interview transcripts listed below" is useful; "continue ingesting" is not.
- **An incomplete Phase 5 goes at the very top, loudly.** Entries that exist but that nothing points
  at are worse than entries that were never written, because the next session will not know they are
  unwired unless the handover says so.
- **It records the counts** — entries, sources, topics, unprocessed sources. The next session
  compares against reality and catches silent losses.
- **It is committed to git**, so any machine you clone to picks it up.
- Stable reference material in it — conventions, filename gotchas, the key-files table — is copied
  forward verbatim rather than rewritten each time.

| File | Nature | Written by | Answers |
| --- | --- | --- | --- |
| `wiki/log.md` | Append-only, permanent | Phase 5 and `/end-session` | What happened, and why we decided it |
| `.claude/handover.md` | Overwritten, current | `/end-session` | Where we are and what is next |

## The /end-session ritual

`/end-session` is a slash command installed at `.claude/commands/end-session.md`
([../templates/commands/end-session.md.template](../templates/commands/end-session.md.template)). It
closes a session in one instruction, in this order:

1. `git status --short`, and flag incomplete work — an unfinished Phase 5 above everything else.
2. Count entries, topics, sources and unprocessed raw files.
3. Determine the session number from the last log entry.
4. `qmd update`, so the index matches the files you just wrote.
5. Prepend the session's entry to `wiki/log.md`.
6. Rewrite `.claude/handover.md` in full.
7. Commit everything with a descriptive message, then ask before pushing — never push from a
   detached HEAD or an unexpected branch.
8. Report the commit, the next task in one sentence, and whether `qmd embed` is now overdue.

Run it even after a fifteen-minute query session. It costs a minute or two; a lost handover costs
most of the next session. And never walk away from an uncommitted half-ingest — if you are out of
time mid-batch, stop and run `/end-session` so the incomplete state is recorded rather than
discovered later.

## Suggested cadence

For someone with an hour or two a week, this works:

| Rhythm | Session | Time |
| --- | --- | --- |
| Weekly | One ingest batch, shortest-first, Phase 5 completed | 60–90 min |
| As needed | Query sessions, whenever you have a real question | 10–20 min each |
| Every 4–6 ingests | Lint pass | 30–60 min |
| Every few weeks | Sourcing and triage — clip, dedupe, rename, triage out the non-sources | 20–30 min |

Consistency beats volume. The reference implementation reached 328 entries, 81 source summaries and
12 topic hubs across 17 sessions — roughly nineteen entries a session — and it became genuinely
useful to query long before it was finished, at around fifty entries. Do not batch two ingests into
one evening because you have time spare; the second one is where Phase 5 gets skipped. And do not let
the ingest cadence crowd out the querying: the wiki is not the deliverable, the answers are.
