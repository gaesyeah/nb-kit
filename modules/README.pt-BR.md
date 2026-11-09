<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/tree/main/modules#readme"><img alt="English" src="https://img.shields.io/badge/English-30363D?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-2F81F7?style=for-the-badge"></a>
</p>

# Como criar um módulo do nbkit

Cada arquivo `.sh` em `modules/` (ou em `modules/themes/`, para temas) é carregado pelo `nbkit.sh` com `source`.
O menu, o status, o "Todos", o progresso `[n/N]`, o ponto de restauração e a conferência já funcionam
para qualquer módulo que siga o contrato abaixo.

Temas não usam este contrato diretamente: cada tema é uma pasta em `modules/themes/` só com dados, e o motor
(`modules/themes/_engine.sh`) cria as funções do contrato para ele (veja "Criar um tema" no
[README](../README.pt-BR.md#criar-um-tema)). Arquivos que começam com `_` não são carregados como módulo.

## Registro

```bash
nbkit_register <id> <prefixo> <categoria> "<nome>" "<descrição>" <versão>
```

- **id:** o que aparece na linha de comando (`bash nbkit.sh install <id>`).
- **prefixo:** início do nome das funções do módulo (`<prefixo>_status`, `<prefixo>_install`...).
- **categoria:** `theme` (só um tema fica ativo por vez; instalar outro troca) ou `tool`.
- **versão:** número inteiro. Quando muda, o menu oferece atualizar.

## Funções obrigatórias

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

## Funções opcionais

| Função | O que faz |
|---|---|
| `<prefixo>_backups` | Lista os arquivos de backup do módulo (o mais antigo primeiro). Faz o item "Backups" aparecer. |
| `<prefixo>_backup_desc <arquivo>` | Descrição curta do que tem no backup. |
| `<prefixo>_restore_steps <arquivo>` e `<prefixo>_restore <arquivo>` | Restaura um backup. |
| `<prefixo>_rollback` | Desfaz algo fora do userdir se a instalação parar no meio. |

## Ajudantes do nbkit

`$UD` (userdir), `$C` (`$UD/config`), `tmpdir` (pasta temporária apagada no fim), `ask_yn <pergunta> Y|N`, `bk_date`,
`version_status`, `log_has_module <nome>` e `log_module_errors <regex>` (para o `check`).

A versão instalada de cada módulo fica em `$UD/nbkit/<id>.version`, gravada pelo nbkit.

## Textos

Tudo o que aparece no terminal vem de `lang/<idioma>.lang`. Use `t <chave> [valores...]`, que imprime o texto com os `%s`
preenchidos na ordem (ex.: `step "$(t meu.passo "$nome")"`), e crie a chave em todos os arquivos de `lang/`, com o
prefixo do módulo (`jsf.`, `theme.`...). Trechos em Python recebem os mesmos arquivos em `NBKIT_LANG_FILES`
(veja a função `T` no `_engine.sh`).
