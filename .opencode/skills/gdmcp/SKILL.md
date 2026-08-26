---
name: gdmcp
description: Use the installed gdmcp CLI to inspect, edit, run, and debug a Godot project without loading the complete Godot MCP tool catalog.
---

# gdmcp

Use `gdmcp` from the shell for operations that require the running Godot editor.
By default, invoke the project-local CLI from the project root at `.\.gdmcp\bin\gdmcp.exe` in PowerShell; the `gdmcp` command in the examples below is shorthand for this path. Use a PATH-installed `gdmcp` only as an explicit fallback when the local executable is unavailable.

## Project directory and configuration discovery

Run the CLI from the Godot project root when possible. The CLI uses the
process working directory to discover `project.godot`, then resolves the
project's Godot `user://mcp_settings.cfg` so a persisted HTTP `http_port` is
used automatically. The CLI executable directory (for example
`.gdmcp/bin`) is not used as the project directory.

When the current directory is not the project root, provide the project and,
if necessary, Godot's custom user-data root explicitly:

```bash
gdmcp --project-path <project-root> --godot-user-data-dir <godot-user-data-root> --json doctor
```

Equivalent environment variables are `GODOT_MCP_PROJECT_PATH` and
`GODOT_USER_DATA_DIR`. URL precedence remains: explicit `--url`,
`GODOT_MCP_URL`, the CLI config file, the discovered Godot MCP settings, then
the built-in `http://127.0.0.1:9080` fallback. Stdio MCP settings do not
produce an HTTP endpoint and therefore use the normal fallback chain.

Start with:

```bash
gdmcp --json doctor
gdmcp --json editor state
```

Prefer narrow domain commands for common operations:

```bash
gdmcp --json scenes current
gdmcp --json scenes list --limit 20
gdmcp --json scenes tree --depth 4
gdmcp --json nodes list --limit 20
gdmcp --json nodes get /root/Main/Player --fields position,visible
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
gdmcp --json scripts list --limit 20
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json scripts create res://new_script.gd --script-type GDScript
gdmcp --json resources list --limit 20
gdmcp --json resources get res://player.tres --fields resource_path
gdmcp --json project settings --filter display/
gdmcp --json debug logs --limit 50
gdmcp --json runtime tree --depth 4
gdmcp --json runtime nodes get /root/Main/Player
```

Resolve names to stable paths (no tool-call needed):

```bash
gdmcp --json nodes resolve Player
gdmcp --json scenes resolve Main
gdmcp --json scripts resolve player
gdmcp --json resources resolve icon
```

Refactor nodes:

```bash
gdmcp --json nodes move /root/Main/Player --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy1 --new-name Boss
```

When a domain command is unavailable, use progressive discovery:

```bash
gdmcp --json tools search "<intent>" --limit 5
gdmcp --json tools schema <tool-name>
gdmcp --json tool-call <tool-name> --args-file <request.json>
```

Rules:

- Use `--json` when the output will be analyzed programmatically.
- Prefer domain commands over raw `tool-call`.
- Do not request the complete catalog with full schemas.
- Bound output with `--limit`, `--depth`, `--fields`, `--lines`, `--max-bytes`, or `--out`.
- Use `scripts list --limit <n> [--cursor <cursor>]` for progressive script discovery.
- Use `scripts read --lines <start>:<end>` to read specific line ranges.
- Use `nodes get --fields <field1,field2>` and `resources get --fields <field1,field2>` to retrieve only specific properties.
- Use `{scenes,nodes,scripts,resources} resolve <name>` to convert human-readable names to stable paths.
- `scenes list`, `nodes list`, `scripts list`, `resources list`, and `debug logs` default to 50 items.
- Use `debug logs --cursor <offset>` to continue log pages.
- Always pass `project settings --filter <prefix>`.
- Use `batch preview` before `batch apply`.
- Batch files use registered tool names and object arguments. Validation completes before any request is sent; execution is sequential and non-atomic.
- Destructive domain commands require `--apply`.
- Raw destructive calls require `--apply` after reviewing the schema.
- Runtime and open-world tools require `--allow-open-world`.
- Configure tokens via `GODOT_MCP_TOKEN` environment variable; never print them.

See `references/command-workflows.md` for copyable task flows.
