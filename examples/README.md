# Examples

**Warning about the content.** These five files are verbatim pages from the reference
implementation: a wiki about corporate careers, influence and personal effectiveness, built over
17 sessions to 328 entries, 81 source summaries and 12 topic hubs. That is almost certainly not
your domain. Read them for **form, not content** — sentence shape, restraint, how links carry an
argument, what gets recorded and what gets left out. Nothing about promotions or corporate
politics is part of the system. Do not edit these files; blank skeletons to fill in live in
`../templates/pages/`, and the rules they follow are in
[`../docs/03-page-schemas.md`](../docs/03-page-schemas.md).

| File | Page type | Origin in the reference implementation |
| --- | --- | --- |
| `example-entry.md` | Atomic entry | `wiki/concepts/nemawashi.md` |
| `example-source-summary.md` | Source summary | `wiki/sources/being-glue.md` |
| `example-topic-hub.md` | Topic hub | `wiki/topics/career-advancement-strategy.md` |
| `example-log-entry.md` | Log entry | one entry from `wiki/log.md`, with the file header |
| `example-index.md` | Master index | an excerpt of `wiki/index.md` |

The reference implementation's entry noun is "concept", so its files say `concepts_extracted:`,
`concepts:` and `## Related concepts`; the kit generalises those names to your own entry noun.
Its raw folder is `original content/` where the kit defaults to `raw/`.

## example-entry.md — the atomic entry

Look at the opening sentence. It names the idea, translates it and states the practice in one
move; there is no run-up, no "this concept describes". A reader who stops after line one has the
idea.

Look at the restraint: 29 lines including frontmatter. Prose carries the argument, the single
bullet list appears only where the content genuinely is a sequence of actions, bold is spent once
on the rule of thumb worth remembering, and there is no heading at all until the closing section.

Look at the linking. The first mention of a related page is wikilinked in the body where it does
work — `[[influence-map]]` inside the sentence that needs it. The closing `## Related concepts`
section draws only on the `related:` frontmatter, and each bullet states the *relationship*, not
the other page's definition. Body prose may link pages outside `related:` (`[[trust-capital]]`
here); the Related section may not.

## example-source-summary.md — the source summary

`source_file:` records the exact original filename. That field, not the page's own filename, is
how [`../scripts/unprocessed.sh`](../scripts/unprocessed.sh) knows a source is done — summary
filenames are slugs and never match the original.

The Summary is honest about capture quality: the talk's slides and video sat behind a
cross-origin iframe, so only the abstract was processed. Recording what you did *not* get stops a
future session treating a stub as a fully mined source. Key Contributions lists only the entries
this source created; Entries Reinforced lists existing pages it strengthens, one line each on
what is added. That split is what keeps near-duplicate pages out of the wiki.

## example-topic-hub.md — the topic hub

The important thing: it **argues**. The `##` sections are stages of a case — the mindset shift,
why hard work alone stalls, the promotion mechanism, then the conversation — and each entry is
wired into a sentence saying how it bears on the one before it, sometimes with piped display
text, `[[nine-box-model|potential axis]]`, so the link reads as English.

A hub that were only a list of links would add nothing over the index, so frontmatter and body
must agree: check 6 of [`../scripts/lint-wiki.sh`](../scripts/lint-wiki.sh) reports entries a hub
claims in frontmatter but never mentions in prose. This one carries dozens of entries and closes
with a "See also" pointing at sibling hubs. It is long, and that is correct — the hub is the one
page allowed to synthesise.

## example-log-entry.md — the log entry

Read this for the **reasoning**, not the result. It records the batch tier and why, which sources
yielded nothing and why (incomplete captures, a job posting mistaken for an article), which
listing pages were excluded — and, the part that matters, a quality-review note explaining that
three candidate entries were dropped because each overlapped a *different* existing entry, and
that merging them was considered and rejected because the result would have been a grab-bag
rather than one atomic idea. It also flags a genuine tension between two entries and leaves both
live instead of picking a winner.

That is what stops a later session re-litigating a settled decision, which is why
[`../docs/07-lessons-learned.md`](../docs/07-lessons-learned.md) makes logging the reasoning a
rule. The entry closes with page counts before and after, so growth stays auditable.

## example-index.md — the master index

An excerpt: the entry table shows three of several hundred rows (the `...` marks the cut) and the
file stops at the `## Sources` heading, so that table is missing altogether. The Topics table is
complete, all twelve hubs.

Rows are `| [slug](path) | one-line description |`, and the descriptions are claims rather than
categories — "treat your career as a business; you are the CEO and the product", not "career".
That matters because the index is the duplicate-detection surface: in Phase 1 the extractor reads
this file to decide whether an idea is new, so a vague description buys a duplicate page. Read
the twelve topic descriptions to see a hub's scope stated in one line.

Next: [`../docs/03-page-schemas.md`](../docs/03-page-schemas.md) for the rules these pages
follow, and [`../docs/02-ingestion-protocol.md`](../docs/02-ingestion-protocol.md) for who writes
each of them and when.
