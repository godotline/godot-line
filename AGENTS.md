# Repository Guidelines

## Project Structure & Module Organization
This is a Godot 4.6 project. Core project files are at the repository root: [`project.godot`](project.godot), [`Main.tscn`](Main.tscn), and several utility/editor scripts (for example `addcol.gd`, `animfix.gd`).

Reusable gameplay content lives in `#Template/`:
- `#Template/[Scripts]/`: main gameplay scripts (`MainLine.gd`, `LevelManager.gd`, camera/trigger logic).
- `#Template/*.tscn`: reusable scene building blocks.
- `#Template/[Resources]/` and `#Template/[Music]/`: models, textures, audio, fonts.

Treat `.godot/` as generated editor state; do not hand-edit it.

## Build, Test, and Development Commands
Use Godot directly (the workspace currently points VS Code to `D:\Code\Godot.exe`):

```powershell
D:\Code\Godot.exe --editor --path .
```
Open the project in the editor.

```powershell
D:\Code\Godot.exe --path .
```
Run the project for local gameplay testing.

```powershell
D:\Code\Godot.exe --headless --path . --quit
```
Quick validation pass (imports/project load) without opening the editor.

## Coding Style & Naming Conventions
- GDScript uses tabs for indentation (existing scripts are tab-indented).
- Prefer `snake_case` for functions/variables/signals.
- Keep scene and node names descriptive (`MainLine`, `LevelHolder`, `BaseCam`).
- Guard editor-only logic in `@tool` scripts with `Engine.is_editor_hint()`.
- Keep `.uid` and `.import` files in sync with renamed/moved assets.

## Testing Guidelines
There is no automated test suite configured yet (no `tests/` folder or test addon in `project.godot`). Do manual smoke tests before merging:
- Load and play the main scene (`Main.tscn`).
- Verify input actions from `project.godot` (`turn`, `retry`, `save`, `reload`, `savetaper`).
- Confirm autoload behavior for `State.gd`.

If you add automated tests, place them under `tests/` and document the run command in this file.

## Commit & Pull Request Guidelines
Current history uses short one-line subjects (`init`, `pure`). Keep commits concise, imperative, and focused on one change. Suggested format: `feat(level): adjust tail sync`.

PRs should include:
- What changed and why.
- Files/scenes touched.
- Manual test evidence (steps, screenshots, or short clip for visual gameplay changes).
