<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-2F81F7?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-30363D?style=for-the-badge"></a>
</p>

# Creating an nbkit tool

nbkit has two kinds of modules, each with its own engine, and both are folders of data:

| Kind | Folder | Engine | Described in |
|---|---|---|---|
| Theme | `modules/themes/<id>/` | `lib/themes.sh` | "Creating a theme" in the [README](../README.md#creating-a-theme) |
| Tool | `modules/tools/<id>/` | `lib/tools.sh` | this page |

nbkit finds each folder by itself. The engine gives the module everything else: the menu and interface entries,
install, update, reinstall and uninstall, the `[n/N]` progress, the restore point (everything goes back on an error
or Ctrl+C), the version check and `check` with NetBeans open.

## tool.toml

```toml
[tool]
name = { en = "JSF checks", pt-BR = "Verificações de JSF" }
description = { en = "Warnings in the xhtml editor", pt-BR = "Avisos no editor de xhtml" }
version = 2                       # raise it when the tool changes, so the menu offers the update
hint = { en = "the rules turn on and off in Tools > Options > Editor > JSF", pt-BR = "..." }   # optional, after the install

[netbeans_module]                 # optional: a NetBeans module (jar) the tool installs
jar = "nbkit-jsf.jar"             # the jar in this folder
codename = "nbkit.jsf"            # OpenIDE-Module of the jar
sha256 = "2e95a0dd..."            # sha256 of the jar (src/build.sh updates it)

[uninstall]                       # optional: lines shown before confirming the uninstall
goes = { en = "the checks module", pt-BR = "o módulo de verificações" }
stays = { en = "your settings in Tools > Options", pt-BR = "suas opções em Tools > Options" }
```

The folder name is the tool id (`bash nbkit.sh install jsf`): lowercase letters, digits and hyphens. Texts can be plain
text or one per language. With `[netbeans_module]`, the jar goes to `modules/<codename with dashes>.jar` in the userdir,
is enabled in `config/Modules/`, and `check` looks for the codename in the NetBeans log. If `tool.toml` has an error,
nbkit skips the tool and says why.

## tool.sh: what is specific to the tool (optional)

A tool that does more than a jar (or no jar at all) puts a `tool.sh` next to `tool.toml`. nbkit loads it right after
registering the tool, so it redefines only the functions it needs; the others stay with the engine. The functions are
named `tool_<id>_<function>`, with the hyphens of the id as underscores (`my-tool` becomes `tool_my_tool_install`).
For example, a tool that writes a folder in `config/`:

```bash
tool_notes_paths() { echo config/nbkit-notes; }      # what it changes: goes into the restore point
tool_notes_install() {
  step "Notes"
  mkdir -p "$C/nbkit-notes" && echo hi > "$C/nbkit-notes/a.txt"
  ok "notes written"
}
tool_notes_uninstall() { step "Notes"; rm -rf "$C/nbkit-notes"; ok "notes removed"; }
```

With a jar and something else, call the engine part inside your function: `tool_module_install <id>`,
`tool_module_uninstall <id>` and `tool_module_check <id>`.

### The functions (the contract of every module)

| Function | What it does | Default of the engine |
|---|---|---|
| `_status` | Prints `no` or calls `version_status <id>` (`ok`, `old:<v>` or `new:<v>`). | installed if its jar is there or nbkit recorded its version |
| `_install_steps` | Prints how many `step` calls the install uses. | 1 |
| `_install` | Installs. Uses the nbkit `step`, `ok`, `info`, `warn` and `die`. | copies and enables the jar, shows the hint |
| `_uninstall_steps` | Prints how many `step` calls the uninstall uses. | 1 |
| `_uninstall` | Removes. | removes the jar |
| `_paths` | Paths (relative to the userdir) it changes: they go into the restore point. | the jar and its xml |
| `_uninstall_summary` | "Goes / Stays" lines shown before confirming. | `[uninstall]` of tool.toml |
| `_check` | With NetBeans open: prints `res 0 "..."` or `res 1 "..."`. Returns 0 (ok), 1 (reinstalling fixes it) or 2 (it does not). | the jar loaded, no error in the log |

Optional (the theme engine uses them; a tool may too):

| Function | What it does |
|---|---|
| `_backups` | Lists the tool backup files (the oldest first). Makes the "Backups" item show up. |
| `_backup_desc <file>` | Short description of what is in the backup. |
| `_restore_steps <file>` and `_restore <file>` | Restores a backup. |
| `_rollback` | Undoes something outside the userdir if the install stops midway. |

nbkit records the installed version in `$UD/nbkit/<id>.version` by itself after each install.

### nbkit helpers

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (temporary folder deleted at the end), `ask_yn <question> Y|N`, `bk_date`,
`version_status`, `file_copy <file> <destination> <sha256>`, `module_xml <codename>`, `res <0|1> <text>`,
`log_has_module <name>` and `log_module_errors <regex>` (for `check`). They are in `lib/registry.sh` and `lib/terminal.sh`.

The graphical interface follows `step` (progress bar) and `ask_yn` (dialog) by itself. A question asked from Python
has to call `event(ev='ask', text=..., default='Y' or 'N')` of `lib/uievents.py` before reading the answer and
`event(ev='answered')` after, as `lib/themes/build.py` does.

### Texts

Everything shown in the terminal comes from `lang/<language>.lang`. Use `t <key> [values...]`, which prints the text with
the `%s` filled in order (e.g. `step "$(t my.step "$name")"`), and create the key in every file in `lang/`, with the tool
id as prefix. Python parts get the same files in `NBKIT_LANG_FILES` and read them with `lib/text.py`.

### Tests

`tests/engine.sh` has a tool made only of `tool.sh` ("Tools engine"), installed into the fake NetBeans: a good model for
the tests of a new tool. Run everything with `bash nbkit.sh test`.
