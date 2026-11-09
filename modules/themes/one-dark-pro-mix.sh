# One Dark Pro Mix theme for nbkit (loaded by nbkit.sh with source).
# Data only: what is the same for every theme (profile, backup, font, coloring module,
# keeping your customizations, check) lives in the engine, _engine.sh. See "Creating a theme" in the README.

source "$(dirname "${BASH_SOURCE[0]}")/_engine.sh"
theme_register one-dark-pro-mix odpm "One Dark Pro Mix" "$(t odpm.description)" 29

odpm_config() {
  THEME_PROFILE="One Dark Pro Mix"
  # base: FlatLaf Dark (engine default)
  # terminal selection: terminal.selectionBackground of the Mix (#abb2bf30 over #282c34 = #41454e)
  THEME_TERMINAL_SELECTION=-12499634
  THEME_FONT_NAME="JetBrains Mono"
  THEME_FONT_DIR="JetBrainsMono"
  THEME_FONT_SOURCE="$(t odpm.font_source)"
  local u="https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master"
  THEME_FONT_URLS=("$u/fonts/ttf/JetBrainsMono-Regular.ttf" "$u/fonts/ttf/JetBrainsMono-Bold.ttf"
                   "$u/fonts/ttf/JetBrainsMono-Italic.ttf" "$u/fonts/ttf/JetBrainsMono-BoldItalic.ttf")
  THEME_FONT_LICENSE="$u/OFL.txt"
}

# installed by the old installer (netbeans-onedark.sh, before nbkit)
odpm_legacy_version() {
  if [ -f "$UD/onedark-version" ]; then cat "$UD/onedark-version"
  elif [ -e "$UD/modules/com-onedarkmix-netbeans.jar" ]; then echo "?"
  fi
}

# ---------- UI (FlatLaf) ----------
odpm_ui() {
  cat <<'EOF'
# Only keys with a direct equivalent in the VS Code theme (Mix key alongside).
# Save and restart NetBeans to apply.

nb.preferred.color.profile=One Dark Pro Mix

# sideBar.background
@background=#21252b
# foreground (Mix does not define it: VS Code default)
@foreground=#cccccc
# button.secondaryBackground (regular buttons); button.background (default button)
@buttonBackground=#30333d
@accentButtonDefaultBackground=#404754
# list.activeSelection*, list.inactiveSelection*
@selectionBackground=#2c313a
@selectionForeground=#d7dae0
@selectionInactiveBackground=#323842
@selectionInactiveForeground=#d7dae0
# focusBorder, textLink.foreground, tab.activeBorder
@accentFocusColor=#3e4452c3
@accentLinkColor=#61afef
@accentUnderlineColor=#b4b4b4

# input.background, dropdown.background
TextField.background=#1d1f23
PasswordField.background=#1d1f23
FormattedTextField.background=#1d1f23
Spinner.background=#1d1f23
ComboBox.background=#21252b

# sideBar.background
List.background=@background
Tree.background=@background

# scrollbarSlider.background / hoverBackground
ScrollBar.thumb=#323741
ScrollBar.hoverThumbColor=#3e4450
# scrollbarSlider.activeBackground
ScrollBar.pressedThumbColor=#4b515e

# editorHoverWidget.background
ToolTip.background=#21252b

# editor.background, tab.*
Nb.EmptyEditorArea.background=#282c34
EditorTab.background=#21252b
EditorTab.activeBackground=#21252b
EditorTab.selectedBackground=#282c34
EditorTab.selectedForeground=#dcdcdc
EditorTab.hoverBackground=#323842
EditorTab.underlineColor=#b4b4b4
EditorTab.tabSeparatorColor=#181a1f

# list.warningForeground, textLink.foreground
nb.warningForeground=#d19a66
nb.html.link.foreground=#61afef

# Output: the VS Code panel uses the editor background and selection
nb.output.background=#282c34
nb.output.backgorund=#282c34
nb.output.selectionBackground=#404859

# gitDecoration.ignoredResourceForeground (Mix)
nb.versioning.ignored.color=#636b78
# diffEditor.insertedLineBackground (VS Code default)
nb.diff.added.color=#3f483b
# original text in the sidebar popup = removed lines: diffEditor.removedLineBackground (VS Code default)
nb.diff.sidebar.changed.color=#53232a
nb.diff.sidebar.deleted.color=#53232a

# ---- VS Code defaults for keys the Mix does not define ----
# sideBar.foreground (Mix, #abb2bfc4 over the background)
Tree.foreground=#8b919d
List.foreground=#8b919d
# menu.foreground (Mix)
Menu.foreground=#abb2bf
MenuItem.foreground=#abb2bf
CheckBoxMenuItem.foreground=#abb2bf
RadioButtonMenuItem.foreground=#abb2bf
# menu.background -> dropdown.background (Mix)
@menuBackground=#21252b
# input.foreground (Mix)
TextField.foreground=#abb2bf
PasswordField.foreground=#abb2bf
FormattedTextField.foreground=#abb2bf
Spinner.foreground=#abb2bf
# dropdown.foreground (VS Code default)
ComboBox.foreground=#f0f0f0
# button.secondaryForeground (Mix); button.foreground (VS Code default)
Button.foreground=#c0bdbd
Button.default.foreground=#ffffff
# editorHoverWidget.foreground -> foreground (VS Code default)
ToolTip.foreground=#cccccc
# checkbox.border (Mix), checkbox.background -> dropdown.background (Mix), checkbox.foreground (VS Code default)
CheckBox.icon.borderColor=#404754
CheckBox.icon.selectedBorderColor=#404754
CheckBox.icon.background=#21252b
CheckBox.icon.selectedBackground=#21252b
CheckBox.icon.checkmarkColor=#f0f0f0
# progressBar.background (VS Code default)
ProgressBar.foreground=#0e70c0
# tab.inactiveForeground = tab.activeForeground at 50% (VS Code default); tab.hoverForeground null = does not change
EditorTab.foreground=#7e8084
EditorTab.activeForeground=#7e8084
EditorTab.hoverForeground=#7e8084
# errorForeground (VS Code default)
nb.errorForeground=#f48771
# Output = Debug Console: debugConsole.errorForeground / warningForeground
nb.output.err.foreground=#f48771
nb.output.warning.foreground=#d19a66
# textLink.foreground (Mix)
nb.output.link.foreground=#61afef
nb.output.link.foreground.important=#61afef
# gitDecoration.* (VS Code default)
nb.versioning.added.color=#81b88b
nb.versioning.modified.color=#e2c08d
nb.versioning.deleted.color=#c74e39
nb.versioning.conflicted.color=#e4676b
# diffEditor.removedLineBackground (VS Code default)
nb.diff.deleted.color=#53232a
EOF
}

# ---------- editor ----------
odpm_colors() {
  # ---------- general tokens (all languages) ----------
  colors_tokens <<'EOF'
    <fontcolor name="default" foreColor="ffabb2bf" bgColor="ff282c34"/>
    <fontcolor name="comment" foreColor="ff7f848e"/>
    <fontcolor name="keyword" foreColor="ffc678dd"/>
    <fontcolor name="string" foreColor="ff98c379"/>
    <fontcolor name="char" foreColor="ff98c379"/>
    <fontcolor name="number" foreColor="ffd19a66"/>
    <fontcolor name="operator" foreColor="ff56b6c2"/>
    <fontcolor name="separator" foreColor="ffabb2bf"/>
    <fontcolor name="identifier" foreColor="ffe06c75"/>
    <fontcolor name="field" foreColor="ffe06c75"/>
    <fontcolor name="method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="markup-element" foreColor="ffe06c75"/>
    <fontcolor name="markup-attribute" foreColor="ffd19a66"/>
    <fontcolor name="markup-attribute-value" foreColor="ff98c379"/>
    <fontcolor name="url" foreColor="ff61afef" underline="ff61afef"/>
    <fontcolor name="whitespace" foreColor="ff40444b"/>
    <fontcolor name="mark-occurrences" bgColor="ff474d59"/>
    <fontcolor name="error" bgColor="ff372e34" waveUnderlined="ffc24038"/>
    <fontcolor name="warning" bgColor="ff393739" waveUnderlined="ffd19a66"/>
EOF

  # ---------- highlights ----------
  colors_highlights <<'EOF'
    <fontcolor name="caret-color-insert-mode" foreColor="ff528bff"/>
    <fontcolor name="caret-color-overwrite-mode" foreColor="ff528bff"/>
    <fontcolor name="selection" bgColor="ff404859"/>
    <fontcolor name="highlight-caret-row" bgColor="ff2c313c"/>
    <fontcolor name="highlight-search" bgColor="ff45484f"/>
    <fontcolor name="line-number" foreColor="ff495162" bgColor="ff282c34"/>
    <fontcolor name="indent-guide-lines" foreColor="ff3b4048"/>
    <fontcolor name="text-limit-line-color" foreColor="ff3c4049"/>
    <fontcolor name="nbeditor-bracesMatching-match" bgColor="ff515a6b"/>
    <fontcolor name="nbeditor-bracesMatching-match-multichar" bgColor="ff515a6b"/>
    <fontcolor name="nbeditor-bracesMatching-mismatch"/>
    <fontcolor name="synchronized-text-blocks-ext" bgColor="ff393e49"/>
    <fontcolor name="synchronized-text-blocks-ext-slave" bgColor="ff393e49"/>
    <fontcolor name="nbeditor-bracesMatching-mismatch-multichar"/>
    <fontcolor name="hyperlinks" foreColor="ff61afef" underline="ff61afef"/>
    <fontcolor name="block-search" bgColor="ff2f3339"/>
    <fontcolor name="inc-search" bgColor="ff554941"/>
    <fontcolor name="code-folding" foreColor="ff808080" bgColor="ff3a3a3a"/>
    <fontcolor name="code-folding-bar" foreColor="ffc5c5c5"/>
    <fontcolor name="code-folding-border" foreColor="ffc5c5c5"/>
    <fontcolor name="coverage-covered" bgColor="ff203d49"/>
    <fontcolor name="coverage-uncovered" bgColor="ff53232a"/>
EOF

  # ---------- annotations (error/warning underlines) ----------
  colors_annotations <<'EOF'
    <fontcolor name="org-netbeans-modules-cnd-cpp-parser_annotation_err" waveUnderlined="ffc24038"/>
    <fontcolor name="org-netbeans-modules-web-core-syntax-JspParserErrorAnnotation" waveUnderlined="ffc24038"/>
    <fontcolor name="PHPError" waveUnderlined="ffc24038"/>
    <fontcolor name="PHPNotice" waveUnderlined="ffd19a66"/>
    <fontcolor name="PHPWarning" waveUnderlined="ffd19a66"/>
    <fontcolor name="CurrentPC" bgColor="ff53562a"/>
    <fontcolor name="CurrentPCLinePart" bgColor="ff53562a"/>
    <fontcolor name="CallSite" bgColor="ff415849"/>
    <fontcolor name="CurrentExpression" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_BP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_CBP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_DBP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_DCBP" bgColor="ff53562a"/>
    <fontcolor name="Dbx_PC" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DCBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DCBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_mixedBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_mixedBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_BPCBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_BPCBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_DBPCBP" bgColor="ff53562a"/>
EOF

  # ---------- per language ----------
  colors_language text/css <<'EOF'
    <fontcolor name="at_rule_symbol" foreColor="ffc678dd"/>
    <fontcolor name="identifiers" foreColor="ffd19a66"/>
    <fontcolor name="mod-method" foreColor="ffd19a66"/>
    <fontcolor name="mod-custom1" foreColor="ffabb2bf"/>
    <fontcolor name="mod-custom2" foreColor="ff56b6c2"><font style="italic"/></fontcolor>
    <fontcolor name="mod-custom3" foreColor="ffabb2bf"><font style="italic"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ff56b6c2"><font style="italic"/></fontcolor>
    <fontcolor name="mod-constructor" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="mod-local-variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-private" foreColor="ff61afef"><font style="bold"/></fontcolor>
EOF

  colors_extras text/css <<'EOF'
    <fontcolor name="keywords" foreColor="ffc678dd"/>
    <fontcolor name="errors" foreColor="ffffffff"/>
    <fontcolor name="IMPORTANT_SYM" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="CP_EQ" foreColor="ff56b6c2"/>
    <fontcolor name="CP_NOT_EQ" foreColor="ff56b6c2"/>
    <fontcolor name="VARIABLE" foreColor="ffe06c75"/>
    <fontcolor name="SASS_VAR" foreColor="ffe06c75"/>
    <fontcolor name="LESS_AND" foreColor="ffe06c75"/>
    <fontcolor name="STAR" foreColor="ffe06c75"/>
    <fontcolor name="GREATER" foreColor="ffabb2bf"/>
    <fontcolor name="TILDE" foreColor="ffabb2bf"/>
    <fontcolor name="PLUS" foreColor="ffabb2bf"/>
    <fontcolor name="INCLUDES" foreColor="ffabb2bf"/>
    <fontcolor name="DASHMATCH" foreColor="ffabb2bf"/>
    <fontcolor name="BEGINS" foreColor="ffabb2bf"/>
    <fontcolor name="ENDS" foreColor="ffabb2bf"/>
    <fontcolor name="CONTAINS" foreColor="ffabb2bf"/>
    <fontcolor name="nbkit-unit" foreColor="ffe06c75"/>
    <fontcolor name="nbkit-function" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-tag" foreColor="ffe06c75"/>
    <fontcolor name="nbkit-id" foreColor="ff61afef"/>
    <fontcolor name="nbkit-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket-unexpected" foreColor="ffd41719"/>
    <fontcolor name="nbkit-attribute" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-string" foreColor="ff98c379"/>
    <fontcolor name="nbkit-plain" foreColor="ffabb2bf"/>
    <fontcolor name="nbkit-url-parameter" foreColor="ffe06c75"/>
EOF

  colors_language text/html <<'EOF'
    <fontcolor name="character" foreColor="ffe06c75"><font style="plain"/></fontcolor>
    <fontcolor name="mod-class" waveUnderlined="ffc24038"/>
    <fontcolor name="el-content" default="default" foreColor="ffabb2bf"/>
EOF

  colors_language text/javascript <<'EOF'
    <fontcolor name="COMMENT_HTML" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="COMMENT_KEYWORD" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="keyword" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-regexp" foreColor="ffe06c75"/>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
EOF

  colors_extras text/javascript <<'EOF'
    <fontcolor name="KEYWORD_TRUE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_FALSE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_NULL" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_THIS" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_SUPER" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
    <fontcolor name="nbkit-call" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="nbkit-object" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-type" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-constant" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-library" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-readonly" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-library-function" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket-unexpected" foreColor="ffd41719"/>
EOF

  colors_language text/textmate <<'EOF'
    <fontcolor name="mod-class" foreColor="ffe5c07b"/>
    <fontcolor name="mod-class-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-struct" foreColor="ffe5c07b"/>
    <fontcolor name="mod-struct-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeAlias" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeAlias-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeParameter" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeParameter-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enumMember" foreColor="ff56b6c2"/>
    <fontcolor name="mod-enumMember-declaration" foreColor="ff56b6c2"/>
    <fontcolor name="mod-macro" foreColor="ffd19a66"/>
    <fontcolor name="mod-macro-declaration" foreColor="ffd19a66"/>
    <fontcolor name="mod-namespace" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-namespace-declaration" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-package" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-package-declaration" foreColor="ffa9b7c6"/>
    <fontcolor name="constant.other" foreColor="ffd19a66"/>
    <fontcolor name="support.function" foreColor="ff56b6c2"/>
    <fontcolor name="markup.heading" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="markup.bold" foreColor="ffd19a66"><font style="bold"/></fontcolor>
    <fontcolor name="markup.italic" foreColor="ffc678dd"><font style="italic"/></fontcolor>
EOF

  colors_language text/x-apache-conf <<'EOF'
    <fontcolor name="variable" foreColor="ffa9b7c6"/>
EOF

  colors_language text/x-diff <<'EOF'
    <fontcolor name="added" foreColor="ff98c379"/>
    <fontcolor name="removed" foreColor="ffe06c75"/>
    <fontcolor name="filename" foreColor="ff61afef"><font style="bold+italic"/></fontcolor>
EOF

  colors_language text/x-el <<'EOF'
    <fontcolor name="identifier" foreColor="ffe06c75"/>
    <fontcolor name="keywords" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="tag-lib-prefix" default="default" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
EOF

  colors_extras text/x-el <<'EOF'
    <fontcolor name="TRUE_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="FALSE_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="NULL_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="nbkit-call" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="nbkit-object" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-library" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket-unexpected" foreColor="ffd41719"/>
EOF

  colors_language text/x-env <<'EOF'
    <fontcolor name="key" foreColor="ffa9b7c6"/>
EOF

  colors_language text/x-java <<'EOF'
    <fontcolor name="literal" foreColor="ffd19a66"/>
    <fontcolor name="string-escape" foreColor="ff56b6c2"/>
    <fontcolor name="character-escape" foreColor="ff56b6c2"><font style="bold"/></fontcolor>
    <fontcolor name="javadoc-tag" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="javadoc-identifier" foreColor="ff7f848e"/>
    <fontcolor name="html-tag" foreColor="ff7f848e"><font style="italic"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ffe5c07b"/>
    <fontcolor name="mod-class-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-interface" foreColor="ffe5c07b"/>
    <fontcolor name="mod-interface-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-enum" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-record-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-annotation-type" foreColor="ffe5c07b"/>
    <fontcolor name="mod-annotation-type-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-constructor" foreColor="ffe5c07b"/>
    <fontcolor name="mod-constructor-declaration" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method-declaration" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-field" foreColor="ffe06c75"/>
    <fontcolor name="mod-field-declaration" foreColor="ffe06c75"/>
    <fontcolor name="mod-local-variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-local-variable-declaration" foreColor="ffe06c75"/>
    <fontcolor name="mod-parameter" foreColor="ffe06c75"/>
    <fontcolor name="mod-parameter-declaration" foreColor="ffe06c75"/>
    <fontcolor name="string-escape-invalid" waveUnderlined="ffc24038"/>
    <fontcolor name="mod-record" foreColor="ffe5c07b"/>
    <fontcolor name="mod-unused"/>
EOF

  colors_language text/x-jflex <<'EOF'
    <fontcolor name="directive_value" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  colors_language text/x-json <<'EOF'
    <fontcolor name="COMMENT_HTML" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="COMMENT_KEYWORD" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-regexp" foreColor="ffe06c75"/>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
EOF

  colors_extras text/x-json <<'EOF'
    <fontcolor name="KEYWORD_TRUE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_FALSE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_NULL" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="nbkit-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket-unexpected" foreColor="ffd41719"/>
EOF

  colors_language text/x-jsp <<'EOF'
    <fontcolor name="attribute-value" foreColor="ff98c379"/>
    <fontcolor name="comment" foreColor="ff7f848e"/>
    <fontcolor name="endtag" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="tag-directive" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="error" foreColor="ffffffff"><font style="bold"/></fontcolor>
    <fontcolor name="expression-language" default="default"/>
    <fontcolor name="scriptlet" default="default"/>
    <fontcolor name="scriptlet-delimiter" default="default"/>
EOF

  colors_language text/x-yaml <<'EOF'
    <fontcolor name="RUBYCOMMENT" default="comment"/>
EOF

  colors_language text/x-markdown <<'EOF'
    <fontcolor name="header" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="header2" foreColor="ffe06c75"/>
    <fontcolor name="header3" foreColor="ffe06c75"/>
    <fontcolor name="header4" foreColor="ffe06c75"/>
    <fontcolor name="header5" foreColor="ffe06c75"/>
    <fontcolor name="header6" foreColor="ffe06c75"/>
    <fontcolor name="bulletlist" foreColor="ffe5c07b"/>
    <fontcolor name="orderedlist" foreColor="ffe5c07b"/>
    <fontcolor name="emph" foreColor="ffc678dd"><font style="italic"/></fontcolor>
    <fontcolor name="strong" foreColor="ffd19a66"><font style="bold"/></fontcolor>
    <fontcolor name="strikethrough"/>
EOF

  colors_language text/x-nbs <<'EOF'
    <fontcolor name="identifier" foreColor="ffa9b7c6"/>
EOF

  colors_language text/x-neon <<'EOF'
    <fontcolor name="literal" foreColor="ffa9b7c6"/>
EOF

  colors_language text/x-oql <<'EOF'
    <fontcolor name="clazz" foreColor="ffa9b7c6"><font style="italic"/></fontcolor>
EOF

  colors_language text/x-php5 <<'EOF'
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="phpopenclose" foreColor="ffbe5046"><font style="bold"/></fontcolor>
    <fontcolor name="variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-custom1" foreColor="ffa9b7c6"/>
    <fontcolor name="keyword" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
    <fontcolor name="mod-deprecated" strikeThrough="ffc3c3c3"/>
EOF

  colors_language text/x-properties <<'EOF'
    <fontcolor name="properties-equal-sign" foreColor="ffabb2bf"/>
EOF

  colors_language text/x-repl <<'EOF'
    <fontcolor name="command" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="command-option" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="prompt" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  colors_language text/x-sql <<'EOF'
    <fontcolor name="sql-identifier" foreColor="ffabb2bf"/>
EOF

  colors_language text/x-tag <<'EOF'
    <fontcolor name="attribute-value" foreColor="ff98c379"/>
    <fontcolor name="comment" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="endtag" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="tag-directive" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="error" foreColor="ffffffff"><font style="bold"/></fontcolor>
    <fontcolor name="expression-language" default="default"/>
    <fontcolor name="scriptlet" default="default"/>
    <fontcolor name="scriptlet-delimiter" default="default"/>
EOF

  colors_language text/x-terraform+x-hcl <<'EOF'
    <fontcolor name="mod-field" foreColor="ff9876aa"/>
EOF

  colors_language text/x-tfvars+x-hcl <<'EOF'
    <fontcolor name="mod-field" foreColor="ff9876aa"/>
EOF

  colors_language text/x-toml <<'EOF'
    <fontcolor name="mod-global" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="string-escape" foreColor="ff56b6c2"/>
    <fontcolor name="table-mark" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  colors_language text/x-tpl <<'EOF'
    <fontcolor name="error" waveUnderlined="ffc24038"/>
    <fontcolor name="smarty" default="default"/>
EOF

  colors_language text/xml <<'EOF'
    <fontcolor name="xml-doctype" foreColor="ffc678dd"/>
    <fontcolor name="xml-operator" foreColor="ffabb2bf"/>
    <fontcolor name="xml-value" foreColor="ff98c379"/>
    <fontcolor name="xml-pi-start" foreColor="ffabb2bf"/>
    <fontcolor name="xml-pi-end" foreColor="ffabb2bf"/>
    <fontcolor name="xml-pi-target" foreColor="ffe06c75"/>
EOF

  colors_language text/xml-external-parsed-entity <<'EOF'
    <fontcolor name="xml-doctype" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="xml-value" foreColor="ff98c379"/>
    <fontcolor name="xml-pi-start" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="xml-pi-end" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="xml-pi-target" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="xml-cdata-section" foreColor="ff98c379"/>
EOF

  colors_language text/xhtml <<'EOF'
    <fontcolor name="expression-language" default="default"/>
EOF

  colors_extras text/x-java <<'EOF'
    <fontcolor name="nbkit-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="nbkit-bracket-unexpected" foreColor="ffd41719"/>
EOF

  colors_extras text/html <<'EOF'
    <fontcolor name="nbkit-plain" foreColor="ffabb2bf"/>
    <fontcolor name="nbkit-doctype" foreColor="ffe06c75"/>
    <fontcolor name="nbkit-attribute" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-string" foreColor="ff98c379"/>
EOF

  colors_extras text/xml <<'EOF'
    <fontcolor name="nbkit-plain" foreColor="ffabb2bf"/>
    <fontcolor name="nbkit-attribute" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-string" foreColor="ff98c379"/>
    <fontcolor name="nbkit-keyword" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-documentroot" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-doctype" foreColor="ffe06c75"/>
EOF

  colors_extras text/xml-external-parsed-entity <<'EOF'
    <fontcolor name="nbkit-plain" foreColor="ffabb2bf"/>
    <fontcolor name="nbkit-attribute" foreColor="ffd19a66"/>
    <fontcolor name="nbkit-string" foreColor="ff98c379"/>
    <fontcolor name="nbkit-keyword" foreColor="ffc678dd"/>
    <fontcolor name="nbkit-documentroot" foreColor="ffe5c07b"/>
    <fontcolor name="nbkit-doctype" foreColor="ffe06c75"/>
EOF
}
