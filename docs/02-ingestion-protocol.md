# Ingestion protocol

Ingestion is the operation that turns raw sources into wiki pages. It runs in five phases, always
the same five, in the same order, once per session. This document is the operational reference:
who runs each phase, what it receives, what it returns, and when it is finished.

Why the work is split across an orchestrator and four specialists at all is explained in
[01-architecture.md](01-architecture.md). What the resulting pages must look like is in
[03-page-schemas.md](03-page-schemas.md).

## The five phases at a glance

| Phase | Owner | What happens |
| --- | --- | --- |
| 1 Extraction | `wiki-extractor` × N in parallel, one per source | Reads one source plus `wiki/index.md`; returns a structured extraction as text. Writes nothing. |
| 2 Quality review | Main agent (librarian) | Checks duplicates, atomicity, link accuracy, drops and merges; presents a verdict to you for approval. |
| 3 Writing | `wiki-writer` × N in parallel, one per 2–3 sources | Receives exact file content in its prompt and writes it verbatim. Reads nothing. |
| 3.5 Formatting | `wiki-formatter` × N in parallel, one per 5–7 entries | Reads freshly written entry files and reformats bodies to the house standard. Entries only, never source summaries. |
| 4 Verification | `wiki-verifier` × 1 | Shell checks: files exist, are non-empty, required frontmatter present, counts match. |
| 5 Integration | Main agent — cannot be delegated | Update `index.md`, prepend to `log.md`, update topic hubs, move originals, update `handover.md`, re-index search. |

Never merge phases. Never skip one. Never reorder them. The half-numbered phase is a historical
artefact: formatting was added to a protocol that already had four phases. Keep the numbering as it
is, because every agent definition, log entry and handover in the system refers to these numbers.

## Before the batch: sizing

Everything in `raw/` is unprocessed by definition — a source moves to `raw-processed/` the moment
its summary page exists (Phase 5, step 4). So sizing the backlog is just measuring `raw/`.

```sh
"$PROJECT_ROOT/scripts/unprocessed.sh"
```

That prints the unprocessed sources ascending by word count. The equivalent one-liner, if you want
it inline:

```sh
wc -w "$PROJECT_ROOT"/raw/*.md | sort -n | head -20
```

Take the batch from the top of that list. Shortest first is not an aesthetic preference: short
sources clear the backlog fast, and they cost little context, which means the dense material later
gets a session with room in it.

| Source length | Max batch |
| --- | --- |
| Short (< ~1,500 words) | 10 sources |
| Medium (~1,500–4,000 words) | 5–7 sources |
| Long (> ~4,000 words) | 3–4 sources |

A batch that mixes lengths uses the tier of its **longest** source. Four short sources plus one
6,000-word essay is a long-tier batch, so cap it at four total, not ten. Record the tier you chose
in the log entry, so the next session can see whether the sizing worked.

## Phase 1 — Extraction

| Aspect | Detail |
| --- | --- |
| Runs it | `wiki-extractor`, one instance per source, all dispatched in parallel |
| Receives | The source filename. Nothing else. |
| Returns | A structured extraction as text: source metadata, proposed new entries with slug, title, tags, related links and body, a list of existing entries this source reinforces, and a draft source summary |
| Done when | Every extractor in the batch has returned. Wait for all of them before starting Phase 2. |

The extractor reads `wiki/index.md` itself — do not paste the index into its prompt, and do not
summarise the wiki for it. That self-service read is what makes duplicate detection work.

Two failure modes to expect. Filenames containing curly apostrophes cannot be opened by the Read
tool; the extractor should fall back to `find` piped through `xargs -0 cat`. Sources over roughly
30 KB blow the shell output limit, so the extractor should query them through the search engine
instead of dumping them. Both are covered in [07-lessons-learned.md](07-lessons-learned.md).

## Phase 2 — Quality review

This is the gate. The main agent applies the checklist below to every proposed entry, then presents
a verdict for your approval. It is the only phase where a human decision is required, and it is the
phase that determines whether the wiki stays worth reading.

| Check | Accept if | Otherwise |
| --- | --- | --- |
| **Atomic** | The entry states exactly one idea, per your atomicity rule | Split it into two entries, or drop the weaker half |
| **Not already present** | No row in `index.md` covers this idea, under any wording | Convert to a reinforcement of the existing entry |
| **Worth a new page** | It adds a mechanism, distinction or claim the existing entries do not have | Reinforce instead — a thin restatement is a liability |
| **Links resolve** | Every slug in `related:` exists in `index.md` today | Delete the invented links; do not create stub pages to satisfy them |
| **Self-contained** | The body makes sense to a reader who has never seen the source | Send it back for a rewrite, or drop it |
| **Tags consistent** | Tags come from the established vocabulary, singular and hyphenated | Map them onto existing tags; add a new tag only deliberately |

Three judgement calls that come up in almost every batch:

- **Do not merge unrelated near-duplicates.** If three thin proposals each overlap a *different*
  existing entry, they are three separate reinforcements. Merging them into one new page produces a
  grab-bag that satisfies no one and violates atomicity.
- **Flag tensions, do not resolve them.** When two sources genuinely disagree, keep both entries
  live and note the disagreement on both. A wiki that silently picks a winner has destroyed
  information you cannot recover.
- **Record the reasoning, not just the outcome.** Every drop, every rejected merge, every tension
  flagged goes into the Phase 5 log entry. Without it, a future session re-litigates the same
  decision and reaches a different answer. See
  [../examples/example-log-entry.md](../examples/example-log-entry.md) for what that looks like
  written out.

The verdict you approve should be a table — one row per source, showing proposed new entries,
reinforcements, and anything dropped with the reason — plus the batch tier and the resulting totals.
**Done when you have said yes.** Silence is not approval; a batch does not proceed on an assumption.

## Phase 3 — Writing

| Aspect | Detail |
| --- | --- |
| Runs it | `wiki-writer`, one instance per 2–3 sources, in parallel |
| Receives | The complete, final text of every file it is to write, plus each exact path. Content only — no instructions to read, look up or improve anything. |
| Returns | A list of files written, and any errors |
| Done when | Every writer has reported, and every file in the approved batch is accounted for by exactly one writer |

The writer is a hand, not a brain. It reads nothing, generates nothing and improves nothing; if the
content in its prompt is wrong, it writes the wrong thing faithfully, which is the behaviour you
want, because the alternative is silent divergence from what you approved. Both entry files and
source summaries are written here. Make sure no two writers are given the same path.

## Phase 3.5 — Formatting

| Aspect | Detail |
| --- | --- |
| Runs it | `wiki-formatter`, one instance per 5–7 entries, in parallel |
| Receives | A list of entry file paths. Nothing else. |
| Returns | Per file: reformatted, minor fixes, or left unchanged |
| Done when | Every entry written in this batch has been through a formatter |

The formatter normalises body shape to the house standard — opening sentence that leads with the
idea, bold terms and bullets and tables only where the content genuinely has that shape, and the
closing related-entries section. It must not touch frontmatter, must not change a factual claim,
and must not run over source summaries: those have their own body format and reformatting them to
the entry standard corrupts them. It may only use slugs already present in the page's own `related:`
frontmatter — that constraint is what stops plausible-looking invented links from appearing.

## Phase 4 — Verification

| Aspect | Detail |
| --- | --- |
| Runs it | `wiki-verifier`, exactly one instance |
| Receives | The list of expected new files, and the expected totals for entries and sources |
| Returns | A report: expected versus found, files under 10 lines, frontmatter field presence, directory counts, and a PASS or FAIL verdict |
| Done when | The verdict is PASS |

Verification is structural, not semantic. It answers "did the write happen" using `ls`, `wc -l` and
`grep '^title:'` — it does not read prose to judge quality, because quality was settled in Phase 2
and re-reading it now burns the context Phase 5 needs. On FAIL, fix and re-verify before going
anywhere near Phase 5.

## Phase 5 — Integration

Integration is where the batch becomes part of the wiki. It cannot be delegated: these are
single-writer shared files, and a second agent editing them concurrently produces a corrupt index
that reports success. Work through all six steps in order.

1. **`wiki/index.md`** — add one row per new entry and one row per new source summary, in the
   correct table, each with its one-line description. Update the meta counts at the top.
2. **`wiki/log.md`** — prepend a new entry at the top, headed
   `## [YYYY-MM-DD] ingest | <description>`. Include the batch tier, every source with what it
   produced, every drop with its reason, every tension flagged, and the before-and-after counts.
3. **Topic hubs** — add the new entries to the `entries:` and `sources:` frontmatter *and* wire
   them into the hub's prose. A hub that gains a wikilink but no sentence has gained nothing over
   the index. If a cluster of five or more new entries has no home, create a new hub.
4. **Move the originals** — every ingested source moves from `raw/` to `raw-processed/`, so that
   `raw/` remains an accurate to-do list.
5. **`.claude/handover.md`** — rewrite it: what this session did, current counts, and a concrete
   suggested next batch with word counts. This is the only thing the next session can rely on.
6. **Re-index search** — run the update command so the new pages are findable, and run the
   embedding step if the search tool reports pending vectors. See
   [04-search-setup-qmd.md](04-search-setup-qmd.md).

Done when all six are complete. If you are running low on context, do Phase 5 anyway and abandon
anything else — the `/end-session` ritual in [06-operations.md](06-operations.md) exists partly to
catch a half-finished integration and shout about it.

## Failure handling

Re-run the smallest failed unit. Never restart a whole batch because one file failed.

| Symptom | What it means | What to do |
| --- | --- | --- |
| Verifier reports a file missing, writer reported success | The writer dropped a file from a long list | Re-run one writer with only the missing files' content. Do not re-run the whole phase. |
| Verifier reports a file under 10 lines | Truncated write, or an entry with an empty body | Re-run the writer for that one file with the approved content. If the content itself is thin, drop the entry and remove it from the batch list. |
| Verifier reports a missing frontmatter field | Field-name drift, e.g. `source:` where the schema says `sources:` | Fix the field in place, then align the schema doc and the agent template so it cannot recur |
| Verifier FAIL after two attempts | Something structural is wrong — bad path, missing directory | Stop. Diagnose by hand. Do not proceed to Phase 5 on a FAIL. |
| An extraction is unusable: off-topic, garbled, or full of invented slugs | The source is unsuitable, or the extractor lost the thread | Drop that source from the batch and continue with the rest. Log why. Re-run a single extractor only if you think the source is fine. |
| An extraction returns zero new entries | Often correct, and not a failure | Still write the source summary, still record the reinforcements, still move the original. A processed source with no entries is processed. |
| A source turns out to be a stub | Broken web capture. The reliable signal is low word count *plus* a capture-failure marker — under ~200 words. The marker alone is not enough. | Write a source summary recording that the capture failed, produce no entries, move the original. Consider re-capturing it later. |
| A source turns out to be a link index or an oversized book | Not a source at all: a blog roll, a search-results page, or a 200,000-word ebook | Move it to a triage folder, not to `raw-processed/`, and note it in the log. See [08-sourcing-content.md](08-sourcing-content.md). |
| A formatter added a link that does not exist | It invented a slug rather than using the page's `related:` frontmatter | Remove the link. Re-run the formatter for that file with the constraint restated. |
| Context is running low mid-batch | The batch was too large for its tier | Finish the entries already written, integrate them in Phase 5, and put the remaining sources back at the top of the next batch in the handover. Never carry an unintegrated batch across a session boundary. |

## The three hard rules

1. **One batch per session.** Not two small ones. The second batch is always the one whose
   integration gets skipped.
2. **Phase 5 completes before the session ends.** A skipped integration is worse than a skipped
   ingest: the pages exist, nothing points at them, and no record says they happened.
3. **The main agent never re-reads what it had written.** Structural verification is delegated to
   `wiki-verifier`; formatting questions go to `wiki-formatter`. Reading it back "just to check"
   spends the context that Phase 5 requires.

## Worked walkthrough

**Illustrative only.** The example below is an invented project — `TransitOS`, a wiki about urban
mobility policy — with invented sources and counts, to show the shape of a real session. Nothing in
it is real data.

**Session start.** The agent runs the search-index status check, reads `wiki/index.md` and the last
few log entries, and reads `.claude/handover.md`, which suggests a batch of consultation responses.
Current state: 94 entries, 22 sources, 5 topic hubs.

**Sizing.** `scripts/unprocessed.sh` returns, ascending:

```text
 1180  raw/kerbside-pricing-review.md
 1640  raw/bus-lane-enforcement-evaluation.md
 2210  raw/modal-shift-after-congestion-charge.md
 2890  raw/school-street-closure-trial.md
 3400  raw/cycle-network-density-thresholds.md
 9750  raw/national-mobility-strategy-2029.md
```

The longest of the first five is 3,400 words, so this is a medium-tier batch: take five, and leave
the 9,750-word strategy document for a long-tier session of its own.

**Phase 1.** Five `wiki-extractor` agents are dispatched in parallel, each given one filename. All
five return. Between them they propose 14 new entries and 9 reinforcements.

**Phase 2.** The main agent applies the checklist and presents this verdict:

| Source | New entries | Reinforces | Dropped |
| --- | --- | --- | --- |
| kerbside-pricing-review | 2 | 1 | — |
| bus-lane-enforcement-evaluation | 3 | 2 | — |
| modal-shift-after-congestion-charge | 2 | 3 | 2 — near-duplicates of existing entries, reinforced instead |
| school-street-closure-trial | 0 | 1 | 1 — thin restatement of an existing entry |
| cycle-network-density-thresholds | 4 | 2 | — |

Two notes go with it. One dropped pair overlapped two *different* existing entries, so they were
recorded as separate reinforcements rather than merged into one new page. And one new entry
contradicts an existing one on whether enforcement or pricing drives compliance faster; both are
kept live, with the tension noted on each. You approve, and ask for one slug to be renamed.

**Phase 3.** Two `wiki-writer` agents run in parallel: one gets the files for the first three
sources, the other the remaining two. Between them they write 11 entry files and 5 source
summaries. Both report success.

**Phase 3.5.** Two `wiki-formatter` agents run over the 11 entry files, six and five. Seven are
reformatted, four need only minor fixes. The source summaries are not sent to them.

**Phase 4.** One `wiki-verifier` receives the 16 expected paths and the expected totals — 105
entries, 27 sources. It reports 16 of 16 found, no file under 10 lines, frontmatter present on all,
directory counts matching. Verdict: PASS.

**Phase 5.** The main agent adds 11 entry rows and 5 source rows to `index.md` and updates the meta
counts; prepends a log entry recording the medium tier, the three drops with reasons, the rejected
merge and the flagged tension; updates three topic hubs, wiring the new entries into their prose,
and notes that the kerbside cluster is close to deserving a hub of its own; moves the five
originals to `raw-processed/`; rewrites `handover.md` naming the 9,750-word strategy document as
the next batch; and re-indexes search.

**Close.** The session ends with `/end-session`, which commits the wiki and `.claude/`. Elapsed:
roughly 70 minutes. One batch, five sources, integration complete.
