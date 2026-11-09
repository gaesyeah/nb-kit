<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-2F81F7?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-30363D?style=for-the-badge"></a>
</p>

# Creating an nbkit module

Each `.sh` file in `modules/` (or in `modules/themes/`, for themes) is loaded by `nbkit.sh` with `source`.
The menu, the status, "All", the `[n/N]` progress, the restore point and the check already work
for any module that follows the contract below.

Themes do not use this contract directly: each theme is a folder in `modules/themes/` with only data, and the engine
(`modules/themes/_engine.sh`) creates the contract functions for it (see "Creating a theme" in the
[README](../README.md#creating-a-theme)). Files starting with `_` are not loaded as modules.

## Registration

```bash
nbkit_register <id> <prefix> <category> "<name>" "<description>" <version>
```

- **id:** what shows up on the command line (`bash nbkit.sh install <id>`).
- **prefix:** start of the module function names (`<prefix>_status`, `<prefix>_install`...).
- **category:** `theme` (only one theme is active at a time; installing another one switches) or `tool`.
- **version:** an integer. When it changes, the menu offers the update.

## Required functions

| Function | What it does |
|---|---|
| `<prefix>_status` | Prints `no` or calls `version_status <id>` (returns `ok`, `old:<v>` or `new:<v>`). |
| `<prefix>_install_steps` | Prints how many `step` calls the install uses. |
| `<prefix>_install` | Installs. Uses the nbkit `step`, `ok`, `info`, `warn` and `die`. |
| `<prefix>_uninstall_steps` | Prints how many `step` calls the uninstall uses. |
| `<prefix>_uninstall` | Removes. |
| `<prefix>_paths` | Paths (relative to the userdir) the module changes: they go into the restore point. |
| `<prefix>_uninstall_summary` | "Goes / Back / Stays" lines shown before confirming. |
| `<prefix>_check` | With NetBeans open: prints `res 0 "..."` or `res 1 "..."`. Returns 0 (ok), 1 (reinstalling fixes it) or 2 (it does not). |

## Optional functions

| Function | What it does |
|---|---|
| `<prefix>_backups` | Lists the module backup files (the oldest first). Makes the "Backups" item show up. |
| `<prefix>_backup_desc <file>` | Short description of what is in the backup. |
| `<prefix>_restore_steps <file>` and `<prefix>_restore <file>` | Restores a backup. |
| `<prefix>_rollback` | Undoes something outside the userdir if the install stops midway. |

## nbkit helpers

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (temporary folder deleted at the end), `ask_yn <question> Y|N`, `bk_date`,
`version_status`, `log_has_module <name>` and `log_module_errors <regex>` (for `check`).

The installed version of each module is kept in `$UD/nbkit/<id>.version`, written by nbkit.

## Texts

Everything shown in the terminal comes from `lang/<language>.lang`. Use `t <key> [values...]`, which prints the text with
the `%s` filled in order (e.g. `step "$(t my.step "$name")"`), and create the key in every file in `lang/`, with the module
prefix (`jsf.`, `theme.`...). Python parts get the same files in `NBKIT_LANG_FILES` (see the `T` function in `_engine.sh`).
