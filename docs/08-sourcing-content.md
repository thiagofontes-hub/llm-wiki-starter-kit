# Sourcing content

Everything upstream of Phase 1: how raw material becomes a markdown file in `raw/`, and what you do
to that folder before you let an extractor near it. The pipeline itself is in
[02-ingestion-protocol.md](02-ingestion-protocol.md); the failures behind the rules here are in
[07-lessons-learned.md](07-lessons-learned.md).

## What an ingestable source looks like

| Property | Target |
| --- | --- |
| Format | Markdown, `.md`, one extension across the whole folder |
| Shape | One author, one artefact, prose you could read start to finish |
| Length | ~300 to ~8,000 words; longer needs splitting |
| Filename | The real title, no spaces, no curly apostrophes |
| Location | `raw/`, flat, never modified after arrival |

Anything that fails the length or shape test is not unusable — it needs preparation first
(splitting) or triage out of the queue (link indexes). Anything that fails the format or filename
test should be fixed on arrival, because the filename is recorded in every source summary's
`source_file:` field and renaming after ingest breaks provenance.

## Capture routes by medium

| Medium | Route | Watch for |
| --- | --- | --- |
| Web article | A browser markdown clipper (MarkDownload, Obsidian Web Clipper, or your reader's "copy as markdown") | Failed iframes, cookie banners, paywall stubs, navigation cruft at the top |
| Long-form newsletter | Open the web version and clip that, not the email | Tracking-pixel noise, subscribe blocks mid-article |
| YouTube video | The transcript panel under the video, or `yt-dlp` subtitles | Auto-captions have no punctuation or speaker labels |
| Podcast | Published transcript if there is one; otherwise transcribe the audio locally | 60 minutes of speech is 9,000–11,000 words — Long tier, 3–4 per batch |
| PDF or paper | `pdftotext -layout`, then wrap in markdown | Two-column layouts interleave into nonsense; check the first page |
| Ebook (EPUB) | `pandoc` per chapter | Always split; see below |
| Interview or your own notes | Paste into a new `.md` file with a title heading | Give it a real filename immediately |

Typical commands, all run from `raw/`:

```sh
# YouTube: subtitles only, no video
yt-dlp --write-auto-subs --skip-download --sub-format vtt --sub-langs en "<url>"

# PDF: preserve column layout; output is plain text, so tidy the headings afterwards
pdftotext -layout "paper.pdf" "author-year-short-title.md"

# EPUB: one chapter per file
pandoc --to=markdown --wrap=none "book.epub" -o "book.md"
```

Auto-generated captions are worth a cleanup pass before ingest: no punctuation means the extractor
has to guess sentence boundaries, and it will guess badly on long monologues. Ask your agent to
punctuate and paragraph the transcript, keeping the words unchanged, and save that as the source.

Check the exact flags with `--help` before relying on any of these; subtitle and conversion tools
change options often.

## Very long files must be split before ingest

The unit of ingestion is one source file, one summary page, a handful of entries. A book breaks that
at every level: it will not fit in an extractor's context, and one summary page for 200,000 words
tells you nothing. The reference corpus contained nine such files — up to 230,000 words each, one
bundling six separate books and another bundling sixteen.

Split at chapter boundaries into one file per chapter:

```sh
# 1. Convert the whole book to one markdown file
pandoc --to=markdown --wrap=none "book.epub" -o "book-full.md"

# 2. Split that file on its top-level headings, one file per chapter
awk '/^# /{n++} n>0 {print > sprintf("book-ch%02d.md", n)}' "book-full.md"
```

Then rename each output to `book-slug-ch03-chapter-title.md` so the ordering and the provenance
survive, and treat each chapter as an ordinary source in the queue. A ten-chapter book is three or
four ingest sessions. Create a topic hub for the book so the chapters reassemble into one argument.

If you are not ready to do that, move the file to the oversized triage folder and get on with
shorter material. Splitting badly is worse than deferring.

## Filename hygiene

| Rule | Why |
| --- | --- |
| One extension: `.md` | Mixed extensions silently fail to index |
| No spaces in filenames or directory names | Argument parsers split on them and drop the remainder |
| No curly apostrophes (`’`, U+2019) | The Read tool cannot match the path |
| Rename scraper timestamps on arrival | `page-2026-05-03.md` carries no provenance |
| Never rename after ingest | `source_file:` in the source summary points at the old name |

Normalise a fresh batch of captures in one pass. Print first, then run for real:

```sh
cd "$PROJECT_ROOT/raw" || exit 1
for f in *.md; do
  new=${f//’/}          # drop curly apostrophes
  new=${new// /-}       # spaces to hyphens
  [ "$f" = "$new" ] || echo mv -- "$f" "$new"
done
```

Drop the `echo` once the output looks right. Scraper-timestamped files need a human decision — open
each one, read the first heading, and rename to that.

## Pre-ingest triage routine

Run this over `raw/` before the first ingest, and again after every batch of new captures. It takes
a few minutes and prevents most of the rework described in
[07-lessons-learned.md](07-lessons-learned.md).

1. **Sweep for byte-identical duplicates.** Fifteen went unnoticed in the reference corpus, some
   after being ingested.

   ```sh
   cd "$PROJECT_ROOT/raw" || exit 1
   shasum -a 256 *.md | sort | awk '{g[$1]=g[$1]" "$2} END {
     for (h in g) if (split(g[h], a, " ") > 1) print h ":" g[h] }'
   ```

   Keep one copy of each group. Prefer the one with the cleanest filename.

2. **Look for near-duplicate snapshots.** `ls` and scan for ` (1).md`, ` (2).md` and same-title
   variants. These are repeat captures of a page taken on different dates; keep the longest, or keep
   both only if the content genuinely differs.

3. **Sort by word count.** This sets your batch size and your reading order. Use
   [`scripts/unprocessed.sh`](../scripts/unprocessed.sh), which lists unprocessed sources ascending
   by words and skips anything already summarised in `wiki/sources/`.

4. **Spot-check the shortest files for broken captures.** The bottom of the word-count list is where
   stubs live.

   ```sh
   wc -w *.md | sort -n | head -15
   grep -l -i "cross-origin\|iframe\|enable javascript\|subscribe to continue" *.md
   ```

   A file under ~200 words that also carries one of those markers is a stub — recapture or drop it.
   The marker on its own means almost nothing: 41 files in the reference corpus had it and were
   completely readable, the shortest of them at 437 words.

5. **Catch unconverted HTML.** `grep -l "<div" *.md` finds captures that kept their markup. Reclip
   or convert them; do not hand raw HTML to an extractor.

6. **Move link indexes and oversized files out.** See the next section.

7. **Confirm the queue.** `ls *.md | wc -l` — this number is your backlog, and it belongs in
   `handover.md` so the next session knows the shape of the remaining work.

## The two triage folders

Create these as siblings of `raw/` the first time you need them, so the search collection glob
(`raw/**/*.md`) does not pick them up and the librarian does not queue them:

| Folder | What belongs in it | Exit condition |
| --- | --- | --- |
| `raw-index-pages/` | Blog rolls, author archives, search-result pages, awesome-list READMEs, tag listings — pages that are lists of links with a teaser sentence each | The individual articles they point to get captured properly; then this file becomes a shopping list, not a source |
| `raw-oversized/` | Single files far past the Long tier: books, multi-book bundles, whole-site dumps | Split at chapter boundaries into `raw/`, then delete or leave the original here |

These two names are what `scripts/scaffold.sh` creates and what the rendered `CLAUDE.md` and
`handover.md` refer to, so changing them means changing all three. The reference implementation
used `index-pages-to-research/` and `oversized-books-for-later/`, and moved eight and nine files
into them respectively. Whatever you call them, record them in your `CLAUDE.md` map of contents
with a note that they are excluded from the batch queue — otherwise a future session will find
them and try to ingest them.

Do not delete triaged files. An index page is a list of things worth capturing later, and an
oversized book is content you already own.

## What is not worth ingesting

- **Link indexes.** No extractable argument. Triage, as above.
- **Paywall stubs.** Two paragraphs and a subscribe prompt. Recapture from a version you can read,
  or drop.
- **Off-domain material caught in the same scrape.** The reference corpus contained a verbatim job
  posting that produced zero entries. If it is not in your domain, it is not a source, however
  interesting it is.
- **Marketing and landing pages.** Product copy, conference blurbs, book sales pages.
- **Second formats of something already ingested.** The video and the article version of the same
  talk will yield the same entries. Ingest one, reinforce from the other only if it genuinely adds.
- **Anything you would not cite.** If you would not point a colleague at it, its ideas do not belong
  in a wiki you will trust in six months.
- **Your own already-atomic notes.** These are not sources to extract from — write them straight
  into the wiki as entries via the query path in [06-operations.md](06-operations.md).

Off-domain fit is a judgement call, and it is yours, not your agent's. Make it once, and record the
decision in `log.md` so it does not get re-argued. The reference implementation flagged two books as
questionable fits and deliberately deferred the decision rather than deleting them.

## Where sources live, and when they move

| State | Location | Rule |
| --- | --- | --- |
| Captured, not ingested | `raw/` | Immutable after the arrival rename; committed to git |
| Triaged out | `raw-index-pages/`, `raw-oversized/` | Excluded from the queue and from search |
| Ingested | `raw-processed/` | Moved during Phase 5; gitignored |

A source counts as processed when `wiki/sources/<slug>.md` exists. That file, not the folder, is the
record — the move is housekeeping so the queue only ever shows real work.
