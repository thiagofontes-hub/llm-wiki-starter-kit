# Setup procedure

You are a Claude Code agent. Your job in this session is to turn this kit into a working,
seeded, search-indexed LLM-maintained wiki for the person you are talking to (referred to below
as **the owner**), and to prove it works by ingesting one pilot source with her.

Work through the phases in order. Each phase has a done-condition; do not move on until it is
met. Everything you need is in this folder: the background docs live in `docs/`, the fill-in-the-
blanks files live in `templates/`, and real pages from a production instance live in `examples/`.

Budget roughly 60–90 minutes of wall-clock time, most of it waiting on the owner's answers and
on the embedding model download.

## Rules for you, the setup agent

- **Do not skip the interview (Phase 1).** Every token value comes from the owner. Guessing her
  domain produces a wiki that fights her for months.
- **Do not skip the pilot ingest (Phase 7).** It is the only step that tests the schemas against
  real content.
- **Do not batch on day one.** One source through all five phases, then stop and tune.
- **Do not invent placeholder tokens.** The 19 in the master table below are the whole
  vocabulary. If something seems missing, tell the owner rather than inventing a token.
- **Do not modify anything under `examples/` or `reference/`.** They are frozen artefacts from a
  different domain, used for comparison only.
- **Stop and ask if the owner's answers are mutually inconsistent** — for example an atomicity
  rule that implies one entry per source, or topic hubs that no plausible entry would ever sit
  under. Reconcile before rendering anything.
- Never write a file literally named `CLAUDE.md` or `.claude/agents/*.md` from a path you have
  not double-checked. Those paths are auto-loaded by Claude Code; a stray one corrupts the
  owner's next session.

---

## Phase 0 — Preconditions

1. Confirm the working directory is the kit root: `SETUP.md` and `templates/` must both be
   present.

   ```sh
   pwd
   ls SETUP.md templates/ docs/ examples/
   ```

2. If either is missing, **stop**. Tell the owner you are in the wrong directory and ask her to
   restart the session from the kit folder. Do not attempt to find the kit by searching the disk.

3. Report tool versions:

   ```sh
   git --version
   node --version   # must be 18 or later
   npm --version
   command -v qmd && qmd --version || echo "qmd not installed"
   ```

4. If `node` is missing or older than 18, tell the owner: search is unavailable until she
   installs it (`brew install node`, or https://nodejs.org). The wiki still works without
   search; note the gap and continue.

**Done when:** you are in the kit root, and you have reported git, node, npm and qmd status to
the owner in one short message.

---

## Phase 1 — Interview the owner

This is the most important phase. Everything downstream is a mechanical substitution of the
answers you collect here.

Use the **AskUserQuestion** tool. It takes up to 4 questions per call, so batch them. For every
question, propose a default, or two or three drafted candidate answers as options, so the owner
can accept or pick rather than compose from nothing. Free-text answers are fine where the option
list cannot capture the nuance — say so in the question.

Before the first call, read the domain-adaptation cheat sheet at the bottom of this file. It
gives you worked token values for four unrelated domains; use it to reason by analogy into hers
and to draft plausible defaults.

### Batch 1 — domain and unit of knowledge

| Question | Establishes | Default to propose |
| --- | --- | --- |
| In one line, what body of knowledge is this wiki for? | `{{DOMAIN}}` | Draft one from whatever she has already told you |
| What is one *thing* in this wiki called — the atomic unit? | `{{ENTRY_NOUN}}`, `{{ENTRY_NOUN_PLURAL}}`, `{{ENTRY_DIR}}` | `concept` / `concepts` |
| What counts as exactly one entry, and what does not? | `{{ATOMICITY_RULE}}` | Offer 2–3 candidate rules drawn from the cheat sheet row closest to her domain |
| What kinds of raw material will you feed it? | `{{SOURCE_TYPES}}` | `interview \| article \| video \| paper` |

**Push back on the atomicity rule.** It is the single answer most likely to be wrong, and the
most expensive to fix later. Test her rule against these four checks and say which ones fail:

- Can one entry be stated in a single sentence, and does its title name one thing rather than a
  theme? If not, the rule is too coarse.
- Does the rule produce a body of 4–12 lines? A rule that implies "one entry per source", "one
  per chapter" or "one per interview" produces essays, not entries. Reject it.
- Would an entry still make sense to a reader who has not read the source? If not, the rule is
  too fine — the unit is a fragment, not an entry.
- Would two different sources ever produce the *same* entry, so that the second reinforces the
  first rather than adding a page? If never, the unit is too specific to be reusable.

Keep interviewing until the rule is concrete enough that you could apply it to a source right
now without asking her anything. State it back to her in her words and get a yes. Show her
`examples/example-entry.md` as a calibration of length and shape — flagging that its content is
from an unrelated domain.

### Batch 2 — structure and standards

| Question | Establishes | Default to propose |
| --- | --- | --- |
| Which 5–10 themes will most entries fall under? | `{{SEED_TOPICS}}` | Draft 6–8 slugs from her domain line and offer them for editing |
| Which 10–20 tags should exist on day one? | `{{SEED_TAGS}}` | Derive from the topic slugs plus source-type tags |
| When should an entry be created rather than an existing one reinforced? | `{{QUALITY_BAR}}` | "New entry only if the idea is not already covered; a restatement, example or added nuance reinforces the existing entry instead" |
| Folder names: raw sources, processed sources, entries? | `{{SOURCE_DIR}}`, `{{PROCESSED_DIR}}`, `{{ENTRY_DIR}}` | `raw/`, `raw-processed/`, and the plural entry noun |

Seed topic hubs are cheap to add and awkward to remove, so err towards fewer. Tell her hubs are
expected to grow: the reference instance reached 12 hubs over 17 sessions.

Never accept a directory name containing a space. Spaces in directory names broke tooling
repeatedly in the reference implementation (see `docs/07-lessons-learned.md`). If she wants
`My Sources`, counter-propose `my-sources`.

### Batch 3 — identity and paths

| Question | Establishes | Default to propose |
| --- | --- | --- |
| What is the project called? | `{{PROJECT_NAME}}` | Something short, derived from the domain |
| Where should it live on disk? | `{{PROJECT_ROOT}}` | In place: this kit folder becomes the project, renamed to the project name |
| What should the ingesting persona be called? | `{{LIBRARIAN_ROLE}}` | `Librarian`, or the domain plus `Librarian` |
| What should the query-time persona be called? | `{{EXPERT_ROLE}}` | A role title from her domain, e.g. `Research Advisor` |

On `{{PROJECT_ROOT}}` there are two shapes, and you must record which one she picks:

- **In place (recommended).** This kit folder *is* the project. Nothing is copied; Phase 3 moves
  the kit's own documentation into `resources/`. Rename the folder to the project name afterwards
  if she wants.
- **Separate folder.** You create `{{PROJECT_ROOT}}`, then move the whole contents of the kit into
  it and continue there. Use this if she wants the pristine kit kept for a second project.

### Batch 4 — voice and optional layers

| Question | Establishes | Default to propose |
| --- | --- | --- |
| How should the expert persona speak? | `{{EXPERT_STYLE}}` | Three bullets: peer-level and direct; concrete recommendations over options; names the trade-off |
| Install the local search engine now? | `{{SEARCH_CMD}}`, Phase 4 | Yes, `qmd` — the system is much weaker without it |
| Set up Foam and VS Code now? | Phase 6 | Yes if she already uses VS Code, otherwise defer |
| Confirm this search context string? | `{{DOMAIN_CONTEXT}}` | Draft 1–2 sentences yourself from her domain line and the topic hubs, and ask her to approve or edit |

`{{DATE_TODAY}}` is not a question. Get it from the system:

```sh
date +%F
```

**Done when:** you hold an explicit, owner-approved value for all 19 tokens, and the atomicity
rule passes all four checks above.

---

## Phase 2 — Record the configuration

Write the answers to `{{PROJECT_ROOT}}/domain-config.md` before rendering anything. If the owner
chose a separate project root that does not exist yet, write the file in the kit root for now; it
moves to the project root with everything else in step 3c. This file is
the single source of truth for the instantiation, it makes the render re-runnable, and it is what
a future session reads to understand why the schemas look the way they do.

Structure it as:

1. An H1 with the project name and the date.
2. A table with one row per token: `| Token | Value |`, all 19 tokens, values in full. Long values
   (`{{ATOMICITY_RULE}}`, `{{QUALITY_BAR}}`, `{{EXPERT_STYLE}}`) go in the table if they fit on a
   line, otherwise put a short form in the table and the full text in a section below.
3. A section headed `## Owner's answers` containing her answers **verbatim**, question by
   question, including anything she said that did not map to a token. Her reasoning is worth more
   than your paraphrase of it when a schema needs revising in three months.
4. A section headed `## Decisions and open questions` recording the in-place-versus-separate
   choice, anything you pushed back on and how it resolved, and anything deferred.

Then **show her the token table in the chat and ask for explicit confirmation.** Do not render a
single template until she says yes. Fixing a token now costs one edit; fixing it after Phase 7
costs a re-render.

**Done when:** `domain-config.md` exists, contains all 19 token values, and the owner has
confirmed the table in the chat.

---

## Phase 3 — Instantiate

Every command in this phase, and the git block in Phase 6, refers to the project root. Claude Code
starts a fresh shell for each tool call, so a variable set in one call is gone by the next: set
`PROJECT_ROOT` at the head of **every** command block you run, using the literal path recorded in
`domain-config.md`.

```sh
PROJECT_ROOT="/Users/her/Documents/GitHub/LoreOS"   # the real value from domain-config.md
mkdir -p "$PROJECT_ROOT/resources"
```

### 3a. Create the skeleton

If the owner chose a separate project root, create it first: `mkdir -p "$PROJECT_ROOT"`.
`scripts/scaffold.sh` only adds subdirectories, and exits 1 if the root does not exist.

Use the helper:

```sh
bash scripts/scaffold.sh --help
```

Read its `--help` output and run it with the owner's values. It creates the project directory
skeleton — source, processed, triage, wiki and `.claude/` folders. `scripts/scaffold.sh` is
authoritative on the exact directory names; if they differ from the shape below, the script wins
and you record the real names in `domain-config.md`.

The intended shape, with `raw/`, `raw-processed/` and `concepts/` standing in for the tokens:

```text
PROJECT_ROOT/
├── CLAUDE.md                 # librarian instructions (rendered)
├── domain-config.md          # written in Phase 2
├── .gitignore
├── .claude/
│   ├── settings.json
│   ├── handover.md
│   ├── agents/
│   └── commands/
├── raw/                      # SOURCE_DIR — immutable sources awaiting ingest
├── raw-processed/            # PROCESSED_DIR — sources already ingested, gitignored
├── wiki/
│   ├── CLAUDE.md             # expert-role override (rendered)
│   ├── index.md
│   ├── log.md
│   ├── concepts/             # ENTRY_DIR
│   ├── topics/
│   └── sources/
├── scripts/
└── resources/                # the kit's own docs, moved here in step 3c
```

### 3b. Render every template

Rendering rules, all mandatory:

- Substitute **every** token in the file with the value from `domain-config.md`.
- Delete the HTML comment header block at the top of the template. It is scaffolding for you, not
  content for the owner.
- Write the target file **without** the `.template` suffix, at the target path in the table below.
- Leave no unsubstituted token behind. Verify at the end of the phase.
- Double-check the path before writing anything named `CLAUDE.md` or under `.claude/agents/`.
- Do not edit the template in place. Templates are kept for a later re-render.

The complete map. Paths in the target column are relative to the project root.

| Template | Renders to | Tokens it consumes |
| --- | --- | --- |
| `templates/CLAUDE.md.template` | `CLAUDE.md` | Nearly all: project name and root, domain, both roles, entry noun and dir, source and processed dirs, source types, atomicity rule, quality bar, seed tags, seed topics, search command |
| `templates/wiki-CLAUDE.md.template` | `wiki/CLAUDE.md` | Project name, domain, expert role, expert style, entry noun and plural, entry dir, seed topics, search command |
| `templates/settings.json.template` | `.claude/settings.json` | Search command (and project root if the MCP entry is path-scoped) |
| `templates/handover.md.template` | `.claude/handover.md` | Project name, date, entry noun and plural, entry dir, source and processed dirs, search command |
| `templates/agents/wiki-extractor.md.template` | `.claude/agents/wiki-extractor.md` | Project root, domain, entry noun and plural, entry dir, source dir, source types, atomicity rule, quality bar, seed tags, search command |
| `templates/agents/wiki-writer.md.template` | `.claude/agents/wiki-writer.md` | Project root, entry noun and plural, entry dir |
| `templates/agents/wiki-formatter.md.template` | `.claude/agents/wiki-formatter.md` | Project root, entry noun and plural, entry dir |
| `templates/agents/wiki-verifier.md.template` | `.claude/agents/wiki-verifier.md` | Project root, entry noun and plural, entry dir |
| `templates/agents/domain-expert.md.template` | `.claude/agents/domain-expert.md` | Domain, expert role, expert style, entry noun and plural, entry dir, search command |
| `templates/commands/end-session.md.template` | `.claude/commands/end-session.md` | Project name, entry noun and plural, entry dir, processed dir, search command, date |
| `templates/wiki/index.md.template` | `wiki/index.md` | Project name, domain, entry noun plural, date, seed topics |
| `templates/wiki/log.md.template` | `wiki/log.md` | Project name, date |
| `templates/gitignore.template` | `.gitignore` | Project name, processed dir, search command |
| `templates/pages/entry.md.template` | Not rendered once — page skeleton kept at `resources/templates/pages/entry.md.template` and used per entry at ingest time | Entry dir, source dir, seed tags |
| `templates/pages/topic-hub.md.template` | Not rendered once — page skeleton, as above | Entry noun plural, seed tags |
| `templates/pages/source-summary.md.template` | Not rendered once — page skeleton, as above | Source dir, source types, entry noun plural |

Each template's own header comment lists its tokens exactly. Where the header and the table above
disagree, **the header wins** — it was written against the file's actual body.

The three page skeletons under `templates/pages/` are not one-shot renders: they describe the
shape of every entry, hub and source summary the wiki will ever contain. The canonical version of
those schemas is `docs/03-page-schemas.md`; the skeletons are the copy-paste form of it.

Optionally create the seed topic hubs now from `templates/pages/topic-hub.md.template`, one per
slug the owner gave for `{{SEED_TOPICS}}`, with empty entry lists and a one-paragraph statement of
what each hub is for. Hubs with no entries yet are fine, and having the files present stops the
first ingest inventing hub slugs.

### 3c. Move the kit's documentation into the project

The project should carry its own documentation. Move, do not copy:

```sh
PROJECT_ROOT="/Users/her/Documents/GitHub/LoreOS"   # the real value from domain-config.md
mkdir -p "$PROJECT_ROOT/resources"
mv docs examples templates "$PROJECT_ROOT/resources/"
mv reference/llm-wiki.md "$PROJECT_ROOT/resources/" && rmdir reference
```

`reference/` is flattened, unlike the other three directories: the pattern write-up lands at
`resources/llm-wiki.md`, which is the path the rendered `CLAUDE.md` already names. `docs/`,
`examples/` and `templates/` keep their folder names under `resources/`.

If the owner chose a separate project root, also move `scripts/`, `domain-config.md`, `README.md`
and this `SETUP.md` into the project — `scripts/` and `domain-config.md` at the project root, the
two markdown files into `resources/`.

`templates/` is **kept, not deleted**. A later session will want to re-render an agent file after
the atomicity rule changes, and re-rendering from `domain-config.md` plus the templates is far
safer than hand-editing four agent files.

### 3d. Verify the render

```sh
PROJECT_ROOT="/Users/her/Documents/GitHub/LoreOS"
grep -rn "{{" "$PROJECT_ROOT" --exclude-dir=resources --exclude-dir=.git
```

No `--include` filters: dotfiles such as `.gitignore` and JSON such as `.claude/settings.json`
carry tokens too, and a filtered grep silently misses them. Expect zero matches. Any hit is an
unsubstituted token — fix it before continuing. Also confirm the header comment blocks are gone:

```sh
PROJECT_ROOT="/Users/her/Documents/GitHub/LoreOS"
grep -rln "Delete this comment block" "$PROJECT_ROOT" --exclude-dir=resources
```

**Done when:** every render-once row of the map has been rendered, both greps come back clean, and
`ls -R "$PROJECT_ROOT/.claude"` shows `settings.json`, `handover.md`, five agent files and
`commands/end-session.md`.

---

## Phase 4 — Search setup

Skip this phase only if the owner declined search in Phase 1; if you skip it, record the decision
in `domain-config.md` and in the handover.

Follow `resources/docs/04-search-setup-qmd.md`. It covers install, the two collections, the
context strings, the command set, per-machine index rebuilds and troubleshooting. Do not
improvise around it, and do not restate it back to the owner — point her at it.

Two things worth telling her up front, because they are slow and she will otherwise think
something has hung:

- The embedding model is a one-off download of roughly 318 MB on first use.
- Embedding a few hundred files takes 10–20 minutes on Apple Silicon. Embedding a brand-new,
  nearly empty wiki is near-instant.

Feed the search engine `{{DOMAIN_CONTEXT}}` as the global context string, plus one context per
collection describing the raw sources and the compiled wiki respectively.

**Done when:** both collections (the source directory and `wiki/`) are registered and indexed,
contexts are added, a status check reports healthy, and embeddings have either been generated or
explicitly deferred with the deferral noted in the handover.

---

## Phase 5 — Seed the wiki

1. Confirm `wiki/index.md` and `wiki/log.md` exist from step 3b, and that their counts read zero
   apart from the seed topic hubs you created.
2. Confirm the entry directory, `wiki/topics/` and `wiki/sources/` exist — empty, or holding only
   the seed hubs.
3. Confirm the initialisation entry rendered from `log.md.template` is the top entry of
   `wiki/log.md`, and edit its state block to the real numbers — 0 entries, N seed topic hubs,
   0 sources. Do not add a second initialisation entry; the template already ships one.

**Done when:** `index.md` and `log.md` exist with correct headings and counts that match reality
(zero entries and sources, N seed hubs), the three wiki subdirectories exist, and exactly one
initialisation entry sits at the top of `log.md`.

---

## Phase 6 — Optional layers

### Foam and VS Code

If the owner said yes in Phase 1, follow `resources/docs/05-foam-vscode-setup.md`. It covers the
extension install, workspace settings, wikilinks, backlinks, the graph view and the Obsidian
alternative. Confirm it works by opening any page and checking that a `[[wikilink]]` resolves.

### Git

The wiki is worth versioning: it is the history of how the owner's understanding of her own domain
changed.

```sh
PROJECT_ROOT="/Users/her/Documents/GitHub/LoreOS"   # the real value from domain-config.md
cd "$PROJECT_ROOT"
git init
git add -A
git status
```

Show her `git status` and **ask before committing**. Do not create a remote and do not push — that
is hers to decide. If she agrees, make one commit with a plain message such as
`chore: initialise <project name> from llm-wiki-starter-kit`.

**Done when:** the Foam layer works or is explicitly deferred, and the repository is initialised
with the first commit either made with her consent or deliberately skipped.

---

## Phase 7 — Pilot ingest (mandatory)

**Do not treat this as optional and do not let the owner talk you out of it.** Schemas that look
right in the abstract are usually wrong for a specific domain, and a wrong schema replicated
across 40 sources is expensive to undo: every entry has the wrong grain, every hub has the wrong
argument, and the only honest fix is a re-ingest.

1. Ask the owner for **one short source** — under about 1,500 words — that is typical of her
   material. Not the most important one; the most representative one. If she has nothing yet,
   `resources/docs/08-sourcing-content.md` covers how to get raw material in.
2. Put it in the source directory as a single `.md` file, with a filename that names the real
   source rather than a scraper timestamp.
3. Run it through **all five phases exactly as written** in
   `resources/docs/02-ingestion-protocol.md`: one `wiki-extractor`, your own quality review, one
   `wiki-writer`, one `wiki-formatter`, one `wiki-verifier`, then the Phase 5 integration you
   cannot delegate. Use the real agents you rendered, not a shortcut where you do the work
   yourself. The point is to test the agent files, not the idea.
4. Then **review the output with the owner, page by page**, and ask these questions explicitly:

   | Question | What a bad answer looks like | What to change |
   | --- | --- | --- |
   | Is the atomicity right? | Entries read as mini-essays, or two entries say the same thing | `{{ATOMICITY_RULE}}`, then the extractor template |
   | Are the tags right? | Every entry carries the same three tags, or tags no future entry will reuse | `{{SEED_TAGS}}` |
   | Do the topic hubs make sense? | Nothing fits a hub, or everything fits one hub | `{{SEED_TOPICS}}` |
   | Is the entry body the right length? | Under 3 lines, or over 12 | The body standard in the entry skeleton and the formatter template |
   | Is the source summary useful on its own? | It repeats the entries instead of framing them | The source-summary skeleton |
   | Is the entry noun natural in her mouth? | She keeps calling them something else | `{{ENTRY_NOUN}}` — rename now, never later |

5. Apply the changes: edit `domain-config.md` first, then re-render the affected templates from it,
   then fix the pilot's pages by hand so the wiki carries no legacy shape. If the entry noun or
   entry directory changes, re-render and re-index rather than patching.
6. Optionally run one more pilot source if the first round produced substantial changes. Still one
   source, not a batch.

**Done when:** one source is fully ingested and integrated, the owner has looked at every page it
produced and agreed the shape is right, and any resulting changes are reflected in both
`domain-config.md` and the rendered templates. **No batch ingest happens in this session.**

---

## Phase 8 — Handover

1. Render `.claude/handover.md` from its template if you have not already, then fill it with the
   real state of the system: what exists, what the pilot taught you, what changed after it, and
   what the next session should do first.
2. Record the recommended first batch — the shortest unprocessed sources, sized by the tier table
   in `resources/docs/02-ingestion-protocol.md`. `scripts/unprocessed.sh` lists the backlog by
   word count.
3. Re-index the search collections so the new pages are findable.
4. Then tell the owner, in plain language and without jargon:
   - **What exists now.** The project root, the wiki and its counts, the librarian and expert
     roles, the five sub-agents, search status.
   - **What to do next session.** Drop sources into the source directory, open Claude Code at the
     project root, and ask for an ingest. One batch per session.
   - **How to start a session.** Open Claude Code in the project root; the root `CLAUDE.md` loads
     the librarian role automatically. To *use* the knowledge rather than build it, open Claude
     Code in the `wiki/` folder instead, where the expert role takes over.
   - **How to end one.** Run `/end-session`, which handles the integration and handover ritual.
   - **Where the manual is.** `resources/docs/06-operations.md` for day-to-day running, and
     `resources/docs/07-lessons-learned.md` before doing anything clever.

**Done when:** `.claude/handover.md` reflects reality, the index is current, and you have given the
owner the five-point plain-language summary above.

---

## Master placeholder table

These 19 tokens are the entire substitution vocabulary: double curly braces, upper snake case.
Example values are from a fictional novel-lore instance, to make clear they are examples and not
part of the system.

| Token | Meaning | Default | Example value |
| --- | --- | --- | --- |
| `{{PROJECT_NAME}}` | Project and repository name | none — ask | `LoreOS` |
| `{{PROJECT_ROOT}}` | Absolute path to the project root | this kit folder, renamed | `/Users/her/Documents/GitHub/LoreOS` |
| `{{DOMAIN}}` | One-line description of the knowledge domain | none — ask | `the lore of the Ninth House novels` |
| `{{DOMAIN_CONTEXT}}` | 1–2 sentence context string handed to the search engine | drafted by you from the domain line | `A lore reference for the Ninth House novels, covering characters, houses, magic and chronology.` |
| `{{LIBRARIAN_ROLE}}` | Name of the ingesting persona | `Librarian` | `Lore Archivist` |
| `{{EXPERT_ROLE}}` | Name of the consuming persona | none — ask | `Lore Master` |
| `{{EXPERT_STYLE}}` | 2–4 bullets defining the expert persona's voice | direct, concrete, names trade-offs | `- Answers in-universe unless asked otherwise` |
| `{{ENTRY_NOUN}}` | Atomic unit, singular | `concept` | `entity` |
| `{{ENTRY_NOUN_PLURAL}}` | Atomic unit, plural | `concepts` | `entities` |
| `{{ENTRY_DIR}}` | Folder holding atomic entries, under `wiki/` | same as the plural entry noun | `entities` |
| `{{SOURCE_DIR}}` | Folder holding raw, immutable sources | `raw` | `raw` |
| `{{PROCESSED_DIR}}` | Folder raw sources move to once ingested | `raw-processed` | `raw-processed` |
| `{{SOURCE_TYPES}}` | Pipe-delimited enum of source types | `interview \| video \| article \| paper` | `chapter \| episode \| companion-book \| interview` |
| `{{ATOMICITY_RULE}}` | What counts as exactly one entry in this domain | none — ask, and challenge | `One entry per named entity; never one per chapter.` |
| `{{QUALITY_BAR}}` | When to create a new entry vs. reinforce an existing one | new only if not already covered; restatements reinforce | as default |
| `{{SEED_TAGS}}` | Starting tag vocabulary | derived from the topic slugs | `houses, magic, chronology, characters, geography` |
| `{{SEED_TOPICS}}` | Starting topic hub slugs, 5–10 | none — ask | `houses-and-factions, magic-system, timeline-and-eras` |
| `{{DATE_TODAY}}` | Today's date, `YYYY-MM-DD` | from `date +%F` | `2026-09-09` |
| `{{SEARCH_CMD}}` | Search binary name | `qmd` | `qmd` |

The directory defaults are deliberately different from the reference implementation, which used
`original content/` and `processed-original-content/`. Spaces in directory names caused real
tooling failures there, so the kit defaults to space-free names. Keep it that way.

---

## Domain-adaptation cheat sheet

Four worked domains, none of them the reference implementation's. Use the closest row to draft
defaults in Phase 1, then adapt with the owner. The last row is the reference implementation
itself, shown so you can see how a real instance resolved the same questions.

| Domain | Entry noun / dir | Source types | Plausible topic hubs | Atomicity rule, in one sentence |
| --- | --- | --- | --- | --- |
| Academic or clinical research papers | `finding` / `findings` | `paper \| preprint \| trial-report \| systematic-review \| dataset` | `study-design-and-bias`, `glycaemic-control`, `biomarker-panels`, `dosing-and-adherence` | One entry per specific claim that a defined study population supports, stated with its effect direction and its evidence quality — never one entry per paper. |
| Lore of a novel or TV series | `entity` / `entities` | `chapter \| episode \| companion-book \| author-interview \| fan-wiki-page` | `houses-and-factions`, `magic-system`, `timeline-and-eras`, `geography-and-realms` | One entry per named entity — person, place, object, faction or dated event — holding everything known about it, never one entry per chapter or episode. |
| Customer and user-research interviews | `insight` / `insights` | `interview \| usability-session \| survey-open-text \| support-ticket \| diary-study` | `onboarding-friction`, `pricing-perception`, `trust-and-security`, `jobs-to-be-done` | One entry per distinct behaviour, need or blocker observed in at least one participant, phrased so a designer can act on it without reading the transcript. |
| Legal case law or regulatory filings | `principle` / `principles` | `judgment \| statute \| regulation \| enforcement-notice \| guidance-note` | `lawful-basis-and-consent`, `jurisdiction-and-standing`, `remedies-and-damages`, `disclosure-duties` | One entry per legal proposition a court or regulator actually decided, kept separate from the facts of the case that produced it and from commentary about it. |
| Reference implementation: corporate career coaching | `concept` / `concepts` | `interview \| video \| article \| exercise` | `career-advancement-strategy`, `corporate-politics-and-influence`, `communication-and-executive-presence`, `productivity-and-execution` | One entry per named tactic, framework or mental model, self-contained in 3–6 sentences. |

Patterns worth carrying across, whatever her domain turns out to be:

- The entry noun should be a word she already uses when talking about her material out loud.
- The atomicity rule almost always needs an explicit **"never one per source"** clause. If hers
  does not have one, ask what stops the extractor producing one entry per document.
- Source types are an enum, not a taxonomy. Four or five values is right; twelve means she is
  encoding metadata that belongs in tags.
- Topic hubs are arguments about the domain, not filing cabinets. If a hub could never be written
  as three paragraphs of prose, it is a tag, not a hub.

---

## Acceptance checklist

Tick every box before you tell the owner setup is complete. If one cannot be ticked, say which and
why.

- [ ] **Phase 0** — working directory confirmed as the kit root; git, node 18+, npm and search-tool
      status reported to the owner.
- [ ] **Phase 1** — all 19 tokens have owner-approved values; the atomicity rule passes the four
      checks and was stated back and confirmed.
- [ ] **Phase 2** — `domain-config.md` exists with the full token table, the owner's verbatim
      answers and the decisions section; the owner confirmed the table in the chat.
- [ ] **Phase 3** — directory skeleton created; every render-once row of the template-to-target map
      rendered, the three `templates/pages/` skeletons deliberately left un-rendered under
      `resources/templates/pages/`; no unsubstituted braces outside `resources/`; no leftover
      template header comments; the kit's `docs/`, `examples/` and `templates/` moved into
      `resources/` and `reference/llm-wiki.md` flattened to `resources/llm-wiki.md`, with
      `templates/` retained.
- [ ] **Phase 4** — both collections indexed, contexts added, status healthy, embeddings generated
      or explicitly deferred and noted.
- [ ] **Phase 5** — `wiki/index.md` and `wiki/log.md` seeded, counts matching reality; entry, topic
      and source directories exist; exactly one initialisation entry, the rendered one, at the top
      of `log.md`.
- [ ] **Phase 6** — Foam and VS Code configured or deliberately deferred; git initialised and the
      first commit made with explicit consent, or deliberately skipped. Nothing pushed.
- [ ] **Phase 7** — exactly one pilot source ingested through all five phases with the real
      sub-agents; output reviewed with the owner against the six review questions; resulting
      changes applied to `domain-config.md` and re-rendered; no batch ingest attempted.
- [ ] **Phase 8** — `.claude/handover.md` reflects real state and names a recommended first batch;
      search index current; the owner has the five-point plain-language summary of what exists,
      what to do next, how to start and end a session, and where the manual lives.
