# Architecture

This document explains the shape of the system and why it is shaped that way. Nothing here is a
step you perform: for the procedure, read [02-ingestion-protocol.md](02-ingestion-protocol.md);
for standing the thing up, read [../SETUP.md](../SETUP.md). The pattern this implements is
described in the original write-up at [../reference/llm-wiki.md](../reference/llm-wiki.md).

## The three layers

| Layer | Owner | Where it lives | The one rule |
| --- | --- | --- | --- |
| Raw sources | You | `raw/` | Immutable. The agent reads, never edits. |
| The wiki | The agent | `wiki/` | You read it; the agent writes it. |
| The schema | You and the agent, jointly | `CLAUDE.md`, `.claude/` | It is what makes the agent a librarian rather than a chatbot. |

**Raw sources** are your curated pile of material: articles, transcripts, papers, notes, exported
threads. They are the source of truth, and they are immutable — not as a nicety but because
provenance depends on it. Every wiki entry names the source file it came from. Edit or reformat a
source after ingestion and every citation pointing at it quietly becomes a claim you can no longer
check. Getting material into this folder, naming it sanely and triaging what is not worth ingesting
is covered in [08-sourcing-content.md](08-sourcing-content.md).

**The wiki** is generated markdown, and the agent owns all of it. It holds three page types —
atomic entries, thematic topic hubs, source summaries — plus two bookkeeping files, `index.md`
(a catalogue of every page) and `log.md` (an append-at-top chronological record). The schemas for
all of these are in [03-page-schemas.md](03-page-schemas.md). You are of course allowed to fix a
typo, but the normal route for a change is to tell the agent, because a change you make by hand is
a change the index and the log do not know about.

**The schema** is the configuration layer, and it is the part most people underestimate. It is the
root `CLAUDE.md` (the librarian's role, conventions and protocol), the four specialist definitions
in `.claude/agents/`, the nested `wiki/CLAUDE.md` that switches the agent into a consuming expert
when you are asking questions rather than ingesting, the `/end-session` command, and
`.claude/handover.md` — the written state that lets session 18 know what session 17 decided. All of
these ship as templates under `../templates/`. You will rewrite parts of this layer in your first
month; that is expected, and it is the main reason the pilot ingest in `../SETUP.md` exists.

## Why compile the wiki instead of retrieving at query time

The default way to point an LLM at a document collection is retrieval at query time: index the
files, pull the relevant chunks when a question arrives, generate an answer. That works, and it
requires no curation. What it does not do is accumulate. Every question starts from the raw pile
again, and the connection the model noticed last Tuesday is gone.

| | Query-time retrieval | Compiled wiki |
| --- | --- | --- |
| Cost per question | Low, constant | Low, constant |
| Cost per source | Near zero | High: a human-gated ingest |
| Cross-references | Re-derived per question, if at all | Already written, and stable |
| Contradictions between sources | Usually invisible | Explicitly flagged on the pages |
| Answer quality on synthesis questions | Limited by what the retriever happens to fetch | Reflects everything ingested so far |
| Value over time | Flat | Compounds |
| Auditability | Chunks, out of context | Named entries with named sources |

Three things you get from compiling, concretely:

- **Knowledge accumulates.** The fifth source about a topic arrives into a structure that already
  holds the first four. It reinforces existing entries as often as it creates new ones, and the
  reinforcement is recorded rather than discarded.
- **The hard work is already done.** Cross-references between entries, and the places where two
  authorities genuinely disagree, are resolved once at ingest time by an agent that has both
  sources in front of it — not improvised at query time from two retrieved fragments.
- **Synthesis reflects the whole corpus.** A topic hub is an argument written across everything
  read so far. No retriever gives you that, because no retriever has read everything.

And honestly, what it costs:

- **Ingestion is slow.** A batch is a session. Expect a session per five medium-length sources,
  and expect it to occupy a meaningful share of a context window. Eighty sources is not an
  afternoon.
- **It needs you in the loop.** Phase 2 is a human approval gate by design. The agent proposes
  entries, drops and merges; you accept or overrule. Skip that gate habitually and the wiki fills
  with near-duplicates and thin entries, at which point it is worse than the raw pile.
- **Early decisions propagate.** Your entry noun, your tag vocabulary and your atomicity rule get
  baked into hundreds of pages. Changing them later is a migration.
- **It is not a replacement for search.** The wiki is a better thing to search than the raw pile,
  not a reason to stop searching. A local search engine sits on top of it —
  see [04-search-setup-qmd.md](04-search-setup-qmd.md).

## The directory layout

`../scripts/scaffold.sh` creates this skeleton. The names shown are the kit defaults; the comments
name the setup placeholder that controls each one, so you can see which are configurable.

```text
PROJECT_ROOT/
├── raw/                       # immutable sources ({{SOURCE_DIR}}) — you add, agent reads
├── raw-processed/             # sources already ingested ({{PROCESSED_DIR}}) — gitignored
├── wiki/                      # the generated wiki — the agent owns everything here
│   ├── CLAUDE.md              # role override: consuming expert, not librarian
│   ├── index.md               # master catalogue, updated on every ingest
│   ├── log.md                 # append-at-top record of ingests, queries, lint passes
│   ├── concepts/              # atomic entries ({{ENTRY_DIR}}) — one idea per file
│   ├── topics/                # thematic hubs — narrative, not link lists
│   └── sources/               # one summary per ingested source
├── .claude/
│   ├── agents/                # the four ingestion specialists + the query-time expert
│   ├── commands/              # end-session.md
│   ├── settings.json          # search MCP server config
│   └── handover.md            # session state and next-batch suggestion
├── scripts/                   # unprocessed.sh, lint-wiki.sh
├── CLAUDE.md                  # the librarian schema — loaded automatically at session start
└── .gitignore
```

| Directory | Its job | Committed? |
| --- | --- | --- |
| `raw/` | Holding pen for material not yet ingested. Everything in it is by definition unprocessed. | Yes, if licensing allows |
| `raw-processed/` | Where a source moves the moment its summary page exists. Keeps `raw/` an accurate to-do list. | No |
| `wiki/concepts/` | The atomic units. One idea per file, self-contained, citing its sources. | Yes |
| `wiki/topics/` | The navigation surface once the wiki is large. Prose that walks a reader through a theme. | Yes |
| `wiki/sources/` | Provenance. One page per source: what it covered, what it produced, what it reinforced. | Yes |
| `.claude/` | The schema layer and the session state. Version this — it is the most valuable directory in the repo. | Yes |
| `scripts/` | Small helpers so the agent shells out instead of reasoning about `find` flags. | Yes |

Triage folders sit alongside `raw/` for material you have decided not to ingest — link-index pages,
oversized books. Create them when you first need one;
[08-sourcing-content.md](08-sourcing-content.md) explains what belongs there and why leaving that
material in `raw/` is corrosive.

## The orchestrator and the four specialists

The first version of the reference implementation had one agent doing everything: read the source,
extract the ideas, write the files, then update the index, the log and the topic hubs. It failed
the same way every time. Reading and writing consumed the context window, and the run ended at the
integration step — entries on disk, nothing pointing at them, nothing logged. That is strictly
worse than not having ingested at all, because the next session cannot tell it happened. This is
lesson 1 in [07-lessons-learned.md](07-lessons-learned.md), and it is the reason for everything
below.

The fix is a division of labour with deliberately narrow roles and deliberately narrow tool grants.

| Role | Reads | Writes | Never |
| --- | --- | --- | --- |
| Orchestrator (main agent) | `index.md`, `log.md`, hubs, `handover.md`, extraction text | Shared state only: index, log, hubs, handover | Reads a source; writes an entry; re-reads a file it caused to be written |
| `wiki-extractor` | One source, plus `index.md` | Nothing | Writes any file |
| `wiki-writer` | Nothing | Exactly the files handed to it, verbatim | Reads a source; invents or improves content |
| `wiki-formatter` | Freshly written entry files | The same files, in place | Touches frontmatter, facts, or source summaries |
| `wiki-verifier` | File metadata via shell | Nothing | Judges prose quality |

Three consequences worth stating plainly, because they look like arbitrary bureaucracy until you
have watched the failure they prevent:

1. **Only the orchestrator touches shared state.** `index.md`, `log.md`, the topic hubs and
   `handover.md` are single-writer files. Two parallel agents editing the index produce a corrupt
   index, and every one of them thinks it succeeded.
2. **The orchestrator never re-reads what it had written.** Verification is structural — does the
   file exist, is it non-empty, does it have the required frontmatter fields — and it is delegated
   to `wiki-verifier`. Re-reading prose to satisfy yourself that it is good burns exactly the
   context that integration needs, and integration is the step that must not be skipped.
3. **One specialist per unit of work, running in parallel.** Each extractor holds one source in
   its context and nothing else, which is both faster and less prone to cross-contamination
   between sources than one agent reading five.

The four specialist definitions live in `../templates/agents/`. The query-time counterpart, which
reads the finished wiki and answers questions from it, is `../templates/agents/domain-expert.md.template`;
day-to-day use of it is covered in [06-operations.md](06-operations.md).

## How the system behaves as it grows

The mechanics do not change with scale, but what you rely on for navigation does.

| Scale | Navigation you actually use | Topic hubs | Search | What breaks if you ignore it |
| --- | --- | --- | --- | --- |
| ~10 entries, 3–5 sources | `index.md`, read top to bottom | None yet, or one | Optional | Nothing. Resist creating hubs before clusters exist. |
| ~100 entries, 25–30 sources | `index.md` as a lookup, not a read | 6–10, each genuinely load-bearing | Necessary | Duplicate detection by scanning titles starts failing; tag vocabulary sprawls |
| 300+ entries, 80+ sources | Topic hubs | 12 or more, some ready to split | Necessary, plus embeddings | Hubs decay into link lists; the index becomes unreadable and the extractor stops trusting it |

What changes at each step:

- **Early (tens of entries).** The index alone is sufficient — the extractor reads it in full and
  duplicate detection is reliable. Your job is to get the schema right, not to build structure.
  Pilot one source end to end and tune the schemas before batching.
- **Middle (around a hundred).** The index no longer fits a comfortable reading pass, and this is
  where a search engine stops being optional: the extractor needs to find near-duplicates it
  cannot see by title. This is also when the first tag audit pays for itself, and when hubs start
  to earn their place because the index has too many rows to skim.
- **Late (several hundred).** Topic hubs become the real interface — the index degenerates into a
  lookup table and nobody reads it linearly, including the agent. The ratio shifts: most new
  sources reinforce existing entries rather than adding new ones, which is a sign of health, not
  of a weak source. Periodic lint passes (orphan entries, hubs with no new prose, contradictions
  left unflagged) become the maintenance work that keeps it usable. Expect to split at least one
  hub that has grown into two arguments.

The reference implementation this kit was distilled from reached 328 entries, 81 source summaries
and 12 topic hubs over 17 sessions, with no change to the protocol along the way. The protocol
scales; the navigation habits are what you adapt.

## When not to use this pattern

Be honest with yourself before you invest. This pattern is a poor fit when:

- **You have one question and one afternoon.** Attach the files to a chat and ask. Compiling a
  wiki to answer a single question is pure overhead.
- **The corpus churns.** If your documents are superseded weekly, the wiki is stale as fast as it
  is written, and the re-compilation cost exceeds the benefit. Search over the live documents.
- **You need verbatim fidelity.** A wiki entry is a synthesis in the agent's words. For legal,
  contractual or quotation-exact work, keep working from the sources; use the wiki at most as an
  index into them.
- **The material is structured data.** Numbers, time series and tabular records belong in a
  database or a spreadsheet, not in prose entries.
- **You will not do Phase 2.** The human approval gate is what keeps quality from decaying. If you
  know you will rubber-stamp every batch, you will end up curating a mess instead of a pile, which
  is not an improvement.
- **You have thousands of files and no intention of curating them.** Ingestion cost is per source
  and human-gated. At that volume, triage first and ingest the tenth you actually care about.

## Where to go next

Read [02-ingestion-protocol.md](02-ingestion-protocol.md) next: it turns the division of labour
above into an operational procedure. [../README.md](../README.md) has the full map of the other
documents.
