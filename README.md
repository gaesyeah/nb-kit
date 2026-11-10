<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit#readme"><img alt="English" src="https://img.shields.io/badge/English-2F81F7?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-30363D?style=for-the-badge"></a>
</p>

# nbkit

<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/releases/latest/download/nbkit.zip"><img alt="Download nbkit.zip" src="https://img.shields.io/badge/Download-nbkit.zip-2F81F7?style=for-the-badge&logo=github&logoColor=white"></a>
  <a href="https://github.com/gaesyeah/nb-kit/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gaesyeah/nb-kit?style=for-the-badge&color=30363D"></a>
  <a href="https://github.com/gaesyeah/nb-kit/actions/workflows/tests.yml"><img alt="Tests" src="https://img.shields.io/github/actions/workflow/status/gaesyeah/nb-kit/tests.yml?branch=main&style=for-the-badge&label=tests"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gaesyeah/nb-kit?style=for-the-badge&color=30363D"></a>
</p>

A kit of modules for **Apache NetBeans** on Linux, installed by a terminal CLI or by a graphical interface. It has two modules today:

- **JSF checks:** warnings in the xhtml editor for errors NetBeans does not show, such as a misspelled bean name (`#{customerVn.name}` instead of `#{customerVm.name}`).
- **One Dark Pro Mix theme:** the colors of the VS Code theme, with the FlatLaf Dark look and feel and the JetBrains Mono font.

Each module installs and uninstalls on its own.

## Installation

Download [`nbkit.zip`](https://github.com/gaesyeah/nb-kit/releases/latest/download/nbkit.zip) from the latest release, unzip it and run:

```bash
bash nbkit/nbkit.sh
```

The CLI shows the status of each module and only the options that make sense. Use ↑↓ to move, Enter to choose and Esc to go back.

- **Install or update:** choose "All" or one module.
- **Reinstall** and **Uninstall:** also per module.
- **Check that it loaded in NetBeans:** checks each installed module.
- **Run the tests** and **Build the modules:** only show up in a clone of the repository (see "Tests" and "Building the jars").
- **Backups:** only shows up when there is one. Enter restores, Del deletes, Esc goes back, and both restore and delete ask for confirmation.

If NetBeans is open, nbkit offers to close it the same way as File > Exit, so NetBeans asks about unsaved files and running processes as usual. At the end, it offers to open NetBeans and checks by itself that everything loaded (if you say no, it tells you how to check later). If something fails midway, or if you press Ctrl+C, everything goes back to how it was.

### Graphical interface

```bash
bash nbkit/nbkit.sh gui
```

A window with the same options: the modules with their status and buttons (tools first, then themes), install or update, reinstall and uninstall all at once, the userdir, Backups (restore or delete each one), Check and, in a clone, Run the tests and Build the modules. At the bottom, a terminal runs the CLI itself, so you see the same progress, colors and messages, with a progress bar on top. To copy from it: select and press Ctrl+Shift+C, or right-click; without a selection, it copies everything.

Every question of the CLI also shows up as a dialog. You can answer there or type in the terminal: the dialog closes by itself. The sudo password, when needed, is typed in the terminal; the interface never sees it. Closing the window in the middle of an action presses Ctrl+C for you, so everything goes back to how it was.

It needs GTK 4 and VTE for GTK 4 (through PyGObject). If they are missing, nbkit offers to install them (`python3-gi`, `gir1.2-gtk-4.0` and `gir1.2-vte-3.91` on Debian, Ubuntu and Pop!_OS; the right names on Fedora, Arch and openSUSE). It works on any desktop (GNOME, KDE, XFCE, Cinnamon, COSMIC) and follows the system GTK theme and its dark mode preference, terminal included.

### Without the menu

| Command | What it does |
|---|---|
| `bash nbkit.sh install [module...] [userdir]` | Installs or updates (no module: all) |
| `bash nbkit.sh uninstall [module...] [userdir]` | Removes (no module: all installed) |
| `bash nbkit.sh check [userdir]` | With NetBeans open, checks that everything loaded |
| `bash nbkit.sh gui [userdir]` | Opens the graphical interface |
| `bash nbkit.sh status [--json] [userdir]` | What is installed; `--json` for programs (the interface uses it) |
| `bash nbkit.sh restore <backup>` | Goes back to a backup (the files are listed by `status --json`) |
| `bash nbkit.sh delete-backup <backup>` | Deletes a backup |
| `bash nbkit.sh test` | Runs the tests (in the repository, see "Tests") |
| `bash nbkit.sh build` | Builds the jars from `src/` (see "Building the jars") |
| `bash nbkit.sh --help` | Help and list of modules |
| `--lang en` or `--lang pt-BR` | With any command, changes the language |

The module ids are `jsf` and `one-dark-pro-mix`. The default userdir is the newest NetBeans in `~/.netbeans/`; if there is more than one, the menu asks which one to use.

## Languages

The terminal speaks English or Portuguese, following the system language (`LANG`): Portuguese when it starts with `pt`, English otherwise. To choose, use `--lang en` or `--lang pt-BR`, or the `NBKIT_LANG` variable.

Inside NetBeans, the JSF hints and the Options page follow the language NetBeans runs in, which comes from the system or from `--locale` in `netbeans.conf`.

To add a language:
- **Terminal:** copy `lang/en.lang` to `lang/<language>.lang` (e.g. `es.lang`) and translate the values. `pt-BR.lang` is the reference: a missing key comes out in Portuguese.
- **NetBeans:** create `Bundle_<language>.properties` next to the `Bundle.properties` of each module in `src/` and run `bash src/build.sh` (see "Building the jars").

## Requirements

- Linux with bash 4 or newer, and Python 3.11 or newer. If it is missing, nbkit offers to install it with the system package manager (apt, dnf, pacman or zypper), next to the Python you already have.
- Apache NetBeans, tested on version 31. Works with a regular install, Flatpak or Snap.
- NetBeans running on Java 17 or newer. `check` warns if it is older.
- `curl` or `wget`, only if JetBrains Mono needs to be downloaded. With neither, nbkit offers to install `curl`.
- For the graphical interface only: GTK 4 and VTE for GTK 4 with PyGObject (nbkit offers to install them).

## JSF checks

NetBeans checks tags, attributes and the EL syntax, but does not catch errors that only show up at runtime, or that never show up. This module marks those errors in the editor:
- **Red:** certainly breaks.
- **Yellow:** probable error, or depends on something outside the file.

Each rule turns on and off in **Tools > Options > Editor > JSF**. The messages come out in English or Portuguese, following the NetBeans language.

- **EL:**
  - name that does not exist;
  - variable out of place;
  - property or method missing in the bean;
  - input `value` that cannot be written;
  - method where a property is expected;
  - enum constant that does not exist;
  - undeclared `cc.attrs`;
  - `${}` in a JSF component.
- **Declared and never used:** `ui:param`, `c:set`, `var`, `varStatus`, `cc:attribute`, lambda parameter.
- **IDs:**
  - `update`/`process`/`for` pointing to a missing id;
  - wrong search keyword (`@from`);
  - invalid or repeated id;
  - update of a component with `rendered`;
  - `PF('x')` without `widgetVar`.
- **Forms:**
  - button or input outside `h:form`;
  - form inside a form;
  - `p:dialog` with `appendTo` body;
  - `p:fileUpload` without multipart;
  - validation without a message component.
- **Lifecycle:**
  - `c:if`/`c:forEach` using the variable of a `ui:repeat`/`p:dataTable`;
  - `f:viewParam` outside `f:metadata`;
  - `p:ajax` event the component does not have.
- **Templates and files:**
  - `ui:define` without `ui:insert`;
  - content outside `ui:define`;
  - missing include, template, resource or navigation page.
- **Others:**
  - EL inside a comment (Facelets runs it);
  - `&nbsp;` and other HTML entities;
  - `escape="false"`.

The beans (Spring `@Component` and its derivatives, `@Bean`, CDI `@Named`, `@ManagedBean`) and the types come from the compiled classes of the project and from the classpath jars, so it works in any project without configuration. Classes not compiled yet come in by name, read from the source code.

## One Dark Pro Mix theme

- Creates the **"One Dark Pro Mix"** profile as a copy of the FlatLaf Dark of your NetBeans version, with the theme colors. The original FlatLaf Dark profile is not changed.
- Uses the Mix colors whenever there is an equivalent. Where the Mix does not define a color, it uses the VS Code default.
- Keeps the NetBeans italics and bold, except for keywords, which are not bold, as in the Mix.
- Selects the FlatLaf Dark look and feel, the profile and the terminal selection color, and installs JetBrains Mono if it is missing.
- Warnings in yellow and errors in red, both with a soft background.
- A coloring module paints what the editor does not tell apart by itself:
  - **JavaScript:** calls, objects and constants.
  - **CSS:** units, functions and selectors.
  - **EL:** variables.
  - **HTML/XML:** DOCTYPE.
  - **Brackets colored by level.**
- **Your customizations:** if you changed values the theme also defines, nbkit asks whether you want to keep yours.
- **Backup:** before the first install, it keeps a backup of the original state, which comes back on uninstall.

## Creating a theme

A theme is a folder in `modules/themes/` with three data files, no code. nbkit finds the folder by itself and the theme shows up in the menu. Everything else is done by the theme engine (`lib/themes.sh`):

- creating the color profile as a copy of the base profile of your NetBeans version, without touching the original;
- backing up, restoring, uninstalling and going back to the previous look and feel and profile;
- keeping the user's customizations;
- installing the font if it is missing, and removing it later only if nbkit installed it;
- installing the coloring module (`nbkit-colors.jar`): calls, objects, constants, units, functions, brackets by level, DOCTYPE...;
- applying the terminal selection color;
- undoing everything on Ctrl+C;
- checking with NetBeans open (`check`).

```
modules/themes/my-theme/
├── theme.toml      name, version, font, terminal
├── ui.properties   UI colors (FlatLaf)
└── colors.toml     editor colors
```

The folder name is the theme id (`bash nbkit.sh install my-theme`): lowercase letters, digits and hyphens.

### theme.toml

```toml
[theme]
name = "My Theme"
version = 1                       # raise it when the colors change, so the menu offers the update
profile = "My Theme"              # optional: profile name in Tools > Options > Fonts & Colors (default: name)
description = { en = "Short description", pt-BR = "Descrição curta" }

[font]                            # optional: without it, the font is not changed
name = "JetBrains Mono"
dir = "JetBrainsMono"             # folder in ~/.local/share/fonts
source = "official JetBrains repository"
urls = ["https://.../Regular.ttf", "https://.../Bold.ttf"]
license = "https://.../OFL.txt"

[terminal]                        # optional: without it, the terminal is not changed
selection = "#41454e"

[base]                            # optional: profile and look and feel the theme is built on
folder = "FlatLafDark"            # these are the defaults
name = "FlatLaf Dark"
profile = "FlatLaf Dark"
laf = "com.formdev.flatlaf.FlatDarkLaf"
laf_file = "FlatDarkLaf.properties"
```

Texts like `description` and `source` can be plain text or one per language, as above.

### ui.properties

FlatLaf keys (`@background`, `Component.focusColor`...), the same format as FlatLaf's own file. The `nb.preferred.color.profile=<profile>` line makes NetBeans keep the theme profile when the look and feel changes. The engine puts the theme mark on the first line and merges the keys the user already had.

```properties
nb.preferred.color.profile=My Theme
@background=#1e1e1e
@foreground=#d4d4d4
```

### colors.toml

```toml
[all]                             # every language
default = "#d4d4d4 on #1e1e1e"
comment = "#6a9955 italic"
keyword = "#569cd6"
error   = "on #3a2a2a wave #f14c4c"

[highlights]                      # selection, current line, search, line numbers...
selection = "on #264f78"

[annotations]                     # error and warning underlines of the modules

["text/x-java"]                   # one language, by its mime type
method-declaration = "#dcdcaa bold"

["text/javascript".extra]         # names the language does not declare, like the coloring module categories
nbkit-call = "#dcdcaa"
```

Each value is a text with, in any order:

| Part | Meaning |
|---|---|
| `#rrggbb` | text color |
| `on #rrggbb` | background |
| `bold`, `italic`, `bold italic`, `plain` | font style (`plain` removes the base bold or italic) |
| `underline #rrggbb`, `wave #rrggbb`, `strike #rrggbb` | underline, wavy underline, strikethrough |
| `inherits <token>` | takes what is not set from another token |

A color the theme does not define stays as in the base profile. To find the name of a token, change its color in Tools > Options > Fonts & Colors and look at the file saved in `~/.netbeans/<version>/config/Editors/<mime>/FontsColors/`. Names with a dot go in quotes (`"markup.bold" = "#e5c07b bold"`).

If a file has an error, nbkit skips that theme and says the file, the line and what is wrong:

```
Warning: theme "my-theme" skipped: unknown word: "itallic" (in all / comment, line 3)
```

Categories of the coloring module, per language (in `["<mime>".extra]`):

| Language | Categories |
|---|---|
| `text/javascript` | `nbkit-call`, `nbkit-object`, `nbkit-type`, `nbkit-constant`, `nbkit-library`, `nbkit-readonly`, `nbkit-library-function`, brackets |
| `text/css` | `nbkit-unit`, `nbkit-function`, `nbkit-tag`, `nbkit-id`, `nbkit-attribute`, `nbkit-string`, `nbkit-plain`, `nbkit-url-parameter`, brackets |
| `text/x-el` | `nbkit-call`, `nbkit-object`, `nbkit-library`, brackets |
| `text/html` | `nbkit-plain`, `nbkit-doctype`, `nbkit-attribute`, `nbkit-string` |
| `text/xml`, `text/xml-external-parsed-entity` | `nbkit-plain`, `nbkit-attribute`, `nbkit-string`, `nbkit-keyword`, `nbkit-documentroot`, `nbkit-doctype` |
| `text/x-java`, `text/x-json` | brackets |

The brackets are `nbkit-bracket1`, `nbkit-bracket2` and `nbkit-bracket3`, one per level, and `nbkit-bracket-unexpected` for a bracket without a pair.

`modules/themes/one-dark-pro-mix/` is a complete example.

## Structure

```
nbkit/
├── nbkit.sh                     CLI
├── lang/                        terminal texts: pt-BR.lang (reference) and en.lang
├── lib/                         code used by the CLI
│   ├── terminal.sh              colors, language and output helpers
│   ├── themes.sh                theme engine (see "Creating a theme")
│   ├── themes/                  Python parts of the theme engine
│   ├── modules.sh, modules.py   engine for NetBeans modules (module.toml)
│   ├── text.py                  texts of lang/ for the Python parts
│   ├── uievents.py              events for the interface (questions) from the Python parts
│   ├── gui.sh                   what the interface needs (GTK 4, VTE) and how to find it
│   ├── gui/                     graphical interface: model.py (no GTK, tested alone) and app.py (window)
│   └── jars/                    base modules: nbkit-core (closes NetBeans) and nbkit-colors (used by the themes)
├── modules/                     only data
│   ├── README.md                how to create a module
│   ├── jsf/                     module.toml + nbkit-jsf.jar
│   └── themes/
│       └── one-dark-pro-mix/    theme.toml, ui.properties, colors.toml
├── src/                         Java code of the NetBeans modules
│   ├── build.sh                 builds the jars (see below)
│   ├── nbkit-core/
│   ├── nbkit-colors/
│   └── nbkit-jsf/               with the test in test/
├── tests/                       tests (see "Tests")
└── .github/workflows/tests.yml  runs the tests on GitHub Actions
```

To add a NetBeans module, create a folder in `modules/` with its jar and a `module.toml` (see [how to create a module](modules/README.md)).

### Building the jars

The jars are already built in `lib/jars/` and `modules/jsf/`. To build them again from `src/`, after changing the Java code or the texts:

```bash
bash src/build.sh [netbeans folder]       # or: bash nbkit.sh build
```

It compiles against the jars of your NetBeans installation (without the folder: `NB_HOME`, or the NetBeans that last used `~/.netbeans`) with a JDK 17 or newer, and updates the sha256 sums. `bash src/build.sh --help` shows the options.

## Tests

```bash
bash nbkit.sh test
```

Runs everything in `tests/`, also on GitHub Actions at each push:

- **Lint:** shellcheck and pyflakes.
- **Python unit tests** (`tests/python/`): the `colors.toml` format and its error messages, the validation of `theme.toml` and `module.toml`, the `lang/` files (same keys in every language, every key the code uses exists) and the interface model (statuses, buttons, commands, events, progress and questions).
- **Engine** (`tests/engine.sh`): installs into a fake NetBeans (`tests/netbeans/`) and checks that the files are exactly the expected ones (`tests/expected/install.sha1`), that a reinstall keeps your customizations, that `check` finds a missing module, that uninstalling brings back exactly what was there, that a failure at any step changes nothing, that broken files are skipped with the reason, and what the interface uses: `status --json`, the step and question events, `restore` and `delete-backup`.
- **JSF checks** (`tests/jsf.sh`, needs a JDK 17 or newer): runs the analyzer on the sample project in `src/nbkit-jsf/test/fixture`, whose pages mark where each warning must show up, in English and in Portuguese.
- **Graphical interface** (`tests/gui.sh`, on a virtual screen with Xvfb): opens the window against the fake NetBeans and uses it like a person would: installs and uninstalls from the buttons, follows the progress bar, answers questions in the dialog and in the terminal, deletes a backup, opens About, closes the window in the middle of an install to check that everything goes back, and checks that it follows the dark mode of the system.

What you need, besides bash and Python 3.11:

| Tool | For | Install (Debian, Ubuntu, Pop!_OS) |
|---|---|---|
| shellcheck | lint of the bash files | `sudo apt install shellcheck` |
| pyflakes | lint of the Python files | `sudo apt install python3-pyflakes` |
| JDK 17 or newer (`javac`, `jar`, `java`) | JSF checks | `sudo apt install openjdk-21-jdk-headless` (or 17) |
| GTK 4, VTE and PyGObject | interface | `sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-vte-3.91` |
| xvfb-run | interface (virtual screen) | `sudo apt install xvfb` |

The JSF checks need nothing else: the libraries the sample project uses (Spring and Jakarta annotations and a PrimeFaces component) are small stubs in `src/nbkit-jsf/test/libs/`, built by the test.

If a tool is missing, `bash nbkit.sh test` offers to install it with the system package manager (apt, dnf, pacman or zypper), with the right package name for each one, asking first. Without a terminal to ask (as on GitHub Actions), or if you say no, that part is skipped with a warning. When a change to a theme alters the installed files on purpose, `bash tests/engine.sh --update` writes the expected list again. `bash src/build.sh --test` builds the jars and runs the JSF checks.

The tests do not replace opening NetBeans: hints and colors on screen still need a look.

## Troubleshooting

- **"could not find the NetBeans installation":** run with `NB_HOME=/path/to/netbeans bash nbkit.sh`.
- **Module did not load:** check that NetBeans runs on Java 17 or newer. `check` shows which Java it is using.

## License

[MIT](LICENSE).

### Third parties

- **Colors:** [One Dark Pro](https://github.com/Binaryify/OneDark-Pro), Mix variant. Copyright (c) 2013-2022 Binaryify, MIT license.
- **Font:** [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), downloaded from the official repository during the install. Copyright 2020 The JetBrains Mono Project Authors, SIL Open Font License 1.1.
- **Apache NetBeans** and **FlatLaf** are licensed under Apache 2.0. The modules use the public NetBeans APIs.

Independent project, not affiliated with the Apache Software Foundation, JetBrains or the One Dark Pro authors. "Apache NetBeans" is a registered trademark of the Apache Software Foundation.
