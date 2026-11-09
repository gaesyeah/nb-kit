<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit#readme"><img alt="English" src="https://img.shields.io/badge/English-2F81F7?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-30363D?style=for-the-badge"></a>
</p>

# nbkit

A kit of modules for **Apache NetBeans** on Linux, installed by a terminal CLI. It has two modules today:

- **One Dark Pro Mix theme:** the colors of the VS Code theme, with the FlatLaf Dark look and feel and the JetBrains Mono font.
- **JSF checks:** warnings in the xhtml editor for errors NetBeans does not show, such as a misspelled bean name (`#{customerVn.name}` instead of `#{customerVm.name}`).

Each module installs and uninstalls on its own.

## Installation

Download the whole `nbkit` folder and run:

```bash
bash nbkit/nbkit.sh
```

The CLI shows the status of each module and only the options that make sense. Use ↑↓ to move, Enter to choose and Esc to go back.

- **Install or update:** choose "All" or one module.
- **Reinstall** and **Uninstall:** also per module.
- **Check that it loaded in NetBeans:** checks each installed module.
- **Backups:** only shows up when there is one. Enter restores, Del deletes, Esc goes back, and both restore and delete ask for confirmation.

If NetBeans is open, nbkit offers to close it the same way as File > Exit, so NetBeans asks about unsaved files and running processes as usual. At the end, it offers to open NetBeans and checks by itself that everything loaded. If something fails midway, or if you press Ctrl+C, everything goes back to how it was.

### Without the menu

| Command | What it does |
|---|---|
| `bash nbkit.sh install [module...] [userdir]` | Installs or updates (no module: all) |
| `bash nbkit.sh uninstall [module...] [userdir]` | Removes (no module: all installed) |
| `bash nbkit.sh check [userdir]` | With NetBeans open, checks that everything loaded |
| `bash nbkit.sh --help` | Help and list of modules |
| `--lang en` or `--lang pt-BR` | With any command, changes the language |

The module ids are `one-dark-pro-mix` and `jsf`. The default userdir is the newest NetBeans in `~/.netbeans/`; if there is more than one, the menu asks which one to use.

## Languages

The terminal speaks English or Portuguese, following the system language (`LANG`): Portuguese when it starts with `pt`, English otherwise. To choose, use `--lang en` or `--lang pt-BR`, or the `NBKIT_LANG` variable.

Inside NetBeans, the JSF hints and the Options page follow the language NetBeans runs in, which comes from the system or from `--locale` in `netbeans.conf`.

To add a language:
- **Terminal:** copy `lang/en.lang` to `lang/<language>.lang` (e.g. `es.lang`) and translate the values. `pt-BR.lang` is the reference: a missing key comes out in Portuguese.
- **NetBeans:** create `Bundle_<language>.properties` next to the `Bundle.properties` of each module in `src/` and build the jar again.

## Requirements

- Linux with bash 4 or newer, and `python3`.
- Apache NetBeans, tested on version 31. Works with a regular install, Flatpak or Snap.
- NetBeans running on Java 17 or newer.
- `curl` or `wget`, only if JetBrains Mono needs to be downloaded.

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

Everything One Dark Pro Mix has besides the colors lives in the theme engine, `modules/themes/_engine.sh`. A new theme only describes the colors. The engine already takes care of:

- creating the color profile as a copy of the base profile of your NetBeans version, without touching the original;
- backing up, restoring, uninstalling and going back to the previous look and feel and profile;
- keeping the user's customizations;
- installing the font if it is missing, and removing it later only if nbkit installed it;
- installing the coloring module (`nbkit-colors.jar`): calls, objects, constants, units, functions, brackets by level, DOCTYPE...;
- applying the terminal selection color;
- undoing everything on Ctrl+C;
- checking with NetBeans open (`check`).

Create `modules/themes/<id>.sh`. nbkit loads the file by itself and the theme shows up in the menu.

```bash
source "$(dirname "${BASH_SOURCE[0]}")/_engine.sh"
theme_register my-theme mt "My Theme" "Short description" 1

mt_config() {
  THEME_PROFILE="My Theme"                  # profile name in Tools > Options > Fonts & Colors
  THEME_TERMINAL_SELECTION=-12499634        # optional: terminal selection color (ARGB as an integer)
  THEME_FONT_NAME="JetBrains Mono"          # optional: editor font
  THEME_FONT_DIR="JetBrainsMono"            # folder in ~/.local/share/fonts
  THEME_FONT_URLS=("https://.../Regular.ttf" "https://.../Bold.ttf")
  THEME_FONT_LICENSE="https://.../OFL.txt"
}

# UI (FlatLaf): content of the look and feel properties file
mt_ui() {
  cat <<'EOF'
nb.preferred.color.profile=My Theme
@background=#1e1e1e
@foreground=#d4d4d4
EOF
}

# editor
mt_colors() {
  colors_tokens <<'EOF'
    <fontcolor name="default" foreColor="ffd4d4d4" bgColor="ff1e1e1e"/>
    <fontcolor name="comment" foreColor="ff6a9955"/>
EOF
  colors_highlights <<'EOF'
    <fontcolor name="selection" bgColor="ff264f78"/>
EOF
  colors_annotations <<'EOF'
EOF
  colors_language text/x-java <<'EOF'
    <fontcolor name="method-declaration" foreColor="ffdcdcaa"/>
EOF
  colors_extras text/javascript <<'EOF'
    <fontcolor name="nbkit-call" foreColor="ffdcdcaa"/>
EOF
}
```

What each part does:

- **`theme_register <id> <prefix> "<name>" "<description>" <version>`:** registers the theme in the menu and wires the nbkit functions to the engine. Raise the version when you change the colors, so the menu offers the update. For the description to follow the terminal language, create a key in the `lang/` files and pass `"$(t <key>)"`, as One Dark Pro Mix does.
- **`<prefix>_config`:** only `THEME_PROFILE` is required. The defaults are:
  - base `FlatLafDark` (`THEME_BASE`, with `THEME_BASE_NAME` and `THEME_BASE_PROFILE` for the messages and for the uninstall);
  - look and feel `com.formdev.flatlaf.FlatDarkLaf` (`THEME_LAF`), with the `FlatDarkLaf.properties` file (`THEME_LAF_FILE`).

  Without `THEME_FONT_NAME`, the font is not changed. Without `THEME_TERMINAL_SELECTION`, the terminal is not changed.
- **`<prefix>_ui`:** FlatLaf keys (`@background`, `Component.focusColor`...). The `nb.preferred.color.profile=<profile>` line makes NetBeans keep the theme profile when the look and feel changes. The engine puts the theme mark on the first line and merges the keys the user already had.
- **`<prefix>_colors`:** NetBeans `<fontcolor .../>` lines, with colors as `ffRRGGBB`.
  - `colors_tokens` applies to all languages (`default`, `comment`, `keyword`, `string`, `error`, `warning`...).
  - `colors_highlights` covers selection, current line, search, line numbers...
  - `colors_annotations` are the underlines the modules use.
  - `colors_language <mime>` are the tokens of one language.
  - `colors_extras <mime>` are the categories of the coloring module.

  A color the theme does not define stays as in the base profile. To find the name of a token, change its color in Tools > Options > Fonts & Colors and look at the file saved in `~/.netbeans/<version>/config/Editors/<mime>/FontsColors/`.

Categories of the coloring module, per language (in `colors_extras`):

| Language | Categories |
|---|---|
| `text/javascript` | `nbkit-call`, `nbkit-object`, `nbkit-type`, `nbkit-constant`, `nbkit-library`, `nbkit-readonly`, `nbkit-library-function`, brackets |
| `text/css` | `nbkit-unit`, `nbkit-function`, `nbkit-tag`, `nbkit-id`, `nbkit-attribute`, `nbkit-string`, `nbkit-plain`, `nbkit-url-parameter`, brackets |
| `text/x-el` | `nbkit-call`, `nbkit-object`, `nbkit-library`, brackets |
| `text/html` | `nbkit-plain`, `nbkit-doctype`, `nbkit-attribute`, `nbkit-string` |
| `text/xml`, `text/xml-external-parsed-entity` | `nbkit-plain`, `nbkit-attribute`, `nbkit-string`, `nbkit-keyword`, `nbkit-documentroot`, `nbkit-doctype` |
| `text/x-java`, `text/x-json` | brackets |

The brackets are `nbkit-bracket1`, `nbkit-bracket2` and `nbkit-bracket3`, one per level, and `nbkit-bracket-unexpected` for a bracket without a pair.

`modules/themes/one-dark-pro-mix.sh` is a complete example.

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

## Structure

```
nbkit/
├── nbkit.sh                     CLI
├── lang/
│   ├── pt-BR.lang               terminal texts in Portuguese (reference)
│   └── en.lang                  terminal texts in English
├── modules/
│   ├── README.md                how to create a module
│   ├── themes/
│   │   ├── _engine.sh           theme engine (see "Creating a theme")
│   │   └── one-dark-pro-mix.sh  only the theme colors
│   └── jsf.sh
└── src/                         Java code of the NetBeans modules
    ├── nbkit-core/              closing NetBeans from the terminal
    ├── nbkit-colors/            coloring by text pattern (used by the themes)
    └── nbkit-jsf/               JSF checks, with the test in test/
```

To add a module, just put a `.sh` in `modules/` following the [contract](modules/README.md).

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
