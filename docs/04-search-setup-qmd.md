# Search setup: qmd

qmd is an on-device search engine for folders of markdown. It combines BM25 keyword search,
vector similarity search and an LLM reranking pass, and it runs entirely on your machine — no
API calls, no data leaving the laptop, no per-query cost. Everything in this document was
verified against qmd 2.5.2 on Apple Silicon.

## Why the system wants it

Three jobs in the pipeline need retrieval that `grep` cannot do:

| Job | What it needs |
| --- | --- |
| Duplicate detection (Phase 1) | "Does an entry like this already exist?" — different words, same idea |
| Expert answers (query mode) | Pull the 5 most relevant entries out of 300+ on a question phrased in the asker's words |
| Sourcing checks | "Have I already ingested something on this?" across the raw folder |

Keyword search fails all three the moment vocabulary diverges. The reference implementation has
an entry called `nemawashi`; nobody searching for "getting buy-in before the meeting" will ever
type that word. Vector search finds it.

qmd is **optional**. See [Alternatives](#alternatives-you-may-not-need-qmd) at the end — under
about 100 entries a well-maintained `wiki/index.md` plus Claude's own Grep is genuinely enough.

## Install

Node.js 18 or later is the only prerequisite.

```sh
node --version
npm install -g @tobilu/qmd
qmd --version
```

Expect `qmd 2.5.2` or later. qmd is not a Homebrew formula — it is an npm global package. On a
machine where Homebrew provides Node, the binary lands at `/opt/homebrew/bin/qmd` as a symlink
into the npm global tree, which is normal. Confirm the shell can see it:

```sh
which qmd
```

## The two collections

A collection is a folder qmd indexes under a short name. This system uses exactly two.

| Collection | Folder | Contents | Churn |
| --- | --- | --- | --- |
| `raw` | `raw/` | Immutable source material — never edited | Grows in bursts, then goes quiet |
| `wiki` | `wiki/` | Generated entries, topic hubs, source summaries | Changes every session |

They stay separate for three reasons. Scoping: `-c wiki` lets the expert persona answer from the
compiled wiki only, while `-c raw` sends the extractor back to primary material — mixing them
pollutes both. Description: each gets its own context string (below), and the two bodies of text
want different ones. Churn: they re-index at different rates, so `qmd embed -c wiki` after a batch
avoids touching the much larger raw corpus.

Add them from the project root:

```sh
cd "$PROJECT_ROOT"
qmd collection add raw "$PROJECT_ROOT/raw"
qmd collection add wiki "$PROJECT_ROOT/wiki"
qmd collection list
```

In templates these folder names are the `{{SOURCE_DIR}}` and `wiki` paths; if you renamed the
raw folder during setup, use your name and keep the collection name identical to the folder name.

Two verified constraints, both of which shaped the kit's defaults:

- **`--pattern` does not work in 2.5.2.** `qmd collection add ... --pattern "**/*.txt"` reports
  success and then stores `**/*.md` anyway. Consequence: every file you want indexed must have a
  `.md` extension. See `07-lessons-learned.md`.
- **Spaces in the path break `collection add` silently.** Adding a collection whose path contains
  a space produced a collection pointing at a non-existent path, `0 files`, and a green success
  message. This is why the kit defaults to `raw/` and `raw-processed/` rather than the reference
  implementation's `original content/`.

## Contexts

A context is one or two sentences of human-written description attached to a collection. qmd
injects it into every result and hands it to the reranker, so it materially changes result
quality: it tells the model what kind of corpus it is scoring against. It is also printed above
each hit, which orients the agent reading the output.

The verified syntax takes a path and a string:

```sh
# Global — applies to every collection
qmd context add / "Knowledge base on <your domain>."

# Per collection, using the virtual path form
qmd context add "qmd://wiki/" "Compiled wiki: atomic entries, thematic topic hubs and source summaries, cross-referenced by wikilink."
qmd context add "qmd://raw/" "Raw, immutable source material — never modified. Primary text behind the wiki."

qmd context list
```

Use `{{DOMAIN_CONTEXT}}` from setup as the global string. Two discrepancies with the reference
implementation's own notes, both verified against the installed CLI: the three-argument form
`qmd context add wiki "/" "text"` is undocumented and prepends a literal `/` plus a space to the
stored text (every context in the reference implementation carries that stray prefix), and
`qmd context add "*" "/" "text"` fails outright with `Path is not in any indexed collection`.
Use the two-argument forms above.

## Build the index

```sh
qmd update   # keyword index — under 30 seconds for a few hundred files
qmd embed    # vector embeddings
qmd status   # confirm collections, file counts, pending embeddings
```

`qmd embed` downloads models on first use into `~/.cache/qmd/models/`. Sizes measured on disk:

| Model | Size | Pulled by |
| --- | --- | --- |
| `embeddinggemma-300M-Q8_0` | 318 MB | `qmd embed`, `qmd vsearch` |
| `Qwen3-Reranker-0.6B-Q8_0` | 610 MB | `qmd query` |
| `qmd-query-expansion-1.7B-q4_k_m` | 1.2 GB | `qmd query` |

Roughly 2.1 GB in total, downloaded once per machine, on demand. Budget the time: a few minutes
per download on a decent connection, then 10–20 minutes to embed a few hundred files on Apple
Silicon. Start `qmd embed` and go do something else.

## The command set

| Command | What it does | When it is the right tool |
| --- | --- | --- |
| `qmd query "..."` | Query expansion, then BM25 + vector, then LLM rerank | Default for questions. Best recall, slowest — a few seconds |
| `qmd search "..."` | BM25 keywords only, no models loaded | Exact terms, slugs, frontmatter values, lint greps. Instant |
| `qmd vsearch "..."` | Vector similarity only | Your phrasing differs from the wiki's vocabulary and you want no keyword bias |
| `qmd get <path>` | Print one document | You already know the page. Accepts `wiki/entry.md`, `qmd://wiki/entry.md`, a `#docid`, or `path:line` |
| `qmd multi-get <glob>` | Batch fetch several documents | Reading a cluster, e.g. `"wiki/topics/*.md"` |
| `qmd ls [collection]` | List indexed files | Fastest check that a new file actually got indexed |
| `qmd status` | Index health, counts, pending embeddings | Session start |
| `qmd update [--pull]` | Re-index collections | After every write to the wiki |
| `qmd embed [-f] [-c <name>]` | Generate or refresh vectors | After a batch. `-f` forces a full re-embed and is slow |
| `qmd cleanup` | Clear cached responses, vacuum the database | Monthly, or after large deletions |
| `qmd collection add/list/remove/rename/show` | Manage indexed folders | Setup, and fixing a mis-added collection |
| `qmd context add/list/rm` | Manage context strings | Setup, and when the domain description drifts |
| `qmd mcp` | Start the MCP server on stdio | Called by Claude Code, not by you |

Flags confirmed present in 2.5.2:

| Flag | Effect |
| --- | --- |
| `-n <num>` | Max results (default 5; 20 with `--files`/`--json`) |
| `-c, --collection <name>` | Restrict to a collection. **Repeat the flag** for several — `-c wiki,raw` fails |
| `--all` with `--min-score <num>` | Return everything above a score floor |
| `--full` | Print whole documents instead of snippets |
| `--files`, `--json`, `--csv`, `--md`, `--xml` | Output formats |
| `--no-rerank` | Skip the reranker; much faster, noticeably worse ordering |
| `--no-gpu` | Force CPU for the local models |
| `--line-numbers` | Prefix snippet lines with numbers |
| `-C, --candidate-limit <n>` | Cap candidates sent to the reranker (default 40) |
| `--explain` | Include retrieval score traces |
| `--index <name>` | Use a separate named index — handy for experiments |

`qmd query` also accepts a structured query document, where each line is typed:

```sh
qmd query $'lex: "exact phrase" -excludedword\nvec: how this feels in practice'
qmd query $'hyde: A hypothetical passage that would answer the question'
```

A bare single-line query is implicitly expanded. You cannot mix a bare query with typed lines,
and each typed line must be a single line with balanced quotes.

## Wiring it into Claude Code

qmd ships an MCP server. The project's `.claude/settings.json` registers it so Claude Code loads
it at session start — the file comes from `templates/settings.json.template`, and `SETUP.md`
covers instantiating it. Restart Claude Code after installing qmd for the first time, then check
the index from inside a session with `qmd status`.

Over MCP, qmd exposes exactly four tools: `query`, `get`, `multi_get` and `status`. There is no
keyword-only tool, so when the agent wants a fast literal grep it should shell out to
`qmd search` through Bash rather than reach for the MCP `query` tool. That is worth telling the
agent explicitly; otherwise it pays for reranking on questions like "which pages mention this
exact slug".

## Maintenance

| When | Run |
| --- | --- |
| Session start | `qmd status`, then `qmd update` |
| End of every Phase 5 integration | `qmd update` — non-negotiable, or the new pages are invisible |
| After a batch that wrote 10 or more files | `qmd embed` |
| Embeddings look stale or wrong | `qmd embed -f` (slow — 15–30 minutes on a few hundred files) |
| Monthly, or after deleting a lot | `qmd cleanup` |

`02-ingestion-protocol.md` places the `qmd update` step inside Phase 5; `06-operations.md` has
the full session-start and session-close rituals.

## What is machine-local and does not travel

| Artefact | Location | In git? | Note |
| --- | --- | --- | --- |
| Project files | `"$PROJECT_ROOT"` | Yes | The only source of truth |
| `.claude/settings.json` | `"$PROJECT_ROOT/.claude"` | Yes | Works on any machine that has qmd |
| Search index | `~/.cache/qmd/index.sqlite` | No | Absolute paths baked in; rebuild per machine |
| Models | `~/.cache/qmd/models/` | No | ~2.1 GB, downloaded on demand |

The index is a derived artefact. Do not commit or sync it: it stores absolute paths, so a copy
from another machine points at directories that do not exist. On a new machine, clone the repo and
repeat the collection, context, `update` and `embed` steps — 20–30 minutes, most of it waiting.
For scale, the reference implementation's index is 43.5 MB covering 533 documents and 5,170
embedded chunks.

## Troubleshooting

**`qmd: command not found`** — not installed, or npm's global bin is not on `PATH`. Run
`npm install -g @tobilu/qmd`, then `which qmd`. If a shell finds it but Claude Code does not,
restart Claude Code so it inherits the updated `PATH`.

**`qmd query` and `qmd vsearch` exit with code 134** — verified on 2.5.2: both print complete,
correct results and then abort during teardown as the local models unload. `SIGABRT` and a native
stack trace follow the output. The results are fine. The consequence is for scripts: never chain
these with `&&`, and do not treat a non-zero exit as failure. `qmd search`, `qmd status` and
`qmd update` exit 0 normally, so prefer them in anything automated.

**A collection shows 0 files** — almost always a space in the path, or files that are not `.md`.
Run `qmd collection show <name>` and compare the stored path with reality. Fix by
`qmd collection remove <name>` and re-adding with a space-free path.

**A collection has a space in its name** — the reference implementation ended up with a
collection literally named `original content`, which makes every `-c` invocation awkward. Fix
with `qmd collection rename`.

**`Pending: N need embedding` in `qmd status`** — new files are keyword-indexed but not yet
vectorised, so `vsearch` and the vector half of `query` will miss them. Run `qmd embed`.

**First query of a session is slow** — the models are loading into memory; later queries are
faster. **Results quote text that is no longer in the file** — the index is stale, run
`qmd update`. **Results are broadly irrelevant** — check `qmd context list`; a missing or wrong
context degrades reranking noticeably.

## Alternatives: you may not need qmd

Be honest about scale. Below roughly 100 entries, a well-maintained `wiki/index.md` — one row per
page with a one-line description — plus Claude's built-in Grep and Glob covers nearly everything.
The agent reads the index, sees what exists, and opens the two or three pages it needs. That costs
nothing to set up. What you give up is semantic recall: duplicate detection weakens as the index
passes a few hundred rows, and questions phrased in vocabulary the wiki does not use will miss.

To run without it:

- Skip the `mcpServers` block when instantiating `.claude/settings.json`.
- Drop the `qmd update` line from the Phase 5 checklist in your `CLAUDE.md`.
- Tell the agent to search with Grep over `"$PROJECT_ROOT/wiki"` and to treat `wiki/index.md`
  as the authoritative catalogue.
- Keep `index.md` scrupulously current. It is now the whole retrieval layer, so a missing row is
  a page that has effectively vanished.

Nothing in the wiki format depends on qmd, so adding it later is purely additive: install,
add the two collections and contexts, `qmd update`, `qmd embed`. Other reasonable substitutes are
`ripgrep` for fast literal search and Obsidian's built-in search over the same folder (see
`05-foam-vscode-setup.md`). If you swap engines, `{{SEARCH_CMD}}` is the single token to change
in the templates.
