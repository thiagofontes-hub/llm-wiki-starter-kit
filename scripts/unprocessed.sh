#!/usr/bin/env bash
#
# unprocessed.sh — answer "what should I ingest next?"
# Lists every raw source that has no summary page yet, shortest first, and
# suggests the next batch. Read-only: it never writes inside the project.
#
set -euo pipefail

usage() {
  cat <<'EOF'
unprocessed.sh — list raw sources that have not been ingested yet, shortest first.

Usage:
  unprocessed.sh [-h|--help]

Output:
  1. one line per un-ingested source: word count, then path relative to the
     project root, sorted ascending by word count;
  2. a suggested next batch (size and tier), derived from the word count of the
     largest source in the batch.

A source counts as processed when some page in <WIKI_DIR>/sources carries it in
its "source_file:" frontmatter field. Summary filenames are slugs and do not
match the original filenames, so filename matching would be wrong. Matching is
on the basename of source_file:, so moving a source into the processed folder
does not make it look un-ingested again.

Batch tiers (see docs/02-ingestion-protocol.md):

  short    < 1,500 words          up to 10 sources
  medium   1,500 - 4,000 words    5 - 7 sources
  long     > 4,000 words          3 - 4 sources

A batch that mixes lengths takes the tier of its longest source, so the
suggestion is the biggest n (n <= 10) where n is still allowed by the tier of
the n-th shortest candidate.

Configuration (environment variables, all optional):

  PROJECT_ROOT    project root                 (default: current directory)
  SOURCE_DIR      raw source folder            (default: raw)
  WIKI_DIR        wiki folder                  (default: wiki)
  SOURCE_GLOB     filename pattern for sources (default: *.md)

Examples:

  unprocessed.sh
  PROJECT_ROOT=~/Documents/GitHub/LoreOS unprocessed.sh
  SOURCE_DIR="original content" unprocessed.sh | head -20
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) printf 'unprocessed.sh: unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
SOURCE_DIR="${SOURCE_DIR:-raw}"
WIKI_DIR="${WIKI_DIR:-wiki}"
SOURCE_GLOB="${SOURCE_GLOB:-*.md}"

src_dir="$PROJECT_ROOT/$SOURCE_DIR"
sum_dir="$PROJECT_ROOT/$WIKI_DIR/sources"

die() { printf 'unprocessed.sh: %s\n' "$1" >&2; exit 1; }

[ -d "$src_dir" ] || die "raw source directory not found: $src_dir (set PROJECT_ROOT / SOURCE_DIR)"
[ -d "$sum_dir" ] || die "source-summary directory not found: $sum_dir (set WIKI_DIR, or run scaffold.sh)"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/unprocessed.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

# Fold a filename to a loose key so that punctuation and encoding differences
# (curly vs straight apostrophes, NFC vs NFD) do not create false positives.
loose_key() { printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -cd 'a-z0-9'; }

# --- which sources are already ingested -------------------------------------
: > "$tmp/keys"
summaries=0
while IFS= read -r page; do
  [ -n "$page" ] || continue
  summaries=$((summaries + 1))
  raw=$(grep -m1 '^source_file:' "$page" 2>/dev/null || true)
  [ -n "$raw" ] || continue
  raw=${raw#source_file:}
  raw=$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
  [ -n "$raw" ] || continue
  printf 'E:%s\n' "${raw##*/}" >> "$tmp/keys"
  printf 'L:%s\n' "$(loose_key "${raw##*/}")" >> "$tmp/keys"
done <<EOF
$(find "$sum_dir" -type f -name '*.md' -print)
EOF

# --- candidates --------------------------------------------------------------
: > "$tmp/todo"
total=0
done_count=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  total=$((total + 1))
  base=${file##*/}
  if grep -Fxq "E:$base" "$tmp/keys" || grep -Fxq "L:$(loose_key "$base")" "$tmp/keys"; then
    done_count=$((done_count + 1))
    continue
  fi
  words=$(wc -w < "$file" | tr -d ' ')
  printf '%s\t%s\n' "$words" "${file#$PROJECT_ROOT/}" >> "$tmp/todo"
done <<EOF
$(find "$src_dir" -type f -name "$SOURCE_GLOB" -print)
EOF

tab=$(printf '\t')
LC_ALL=C sort -t "$tab" -k1,1n -k2,2 "$tmp/todo" > "$tmp/sorted"
pending=$(wc -l < "$tmp/sorted" | tr -d ' ')

printf 'Source backlog in %s\n' "$src_dir"
printf 'Summary pages: %d   sources seen: %d   ingested: %d   pending: %d\n\n' \
  "$summaries" "$total" "$done_count" "$pending"

if [ "$total" -eq 0 ]; then
  printf 'No files matching %s in %s. Add raw material there and re-run.\n' "$SOURCE_GLOB" "$SOURCE_DIR"
  exit 0
fi

if [ "$pending" -eq 0 ]; then
  printf 'Nothing pending. Every source in %s already has a summary page.\n' "$SOURCE_DIR"
  exit 0
fi

printf '%7s  %s\n' "WORDS" "SOURCE"
awk -F'\t' '{ printf "%7d  %s\n", $1, $2 }' "$tmp/sorted"

# --- batch suggestion --------------------------------------------------------
tier_of() {
  if [ "$1" -lt 1500 ]; then printf 'short'
  elif [ "$1" -le 4000 ]; then printf 'medium'
  else printf 'long'; fi
}
ceiling_of() {
  case "$1" in
    short) printf '10' ;;
    medium) printf '7' ;;
    *) printf '4' ;;
  esac
}
range_of() {
  case "$1" in
    short) printf 'up to 10' ;;
    medium) printf '5 - 7' ;;
    *) printf '3 - 4' ;;
  esac
}
span_of() {
  case "$1" in
    short) printf '< 1,500' ;;
    medium) printf '1,500 - 4,000' ;;
    *) printf '> 4,000' ;;
  esac
}

n=0
batch=0
batch_tier=short
batch_words=0
batch_file=""
while IFS= read -r line; do
  n=$((n + 1))
  [ "$n" -le 10 ] || break
  words=${line%%$tab*}
  this_tier=$(tier_of "$words")
  if [ "$n" -le "$(ceiling_of "$this_tier")" ]; then
    batch=$n
    batch_tier=$this_tier
    batch_words=$words
    batch_file=${line#*$tab}
  else
    break
  fi
done < "$tmp/sorted"

printf '\nSuggested next batch: %d source(s)\n' "$batch"
printf '  tier              %s (%s words per source, batch %s)\n' \
  "$batch_tier" "$(span_of "$batch_tier")" "$(range_of "$batch_tier")"
printf '  largest in batch  %d words - %s\n' "$batch_words" "$batch_file"
printf '  rule              a mixed batch takes the tier of its longest source\n'
