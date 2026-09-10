# Lessons learned

Twenty-two things that went wrong, or turned out to be true, while building the reference
implementation: 328 atomic entries, 81 source summaries and 12 topic hubs over 17 sessions in a
corporate-career-coaching domain. Every rule elsewhere in this kit that looks arbitrary is here,
with the failure that produced it.

Each lesson reads the same way: **symptom**, **why**, **what to do**. Numbers come from the
reference implementation; its domain is not yours, but the failures are domain-independent. See
[01-architecture.md](01-architecture.md) for the shape of the system,
[02-ingestion-protocol.md](02-ingestion-protocol.md) for the phases, and
[08-sourcing-content.md](08-sourcing-content.md) for the triage routine several lessons feed into.

---

## Context and session discipline

### 1. Context collapse

**Symptom.** A session reads sources, extracts ideas, writes pages — and then dies. The entries are
on disk, but `index.md` has no rows for them, the log has no entry, and no hub mentions them.

**Why.** Reading raw sources and writing pages are the two most token-expensive activities, and
integration comes last. One agent doing read plus extract plus write plus integrate spends its
whole window before reaching the cheapest and most important step.

**What to do.** Keep the orchestrator/specialist split: the librarian never reads a raw source and
never re-reads a file it caused to be written; extraction happens in throwaway sub-agent contexts
that return text; writers receive finished content in their prompt and read nothing. If you are
about to open a raw source in the main session, spawn an extractor instead.

### 2. Phase 5 is the fragile one

**Symptom.** Ingest looks successful, but weeks later a search returns an entry no page links to,
and the log's last entry is two batches old.

**Why.** Integration gets skipped when context runs low, because everything before it feels like
the real work. A skipped ingest costs nothing; a skipped integration leaves orphans nobody knows
about.

**What to do.** Treat Phase 5 as the deliverable, not the tidy-up: run it immediately after
verification, in the same session. Never start a second batch in one session even when context
looks plentiful — the second batch is what eats the first one's integration budget.

### 3. Shortest first

**Symptom.** Three sessions in, the backlog has barely moved and every remaining source is
intimidating.

**Why.** Long sources consume context out of proportion to the entries they yield, and a batch is
capped by its longest member. Start with dense material and the easy majority never clears.

**What to do.** Sort the queue ascending by word count and take from the front. Use
[`scripts/unprocessed.sh`](../scripts/unprocessed.sh) at the start of every ingest session, then
set batch size from the tier table in [02-ingestion-protocol.md](02-ingestion-protocol.md).

### 4. Verify structurally, not semantically

**Symptom.** A verification pass that "reads the new entries to check they are good" burns the
remaining context and still misses the real defect: a file that was never written at all.

**Why.** Silent write failures are structural — missing file, empty file, absent frontmatter,
wrong count. Prose quality was already decided in Phase 2. Re-judging it competes with Phase 5.

**What to do.** Verify with cheap shell checks: files exist, are non-empty, contain a `title:`
line, and the count matches what Phase 2 approved. On failure re-run the writer rather than patching
by hand. Quality review belongs in Phase 2 and in the periodic lint pass
([06-operations.md](06-operations.md)).

---

## Entry quality and duplication

### 5. Duplicate detection happens before creation, not after

**Symptom.** The wiki accumulates near-identical entries with different slugs; searches return
three pages that say the same thing with different examples.

**Why.** An extractor that has not seen the existing catalogue has no way to know the idea is
already there, and creating a new page is always the path of least resistance.

**What to do.** Every extractor reads `wiki/index.md` before proposing anything, and returns two
buckets: new entries, and reinforcements. A reinforcement adds a source to an existing page's
frontmatter and a line to the source summary — it does not create a page.

### 6. Do not merge unrelated near-duplicates

**Symptom.** Three thin ideas each overlap something that already exists, so merging them into one
new page looks efficient. The result has no single core idea and nothing links to it cleanly.

**Why.** Thin ideas overlap *different* existing entries, not each other. Merging buys tidy
arithmetic (three in, one out) at the cost of atomicity, which everything else depends on.

**What to do.** Handle each thin idea separately: reinforce the entry it overlaps, or drop it and
note it in the source summary. In the reference implementation a source offering seven one-sentence
tensions produced four entries; the other three reinforced three different existing pages, and the
merge was considered and explicitly rejected in the log.

### 7. Log the reasoning, not just the result

**Symptom.** A later session re-litigates a decision you already made — recreating an entry you
deliberately dropped, or re-proposing a merge you rejected.

**Why.** `log.md` written as a list of outputs records what exists. It does not record what was
considered and refused, so that judgement is lost the moment the session ends.

**What to do.** In each ingest log entry, record the batch tier and why, the entries dropped and
what they were reinforcing instead, merges considered and rejected, and any tension flagged. See
[`examples/example-log-entry.md`](../examples/example-log-entry.md) for a real one with the
reasoning intact.

### 8. Flag tensions, do not resolve them

**Symptom.** Two sources genuinely disagree. The tidy instinct is to write one entry that
reconciles them.

**Why.** Reconciliation adds an opinion the sources do not support and destroys the more useful
fact: credible people disagree here. At query time that disagreement is what you want to see.

**What to do.** Keep both entries live, cross-link them in `related:`, and note the tension in the
log and in the topic hub prose. The reference implementation keeps "learning rate substitutes for
talent" and "talent gates outcomes" as two live, unresolved entries.

---

## Source hygiene and triage

### 9. Broken web captures: the marker alone means nothing

**Symptom.** Clipped articles contain a note about cross-origin iframes that failed to load. It
looks like the capture is broken.

**Why.** Clippers emit that note when they cannot inline embedded images, videos or widgets; the
prose is usually intact. A genuinely broken capture got the page shell and none of the body.

**What to do.** In the reference corpus 41 files carried the marker and all were fine — the
shortest, at 437 words, still had its full argument. The two genuinely broken files had under 200
words each. The reliable stub signal is **low word count plus the marker**, not the marker alone.
Screen by word count first; only then look for the marker. Commands in
[08-sourcing-content.md](08-sourcing-content.md).

### 10. Index pages are not sources

**Symptom.** An extractor returns vague, generic entries from a file that is technically about your
domain, and the extraction has no quotable substance.

**Why.** Blog rolls, author archives, search-result pages and awesome-list READMEs are lists of
links with one teaser sentence each. There is no argument to extract, and forcing entries out of
them produces exactly the thin, unsupported pages atomicity exists to prevent.

**What to do.** Triage them into a sibling folder before Phase 1 — the reference implementation
moved eight out. Revisit only if the articles they point to get captured properly. Do not delete
them; they are a shopping list.

### 11. Oversized books are not sources either

**Symptom.** One file, 230,000 words. The extractor cannot read it in one context, and if it could,
one source summary for a whole book would be useless.

**Why.** The unit of ingestion is one source, one summary page, a handful of entries; a book breaks
that by two orders of magnitude. Scraped ebook files also bundle: in the reference corpus one file
held six books and another sixteen.

**What to do.** Move them out of the normal queue into their own folder and treat each as a project
— split at chapter boundaries, then ingest the chapters as ordinary sources over several sessions.
Splitting commands are in [08-sourcing-content.md](08-sourcing-content.md).

### 12. Sweep for exact duplicates before you ingest anything

**Symptom.** Two source summaries describing the same article, or the same file appearing twice in
a batch with `(1)` appended.

**Why.** Web clippers and repeated scrapes produce byte-identical copies with different names, and
nothing in the pipeline notices. The reference implementation found 15 byte-identical duplicates
late — after several of them had already been through ingest.

**What to do.** Checksum the whole backlog before the first ingest and again whenever you add a
batch of captures. One command, in [08-sourcing-content.md](08-sourcing-content.md).

### 13. Filename hygiene is provenance

**Symptom.** Three distinct problems with one root: files named `page-2026-05-03.md` that you
cannot identify; files the Read tool refuses to open; and tooling that silently points at a
directory that does not exist.

**Why.** Timestamped names carry no provenance, and the filename is recorded in every source
summary's `source_file:` field, so renaming after ingest breaks that link. Curly apostrophes (`’`,
U+2019) defeat path matching in the Read tool. Spaces in directory names get split by argument
parsers: the reference implementation's `original content/` was parsed as `original` plus a dropped
positional argument, so the search collection pointed at a non-existent path and indexed nothing.

**What to do.** Rename on arrival, never after ingest. Strip curly apostrophes and spaces from
filenames, and use space-free directory names — this is why the kit defaults to `raw/` and
`raw-processed/` rather than the reference implementation's spaced names. To read a file that
already has a curly apostrophe, go through the shell rather than the Read tool:

```sh
find "$PROJECT_ROOT/raw" -name "*keyword*" -print0 | xargs -0 cat
```

### 14. One file extension for everything

**Symptom.** The search index reports far fewer files than the folder contains, with no error.

**Why.** Mixed `.txt` and `.md` in one folder, plus a `--pattern` flag that did not work: qmd
v2.5.2 accepted and stored the flag but indexed `**/*.md` regardless, so everything else was
invisible.

**What to do.** Normalise every source to `.md` on arrival and let the default pattern work. The
reference implementation renamed 54 `.txt` files late and then had to update `source_file:` in 43
already-written source summaries — an avoidable second pass. Changing an extension does not count as
modifying an original.

---

## Tooling and indexing

### 15. The search index is machine-local

**Symptom.** You clone the repo on a second machine, run a search, and get nothing — or results
pointing at paths from the first machine.

**Why.** The index lives outside the project (`~/.cache/qmd/` for qmd), is not committed, and bakes
in absolute paths. It is derived data, not content.

**What to do.** Rebuild the index per machine as a documented setup step, not as a surprise. Budget
for the embedding model download (~318 MB on first use) and for embedding time (10–20 minutes for a
few hundred files on Apple Silicon). Full procedure in
[04-search-setup-qmd.md](04-search-setup-qmd.md).

### 16. Hardcoded absolute paths rot

**Symptom.** Sub-agent instruction files still name a working directory the project left months ago.
Nothing errors; the agents use relative paths and the stale line misleads every human who reads it.

**Why.** Absolute paths written once into agent prompts are never revisited, and repositories move
between machines and cloud folders.

**What to do.** Name the project root in exactly one place (`CLAUDE.md`, from the
`{{PROJECT_ROOT}}` token at setup) and use paths relative to it everywhere else. If a script needs
the root, take it from an environment variable or `git rev-parse --show-toplevel`, and quote it.

### 17. The wiki is a git repo

**Symptom.** A bad formatting pass rewrites 40 entry bodies and you cannot tell what changed.

**Why.** Agents edit in bulk. Without version history you have no diff, no revert, and no record of
when an idea entered the wiki.

**What to do.** Commit `wiki/`, `.claude/` (including `settings.json` and `handover.md`), and the
raw sources. Ignore the processed-sources folder and OS cruft. Commit at the end of every session,
after Phase 5 — the log entry makes an excellent commit message.

---

## Structure and linking

### 18. Frontmatter drift

**Symptom.** A query that filters on a field returns half the pages it should. Some entries say
`source:`, others `sources:`.

**Why.** Field names get re-derived from memory by every agent that writes a page. Singular and
plural are equally plausible, so both appear. The reference implementation still carries this scar:
its entries use `source:` while the kit standardises on `sources:`.

**What to do.** Fix one spelling per field in [03-page-schemas.md](03-page-schemas.md), have the
writer templates carry it verbatim, and have the verifier grep for it. Fix drift the moment you see
it, across all pages at once, not opportunistically.

### 19. Wikilinks must resolve

**Symptom.** The graph view ([05-foam-vscode-setup.md](05-foam-vscode-setup.md)) shows a halo of
ghost nodes, and clicking a link offers to create the file.

**Why.** Agents invent plausible slugs. Asked to relate an entry to "psychological safety", a model
will write `[[psychological-safety]]` whether or not that page exists.

**What to do.** Two hard constraints, both already in the agent templates: the extractor may only
propose links to slugs that appear in `index.md`, and the formatter may only use slugs from the
page's own `related:` frontmatter. Catch the rest with
[`scripts/lint-wiki.sh`](../scripts/lint-wiki.sh), which reports unresolved links.

### 20. Topic hubs need prose

**Symptom.** A hub page is a bulleted list of wikilinks. It duplicates the index and nobody opens
it twice.

**Why.** Appending a bullet is the cheapest possible integration, so it is what happens unless the
rule says otherwise.

**What to do.** A hub is an argument that walks a reader through the topic, with entries wired into
sentences under `##` sections. Every Phase 5 must place new entries into that argument, not append
them to a list. See [`examples/example-topic-hub.md`](../examples/example-topic-hub.md). If you
cannot write a sentence that positions a new entry, that is a signal the hub is the wrong home for
it.

### 21. A nested `CLAUDE.md` must override explicitly

**Symptom.** You open a session inside `wiki/` to ask a question, and the agent starts proposing an
ingest batch.

**Why.** Claude Code loads the root `CLAUDE.md` as well as the nested one. The librarian
instructions are still in context, and they are more specific and more actionable than a vague
"answer questions" role.

**What to do.** Open the nested file with a loud, explicit override: state that the root librarian
role does not apply here, that this session ingests nothing and writes nothing outside the wiki,
and what the consuming persona does instead. See
[`templates/wiki-CLAUDE.md.template`](../templates/wiki-CLAUDE.md.template).

---

## Before your first batch

### 22. Pilot with one source

**Symptom.** You batch ten sources against a schema you designed in the abstract, and discover
afterwards that the entry noun is wrong for your domain, or the tag vocabulary is unusable, or
source summaries need a field you did not define.

**Why.** Schemas look correct until real content is poured through them. Domain fit is only visible
in output.

**What to do.** Run one source end to end through all five phases, read the resulting pages
yourself, and tune the tokens and schemas before batching. The cost of getting this wrong scales
with the number of pages already written. The pilot ingest is a step in
[`SETUP.md`](../SETUP.md); do not skip it because setup "went fine".

---

## What you will hit first in a brand-new instance

Roughly in the order they arrive:

| When | Lessons |
| --- | --- |
| Setup, before any content | 22 (pilot), 13 (filenames), 14 (one extension), 15 (index is machine-local) |
| First triage of the backlog | 12 (checksum sweep), 9 (broken captures), 10 (index pages), 11 (oversized books) |
| First real batch | 3 (shortest first), 5 (duplicate detection), 18 (frontmatter drift), 19 (wikilinks) |
| Second and third sessions | 2 (Phase 5 discipline), 6 (do not merge), 7 (log the reasoning), 17 (commit) |
| Once the wiki passes ~50 entries | 1 (context collapse), 4 (structural verification), 20 (hub prose), 8 (tensions) |
| First time you query rather than ingest | 21 (nested role override) |

The two that cost the reference implementation the most time were 12 and 14: a checksum sweep and a
bulk rename that each take five minutes before the first ingest, and hours of rework afterwards.
Do both on day one.
