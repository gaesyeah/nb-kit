<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-2F81F7?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-30363D?style=for-the-badge"></a>
</p>

# Creating an nbkit module

A NetBeans module is a folder in `modules/` with its jar and a `module.toml`, with no code. nbkit finds the folder by
itself and the module shows up in the menu, with install, update, reinstall, uninstall, the `[n/N]` progress, the
restore point and the check. The engine is `lib/modules.sh`. Themes are folders in `modules/themes/` (see
"Creating a theme" in the [README](../README.md#creating-a-theme)).

## module.toml

```toml
[module]
name = { en = "JSF checks", pt-BR = "Verificações de JSF" }
description = { en = "Warnings in the xhtml editor", pt-BR = "Avisos no editor de xhtml" }
version = 2                       # raise it when the jar changes, so the menu offers the update
jar = "nbkit-jsf.jar"             # the jar in this folder
codename = "nbkit.jsf"            # OpenIDE-Module of the jar
sha256 = "2e95a0dd..."            # sha256 of the jar (src/build.sh updates it)
hint = { en = "the rules turn on and off in Tools > Options > Editor > JSF", pt-BR = "..." }   # optional, after the install

[uninstall]                       # optional: lines shown before confirming the uninstall
goes = { en = "the checks module", pt-BR = "o módulo de verificações" }
stays = { en = "your settings in Tools > Options", pt-BR = "suas opções em Tools > Options" }
```

The folder name is the module id (`bash nbkit.sh install jsf`): lowercase letters, digits and hyphens. Texts can be
plain text or one per language. The jar goes to `modules/<codename with dashes>.jar` in the userdir, and
`check` looks for the codename in the NetBeans log. If `module.toml` has an error, nbkit skips the module and says why.

## Modules in bash (advanced)

For something that is not just a jar, put a `.sh` in `modules/`. nbkit loads it with `source`; it registers itself with:

```bash
nbkit_register <id> <prefix> <category> "<name>" "<description>" <version>
```

- **id:** what shows up on the command line (`bash nbkit.sh install <id>`).
- **prefix:** start of the module function names (`<prefix>_status`, `<prefix>_install`...).
- **category:** `theme` (only one theme is active at a time; installing another one switches) or `tool`.
- **version:** an integer. When it changes, the menu offers the update.

### Required functions

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

### Optional functions

| Function | What it does |
|---|---|
| `<prefix>_backups` | Lists the module backup files (the oldest first). Makes the "Backups" item show up. |
| `<prefix>_backup_desc <file>` | Short description of what is in the backup. |
| `<prefix>_restore_steps <file>` and `<prefix>_restore <file>` | Restores a backup. |
| `<prefix>_rollback` | Undoes something outside the userdir if the install stops midway. |

### nbkit helpers

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (temporary folder deleted at the end), `ask_yn <question> Y|N`, `bk_date`,
`version_status`, `file_copy <file> <destination> <sha256>`, `module_xml <codename>`, `log_has_module <name>` and
`log_module_errors <regex>` (for `check`). The installed version of each module is kept in `$UD/nbkit/<id>.version`.

### Texts

Everything shown in the terminal comes from `lang/<language>.lang`. Use `t <key> [values...]`, which prints the text with
the `%s` filled in order (e.g. `step "$(t my.step "$name")"`), and create the key in every file in `lang/`, with the module
prefix. Python parts get the same files in `NBKIT_LANG_FILES` and read them with `lib/text.py`.
