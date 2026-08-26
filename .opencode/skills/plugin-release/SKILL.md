---
name: plugin-release
description: Publish a GodotLine editor plugin to its standalone GitHub repo and update the central plugin registry. Use when releasing plugin changes, bumping a plugin version, refreshing plugin_registry.json, or tagging any godotline/* plugin repo.
---

# plugin-release

The GodotLine project ships several editor plugins as **standalone GitHub repos**
that are listed in a central registry. This skill covers the full release flow for
**any** of them: make the change, sync it into the plugin repo, tag a release, and
update the registry so installs are reproducible.

## Plugins (authoritative source: plugin_registry.json)

The list of plugins, their publish repo, current tag, `sub_dir`, `dest_path`,
`version`, and `md5` all live in `plugin_registry.json` in
`https://github.com/godotline/godotline-plugin-registry`. **Always read it first**
rather than assuming names. The publish repos are `https://github.com/godotline/<github_repo>`.

Known `github_repo` values include (verify against the registry):
`plugin-advanced-components`, `plugin_mpm_importer`, `plugin_unidot_importer`,
`plugin-unitylike-timeline`, `plugin_arphros_importer`.

## Repositories

- **Publish target:** `https://github.com/godotline/<github_repo>` — its content is
  always the `<sub_dir>` subtree (e.g. `addons/godot_line/`). Clone this to release.
- **Source of truth (edits):** where the plugin code is maintained.
  - For `plugin-advanced-components` the source is `godot-line/addons/godot_line/`
    (the godot-line template repo) — edit there, then sync into the plugin repo.
  - For other plugins the source may be a separate repo or `godot-line/addons/<sub_dir>`.
    If `godot-line/addons/<sub_dir>` exists, treat it as the source and sync; otherwise
    edit directly inside the cloned plugin repo (it is already in place).
  - Never guess — verify which path exists before editing.

## Workflow

Do all clone work in a temp dir (e.g. `/tmp/opencode`), never inside `godot-line`.

### 1. Apply the plugin source changes
Edit the plugin's files at the determined source location. Keep the `.tscn` button
nodes, their `pressed` signal connections, and the `_on_*_pressed` handlers in sync.

### 1.5 Bump the plugin's own version
The plugin store reads each installed plugin's version from its `plugin.cfg`
(`[plugin] version = ...`) and compares it against the registry `version`. If they
differ, the store shows a spurious "可更新到 <registry version>" even right after
installing the latest release. **Always bump `plugin.cfg` `version` in the plugin
source to the same value you will set in the registry** (step 5). They must match
exactly, or users get a false update prompt.

### 2. Sync into the plugin repo and push to main
If you edited in `godot-line`, copy the subtree into the cloned plugin repo:
```bash
cd /tmp/opencode
rm -rf <plugin_repo>
git clone --depth 1 https://github.com/godotline/<plugin_repo>
cp -r /home/meny/Code/GodotLine/godot-line/<source_path>/* <plugin_repo>/<sub_dir>/
```
(If you edited inside the plugin repo directly, skip the `cp`.)

Then commit and push:
```bash
cd <plugin_repo>
git status --short          # expect only intended file changes
git --no-pager diff         # verify the diff is exactly the intended change
git add -A
git -c user.name=meny -c user.email=meny2333@users.noreply.github.com \
    commit -m "<concise Chinese summary of the plugin change>"
git push origin main
```
Never copy unrelated `godot-line` working-tree changes — only the plugin subtree.
If the push hits an OpenSSL `SSL_read: ... unexpected eof` error, retry (transient);
loop a few times with `sleep 2` between attempts.

### 3. Tag a release
Tags use `v0.1.x` (e.g. previous `v0.1.3` → next `v0.1.4`). Bump the patch for a
small change; the plugin `version` in the registry is independent (tracks the
template version, e.g. `2.3.249`).
```bash
git tag v0.1.4
git push origin v0.1.4
```

### 4. Recompute the registry md5 from the tag zip
The codeload zip's inner folder name embeds the ref, so tag vs `main` zips have
**different** md5 even with identical content. Always download the tag zip:
```bash
cd /tmp/opencode
curl -sL -o pac_tag.zip \
  "https://codeload.github.com/godotline/<plugin_repo>/zip/refs/tags/v0.1.4"
md5sum pac_tag.zip        # copy this value into the registry entry
```

### 5. Update plugin_registry.json and push
Clone the registry repo, edit the matching entry (`id`):
```bash
cd /tmp/opencode
rm -rf godotline-plugin-registry
git clone --depth 1 https://github.com/godotline/godotline-plugin-registry
```
Update these fields in the entry:
- `branch`: `"v0.1.4"`
- `download_urls[].url`: the two URLs' `refs/tags/v0.1.3` → `refs/tags/v0.1.4`
  (`.../archive/refs/tags/v0.1.4.zip` and `.../zip/refs/tags/v0.1.4`)
- `version`: bump (tracks the template version, e.g. `2.3.249`)
- `md5`: the value from step 4
- `updated_at`: today's date in ISO form (`YYYY-MM-DD`). The store shows it as
  更新时间 in the detail panel and uses it for time-sorted ordering of the plugin list.
- `changelog`: **prepend** a new release at the front, newest first:
  ```json
  { "version": "…", "date": "YYYY-MM-DD", "notes": ["简短中文要点", "…"] }
  ```
  Keep previous entries so history accumulates; write concise Chinese bullets.
- `recommended_template_version` (optional): set or bump it only when this release
  depends on newer template features. It is advisory — the store labels it
  推荐 Template 版本 and never blocks installation on it.

If you add or rename registry fields, bump the top-level `schema_version` too.

Validate JSON before committing:
```bash
cd godotline-plugin-registry
python3 -c "import json;json.load(open('plugin_registry.json'));print('JSON OK')"
git add -A
git -c user.name=meny -c user.email=meny2333@users.noreply.github.com \
    commit -m "<plugin id> 钉到标签 v0.1.4"
git push origin main
```

## Rules
- Pin the registry to a **tag**, not floating `main`, so installs are reproducible.
- If a change is pushed to `main` but the registry still points at an old tag, users
  will not receive it — always tag + update registry together.
- `version` (template version, e.g. `2.3.249`) and the git tag (`v0.1.x`) are
  separate numbering schemes; bump both deliberately.
- Every release must also update `updated_at` and prepend a `changelog` entry —
  the store's time sorting and detail panel read them; stale values misorder the list.
- There is no minimum-template-version gate: `recommended_template_version` is a
  soft recommendation shown as 推荐 in the store and never blocks installation.
- The plugin's `plugin.cfg` `[plugin] version` MUST equal the registry `version`
  (step 1.5); otherwise the store shows a false "可更新" after install.
- Keep the `.tscn` button ↔ `_on_*_pressed` handler ↔ signal connection triple consistent.
- Push failures are usually transient SSL errors — retry, don't recreate the repo.
- Use `meny2333@users.noreply.github.com` as the commit author when the user has not
  specified otherwise.
