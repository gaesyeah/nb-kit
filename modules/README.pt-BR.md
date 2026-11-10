<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-30363D?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-2F81F7?style=for-the-badge"></a>
</p>

# Criar uma ferramenta do nbkit

O nbkit tem dois tipos de módulo, cada um com o seu motor, e os dois são pastas de dados:

| Tipo | Pasta | Motor | Explicado em |
|---|---|---|---|
| Tema | `modules/themes/<id>/` | `lib/themes.sh` | "Criar um tema" no [README](../README.pt-BR.md#criar-um-tema) |
| Ferramenta | `modules/tools/<id>/` | `lib/tools.sh` | esta página |

O nbkit acha cada pasta sozinho. O motor dá ao módulo todo o resto: as entradas no menu e na interface, instalar,
atualizar, reinstalar e desinstalar, o progresso `[n/N]`, o ponto de restauração (tudo volta num erro ou Ctrl+C), a
conferência de versão e o `check` com o NetBeans aberto.

## tool.toml

```toml
[tool]
name = { en = "JSF checks", pt-BR = "Verificações de JSF" }
description = { en = "Warnings in the xhtml editor", pt-BR = "Avisos no editor de xhtml" }
version = 2                       # aumente quando a ferramenta mudar, para o menu oferecer a atualização
hint = { en = "...", pt-BR = "as regras ligam e desligam em Tools > Options > Editor > JSF" }   # opcional, depois de instalar

[netbeans_module]                 # opcional: um módulo do NetBeans (jar) que a ferramenta instala
jar = "nbkit-jsf.jar"             # o jar nesta pasta
codename = "nbkit.jsf"            # OpenIDE-Module do jar
sha256 = "2e95a0dd..."            # sha256 do jar (o src/build.sh atualiza)

[uninstall]                       # opcional: linhas mostradas antes de confirmar a desinstalação
goes = { en = "the checks module", pt-BR = "o módulo de verificações" }
stays = { en = "your settings in Tools > Options", pt-BR = "suas opções em Tools > Options" }
```

O nome da pasta é o id da ferramenta (`bash nbkit.sh install jsf`): letras minúsculas, números e hífens. Os textos podem
ser um texto só ou um por idioma. Com `[netbeans_module]`, o jar vai para `modules/<codename com hífens>.jar` no userdir,
é ligado em `config/Modules/`, e o `check` procura o codename no log do NetBeans. Se o `tool.toml` tiver erro, o nbkit
ignora a ferramenta e diz o motivo.

## tool.sh: o que é específico da ferramenta (opcional)

Uma ferramenta que faz mais que um jar (ou nem tem jar) coloca um `tool.sh` ao lado do `tool.toml`. O nbkit carrega ele
logo depois de registrar a ferramenta, então ele redefine só as funções que precisa; as outras ficam com o motor. As
funções se chamam `tool_<id>_<função>`, com os hífens do id virando sublinhado (`minha-ferramenta` vira
`tool_minha_ferramenta_install`). Por exemplo, uma ferramenta que grava uma pasta em `config/`:

```bash
tool_notes_paths() { echo config/nbkit-notes; }      # o que ela altera: entra no ponto de restauração
tool_notes_install() {
  step "Notes"
  mkdir -p "$C/nbkit-notes" && echo hi > "$C/nbkit-notes/a.txt"
  ok "notes written"
}
tool_notes_uninstall() { step "Notes"; rm -rf "$C/nbkit-notes"; ok "notes removed"; }
```

Com um jar e mais alguma coisa, chame a parte do motor dentro da sua função: `tool_module_install <id>`,
`tool_module_uninstall <id>` e `tool_module_check <id>`.

### As funções (o contrato de todo módulo)

| Função | O que faz | Padrão do motor |
|---|---|---|
| `_status` | Imprime `no` ou chama `version_status <id>` (`ok`, `old:<v>` ou `new:<v>`). | instalada se o jar está lá ou o nbkit gravou a versão |
| `_install_steps` | Imprime quantos `step` a instalação usa. | 1 |
| `_install` | Instala. Usa `step`, `ok`, `info`, `warn` e `die` do nbkit. | copia e liga o jar, mostra a dica |
| `_uninstall_steps` | Imprime quantos `step` a desinstalação usa. | 1 |
| `_uninstall` | Remove. | remove o jar |
| `_paths` | Caminhos (relativos ao userdir) que ela altera: entram no ponto de restauração. | o jar e o xml dele |
| `_uninstall_summary` | Linhas "Sai / Fica" mostradas antes de confirmar. | `[uninstall]` do tool.toml |
| `_check` | Com o NetBeans aberto: imprime `res 0 "..."` ou `res 1 "..."`. Retorna 0 (ok), 1 (reinstalar corrige) ou 2 (não corrige). | o jar carregou, sem erro no log |

Opcionais (o motor de temas usa; uma ferramenta também pode):

| Função | O que faz |
|---|---|
| `_backups` | Lista os arquivos de backup da ferramenta (o mais antigo primeiro). Faz o item "Backups" aparecer. |
| `_backup_desc <arquivo>` | Descrição curta do que tem no backup. |
| `_restore_steps <arquivo>` e `_restore <arquivo>` | Restaura um backup. |
| `_rollback` | Desfaz algo fora do userdir se a instalação parar no meio. |

O nbkit grava sozinho a versão instalada em `$UD/nbkit/<id>.version` depois de cada instalação.

### Ajudantes do nbkit

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (pasta temporária apagada no fim), `ask_yn <pergunta> Y|N`, `bk_date`,
`version_status`, `file_copy <arquivo> <destino> <sha256>`, `module_xml <codename>`, `res <0|1> <texto>`,
`log_has_module <nome>` e `log_module_errors <regex>` (para o `check`). Ficam no `lib/registry.sh` e no `lib/terminal.sh`.

A interface gráfica acompanha o `step` (barra de progresso) e o `ask_yn` (diálogo) sozinha. Uma pergunta feita em
Python precisa chamar `event(ev='ask', text=..., default='Y' ou 'N')` do `lib/uievents.py` antes de ler a resposta
e `event(ev='answered')` depois, como faz o `lib/themes/build.py`.

### Textos

Tudo o que aparece no terminal vem de `lang/<idioma>.lang`. Use `t <chave> [valores...]`, que imprime o texto com os `%s`
preenchidos na ordem (ex.: `step "$(t meu.passo "$nome")"`), e crie a chave em todos os arquivos de `lang/`, com o id
da ferramenta como prefixo. Trechos em Python recebem os mesmos arquivos em `NBKIT_LANG_FILES` e leem com o `lib/text.py`.

### Testes

O `tests/engine.sh` tem uma ferramenta feita só de `tool.sh` ("Tools engine"), instalada no NetBeans falso: um bom modelo
para os testes de uma ferramenta nova. Rode tudo com `bash nbkit.sh test`.
