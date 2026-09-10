# Page schemas

This is the canonical schema reference for the whole kit — the templates, the agent instructions and
the setup procedure all link here rather than restating the rules, so this is the one place to
change if you want your wiki shaped differently.

Frontmatter is the wiki's API: the search engine indexes it, Foam builds the graph and backlink
panes from it, `scripts/lint-wiki.sh` checks it, and the four sub-agents read and write it as their
contract with each other. When a field name drifts — `source:` on one page, `sources:` on the next —
nothing errors; queries just quietly start returning less and you find out months later
([07-lessons-learned.md](07-lessons-learned.md) has the full story).

**Names.** This doc writes the atomic-entry directory as `concepts/`, the raw folder as `raw/` and
the search binary as `qmd`. Yours are whatever you chose for `{{ENTRY_DIR}}`, `{{SOURCE_DIR}}` and
`{{SEARCH_CMD}}`; substitute throughout. The master token table is in [../SETUP.md](../SETUP.md).

## The four page types

| Type | Path | One per | Job |
| --- | --- | --- | --- |
| Atomic entry | `wiki/concepts/<slug>.md` | One idea | The reusable unit. Everything else points at these. |
| Topic hub | `wiki/topics/<slug>.md` | One theme | An argument that walks a reader through a cluster of entries. |
| Source summary | `wiki/sources/<slug>.md` | One ingested source | Provenance, and the record that this source is done. |
| Register pages | `wiki/index.md`, `wiki/log.md` | Exactly one each | Catalogue and history. Both are owned by the main agent. |

Real specimens of all five ship in [../examples/](../examples/) — read those rather than trusting
a synthetic example. They come from a career-coaching domain, not yours: look at the shape, not
the subject. [../examples/README.md](../examples/README.md) says what to notice in each.

## Rules that apply to all frontmatter

- The YAML block is the first thing in the file: `---` on line 1, no blank line before the first
  key, `---` to close, then a blank line, then the body.
- **Quote every wikilink inside a list.** `sources: ["[[being-glue]]"]` is a list of one string;
  `sources: [[[being-glue]]]` is a parse error or a nested list depending on the parser. This is
  the single most common frontmatter mistake.
- Quote `title:` always — titles acquire colons and apostrophes eventually. Tags stay bare and
  kebab-case (`tags: [glue-work, career-risk]`); dates stay bare ISO (`2026-09-09`).
- **One spelling per field, forever.** Singular versus plural, underscore versus hyphen — pick one,
  record it here, and have the verifier grep for it in Phase 4.

## Atomic entry

```yaml
---
title: "Nemawashi"
tags: [corporate-politics, influence, buy-in]
sources: ["[[corporate-politics-survive-rivals-build-allies]]"]
related: ["[[influence-map]]", "[[risk-flagging]]", "[[power-center-mapping]]"]
---
```

| Field | Type | Required | If it drifts |
| --- | --- | --- | --- |
| `title` | Quoted string | Yes | Foam labels the graph node with the filename instead; search snippets lose their heading. |
| `tags` | List of bare kebab words, 3–6 | Yes | The page is unreachable by tag; it only surfaces on full-text luck. |
| `sources` | List of quoted wikilinks, 1 or more | Yes | Provenance is lost. An entry with no source is an opinion, and you cannot audit it later. |
| `related` | List of quoted wikilinks, 2–5 | Expected | The formatter has nothing to build the Related section from, and the page becomes a graph orphan. |

An entry may cite more than one source — that is what reinforcement looks like when a later source
strengthens an existing idea. `related` is the only permitted vocabulary for the Related section:
the formatter must not invent links beyond it.

### Body standard for entries

1. **Open with the idea.** One or two sentences stating the core claim in the entry's own terms.
   Never "This concept describes…". If a reader stops after the first sentence, they still have
   the point.
2. **Then use the shape the content actually has.** Do not decorate.

| Use | When |
| --- | --- |
| `**Bold terms**` | Naming the components of a framework, contrasting two named things, or marking the one phrase worth remembering. |
| Bullets | Three or more genuinely parallel items: steps, rules, examples, components. |
| A table | Two dimensions to cross, or one set mapped onto another. |
| Plain prose | A single coherent idea with no enumerable parts. This is correct more often than agents assume. |

3. **Budget: 4–12 lines of body**, excluding the Related section. Enough to stand alone, not a
   treatise. If it will not fit, you probably have two entries.
4. **Wikilink the first mention** of any related entry in the prose, plain text after that. Links
   inside sentences are what make the graph worth having.
5. **Close with `## Related concepts`** — 2–5 bullets, each `[[slug]] — one sentence on the
   relationship`. The sentence must say *how* they relate, not repeat the title:

```markdown
## Related concepts

- [[influence-map]] — the map of relationships that nemawashi is applied to
- [[power-center-mapping]] — identifying whose pre-buy-in matters most
```

Omit the section entirely if `related:` is empty. Heading text follows your entry noun: rename it
to `## Related findings` if that is your unit.

## Topic hub

```yaml
---
title: "Career Advancement Strategy"
tags: [career-advancement, promotion, strategy]
entries: ["[[career-as-a-business]]", "[[nine-box-model]]", "[[self-advocacy]]"]
sources: ["[[being-glue]]", "[[secrets-of-the-career-game-1]]"]
---
```

| Field | Type | Required | If it drifts |
| --- | --- | --- | --- |
| `title` | Quoted string | Yes | As above. |
| `tags` | List of bare kebab words | Yes | The hub does not surface alongside the entries it collects. |
| `entries` | List of quoted wikilinks, grows over time | Yes | Coverage becomes unauditable — you cannot tell which entries have a home. |
| `sources` | List of quoted wikilinks | Yes | You lose the record of which sources fed the theme. |

The reference implementation calls these fields `concepts:` and `concepts_extracted:`, because its
entry noun is "concept". The kit generalises to `entries:` and `entries_extracted:`. Either is
fine; using both is not.

### Body standard for hubs

A hub is an **argument**, not a list of links — the index already lists things. Write prose under
`##` sections that each make a point, wikilinking entries into the sentences where they earn their
place: "[[nine-box-model]] explains the mechanics of how promotions are decided", not a bullet
reading "nine-box model". Every Phase 5 integration must wire the session's new entries into that
argument, not merely append them to the frontmatter. Close with `## See also` pointing at sibling
hubs. A hub earns its existence at roughly 8–10 related entries; below that, tags are enough.

## Source summary

```yaml
---
title: "Being Glue"
source_file: "raw/being-glue-no-idea-blog.md"
source_type: article
date_ingested: 2026-09-09
tags: [glue-work, non-promotable-work, career-risk]
entries_extracted: ["[[glue-work]]", "[[deliberate-glue-work-allocation]]"]
---
```

| Field | Type | Required | If it drifts |
| --- | --- | --- | --- |
| `title` | Quoted string — the source's real title | Yes | You lose the ability to recognise a duplicate capture of the same source. |
| `source_file` | Quoted path, relative to project root | Yes | The chain back to the raw text breaks, and the file has already moved to `raw-processed/`. |
| `source_type` | One bare value from your `{{SOURCE_TYPES}}` enum | Yes | Type filtering stops working. Never invent a new value ad hoc; extend the enum deliberately. |
| `date_ingested` | Unquoted `YYYY-MM-DD` | Yes | Supersession judgements in a lint pass become guesswork. |
| `tags` | List of bare kebab words | Yes | The summary does not surface with its own subject matter. |
| `entries_extracted` | List of quoted wikilinks; `[]` is legitimate | Yes | You cannot answer "what did this source actually give us?". |

An empty `entries_extracted: []` is a real and useful outcome — a broken capture or an off-topic
source still deserves a summary page, because the summary is what marks the source processed.

### Body standard for source summaries

Three sections, in this order. Source summaries are **never** touched by the formatter in
Phase 3.5; entries only.

- `## Summary` — 2–3 sentences: what the source is, who made it, what it contributes.
- `## Key Contributions` — one line per new entry, `**Entry Name** — what it adds`.
- `## Entries Reinforced` — one line per existing entry this source strengthened without creating
  a new page: `[[slug]] — what this source adds to it`.

## Slugs

The filename is the slug is the wikilink target. Get it right once.

- Lowercase, ASCII, hyphen-separated. No spaces, underscores, apostrophes or `&`.
- A noun phrase naming the idea, 2–5 words: `glue-work`, `power-center-mapping`. Not a sentence, a
  question or a date. No numbering or version suffix — `nemawashi-2` means you missed a duplicate.
- Source slugs derive from the source's real title, not the scraper's filename.
- **Slugs are permanent.** Renaming one silently breaks every inbound wikilink. If you must rename,
  run `grep -rl "\[\[old-slug\]\]" wiki/` first and fix every hit in the same commit.

## Wikilinks

Foam syntax, no extension and no path: `[[glue-work]]` resolves wherever it appears. Use the
pipe-alias form when the slug does not fit the sentence grammatically — the target is still the
slug, only the visible text changes:

```markdown
building [[cross-calibration-advocacy|advocates who know your work]] before calibration
```

Aliases are for prose only; frontmatter lists take bare slugs.

**The resolution rule, which agents break constantly:** only link to a slug that already exists. The
extractor may link only to slugs present in `wiki/index.md`; the formatter may link only to slugs in
the page's own `related:` frontmatter. Left unconstrained, an agent will invent a plausible slug that
no file matches. [../scripts/lint-wiki.sh](../scripts/lint-wiki.sh) catches the dead ends after the
fact; the constraint prevents them.

## Tags

Three mechanisms, three jobs: **tags** are a flat, cross-cutting axis for retrieval; **topic hubs**
are curated arguments; **`related`** is a page-to-page relationship. Do not use a tag to do a hub's
job. Keeping the vocabulary from sprawling is ongoing work, not a one-off decision:

- Start from your `{{SEED_TAGS}}` list and treat every addition as deliberate.
- 3–6 tags per page. More than that means the tags are describing sentences, not subjects.
- Prefer an existing tag over a near-synonym. `influence` and `influencing` are one tag.
- Pick singular or plural per concept and never mix.
- When a tag reaches 8–10 entries, that is the signal to promote it to a topic hub.
- Review the vocabulary in every lint pass. To see what you actually have:

```sh
grep -h "^tags:" wiki/concepts/*.md | tr -d '[]' | cut -d: -f2 \
  | tr ',' '\n' | sed 's/^ *//' | sort | uniq -c | sort -rn
```

Anything with a count of 1 is either a mistake or a tag waiting to be merged.

## Index rows

`wiki/index.md` opens with a one-line purpose statement, then a Meta table, then one table per
page type. Canonical row format is two columns:

```markdown
| [glue-work](concepts/glue-work.md) | Coordination work that holds a team together but is nobody's formal deliverable |
```

Link text is the bare slug; the target is the path relative to `wiki/`. The reference
implementation's Sources table carries a third column (`File | Original | Type`) — a fine variant,
as long as every row has it.

The description is not decoration: it is the surface the extractor reads in Phase 1 to decide
whether an idea already exists. Write it as a **claim the page makes**, not a topic label. "Treat
your career as a business; you are the CEO and the product" is usable for duplicate detection;
"about careers" is not.

## Log entries

`wiki/log.md` is append-at-top: newest entry immediately under the file header, headed exactly

```markdown
## [2026-09-09] ingest | Batch 5 — 10 short sources, 19 new entries (session 17)
```

where type is one of `ingest`, `query`, `lint`, `maintenance`. The bracketed-date-first format is
not cosmetic — it is what makes recent history retrievable in one command, which is a step in every
session start (see [06-operations.md](06-operations.md)):

```sh
grep "^## \[" wiki/log.md | head -5
```

Under the heading, record the **reasoning**, not just the result: the batch tier and why, each source
and the entries it produced, entries dropped and what they duplicated, merges considered and
rejected, tensions flagged rather than resolved, hubs updated, and the counts before and after.
Otherwise a future session with none of your context re-litigates the same decisions.
[../examples/example-log-entry.md](../examples/example-log-entry.md) shows the detail to aim for.

## Changing a schema after you have pages

Expect to change something after your pilot ingest — that is what the pilot is for. Change this doc
first, then the affected files in `templates/pages/` and `templates/agents/`, then migrate existing
pages with `grep -rl` plus a targeted edit, then run
[../scripts/lint-wiki.sh](../scripts/lint-wiki.sh) over the whole wiki. Migrating 40 pages is an
afternoon; migrating 400 is a project. Settle the schema early.
