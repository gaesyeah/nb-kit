<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-30363D?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-2F81F7?style=for-the-badge"></a>
</p>

# Como criar um módulo do nbkit

Um módulo do NetBeans é uma pasta em `modules/` com o jar dele e um `module.toml`, sem código. O nbkit acha a pasta
sozinho e o módulo aparece no menu, com instalar, atualizar, reinstalar, desinstalar, o progresso `[n/N]`, o ponto de
restauração e a conferência. O motor é o `lib/modules.sh`. Temas são pastas em `modules/themes/` (veja "Criar um
tema" no [README](../README.pt-BR.md#criar-um-tema)).

## module.toml

```toml
[module]
name = { en = "JSF checks", pt-BR = "Verificações de JSF" }
description = { en = "Warnings in the xhtml editor", pt-BR = "Avisos no editor de xhtml" }
version = 2                       # aumente quando o jar mudar, para o menu oferecer a atualização
jar = "nbkit-jsf.jar"             # o jar desta pasta
codename = "nbkit.jsf"            # OpenIDE-Module do jar
sha256 = "2e95a0dd..."            # sha256 do jar (o src/build.sh atualiza)
hint = { en = "...", pt-BR = "as regras ligam e desligam em Tools > Options > Editor > JSF" }   # opcional, depois de instalar

[uninstall]                       # opcional: linhas mostradas antes de confirmar a desinstalação
goes = { en = "the checks module", pt-BR = "o módulo de verificações" }
stays = { en = "your settings in Tools > Options", pt-BR = "suas opções em Tools > Options" }
```

O nome da pasta é o id do módulo (`bash nbkit.sh install jsf`): letras minúsculas, números e hífen. Os textos podem ser
um texto só ou um por idioma. O jar vai para `modules/<codename com hífens>.jar` no userdir, e o `check` procura o
codename no log do NetBeans. Se o `module.toml` tiver erro, o nbkit ignora o módulo e diz o motivo.

## Módulos em bash (avançado)

Para algo que não seja só um jar, coloque um `.sh` em `modules/`. O nbkit carrega com `source`; ele se registra com:

```bash
nbkit_register <id> <prefixo> <categoria> "<nome>" "<descrição>" <versão>
```

- **id:** o que aparece na linha de comando (`bash nbkit.sh install <id>`).
- **prefixo:** início do nome das funções do módulo (`<prefixo>_status`, `<prefixo>_install`...).
- **categoria:** `theme` (só um tema fica ativo por vez; instalar outro troca) ou `tool`.
- **versão:** número inteiro. Quando muda, o menu oferece atualizar.

### Funções obrigatórias

| Função | O que faz |
|---|---|
| `<prefixo>_status` | Imprime `no` ou chama `version_status <id>` (devolve `ok`, `old:<v>` ou `new:<v>`). |
| `<prefixo>_install_steps` | Imprime quantos `step` a instalação usa. |
| `<prefixo>_install` | Instala. Usa `step`, `ok`, `info`, `warn` e `die` do nbkit. |
| `<prefixo>_uninstall_steps` | Imprime quantos `step` a desinstalação usa. |
| `<prefixo>_uninstall` | Remove. |
| `<prefixo>_paths` | Caminhos (relativos ao userdir) que o módulo altera: entram no ponto de restauração. |
| `<prefixo>_uninstall_summary` | Linhas "Sai / Volta / Fica" mostradas antes de confirmar. |
| `<prefixo>_check` | Com o NetBeans aberto: imprime `res 0 "..."` ou `res 1 "..."`. Retorna 0 (ok), 1 (reinstalar corrige) ou 2 (não corrige). |

### Funções opcionais

| Função | O que faz |
|---|---|
| `<prefixo>_backups` | Lista os arquivos de backup do módulo (o mais antigo primeiro). Faz o item "Backups" aparecer. |
| `<prefixo>_backup_desc <arquivo>` | Descrição curta do que tem no backup. |
| `<prefixo>_restore_steps <arquivo>` e `<prefixo>_restore <arquivo>` | Restaura um backup. |
| `<prefixo>_rollback` | Desfaz algo fora do userdir se a instalação parar no meio. |

### Ajudantes do nbkit

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (pasta temporária apagada no fim), `ask_yn <pergunta> Y|N`, `bk_date`,
`version_status`, `file_copy <arquivo> <destino> <sha256>`, `module_xml <codename>`, `log_has_module <nome>` e
`log_module_errors <regex>` (para o `check`). A versão instalada de cada módulo fica em `$UD/nbkit/<id>.version`.

A interface gráfica acompanha o `step` (barra de progresso) e o `ask_yn` (diálogo) sozinha. Uma pergunta feita em
Python precisa chamar `event(ev='ask', text=..., default='Y' ou 'N')` do `lib/uievents.py` antes de ler a resposta
e `event(ev='answered')` depois, como faz o `lib/themes/build.py`.

### Textos

Tudo o que aparece no terminal vem de `lang/<idioma>.lang`. Use `t <chave> [valores...]`, que imprime o texto com os `%s`
preenchidos na ordem (ex.: `step "$(t meu.passo "$nome")"`), e crie a chave em todos os arquivos de `lang/`, com o
prefixo do módulo. Trechos em Python recebem os mesmos arquivos em `NBKIT_LANG_FILES` e leem com o `lib/text.py`.
