# LLM wiki starter kit

## What this is

A kit for standing up an **LLM-maintained wiki**: a knowledge base that an agent writes and keeps
current for you, instead of a folder of documents you re-read every time you have a question.

Raw sources go in one side — articles, interview notes, transcripts, papers, PDFs. An orchestrating
Claude agent (the "librarian") plus four specialist sub-agents read each source and compile it into
three kinds of interlinked markdown page:

- **Atomic entries** — one idea per file, tagged, with provenance back to every source that argued it.
- **Topic hubs** — thematic pages that walk you through a cluster of entries as an argument, not a list.
- **Source summaries** — one page per ingested source, so nothing loses its origin.

Two tools sit on top: a local search engine (qmd — on-device hybrid keyword and vector search) and a
wikilink editor with a graph view (VS Code + Foam, or Obsidian). You curate sources, approve the
agent's plan, and ask questions; the agent does the reading, cross-referencing and bookkeeping.

The difference from ordinary RAG is that the knowledge is **compiled once and then maintained**,
rather than re-derived on every query, so each new source strengthens what is already there. The
pattern is described in `reference/llm-wiki.md`; this implementation's shape is in
`docs/01-architecture.md`.

Two things to be clear about before you start:

- **It is domain-neutral.** Nothing in the system assumes a subject. Clinical research, case law,
  a fantasy series, competitor intelligence, your own journals — the schemas adapt to whatever you
  point them at.
- **Setup is done by your Claude, not by hand.** You do not edit templates, create directories or
  write config files. You open Claude Code, tell it to read `SETUP.md`, answer its questions about
  your domain, and approve what it proposes.

## Prerequisites

| Requirement | Why | Notes |
| --- | --- | --- |
| Claude Code | Runs the setup and every ingest afterwards | The agent is the system |
| Node.js 18 or later | The search engine installs via npm | `brew install node`, or nodejs.org |
| git | The wiki is a git repo; version history of a knowledge base is worth having | Any recent version |
| VS Code + Foam extension | Wikilinks, backlinks, graph view, tag browser | Optional; Obsidian works instead |

macOS or Linux is assumed throughout. On Windows, run the whole thing inside WSL, or expect to
adapt the shell snippets in `scripts/` and `docs/` yourself.

## Quickstart

Three steps.

```sh
# 1. Put the kit where the project should live, and name it after your project
cp -R llm-wiki-starter-kit ~/Documents/GitHub/MyWiki
cd ~/Documents/GitHub/MyWiki

# 2. Open Claude Code in that folder
claude

# 3. Say exactly this:
#    Read SETUP.md and set this system up for me.
```

`SETUP.md` is the entry point for **the agent**. This README is the entry point for **you**. You do
not need to read `SETUP.md` yourself — it is written as instructions to Claude, and it will ask you
everything it needs, including a short interview about your domain that decides folder names, page
schemas and the starting tag vocabulary.

## What is in the box

```text
llm-wiki-starter-kit/
├── README.md                              # this file — human entry point
├── SETUP.md                               # the setup procedure, addressed to your agent
├── .gitignore                             # the kit's own ignores
├── docs/
│   ├── 01-architecture.md                 # the three layers, and why a compiled wiki beats query-time RAG
│   ├── 02-ingestion-protocol.md           # the five ingestion phases in operational detail
│   ├── 03-page-schemas.md                 # frontmatter and body standards for all four page types
│   ├── 04-search-setup-qmd.md             # search engine: install, collections, commands, troubleshooting
│   ├── 05-foam-vscode-setup.md            # VS Code + Foam (and Obsidian as the alternative)
│   ├── 06-operations.md                   # running it day to day: ingest, query, lint, handover
│   ├── 07-lessons-learned.md              # failures and fixes from 17 sessions of real use
│   └── 08-sourcing-content.md             # getting raw material in, and triaging what is not worth ingesting
├── templates/
│   ├── CLAUDE.md.template                 # the librarian schema that governs the project root
│   ├── wiki-CLAUDE.md.template            # nested role override so queries do not trigger ingestion
│   ├── settings.json.template             # Claude Code settings, including the search MCP server
│   ├── handover.md.template               # session state file the agent updates at every close
│   ├── gitignore.template                 # the project's own .gitignore
│   ├── agents/
│   │   ├── wiki-extractor.md.template     # phase 1 specialist — reads a source, proposes entries
│   │   ├── wiki-writer.md.template        # phase 3 specialist — writes files verbatim
│   │   ├── wiki-formatter.md.template     # phase 3.5 specialist — enforces the body standard
│   │   ├── wiki-verifier.md.template      # phase 4 specialist — structural checks, not prose review
│   │   └── domain-expert.md.template      # query-time persona that answers from the wiki
│   ├── commands/
│   │   └── end-session.md.template        # the /end-session close-down ritual
│   ├── wiki/
│   │   ├── index.md.template              # seed master catalogue
│   │   └── log.md.template                # seed append-only log
│   └── pages/
│       ├── entry.md.template              # atomic entry skeleton
│       ├── topic-hub.md.template          # topic hub skeleton
│       └── source-summary.md.template     # source summary skeleton
├── scripts/
│   ├── scaffold.sh                        # creates the project skeleton
│   ├── unprocessed.sh                     # lists unprocessed sources by word count, shortest first
│   └── lint-wiki.sh                       # wiki health check
├── examples/
│   ├── README.md                          # what each example shows, and the domain warning
│   ├── example-entry.md                   # a mature atomic entry
│   ├── example-topic-hub.md               # a mature topic hub
│   ├── example-source-summary.md          # a mature source summary
│   ├── example-index.md                   # an excerpt of a master index at scale
│   └── example-log-entry.md               # a real log entry, including quality-review reasoning
└── reference/
    └── llm-wiki.md                        # the original pattern write-up this kit implements
```

That is the layout before setup. Step 3c of `SETUP.md` moves `docs/`, `examples/`, `reference/` and
`templates/` under `resources/`, so in a set-up project the same files sit one level deeper — if a
path in this file does not resolve, look for it under `resources/`.

Every template ends in `.template` on purpose: a file literally named `CLAUDE.md` or `agents/*.md`
inside the kit would be auto-loaded by Claude Code and pollute your session. The agent strips the
suffix and fills in placeholder tokens such as `{{DOMAIN}}` when it instantiates each one.

## What to expect, honestly

| Step | Rough time |
| --- | --- |
| Setup conversation — domain interview, instantiating templates, review | 20–40 minutes |
| Installing Node.js and the search engine | 5–15 minutes |
| First embedding pass — downloads a ~318 MB model, then indexes | 10–20 minutes on Apple Silicon |
| VS Code + Foam, or Obsidian | about 5 minutes |
| Pilot ingest of one source, end to end | 20–30 minutes |

Budget half a day, most of it waiting on downloads and answering questions. Everything except the
Claude Code session itself runs on your machine: no API keys, no subscriptions, no data leaving the
laptop for search or embeddings.

Two expectations worth setting:

- **The first real value appears after the pilot ingest, not after setup.** Setup produces empty
  folders and a schema. Only once one source has been through all five phases can you judge whether
  the entry granularity suits your domain — which is why the pilot exists, and why tuning the schema
  afterwards is normal rather than a sign something went wrong.
- **The wiki stays thin until roughly 20 to 30 sources.** It compounds: the value is in the
  cross-references, and cross-references need something to point at.

## Where to read next

| File | When to read it |
| --- | --- |
| `SETUP.md` | You do not — hand it to your agent. Read it only if setup goes wrong |
| `docs/01-architecture.md` | Before you commit to this pattern, or when deciding it does not fit |
| `docs/02-ingestion-protocol.md` | Before your first real ingest batch, and whenever a batch misbehaves |
| `docs/03-page-schemas.md` | When you want to change what a page looks like, or a field name |
| `docs/04-search-setup-qmd.md` | Installing search, moving to a new machine, or search returns nothing |
| `docs/05-foam-vscode-setup.md` | Setting up the editor, or when wikilinks and the graph do not resolve |
| `docs/06-operations.md` | Your day-to-day reference: session start, query, lint, session close |
| `docs/07-lessons-learned.md` | Read it once early. Re-read whenever something breaks — most failures are in here |
| `docs/08-sourcing-content.md` | When filling the raw folder, or deciding whether a source is worth ingesting |
| `examples/README.md` | When you want to see the target quality before writing your own schema |
| `reference/llm-wiki.md` | For the underlying idea, independent of this implementation |

Those are kit paths. After step 3c of `SETUP.md` the same files sit under `resources/` — read
`resources/docs/06-operations.md`, `resources/examples/README.md`, and so on.

## Provenance and credit

This kit implements the pattern described in `reference/llm-wiki.md`, an intentionally abstract
write-up of the LLM-maintained wiki idea. The kit is one concrete, opinionated instantiation of it.

It is distilled from a production instance built over **17 working sessions**, which holds **328
atomic entries, 81 source summaries and 12 topic hubs**. Everything prescriptive here — the
five-phase protocol, the orchestrator plus four specialists, the batch-size tiers, the naming rules
— exists because the simpler version of it failed in practice. `docs/07-lessons-learned.md` records
those failures.

The files in `examples/` are **real pages from that instance**, not invented samples. Its subject is
corporate-career coaching, which is almost certainly not your domain. They are kept anyway because
they show the quality bar: entry granularity, how frontmatter is used, how a hub reads as an
argument, how a log entry captures reasoning. Read them for shape and standard; ignore the subject
matter. `examples/README.md` says what to look at in each.

The search engine is [qmd](https://github.com/tobi/qmd), and Foam is a third-party VS Code
extension. Both are independent projects, used here as-is.
