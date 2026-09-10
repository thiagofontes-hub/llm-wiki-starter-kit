#!/usr/bin/env bash
#
# scaffold.sh — create the directory skeleton of an LLM-maintained wiki project.
# Creates directories only. Never creates, overwrites or deletes a file.
#
set -euo pipefail

usage() {
  cat <<'EOF'
scaffold.sh — create the directory skeleton of an LLM-maintained wiki project.

Usage:
  scaffold.sh [-h|--help]

Creates (idempotently, directories only — no files are written):

  <WIKI_DIR>/                    the compiled wiki
  <WIKI_DIR>/<ENTRY_DIR>/        atomic entries
  <WIKI_DIR>/topics/             topic hubs
  <WIKI_DIR>/sources/            one summary page per ingested source
  <SOURCE_DIR>/                  raw, immutable sources waiting to be ingested
  <PROCESSED_DIR>/               sources already ingested (git-ignored)
  <triage dirs>/                 material deliberately kept out of the queue
  .claude/agents/                the four specialist sub-agents
  .claude/commands/              slash commands (for example /end-session)
  resources/                     setup notes and tooling docs you keep locally

Configuration (environment variables, all optional):

  PROJECT_ROOT    project root to scaffold        (default: current directory)
  WIKI_DIR        wiki folder name                (default: wiki)
  ENTRY_DIR       atomic-entry folder name        (default: concepts)
  SOURCE_DIR      raw source folder name          (default: raw)
  PROCESSED_DIR   processed source folder name    (default: raw-processed)
  TRIAGE_DIRS     newline- or space-separated list of triage folders
                  (default: "raw-index-pages raw-oversized")

Examples:

  scaffold.sh
  PROJECT_ROOT="$HOME/Documents/GitHub/LoreOS" ENTRY_DIR=findings scaffold.sh
  TRIAGE_DIRS="triage-linkpages triage-oversized" scaffold.sh

Files are written afterwards by rendering the kit's templates/ into these
directories — see SETUP.md. Triage folders are explained in
docs/08-sourcing-content.md.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) printf 'scaffold.sh: unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
WIKI_DIR="${WIKI_DIR:-wiki}"
ENTRY_DIR="${ENTRY_DIR:-concepts}"
SOURCE_DIR="${SOURCE_DIR:-raw}"
PROCESSED_DIR="${PROCESSED_DIR:-raw-processed}"
TRIAGE_DIRS="${TRIAGE_DIRS:-raw-index-pages raw-oversized}"

if [ ! -d "$PROJECT_ROOT" ]; then
  printf 'scaffold.sh: PROJECT_ROOT does not exist: %s\n' "$PROJECT_ROOT" >&2
  printf 'Create it first (mkdir -p), then re-run. This script only adds subdirectories.\n' >&2
  exit 1
fi

# TRIAGE_DIRS is split on whitespace on purpose, so triage folder names must not
# contain spaces. Globbing is off so that a stray * cannot expand to a path.
set -f
wanted=$(printf '%s\n' \
  "$WIKI_DIR" \
  "$WIKI_DIR/$ENTRY_DIR" \
  "$WIKI_DIR/topics" \
  "$WIKI_DIR/sources" \
  "$SOURCE_DIR" \
  "$PROCESSED_DIR" \
  $TRIAGE_DIRS \
  ".claude/agents" \
  ".claude/commands" \
  "resources")

created=0
existed=0

printf 'Scaffolding: %s\n\n' "$PROJECT_ROOT"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -d "$PROJECT_ROOT/$rel" ]; then
    printf '  exists   %s/\n' "$rel"
    existed=$((existed + 1))
  else
    mkdir -p "$PROJECT_ROOT/$rel"
    printf '  created  %s/\n' "$rel"
    created=$((created + 1))
  fi
done <<EOF
$wanted
EOF

printf '\nDirectories created: %d. Already present: %d.\n' "$created" "$existed"
printf 'No files were written. Next: render the kit templates (see SETUP.md).\n'
