#!/usr/bin/env bash
#
# lint-wiki.sh — health check for an LLM-maintained wiki.
# Read-only: it reports, it never edits, moves or deletes anything.
#
set -euo pipefail

usage() {
  cat <<'EOF'
lint-wiki.sh — report structural problems in an LLM-maintained wiki.

Usage:
  lint-wiki.sh [-h|--help]

Checks (the first three are gates: any hit exits 1):

  1. broken wikilinks      [[slug]] with no matching <slug>.md anywhere in the wiki
  2. orphan pages          pages with no inbound wikilink from another page
  3. missing frontmatter   entry pages lacking a required frontmatter field
  4. not in index.md       entry pages the master index never lists
  5. very short pages      pages under MIN_LINES lines - usually a failed write
  6. unwired hub entries   topic hubs listing an entry in frontmatter that the
                           hub body never links (a hub must argue, not list)

It then prints a summary table and exits 1 if any gate check found something,
0 otherwise. Nothing inside the project is ever written.

Conventions it assumes (see docs/03-page-schemas.md):

  - wikilinks are Foam style, [[slug]] or [[slug|display text]];
  - slug comparison is case-insensitive, matching Foam's own resolution;
  - ROOT_PAGES (index.md, log.md, CLAUDE.md, README.md) are infrastructure:
    never reported as orphans, and their wikilinks do not count as inbound
    links, so an entry mentioned only in log.md is still an orphan;
  - the topic-hub entry list is the frontmatter field "entries:", falling back
    to "<ENTRY_DIR>:" for wikis that name the field after the entry noun.

Configuration (environment variables, all optional):

  PROJECT_ROOT      project root                       (default: current directory)
  WIKI_DIR          wiki folder                        (default: wiki)
  ENTRY_DIR         atomic-entry folder                (default: concepts)
  TOPIC_DIR         topic-hub folder                   (default: topics)
  SOURCE_PAGE_DIR   source-summary folder              (default: sources)
  REQUIRED_FIELDS   required entry frontmatter fields  (default: "title tags sources related")
  ROOT_PAGES        pages exempt from the orphan check (default: "index.md log.md CLAUDE.md README.md")
  MIN_LINES         short-page threshold               (default: 10)
  MAX_LIST          offenders printed per check, 0 = all (default: 15)

Examples:

  lint-wiki.sh
  PROJECT_ROOT=~/Documents/GitHub/LoreOS ENTRY_DIR=findings lint-wiki.sh
  MAX_LIST=0 lint-wiki.sh > lint-report.txt
  REQUIRED_FIELDS="title tags source related" lint-wiki.sh
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) printf 'lint-wiki.sh: unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
WIKI_DIR="${WIKI_DIR:-wiki}"
ENTRY_DIR="${ENTRY_DIR:-concepts}"
TOPIC_DIR="${TOPIC_DIR:-topics}"
SOURCE_PAGE_DIR="${SOURCE_PAGE_DIR:-sources}"
REQUIRED_FIELDS="${REQUIRED_FIELDS:-title tags sources related}"
ROOT_PAGES="${ROOT_PAGES:-index.md log.md CLAUDE.md README.md}"
MIN_LINES="${MIN_LINES:-10}"
MAX_LIST="${MAX_LIST:-15}"

wiki="$PROJECT_ROOT/$WIKI_DIR"
index="$wiki/index.md"

die() { printf 'lint-wiki.sh: %s\n' "$1" >&2; exit 1; }

[ -d "$wiki" ] || die "wiki directory not found: $wiki (set PROJECT_ROOT / WIKI_DIR)"
[ -d "$wiki/$ENTRY_DIR" ] || die "entry directory not found: $wiki/$ENTRY_DIR (set ENTRY_DIR)"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/lint-wiki.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

# Pulls every [[wikilink]] out of every file it is given, one per line, as
# "path-relative-to-project-root <TAB> lower-cased slug". Display text after |
# and #anchors are stripped.
LINK_AWK='
FNR==1 { rel = FILENAME; if (index(rel, root) == 1) rel = substr(rel, length(root) + 1) }
{
  line = $0
  while (match(line, /\[\[[^]]*\]\]/) > 0) {
    t = substr(line, RSTART + 2, RLENGTH - 4)
    line = substr(line, RSTART + RLENGTH)
    sub(/\|.*$/, "", t); sub(/#.*$/, "", t)
    gsub(/^[ \t]+/, "", t); gsub(/[ \t]+$/, "", t)
    if (t != "") print rel "\t" tolower(t)
  }
}'

frontmatter() {
  awk 'NR==1 { if ($0 !~ /^---[[:space:]]*$/) exit; next }
       /^---[[:space:]]*$/ { exit }
       { print }' "$1"
}

body_of() {
  awk 'NR==1 && /^---[[:space:]]*$/ { fm=1; next }
       fm==1 && /^---[[:space:]]*$/ { fm=0; next }
       fm==0 { print }' "$1"
}

# A frontmatter field plus any indented continuation lines, read from stdin.
field_block() {
  awk -v pat="$1" '
    $0 ~ "^" pat ":" { grab=1; print; next }
    grab && /^[[:space:]]/ { print; next }
    grab { exit }'
}

# Wikilink slugs found in the file named by $1, space-delimited and space-padded
# so that a plain case match can test membership.
slug_set() {
  printf ' %s ' "$(awk -v root="" "$LINK_AWK" "$1" | cut -f2 | LC_ALL=C sort -u | tr '\n' ' ')"
}

show() { # show <file-of-lines>
  if [ "$MAX_LIST" -gt 0 ]; then
    head -n "$MAX_LIST" "$1" | sed 's/^/    /'
    extra=$(( $(wc -l < "$1") - MAX_LIST ))
    if [ "$extra" -gt 0 ]; then printf '    ... and %d more\n' "$extra"; fi
  else
    sed 's/^/    /' "$1"
  fi
}

count_of() { wc -l < "$1" | tr -d ' '; }

find_md() { find "$1" -type f -name '*.md' -print; }

# --- inventory ---------------------------------------------------------------
find_md "$wiki" | LC_ALL=C sort > "$tmp/pages.txt"
[ -s "$tmp/pages.txt" ] || die "no markdown pages under $wiki - is WIKI_DIR right?"

awk -v root="$PROJECT_ROOT/" '{
  p = $0
  rel = p; if (index(rel, root) == 1) rel = substr(rel, length(root) + 1)
  n = split(p, a, "/"); b = a[n]; sub(/\.md$/, "", b)
  print tolower(b) "\t" rel
}' "$tmp/pages.txt" > "$tmp/pages.tsv"

tr '\n' '\000' < "$tmp/pages.txt" |
  xargs -0 awk -v root="$PROJECT_ROOT/" "$LINK_AWK" > "$tmp/links.tsv"

pages_total=$(count_of "$tmp/pages.tsv")
entries_total=$(find_md "$wiki/$ENTRY_DIR" | wc -l | tr -d ' ')
topics_total=0
sources_total=0
if [ -d "$wiki/$TOPIC_DIR" ]; then topics_total=$(find_md "$wiki/$TOPIC_DIR" | wc -l | tr -d ' '); fi
if [ -d "$wiki/$SOURCE_PAGE_DIR" ]; then sources_total=$(find_md "$wiki/$SOURCE_PAGE_DIR" | wc -l | tr -d ' '); fi
links_total=$(count_of "$tmp/links.tsv")

printf 'Linting %s\n' "$wiki"
printf 'Pages %d | entries %d | topic hubs %d | source summaries %d | wikilinks %d\n\n' \
  "$pages_total" "$entries_total" "$topics_total" "$sources_total" "$links_total"

# --- 1. broken wikilinks -----------------------------------------------------
cut -f2 "$tmp/links.tsv" | LC_ALL=C sort -u > "$tmp/linked.slugs"
cut -f1 "$tmp/pages.tsv" | LC_ALL=C sort -u > "$tmp/page.slugs"
LC_ALL=C comm -23 "$tmp/linked.slugs" "$tmp/page.slugs" > "$tmp/broken.slugs"

awk -F'\t' '
  FNR==NR { broken[$0] = 1; next }
  $2 in broken { if (!seen[$2 "\t" $1]++) { refs[$2] = refs[$2] == "" ? $1 : refs[$2]; n[$2]++ } }
  END { for (s in n) printf "[[%s]] - first referenced by %s (%d referring page(s))\n", s, refs[s], n[s] }
' "$tmp/broken.slugs" "$tmp/links.tsv" | LC_ALL=C sort > "$tmp/report.broken"
n_broken=$(count_of "$tmp/report.broken")

printf '1. Broken wikilinks: %d\n' "$n_broken"
if [ "$n_broken" -gt 0 ]; then show "$tmp/report.broken"; fi
printf '\n'

# --- 2. orphan pages ---------------------------------------------------------
awk -F'\t' -v roots="$ROOT_PAGES" '
  BEGIN { k = split(roots, r, " "); for (i = 1; i <= k; i++) isroot[r[i]] = 1 }
  FNR==NR { path[$1] = $2; next }
  {
    m = split($1, a, "/")
    if (isroot[a[m]]) next
    if ($1 != path[$2]) inbound[$2] = 1
  }
  END {
    for (s in path) {
      m = split(path[s], b, "/")
      if (isroot[b[m]]) continue
      if (!(s in inbound)) print path[s]
    }
  }' "$tmp/pages.tsv" "$tmp/links.tsv" | LC_ALL=C sort > "$tmp/report.orphans"
n_orphans=$(count_of "$tmp/report.orphans")

printf '2. Orphan pages (no inbound wikilink): %d\n' "$n_orphans"
if [ "$n_orphans" -gt 0 ]; then show "$tmp/report.orphans"; fi
printf '\n'

# --- 3. entry pages missing required frontmatter -----------------------------
find_md "$wiki/$ENTRY_DIR" | LC_ALL=C sort > "$tmp/entries.txt"
: > "$tmp/report.frontmatter"
while IFS= read -r page; do
  [ -n "$page" ] || continue
  have=" $(frontmatter "$page" | sed -n 's/^\([A-Za-z_][A-Za-z0-9_-]*\):.*/\1/p' | tr '\n' ' ')"
  missing=""
  for f in $REQUIRED_FIELDS; do
    case "$have" in
      *" $f "*) ;;
      *) missing="$missing $f" ;;
    esac
  done
  if [ -n "$missing" ]; then
    printf '%s -- missing:%s\n' "${page#$PROJECT_ROOT/}" "$missing" >> "$tmp/report.frontmatter"
  fi
done < "$tmp/entries.txt"
n_fm=$(count_of "$tmp/report.frontmatter")

printf '3. Entry pages missing frontmatter (%s): %d\n' \
  "$(printf '%s' "$REQUIRED_FIELDS" | tr ' ' ',')" "$n_fm"
if [ "$n_fm" -gt 0 ]; then show "$tmp/report.frontmatter"; fi
printf '\n'

# --- 4. entry pages not listed in index.md -----------------------------------
: > "$tmp/report.unlisted"
index_note=""
if [ -f "$index" ]; then
  # Slugs the index mentions, via markdown links and via wikilinks.
  awk '{
    line = $0
    while (match(line, /\]\([^)]*\)/) > 0) {
      t = substr(line, RSTART + 2, RLENGTH - 3)
      line = substr(line, RSTART + RLENGTH)
      n = split(t, a, "/"); b = a[n]; sub(/\.md$/, "", b)
      if (b != "") print tolower(b)
    }
    line = $0
    while (match(line, /\[\[[^]]*\]\]/) > 0) {
      t = substr(line, RSTART + 2, RLENGTH - 4)
      line = substr(line, RSTART + RLENGTH)
      sub(/\|.*$/, "", t)
      if (t != "") print tolower(t)
    }
  }' "$index" | LC_ALL=C sort -u > "$tmp/index.slugs"
  awk -F'\t' -v dir="$WIKI_DIR/$ENTRY_DIR/" '
    FNR==NR { listed[$0] = 1; next }
    index($2, dir) == 1 && !($1 in listed) { print $2 }
  ' "$tmp/index.slugs" "$tmp/pages.tsv" | LC_ALL=C sort > "$tmp/report.unlisted"
else
  index_note=" (skipped: $index not found)"
fi
n_unlisted=$(count_of "$tmp/report.unlisted")

printf '4. Entry pages not in index.md: %d%s\n' "$n_unlisted" "$index_note"
if [ "$n_unlisted" -gt 0 ]; then show "$tmp/report.unlisted"; fi
printf '\n'

# --- 5. suspiciously short pages ---------------------------------------------
: > "$tmp/content.txt"
for dir in "$ENTRY_DIR" "$TOPIC_DIR" "$SOURCE_PAGE_DIR"; do
  if [ -d "$wiki/$dir" ]; then find_md "$wiki/$dir" >> "$tmp/content.txt"; fi
done
LC_ALL=C sort "$tmp/content.txt" -o "$tmp/content.txt"
tr '\n' '\000' < "$tmp/content.txt" | xargs -0 wc -l |
  awk -v min="$MIN_LINES" -v root="$PROJECT_ROOT/" '{
    lines = $1
    sub(/^[ \t]*[0-9]+[ \t]+/, "")
    if ($0 == "total" || $0 == "") next
    rel = $0; if (index(rel, root) == 1) rel = substr(rel, length(root) + 1)
    if (lines + 0 < min + 0) printf "%s (%d lines)\n", rel, lines
  }' > "$tmp/report.short"
n_short=$(count_of "$tmp/report.short")

printf '5. Pages under %d lines: %d\n' "$MIN_LINES" "$n_short"
if [ "$n_short" -gt 0 ]; then show "$tmp/report.short"; fi
printf '\n'

# --- 6. hub entries the hub body never links ---------------------------------
: > "$tmp/report.unwired"
if [ -d "$wiki/$TOPIC_DIR" ]; then
  while IFS= read -r hub; do
    [ -n "$hub" ] || continue
    frontmatter "$hub" > "$tmp/fm"
    block=$(field_block entries < "$tmp/fm")
    [ -n "$block" ] || block=$(field_block "$ENTRY_DIR" < "$tmp/fm")
    [ -n "$block" ] || continue
    body_of "$hub" > "$tmp/body"
    wired=$(slug_set "$tmp/body")
    printf '%s\n' "$block" > "$tmp/block"
    listed=$(awk -v root="" "$LINK_AWK" "$tmp/block" | cut -f2 | LC_ALL=C sort -u)
    unwired=""
    count=0
    for slug in $listed; do
      case "$wired" in
        *" $slug "*) continue ;;
      esac
      count=$((count + 1))
      if [ "$count" -le 4 ]; then unwired="$unwired $slug"; fi
    done
    if [ "$count" -gt 0 ]; then
      more=""
      if [ "$count" -gt 4 ]; then more=" (+$((count - 4)) more)"; fi
      printf '%s -- %d unwired:%s%s\n' "${hub#$PROJECT_ROOT/}" "$count" "$unwired" "$more" >> "$tmp/report.unwired"
    fi
  done <<EOF
$(find_md "$wiki/$TOPIC_DIR" | LC_ALL=C sort)
EOF
fi
n_unwired=$(count_of "$tmp/report.unwired")

printf '6. Topic hubs with unwired entries: %d\n' "$n_unwired"
if [ "$n_unwired" -gt 0 ]; then show "$tmp/report.unwired"; fi
printf '\n'

# --- summary -----------------------------------------------------------------
printf '%-36s %7s  %s\n' "CHECK" "COUNT" "GATE"
printf '%-36s %7d  %s\n' "1 broken wikilinks" "$n_broken" "fail"
printf '%-36s %7d  %s\n' "2 orphan pages" "$n_orphans" "fail"
printf '%-36s %7d  %s\n' "3 entries missing frontmatter" "$n_fm" "fail"
printf '%-36s %7d  %s\n' "4 entries not in index.md" "$n_unlisted" "warn"
printf '%-36s %7d  %s\n' "5 pages under $MIN_LINES lines" "$n_short" "warn"
printf '%-36s %7d  %s\n' "6 hubs with unwired entries" "$n_unwired" "warn"

gates=$((n_broken + n_orphans + n_fm))
if [ "$gates" -gt 0 ]; then
  printf '\nFAIL: %d gate problem(s). Fix these before the next ingest.\n' "$gates"
  exit 1
fi

printf '\nPASS: no gate problems. Warnings above are integration debt, not corruption.\n'
exit 0
