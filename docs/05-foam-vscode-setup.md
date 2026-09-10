# Editing and navigation: VS Code and Foam

Your agent writes the wiki. Foam is how you read it — a VS Code extension that treats a folder of
markdown as a linked graph: it resolves `[[wikilinks]]`, shows what points at the page you are
reading, and draws the whole thing as a network. It writes nothing to your files unless you ask it
to, and the wiki works fine without it. Foam is the viewer that makes the links worth having.

## What Foam adds

| Feature | What it gives you here |
| --- | --- |
| Wikilink autocomplete | Type `[[` and get real slugs, so links you write by hand resolve |
| Navigation | `Cmd+Click` or `F12` on a wikilink opens that page |
| Backlinks (Connections panel) | Every page that references the one you are reading — the reverse index nobody maintains by hand |
| Graph view | Structural health at a glance: hubs, clusters, orphans |
| Tag Explorer | Browse the tag vocabulary as a tree, click a tag to list its pages |
| Note properties | Reads `title`, `type`, `tags` and `alias` from frontmatter |
| Placeholders panel | Wikilinks with no file behind them — your broken-link list |
| Link sync on rename | Rename a page and every `[[slug]]` pointing at it is rewritten |

Two matter more than the rest. **Placeholders** is a defect list: here a placeholder means an agent
invented a slug that does not exist, the most common content failure (`07-lessons-learned.md`).
**Link sync on rename** is what makes slug changes survivable at 300 pages. Foam's daily notes and
templates are irrelevant to this system — pages come from the schemas in `03-page-schemas.md`.

## Install

```sh
code --install-extension foam.foam-vscode
```

Or open the Extensions view, search "Foam", and pick the one published by Foam. The identifier is
`foam.foam-vscode` (current version 0.44.6). There is no "create a Foam workspace" step: open the
project folder in VS Code and the extension indexes the markdown it finds.

## Workspace settings

Create `"$PROJECT_ROOT/.vscode/settings.json"` by hand — there is no template for it in the kit —
and commit it, so the same behaviour follows the repo to any machine.

```json
{
  "foam.edit.linkReferenceDefinitions": "off",
  "foam.links.sync.enable": true,
  "foam.links.directory.mode": "disabled",
  "foam.graph.navigateToPreview": true,
  "foam.graph.views": [
    {
      "name": "Default",
      "colorBy": "directory",
      "show": { "tag": { "enabled": false }, "placeholder": { "enabled": true } }
    }
  ],
  "markdown.updateLinksOnFileMove.enabled": "prompt",
  "files.trimTrailingWhitespace": true,
  "editor.wordWrap": "on"
}
```

| Setting | Why |
| --- | --- |
| `linkReferenceDefinitions: "off"` | Keeps Foam out of your files. See the next section |
| `links.sync.enable: true` | Renaming a page rewrites inbound wikilinks instead of breaking them |
| `links.directory.mode: "disabled"` | Off by default this is on: `[[topics]]` silently resolves to `topics/index.md`. With a `wiki/index.md` present that is confusing magic. Keep links literal |
| `graph.navigateToPreview: true` | Clicking a graph node opens the rendered page, not the source — graph on one side, reading on the other |
| `graph.views` with a `"Default"` view | Applied automatically on open. Colour by directory so entries, topics and sources are visually distinct; hide tag nodes, which turn the graph into a hairball past a few hundred pages; keep placeholders visible, because you want to see broken links |
| `markdown.updateLinksOnFileMove` | VS Code's own equivalent for standard `[text](path.md)` links |
| `files.trimTrailingWhitespace` | The page schema forbids trailing whitespace; this stops you reintroducing it and keeps diffs clean |
| `editor.wordWrap: "on"` | These are prose files |

## Wikilinks in practice

The schema uses one form only: `[[slug]]`, the filename without its extension. That is an
*identifier* link — Foam resolves it across the whole workspace, so `[[nemawashi]]` works from any
folder without a relative path. This is why slugs must be unique across `concepts/`, `topics/` and
`sources/`: they share one namespace.

| Form | Behaviour |
| --- | --- |
| `[[slug]]` | Identifier, resolved workspace-wide. The only form the schema uses |
| `[[folder/slug]]` | Longer identifier; valid, and needed only to disambiguate |
| `[[./slug]]`, `[[/wiki/slug]]` | Path links — a leading `.` or `/` switches Foam to path resolution. Avoid |
| `[[slug#Heading]]` | Section link, with autocomplete on headings |
| `[[slug#^blockid]]` | Block link to an anchored paragraph. Not used by the schema |
| `![[slug#Heading]]` | Embeds that section's content inline |

If the same filename exists in two folders, `[[slug]]` is ambiguous: Foam resolves it
alphabetically and raises a warning diagnostic. Never give a topic hub the same slug as an entry.

Aliases work through frontmatter (`alias: first-alias, second-alias`) and show up in autocomplete.
They are genuinely useful when the canonical title is jargon and you search for the plain-English
version. The canonical schemas in `03-page-schemas.md` do not include an `alias` field; if you want
one, add it to the schema doc so the writer agent produces it consistently rather than sprinkling
it by hand.

## The link-reference-definition behaviour that surprises people

Foam can append a block of standard markdown reference definitions to the bottom of every file on
save:

```markdown
Related to [[data-science]] and [[statistics]].

[data-science]: data-science.md 'Data Science'
[statistics]: statistics.md 'Statistics'
```

This is controlled by `foam.edit.linkReferenceDefinitions`, with values `off` (the default),
`withoutExtensions` and `withExtensions`. The surprise is the blast radius: switch it on and every
page in the wiki grows an auto-generated footer that Foam rewrites whenever links change. On a
300-page wiki that is a 300-file diff, and pages whose body format your formatter agent specifies
precisely now end with machinery nobody asked for. Foam's own documentation files carry these
footers, which is how the setting gets copied by accident.

Leave it `off`. Turn it on only if you are publishing the wiki through a renderer that cannot
handle `[[...]]` syntax, and turn it on as a deliberate, separately committed change.

## Reading the graph as a health signal

`Cmd+Shift+P` → `Foam: Show Graph`. Files and tags are nodes, links are edges, and node size grows
with connection count. Read it at the end of a session, as a curation tool — not while working.

| What you see | What it means | What to do |
| --- | --- | --- |
| A few large nodes with dense clusters around them | Healthy. Topic hubs should be your largest nodes | Nothing |
| An entry with no edges at all | Nothing links to it and its `related:` is empty | Wire it into a hub and give it relations, or accept that it is not worth keeping |
| Grey placeholder nodes | A wikilink points at a slug with no file — an invented link | Fix the `related:` frontmatter on the page that emitted it |
| A tight cluster with no hub in it | A topic hub is missing | Create one and write the argument that connects them |
| Two hubs sharing most of their edges | The two topics are one topic, or the boundary is wrong | Merge, or restate the boundary in both hubs |
| A hub with edges but a thin body | A link list masquerading as a hub | Rewrite it as prose (`03-page-schemas.md`) |

`colorBy: "directory"` is what makes this legible: entries, topic hubs and source summaries get
distinct colours, so a cluster with no hub-coloured node in it is obvious at a glance.

## Obsidian instead

Obsidian is an equally good choice. Point it at `"$PROJECT_ROOT/wiki"` as a vault and it reads the
same files with no conversion.

| | Foam | Obsidian |
| --- | --- | --- |
| Where it runs | Inside VS Code, same window as Claude Code | A separate application |
| Footprint in the repo | Nothing added | Creates `.obsidian/` in the vault — gitignore it or commit it deliberately |
| Wikilink resolution | Identifiers resolved workspace-wide | Resolved as paths from the vault root; identical results for flat, unique slugs |
| Graph | Functional | Better: local graph, filters, saved views |
| Mobile | None | iOS and Android |
| Licence | Free, open source | Free for personal use; commercial use needs a paid licence — check current terms |

Both read plain `[[slug]]` wikilinks and YAML frontmatter, which is all the schema uses, so you can
run both against the same folder. Foam wins on living in the same window as the agent doing the
writing; Obsidian wins on graph and search when you are curating rather than ingesting.

## Gotchas

- **Foam indexes the whole workspace.** Open the project root and your raw source files show up in
  autocomplete and the graph alongside the wiki. When curating, open `wiki/` as the workspace
  folder; when ingesting, open the project root.
- **Rename inside VS Code, not in the terminal.** Link sync reacts to VS Code's rename event. A
  `mv` in a shell looks like a delete plus a create, and inbound `[[slug]]` links are left pointing
  at nothing. If you must rename outside the editor, check the Placeholders panel afterwards.
- **A freshly written page missing from autocomplete or the graph** usually means Foam has not
  picked up the change. Run `Developer: Reload Window`.
- **Frontmatter must start on line 1.** A blank line or stray character above the opening `---` and
  Foam ignores the block entirely — the graph then labels the node with the filename instead of the
  `title`.
- **Inline `#tags` are real tags.** The schema puts tags in frontmatter only, but a `#` mid-sentence
  in prose creates a tag node in the graph. Harmless, but it is why the graph sometimes grows nodes
  nobody declared.
- **The graph is a webview.** First paint on a large wiki takes a few seconds. It is not stuck.
- **Curly apostrophes in filenames** break tooling well beyond Foam. See `07-lessons-learned.md`.

Foam has no search worth using at this scale — that is what `04-search-setup-qmd.md` is for. The
recurring health pass that uses the graph and the Placeholders panel is written up in
`06-operations.md`.
