---
name: deepwiki
description: Rewrite or update .devin/wiki.json to steer DeepWiki. Use when the user says rewrite wiki.json, DeepWiki, 控制 DeepWiki, .devin/wiki.json, regenerate wiki, or after a repo refactor that would make wiki pages stale.
---

# deepwiki

Steer DeepWiki with `.devin/wiki.json`. Spec: https://docs.devin.ai/zh/work-with-devin/deepwiki#%E6%8E%A7%E5%88%B6-deepwiki

This repo uses **public / free DeepWiki** → effort is always **Low** (free, no ACU). Do not tell the user to switch Medium/High; those need a paid subscription and will be rejected. Public DeepWiki + MCP = docs + Q&A only; full Ask Devin is paid.

If `pages` is present, DeepWiki generates **only** those pages. List every page, not just the missing ones. On Low effort, fewer denser pages beat a 20+ page tree.

## Limits

- ≤30 pages (80 enterprise)
- ≤100 notes total (`repo_notes` + all `page_notes`)
- ≤10,000 chars per note
- titles unique and non-empty
- `parent` must match an existing `title`

## Format

```json
{
  "repo_notes": [{ "content": "...", "author": "optional" }],
  "pages": [
    {
      "title": "Overview",
      "purpose": "what this page must document",
      "parent": null,
      "page_notes": [{ "content": "page-specific correction" }]
    }
  ]
}
```

`pages` optional. **Free/Low: start with `repo_notes` only**, regenerate, then add `pages` only if the wiki still misses or invents structure. Notes-only still guides auto clustering. If `pages` is required (last wiki was structurally wrong), cap around 8–12 merged pages, not 22.

## Workflow

1. Fetch the spec URL above. Do not rely on memory.
2. Inventory the **current** repo. Do not copy the old wiki. Check:
   - `project.godot` (engine, physics, renderer, input, plugins)
   - `#Template/` layout (`[Scripts]` subdirs, root `.tscn`, `[Scenes]/`)
   - `addons/` (enabled vs present)
   - `class_name` / `extends` / `signal` / export names in `#Template/[Scripts]`
3. `repo_notes` = facts that stop the generator from repeating old mistakes (paths, renames, naming, trigger modes).
4. `purpose` / `page_notes` = current class names, camelCase fields, real file paths. Empty `page_notes` → omit the key.
5. Validate JSON: unique titles, parents exist, page count, note count.
6. `.gitignore` has `.*` — keep `!.devin/` or git will ignore the file. `git add -f` if needed.
7. `main` is protected. Branch → PR (see `pr-push`). Do not push `main`.

## Do not

- Invent files from the previous wiki (`RoadMaker`, `gameui`, `FogColorChanger`, `PortTookits`, `mpm_importer`, `openspec`, `[Scripts]/Editor/`).
- Document deleted APIs as current.
- Add pages past the 30 cap by splitting trivia; merge related systems (camera + its triggers, animator + TrackSwitcher).
- Assume Medium/High effort or paid Ask Devin. Free = Low only.
